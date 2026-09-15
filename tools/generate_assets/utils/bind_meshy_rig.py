"""
scripts/utils/bind_meshy_rig.py

NEW pipeline stage implementing the revised Meshy workflow: Meshy's own
rigged/animated mesh output is a THROWAWAY placeholder (Meshy's Rigging API
has a hard ~200-250 triangle auto-decimation ceiling on ANY upload -- see
decimate_for_meshy.py's module docstring), so it must never be shipped as
the actual in-game visual mesh. Only Meshy's ARMATURE (bone hierarchy /
rest pose) and ANIMATION data (actions) are worth keeping from its output.

This script runs INSIDE Blender's own Python interpreter (needs `bpy`),
following the same headless-invocation pattern as decimate_for_meshy.py:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" ^
        --background --python scripts\\utils\\bind_meshy_rig.py -- ^
        --optimized clans\\bard\\scout\\base_mesh\\_models\\bard_scout_dagger_raised_final_optimized.glb ^
        --meshy-anim clans\\bard\\scout\\base_mesh\\_meshy_raw\\bard_scout_dagger_raised_anim_attack_meshy_raw.glb ^
        --output clans\\bard\\scout\\anim_attack\\Meshy_AI_bard_scout_anim_attack.glb

Everything after `--` is this script's own argparse; Blender consumes its
own args before the `--`.

WHAT IT DOES:
    1. Imports --meshy-anim (Meshy's rigged/animated output: an Armature
       object, its rest-pose bones, one or more Actions/NLA tracks, and its
       own tiny placeholder mesh -- KEPT TEMPORARILY as a real-weight
       source, see step 4b, not discarded until the very end).
    2. Imports --optimized (the Blender-decimated, game-ready mesh at the
       target triangle budget -- produced upstream by decimate_for_meshy.py
       run against a much higher --target-triangles, e.g. 30000, than the
       ~242 Meshy itself would produce). This file has NO armature.
    3. Aligns the optimized mesh's world-space bounding box into the SAME
       coordinate space Meshy's own mesh/armature occupy (see
       _align_to_meshy_space) -- REQUIRED, since a real end-to-end test
       this session found these two files sit in totally different scales/
       origins (Meshy: real-world meters matching height_meters=1.7;
       raw/optimized: small mesh-local unit-scale bbox), which alone is
       enough to make Blender's own automatic bone-heat-weighting solver
       fail outright.
    4. Binds (skins) the optimized mesh to that armature:
         a. PRIMARY: if the optimized mesh already carries vertex groups
            matching the armature's bone names (i.e. it is a decimated
            descendant of the SAME skinned source attach_hand_item.py
            merged, so Blender's Decimate modifier preserved its original
            vertex groups), just add an Armature modifier pointing at the
            imported armature and re-parent -- no weight recomputation
            needed, preserving the highest-fidelity weights available.
         b. FALLBACK (Data Transfer, preferred over (c)): a real end-to-end
            test this session found Meshy's OWN exported armature commonly
            has corrupted/garbage bone TAIL positions (observed: tails
            thousands of units away from their heads, unrelated to the
            actual mesh scale) which makes Blender's bone-heat-weighting
            solver fail for EVERY bone regardless of coordinate alignment.
            Meshy's own throwaway mesh, however, DOES carry real, working
            per-vertex bone weights (that's how Meshy itself renders/
            animates it) -- so instead of recomputing weights from scratch,
            this transfers those EXISTING weights from Meshy's mesh onto
            the optimized mesh via a nearest-surface Data Transfer
            modifier (bpy.ops.object.data_transfer, VGROUP_WEIGHTS,
            POLYINTERP_NEAREST), which only requires the two meshes to
            spatially overlap (guaranteed by step 3), not a working bone
            hierarchy.
         c. LAST-RESORT FALLBACK: if (b) also produces no real weights
            (e.g. Meshy's own mesh unexpectedly has none either), falls
            back to Blender's automatic-weights parenting
            (bpy.ops.object.parent_set(type="ARMATURE_AUTO")) as a final
            attempt -- heuristic, lowest fidelity, but at least an attempt
            when nothing else is available.
    5. Re-parents the mesh as a flat, top-level scene node (matching the
       existing merged-mesh node-structure convention documented in
       decimate_for_meshy.py / required by validate_glb.py's Meshy-merge-
       compliance check), keeping the Armature MODIFIER binding intact.
    6. Exports the result as GLB with animations included, to --output --
       this becomes the pipeline's actual final asset (mesh + skeleton +
       animation), completely replacing Meshy's own low-poly output at
       that same path.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))


def _blender_argv() -> list[str]:
    argv = sys.argv
    if "--" in argv:
        return argv[argv.index("--") + 1:]
    return []


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--optimized", required=True, type=Path,
                    help="Path to the Blender-optimized (target-triangle-budget) game mesh .glb, no armature.")
    p.add_argument("--meshy-anim", required=True, type=Path,
                    help="Path to Meshy's own rigged/animated .glb output (throwaway mesh + real armature/animation).")
    p.add_argument("--output", required=True, type=Path,
                    help="Path to write the final bound (optimized mesh + Meshy armature/animation) .glb to.")
    return p


def _clear_scene() -> None:
    import bpy
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def _import_glb(path: Path) -> list:
    import bpy
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    after = set(bpy.context.scene.objects)
    imported = list(after - before)
    if not imported:
        raise RuntimeError(f"glTF import produced no objects: {path}")
    return imported


def _world_bbox(objs):
    """World-space (min, max) corner of the combined bounding box of the
    given mesh objects, as two 3-tuples."""
    import mathutils

    mins = [float("inf")] * 3
    maxs = [float("-inf")] * 3
    for o in objs:
        for corner in o.bound_box:
            world_co = o.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                mins[i] = min(mins[i], world_co[i])
                maxs[i] = max(maxs[i], world_co[i])
    return tuple(mins), tuple(maxs)


def _align_to_meshy_space(mesh_objs, meshy_min, meshy_max) -> None:
    """
    Rescales/repositions mesh_objs (in place, baked into their mesh data) so
    their combined world-space bounding box matches meshy_min/meshy_max's
    height (Z) and X/Y center -- i.e. aligns the optimized mesh into the
    SAME coordinate space Meshy's own (now-discarded) rigged mesh occupied.

    WHY THIS EXISTS: a real end-to-end test (this session) found the raw/
    optimized mesh sits in a small, mesh-local unit-scale bounding box
    (observed: Z in [-0.5, 0.5]), while Meshy's own rigged mesh -- and
    therefore its armature's bind-pose bones -- occupies real-world meters
    (observed: Z in [0, 1.7], matching the rig() call's height_meters=1.7).
    Binding the optimized mesh directly against that armature without first
    aligning coordinate spaces means the bones and mesh vertices don't
    spatially overlap AT ALL, which silently made Blender's automatic
    bone-heat-weighting solver fail for every bone ("Bone Heat Weighting:
    failed to find solution for one or more bones"), producing a mesh with
    NO real vertex weights -- which the glTF exporter then correctly
    detected as "no skin" and dropped, degrading the exported armature back
    into plain (non-skinned) empties on the next import. This alignment
    step is a no-op (scale ~1, translation ~0) if the two spaces already
    happen to coincide.
    """
    import bpy
    import mathutils

    opt_min, opt_max = _world_bbox(mesh_objs)
    opt_height = opt_max[2] - opt_min[2]
    meshy_height = meshy_max[2] - meshy_min[2]
    if opt_height <= 1e-9 or meshy_height <= 1e-9:
        print("WARNING: degenerate bounding box height -- skipping coordinate-space alignment.", file=sys.stderr)
        return

    scale = meshy_height / opt_height
    opt_center = mathutils.Vector(((opt_min[0] + opt_max[0]) / 2.0, (opt_min[1] + opt_max[1]) / 2.0, opt_min[2]))
    meshy_center = mathutils.Vector(((meshy_min[0] + meshy_max[0]) / 2.0, (meshy_min[1] + meshy_max[1]) / 2.0, meshy_min[2]))

    print(f"Aligning optimized mesh into Meshy's coordinate space: scale={scale:.6f}, "
          f"opt_height={opt_height:.6f} -> meshy_height={meshy_height:.6f}, "
          f"translating bbox-bottom-center {tuple(opt_center)} -> {tuple(meshy_center)}")

    t1 = mathutils.Matrix.Translation(-opt_center)
    s = mathutils.Matrix.Diagonal((scale, scale, scale, 1.0))
    t2 = mathutils.Matrix.Translation(meshy_center)
    transform = t2 @ s @ t1

    bpy.ops.object.select_all(action="DESELECT")
    for mesh_obj in mesh_objs:
        mesh_obj.matrix_world = transform @ mesh_obj.matrix_world
        mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def _repair_armature_bone_tails(armature_obj) -> None:
    """
    Repairs Meshy's own exported armature's badly corrupted bone TAIL
    positions in place (edit-bone data, in the armature's local/rest
    space) by snapping each bone's tail to the average head position of
    its direct children, or -- for leaf bones with no children -- by
    extending the same head-to-tail direction as its own parent bone at a
    small fixed length, so every bone ends up with a short, sane tail
    pointing roughly at the next joint down its own chain.

    WHY THIS EXISTS (Bug 3b, see activeContext.md): a real end-to-end test
    found Meshy's own exported bone tails are wildly wrong (observed:
    tails thousands of units away from their heads, sometimes in a
    direction that doesn't even point at the bone's own children) --
    e.g. `LeftToeBase` had `tail` ~1450 units from its `head` on a
    character whose total height is ~170 units. `bind_meshy_rig.py`'s
    module docstring already documented that this corruption makes
    Blender's own automatic bone-heat-weighting solver fail outright
    (hence the Data Transfer fallback this function's caller otherwise
    always falls back to) -- but the Data Transfer path turned out to
    inherit its own contamination from Meshy's SOURCE mesh weights being
    ambiguous near hip/coat-hem geometry, which is plausibly itself a
    side effect of the solver Meshy used internally being confused by
    these same corrupted tails. Repairing tail positions BEFORE attempting
    Blender's own automatic weights (bpy.ops.object.parent_set(type=
    "ARMATURE_AUTO")) gives that solver a real chance to produce clean,
    unambiguous weights directly against the optimized mesh, entirely
    bypassing Meshy's own (possibly still-ambiguous) per-vertex weights.

    Only tail positions are touched -- head positions (i.e. each bone's
    own joint location, which is what animation curves actually rotate
    around) are left untouched, since those aren't reported as corrupted
    and are load-bearing for both existing animation data and any
    Data-Transfer fallback still used elsewhere.
    """
    import bpy
    import mathutils

    bpy.ops.object.select_all(action="DESELECT")
    armature_obj.select_set(True)
    bpy.context.view_layer.objects.active = armature_obj
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        edit_bones = armature_obj.data.edit_bones
        children_by_parent: dict[str, list] = {}
        for eb in edit_bones:
            if eb.parent is not None:
                children_by_parent.setdefault(eb.parent.name, []).append(eb)

        # Use the overall spread of bone HEAD positions (unaffected by the
        # tail corruption) as a scale-independent sanity yardstick, instead
        # of comparing each bone against its own (possibly also corrupted)
        # parent -- avoids depending on edit_bones iteration/fix order.
        heads = [eb.head.copy() for eb in edit_bones]
        head_min = mathutils.Vector((min(h[i] for h in heads) for i in range(3)))
        head_max = mathutils.Vector((max(h[i] for h in heads) for i in range(3)))
        armature_span = (head_max - head_min).length or 1.0

        fixed = 0
        for eb in edit_bones:
            own_len = (eb.tail - eb.head).length
            is_corrupted = own_len > armature_span * 0.5

            kids = children_by_parent.get(eb.name, [])
            if kids:
                avg_child_head = sum((k.head for k in kids), mathutils.Vector()) / len(kids)
                new_len = (avg_child_head - eb.head).length
                if is_corrupted or new_len < own_len:
                    eb.tail = avg_child_head
                    fixed += 1
            elif is_corrupted:
                # Leaf bone with a corrupted tail and no children to aim
                # at: shrink the existing (wrong-length) direction down to
                # a small sane fraction of the armature's own scale
                # instead, preserving whatever direction Meshy did intend.
                direction = (eb.tail - eb.head)
                direction = direction.normalized() if direction.length > 1e-9 else mathutils.Vector((0.0, 0.0, 1.0))
                eb.tail = eb.head + direction * (armature_span * 0.05)
                fixed += 1

        print(f"_repair_armature_bone_tails: repaired {fixed}/{len(edit_bones)} bone tail(s) on "
              f"{armature_obj.name}.")
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")


def _has_real_weights(mesh_obj, bone_names: set) -> bool:
    """True if mesh_obj has at least one vertex group named after a real
    armature bone AND at least one vertex with a nonzero weight in one of
    those groups."""
    deform_group_idx = {vg.index for vg in mesh_obj.vertex_groups if vg.name in bone_names}
    if not deform_group_idx:
        return False
    return any(
        any(g.group in deform_group_idx and g.weight > 0.0 for g in v.groups)
        for v in mesh_obj.data.vertices
    )


def _transfer_weights_from_meshy_mesh(mesh_obj, meshy_char_mesh_objs, bone_names: set) -> bool:
    """
    Transfers real, working per-vertex bone weights from Meshy's own
    (still-in-scene) throwaway character mesh onto mesh_obj via a
    nearest-surface Data Transfer modifier, rather than recomputing weights
    from scratch -- see module docstring's step 4b for why this exists
    (Meshy's exported armature bone hierarchy is frequently too corrupted
    for Blender's own automatic bone-heat-weighting solver to work at all,
    but Meshy's mesh itself DOES carry real weights). Returns True if the
    transfer produced at least one real nonzero weight, False otherwise
    (caller should fall back further).

    BUG FIX (skewed/sheared feet during animated poses, diagnosed via real
    rendered anim_attack frames -- rest pose looked fine, mid-lunge/kick
    poses showed feet/lower-legs stretching into long triangular shapes
    detached from the body): Meshy's own rigged mesh is auto-decimated by
    its Rigging API down to ~242 triangles (see module docstring's WHY THIS
    EXISTS), so it's an extremely coarse weight source relative to the
    ~30k-triangle optimized mesh being transferred onto. The previous
    POLYINTERP_NEAREST mapping snaps EVERY destination vertex to a single
    nearest source vertex/triangle with no blending -- at that source
    density, extremity geometry (feet especially, being spatially small)
    frequently snapped to the nearest source triangle belonging to the
    calf/shin instead of the foot, so those foot vertices ended up almost
    entirely weighted to the calf bone instead of the foot bone. Once the
    knee/ankle joints actually rotate away from rest pose (e.g. an attack
    lunge), that mis-weighted foot geometry partially follows the calf's
    rotation instead of the foot's, producing the observed shearing.
    Switching to POLYINTERP_VNORPROJ (projects each destination vertex
    along its OWN normal to find the corresponding source-mesh surface
    point, then barycentrically interpolates that source polygon's
    weights) is far more robust against exactly this failure than plain
    nearest-point/nearest-polygon mapping: a foot vertex's outward-facing
    normal projects onto the source mesh's own foot surface even when the
    nearest raw 3D point on the coarse source mesh happens to belong to
    the calf, because normal-projection follows the local surface
    direction instead of pure Euclidean distance. (Blender's Data Transfer
    enum for this operator does not offer a distinct "nearest N faces,
    blended" mode -- POLYINTERP_NEAREST already barycentrically
    interpolates within whichever single nearest polygon it finds, so the
    real lever available here is *which* polygon gets selected, which is
    exactly what VNORPROJ improves.) A post-transfer vertex-group
    smoothing pass further blurs any remaining blocky weight-boundary
    artifacts across each transferred deform group before the mesh is
    bound/exported.
    """
    import bpy

    if not meshy_char_mesh_objs:
        return False
    source_obj = meshy_char_mesh_objs[0]

    # Data Transfer's VGROUP_WEIGHTS needs the destination to already own a
    # vertex group per source group name it's copying into.
    transferred_vgroup_names = []
    for vg in source_obj.vertex_groups:
        if vg.name not in mesh_obj.vertex_groups:
            mesh_obj.vertex_groups.new(name=vg.name)
        transferred_vgroup_names.append(vg.name)

    bpy.ops.object.select_all(action="DESELECT")
    source_obj.select_set(True)
    mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_obj

    mod = mesh_obj.modifiers.new(name="MeshyWeightTransfer", type="DATA_TRANSFER")
    mod.object = source_obj
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_VNORPROJ"

    with bpy.context.temp_override(object=mesh_obj):
        bpy.ops.object.datalayout_transfer(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)

    ok = _has_real_weights(mesh_obj, bone_names)
    if ok:
        _smooth_transferred_vertex_groups(mesh_obj, transferred_vgroup_names)
    return ok


def _smooth_transferred_vertex_groups(mesh_obj, vgroup_names: list, *, factor: float = 0.5, repeat: int = 2) -> None:
    """
    Manually blurs blocky weight-boundary artifacts left behind by
    transferring from a much coarser source mesh (see
    _transfer_weights_from_meshy_mesh's docstring for the failure mode this
    mitigates): for each named vertex group, repeatedly replaces every
    vertex's weight with a blend of its own weight and the average weight
    of its edge-connected neighbors.

    Implemented directly against mesh data (not via
    bpy.ops.object.vertex_group_smooth) because that operator's poll()
    requires real window/screen/area context that doesn't exist when
    Blender runs `--background` (confirmed: "context is incorrect" in a
    real headless run) -- this entire pipeline runs headless (see module
    docstring), so an operator-based approach can never work here.
    Best-effort: silently no-ops for a missing group name or a group with
    no real weights, since smoothing is a quality improvement on top of a
    transfer that already produced real usable weights, not something
    later steps depend on succeeding.
    """
    mesh = mesh_obj.data

    # Build vertex adjacency once (shared across all groups/iterations).
    neighbors: dict[int, set] = {v.index: set() for v in mesh.vertices}
    for edge in mesh.edges:
        a, b = edge.vertices[0], edge.vertices[1]
        neighbors[a].add(b)
        neighbors[b].add(a)

    for name in vgroup_names:
        vg = mesh_obj.vertex_groups.get(name)
        if vg is None:
            continue
        vg_idx = vg.index

        # Snapshot current per-vertex weight (0.0 where the vertex isn't a
        # member of this group at all).
        weights = [0.0] * len(mesh.vertices)
        member = [False] * len(mesh.vertices)
        for v in mesh.vertices:
            for g in v.groups:
                if g.group == vg_idx:
                    weights[v.index] = g.weight
                    member[v.index] = True
                    break

        if not any(member):
            continue

        for _ in range(repeat):
            new_weights = list(weights)
            for idx in range(len(mesh.vertices)):
                nbrs = neighbors[idx]
                if not nbrs:
                    continue
                avg = sum(weights[n] for n in nbrs) / len(nbrs)
                new_weights[idx] = weights[idx] * (1.0 - factor) + avg * factor
            weights = new_weights

        # Write the smoothed weights back, adding membership for
        # previously-zero-but-now-nonzero neighbors of the group (matching
        # what the real operator's smoothing/expand behavior does) and
        # updating existing members in place.
        for idx, w in enumerate(weights):
            if w <= 1e-6 and not member[idx]:
                continue
            vg.add([idx], w, "REPLACE")


def _select_action_with_largest_span(armature_obj) -> "bpy.types.Action | None":
    """
    Meshy's animated .glb output carries multiple actions/NLA strips per
    armature (matching render_core.py's own _select_primary_action finding,
    e.g. `Armature|clip0|baselayer` at frame_range (0, 1), a near-static rest
    pose, alongside `rigify_clip`, the actual multi-frame motion clip) -- the
    action assigned as animation_data.action right after import is NOT
    reliably the real motion clip. Returns whichever action loaded from this
    file has the largest frame span (the real motion clip is reliably the
    one with many frames; rest/pose-snapshot clips are always 1-2 frames),
    or None if bpy.data.actions is empty.
    """
    best_action = None
    best_span = -1.0
    import bpy
    for action in bpy.data.actions:
        frame_start, frame_end = action.frame_range
        span = frame_end - frame_start
        if span > best_span:
            best_span = span
            best_action = action
    return best_action


def _armature_rest_bbox(armature_obj):
    """World-space (min, max) bounding box of armature_obj's REST-pose bone
    HEAD positions -- unaffected by whatever pose/action is currently
    active, unlike pose.bones[*].head."""
    import mathutils

    heads = [armature_obj.matrix_world @ b.head_local for b in armature_obj.data.bones]
    if not heads:
        return None, None
    mins = mathutils.Vector((min(h[i] for h in heads) for i in range(3)))
    maxs = mathutils.Vector((max(h[i] for h in heads) for i in range(3)))
    return mins, maxs


def _align_armature_to_reference(source_armature_obj, ref_armature_obj) -> None:
    """
    Rescales/repositions source_armature_obj's OBJECT transform (not baked
    into any data -- source_armature_obj is discarded right after
    retargeting, see _retarget_action_onto_reference_armature) so its
    rest-pose bone-head bounding box matches ref_armature_obj's height (Z)
    and X/Y center -- the same coordinate-space-alignment technique
    _align_to_meshy_space already uses for meshes, applied here to two
    armatures so the world-space COPY_ROTATION/COPY_LOCATION constraints
    used for retargeting compare like-scaled poses.
    """
    import mathutils

    src_min, src_max = _armature_rest_bbox(source_armature_obj)
    ref_min, ref_max = _armature_rest_bbox(ref_armature_obj)
    if src_min is None or ref_min is None:
        print("WARNING: degenerate armature bone bounding box -- skipping armature alignment.", file=sys.stderr)
        return

    src_height = src_max[2] - src_min[2]
    ref_height = ref_max[2] - ref_min[2]
    if src_height <= 1e-9 or ref_height <= 1e-9:
        print("WARNING: degenerate armature height -- skipping armature alignment.", file=sys.stderr)
        return

    scale = ref_height / src_height
    src_center = mathutils.Vector(((src_min[0] + src_max[0]) / 2.0, (src_min[1] + src_max[1]) / 2.0, src_min[2]))
    ref_center = mathutils.Vector(((ref_min[0] + ref_max[0]) / 2.0, (ref_min[1] + ref_max[1]) / 2.0, ref_min[2]))

    print(f"Aligning Meshy's armature into the reference armature's coordinate space: scale={scale:.6f}, "
          f"src_height={src_height:.6f} -> ref_height={ref_height:.6f}")

    t1 = mathutils.Matrix.Translation(-src_center)
    s = mathutils.Matrix.Diagonal((scale, scale, scale, 1.0))
    t2 = mathutils.Matrix.Translation(ref_center)
    source_armature_obj.matrix_world = (t2 @ s @ t1) @ source_armature_obj.matrix_world


def _retarget_action_onto_reference_armature(ref_armature_obj, source_armature_obj, source_action):
    """
    Bakes source_action (driving source_armature_obj, Meshy's freshly rigged/
    animated armature from THIS bind_meshy_rig.py call) onto ref_armature_obj
    (the STABLE reference armature already embedded in the optimized mesh,
    whose bone names its vertex groups actually match) as a brand-new action,
    via full world-space bone retargeting, and returns that new action.

    WHY THIS EXISTS (bind-pose drift across separate Meshy rigging calls): a
    real regression this session found each meshy_animate.py state
    re-invokes Meshy's Rigging API from scratch for that model, and Meshy
    returns a DIFFERENT, non-reproducible bind pose (per-bone rest rotation)
    on every call, even though bone NAMES stay the same. bind_meshy_rig.py's
    previous behavior re-parented the optimized mesh's EXISTING vertex-group
    weights (computed once, against the rig_base_models.py armature) onto
    THIS freshly-returned armature via a plain Armature modifier -- which has
    no explicit stored bind matrix; it assumes the mesh's current shape IS
    the new armature's rest pose. Since it usually isn't (confirmed via raw
    quaternion inspection: same-named leg bones' bind rotations differed by
    ~180 degrees between separate rig calls for the same character), any
    bone rotation away from rest produced severely skewed limb deformation.

    FIX: never re-parent the mesh onto a new armature. Keep it permanently
    bound to its own stable reference armature (unchanged since
    rig_base_models.py, version-controlled from then on), and retarget
    Meshy's ANIMATION DATA onto that stable armature instead: per common
    bone name, add temporary COPY_ROTATION + COPY_LOCATION pose constraints
    (WORLD space) pointing at Meshy's armature, forcing ref_armature_obj's
    pose bones to reproduce Meshy's animated world-space pose frame-by-
    frame regardless of either armature's own local bind-pose convention,
    bake via bpy.ops.nla.bake, then remove the constraints -- the same
    technique used for this session's earlier one-off manual fix of
    anim_idle, now applied automatically on every pipeline run.
    """
    import bpy

    ref_bone_names = {b.name for b in ref_armature_obj.data.bones}
    src_bone_names = {b.name for b in source_armature_obj.data.bones}
    common = sorted(ref_bone_names & src_bone_names)
    if not common:
        raise RuntimeError(
            f"No common bone names between reference armature '{ref_armature_obj.name}' and Meshy's "
            f"animated armature '{source_armature_obj.name}' -- cannot retarget animation.")

    missing = src_bone_names - ref_bone_names
    if missing:
        print(f"NOTE: {len(missing)} bone(s) on Meshy's armature have no counterpart on the reference "
              f"armature and will not be retargeted: {sorted(missing)}", file=sys.stderr)

    _align_armature_to_reference(source_armature_obj, ref_armature_obj)

    if source_armature_obj.animation_data is None:
        source_armature_obj.animation_data_create()
    source_armature_obj.animation_data.action = source_action
    frame_start, frame_end = source_action.frame_range
    frame_start_i, frame_end_i = int(frame_start), int(frame_end)

    bpy.ops.object.select_all(action="DESELECT")
    ref_armature_obj.select_set(True)
    bpy.context.view_layer.objects.active = ref_armature_obj
    bpy.ops.object.mode_set(mode="POSE")

    for name in common:
        pb = ref_armature_obj.pose.bones[name]

        rot_c = pb.constraints.new("COPY_ROTATION")
        rot_c.target = source_armature_obj
        rot_c.subtarget = name
        rot_c.target_space = "WORLD"
        rot_c.owner_space = "WORLD"

        loc_c = pb.constraints.new("COPY_LOCATION")
        loc_c.target = source_armature_obj
        loc_c.subtarget = name
        loc_c.target_space = "WORLD"
        loc_c.owner_space = "WORLD"

    bpy.context.scene.frame_start = frame_start_i
    bpy.context.scene.frame_end = frame_end_i

    bpy.ops.nla.bake(
        frame_start=frame_start_i, frame_end=frame_end_i,
        only_selected=False, visual_keying=True, clear_constraints=True,
        clear_parents=False, use_current_action=False, bake_types={"POSE"},
    )
    bpy.ops.object.mode_set(mode="OBJECT")

    new_action = ref_armature_obj.animation_data.action if ref_armature_obj.animation_data else None
    if new_action is None:
        raise RuntimeError(f"nla.bake produced no action on reference armature '{ref_armature_obj.name}'.")
    new_action.name = source_action.name
    print(f"Retargeted '{source_action.name}' ({len(common)} common bone(s), frames "
          f"{frame_start_i}-{frame_end_i}) from '{source_armature_obj.name}' onto '{ref_armature_obj.name}'.")
    return new_action


def bind(optimized_path: Path, meshy_anim_path: Path, output_path: Path) -> None:
    import bpy

    if not optimized_path.is_file():
        raise FileNotFoundError(f"Optimized mesh not found: {optimized_path}")
    if not meshy_anim_path.is_file():
        raise FileNotFoundError(f"Meshy animated .glb not found: {meshy_anim_path}")

    _clear_scene()

    # --- Step 1: import Meshy's rigged/animated output, keep only the ---
    # --- armature (+ its actions); discard Meshy's own throwaway mesh. ---
    meshy_imported = _import_glb(meshy_anim_path)
    armature_objs = [o for o in meshy_imported if o.type == "ARMATURE"]
    if not armature_objs:
        raise RuntimeError(f"No Armature object found in Meshy output: {meshy_anim_path}")
    if len(armature_objs) > 1:
        print(f"WARNING: {len(armature_objs)} armatures found in {meshy_anim_path}; using the first one "
              f"({armature_objs[0].name}).", file=sys.stderr)
    meshy_armature_obj = armature_objs[0]
    _repair_armature_bone_tails(meshy_armature_obj)
    meshy_action = _select_action_with_largest_span(meshy_armature_obj)
    if meshy_action is None:
        raise RuntimeError(f"No actions found in Meshy output: {meshy_anim_path}")

    meshy_mesh_objs = [o for o in meshy_imported if o.type == "MESH"]
    # Meshy's mesh objects actually parented under the armature are the
    # real character mesh (with real, working bone weights); a plain
    # unparented "Icosphere" is a known Blender glTF-importer artifact
    # (matching decimate_for_meshy.py's own identical heuristic) -- an
    # unrelated unit-sphere object, discarded immediately, never used as a
    # weight source or for bounding-box measurement.
    meshy_char_mesh_objs = [o for o in meshy_mesh_objs if o.parent is not None and o.parent.type == "ARMATURE"]
    if not meshy_char_mesh_objs:
        meshy_char_mesh_objs = meshy_mesh_objs
    meshy_artifact_objs = [o for o in meshy_mesh_objs if o not in meshy_char_mesh_objs]
    if meshy_artifact_objs:
        print(f"Discarding {len(meshy_artifact_objs)} Blender glTF-importer artifact mesh object(s): "
              f"{[o.name for o in meshy_artifact_objs]}")
        for o in meshy_artifact_objs:
            bpy.data.objects.remove(o, do_unlink=True)
    # NOTE: meshy_char_mesh_objs (Meshy's own real, throwaway character
    # mesh) is deliberately KEPT for now -- it carries real, working
    # per-vertex bone weights used as a Data Transfer source below (step
    # 4b) -- and is only discarded right before export, once no longer
    # needed.
    meshy_bbox_min, meshy_bbox_max = _world_bbox(meshy_char_mesh_objs) if meshy_char_mesh_objs else (None, None)

    # --- Step 2: import the Blender-optimized game mesh (no armature). ---
    optimized_imported = _import_glb(optimized_path)
    all_optimized_mesh_objs = [o for o in optimized_imported if o.type == "MESH"]
    if not all_optimized_mesh_objs:
        raise RuntimeError(f"No mesh objects found in optimized input: {optimized_path}")
    reference_armature_objs = [o for o in optimized_imported if o.type == "ARMATURE"]

    # Same Blender glTF-importer artifact heuristic used by
    # decimate_for_meshy.py and by this file's own Meshy-anim import above:
    # when the optimized input embeds a reference armature (see PREFERRED
    # PATH below), Blender's glTF importer has been observed to additionally
    # create a stray, UNPARENTED "Icosphere" mesh object alongside the real,
    # armature-parented mesh/item objects. Left in, this bogus unit-sphere
    # object still has no matching vertex groups, so it falls through to the
    # Data Transfer/ARMATURE_AUTO fallback below and gets shipped in the
    # final exported .glb as an extra, garbled, animated blob overlapping the
    # real character -- this was confirmed via a real end-to-end run
    # (bard_scout_dagger_neutral -anim idle) to be the actual cause of the
    # twisted/warped-looking rendered sprites, NOT a bind-pose or weighting
    # bug in the real mesh. Filter it out here exactly like the other two
    # call sites already do.
    if reference_armature_objs:
        optimized_mesh_objs = [o for o in all_optimized_mesh_objs if o.parent is not None and o.parent.type == "ARMATURE"]
        artifact_objs = [o for o in all_optimized_mesh_objs if o not in optimized_mesh_objs]
        if artifact_objs:
            print(f"Discarding {len(artifact_objs)} Blender glTF-importer artifact mesh object(s) from --optimized "
                  f"input (likely a Blender glTF-importer artifact, not real mesh data): "
                  f"{[o.name for o in artifact_objs]}")
            import bpy
            for o in artifact_objs:
                bpy.data.objects.remove(o, do_unlink=True)
        if not optimized_mesh_objs:
            raise RuntimeError(
                f"No armature-parented mesh objects found in optimized input after filtering artifacts: "
                f"{optimized_path}")
    else:
        optimized_mesh_objs = all_optimized_mesh_objs

    if reference_armature_objs:
        # PREFERRED PATH (see _retarget_action_onto_reference_armature's
        # docstring for the full bind-pose-drift bug this avoids): the
        # optimized mesh already carries its OWN stable reference armature
        # (embedded once by rig_base_models.py / decimate_for_meshy.py and
        # never regenerated since), whose bone names the mesh's vertex
        # groups actually match. Never re-parent the mesh onto Meshy's own
        # freshly-returned armature (a different, non-reproducible bind
        # pose every call) -- instead retarget Meshy's animation data onto
        # this stable armature, then discard Meshy's armature entirely.
        if len(reference_armature_objs) > 1:
            print(f"WARNING: {len(reference_armature_objs)} armatures found in --optimized input; using the "
                  f"first one ({reference_armature_objs[0].name}).", file=sys.stderr)
        armature_obj = reference_armature_objs[0]
        _retarget_action_onto_reference_armature(armature_obj, meshy_armature_obj, meshy_action)
        bpy.data.objects.remove(meshy_armature_obj, do_unlink=True)
        # The optimized mesh's own mesh objects are already parented to
        # armature_obj (that's how it carries matching vertex groups in the
        # first place) with a working Armature modifier -- nothing further
        # to bind for them; only items that DON'T already carry matching
        # vertex groups (handled generically below) need any extra work.
    else:
        # FALLBACK: no embedded reference armature in --optimized input
        # (e.g. a standalone item never routed through rig_base_models.py) --
        # fall back to the previous behavior of using Meshy's own armature
        # directly, keeping its own (freshly-returned, but here the ONLY
        # option) bind pose as the shipped rest pose.
        armature_obj = meshy_armature_obj

    bone_names = {b.name for b in armature_obj.data.bones}

    if reference_armature_objs:
        # armature_obj here is the optimized mesh's OWN embedded reference
        # armature -- both were imported together from the same file and
        # already occupy the same coordinate space, so no alignment is
        # needed (or wanted: _align_to_meshy_space would just move the mesh
        # away from its own already-correct armature).
        print("Optimized mesh already carries its own reference armature -- skipping coordinate-space alignment.")
    elif meshy_bbox_min is not None:
        # Align the optimized mesh into the SAME coordinate space Meshy's
        # own (now-discarded) rigged mesh occupied, so the armature's
        # bind-pose bones actually overlap the mesh geometry -- required
        # for automatic weights to succeed and for existing vertex-group
        # weights to still make sense against these bones. See
        # _align_to_meshy_space's docstring for the real failure mode this
        # fixes. Only reachable via the FALLBACK (no embedded reference
        # armature) path above, where armature_obj is Meshy's own armature.
        _align_to_meshy_space(optimized_mesh_objs, meshy_bbox_min, meshy_bbox_max)
    else:
        print("WARNING: could not determine Meshy's mesh bounding box -- skipping coordinate-space alignment "
              "(binding may fail if the optimized mesh isn't already in the same space as the armature).",
              file=sys.stderr)

    for mesh_obj in optimized_mesh_objs:
        vgroup_names = {vg.name for vg in mesh_obj.vertex_groups}
        has_matching_weights = bool(vgroup_names & bone_names)

        # Clear any existing object-level parent, keeping world transform,
        # so the armature-parenting step below starts from a clean slate.
        bpy.ops.object.select_all(action="DESELECT")
        mesh_obj.select_set(True)
        bpy.context.view_layer.objects.active = mesh_obj
        if mesh_obj.parent is not None:
            bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

        if has_matching_weights:
            print(f"{mesh_obj.name}: found {len(vgroup_names & bone_names)} vertex group(s) matching armature "
                  f"bone names -- binding with EXISTING weights (no automatic-weights recompute).")
            # Preserve existing vertex groups: parent under the armature
            # object (OBJECT type, not ARMATURE_AUTO) and add/point an
            # Armature modifier at it manually, since parent_set(type="OBJECT")
            # does not create/adjust an Armature modifier itself.
            bpy.ops.object.select_all(action="DESELECT")
            mesh_obj.select_set(True)
            armature_obj.select_set(True)
            bpy.context.view_layer.objects.active = armature_obj
            bpy.ops.object.parent_set(type="OBJECT", keep_transform=True)

            mod = mesh_obj.modifiers.get("Armature")
            if mod is None:
                mod = mesh_obj.modifiers.new(name="Armature", type="ARMATURE")
            mod.object = armature_obj
        else:
            print(f"{mesh_obj.name}: no matching vertex groups found -- attempting Blender's own automatic "
                  f"bone-heat weighting (ARMATURE_AUTO) against the tail-repaired armature first (see Bug 3b "
                  f"in activeContext.md for why this is now tried before the Data Transfer fallback).")
            # Parent under the armature first (OBJECT type) + add the
            # Armature modifier, same as the has_matching_weights branch,
            # so the mesh is properly bound regardless of which weight
            # source below ends up succeeding.
            bpy.ops.object.select_all(action="DESELECT")
            mesh_obj.select_set(True)
            armature_obj.select_set(True)
            bpy.context.view_layer.objects.active = armature_obj
            bpy.ops.object.parent_set(type="OBJECT", keep_transform=True)

            mod = mesh_obj.modifiers.get("Armature")
            if mod is None:
                mod = mesh_obj.modifiers.new(name="Armature", type="ARMATURE")
            mod.object = armature_obj

            # ATTEMPT 1 (preferred): Blender's own automatic bone-heat
            # weighting solver, now that _repair_armature_bone_tails() has
            # given it sane bone tails to solve against (previously always
            # failed outright with corrupted Meshy tails -- see that
            # function's docstring). Solves per-bone weights directly
            # against the actual optimized mesh geometry, with no
            # dependency on Meshy's own (possibly ambiguous near hip/coat
            # joints -- see Bug 3b) per-vertex weights at all.
            bpy.ops.object.select_all(action="DESELECT")
            mesh_obj.select_set(True)
            armature_obj.select_set(True)
            bpy.context.view_layer.objects.active = armature_obj
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
            auto_ok = _has_real_weights(mesh_obj, bone_names)

            if auto_ok:
                print(f"{mesh_obj.name}: automatic bone-heat weighting succeeded against the tail-repaired "
                      f"armature.")
            else:
                print(f"{mesh_obj.name}: automatic bone-heat weighting produced no real weights -- falling "
                      f"back to Data Transfer of Meshy's own real per-vertex weights (from "
                      f"{[o.name for o in meshy_char_mesh_objs]}).", file=sys.stderr)
                transferred_ok = _transfer_weights_from_meshy_mesh(mesh_obj, meshy_char_mesh_objs, bone_names)
                if transferred_ok:
                    print(f"{mesh_obj.name}: Data Transfer succeeded -- using Meshy's real per-vertex weights.")

            # Both the Data Transfer and ARMATURE_AUTO paths can silently
            # fail to produce any real weight at all (observed this session
            # as a real failure mode for ARMATURE_AUTO when Meshy's own
            # exported armature has corrupted bone-tail positions -- see
            # module docstring's step 4b); the glTF exporter then drops the
            # skin entirely, degrading the exported armature back into
            # plain (non-skinned) empties on the next import, with no other
            # visible error. Detect and fail loudly here instead.
            if not _has_real_weights(mesh_obj, bone_names):
                raise RuntimeError(
                    f"{mesh_obj.name}: neither Data Transfer nor automatic weights (ARMATURE_AUTO) produced any "
                    f"real nonzero vertex weight against {armature_obj.name}'s bones. Refusing to export a mesh "
                    f"with no real skin.")

    # Meshy's own throwaway character mesh (kept until now only as a Data
    # Transfer weight source) is no longer needed -- discard before export.
    print(f"Discarding {len(meshy_char_mesh_objs)} throwaway Meshy character mesh object(s): "
          f"{[o.name for o in meshy_char_mesh_objs]}")
    for o in meshy_char_mesh_objs:
        bpy.data.objects.remove(o, do_unlink=True)

    # --- Restore flat/top-level node structure on export (see ---
    # --- decimate_for_meshy.py's identical rationale/comment). ---
    bpy.ops.object.select_all(action="DESELECT")
    for mesh_obj in optimized_mesh_objs:
        mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = optimized_mesh_objs[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    # NOTE: parent_clear() only clears Blender-level OBJECT parenting -- the
    # Armature MODIFIER's .object reference set above is independent of that
    # and survives untouched, which is what actually drives glTF skin export.

    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_animations=True,
        export_skins=True,
    )
    print(f"Wrote {output_path}")


def main() -> int:
    args = build_arg_parser().parse_args(_blender_argv())
    bind(args.optimized, args.meshy_anim, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
