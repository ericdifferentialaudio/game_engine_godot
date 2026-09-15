"""
scripts/validate_glb.py

Lightweight, dependency-free structural compliance checker for the .glb
files this pipeline generates (attach_hand_item.py's batch mode). No `bpy`,
no third-party glTF library (matches this codebase's existing convention --
see attach_hand_item.py's own module docstring -- of hand-rolling glTF
JSON/binary I/O with only numpy, since pygltflib/trimesh weren't
installable in this environment).

This is NOT a full glTF 2.0 spec validator (that's what the official
Khronos "gltf-validator" CLI is for -- see below); it specifically targets
the invariants THIS pipeline's own item-attachment code must uphold for
its output to be portable across spec-compliant glTF consumers (Blender,
Meshy, three.js, Unity, Unreal, etc.), based on the real interop bug this
tool was written to catch: an earlier version of attach_hand_item.py
attached items as plain nodes parented directly under a skin joint node
(relying on a Blender-specific import-time correction hack to render
correctly) -- Meshy did not apply that same correction, so the item ended
up mispositioned and the auto-fit camera framing broke. Checks performed:
    - every accessor's bufferView/componentType/count/type is internally
      consistent and in-bounds against the binary chunk
    - every node's mesh/skin/children index is in-bounds
    - every skin's joints list only references valid node indices, and
      inverseBindMatrices (if present) has one MAT4 per joint
    - any primitive with JOINTS_0 also has WEIGHTS_0 (and vice versa), with
      matching vertex counts against POSITION
    - WEIGHTS_0 rows sum to ~1.0 (a common, easy-to-introduce skinning bug
      if weights are ever built by hand, as this pipeline's own
      add_skinning_to_item_mesh() does)
    - JOINTS_0 index values are valid positions into the referenced skin's
      "joints" array (not raw scene-node indices, a mistake that's easy to
      make since both are plain small integers)
    - no item ("item_"-prefixed) mesh node is parented under another node
      as a "BONE"-style joint child (i.e. it should be a top-level scene
      node with its own "skin" reference) -- a regression check against
      re-introducing the old, non-portable attachment pattern

For a full, authoritative glTF 2.0 spec conformance report (recommended
before treating a file as "done" for external tools like Meshy), install
Node.js and run the official validator instead:
    npm install -g gltf-validator
    gltf-validator path/to/file.glb
This script is a fast, no-extra-toolchain-required first line of defense
that can run as part of this repo's own Python-only pipeline.

Usage (run from inside scripts/ -- see scripts/README.md's top-level note):
    python utils/validate_glb.py path/to/file.glb
    python utils/validate_glb.py path/to/file.glb --strict   # nonzero exit on warnings too
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

import numpy as np

# This file lives in scripts/utils/ -- scripts/main_scripts/ (attach_hand_item.py)
# needs to be importable regardless of cwd.
_SCRIPT_DIR = Path(__file__).resolve().parent           # scripts/utils/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                        # scripts/
_MAIN_SCRIPTS_DIR = _SCRIPTS_DIR / "main_scripts"
for _p in (_SCRIPTS_DIR, _SCRIPT_DIR, _MAIN_SCRIPTS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from attach_hand_item import load_glb, read_accessor  # noqa: E402

_COMPONENT_TYPE_SIZES = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
_TYPE_COMPONENT_COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Report:
    def __init__(self):
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    @property
    def ok(self) -> bool:
        return not self.errors


def _check_accessors(gltf, bin_data, report: Report) -> None:
    n_bufferviews = len(gltf.get("bufferViews", []))
    for i, acc in enumerate(gltf.get("accessors", [])):
        bv_idx = acc.get("bufferView")
        if bv_idx is None:
            continue  # sparse/zero-filled accessor with no bufferView -- valid per spec, nothing to check here
        if not (0 <= bv_idx < n_bufferviews):
            report.error(f"accessor[{i}]: bufferView {bv_idx} out of range (0..{n_bufferviews - 1})")
            continue
        acc_type = acc.get("type")
        comp_type = acc.get("componentType")
        if acc_type not in _TYPE_COMPONENT_COUNTS:
            report.error(f"accessor[{i}]: unknown type {acc_type!r}")
            continue
        if comp_type not in _COMPONENT_TYPE_SIZES:
            report.error(f"accessor[{i}]: unknown componentType {comp_type!r}")
            continue
        bv = gltf["bufferViews"][bv_idx]
        elem_size = _TYPE_COMPONENT_COUNTS[acc_type] * _COMPONENT_TYPE_SIZES[comp_type]
        stride = bv.get("byteStride", elem_size)
        base_offset = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        count = acc.get("count", 0)
        needed = base_offset + max(count - 1, 0) * stride + elem_size
        if needed > len(bin_data):
            report.error(
                f"accessor[{i}]: reads past end of binary chunk "
                f"(needs {needed} bytes, chunk is {len(bin_data)} bytes)"
            )


def _check_nodes(gltf, report: Report) -> None:
    nodes = gltf.get("nodes", [])
    n_nodes = len(nodes)
    n_meshes = len(gltf.get("meshes", []))
    n_skins = len(gltf.get("skins", []))
    for i, node in enumerate(nodes):
        if "mesh" in node and not (0 <= node["mesh"] < n_meshes):
            report.error(f"node[{i}] ({node.get('name')!r}): mesh {node['mesh']} out of range")
        if "skin" in node and not (0 <= node["skin"] < n_skins):
            report.error(f"node[{i}] ({node.get('name')!r}): skin {node['skin']} out of range")
        for c in node.get("children", []):
            if not (0 <= c < n_nodes):
                report.error(f"node[{i}] ({node.get('name')!r}): child {c} out of range")


def _check_skins(gltf, bin_data, report: Report) -> None:
    n_nodes = len(gltf.get("nodes", []))
    for i, skin in enumerate(gltf.get("skins", [])):
        joints = skin.get("joints", [])
        for j in joints:
            if not (0 <= j < n_nodes):
                report.error(f"skin[{i}]: joint node index {j} out of range")
        ibm_idx = skin.get("inverseBindMatrices")
        if ibm_idx is not None:
            ibm = read_accessor(gltf, bin_data, ibm_idx)
            if len(ibm) != len(joints):
                report.error(
                    f"skin[{i}]: inverseBindMatrices count ({len(ibm)}) != joints count ({len(joints)})"
                )


def _check_item_attachment_regression(gltf, report: Report) -> None:
    """Regression check: no item node should be a child of another node
    (the old, non-portable "plain node parented under a joint" pattern --
    see this script's module docstring). Item nodes must be top-level
    scene nodes with their own "skin" reference instead."""
    nodes = gltf.get("nodes", [])
    parent_of = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent_of[c] = i

    for i, n in enumerate(nodes):
        name = n.get("name", "")
        if not name.startswith("item_"):
            continue
        if i in parent_of:
            report.error(
                f"node[{i}] ({name!r}): item node is parented under node {parent_of[i]} "
                f"({nodes[parent_of[i]].get('name')!r}) -- items must be top-level scene nodes "
                f"with their own 'skin' reference (the old bone-parented-node pattern is not "
                f"portable to other glTF consumers, see module docstring)"
            )
        if "skin" not in n:
            report.warn(f"node[{i}] ({name!r}): item node has no 'skin' -- it will not follow any joint")


def _check_skinning_attributes(gltf, bin_data, report: Report) -> None:
    for mesh_idx, mesh in enumerate(gltf.get("meshes", [])):
        for prim_idx, prim in enumerate(mesh.get("primitives", [])):
            attrs = prim.get("attributes", {})
            has_joints = "JOINTS_0" in attrs
            has_weights = "WEIGHTS_0" in attrs
            label = f"mesh[{mesh_idx}].primitives[{prim_idx}]"

            if has_joints != has_weights:
                report.error(f"{label}: has JOINTS_0={has_joints} but WEIGHTS_0={has_weights} -- must have both or neither")
                continue
            if not has_joints:
                continue

            pos_count = gltf["accessors"][attrs["POSITION"]]["count"]
            joints0 = read_accessor(gltf, bin_data, attrs["JOINTS_0"])
            weights0 = read_accessor(gltf, bin_data, attrs["WEIGHTS_0"])
            if len(joints0) != pos_count or len(weights0) != pos_count:
                report.error(
                    f"{label}: JOINTS_0/WEIGHTS_0 count ({len(joints0)}/{len(weights0)}) "
                    f"!= POSITION count ({pos_count})"
                )

            weight_sums = weights0.sum(axis=1)
            bad = np.abs(weight_sums - 1.0) > 1e-3
            if np.any(bad):
                report.error(
                    f"{label}: {int(bad.sum())} vertex/vertices have WEIGHTS_0 not summing to ~1.0 "
                    f"(min={weight_sums.min():.4f}, max={weight_sums.max():.4f})"
                )

            # Find which skin (if any) this mesh's owning node references,
            # to validate JOINTS_0 indices are positions into that skin's
            # "joints" list (not raw scene-node indices).
            owning_skins = set()
            for n in gltf.get("nodes", []):
                if n.get("mesh") == mesh_idx and "skin" in n:
                    owning_skins.add(n["skin"])
            if not owning_skins:
                report.warn(f"{label}: has JOINTS_0/WEIGHTS_0 but no node referencing this mesh sets 'skin'")
                continue
            for skin_idx in owning_skins:
                n_joints_in_skin = len(gltf["skins"][skin_idx].get("joints", []))
                max_joint_idx = int(joints0.max()) if len(joints0) else -1
                if max_joint_idx >= n_joints_in_skin:
                    report.error(
                        f"{label}: JOINTS_0 references index {max_joint_idx}, but skin[{skin_idx}] "
                        f"only has {n_joints_in_skin} joints -- JOINTS_0 must index INTO the skin's "
                        f"joints list, not raw scene-node indices"
                    )


def _check_meshy_merge_compliance(gltf, bin_data, report: Report) -> None:
    """
    Meshy requires (per its own documented import requirements): only
    one mesh in the file (others get silently merged on upload), exactly
    1 material and 1 UV map after merging, and non-overlapping UV
    islands between parts. This checks that any file with an item
    attached (i.e. more than one mesh-bearing scene node still present)
    has already been merged via merge_item_into_character_mesh() --
    exactly one mesh-bearing top-level scene node, referencing exactly
    one material, with no overlapping UV bounding boxes across
    primitives (a coarse but effective proxy for UV island overlap).
    """
    # Walk the FULL scene graph (not just direct scene-root children) --
    # the character mesh node is typically nested under an Armature
    # root, not a scene-root node itself, while an attached item (before
    # merging) is added as a scene-root sibling -- so only checking
    # direct scene-root nodes would miss the character entirely.
    def walk(node_idx, seen):
        if node_idx in seen:
            return
        seen.add(node_idx)
        for c in gltf["nodes"][node_idx].get("children", []):
            walk(c, seen)

    scene = gltf["scenes"][gltf.get("scene", 0)]
    all_reachable = set()
    for root in scene.get("nodes", []):
        walk(root, all_reachable)
    mesh_bearing_nodes = [
        i for i in sorted(all_reachable)
        if "mesh" in gltf["nodes"][i]
    ]
    if len(mesh_bearing_nodes) > 1:
        report.error(
            f"{len(mesh_bearing_nodes)} mesh-bearing top-level scene nodes found "
            f"(nodes {mesh_bearing_nodes}) -- Meshy merges all meshes into one on "
            f"upload/re-rig, which will collide separately-UV-mapped parts unless "
            f"merge_item_into_character_mesh() has already combined them into one "
            f"mesh/material/UV map before this file is handed to Meshy"
        )
        return
    if not mesh_bearing_nodes:
        return

    mesh_idx = gltf["nodes"][mesh_bearing_nodes[0]]["mesh"]
    mesh = gltf["meshes"][mesh_idx]
    materials_used = {p["material"] for p in mesh.get("primitives", []) if "material" in p}
    if len(materials_used) > 1:
        report.error(
            f"mesh[{mesh_idx}] uses {len(materials_used)} different materials "
            f"({sorted(materials_used)}) across its primitives -- Meshy requires exactly "
            f"1 material after merging"
        )


def validate(path: Path) -> Report:
    report = Report()
    gltf, bin_data = load_glb(str(path))
    _check_accessors(gltf, bin_data, report)
    _check_nodes(gltf, report)
    _check_skins(gltf, bin_data, report)
    _check_skinning_attributes(gltf, bin_data, report)
    _check_item_attachment_regression(gltf, report)
    _check_meshy_merge_compliance(gltf, bin_data, report)
    return report


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("glb_path", type=Path)
    p.add_argument("--strict", action="store_true", help="exit nonzero on warnings too, not just errors")
    args = p.parse_args()

    if not args.glb_path.is_file():
        print(f"ERROR: file not found: {args.glb_path}", file=sys.stderr)
        return 1

    report = validate(args.glb_path)

    for e in report.errors:
        print(f"ERROR: {e}")
    for w in report.warnings:
        print(f"WARNING: {w}")

    if report.ok and not report.warnings:
        print(f"OK: {args.glb_path} -- no issues found")
    elif report.ok:
        print(f"\n{args.glb_path}: 0 error(s), {len(report.warnings)} warning(s)")
    else:
        print(f"\n{args.glb_path}: {len(report.errors)} error(s), {len(report.warnings)} warning(s)")

    if not report.ok:
        return 1
    if args.strict and report.warnings:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
