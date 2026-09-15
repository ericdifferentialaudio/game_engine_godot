"""
scripts/render_core.py

Blender-side execution engine for RenderJob objects (see render_config.py).

This module DOES depend on `bpy` and can only run inside a Blender Python
interpreter, e.g.:

    blender --background --python scripts/render_cli.py -- --subject clans

Importing this module outside Blender raises a clear ImportError instead of
an opaque `ModuleNotFoundError: bpy`, so tooling/tests that only need
render_config.py's plain dataclasses can still import this file's constants
without crashing (see `BPY_AVAILABLE` below).

Responsibilities:
    - load a mesh (glb) into a clean scene
    - set up the fixed isometric camera + transparent-background render
      settings (locked pipeline parameters)
    - step through a RenderJob's directions x frames, orbiting the CAMERA
      (not the subject) around the subject per direction, and rendering one
      PNG per frame - the subject's own transform/animation is never
      touched, see position_camera_for_direction()
    - skip already-rendered frames (idempotent / resumable batch runs)
"""
from __future__ import annotations

import math
from pathlib import Path
from typing import Optional

from render_config import RenderJob, DIRECTION_ANGLES

try:
    import bpy
    BPY_AVAILABLE = True
except ImportError:
    bpy = None  # type: ignore
    BPY_AVAILABLE = False


def _require_bpy() -> None:
    if not BPY_AVAILABLE:
        raise RuntimeError(
            "render_core requires Blender's bpy module. Run this via "
            "`blender --background --python scripts/render_cli.py -- ...`, "
            "not a plain python interpreter."
        )


# ============================================================
# Scene setup
# ============================================================

def reset_scene() -> None:
    """Clear the default scene to a blank slate before loading a subject."""
    _require_bpy()
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _fix_bone_parented_item_transforms(armature_obj) -> None:
    """
    Works around a Blender glTF-importer quirk affecting nodes attached by
    attach_hand_item.py's batch mode (see that script's module docstring):
    a plain (non-joint) node parented to a skin JOINT node is represented on
    import via Blender's own "Bone" parent_type, whose world-matrix
    reconstruction does NOT match the source glTF's forward-kinematics
    result once the joint/armature chain carries scale (observed here: the
    armature object's 0.01 scale composing with the item node's own baked
    100x scale). Independently re-deriving the item's world transform via
    plain glTF FK math (translation/rotation/scale composed straight down
    the node hierarchy, matching attach_hand_item.py's own
    compute_hand_local_trs()) confirmed the authored data is correct and
    only Blender's *display* of it is wrong; without this fix the item ends
    up many meters away from the hand, invisible in every render (this
    pipeline's fixed camera/ortho framing never reaches that far).

    Fix: for every mesh object parented to a bone (parent_type == "BONE")
    whose name marks it as an attached item ("item_" prefix, see
    attach_hand_item.py's attach_node_to_hand()), recompute
    matrix_parent_inverse so that combining it with the object's own
    imported matrix_basis reproduces the correct glTF-FK world transform:
    armature.matrix_world @ pose_bone.matrix @ item.matrix_basis. This
    leaves the item's local TRS (matrix_basis) exactly as glTF authored it
    and only corrects Blender's parent-inverse bookkeeping, so the item
    still follows the hand joint through any future animation/re-posing
    exactly like every other bone-parented child does.

    NOTE: attach_hand_item.py's batch mode no longer produces bone-parented
    item nodes -- items are now attached via proper glTF skinning (rigidly
    weighted 100% to the hand joint, sharing the character's own skin/
    inverse-bind-matrices) instead, which every spec-compliant glTF
    consumer (including Meshy, not just Blender) interprets identically
    with no special-casing needed. This function is now a no-op against
    freshly-generated "_final.glb" files (they contain no "item_"-prefixed
    bone-parented children for it to find) and is kept only so any older
    already-generated files using the previous approach still render
    correctly in this pipeline.
    """
    if armature_obj is None or armature_obj.type != "ARMATURE":
        return

    for obj in list(armature_obj.children):
        if not obj.name.startswith("item_"):
            continue
        if getattr(obj, "parent_type", None) != "BONE":
            continue
        bone_name = getattr(obj, "parent_bone", "")
        pose_bone = armature_obj.pose.bones.get(bone_name)
        if pose_bone is None:
            continue

        # Blender's current (wrong) reconstruction of the parent frame it
        # used, backed out from the object's own current (wrong) world
        # matrix and its correct local matrix_basis.
        blender_parent_matrix = obj.matrix_world @ obj.matrix_basis.inverted()
        # The parent frame glTF FK actually implies: the hand joint's own
        # world transform (armature transform composed with the joint's
        # current pose matrix).
        desired_parent_matrix = armature_obj.matrix_world @ pose_bone.matrix
        obj.matrix_parent_inverse = blender_parent_matrix.inverted() @ desired_parent_matrix

    bpy.context.view_layer.update()


def import_mesh(mesh_path: Path) -> "bpy.types.Object":
    """
    Import a .glb/.gltf mesh and return the root object. Assumes a single
    rigged root object per file (Blender's glTF importer creates an armature
    + mesh hierarchy). The returned object's own transform/animation is
    never modified by this pipeline - direction changes are achieved by
    orbiting the camera around it instead (see position_camera_for_direction).

    Also corrects any attach_hand_item.py-attached item node's mis-placed
    world transform (see _fix_bone_parented_item_transforms's docstring) so
    attached items (e.g. a hand weapon) render in the correct place instead
    of many meters away from the character.
    """
    _require_bpy()
    if mesh_path is None or not mesh_path.is_file():
        raise FileNotFoundError(f"Mesh not found: {mesh_path}")

    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(mesh_path))
    after = set(bpy.context.scene.objects)
    imported = list(after - before)
    if not imported:
        raise RuntimeError(f"glTF import produced no objects: {mesh_path}")

    # Prefer an ARMATURE root if present, else the first object with no parent.
    roots = [o for o in imported if o.parent is None]
    result = None
    for o in roots:
        if o.type == "ARMATURE":
            result = o
            break
    if result is None:
        result = roots[0] if roots else imported[0]

    if result is not None and result.type == "ARMATURE":
        _fix_bone_parented_item_transforms(result)
        _select_primary_action(result)

    return result


def _select_primary_action(armature_obj: "bpy.types.Object") -> None:
    """
    Works around a Blender glTF-importer quirk where the armature's active
    action (animation_data.action) after import is NOT reliably the file's
    real motion clip. Meshy's source .glb files carry multiple actions/NLA
    strips per armature - e.g. for anim_walk: `Armature|clip0|baselayer`
    (frame_range (0, 1), a single near-static rest pose),
    `Armature|clip0|baselayer.001` (frame_range (7, 7), a single frozen
    pose), and `rigify_clip` (frame_range (1, 48), the actual walk motion).
    The importer arbitrarily left `Armature|clip0|baselayer` active, so
    every rendered frame sampled within a 1-frame static range: no motion,
    a different (smaller/contracted) pose than intended, and a bounding box
    that didn't fill the frame as expected.

    Fix: after import, explicitly pick the action with the LARGEST frame
    span among every action loaded from this file (bpy.data.actions is
    fresh per job - reset_scene() wipes it via read_factory_settings before
    each import_mesh call) and make it the active action. The real motion
    clip is reliably the one with many frames; rest/pose-snapshot clips are
    always 1-2 frames.
    """
    if not bpy.data.actions:
        return

    best_action = None
    best_span = -1.0
    for action in bpy.data.actions:
        frame_start, frame_end = action.frame_range
        span = frame_end - frame_start
        if span > best_span:
            best_span = span
            best_action = action

    if best_action is None:
        return

    if armature_obj.animation_data is None:
        armature_obj.animation_data_create()
    armature_obj.animation_data.action = best_action


def _object_world_bbox_corners(obj: "bpy.types.Object") -> list:
    """
    World-space bounding-box corners of `obj` and all its mesh children
    (e.g. an armature's skinned mesh), evaluated at `obj`'s CURRENT
    transform. The subject's own transform is never rotated by this
    pipeline (direction is achieved by orbiting the camera instead, see
    position_camera_for_direction), so these corners reflect the subject's
    natural imported/posed orientation.
    """
    import mathutils

    corners = []
    stack = [obj]
    while stack:
        o = stack.pop()
        stack.extend(o.children)
        if o.type == "MESH":
            corners.extend(o.matrix_world @ mathutils.Vector(c) for c in o.bound_box)
    return corners


def _object_world_bbox_center(obj: "bpy.types.Object") -> "mathutils.Vector":
    """
    World-space bounding-box center of `obj` and all its children, used to
    aim the camera regardless of whether the imported mesh happens to be
    centered at the scene origin.
    """
    import mathutils

    corners = _object_world_bbox_corners(obj)
    if not corners:
        return mathutils.Vector((0.0, 0.0, 0.0))

    min_v = mathutils.Vector((min(c[i] for c in corners) for i in range(3)))
    max_v = mathutils.Vector((max(c[i] for c in corners) for i in range(3)))
    return (min_v + max_v) / 2.0


# FIXED, standardized ortho_scale (world units spanned by the frame's full
# width/height) shared by every clan subject/state. Deliberately NOT
# computed per-subject or per-state: an earlier per-job auto-calibration
# pass produced a DIFFERENT zoom for every animation (idle vs death vs
# meditate), so the same character visibly changed size between its own
# animations, and states with a large vertical pose swing (meditate's
# crouch, death's collapse) still clipped when the calibration's sampled
# poses didn't happen to catch the true extreme. A single fixed value,
# generous enough to fit the tallest/widest pose across the whole roster
# with headroom, trades a bit of "fills the frame perfectly" for the
# uniform scale a sprite pipeline actually needs across all clans/units/
# states. Originally calibrated at 4.5 against the Crimson Shieldbearer
# pilot's meditate (crouching lunge with outstretched sword) pose, which
# clipped badly at 2.6 (sword tip exits frame) -- but 4.5 left every
# subject rendering far too small in practice (re-measured across every
# subject with real rendered frames -- bard/scout, fighter/common,
# fighter/defender -- worst observed real fill was only 53.5% of the
# frame's width/height at scale 4.5, typical frames far smaller, ~35%
# fill on average -- reported by user as "animation renders are too
# small"). Lowered to 3.0 (fill scales inversely with ortho_scale, so
# this maps that same 53.5%-at-4.5 worst case to ~80%-at-3.0 -- still
# comfortable headroom against the frame edge, not a tight/exact fit,
# while roughly doubling the character's visible size versus 4.5).
#
# REVISED (real user request, this session): "zoom in slightly" on top of
# the 3.0 baseline. Lowered to 2.7 (a further ~10% reduction; fill scales
# inversely with ortho_scale) - still comfortably above the 2.6 value that
# was observed clipping the worst-case pose (Crimson Shieldbearer's
# meditate, crouching lunge with outstretched sword), so headroom is
# preserved while every subject renders modestly larger/tighter-framed.
FIXED_ORTHO_SCALE = 2.7


def _subject_aim_point(target: "bpy.types.Object") -> "mathutils.Vector":
    """
    World-space point the camera should look at: the mesh's actual CURRENT
    bounding-box center (X/Y/Z), evaluated at whatever frame is set on the
    scene when this is called.

    Originally X/Y came from the armature object's own origin instead of
    the bbox center, on the theory that the object's origin never moves
    (direction is achieved by orbiting the camera, not rotating the
    subject - see position_camera_for_direction's docstring) so it made a
    stable orbit pivot. That reasoning missed that Meshy's animation clips
    carry real ROOT-BONE translation drift within the pose itself (e.g. a
    walk cycle's hips bone advancing many units over the clip) - the
    ARMATURE OBJECT's origin indeed never moves, but the character's
    actual on-screen position does, so pinning the aim point to the
    object's static origin let the character visibly drift out of frame
    over the course of a clip while the camera kept looking at the empty
    point the character started at (observed: bard/scout anim_walk's bbox
    x-range sliding from roughly -0.14..0.29 at frame 1 to 0.03..0.54 at
    frame 48 - half a subject-width of lateral drift the old aim point
    never followed). Using the bbox center's X/Y too (in addition to Z,
    which already used the bbox center for the same reason: a humanoid
    rig's origin is typically at its feet, not its visual center) keeps
    the camera following the character's true current position every
    frame, matching this pipeline's fixed-size sprite-frame requirement
    (a walk cycle should loop in place visually, not walk itself off the
    render) - see run_job()'s per-frame call to
    position_camera_for_direction() for how this is kept in sync with the
    current animation frame.
    """
    return _object_world_bbox_center(target)


def setup_camera(
    pitch_deg: float,
    target: "bpy.types.Object",
    ortho_scale: Optional[float] = None,
) -> "bpy.types.Object":
    """
    Creates the orthographic render camera (fixed FOV/pitch, transparent
    background handled separately in setup_render_settings). Does NOT
    position the camera for a specific direction - call
    position_camera_for_direction() once per direction after this.

    `ortho_scale`: if None (the default), uses FIXED_ORTHO_SCALE - a single
    value shared by every subject/state (see FIXED_ORTHO_SCALE's docstring
    for why this is fixed rather than computed per-subject). Pass an
    explicit value to override for a different subject category (e.g.
    dragons/monsters at a different native render size).
    """
    _require_bpy()

    cam_data = bpy.data.cameras.new("RenderCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = FIXED_ORTHO_SCALE if ortho_scale is None else ortho_scale

    cam_obj = bpy.data.objects.new("RenderCam", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)

    bpy.context.scene.camera = cam_obj
    return cam_obj


def position_camera_for_direction(
    cam_obj: "bpy.types.Object",
    target: "bpy.types.Object",
    pitch_deg: float,
    direction: str,
) -> None:
    """
    Orbits the camera to the position for `direction` around `target`,
    keeping the subject itself untouched (no rotation applied to the mesh -
    it stays exactly as imported/posed by its animation). This REPLACES the
    earlier approach of rotating the subject under a fixed camera: rotating
    the subject risked interacting with whatever coordinate-system-
    correction rotation the glTF importer may bake onto the armature root,
    and a directional arrow-marker test confirmed the per-direction ANGLES
    were mathematically correct even when real character renders still
    looked wrong - pointing at some other camera/subject interaction rather
    than the angle table itself. Orbiting the camera sidesteps all of that:
    the subject's own transform is never touched.

    The orbit distance/height is derived from FIXED_ORTHO_SCALE so the
    camera-to-subject distance is consistent across every render (distance
    only matters for near/far clipping and light falloff for an orthographic
    camera, not apparent size, but keeping it fixed avoids any per-subject
    variance creeping back in).
    """
    _require_bpy()
    import mathutils

    aim_point = _subject_aim_point(target)
    pitch_rad = math.radians(pitch_deg)

    distance = max(FIXED_ORTHO_SCALE * 3.0, 10.0)
    horiz = distance * math.cos(pitch_rad)
    height = distance * math.sin(pitch_rad)

    # Rotating the SUBJECT by +theta (CCW) around Z, under a fixed camera,
    # produces an identical image to keeping the subject fixed and instead
    # rotating the CAMERA by -theta around the subject. Two earlier attempts
    # at this base offset (-90, then an empirically-"corrected" -150, then
    # back to -90 again) all kept the SAME sign on azimuth_deg, which - as
    # proven this session with an unambiguous ground-truth diagnostic (a
    # throwaway scene with plain-text N/S/E/W markers at their literal
    # world-compass positions, rendered through this exact function) -
    # makes the camera's real azimuth a MIRROR REFLECTION of the requested
    # direction's azimuth across the e/w axis, not a simple rotational
    # offset. That reflection leaves "e" and "w" looking self-consistent
    # (they sit ON the mirror axis, e always resolves to a full front view
    # confirmed by real character renders, w to a full back view - which is
    # why every prior fix attempt, tested by eyeballing e/w, looked
    # "plausible" and shipped) while silently swapping the two pairs of
    # off-axis diagonals with each other: ne's azimuth always landed
    # exactly on se's correct camera position and vice versa (confirmed
    # both by the marker diagnostic and by the user's real-world report:
    # "ne actually shows se's view"), and likewise nw swapped with sw.
    # No constant added to -90 alone can fix a mirror reflection, only
    # negating azimuth_deg itself can: this reverses the rotational
    # direction of the orbit while leaving the two mirror-axis fixed points
    # (azimuth_deg 0 and 180 -> e/w) exactly where they already were
    # (confirmed correct), and swaps ne<->se, nw<->sw back onto their
    # correctly-labeled views.
    azimuth_deg = DIRECTION_ANGLES[direction]
    camera_angle_rad = math.radians(-90.0 + azimuth_deg)

    offset = mathutils.Vector((
        horiz * math.cos(camera_angle_rad),
        horiz * math.sin(camera_angle_rad),
        height,
    ))
    cam_obj.location = aim_point + offset

    direction_vec = aim_point - cam_obj.location
    cam_obj.rotation_euler = direction_vec.to_track_quat("-Z", "Y").to_euler()


def setup_lighting() -> "bpy.types.Object":
    """
    Single sun lamp from upper-left, matching art_spec.md's stated art
    direction ("dramatic lighting from upper-left"). reset_scene() creates a
    fully empty scene with no lights at all, so without this every render
    would come out unlit (pure black) even once the camera correctly frames
    the subject.
    """
    _require_bpy()
    light_data = bpy.data.lights.new("RenderSun", type="SUN")
    light_data.energy = 3.0

    light_obj = bpy.data.objects.new("RenderSun", light_data)
    bpy.context.scene.collection.objects.link(light_obj)

    # Upper-left, angled down toward the subject - matches the isometric
    # camera's general facing without being perfectly parallel to it, so
    # surfaces get visible shading/falloff rather than flat frontal light.
    light_obj.rotation_euler = (math.radians(55), 0.0, math.radians(-35))
    return light_obj


def setup_world_ambient_lighting(energy_per_light: float = 3.0) -> list:
    """
    Shadow-free, direction-less ambient lighting via a RIG of several sun
    lamps surrounding the subject from opposing angles (front/back/
    left/right/top/bottom), instead of setup_lighting()s single
    directional sun lamp. Deliberately NOT implemented via Blenders
    World background strength, because that same background is what
    shows up as the rendered backdrop with film_transparent off -- using
    it as a light source would force a bright/white background,
    conflicting with setup_solid_black_background() below. Keeping
    illumination on real light objects and the World color pure black
    lets both requirements (ambient light AND a solid black background)
    be satisfied independently.

    Used for pre-Meshy-handoff QA/reference renders (both
    render_final_preview.py and, when requested, this modules own
    run_job()) so a unit looks the SAME whether viewed before or after
    animating in Meshy -- a single strong directional light produces
    hard shadows/highlights that would look different once Meshy poses
    the character differently per animation frame, whereas this
    multi-angle rig approximates uniform ambient light with much softer,
    near-shadow-free falloff regardless of pose.

    energy_per_light is tuned relative to setup_lighting()s energy=3.0
    single sun -- both this and setup_lighting() are calibrated against
    a character material with NO emissiveFactor self-glow (see
    repair_material_lighting_properties() in attach_hand_item.py, which
    zeros out an unconditional emissiveFactor=[1,1,1] Meshy sometimes
    authors) -- without that repair, real content will double-expose.
    Returns the list of created light objects.
    """
    _require_bpy()
    # (pitch_deg, yaw_deg) pairs pointing roughly from 6 surrounding
    # directions toward the origin -- front/back, left/right, top/bottom.
    directions = [
        (55, -35), (55, 145), (55, 55), (55, -125), (85, 0), (-85, 0),
    ]
    lights = []
    for i, (pitch, yaw) in enumerate(directions):
        light_data = bpy.data.lights.new(f"AmbientSun_{i}", type="SUN")
        light_data.energy = energy_per_light
        light_obj = bpy.data.objects.new(f"AmbientSun_{i}", light_data)
        bpy.context.scene.collection.objects.link(light_obj)
        light_obj.rotation_euler = (math.radians(pitch), 0.0, math.radians(yaw))
        lights.append(light_obj)
    return lights


def setup_solid_black_background() -> None:
    """
    Opaque pure-black background, instead of setup_render_settings()s
    transparent-PNG approach -- pairs with setup_world_ambient_lighting()
    for pre-Meshy-handoff QA/reference renders where a flat black backdrop
    (not transparency, which some external viewers render as white or
    checkerboard) is wanted.
    """
    _require_bpy()
    scene = bpy.context.scene
    scene.render.film_transparent = False
    world = scene.world
    if world is None:
        world = bpy.data.worlds.new("BlackWorld")
        scene.world = world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node is not None:
        bg_node.inputs[0].default_value = (0.0, 0.0, 0.0, 1.0)
        bg_node.inputs[1].default_value = 0.0


def setup_render_settings(size_px: int) -> None:
    """Transparent background, square render at the locked pipeline size."""
    _require_bpy()
    scene = bpy.context.scene
    scene.render.resolution_x = size_px
    scene.render.resolution_y = size_px
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"


# ============================================================
# Frame stepping / rendering
# ============================================================

def render_frame(output_path: Path) -> None:
    _require_bpy()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.filepath = str(output_path.with_suffix(""))  # Blender appends extension
    bpy.ops.render.render(write_still=True)


def run_job(job: RenderJob, *, force: bool = False, verbose: bool = True) -> list[Path]:
    """
    Execute a single RenderJob end to end: load mesh, set up camera/render
    settings once, then for each direction x frame set the animation's frame
    number and render a PNG, skipping frames that already exist unless
    `force` is set.

    Returns the list of frame paths written (or already present, if skipped).
    """
    _require_bpy()

    reset_scene()
    root_obj = import_mesh(job.mesh_path)
    cam_obj = setup_camera(job.camera_pitch_deg, root_obj)
    # Ambient rig + solid black background (see
    # setup_world_ambient_lighting()/setup_solid_black_background()
    # docstrings) -- used here too (not just render_final_preview.py) so
    # a unit renders IDENTICALLY whether viewed as a pre-Meshy QA preview
    # or as the actual post-animation sprite frames, per user request.
    setup_world_ambient_lighting()
    setup_render_settings(job.render_size)
    setup_solid_black_background()

    action = None
    if root_obj.animation_data and root_obj.animation_data.action:
        action = root_obj.animation_data.action

    written: list[Path] = []
    scene = bpy.context.scene

    for direction in job.directions:
        for frame_idx in range(job.state.frames):
            out_path = job.frame_path(direction, frame_idx)
            if out_path.is_file() and not force:
                written.append(out_path)
                continue

            if action is not None:
                # Map this state's local frame index onto the loaded clip's
                # frame range proportionally, resampling to our target frame
                # count. This is correct BECAUSE mesh_discovery.py resolves
                # one .glb per state (Meshy ships one file per animation
                # clip) — `action` here is that state's own clip, not a
                # shared multi-state action, so "proportional position in
                # this file's frame range" and "proportional position in
                # this state's clip" are the same thing.
                frame_start, frame_end = action.frame_range
                span = max(frame_end - frame_start, 1)
                t = frame_idx / max(job.state.frames - 1, 1)
                scene.frame_set(int(round(frame_start + t * span)))

            # Re-orbit the camera to this direction EVERY frame, not once
            # per direction: Meshy's rigify_clip actions carry real root-
            # bone translation drift across the clip (e.g. a walk cycle's
            # root bone advancing many units over the animation), and
            # _subject_aim_point()/setup_camera()'s orbit offset are both
            # derived from the subject's CURRENT world bbox/origin - set
            # once before the frame loop, that orbit point goes stale as
            # soon as the pose advances, so the character visibly drifts
            # out of frame over the course of a clip (observed: bbox
            # x-range sliding from roughly -0.14..0.29 at frame 1 to
            # 0.03..0.54 at frame 48 of anim_walk, half a subject-width of
            # lateral drift). Recomputing the aim point/offset after each
            # frame_set keeps the subject centered every frame regardless
            # of in-clip root motion, matching this pipeline's fixed-size
            # sprite-frame requirement (a walk cycle should loop in place
            # visually, not walk itself off the render).
            position_camera_for_direction(cam_obj, root_obj, job.camera_pitch_deg, direction)

            if verbose:
                print(f"[render] {job.subject_id} {job.state.name} {direction} "
                      f"{frame_idx:04d} -> {out_path}")

            render_frame(out_path)
            written.append(out_path)

    return written


def run_jobs(jobs: list[RenderJob], *, force: bool = False,
             verbose: bool = True) -> dict[str, list[Path]]:
    """
    Execute multiple RenderJobs in sequence (e.g. all states for a subject,
    or a whole subject-category batch). Returns {subject_id/state.name: [paths]}.

    A job is skipped (not re-rendered) when `force` is False and
    `job.needs_render()` is False — i.e. every expected frame already exists
    AND is newer than the job's source mesh (and the pipeline scripts
    themselves, via render_config.PIPELINE_SCRIPT_PATHS). Jobs with no
    resolvable source mesh yet (`job.is_renderable()` False) are reported
    separately and skipped regardless of `force`, since there's nothing to
    render from.
    """
    results: dict[str, list[Path]] = {}
    for job in jobs:
        key = f"{job.subject_id}/{job.state.name}"

        if not job.is_renderable():
            if verbose:
                print(f"[no-mesh] {key} - no source .glb resolved, skipping")
            results[key] = job.all_frame_paths() if job.is_complete() else []
            continue

        if not force and not job.needs_render():
            if verbose:
                print(f"[skip] {key} up to date ({len(job.all_frame_paths())} frames)")
            results[key] = job.all_frame_paths()
            continue

        results[key] = run_job(job, force=True, verbose=verbose)
    return results
