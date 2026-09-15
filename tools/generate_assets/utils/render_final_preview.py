"""
scripts/render_final_preview.py

One-shot Blender preview render: loads a single .glb (typically one of the
"<clan>_<unit_type>_rigged_final.glb" outputs of attach_hand_item.py's batch
mode) and renders exactly ONE front-facing PNG, using the same fixed
isometric camera/lighting/render settings as the main sprite pipeline
(render_core.py) so the preview looks like a real in-game frame rather than
an ad-hoc Blender default viewport shot.

This is NOT part of the directions x frames batch pipeline (render_cli.py /
render_core.run_job) -- it's a lightweight sanity-check tool for eyeballing
one mesh (e.g. right after attaching a hand item) without setting up a full
RenderJob/SubjectSpec. "Front" defaults to whichever render_config.
DIRECTION_ANGLES entry actually faces the camera for the rig family this
tool has been validated against -- see the NOTE below (currently "e",
which IS the true front view for this rig -- see the NOTE for how that was
confirmed and why an earlier version of this docstring said "se" instead).

Unlike the main sprite pipeline (which is deliberately locked to a fixed
~30 degree isometric camera pitch, shared uniformly across every clan/
dragon/monster/npc sprite -- see render_config.CAMERA_PITCH_DEG), this
standalone preview tool defaults its OWN camera pitch to 0 degrees (straight
-on, eye-level, non-isometric) via PREVIEW_CAMERA_PITCH_DEG below, since its
job is a flat, easy-to-inspect QA shot of one mesh (e.g. confirming a hand
item attached correctly) rather than an in-game sprite frame. This default
is local to this script only -- render_config.py/render_core.py and the main
batch pipeline's isometric pitch are untouched. Pass --camera-pitch-deg to
override per-invocation (e.g. back to the isometric 30 degrees for
side-by-side comparison against real sprite output).

NOTE on the default --direction: render_config.DIRECTION_ANGLES labels "e"
as the 0-degree/"front" azimuth for the main batch pipeline, but that
labelling is only meaningful relative to whatever forward axis a given
imported rig happens to land on after glTF import -- it is not guaranteed
a priori to put the CAMERA in front of the CHARACTER for every rig family,
so this tool re-validates it per rig rather than assuming.

An earlier version of this docstring/default claimed "e" was a
side-profile view and "se" was the true front for bard_scout_
rigged_final.glb, based on eyeballing real character renders under what
turned out to be a BUGGY position_camera_for_direction() (see that
function's own docstring in render_core.py for the full history: two
prior offset-formula attempts introduced a mirror-reflection error that
swapped the ne/se and nw/sw pairs with each other while leaving e/w
looking self-consistent -- which is exactly why e/w were never suspected
and se was wrongly promoted to "front" instead). With that bug fixed
(confirmed via an unambiguous ground-truth diagnostic plus re-inspection
of real bard_scout_anim_idle_final.glb renders across all 6 directions),
"e" is now confirmed to be the genuine full front view for this rig
family, and "se"/"ne" are 3/4 views as their azimuths (60 degrees off
front) would suggest. PREVIEW_DEFAULT_DIRECTION below has been reverted
to "e" accordingly. --direction is still a free CLI override for any mesh
where even this default doesn't hold.

Run inside Blender's own Python interpreter (not plain `python`):

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" ^
        --background --python assets\\graphics\\scripts\\render_final_preview.py -- ^
        --mesh assets\\graphics\\clans\\bard\\scout\\base_mesh\\bard_scout_rigged_final.glb ^
        --out assets\\graphics\\clans\\bard\\scout\\base_mesh\\bard_scout_rigged_final_preview.png

Everything after `--` is this script's own argparse; Blender consumes its
own args before the `--`.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

import bpy  # noqa: E402
import render_core  # noqa: E402
from render_config import RENDER_SIZE_PX  # noqa: E402

# See module docstring: this standalone preview tool intentionally does NOT
# default to render_config.CAMERA_PITCH_DEG (the main pipeline's fixed ~30
# degree isometric pitch) -- 0 degrees gives a flat, straight-on QA shot.
PREVIEW_CAMERA_PITCH_DEG = 0.0

# See module docstring's "NOTE on the default --direction" above: "e" is
# the DIRECTION_ANGLES entry that actually faces the camera for the
# bard_scout rig family this tool has been validated against (re-confirmed
# after fixing position_camera_for_direction()'s mirror-reflection bug --
# the earlier "se" default was a symptom of that bug, not a real rig quirk).
PREVIEW_DEFAULT_DIRECTION = "e"


def _aim_root_for_framing(root_obj):
    """
    Returns the object whose own + mesh-children bounding box should drive
    camera aim/framing, EXCLUDING any attached-item objects (named
    "item_*", see attach_hand_item.py) from that calculation.

    Rationale: attach_hand_item.py's batch mode rigidly skins item meshes
    to a hand joint (proper glTF skinning, sharing the character's own
    skin/inverse-bind-matrices -- see attach_node_to_skin()), so Blender
    imports each item as its own skinned mesh object parented under the
    Armature object (a normal child, not Blender's special "Bone" parent
    type). These are still real, correctly-posed geometry once imported
    (unlike the earlier bone-parented-node approach, which needed
    render_core._fix_bone_parented_item_transforms to avoid ending up many
    meters away) -- excluding "item_*" objects here is purely a framing
    choice: a small handheld prop shouldn't otherwise influence the
    auto-fit camera bounding box/aim point computed from the character's
    own silhouette.
    """
    import bpy

    class _FilteredRoot:
        """Duck-types just enough of bpy.types.Object for render_core's
        _object_world_bbox_corners()/_object_world_bbox_center() (which only
        read .type/.children/.matrix_world) and position_camera_for_direction
        (which also reads .matrix_world.translation)."""

        def __init__(self, real_root):
            self._real = real_root
            self.type = real_root.type
            self.matrix_world = real_root.matrix_world
            self.children = [
                c for c in real_root.children
                if not c.name.startswith("item_")
            ]

    return _FilteredRoot(root_obj)


def _compute_tight_ortho_scale(target, padding_factor: float = 1.15) -> float:
    """
    Auto-fit ortho_scale computed from the imported meshs OWN world-space
    bounding box, instead of the main sprite pipelines deliberately
    generous FIXED_ORTHO_SCALE (render_core.py; 3.0 as of this writing,
    calibrated for worst-case across the WHOLE roster/every animation
    state, so any single subject fills only a fraction of the frame at
    that shared scale -- correct for sprite-sheet consistency, but
    wastes most of the frame for a one-off QA preview of a single
    mesh). Scoped to this standalone preview tool only --
    render_core.FIXED_ORTHO_SCALE and the main batch pipeline are
    untouched.

    padding_factor is a small multiplier (default 1.15, i.e. 15% headroom)
    so the silhouette does not touch the frame edge exactly.
    """
    corners = render_core._object_world_bbox_corners(target)
    if not corners:
        return render_core.FIXED_ORTHO_SCALE

    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    width = max(xs) - min(xs)
    depth = max(ys) - min(ys)
    height = max(zs) - min(zs)
    # Orthographic frame extent needs to cover the largest dimension the
    # subject could present from any orbit angle -- use the horizontal
    # diagonal (width/depth) as a conservative stand-in for that, and the
    # actual height, then take whichever is larger (a tall character vs.
    # a wide one).
    horizontal_extent = (width ** 2 + depth ** 2) ** 0.5
    largest = max(horizontal_extent, height)
    return max(largest * padding_factor, 0.1)


def _blender_argv() -> list[str]:
    argv = sys.argv
    if "--" in argv:
        return argv[argv.index("--") + 1:]
    return []


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Render a single front-view preview PNG of one .glb mesh."
    )
    p.add_argument("--mesh", required=True, type=Path, help="Path to the .glb to render.")
    p.add_argument("--out", required=True, type=Path, help="Output PNG path.")
    p.add_argument("--direction", default=PREVIEW_DEFAULT_DIRECTION, choices=list(render_core.DIRECTION_ANGLES.keys()),
                    help=f"Which fixed-pipeline direction to use as 'front' (default: {PREVIEW_DEFAULT_DIRECTION!r} "
                         "-- see module docstring's NOTE on the default --direction for why this isn't 'e').")
    p.add_argument("--render-size", type=int, default=RENDER_SIZE_PX,
                    help=f"Square render resolution in pixels (default: {RENDER_SIZE_PX}).")
    p.add_argument("--camera-pitch-deg", type=float, default=PREVIEW_CAMERA_PITCH_DEG,
                    help=f"Camera pitch in degrees (default: {PREVIEW_CAMERA_PITCH_DEG}, "
                         "straight-on/non-isometric -- pass 30 to match the main "
                         "sprite pipeline's isometric pitch instead).")
    p.add_argument("--ortho-scale", type=float, default=None,
                    help="Explicit ortho_scale override -- default (None) auto-fits tightly "
                         "to this mesh's own bounding box (see _compute_tight_ortho_scale), "
                         "instead of the main pipeline's generous FIXED_ORTHO_SCALE.")
    p.add_argument("--frame-fraction", type=float, default=0.0,
                    help="Where in the mesh's own animation clip to sample this preview from, "
                         "as a 0.0-1.0 fraction of the active action's frame_range (default: "
                         "0.0 -- the clip's first/rest-pose frame, matching this tool's original "
                         "always-rest-pose behavior). Pass e.g. 0.35 to inspect a mid-animation "
                         "pose (e.g. a lunge/kick mid-attack) instead, using the exact same "
                         "frame_start + fraction * span mapping render_core.run_job() uses for "
                         "the real batch-rendered sprite frames. A no-op if the imported root has "
                         "no animation_data.action (e.g. a static/non-animated mesh).")
    return p


def main() -> None:
    args = build_arg_parser().parse_args(_blender_argv())

    mesh_path = args.mesh.resolve()
    if not mesh_path.is_file():
        print(f"ERROR: mesh not found: {mesh_path}", file=sys.stderr)
        sys.exit(1)

    render_core.reset_scene()
    root_obj = render_core.import_mesh(mesh_path)
    framing_root = _aim_root_for_framing(root_obj)
    ortho_scale = args.ortho_scale if args.ortho_scale is not None else _compute_tight_ortho_scale(framing_root)
    cam_obj = render_core.setup_camera(args.camera_pitch_deg, framing_root, ortho_scale=ortho_scale)
    render_core.setup_world_ambient_lighting()
    render_core.setup_render_settings(args.render_size)
    render_core.setup_solid_black_background()

    # Sample the requested point in the clip BEFORE the final camera
    # orbit/aim, mirroring render_core.run_job()'s own per-frame ordering
    # (frame_set first, then re-aim) -- see that function's own comment on
    # why re-aiming after frame_set matters for clips with root motion.
    if args.frame_fraction and root_obj.animation_data and root_obj.animation_data.action:
        action = root_obj.animation_data.action
        frame_start, frame_end = action.frame_range
        span = max(frame_end - frame_start, 1)
        bpy.context.scene.frame_set(int(round(frame_start + args.frame_fraction * span)))

    render_core.position_camera_for_direction(cam_obj, framing_root, args.camera_pitch_deg, args.direction)

    out_path = args.out.resolve()
    render_core.render_frame(out_path)
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
