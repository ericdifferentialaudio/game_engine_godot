"""
scripts/decimate_for_meshy.py

Reduces a .glb mesh down to a target triangle budget via Blender's Decimate
modifier. Handles TWO kinds of input:
    1. A merged character+item .glb (attach_hand_item.py batch's own
       "<model_name>_final.glb" output) -- a single skinned mesh, parented
       under an Armature. Used to keep Meshy's programmatic Rigging API
       from silently falling back to an emergency low-poly proxy mesh (see
       WHY THIS EXISTS below).
    2. A plain standalone item .glb (clans/<clan>/_items/*.glb) -- a single
       UNSKINNED mesh with no armature at all. Used by
       scripts/decimate_items.py to shrink oversized source item meshes
       (some real ones observed as high as ~3M triangles) both so Meshy
       doesn't choke on them once attached to a character, AND to keep
       this repo's own committed .glb file sizes reasonable.
Which case applies is auto-detected per-file (presence/absence of an
ARMATURE object after import) -- no separate flag needed.

WHY THIS EXISTS: a real end-to-end test (see scripts/README.md's
meshy_animate.py section / session log) confirmed POST /openapi/v1/rigging
auto-decimates any "dense" uploaded mesh down to a tiny fixed budget
(~242 triangles observed against a ~218k-triangle merged character+dagger
mesh) AND drops any secondary mesh (e.g. an attached item) entirely,
regardless of animation --mode (prime/swift produced byte-identical
topology) -- this happens at the RIGGING step itself, confirmed by
inspecting the rig task's own rigged_character_glb_url before any
animation is applied. There is no request parameter on the Rigging API to
disable this (confirmed against the published OpenAPI spec's
RiggingRequest schema: model_url/input_task_id/texture_image_url/name/
animation_type/height_meters only -- nothing about topology/decimation).
The fix has to happen BEFORE upload, locally.

This script runs INSIDE Blender's own Python interpreter (needs `bpy`),
following the same headless-invocation pattern as render_final_preview.py:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" ^
        --background --python scripts\\decimate_for_meshy.py -- ^
        --input clans\\bard\\scout\\base_mesh\\_models\\bard_scout_dagger_raised_final.glb ^
        --output clans\\bard\\scout\\base_mesh\\_models\\bard_scout_dagger_raised_final_meshy.glb ^
        --target-triangles 30000

Everything after `--` is this script's own argparse; Blender consumes its
own args before the `--`.

WHAT IT DOES:
    1. Imports the input .glb (a single skinned mesh + armature, per
       attach_hand_item.py's merge_item_into_character_mesh() -- character
       and any attached item are already ONE mesh/material/UV atlas by the
       time this script ever sees the file, so there is nothing left to
       join here, unlike a from-scratch Blender workflow).
    2. If the mesh's current triangle count is already <= --target-triangles,
       exports it unchanged (no-op, still writes --output for a consistent
       pipeline contract).
    3. Otherwise adds a DECIMATE modifier (COLLAPSE type, ratio =
       target/current) and applies it. Collapse decimation preserves vertex
       groups (bone weights) reasonably well for moderate ratios, which is
       what actually matters here (Meshy re-rigs from scratch against the
       decimated mesh anyway -- OUR skinning on this particular file is
       only used so Blender's Decimate modifier has vertex groups to drag
       along; it is not sent anywhere as the final skin).
    4. Exports the result as GLB, preserving the merged mesh/material
       structure validate_glb.py's Meshy-merge-compliance check expects
       (exactly one mesh-bearing node, one material) -- Decimate does not
       add nodes/materials, so this holds automatically.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

DEFAULT_TARGET_TRIANGLES = 30000


def _blender_argv() -> list[str]:
    argv = sys.argv
    if "--" in argv:
        return argv[argv.index("--") + 1:]
    return []


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--input", required=True, type=Path, help="Path to the merged .glb to decimate.")
    p.add_argument("--output", required=True, type=Path, help="Path to write the decimated .glb to.")
    p.add_argument("--target-triangles", type=int, default=DEFAULT_TARGET_TRIANGLES,
                    help=f"Triangle budget to decimate down to if the input exceeds it (default: {DEFAULT_TARGET_TRIANGLES}).")
    return p


def _count_triangles(mesh_obj) -> int:
    """Triangle count of mesh_obj's CURRENT (evaluated/modifier-applied)
    mesh data, so this is accurate even if called again after a prior
    modifier is already in the stack."""
    import bpy

    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh_eval = mesh_obj.evaluated_get(depsgraph).data
    # A polygon with N vertices contributes N-2 triangles once triangulated
    # (glTF export always triangulates n-gons/quads) -- summing this gives
    # an exact triangle count without needing to actually triangulate here.
    return sum(max(len(poly.vertices) - 2, 0) for poly in mesh_eval.polygons)


def decimate(input_path: Path, output_path: Path, target_triangles: int) -> None:
    import bpy

    if not input_path.is_file():
        raise FileNotFoundError(f"Input mesh not found: {input_path}")

    # Clear the default scene defensively -- this script is always run as
    # a fresh `blender --background --python ...` process, never reused,
    # but this guards against Blender's default cube/camera/light existing.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(input_path))
    after = set(bpy.context.scene.objects)
    imported = list(after - before)
    if not imported:
        raise RuntimeError(f"glTF import produced no objects: {input_path}")

    # Only consider mesh objects that are either (a) parented under an
    # ARMATURE (real skinned character/item geometry from
    # attach_hand_item.py's own merged "_final.glb" output), or (b) plain
    # unskinned/unparented meshes (a standalone clans/<clan>/_items/*.glb
    # item file, which has no armature at all). Blender's glTF importer
    # has been observed to additionally create a stray, UNPARENTED
    # "Icosphere" mesh object for some skinned inputs specifically
    # (apparently an importer-side artifact of the KHR_materials_specular/
    # KHR_materials_ior extensions attach_hand_item.py's
    # repair_material_lighting_properties() leaves on the character
    # material -- not part of our actual mesh data); that case is only
    # ambiguous with case (b) when the file HAS an armature at all, so we
    # only apply the Icosphere-name heuristic when an armature is present
    # in the imported scene.
    all_mesh_objs = [o for o in imported if o.type == "MESH"]
    has_armature = any(o.type == "ARMATURE" for o in imported)
    if has_armature:
        mesh_objs = [o for o in all_mesh_objs if o.parent is not None and o.parent.type == "ARMATURE"]
        ignored = [o for o in all_mesh_objs if o not in mesh_objs]
        if ignored:
            print(f"NOTE: ignoring {len(ignored)} mesh object(s) not parented under the armature "
                  f"(likely a Blender glTF-importer artifact, not real mesh data): "
                  f"{[o.name for o in ignored]}", file=sys.stderr)
            for o in ignored:
                bpy.data.objects.remove(o, do_unlink=True)
    else:
        # No armature at all in this file (e.g. a standalone item mesh
        # with no skin) -- every imported mesh object is real data.
        mesh_objs = all_mesh_objs
    if not mesh_objs:
        raise RuntimeError(f"glTF import produced no usable mesh objects: {input_path}")

    # Some of attach_hand_item.py's own merged outputs have been observed
    # to reference an item mesh node via its shared skin (skin index) but
    # NOT list that node in the glTF file's own scene.nodes array -- a
    # structural quirk (worth fixing at the source separately) that makes
    # Blender's glTF importer file it under a separate "Orphan Nodes"
    # collection rather than the active view layer, so plain
    # object.select_set()/modifier_apply() calls fail with "not in View
    # Layer". Link any such orphaned mesh object into the active view
    # layer's own scene collection so it can be selected/decimated/
    # exported normally.
    active_collection = bpy.context.view_layer.active_layer_collection.collection
    for mesh_obj in mesh_objs:
        if mesh_obj.name not in bpy.context.view_layer.objects:
            for coll in list(mesh_obj.users_collection):
                coll.objects.unlink(mesh_obj)
            active_collection.objects.link(mesh_obj)
            print(f"NOTE: {mesh_obj.name} was in an orphaned collection (not the active view layer) -- "
                  f"relinked into the scene so it can be processed/exported.", file=sys.stderr)

    for mesh_obj in mesh_objs:
        current_tris = _count_triangles(mesh_obj)
        print(f"{mesh_obj.name}: current triangle count = {current_tris}")

        if current_tris <= target_triangles:
            print(f"{mesh_obj.name}: already within budget ({current_tris} <= {target_triangles}) -- no decimation applied")
            continue

        ratio = target_triangles / current_tris
        print(f"{mesh_obj.name}: decimating with ratio={ratio:.4f} (target={target_triangles})")

        bpy.ops.object.select_all(action="DESELECT")
        mesh_obj.select_set(True)
        bpy.context.view_layer.objects.active = mesh_obj

        mod = mesh_obj.modifiers.new(name="MeshyDecimate", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True

        with bpy.context.temp_override(object=mesh_obj):
            bpy.ops.object.modifier_apply(modifier=mod.name)

        final_tris = _count_triangles(mesh_obj)
        print(f"{mesh_obj.name}: decimated triangle count = {final_tris}")

    # Clear Blender's own OBJECT-level parenting (keeping each mesh's world
    # transform) for every mesh object here, WITHOUT touching their
    # Armature modifier (which is what actually drives glTF skin export).
    # attach_hand_item.py's original merged output always exports item
    # meshes as TOP-LEVEL scene nodes carrying their own 'skin' reference
    # (see validate_glb.py's _check_meshy_merge_compliance, which rejects
    # the old "bone-parented-node" pattern) -- but importing that file into
    # Blender re-parents each mesh object under the Armature object at the
    # Blender level (a normal object-hierarchy parent, separate from the
    # Armature MODIFIER binding), and Blender's own glTF exporter mirrors
    # that Blender-level object parent into the exported node hierarchy,
    # nesting the item node under the Armature node again. Clearing the
    # object parent here (keep_transform=True so nothing visually moves)
    # restores the expected flat/top-level node structure on export.
    if has_armature:
        bpy.ops.object.select_all(action="DESELECT")
        for mesh_obj in mesh_objs:
            mesh_obj.select_set(True)
        if mesh_objs:
            bpy.context.view_layer.objects.active = mesh_objs[0]
            bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=False,
        export_yup=True,
    )
    print(f"Wrote {output_path}")


def main() -> int:
    args = build_arg_parser().parse_args(_blender_argv())
    decimate(args.input, args.output, args.target_triangles)
    return 0


if __name__ == "__main__":
    sys.exit(main())
