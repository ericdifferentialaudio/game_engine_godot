#!/usr/bin/env python3
"""
attach_hand_item.py

Locate the left/right hand joints on a rigged, A-pose humanoid GLB (tested
against Meshy AI's auto-rig output, which follows Mixamo-style joint
naming: LeftHand / RightHand as leaf bones with no separate finger joints),
compute a grip frame at each hand from the actual skinned mesh geometry,
and attach a placeholder item (a simple cylinder "handle" proxy) as a new
child node parented under the hand joint -- so it rides along with any
future animation/re-posing of the character.

No third-party glTF library is used (pygltflib/trimesh weren't
installable in this environment) -- this reads and writes the GLB
container (JSON chunk + BIN chunk) directly per the glTF 2.0 binary spec.
numpy is required for all mesh math; Pillow (PIL) is additionally
required for batch modes texture-atlas compositing (see
merge_item_into_character_mesh()).

MAIN PIPELINE (see scripts/README.md for the full picture): this script's
`batch` command is step 1 of a 3-script pipeline --
    1. attach_hand_item.py batch   -- (this file) auto-decimates any
       oversized source item .glb(s) in scope (via scripts/utils/
       decimate_items.py, --skip-decimate to opt out), merges rig + item(s)
       into clans/<clan>/<unit_type>/base_mesh/_models/<model>_final.glb,
       then auto-validates + auto-previews the result.
    2. meshy_animate.py            -- rigs + animates each _final.glb via
       the Meshy API.
    3. render.py --execute         -- renders the final sprite-sheet PNG
       frames.
Everything else in scripts/utils/ (decimate_items.py, decimate_for_meshy.py,
preview_batch_items.py, validate_glb.py, mesh_discovery.py, render_cli.py,
render_core.py, render_config.py, render_final_preview.py, scaffold_dirs.py,
subjects/) is an internal helper invoked automatically by one of these 3
scripts -- you normally never call anything under utils/ directly.

USAGE
    Placeholder-cylinder mode (original behavior, single file in/out):
        python3 attach_hand_item.py cylinder input.glb output.glb --hand both
        python3 attach_hand_item.py cylinder input.glb output.glb --hand right --radius 0.012 --length 0.14

    Batch mode (real item .glb meshes, driven by an instructions file):
        python3 attach_hand_item.py batch
        python3 attach_hand_item.py batch --instructions model_definitions.txt --dry-run

        Iterate on a single unit/state without editing the instructions
        file or re-processing every line, via --clan/--unit-type/--anim
        (each optional, all combinable; --anim 'none' matches lines with
        no -anim at all):
        python3 attach_hand_item.py batch --clan bard --unit-type scout --anim attack

    Batch mode reads scripts/model_definitions.txt (one line per subject):
        <clan> <unit_type> [-anim <state>] left:<item_name|none> [X:<deg> Y:<deg> Z:<deg>] [TX:<m> TY:<m> TZ:<m>] [S:<m>]
            right:<item_name|none> [X:<deg> Y:<deg> Z:<deg>] [TX:<m> TY:<m> TZ:<m>] [S:<m>] [--flip-left] [--flip-right]
    e.g.
        bard scout right:small_dagger left:none
        bard scout -anim attack right:small_dagger X:0 Y:0 Z:45 TY:0.20 S:-0.05 left:none

    ITEM PRESETS: a line starting with the literal token 'item' (instead
    of a clan name) defines a reusable, named pose for a base item, so
    multiple subject lines can share one set of X:/Y:/Z:/TX:/TY:/TZ:/S:/
    --flip tokens instead of repeating them on every line:
        item <clan> <preset_name> <base_item> [X:<deg> Y:<deg> Z:<deg>]
            [TX:<m> TY:<m> TZ:<m>] [S:<m>] [--flip]
    e.g.
        item bard dagger_down small_dagger X:0 Y:0 Z:45 TY:0.03 S:-0.05
        item bard dagger_raised small_dagger X:0 Y:0 Z:45 TY:0.0 S:-0.0
    A subject line then references <preset_name> in place of a literal
    item filename for any slot:
        bard scout -anim attack right:dagger_down left:none
        bard scout -anim idle right:dagger_raised left:none
    Preset lookup is scoped per-clan (a preset named 'dagger_down' only
    resolves for subject lines with the SAME <clan>) and is tried first
    -- if no preset with that name exists for that clan, the value is
    treated as a literal clans/<clan>/_items/<value>.glb item name
    exactly as before (fully backward compatible). A subject line can
    still override individual fields of a preset by adding its own
    X:/Y:/Z:/TX:/TY:/TZ:/S:/--flip token(s) after the slot reference --
    those are applied on top of (overwriting) the preset's own defaults
    for just that field, e.g. `right:dagger_down Z:90` keeps dagger_down's
    TY:/S: but replaces its Z: rotation. 'item' lines may appear anywhere
    in the file (collected in a first pass before any subject line is
    resolved) and are never treated as subjects themselves.
    Blank lines and lines starting with '#' are ignored. Any X:/Y:/Z: token
    applies to whichever hand ("left:"/"right:") most recently preceded it
    on the line, rotating that item about its own grip-aligned local axes
    (local +Y = the elbow-to-hand "grip" axis the item's long axis is
    aligned to; X/Z are the two axes perpendicular to it) by the given
    number of degrees -- e.g. Y:45 rolls the item 45 degrees around its own
    handle without moving where it points; X:/Z: tilt it off that axis
    (e.g. raising a dagger for an attack pose vs. hanging down for idle).
    Defaults to X:0 Y:0 Z:0 (no rotation) for a hand if omitted.

    TX:/TY:/TZ: tokens (same stateful "current hand" scanning as X:/Y:/Z:)
    set the ROTATION PIVOT POINT (in METERS, same grip-aligned local axes
    as X:/Y:/Z: -- TY along the grip axis, TX/TZ perpendicular to it),
    measured from the item's own detected handle end. This matters because
    the hand JOINT's origin (what the item's handle end is placed at) sits
    at the WRIST, not out at the palm/fingers where a fist actually closes
    around a held item's grip (the hand mesh is a rigid extension of the
    same wrist bone) -- rotating about the wrist (TY:0, the default) swings
    the item's grip end visibly away from the fist as soon as X:/Y:/Z: is
    non-zero, even though it looks fine with no rotation (the item's long
    axis already points straight down the wrist-to-hand vector). Set TY to
    roughly the real-world distance from the wrist to where the fingers
    actually close around the grip (typically a small positive number, a
    few centimeters) so that point -- not the wrist -- stays fixed in
    place when X:/Y:/Z: rotates the item. Defaults to TX:0 TY:0 TZ:0 (pivot
    at the wrist) if omitted, matching the original un-rotated behavior.

    S: (same stateful "current hand" scanning) is a plain SCALAR slide in
    METERS, applied LAST, purely along the item's own grip/blade axis
    (there is only one axis here, unlike TX:/TY:/TZ:'s three, since
    "slide along its own length" is inherently one-dimensional). Unlike
    TX:/TY:/TZ: (which only changes where a rotation pivots, and is a
    no-op with no rotation), S: always moves the item -- use it to push
    the handle further into the fist (negative values, typically) or pull
    it back out (positive), independent of any rotation -- e.g. after
    TY: has correctly pivoted a rotation but the handle still isn't fully
    seated in the grip. Defaults to S:0 (no change) if omitted.

    -anim <state> (optional; e.g. "attack", "walk") targets a specific
    animation state's own source mesh instead of the plain base rig:
        rig  = whichever .glb mesh_discovery.discover_state_meshes() resolves
               for <state> under clans/<clan>/<unit_type>/base_mesh/ (the
               same per-state resolution the render pipeline itself uses --
               see mesh_discovery.py)
        item = clans/<clan>/_items/<item_name>.glb
    and the result is written to
        clans/<clan>/<unit_type>/anim_<state>/<clan>_<unit_type>_anim_<state>_final.glb
    so different animation states can carry differently-posed/rotated items
    (e.g. dagger lowered for "walk", raised for "attack"). The render
    pipeline's subjects/clans.py automatically prefers this file over the
    plain discovered clip for that state, once it exists.

    left:none right:none (both hands empty) with -anim <state> does NOT
    skip the line -- it still resolves that states source mesh and
    writes it through UNCHANGED as that same anim_<state>/..._final.glb
    (a plain copy, since nothing is attached), so every requested
    anim_<state>/ folder always ends up with its own mesh ready to hand
    off to Meshy for animating, even for states with no item attached.
    Without -anim, left:none right:none on a plain line IS still
    skipped (no dedicated anim_<state>/ folder to populate in that case).

    Without -anim, batch mode keeps its original behavior: this resolves
        rig  = clans/<clan>/<unit_type>/base_mesh/<clan>_<unit_type>_rigged.glb
        item = clans/<clan>/_items/<item_name>.glb
    and attaches the item mesh (real geometry/materials/textures, not the
    placeholder cylinder) to that hand, WITHOUT touching the original rig
    .glb -- the result is written to a new sibling file
    "<clan>_<unit_type>_rigged_final.glb" next to it (only the static
    rigged mesh is touched -- animation clips are handled separately,
    later). The item mesh's "handle end" (which end plugs into
    the hand) is auto-detected via PCA long-axis + cross-sectional-thickness
    heuristic (thinner end = handle); pass --flip-left/--flip-right on a
    line to use the other end if the guess is wrong for a given item.

WHAT IT DOES
    1. Parses the GLB container into the JSON scene description + binary buffer.
    2. Builds the world transform of every node via forward kinematics
       (walks each node's parent chain, composing TRS matrices).
    3. Finds the LeftHand / RightHand joint nodes by name (with fallback
       patterns for other common naming conventions).
    4. Reads the mesh's skin weights (JOINTS_0 / WEIGHTS_0) to find which
       vertices are predominantly bound to each hand joint -- this is the
       actual hand geometry, not a guess.
    5. Computes a grip frame per hand:
         - anchor  = centroid of that hand's vertex cluster
         - primary axis (grip/forward) = direction from the joint origin
           to that centroid (i.e. "which way the hand extends")
         - normal axis (palm-perpendicular) = the flattest axis of the
           hand's vertex cluster via PCA, orthogonalized against primary
         - third axis = cross product of the other two
    6. Builds a placeholder cylinder mesh oriented along that frame,
       appends it to the glTF's accessors/bufferViews/meshes, adds a new
       node parented under the hand joint with the correctly-computed
       local transform, and writes out a new valid GLB.

CAVEATS / WHAT WOULD NEED ADJUSTING FOR A DIFFERENT RIG
    - Assumes a single skin, a single skinned mesh primitive using
      JOINTS_0/WEIGHTS_0 (4 influences/vertex) -- the common case, but not
      exhaustive (no JOINTS_1/WEIGHTS_1, no sparse accessors).
    - Joint-name matching covers Mixamo/Meshy-style ("LeftHand"/"RightHand")
      and a few common alternates (hand_l/hand_r, hand.L/hand.R, l_hand/r_hand).
      A wildly different naming scheme would need another pattern added to
      HAND_NAME_PATTERNS below.
    - The palm-normal sign (which way it "faces") is picked heuristically
      (lateral, away from the spine) -- fine for a rotationally-symmetric
      placeholder like a cylinder; worth checking visually once you swap
      in real art with a distinct front/back.
"""

import argparse
import json
import os
import re
import struct
import sys
from pathlib import Path

import numpy as np

# This file lives in scripts/main_scripts/ -- scripts/utils/ (the
# lower-level helper modules -- mesh_discovery.py, render_config.py,
# decimate_items.py, validate_glb.py, preview_batch_items.py, etc., see
# scripts/README.md's "Layout" section) and scripts/main_scripts/ itself
# (meshy_animate.py, render.py) both need to be importable regardless of
# cwd, so `from mesh_discovery import discover_state_meshes` below works
# whether this is run as `python attach_hand_item.py ...` from within
# scripts/main_scripts/ or invoked with a full path from elsewhere.
_SCRIPT_DIR = Path(__file__).resolve().parent            # scripts/main_scripts/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                         # scripts/
_UTILS_DIR = _SCRIPTS_DIR / "utils"
for _p in (_SCRIPT_DIR, _SCRIPTS_DIR, _UTILS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from mesh_discovery import discover_state_meshes  # noqa: E402

GLB_MAGIC = b"glTF"
CHUNK_TYPE_JSON = 0x4E4F534A
CHUNK_TYPE_BIN = 0x004E4942

COMPONENT_FORMATS = {
    5120: ("b", 1),  # BYTE
    5121: ("B", 1),  # UNSIGNED_BYTE
    5122: ("h", 2),  # SHORT
    5123: ("H", 2),  # UNSIGNED_SHORT
    5125: ("I", 4),  # UNSIGNED_INT
    5126: ("f", 4),  # FLOAT
}
TYPE_COMPONENT_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

HAND_NAME_PATTERNS = [
    # (regex for "this node is a hand joint", regex to decide left vs right)
    re.compile(r"hand", re.IGNORECASE),
]
FINGER_EXCLUDE = re.compile(r"(finger|thumb|index|middle|ring|pinky)", re.IGNORECASE)
LEFT_PATTERNS = [re.compile(r"left", re.IGNORECASE), re.compile(r"(^|[_.\s])l($|[_.\s])", re.IGNORECASE)]
RIGHT_PATTERNS = [re.compile(r"right", re.IGNORECASE), re.compile(r"(^|[_.\s])r($|[_.\s])", re.IGNORECASE)]


# --------------------------------------------------------------------------
# GLB read/write
# --------------------------------------------------------------------------

def load_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != GLB_MAGIC:
        raise ValueError(f"{path} is not a valid GLB (bad magic)")
    offset = 12
    gltf_json = None
    bin_data = b""
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk_data = data[offset : offset + chunk_len]
        if chunk_type == CHUNK_TYPE_JSON:
            gltf_json = json.loads(chunk_data.decode("utf-8"))
        elif chunk_type == CHUNK_TYPE_BIN:
            bin_data = chunk_data
        offset += chunk_len
    if gltf_json is None:
        raise ValueError(f"{path} has no JSON chunk")
    return gltf_json, bytearray(bin_data)


def save_glb(path, gltf_json, bin_data):
    json_bytes = json.dumps(gltf_json, separators=(",", ":")).encode("utf-8")
    # pad JSON chunk to 4-byte boundary with spaces (per spec)
    pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b" " * pad

    bin_bytes = bytes(bin_data)
    pad = (4 - len(bin_bytes) % 4) % 4
    bin_bytes += b"\x00" * pad

    total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", GLB_MAGIC, 2, total_len))
        f.write(struct.pack("<II", len(json_bytes), CHUNK_TYPE_JSON))
        f.write(json_bytes)
        f.write(struct.pack("<II", len(bin_bytes), CHUNK_TYPE_BIN))
        f.write(bin_bytes)


# --------------------------------------------------------------------------
# Accessor read helper
# --------------------------------------------------------------------------

def read_accessor(gltf, bin_data, accessor_idx):
    a = gltf["accessors"][accessor_idx]
    bv = gltf["bufferViews"][a["bufferView"]]
    n = TYPE_COMPONENT_COUNT[a["type"]]
    fmt_char, comp_size = COMPONENT_FORMATS[a["componentType"]]
    fmt = "<" + fmt_char * n
    elem_size = comp_size * n
    stride = bv.get("byteStride", elem_size)
    base_offset = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    count = a["count"]
    out = np.zeros((count, n))
    for i in range(count):
        o = base_offset + i * stride
        out[i] = struct.unpack_from(fmt, bin_data, o)
    return out


# --------------------------------------------------------------------------
# Node hierarchy / forward kinematics
# --------------------------------------------------------------------------

def quat_to_mat3(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def mat3_to_quat(R):
    # standard matrix->quaternion (Shepperd's method)
    m = R
    tr = m[0, 0] + m[1, 1] + m[2, 2]
    if tr > 0:
        S = np.sqrt(tr + 1.0) * 2
        w = 0.25 * S
        x = (m[2, 1] - m[1, 2]) / S
        y = (m[0, 2] - m[2, 0]) / S
        z = (m[1, 0] - m[0, 1]) / S
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        S = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w = (m[2, 1] - m[1, 2]) / S
        x = 0.25 * S
        y = (m[0, 1] + m[1, 0]) / S
        z = (m[0, 2] + m[2, 0]) / S
    elif m[1, 1] > m[2, 2]:
        S = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w = (m[0, 2] - m[2, 0]) / S
        x = (m[0, 1] + m[1, 0]) / S
        y = 0.25 * S
        z = (m[1, 2] + m[2, 1]) / S
    else:
        S = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w = (m[1, 0] - m[0, 1]) / S
        x = (m[0, 2] + m[2, 0]) / S
        y = (m[1, 2] + m[2, 1]) / S
        z = 0.25 * S
    return [x, y, z, w]


def node_local_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"]).reshape(4, 4).T
    t = np.array(node.get("translation", [0, 0, 0]), dtype=float)
    r = node.get("rotation", [0, 0, 0, 1])
    s = np.array(node.get("scale", [1, 1, 1]), dtype=float)
    M = np.eye(4)
    M[:3, :3] = quat_to_mat3(r) @ np.diag(s)
    M[:3, 3] = t
    return M


def build_parent_map(nodes):
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    return parent


def compute_world_matrices(nodes):
    parent = build_parent_map(nodes)
    cache = {}

    def world(idx):
        if idx in cache:
            return cache[idx]
        M = node_local_matrix(nodes[idx])
        if idx in parent:
            M = world(parent[idx]) @ M
        cache[idx] = M
        return M

    return {i: world(i) for i in range(len(nodes))}, parent


# --------------------------------------------------------------------------
# Hand joint discovery
# --------------------------------------------------------------------------

def find_hand_joints(nodes):
    """Returns {'left': node_idx_or_None, 'right': node_idx_or_None}."""
    candidates = {"left": [], "right": []}
    for i, n in enumerate(nodes):
        name = n.get("name", "")
        if not name or FINGER_EXCLUDE.search(name):
            continue
        if not any(p.search(name) for p in HAND_NAME_PATTERNS):
            continue
        if any(p.search(name) for p in LEFT_PATTERNS):
            candidates["left"].append(i)
        elif any(p.search(name) for p in RIGHT_PATTERNS):
            candidates["right"].append(i)

    result = {}
    for side in ("left", "right"):
        opts = candidates[side]
        if not opts:
            result[side] = None
        else:
            # Prefer a leaf-ish joint (no children) -- that's the actual
            # hand/wrist end effector rather than an ancestor.
            leafy = [i for i in opts if not nodes[i].get("children")]
            result[side] = leafy[0] if leafy else opts[0]
    return result


NECK_NAME_PATTERNS = [re.compile(r"neck", re.IGNORECASE)]
HEAD_NAME_PATTERNS = [re.compile(r"^head$|head_end|headtop|head_top", re.IGNORECASE)]
SPINE_NAME_PATTERNS = [re.compile(r"spine", re.IGNORECASE)]


def find_named_joint(nodes, patterns, prefer_leaf=False, prefer_highest_suffix=False):
    """
    Generic joint-name lookup, generalizing find_hand_joints() for
    single (non-left/right) attachment points like neck/head/spine.
    Returns the matching node index, or None.

    prefer_leaf: among matches, prefer one with no children (e.g. a
    head_end leaf marker over the Head bone that has children).
    prefer_highest_suffix: among matches (e.g. Spine, Spine01, Spine02),
    prefer the one with the highest trailing number -- the TOPMOST spine
    segment closest to the neck, which is what back mounts should anchor to.
    """
    matches = [
        i for i, n in enumerate(nodes)
        if n.get("name") and any(p.search(n["name"]) for p in patterns)
    ]
    if not matches:
        return None
    if prefer_highest_suffix:
        def suffix_num(i):
            m = re.search(r"(\d+)$", nodes[i].get("name", ""))
            return int(m.group(1)) if m else -1
        matches.sort(key=suffix_num, reverse=True)
        return matches[0]
    if prefer_leaf:
        leafy = [i for i in matches if not nodes[i].get("children")]
        if leafy:
            return leafy[0]
    return matches[0]


# --------------------------------------------------------------------------
# Skin-weight based hand vertex selection
# --------------------------------------------------------------------------

def get_skinned_mesh_data(gltf, bin_data):
    """Returns (positions, joints0, weights0, skin_joint_node_indices) for
    the first mesh primitive that has a skin. Raises if none found."""
    skins = gltf.get("skins", [])
    if not skins:
        raise ValueError("No skin found in this GLB -- character isn't rigged.")
    skin = skins[0]
    skin_joints = skin["joints"]

    for node in gltf["nodes"]:
        if "mesh" in node and "skin" in node:
            mesh = gltf["meshes"][node["mesh"]]
            prim = mesh["primitives"][0]
            attrs = prim["attributes"]
            positions = read_accessor(gltf, bin_data, attrs["POSITION"])
            joints0 = read_accessor(gltf, bin_data, attrs["JOINTS_0"]).astype(int)
            weights0 = read_accessor(gltf, bin_data, attrs["WEIGHTS_0"])
            return positions, joints0, weights0, skin_joints, node["mesh"]
    raise ValueError("No skinned mesh primitive found.")


def hand_vertex_cluster(positions, joints0, weights0, skin_joints, hand_node_idx, weight_threshold=0.5):
    skin_joint_idx = skin_joints.index(hand_node_idx)
    match = joints0 == skin_joint_idx
    total_weight = (weights0 * match).sum(axis=1)
    mask = total_weight > weight_threshold
    if mask.sum() < 8:
        # fall back to a looser threshold if the rig blends weights more broadly
        mask = total_weight > 0.15
    return positions[mask]


def compute_forward_axis(positions, normals):
    """
    Estimates the characters own forward-facing WORLD axis (unit vector)
    from the average surface normal of torso-center vertices (a narrow
    band around the chest/neck height and world X~0, i.e. the front/back
    of the torso rather than a side/limb) -- this rig family bakes bind-
    pose joint ROTATIONS as near-identity (no usable facing direction
    there), so the actual mesh geometry is the only reliable source for
    which way the character faces. Used to place back-mounted items
    (opposite this axis) and to validate up/forward assumptions.
    Falls back to world +Z if the torso-band mask is empty (degenerate
    mesh) -- +Z is this rig familys confirmed forward axis.
    """
    y_min, y_max = np.percentile(positions[:, 1], [55, 85])
    mask = (positions[:, 1] > y_min) & (positions[:, 1] < y_max) & (np.abs(positions[:, 0]) < 0.15)
    if mask.sum() < 8:
        return np.array([0.0, 0.0, 1.0])
    avg_normal = normals[mask].mean(axis=0)
    avg_normal[1] = 0.0  # keep forward strictly horizontal
    norm = np.linalg.norm(avg_normal)
    if norm < 1e-6:
        return np.array([0.0, 0.0, 1.0])
    return avg_normal / norm


def compute_mount_frame(anchor, primary):
    """
    Builds an orthonormal grip-like frame for a FIXED-MOUNT attachment
    point (back/head -- no grip-vertex-cluster/PCA available like a hand
    has, since these arent skinned regions with their own geometry to
    analyze). anchor = world-space attach point, primary = world-space
    unit direction the items own local +Y (grip/long axis, same
    convention fit_item_to_grip() uses) should point along.
    Returns (anchor, primary, flat_axis, third) in the same shape
    compute_grip_frame()/compute_hand_local_trs() expect, so the exact
    same downstream attach/merge machinery works unmodified.
    """
    primary = primary / np.linalg.norm(primary)
    world_up = np.array([0.0, 1.0, 0.0])
    third = np.cross(world_up, primary)
    if np.linalg.norm(third) < 1e-6:
        third = np.cross(np.array([1.0, 0.0, 0.0]), primary)
    third = third / np.linalg.norm(third)
    flat_axis = np.cross(third, primary)
    flat_axis = flat_axis / np.linalg.norm(flat_axis)
    return anchor, primary, flat_axis, third


def compute_grip_frame(joint_world_pos, hand_points):
    centroid = hand_points.mean(axis=0)
    primary = centroid - joint_world_pos
    if np.linalg.norm(primary) < 1e-6:
        primary = np.array([0.0, 1.0, 0.0])
    primary = primary / np.linalg.norm(primary)

    centered = hand_points - centroid
    cov = np.cov(centered.T)
    eigvals, eigvecs = np.linalg.eigh(cov)  # ascending eigenvalue order
    flat_axis = eigvecs[:, 0]  # smallest-variance axis ~ palm normal

    # orthogonalize against primary (Gram-Schmidt)
    flat_axis = flat_axis - np.dot(flat_axis, primary) * primary
    if np.linalg.norm(flat_axis) < 1e-6:
        # degenerate (primary happened to equal PCA normal); pick any
        # perpendicular vector
        flat_axis = np.cross(primary, np.array([1.0, 0.0, 0.0]))
        if np.linalg.norm(flat_axis) < 1e-6:
            flat_axis = np.cross(primary, np.array([0.0, 0.0, 1.0]))
    flat_axis = flat_axis / np.linalg.norm(flat_axis)

    third = np.cross(primary, flat_axis)
    third = third / np.linalg.norm(third)
    # recompute flat_axis to guarantee a clean right-handed orthonormal set
    flat_axis = np.cross(third, primary)
    flat_axis = flat_axis / np.linalg.norm(flat_axis)

    return centroid, primary, flat_axis, third


def fix_lateral_sign(axis, side, joint_world_pos):
    """Point 'axis' away from the body midline (world X=0) so a
    non-symmetric item (once you swap in real art) faces outward by
    default rather than at random. Harmless for a symmetric placeholder."""
    body_relative_x = joint_world_pos[0]  # left hand: +X, right hand: -X (Meshy/Mixamo convention)
    want_sign = 1.0 if body_relative_x >= 0 else -1.0
    if np.dot(axis, np.array([1.0, 0.0, 0.0])) * want_sign < 0:
        axis = -axis
    return axis


# --------------------------------------------------------------------------
# Placeholder item geometry (a simple cylinder "handle" proxy)
# --------------------------------------------------------------------------

def make_cylinder(radius, length, segments=12):
    """Cylinder centered at origin, long axis along local +Y.
    Returns (positions[N,3], normals[N,3], indices[M])."""
    positions = []
    normals = []
    half = length / 2.0

    # side wall
    for i in range(segments):
        theta = 2 * np.pi * i / segments
        x, z = radius * np.cos(theta), radius * np.sin(theta)
        n = np.array([np.cos(theta), 0.0, np.sin(theta)])
        positions.append([x, -half, z])
        normals.append(n)
        positions.append([x, half, z])
        normals.append(n)

    indices = []
    for i in range(segments):
        i0 = 2 * i
        i1 = 2 * i + 1
        i2 = 2 * ((i + 1) % segments)
        i3 = 2 * ((i + 1) % segments) + 1
        indices += [i0, i2, i1, i2, i3, i1]

    # simple flat end caps
    base_bottom = len(positions)
    positions.append([0, -half, 0])
    normals.append([0, -1, 0])
    base_top = len(positions)
    positions.append([0, half, 0])
    normals.append([0, 1, 0])

    ring_bottom_start = 0
    ring_top_start = 1
    for i in range(segments):
        a = ring_bottom_start + 2 * i
        b = ring_bottom_start + 2 * ((i + 1) % segments)
        indices += [base_bottom, b, a]
        a2 = ring_top_start + 2 * i
        b2 = ring_top_start + 2 * ((i + 1) % segments)
        indices += [base_top, a2, b2]

    return np.array(positions, dtype=np.float32), np.array(normals, dtype=np.float32), np.array(indices, dtype=np.uint16)


# --------------------------------------------------------------------------
# Appending new buffer data / accessors / mesh / node into the glTF
# --------------------------------------------------------------------------

def append_buffer_view(gltf, bin_data, raw_bytes, target=None):
    # 4-byte align the start of this bufferView
    pad = (4 - len(bin_data) % 4) % 4
    bin_data.extend(b"\x00" * pad)
    offset = len(bin_data)
    bin_data.extend(raw_bytes)
    bv = {"buffer": 0, "byteOffset": offset, "byteLength": len(raw_bytes)}
    if target is not None:
        bv["target"] = target
    gltf["bufferViews"].append(bv)
    return len(gltf["bufferViews"]) - 1


def add_item_mesh(gltf, bin_data, positions, normals, indices, color_rgba=(0.55, 0.35, 0.15, 1.0)):
    pos_bytes = positions.astype("<f4").tobytes()
    norm_bytes = normals.astype("<f4").tobytes()
    idx_bytes = indices.astype("<u2").tobytes()

    pos_bv = append_buffer_view(gltf, bin_data, pos_bytes, target=34962)
    norm_bv = append_buffer_view(gltf, bin_data, norm_bytes, target=34962)
    idx_bv = append_buffer_view(gltf, bin_data, idx_bytes, target=34963)

    pos_accessor = {
        "bufferView": pos_bv,
        "componentType": 5126,
        "count": len(positions),
        "type": "VEC3",
        "min": positions.min(axis=0).tolist(),
        "max": positions.max(axis=0).tolist(),
    }
    norm_accessor = {"bufferView": norm_bv, "componentType": 5126, "count": len(normals), "type": "VEC3"}
    idx_accessor = {"bufferView": idx_bv, "componentType": 5123, "count": len(indices), "type": "SCALAR"}

    gltf["accessors"].append(pos_accessor)
    pos_idx = len(gltf["accessors"]) - 1
    gltf["accessors"].append(norm_accessor)
    norm_idx = len(gltf["accessors"]) - 1
    gltf["accessors"].append(idx_accessor)
    idx_idx = len(gltf["accessors"]) - 1

    material = {
        "name": "item_placeholder",
        "pbrMetallicRoughness": {
            "baseColorFactor": list(color_rgba),
            "metallicFactor": 0.2,
            "roughnessFactor": 0.6,
        },
    }
    gltf.setdefault("materials", []).append(material)
    mat_idx = len(gltf["materials"]) - 1

    mesh = {
        "name": "item_placeholder_mesh",
        "primitives": [
            {
                "attributes": {"POSITION": pos_idx, "NORMAL": norm_idx},
                "indices": idx_idx,
                "material": mat_idx,
            }
        ],
    }
    gltf["meshes"].append(mesh)
    return len(gltf["meshes"]) - 1


def compute_hand_local_trs(world_matrices, hand_node_idx, anchor, primary, flat_axis, third):
    """Given a grip frame (world-space), returns (translation, rotation_quat,
    scale) of that frame expressed in the hand joint's local space -- i.e.
    the TRS to give a new child node of the hand joint so it lands exactly
    on the grip frame."""
    R = np.column_stack([third, primary, flat_axis])  # local X=third(lateral), Y=primary(grip), Z=flat_axis(normal)
    desired_world = np.eye(4)
    desired_world[:3, :3] = R
    desired_world[:3, 3] = anchor

    hand_world = world_matrices[hand_node_idx]
    local = np.linalg.inv(hand_world) @ desired_world

    local_translation = local[:3, 3].tolist()
    local_rot_mat = local[:3, :3]
    # remove any residual scale before quaternion conversion
    scale = np.linalg.norm(local_rot_mat, axis=0)
    local_rot_mat = local_rot_mat / scale
    local_rotation = mat3_to_quat(local_rot_mat)
    local_scale = scale.tolist()
    return local_translation, local_rotation, local_scale


def attach_node_to_hand(gltf, hand_node_idx, mesh_idx, translation, rotation, scale, name_suffix):
    """Appends a new node (with the given mesh + local TRS) as a child of
    hand_node_idx. Returns the new node's index."""
    new_node = {
        "name": f"item_{name_suffix}",
        "mesh": mesh_idx,
        "translation": translation,
        "rotation": rotation,
        "scale": scale,
    }
    gltf["nodes"].append(new_node)
    new_node_idx = len(gltf["nodes"]) - 1

    gltf["nodes"][hand_node_idx].setdefault("children", []).append(new_node_idx)
    return new_node_idx


def attach_item_to_hand(gltf, bin_data, world_matrices, hand_node_idx, anchor, primary, flat_axis, third, radius, length, name_suffix):
    """Original placeholder-cylinder attach path (used by the `cylinder`
    subcommand)."""
    local_translation, local_rotation, local_scale = compute_hand_local_trs(
        world_matrices, hand_node_idx, anchor, primary, flat_axis, third
    )
    positions, normals, indices = make_cylinder(radius, length)
    mesh_idx = add_item_mesh(gltf, bin_data, positions, normals, indices)
    return attach_node_to_hand(gltf, hand_node_idx, mesh_idx, local_translation, local_rotation, local_scale, name_suffix)


# --------------------------------------------------------------------------
# Real item mesh loading (batch mode) -- merging another GLB's mesh/material/
# texture/image data into the target character GLB.
# --------------------------------------------------------------------------

def _transform_points(matrix4, points):
    """Apply a 4x4 affine matrix to an (N,3) array of points."""
    ones = np.ones((points.shape[0], 1))
    homo = np.hstack([points, ones])
    out = (matrix4 @ homo.T).T
    return out[:, :3]


def _transform_directions(matrix4, dirs):
    """Apply the linear (rotation+scale, no translation) part of a 4x4
    matrix to an (N,3) array of direction vectors (normals/tangent xyz),
    using the inverse-transpose so non-uniform scale doesn't skew normals."""
    linear = matrix4[:3, :3]
    inv_t = np.linalg.inv(linear).T
    out = (inv_t @ dirs.T).T
    norms = np.linalg.norm(out, axis=1, keepdims=True)
    norms[norms < 1e-12] = 1.0
    return out / norms


def load_item_mesh(item_glb_path):
    """
    Loads an item .glb (e.g. clans/<clan>/items/small_dagger.glb) -- one or
    more mesh-bearing nodes, each with POSITION/NORMAL/[TANGENT]/[TEXCOORD_0]
    (the case seen in practice: Meshy-exported prop meshes with a single
    baked material/texture set, no skin).

    Bakes each mesh-bearing node's own local transform into its vertex data
    (so multiple nodes, if present, all land in one consistent local space)
    and returns a dict with:
        positions, normals, tangents (or None), uvs (or None), indices,
        material (dict or None), textures, samplers, images_raw (lists,
        possibly empty).
    Image bytes are re-hosted as standalone bytes (not bufferView indices
    into the source file) so the caller can append them into a different
    GLB's own buffer.
    """
    gltf, bin_data = load_glb(item_glb_path)
    nodes = gltf.get("nodes", [])
    world_matrices, _ = compute_world_matrices(nodes)

    all_positions, all_normals, all_tangents, all_uvs, all_indices = [], [], [], [], []
    material = None
    vertex_offset = 0
    have_tangent = True
    have_uv = True

    for i, node in enumerate(nodes):
        if "mesh" not in node:
            continue
        mesh = gltf["meshes"][node["mesh"]]
        for prim in mesh["primitives"]:
            attrs = prim["attributes"]
            positions = read_accessor(gltf, bin_data, attrs["POSITION"])[:, :3]
            world = world_matrices[i]
            positions = _transform_points(world, positions)

            if "NORMAL" in attrs:
                normals = read_accessor(gltf, bin_data, attrs["NORMAL"])[:, :3]
                normals = _transform_directions(world, normals)
            else:
                normals = np.tile(np.array([0.0, 1.0, 0.0]), (len(positions), 1))

            if "TANGENT" in attrs:
                tangent_raw = read_accessor(gltf, bin_data, attrs["TANGENT"])
                tangents_xyz = _transform_directions(world, tangent_raw[:, :3])
                tangent_w = tangent_raw[:, 3:4] if tangent_raw.shape[1] > 3 else np.ones((len(positions), 1))
                tangents = np.hstack([tangents_xyz, tangent_w])
            else:
                have_tangent = False
                tangents = None

            if "TEXCOORD_0" in attrs:
                uvs = read_accessor(gltf, bin_data, attrs["TEXCOORD_0"])[:, :2]
            else:
                have_uv = False
                uvs = None

            if "indices" in prim:
                idx = read_accessor(gltf, bin_data, prim["indices"])[:, 0].astype(np.int64)
            else:
                idx = np.arange(len(positions), dtype=np.int64)

            all_positions.append(positions)
            all_normals.append(normals)
            if tangents is not None:
                all_tangents.append(tangents)
            if uvs is not None:
                all_uvs.append(uvs)
            all_indices.append(idx + vertex_offset)
            vertex_offset += len(positions)

            if material is None and "material" in prim:
                material = gltf["materials"][prim["material"]]

    if not all_positions:
        raise ValueError(f"{item_glb_path}: no mesh primitives found")

    positions = np.concatenate(all_positions, axis=0)
    normals = np.concatenate(all_normals, axis=0)
    tangents = np.concatenate(all_tangents, axis=0) if (have_tangent and all_tangents) else None
    uvs = np.concatenate(all_uvs, axis=0) if (have_uv and all_uvs) else None
    indices = np.concatenate(all_indices, axis=0)

    images_raw = []
    for img in gltf.get("images", []):
        if "bufferView" in img:
            bv = gltf["bufferViews"][img["bufferView"]]
            offset = bv.get("byteOffset", 0)
            length = bv["byteLength"]
            raw = bytes(bin_data[offset: offset + length])
            images_raw.append({"mimeType": img.get("mimeType", "image/png"), "name": img.get("name"), "bytes": raw})
        else:
            images_raw.append(None)  # unsupported (e.g. external uri) -- skipped by caller

    return {
        "positions": positions,
        "normals": normals,
        "tangents": tangents,
        "uvs": uvs,
        "indices": indices,
        "material": material,
        "textures": gltf.get("textures", []),
        "samplers": gltf.get("samplers", []),
        "images_raw": images_raw,
    }


def detect_handle_end(positions, flip=False):
    """
    PCA on the item's own vertex positions to find its long axis, then
    compares cross-sectional spread at each end of that axis (thinner end
    assumed to be the handle/grip end -- true for a dagger/sword: blade is
    wide+thin, handle/grip is narrow+round).

    Returns (handle_point, blade_direction) in the item's own local space,
    where blade_direction points FROM the handle end TOWARD the blade/tip
    (i.e. "away from the hand"). Pass flip=True to use the other end
    instead (per-line --flip-left/--flip-right override).
    """
    centroid = positions.mean(axis=0)
    centered = positions - centroid
    cov = np.cov(centered.T)
    eigvals, eigvecs = np.linalg.eigh(cov)  # ascending eigenvalue order
    long_axis = eigvecs[:, -1]  # largest-variance axis = long axis
    long_axis = long_axis / np.linalg.norm(long_axis)

    proj = centered @ long_axis
    lo, hi = proj.min(), proj.max()
    span = hi - lo
    if span < 1e-9:
        handle_point = centroid
        blade_dir = -long_axis if flip else long_axis
        return handle_point, blade_dir

    band = span * 0.12
    lo_mask = proj <= (lo + band)
    hi_mask = proj >= (hi - band)

    def _cross_section_spread(mask):
        pts = centered[mask]
        if len(pts) < 3:
            return np.inf
        perp = pts - np.outer(pts @ long_axis, long_axis)
        return np.linalg.norm(perp, axis=1).std()

    lo_spread = _cross_section_spread(lo_mask)
    hi_spread = _cross_section_spread(hi_mask)

    handle_at_lo = lo_spread <= hi_spread  # thinner end = handle
    if flip:
        handle_at_lo = not handle_at_lo

    if handle_at_lo:
        handle_proj, blade_dir = lo, long_axis
    else:
        handle_proj, blade_dir = hi, -long_axis

    handle_point = centroid + handle_proj * long_axis
    return handle_point, blade_dir


def _rotation_180_about_any_perp(axis):
    perp = np.cross(axis, np.array([1.0, 0.0, 0.0]))
    if np.linalg.norm(perp) < 1e-6:
        perp = np.cross(axis, np.array([0.0, 0.0, 1.0]))
    perp = perp / np.linalg.norm(perp)
    K = np.array([[0, -perp[2], perp[1]], [perp[2], 0, -perp[0]], [-perp[1], perp[0], 0]])
    return np.eye(3) + 2 * (K @ K)  # Rodrigues, 180 degrees about perp


def _axis_rotation_matrix(axis, degrees):
    """Rodrigues' rotation formula: rotation matrix for `degrees` about the
    given (already unit-length) 3-vector `axis`."""
    if abs(degrees) < 1e-9:
        return np.eye(3)
    theta = np.radians(degrees)
    axis = axis / np.linalg.norm(axis)
    K = np.array([
        [0, -axis[2], axis[1]],
        [axis[2], 0, -axis[0]],
        [-axis[1], axis[0], 0],
    ])
    return np.eye(3) + np.sin(theta) * K + (1 - np.cos(theta)) * (K @ K)


def _euler_rotation_xyz(x_deg, y_deg, z_deg):
    """Combined rotation matrix applying rotation about local +X, then +Y,
    then +Z (in that order: R = Rz @ Ry @ Rx), each in the item's own
    grip-aligned local space (local +Y = the elbow-to-hand grip axis the
    item's long axis has already been aligned to by fit_item_to_grip's
    blade-direction alignment step)."""
    rx = _axis_rotation_matrix(np.array([1.0, 0.0, 0.0]), x_deg)
    ry = _axis_rotation_matrix(np.array([0.0, 1.0, 0.0]), y_deg)
    rz = _axis_rotation_matrix(np.array([0.0, 0.0, 1.0]), z_deg)
    return rz @ ry @ rx


def fit_item_to_grip(item_data, handle_point, blade_dir, target_length, rotation_xyz=(0.0, 0.0, 0.0),
                      offset_xyz=(0.0, 0.0, 0.0), slide=0.0):
    """
    Re-expresses the item's vertex data in the same local convention used
    by the placeholder cylinder/grip frame: local origin = grip point,
    local +Y = "away from hand" (grip/forward) axis, uniformly scaled so
    the item's own long-axis extent equals target_length.

    rotation_xyz is an optional (x_deg, y_deg, z_deg) tuple applied AFTER
    the blade-direction alignment (see _euler_rotation_xyz), PIVOTED AT
    offset_xyz rather than at the origin/handle point (see offset_xyz
    below for why) -- e.g. to roll the item about its own grip axis (Y) or
    tilt it off that axis (X/Z) for a specific pose.

    offset_xyz is an optional (x, y, z) point in METERS (in the same
    grip-aligned local axes as rotation_xyz -- local Y is the grip axis,
    X/Z perpendicular to it), measured from the DETECTED HANDLE POINT, that
    marks the true grip location the rig's hand actually closes around.
    This matters because the detected "handle point" this function centers
    on is wherever detect_handle_end()'s heuristic found the item's own
    thin end -- for the skeleton side, the corresponding attach point is
    the hand JOINT's origin, which sits at the WRIST, not out at the palm/
    fingers where the fist visually wraps around a held item (the hand
    mesh is a rigid extension of the same wrist bone, not a separate
    pivot). With zero rotation this discrepancy is invisible (the item's
    long axis already points straight down the wrist-to-hand vector, so it
    still visually lines up with the fist), but rotating it PIVOTED AT THE
    WRIST (the origin, pre-fix) swings the item's grip end away from the
    fist as soon as any rotation is applied, since the true grip point
    several centimeters further out along that same vector is what should
    stay fixed in place during the rotation, not the wrist.
    offset_xyz fixes this by rotating about that true grip point instead
    of the origin: with rotation_xyz all zero this is a mathematical no-op
    regardless of offset_xyz (matches the already-correct no-rotation
    case), and with rotation applied, the point at offset_xyz stays fixed
    in space while the rest of the item swings around it. Tune offset_xyz
    (mainly its Y component -- the distance from the wrist joint to where
    the fingers actually close around a held grip) per-rig/hand size;
    typically a small positive number (a few centimeters).

    slide is an optional SCALAR (meters) applied LAST, as a plain
    translation purely along the item's own local Y axis (the grip/blade
    vector itself -- not a full XYZ vector, since "slide it along its own
    length" is inherently one-dimensional). Unlike offset_xyz (which only
    changes the PIVOT of a rotation and is a no-op with zero rotation),
    slide always moves the item -- use it to push the handle further into
    the fist (or pull it back out) independent of any rotation, e.g. after
    a rotation is already correctly pivoted but the handle still isn't
    fully seated in the grip.

    Returns (positions, normals, tangents_or_None) in this new local space.
    """
    positions = item_data["positions"] - handle_point
    blade_dir = blade_dir / np.linalg.norm(blade_dir)

    target = np.array([0.0, 1.0, 0.0])
    v = np.cross(blade_dir, target)
    c = np.dot(blade_dir, target)
    if np.linalg.norm(v) < 1e-9:
        R = np.eye(3) if c > 0 else _rotation_180_about_any_perp(blade_dir)
    else:
        vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
        R = np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))

    positions = positions @ R.T
    normals = item_data["normals"] @ R.T
    tangents = None
    if item_data["tangents"] is not None:
        txyz = item_data["tangents"][:, :3] @ R.T
        tangents = np.hstack([txyz, item_data["tangents"][:, 3:4]])

    # Scale BEFORE the extra rotation (rather than after, as in the
    # original pre-fix ordering) so offset_xyz's pivot point can be
    # specified directly in real-world meters, matching the final
    # in-scene item size, instead of in pre-scale mesh units.
    y_span = positions[:, 1].max() - positions[:, 1].min()
    scale_factor = 1.0 if y_span < 1e-9 else target_length / y_span
    positions = positions * scale_factor

    x_deg, y_deg, z_deg = rotation_xyz
    R_extra = _euler_rotation_xyz(x_deg, y_deg, z_deg)
    pivot = np.array(offset_xyz, dtype=positions.dtype)
    positions = (positions - pivot) @ R_extra.T + pivot
    normals = normals @ R_extra.T
    if tangents is not None:
        txyz = tangents[:, :3] @ R_extra.T
        tangents = np.hstack([txyz, tangents[:, 3:4]])

    if slide:
        positions = positions.copy()
        positions[:, 1] += slide

    return positions, normals, tangents


def add_item_mesh_full(gltf, bin_data, positions, normals, tangents, uvs, indices, item_data, name_suffix):
    """
    Like add_item_mesh() but for a real imported item mesh: copies over the
    source material (with its textures/samplers/images re-hosted into the
    target GLB's own buffer) instead of a flat placeholder color.
    """
    image_index_map = {}
    gltf.setdefault("images", [])
    for old_idx, img in enumerate(item_data.get("images_raw", [])):
        if img is None:
            continue
        bv_idx = append_buffer_view(gltf, bin_data, img["bytes"])
        new_img = {"bufferView": bv_idx, "mimeType": img["mimeType"]}
        if img.get("name"):
            new_img["name"] = img["name"]
        gltf["images"].append(new_img)
        image_index_map[old_idx] = len(gltf["images"]) - 1

    sampler_index_map = {}
    gltf.setdefault("samplers", [])
    for old_idx, samp in enumerate(item_data.get("samplers", [])):
        gltf["samplers"].append(dict(samp))
        sampler_index_map[old_idx] = len(gltf["samplers"]) - 1

    texture_index_map = {}
    gltf.setdefault("textures", [])
    for old_idx, tex in enumerate(item_data.get("textures", [])):
        new_tex = {}
        if "sampler" in tex:
            new_tex["sampler"] = sampler_index_map.get(tex["sampler"], tex["sampler"])
        if "source" in tex:
            new_tex["source"] = image_index_map.get(tex["source"], tex["source"])
        gltf["textures"].append(new_tex)
        texture_index_map[old_idx] = len(gltf["textures"]) - 1

    def _remap_texture_ref(ref):
        if ref is None:
            return None
        new_ref = dict(ref)
        if "index" in new_ref:
            new_ref["index"] = texture_index_map.get(new_ref["index"], new_ref["index"])
        return new_ref

    src_material = item_data.get("material")
    gltf.setdefault("materials", [])
    if src_material is not None:
        new_material = json.loads(json.dumps(src_material))  # deep copy
        pbr = new_material.get("pbrMetallicRoughness")
        if pbr and "baseColorTexture" in pbr:
            pbr["baseColorTexture"] = _remap_texture_ref(pbr["baseColorTexture"])
        if pbr and "metallicRoughnessTexture" in pbr:
            pbr["metallicRoughnessTexture"] = _remap_texture_ref(pbr["metallicRoughnessTexture"])
        if "normalTexture" in new_material:
            new_material["normalTexture"] = _remap_texture_ref(new_material["normalTexture"])
        if "emissiveTexture" in new_material:
            new_material["emissiveTexture"] = _remap_texture_ref(new_material["emissiveTexture"])
        if "occlusionTexture" in new_material:
            new_material["occlusionTexture"] = _remap_texture_ref(new_material["occlusionTexture"])
        gltf["materials"].append(new_material)
        mat_idx = len(gltf["materials"]) - 1
    else:
        gltf["materials"].append({"name": "item_material", "pbrMetallicRoughness": {"baseColorFactor": [0.6, 0.6, 0.6, 1.0]}})
        mat_idx = len(gltf["materials"]) - 1

    pos_bytes = positions.astype("<f4").tobytes()
    norm_bytes = normals.astype("<f4").tobytes()
    pos_bv = append_buffer_view(gltf, bin_data, pos_bytes, target=34962)
    norm_bv = append_buffer_view(gltf, bin_data, norm_bytes, target=34962)

    attributes = {}
    attributes["POSITION"] = len(gltf["accessors"])
    gltf["accessors"].append({
        "bufferView": pos_bv, "componentType": 5126, "count": len(positions), "type": "VEC3",
        "min": positions.min(axis=0).tolist(), "max": positions.max(axis=0).tolist(),
    })
    attributes["NORMAL"] = len(gltf["accessors"])
    gltf["accessors"].append({"bufferView": norm_bv, "componentType": 5126, "count": len(normals), "type": "VEC3"})

    if tangents is not None:
        tan_bytes = tangents.astype("<f4").tobytes()
        tan_bv = append_buffer_view(gltf, bin_data, tan_bytes, target=34962)
        attributes["TANGENT"] = len(gltf["accessors"])
        gltf["accessors"].append({"bufferView": tan_bv, "componentType": 5126, "count": len(tangents), "type": "VEC4"})

    if uvs is not None:
        uv_bytes = uvs.astype("<f4").tobytes()
        uv_bv = append_buffer_view(gltf, bin_data, uv_bytes, target=34962)
        attributes["TEXCOORD_0"] = len(gltf["accessors"])
        gltf["accessors"].append({"bufferView": uv_bv, "componentType": 5126, "count": len(uvs), "type": "VEC2"})

    max_idx = int(indices.max()) if len(indices) else 0
    if max_idx < 65536:
        idx_bytes = indices.astype("<u2").tobytes()
        idx_component_type = 5123
    else:
        idx_bytes = indices.astype("<u4").tobytes()
        idx_component_type = 5125
    idx_bv = append_buffer_view(gltf, bin_data, idx_bytes, target=34963)
    idx_accessor_idx = len(gltf["accessors"])
    gltf["accessors"].append({"bufferView": idx_bv, "componentType": idx_component_type, "count": len(indices), "type": "SCALAR"})

    mesh = {
        "name": f"item_{name_suffix}_mesh",
        "primitives": [{"attributes": attributes, "indices": idx_accessor_idx, "material": mat_idx}],
    }
    gltf["meshes"].append(mesh)
    return len(gltf["meshes"]) - 1


def add_skinning_to_item_mesh(gltf, bin_data, mesh_idx, vertex_count, skin_joint_index):
    """
    Adds JOINTS_0/WEIGHTS_0 accessors to an already-added item mesh
    (mesh_idx, from add_item_mesh_full()), 100% rigidly weighted to a
    single joint (skin_joint_index -- the item's POSITION index into
    gltf["skins"][0]["joints"], NOT a scene node index).

    This is the portable, spec-correct way to rigidly attach a prop to one
    bone: item vertices participate in the SAME skin as the character mesh
    (see attach_node_to_skin() for why they must additionally be authored
    in world/bind-pose space for this to work), so any spec-compliant
    glTF consumer -- Blender, Meshy, three.js, Unity, Unreal, etc. --
    follows the joint correctly with zero special-casing, unlike the
    previous "plain node parented directly under the joint node" approach
    (which relied on a Blender-specific import-time correction hack, see
    render_core._fix_bone_parented_item_transforms, and was NOT
    interpreted correctly by Meshy's own glTF import).
    """
    joints0 = np.zeros((vertex_count, 4), dtype="<u1")
    joints0[:, 0] = skin_joint_index
    weights0 = np.zeros((vertex_count, 4), dtype="<f4")
    weights0[:, 0] = 1.0

    joints_bv = append_buffer_view(gltf, bin_data, joints0.tobytes(), target=34962)
    weights_bv = append_buffer_view(gltf, bin_data, weights0.astype("<f4").tobytes(), target=34962)

    joints_acc_idx = len(gltf["accessors"])
    gltf["accessors"].append({
        "bufferView": joints_bv, "componentType": 5121, "count": vertex_count, "type": "VEC4",
    })
    weights_acc_idx = len(gltf["accessors"])
    gltf["accessors"].append({
        "bufferView": weights_bv, "componentType": 5126, "count": vertex_count, "type": "VEC4",
    })

    mesh = gltf["meshes"][mesh_idx]
    mesh["primitives"][0]["attributes"]["JOINTS_0"] = joints_acc_idx
    mesh["primitives"][0]["attributes"]["WEIGHTS_0"] = weights_acc_idx


def attach_node_to_skin(gltf, mesh_idx, name_suffix):
    """
    Adds a new node referencing mesh_idx (already skinned via
    add_skinning_to_item_mesh()) and gltf["skins"][0], as a top-level
    scene node (a sibling of the character mesh node, NOT a child of any
    joint node -- skinned meshes are positioned entirely by their
    vertices' bind-pose-space coordinates + their joints' current pose,
    per the glTF skinning spec, so this node needs no TRS of its own and
    must NOT be reparented under a joint). Returns the new node's index.
    """
    new_node = {
        "name": f"item_{name_suffix}",
        "mesh": mesh_idx,
        "skin": 0,
    }
    gltf["nodes"].append(new_node)
    new_node_idx = len(gltf["nodes"]) - 1

    scene = gltf["scenes"][gltf.get("scene", 0)]
    scene.setdefault("nodes", []).append(new_node_idx)
    return new_node_idx


def _decode_image_bytes(gltf, bin_data, image_idx):
    img = gltf["images"][image_idx]
    bv = gltf["bufferViews"][img["bufferView"]]
    offset = bv.get("byteOffset", 0)
    length = bv["byteLength"]
    return bytes(bin_data[offset:offset + length])


def _material_texture_image_indices(gltf, material_idx):
    """Returns {channel_name: image_idx_or_None} for a materials 4
    common PBR channels, resolved through textures[].source."""
    mat = gltf["materials"][material_idx]

    def resolve(tex_ref):
        if tex_ref is None:
            return None
        tex = gltf["textures"][tex_ref["index"]]
        return tex.get("source")

    pbr = mat.get("pbrMetallicRoughness", {})
    return {
        "base_color": resolve(pbr.get("baseColorTexture")),
        "metallic_roughness": resolve(pbr.get("metallicRoughnessTexture")),
        "normal": resolve(mat.get("normalTexture")),
        "emissive": resolve(mat.get("emissiveTexture")),
    }


ATLAS_SIZE = 2048  # square canvas size (px) for each composited PBR channel image
ITEM_UV_MARGIN = 0.02  # fraction of atlas reserved as padding around the items packed region
ITEM_UV_FRACTION = 0.30  # items packed region occupies this fraction of the atlas edge length


def merge_item_into_character_mesh(gltf, bin_data, char_mesh_idx, item_mesh_idx, item_node_idx):
    """
    Merges the item mesh (item_mesh_idx, a rigidly-skinned sibling node added
    by attach_real_item_to_hand()/attach_node_to_skin()) INTO the character
    meshs own primitive (char_mesh_idx) as one combined mesh/material/UV map,
    per Meshys own documented import requirements:
        - only include one mesh in the file (multiple meshes get merged on
          upload anyway)
        - the model must have exactly 1 material and 1 UV map AFTER merging
        - UV islands cannot overlap or be shared among multiple parts

    Before this fix, attach_hand_item.py shipped the character and the item
    as TWO separate meshes/materials, each using the items own UV island
    (BOTH occupying the full [0,1]x[0,1] UV range independently). Meshys own
    merge-on-upload step (needed before it will animate a model) collapses
    these into one mesh/material, at which point the two identically-ranged
    UV islands directly overlap -- exactly what Meshys own docs say breaks
    texture preservation -- which is why the dagger picks up the characters
    texture (or vice versa) specifically AFTER Meshys re-rig/merge step, even
    though the file looks correct on raw import beforehand.

    Fix: perform that merge OURSELVES, correctly, before the file ever
    reaches Meshy --
        1. Composite one shared atlas image per PBR channel (base color,
           metallic/roughness, normal, emissive): the characters own texture
           pasted at full size, with the items corresponding texture resized
           and pasted into a small reserved, non-overlapping corner region.
        2. Remap the items UVs from its native [0,1] range into that same
           reserved corner region of the shared atlas; shrink the characters
           own UVs slightly so they cannot bleed into that reserved corner
           either (guaranteeing zero UV island overlap either direction).
        3. Concatenate both primitives vertex attributes (positions, normals,
           UVs, JOINTS_0/WEIGHTS_0 -- both already share one skin) and index
           buffers into ONE merged primitive on ONE merged material.
        4. Remove the now-empty item mesh/node -- the character mesh node is
           the only mesh-bearing node left.

    TANGENT is dropped from the merged primitive (the character mesh has no
    TANGENT attribute of its own in practice, and glTF consumers compute a
    reasonable default when its absent, per spec).

    Mutates gltf/bin_data in place.
    """
    from PIL import Image
    import io

    char_mesh = gltf["meshes"][char_mesh_idx]
    item_mesh = gltf["meshes"][item_mesh_idx]
    char_prim = char_mesh["primitives"][0]
    item_prim = item_mesh["primitives"][0]
    char_mat_idx = char_prim["material"]
    item_mat_idx = item_prim["material"]

    char_channels = _material_texture_image_indices(gltf, char_mat_idx)
    item_channels = _material_texture_image_indices(gltf, item_mat_idx)

    # Reserved corner region (bottom-right) for the items remapped UVs,
    # in [0,1] atlas-space -- used both for image compositing (pixel
    # coords) and UV remapping (normalized coords) below.
    region_u0 = 1.0 - ITEM_UV_FRACTION - ITEM_UV_MARGIN
    region_v0 = 1.0 - ITEM_UV_FRACTION - ITEM_UV_MARGIN
    region_size = ITEM_UV_FRACTION
    char_uv_scale = 1.0 - ITEM_UV_FRACTION - 2 * ITEM_UV_MARGIN

    def composite_channel(channel_name, char_img_idx, item_img_idx, default_rgb):
        """Builds one ATLAS_SIZE x ATLAS_SIZE RGB(A) image. The characters
        own texture for this channel (or a flat default_rgb fill if it has
        none) is resized down to fit the SAME shrunk [0, char_uv_scale]
        region its own remapped UVs will point to (matching
        char_uv_remapped below) -- NOT pasted at full atlas size, which
        would desync the UVs from the actual pixel content and produce a
        cropped/distorted look. The items own texture for this channel
        (if any) is resized into the reserved corner region. Returns
        encoded JPEG bytes, or None if NEITHER side has this channel.
        """
        if char_img_idx is None and item_img_idx is None:
            return None

        canvas = Image.new("RGB", (ATLAS_SIZE, ATLAS_SIZE), default_rgb)
        char_region_px = int(round(char_uv_scale * ATLAS_SIZE))
        if char_img_idx is not None:
            char_bytes = _decode_image_bytes(gltf, bin_data, char_img_idx)
            char_img = Image.open(io.BytesIO(char_bytes)).convert("RGB").resize((char_region_px, char_region_px))
            canvas.paste(char_img, (0, 0))

        if item_img_idx is not None:
            item_bytes = _decode_image_bytes(gltf, bin_data, item_img_idx)
            item_img = Image.open(io.BytesIO(item_bytes)).convert("RGB")
            region_px = int(round(region_size * ATLAS_SIZE))
            item_img = item_img.resize((region_px, region_px))
            paste_x = int(round(region_u0 * ATLAS_SIZE))
            paste_y = int(round(region_v0 * ATLAS_SIZE))
            canvas.paste(item_img, (paste_x, paste_y))

        out = io.BytesIO()
        canvas.save(out, format="JPEG", quality=92)
        return out.getvalue()

    channel_defaults = {
        "base_color": (200, 200, 200),
        "metallic_roughness": (0, 200, 0),
        "normal": (128, 128, 255),
        "emissive": (0, 0, 0),
    }
    new_image_idx = {}
    for channel_name, default_rgb in channel_defaults.items():
        encoded = composite_channel(
            channel_name, char_channels.get(channel_name), item_channels.get(channel_name), default_rgb,
        )
        if encoded is None:
            continue
        bv_idx = append_buffer_view(gltf, bin_data, encoded)
        gltf["images"].append({"bufferView": bv_idx, "mimeType": "image/jpeg", "name": f"merged_{channel_name}"})
        new_image_idx[channel_name] = len(gltf["images"]) - 1

    gltf.setdefault("samplers", [])
    gltf["samplers"].append({"magFilter": 9729, "minFilter": 9987})
    sampler_idx = len(gltf["samplers"]) - 1

    new_texture_idx = {}
    for channel_name, img_idx in new_image_idx.items():
        gltf["textures"].append({"sampler": sampler_idx, "source": img_idx})
        new_texture_idx[channel_name] = len(gltf["textures"]) - 1

    merged_material = {"name": "merged_material", "doubleSided": True, "pbrMetallicRoughness": {}}
    if "base_color" in new_texture_idx:
        merged_material["pbrMetallicRoughness"]["baseColorTexture"] = {"index": new_texture_idx["base_color"]}
    if "metallic_roughness" in new_texture_idx:
        merged_material["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": new_texture_idx["metallic_roughness"]}
    if "normal" in new_texture_idx:
        merged_material["normalTexture"] = {"index": new_texture_idx["normal"]}
    if "emissive" in new_texture_idx:
        merged_material["emissiveTexture"] = {"index": new_texture_idx["emissive"]}
        merged_material["emissiveFactor"] = [1.0, 1.0, 1.0]
    else:
        merged_material["emissiveFactor"] = [0.0, 0.0, 0.0]

    gltf["materials"].append(merged_material)
    merged_mat_idx = len(gltf["materials"]) - 1

    def read_attr(prim, name, default_fill=None, count=None):
        if name in prim["attributes"]:
            return read_accessor(gltf, bin_data, prim["attributes"][name])
        return None if default_fill is None else np.tile(np.array(default_fill), (count, 1))

    char_pos = read_attr(char_prim, "POSITION")
    char_norm = read_attr(char_prim, "NORMAL", default_fill=[0.0, 1.0, 0.0], count=len(char_pos))
    char_uv = read_attr(char_prim, "TEXCOORD_0", default_fill=[0.0, 0.0], count=len(char_pos))
    char_joints = read_attr(char_prim, "JOINTS_0", default_fill=[0, 0, 0, 0], count=len(char_pos))
    char_weights = read_attr(char_prim, "WEIGHTS_0", default_fill=[1.0, 0.0, 0.0, 0.0], count=len(char_pos))
    char_indices = read_accessor(gltf, bin_data, char_prim["indices"])[:, 0].astype(np.int64)

    item_pos = read_attr(item_prim, "POSITION")
    item_norm = read_attr(item_prim, "NORMAL", default_fill=[0.0, 1.0, 0.0], count=len(item_pos))
    item_uv = read_attr(item_prim, "TEXCOORD_0", default_fill=[0.0, 0.0], count=len(item_pos))
    item_joints = read_attr(item_prim, "JOINTS_0", default_fill=[0, 0, 0, 0], count=len(item_pos))
    item_weights = read_attr(item_prim, "WEIGHTS_0", default_fill=[1.0, 0.0, 0.0, 0.0], count=len(item_pos))
    item_indices = read_accessor(gltf, bin_data, item_prim["indices"])[:, 0].astype(np.int64)

    # Remap UVs: shrink the characters own UVs to the SAME [0, char_uv_scale]
    # region composite_channel() above already pasted the character texture
    # into, and remap the items UVs (native [0,1]) into the reserved
    # corner region. This guarantees zero overlap between the two UV
    # islands in the shared atlas, and keeps each sides UVs correctly
    # synced to where its own pixel content actually landed.
    char_uv_remapped = char_uv * char_uv_scale
    item_uv_remapped = item_uv * region_size + np.array([region_u0, region_v0])

    merged_pos = np.vstack([char_pos, item_pos])
    merged_norm = np.vstack([char_norm, item_norm])
    merged_uv = np.vstack([char_uv_remapped, item_uv_remapped])
    merged_joints = np.vstack([char_joints, item_joints])
    merged_weights = np.vstack([char_weights, item_weights])
    merged_indices = np.concatenate([char_indices, item_indices + len(char_pos)])

    pos_bv = append_buffer_view(gltf, bin_data, merged_pos.astype("<f4").tobytes(), target=34962)
    norm_bv = append_buffer_view(gltf, bin_data, merged_norm.astype("<f4").tobytes(), target=34962)
    uv_bv = append_buffer_view(gltf, bin_data, merged_uv.astype("<f4").tobytes(), target=34962)
    joints_bv = append_buffer_view(gltf, bin_data, merged_joints.astype("<u1").tobytes(), target=34962)
    weights_bv = append_buffer_view(gltf, bin_data, merged_weights.astype("<f4").tobytes(), target=34962)

    max_idx = int(merged_indices.max()) if len(merged_indices) else 0
    if max_idx < 65536:
        idx_bytes = merged_indices.astype("<u2").tobytes()
        idx_component_type = 5123
    else:
        idx_bytes = merged_indices.astype("<u4").tobytes()
        idx_component_type = 5125
    idx_bv = append_buffer_view(gltf, bin_data, idx_bytes, target=34963)

    def add_acc(bv, comp_type, count, acc_type, min_max=None):
        acc = {"bufferView": bv, "componentType": comp_type, "count": count, "type": acc_type}
        if min_max is not None:
            acc["min"], acc["max"] = min_max
        gltf["accessors"].append(acc)
        return len(gltf["accessors"]) - 1

    n_verts = len(merged_pos)
    new_attrs = {
        "POSITION": add_acc(pos_bv, 5126, n_verts, "VEC3", (merged_pos.min(axis=0).tolist(), merged_pos.max(axis=0).tolist())),
        "NORMAL": add_acc(norm_bv, 5126, n_verts, "VEC3"),
        "TEXCOORD_0": add_acc(uv_bv, 5126, n_verts, "VEC2"),
        "JOINTS_0": add_acc(joints_bv, 5121, n_verts, "VEC4"),
        "WEIGHTS_0": add_acc(weights_bv, 5126, n_verts, "VEC4"),
    }
    new_idx_acc = add_acc(idx_bv, idx_component_type, len(merged_indices), "SCALAR")

    char_mesh["primitives"] = [{"attributes": new_attrs, "indices": new_idx_acc, "material": merged_mat_idx}]

    # Remove the now-empty item mesh node from the scene graph (its
    # geometry now lives merged into char_mesh) -- leave the mesh/
    # material/image/texture/accessor/bufferView entries themselves in
    # place (harmless orphaned data, simpler and safer than renumbering
    # every other index in the file).
    for scene in gltf.get("scenes", []):
        if item_node_idx in scene.get("nodes", []):
            scene["nodes"].remove(item_node_idx)
    for node in gltf.get("nodes", []):
        if "children" in node and item_node_idx in node["children"]:
            node["children"].remove(item_node_idx)

def hand_span_length(hand_points):
    """Rough real-world hand size (bbox diagonal of the hand's own skinned
    vertex cluster) used as the basis for auto-scaling an item to a
    plausible size relative to this specific character's hands."""
    bbox_min = hand_points.min(axis=0)
    bbox_max = hand_points.max(axis=0)
    return float(np.linalg.norm(bbox_max - bbox_min))


def attach_real_item_to_hand(gltf, bin_data, world_matrices, hand_node_idx, anchor, primary, flat_axis, third,
                              item_data, target_length, flip, name_suffix, skin_joints, rotation_xyz=(0.0, 0.0, 0.0),
                              offset_xyz=(0.0, 0.0, 0.0), slide=0.0):
    """
    Attaches a real item mesh RIGIDLY SKINNED to hand_node_idx (spec-correct
    glTF skinning -- see add_skinning_to_item_mesh()/attach_node_to_skin())
    rather than as a plain node parented under the hand joint. The item's
    own local grip-space vertices (from fit_item_to_grip(), origin = grip
    point, +Y = grip axis) are baked into WORLD/BIND-POSE space here via
    the same grip-frame -> hand-local TRS math compute_hand_local_trs()
    already computed (hand_world_matrix @ that local TRS), because
    glTF skinning requires a skinned primitive's vertices to be authored
    in the skeleton's bind pose space -- the joint's inverse-bind-matrix
    then correctly re-derives them relative to the joint at render/
    animation time, in any spec-compliant consumer.
    """
    handle_point, blade_dir = detect_handle_end(item_data["positions"], flip=flip)
    positions, normals, tangents = fit_item_to_grip(item_data, handle_point, blade_dir, target_length,
                                                     rotation_xyz, offset_xyz, slide)

    local_translation, local_rotation, local_scale = compute_hand_local_trs(
        world_matrices, hand_node_idx, anchor, primary, flat_axis, third
    )
    local_matrix = np.eye(4)
    local_matrix[:3, :3] = quat_to_mat3(local_rotation) @ np.diag(local_scale)
    local_matrix[:3, 3] = local_translation
    bind_matrix = world_matrices[hand_node_idx] @ local_matrix

    positions = _transform_points(bind_matrix, positions)
    normal_matrix = np.linalg.inv(bind_matrix[:3, :3]).T
    normals = normals @ normal_matrix.T
    normals = normals / np.linalg.norm(normals, axis=1, keepdims=True)
    if tangents is not None:
        txyz = tangents[:, :3] @ bind_matrix[:3, :3].T
        txyz = txyz / np.linalg.norm(txyz, axis=1, keepdims=True)
        tangents = np.hstack([txyz, tangents[:, 3:4]])

    mesh_idx = add_item_mesh_full(
        gltf, bin_data, positions, normals, tangents, item_data["uvs"], item_data["indices"], item_data, name_suffix,
    )
    skin_joint_index = skin_joints.index(hand_node_idx)
    add_skinning_to_item_mesh(gltf, bin_data, mesh_idx, len(positions), skin_joint_index)
    return attach_node_to_skin(gltf, mesh_idx, name_suffix)


def _parse_item_preset_lines(path, raw_lines):
    """First pass over an instructions file: collects 'item <clan>
    <preset_name> <base_item> [X:/Y:/Z:/TX:/TY:/TZ:/S:/--flip tokens]'
    preset-definition lines into a {(clan, preset_name): pose_dict} map
    (see parse_instructions_file's docstring for the full resolution
    semantics). Lines not starting with the literal token 'item' (case-
    insensitive) are ignored here -- they're subject lines, handled by
    parse_instructions_file's own second pass."""
    presets = {}
    for lineno, raw_line in enumerate(raw_lines, start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        tokens = line.split()
        if tokens[0].lower() != "item":
            continue
        if len(tokens) < 4:
            print(f"WARNING: {path}:{lineno}: 'item' line expected at least 4 fields "
                  f"(item <clan> <preset_name> <base_item>), got {len(tokens)!r} -- skipping", file=sys.stderr)
            continue
        _, clan, preset_name, base_item = tokens[0], tokens[1], tokens[2], tokens[3]
        rotation = [0.0, 0.0, 0.0]
        offset = [0.0, 0.0, 0.0]
        slide = 0.0
        flip = False
        rest = tokens[4:]
        i = 0
        while i < len(rest):
            tok = rest[i]
            if tok in ("--flip", "--flip-left", "--flip-right"):
                flip = True
                i += 1
                continue
            if ":" not in tok:
                print(f"WARNING: {path}:{lineno}: unrecognized token {tok!r} in 'item' line -- skipping token", file=sys.stderr)
                i += 1
                continue
            key, value = tok.split(":", 1)
            key = key.strip().lower()
            value = value.strip()
            if key in ("x", "y", "z"):
                try:
                    degrees = float(value)
                except ValueError:
                    print(f"WARNING: {path}:{lineno}: {tok!r} has a non-numeric value -- skipping token", file=sys.stderr)
                    i += 1
                    continue
                rotation[{"x": 0, "y": 1, "z": 2}[key]] = degrees
            elif key in ("tx", "ty", "tz"):
                try:
                    meters = float(value)
                except ValueError:
                    print(f"WARNING: {path}:{lineno}: {tok!r} has a non-numeric value -- skipping token", file=sys.stderr)
                    i += 1
                    continue
                offset[{"tx": 0, "ty": 1, "tz": 2}[key]] = meters
            elif key == "s":
                try:
                    meters = float(value)
                except ValueError:
                    print(f"WARNING: {path}:{lineno}: {tok!r} has a non-numeric value -- skipping token", file=sys.stderr)
                    i += 1
                    continue
                slide = meters
            else:
                print(f"WARNING: {path}:{lineno}: unrecognized token {tok!r} in 'item' line -- skipping token", file=sys.stderr)
            i += 1
        preset_key = (clan, preset_name)
        if preset_key in presets:
            print(f"WARNING: {path}:{lineno}: preset {preset_name!r} for clan {clan!r} redefined "
                  f"(previous definition overwritten)", file=sys.stderr)
        presets[preset_key] = {
            "item": base_item, "rotation": tuple(rotation), "offset": tuple(offset),
            "slide": slide, "flip": flip, "lineno": lineno,
        }
    return presets


_MODEL_ANIM_LINE_RE = re.compile(
    r'^--\s*anim\s+(?P<state>\S+)\s+anim_text:\s*"(?P<text>.*)"\s*$'
)
# Alternative anim-line form: a Meshy Animation Library preset instead of a
# free-form Text-to-Motion prompt -- see
# https://docs.meshy.ai/en/api/animation-library. Cheaper (skips the
# text-to-motion credit cost entirely) and deterministic/previewable, at
# the cost of being limited to the library's ~700 preset actions rather
# than an arbitrary natural-language description.
_MODEL_ANIM_ACTION_LINE_RE = re.compile(
    r'^--\s*anim\s+(?P<state>\S+)\s+action_id:\s*(?P<action_id>\d+)\s*$'
)


def read_api_key(path):
    """
    Resolves the Meshy API key for this run.

    The MESHY_API_KEY environment variable wins if set -- preferred, since
    this script tree now lives in a SHARED, version-controlled engine repo
    (tools/generate_assets/) whose bundled model_definitions.txt template
    must never carry a real secret. Otherwise the key is read off the
    reserved FIRST line of the instructions file, in the form:
        MESHY_API_KEY="msy_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    Returns the bare key string (quotes stripped). Raises ValueError if
    neither source yields a usable key.
    """
    env_key = os.environ.get("MESHY_API_KEY", "").strip()
    if env_key:
        return env_key

    with open(path, "r", encoding="utf-8") as f:
        first_line = f.readline().strip()
    m = re.match(r'^MESHY_API_KEY\s*=\s*"([^"]+)"\s*$', first_line)
    if not m:
        raise ValueError(
            f"{path}: expected first line to be MESHY_API_KEY=\"...\", got {first_line!r} "
            f"(or set the MESHY_API_KEY environment variable instead)"
        )
    key = m.group(1).strip()
    if not key or key.upper().startswith("PUT_YOUR"):
        raise ValueError(
            f"{path}: line 1 still holds the placeholder API key. Put your real Meshy key there, "
            f"or set the MESHY_API_KEY environment variable."
        )
    return key


def _parse_slot_tokens(path, lineno, clan, tokens, presets, start_index=0):
    """
    Shared token-scanning loop for a 'model' header line's slot tokens
    (left:/right:/back:/head:, X:/Y:/Z:, TX:/TY:/TZ:, S:, --flip variants).
    Returns (hands, flip, rotation, offset, slide) dicts keyed by SLOTS.
    """
    SLOTS = ("left", "right", "back", "head")
    hands = {s: None for s in SLOTS}
    flip = {s: False for s in SLOTS}
    rotation = {s: [0.0, 0.0, 0.0] for s in SLOTS}
    offset = {s: [0.0, 0.0, 0.0] for s in SLOTS}
    slide = {s: 0.0 for s in SLOTS}
    current_hand = None
    i = start_index
    while i < len(tokens):
        tok = tokens[i]
        if tok in ("--flip", "--flip-left"):
            flip["left"] = True
            if tok == "--flip":
                flip["right"] = True
            i += 1
            continue
        if tok == "--flip-right":
            flip["right"] = True
            i += 1
            continue
        if ":" not in tok:
            print(f"WARNING: {path}:{lineno}: unrecognized token {tok!r} -- skipping token", file=sys.stderr)
            i += 1
            continue
        key, value = tok.split(":", 1)
        key = key.strip().lower()
        value = value.strip()
        if key in ("left", "right", "back", "head"):
            current_hand = key
            if value.lower() == "none":
                hands[key] = None
            else:
                preset = presets.get((clan, value))
                if preset is not None:
                    hands[key] = preset["item"]
                    rotation[key] = list(preset["rotation"])
                    offset[key] = list(preset["offset"])
                    slide[key] = preset["slide"]
                    flip[key] = preset["flip"]
                else:
                    hands[key] = value
        elif key in ("x", "y", "z"):
            if current_hand is None:
                print(f"WARNING: {path}:{lineno}: {tok!r} appears before any 'left:'/'right:' token -- skipping token", file=sys.stderr)
                i += 1
                continue
            try:
                degrees = float(value)
            except ValueError:
                print(f"WARNING: {path}:{lineno}: {tok!r} has a non-numeric value -- skipping token", file=sys.stderr)
                i += 1
                continue
            axis_idx = {"x": 0, "y": 1, "z": 2}[key]
            rotation[current_hand][axis_idx] = degrees
        elif key in ("tx", "ty", "tz"):
            if current_hand is None:
                print(f"WARNING: {path}:{lineno}: {tok!r} appears before any 'left:'/'right:' token -- skipping token", file=sys.stderr)
                i += 1
                continue
            try:
                meters = float(value)
            except ValueError:
                print(f"WARNING: {path}:{lineno}: {tok!r} has a non-numeric value -- skipping token", file=sys.stderr)
                i += 1
                continue
            axis_idx = {"tx": 0, "ty": 1, "tz": 2}[key]
            offset[current_hand][axis_idx] = meters
        elif key == "s":
            if current_hand is None:
                print(f"WARNING: {path}:{lineno}: {tok!r} appears before any 'left:'/'right:' token -- skipping token", file=sys.stderr)
                i += 1
                continue
            try:
                meters = float(value)
            except ValueError:
                print(f"WARNING: {path}:{lineno}: {tok!r} has a non-numeric value -- skipping token", file=sys.stderr)
                i += 1
                continue
            slide[current_hand] = meters
        else:
            print(f"WARNING: {path}:{lineno}: unrecognized token {tok!r} -- skipping token", file=sys.stderr)
        i += 1
    rotation = {side: tuple(vals) for side, vals in rotation.items()}
    offset = {side: tuple(vals) for side, vals in offset.items()}
    return hands, flip, rotation, offset, slide


def parse_instructions_file(path):
    """Yields one dict per 'model' block:
        {clan, unit_type, model_name,
         hands: {'left'/'right'/'back'/'head': item_or_None},
         flip: {...: bool}, rotation: {...: (x,y,z) deg}, offset: {...: (x,y,z) m},
         slide: {...: meters},
         anims: [{'state': str, 'anim_text': str|None, 'action_id': int|None}, ...]
             (exactly one of anim_text/action_id is set per anim, per the
             two supported '-- anim' line forms below),
         lineno}

    FILE FORMAT (model_definitions.txt -- see module docstring for full
    syntax). Line 1 MUST be the Meshy API key: MESHY_API_KEY="msy_..."
    (read separately via read_api_key(), not part of these entries).

    ITEM PRESETS: 'item <clan> <preset_name> <base_item> [tokens...]'
    lines (parsed by _parse_item_preset_lines in a first pass, may appear
    anywhere) define reusable named poses -- see that function's
    docstring and the module docstring's ITEM PRESETS section.

    MODEL BLOCKS: a 'model <clan> <unit_type> <model_name> <slot
    tokens...>' header line followed immediately by one or more indented
    continuation lines, in EITHER of two forms:
        -- anim <state> anim_text: "<free-form text-to-motion prompt>"
        -- anim <state> action_id: <int>
    The first drives Meshy's Text-to-Motion API (flexible, ~13 credits/
    state incl. rigging+animate). The second retargets a preset from
    Meshy's free Animation Library (GET /openapi/v1/animations/library,
    see https://docs.meshy.ai/en/api/animation-library) directly onto the
    rig (~3 credits/state, deterministic, previewable via that endpoint's
    preview_url) -- use utils/list_animation_library.py to browse/search
    for an action_id. Each model is attached/merged exactly ONCE (by
    attach_hand_item.py batch) and then reused by meshy_animate.py for
    every one of its listed anim entries -- so multiple animation states
    that share the same held-item pose only cost one rig operation.

    Blank lines and lines starting with '#' are ignored everywhere.
    """
    with open(path, "r", encoding="utf-8") as f:
        raw_lines = f.readlines()

    presets = _parse_item_preset_lines(path, raw_lines)

    entries = []
    current = None  # the in-progress model entry, or None
    for lineno, raw_line in enumerate(raw_lines, start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if lineno == 1 and stripped.upper().startswith("MESHY_API_KEY"):
            continue  # reserved API-key line, read separately via read_api_key()

        if stripped.startswith("--"):
            if current is None:
                print(f"WARNING: {path}:{lineno}: '-- anim ...' continuation line with no preceding "
                      f"'model' header -- skipping", file=sys.stderr)
                continue
            m = _MODEL_ANIM_LINE_RE.match(stripped)
            if m:
                current["anims"].append({
                    "state": m.group("state").strip().lower(),
                    "anim_text": m.group("text"),
                    "action_id": None,
                })
                continue
            m = _MODEL_ANIM_ACTION_LINE_RE.match(stripped)
            if m:
                current["anims"].append({
                    "state": m.group("state").strip().lower(),
                    "anim_text": None,
                    "action_id": int(m.group("action_id")),
                })
                continue
            print(f"WARNING: {path}:{lineno}: malformed anim line {stripped!r} -- expected "
                  f'\'-- anim <state> anim_text: "<text>"\' or \'-- anim <state> action_id: <int>\' '
                  f'(see https://docs.meshy.ai/en/api/animation-library) -- skipping', file=sys.stderr)
            continue

        tokens = stripped.split()
        if tokens[0].lower() == "item":
            continue  # preset line, already consumed by _parse_item_preset_lines
        if tokens[0].lower() != "model":
            print(f"WARNING: {path}:{lineno}: expected a 'model' line (or 'item'/'-- anim' line), "
                  f"got {stripped!r} -- skipping", file=sys.stderr)
            continue
        if len(tokens) < 4:
            print(f"WARNING: {path}:{lineno}: 'model' line expected at least 4 fields "
                  f"(model <clan> <unit_type> <model_name>), got {len(tokens)!r} -- skipping", file=sys.stderr)
            continue

        clan, unit_type, model_name = tokens[1], tokens[2], tokens[3]
        hands, flip, rotation, offset, slide = _parse_slot_tokens(
            path, lineno, clan, tokens, presets, start_index=4
        )
        current = {
            "clan": clan, "unit_type": unit_type, "model_name": model_name,
            "hands": hands, "flip": flip, "rotation": rotation, "offset": offset, "slide": slide,
            "anims": [], "lineno": lineno,
        }
        entries.append(current)

    for entry in entries:
        if not entry["anims"]:
            print(f"WARNING: {path}:{entry['lineno']}: model {entry['model_name']!r} has no "
                  f"'-- anim ...' lines (anim_text or action_id) -- it will be attached but never animated",
                  file=sys.stderr)

    return entries


def resolve_output_paths(assets_graphics_root, entry):
    """
    Given one parsed instructions-file model entry (see
    parse_instructions_file), returns (source_path_or_None, final_path):
      source_path -- the unit's plain rigged base mesh
                      (clans/<clan>/<unit_type>/base_mesh/<clan>_<unit_type>_rigged.glb),
                      or None if it doesn't exist yet.
      final_path  -- clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb,
                      the merged (item-attached) mesh meshy_animate.py rigs
                      and reuses for every one of this model's anim states.

    Factored out so other tools (e.g. preview_batch_items.py,
    meshy_animate.py) can locate the same files without duplicating this
    logic.
    """
    clan, unit_type, model_name = entry["clan"], entry["unit_type"], entry["model_name"]
    unit_dir = assets_graphics_root / "clans" / clan / unit_type

    rig_path = unit_dir / "base_mesh" / f"{clan}_{unit_type}_rigged.glb"
    source_path = rig_path if rig_path.is_file() else None
    final_path = unit_dir / "base_mesh" / "_models" / f"{model_name}_final.glb"

    return source_path, final_path


def repair_material_lighting_properties(gltf, label=None):
    """
    Clamps/repairs out-of-glTF-spec or otherwise abnormal material
    values seen in real Meshy exports (confirmed present in the
    ORIGINAL, untouched rig .glb BEFORE attach_hand_item.py ever
    touches it -- this is not something this script introduces, it is
    a corrective pass against values Meshy itself authored):

        - KHR_materials_specular.specularColorFactor / specularFactor
          clamped to the spec-valid [0.0, 1.0] range per component --
          seen as high as [2.0, 2.0, 2.0] (200%% reflectivity, not a
          physically meaningful value), which reads as blown-out,
          washed-out highlights in a standards-compliant PBR renderer
          (observed specifically in Meshys own lighting/rendering).
        - emissiveFactor zeroed to [0, 0, 0] when it is unconditionally
          [1, 1, 1] (full, always-on self-illumination with no actual
          emissive design intent for this character -- confirmed by
          user request) -- this is what produces the spotlight-like
          glow/washed-out look regardless of scene lighting, since an
          emissiveFactor of [1,1,1] makes the whole surface radiate at
          full brightness independent of any light source.
        - metallicFactor/roughnessFactor explicitly set to (0.0, 0.784)
          on the CHARACTER material when it has NO metallicRoughnessTexture
          and no explicit metallicFactor/roughnessFactor of its own. Per
          the glTF 2.0 spec, both default to 1.0 when unset -- i.e. a
          "bare" pass-through character material (no item ever merged
          into it, e.g. a -anim state with every slot left `none`, see
          run_batch's pass-through branch) renders as fully
          metallic/fully rough with NO other repair applied, which
          reads as noticeably darker under this pipeline's fixed sun +
          ambient-only lighting (no reflection probe) than the SAME
          character once merge_item_into_character_mesh() has run --
          that function always bakes an explicit metallic_roughness
          texture whose empty/background pixels use RGB (0, 200, 0),
          i.e. metalness=0, roughness=200/255=0.784 (see
          merge_item_into_character_mesh's channel_defaults). Matching
          that same default here keeps a subject's pass-through states
          (e.g. cast/meditate with no held item) visually consistent
          with its merged states (e.g. attack/idle/walk) instead of
          looking mysteriously ~40% darker.

    Mutates gltf in place. Returns a list of human-readable strings
    describing what was changed (empty if nothing needed repair).
    """
    # Matches merge_item_into_character_mesh's channel_defaults["metallic_roughness"]
    # = (0, 200, 0) -- see this function's docstring above.
    PASS_THROUGH_METALLIC_FACTOR = 0.0
    PASS_THROUGH_ROUGHNESS_FACTOR = 200 / 255
    # emissiveFactor zeroing is scoped to the CHARACTER mesh (i.e. the
    # node named char1) material only -- confirmed by user request that
    # this characters emissive glow is not an intentional design
    # choice, unlike an attached items own material (e.g. small_dagger
    # .glb could legitimately want a genuine emissive glow effect, like
    # a magic rune/gem, so it is left untouched by this rule). The
    # specular clamp below is an objective glTF-spec violation
    # regardless of which material has it, so it applies to every one.
    character_material_indices = set()
    for n in gltf.get("nodes", []):
        if n.get("name") != "char1" or "mesh" not in n:
            continue
        mesh = gltf["meshes"][n["mesh"]]
        for prim in mesh.get("primitives", []):
            if "material" in prim:
                character_material_indices.add(prim["material"])

    changes = []
    for i, mat in enumerate(gltf.get("materials", [])):
        mat_label = f"material[{i}]" + (f" ({mat['name']!r})" if mat.get('name') else "")

        specular_ext = mat.get("extensions", {}).get("KHR_materials_specular")
        if specular_ext:
            color = specular_ext.get("specularColorFactor")
            if color is not None:
                clamped = [min(max(c, 0.0), 1.0) for c in color]
                if clamped != color:
                    specular_ext["specularColorFactor"] = clamped
                    changes.append(f"{mat_label}: specularColorFactor {color} -> {clamped}")
            factor = specular_ext.get("specularFactor")
            if factor is not None:
                clamped_factor = min(max(factor, 0.0), 1.0)
                if clamped_factor != factor:
                    specular_ext["specularFactor"] = clamped_factor
                    changes.append(f"{mat_label}: specularFactor {factor} -> {clamped_factor}")

        emissive = mat.get("emissiveFactor")
        is_full_white = emissive == [1, 1, 1] or emissive == [1.0, 1.0, 1.0]
        if is_full_white and i in character_material_indices:
            mat["emissiveFactor"] = [0.0, 0.0, 0.0]
            changes.append(f"{mat_label}: emissiveFactor {emissive} -> [0.0, 0.0, 0.0]")

        if i in character_material_indices:
            pbr = mat.setdefault("pbrMetallicRoughness", {})
            has_mr_texture = "metallicRoughnessTexture" in pbr
            has_metallic_factor = "metallicFactor" in pbr
            has_roughness_factor = "roughnessFactor" in pbr
            if not has_mr_texture and not has_metallic_factor and not has_roughness_factor:
                pbr["metallicFactor"] = PASS_THROUGH_METALLIC_FACTOR
                pbr["roughnessFactor"] = PASS_THROUGH_ROUGHNESS_FACTOR
                changes.append(
                    f"{mat_label}: metallicFactor/roughnessFactor unset (glTF default 1.0/1.0) -> "
                    f"{PASS_THROUGH_METALLIC_FACTOR}/{PASS_THROUGH_ROUGHNESS_FACTOR:.3f} "
                    f"(matches merge_item_into_character_mesh's metallic_roughness default fill)"
                )

    if changes and label:
        for c in changes:
            print(f"{label}: repaired {c}")
    return changes


def filter_entries(entries, clan=None, unit_type=None, model=None):
    """
    Restricts a parsed entries list (see parse_instructions_file) to those
    matching the given clan/unit_type/model filters (each optional; None
    means skip that filter), for iterating on a single unit/model without
    editing the instructions file or re-processing every entry.
    """
    filtered = entries
    if clan is not None:
        filtered = [e for e in filtered if e["clan"] == clan]
    if unit_type is not None:
        filtered = [e for e in filtered if e["unit_type"] == unit_type]
    if model is not None:
        filtered = [e for e in filtered if e["model_name"] == model]
    return filtered


def run_batch(assets_graphics_root, instructions_path, scale_multiplier, weight_threshold, dry_run,
              clan=None, unit_type=None, model=None):
    entries = parse_instructions_file(instructions_path)
    entries = filter_entries(entries, clan=clan, unit_type=unit_type, model=model)
    if not entries:
        print(f"No entries match the given filter(s) (clan={clan!r}, unit_type={unit_type!r}, model={model!r}) -- nothing to do.", file=sys.stderr)
        return True
    updated = skipped = errors = 0
    item_cache = {}

    for entry in entries:
        clan, unit_type, model_name = entry["clan"], entry["unit_type"], entry["model_name"]
        active_hands = {side: item for side, item in entry["hands"].items() if item}

        unit_dir = assets_graphics_root / "clans" / clan / unit_type
        rig_path, final_path = resolve_output_paths(assets_graphics_root, entry)
        if rig_path is None:
            print(f"[line {entry['lineno']}] {clan}/{unit_type}/{model_name}: rig not found at "
                  f"{unit_dir / 'base_mesh' / f'{clan}_{unit_type}_rigged.glb'} -- skipping", file=sys.stderr)
            skipped += 1
            continue

        try:
            gltf, bin_data = load_glb(str(rig_path))
            nodes = gltf["nodes"]
            world_matrices, _ = compute_world_matrices(nodes)
            hand_joints = find_hand_joints(nodes)
            positions, joints0, weights0, skin_joints, mesh_idx = get_skinned_mesh_data(gltf, bin_data)

            # Fixed-mount attach points (not a hand grip -- no skinned
            # vertex cluster of their own to analyze). Resolved lazily
            # (only if actually requested on this line) since they cost
            # a bit of extra vertex-normal work (compute_forward_axis).
            mount_joints = {}
            mount_anchor_offset = {"back": 0.12, "head": 0.20}  # meters, tuned per-slot
            if entry["hands"].get("back"):
                mount_joints["back"] = find_named_joint(nodes, NECK_NAME_PATTERNS)
            if entry["hands"].get("head"):
                mount_joints["head"] = find_named_joint(nodes, HEAD_NAME_PATTERNS, prefer_leaf=True)

            any_attached = False
            attached_item_node_indices = []
            for side, item_name in active_hands.items():
                is_mount = side in ("back", "head")
                node_idx = mount_joints.get(side) if is_mount else hand_joints.get(side)
                if node_idx is None:
                    joint_kind = "neck" if side == "back" else ("head" if side == "head" else side)
                    print(f"[line {entry['lineno']}] {clan}/{unit_type}: no {joint_kind!r}-matching joint found for '{side}' slot -- skipping", file=sys.stderr)
                    continue

                item_path = assets_graphics_root / "clans" / clan / "_items" / f"{item_name}.glb"
                if not item_path.is_file():
                    print(f"[line {entry['lineno']}] {clan}/{unit_type}: item mesh not found at {item_path} -- skipping '{side}' slot", file=sys.stderr)
                    continue

                cache_key = str(item_path)
                if cache_key not in item_cache:
                    item_cache[cache_key] = load_item_mesh(str(item_path))
                item_data = item_cache[cache_key]

                joint_world_pos = world_matrices[node_idx][:3, 3]

                if is_mount:
                    forward = compute_forward_axis(positions, read_accessor(
                        gltf, bin_data, gltf["meshes"][mesh_idx]["primitives"][0]["attributes"]["NORMAL"],
                    ))
                    if side == "back":
                        # Anchored near the neck, offset BACKWARD (opposite
                        # the characters own forward-facing axis) -- e.g. a
                        # sword/bow mounted across the back.
                        mount_anchor = joint_world_pos - forward * mount_anchor_offset["back"]
                        primary = np.array([0.0, 1.0, 0.0])  # item hangs/mounts vertically along the spine
                    else:  # head
                        # Anchored ABOVE the head, offset vertically along
                        # the spines up axis -- e.g. a VFX socket.
                        mount_anchor = joint_world_pos + np.array([0.0, mount_anchor_offset["head"], 0.0])
                        primary = np.array([0.0, 1.0, 0.0])  # points further upward, away from the head
                    anchor, primary, flat_axis, third = compute_mount_frame(mount_anchor, primary)
                    target_length = item_data['positions'].ptp(axis=0).max() if False else None
                    # Fixed-mount items keep their own OWN authored scale
                    # (no hand-span heuristic available -- mounts arent a
                    # skinned body part with a natural size reference).
                    target_length = None
                else:
                    hand_points = hand_vertex_cluster(positions, joints0, weights0, skin_joints, node_idx, weight_threshold)
                    if len(hand_points) == 0:
                        print(f"[line {entry['lineno']}] {clan}/{unit_type}: no vertices skinned to {side} hand -- skipping that hand", file=sys.stderr)
                        continue
                    anchor, primary, flat_axis, third = compute_grip_frame(joint_world_pos, hand_points)
                    third = fix_lateral_sign(third, side, joint_world_pos)
                    flat_axis = np.cross(third, primary)
                    flat_axis = flat_axis / np.linalg.norm(flat_axis)
                    target_length = hand_span_length(hand_points) * scale_multiplier

                if target_length is None:
                    # Fixed-mount items keep their own authored/native
                    # scale -- target_length must equal the items own
                    # extent ALONG THE GRIP AXIS ITSELF (matching what
                    # fit_item_to_grip computes internally as y_span
                    # AFTER aligning to that axis), so scale_factor there
                    # comes out to 1.0 (no rescaling) rather than an
                    # unrelated bounding-box-diagonal value.
                    proj = item_data["positions"] @ (primary / np.linalg.norm(primary))
                    target_length = float(proj.max() - proj.min())
                    if target_length < 1e-9:
                        target_length = 0.1

                rotation_xyz = entry["rotation"][side]
                offset_xyz = entry["offset"][side]
                slide = entry["slide"][side]
                new_item_node_idx = attach_real_item_to_hand(
                    gltf, bin_data, world_matrices, node_idx, anchor, primary, flat_axis, third,
                    item_data, target_length, entry["flip"][side], name_suffix=f"{side}_{item_name}",
                    skin_joints=skin_joints, rotation_xyz=rotation_xyz, offset_xyz=offset_xyz, slide=slide,
                )
                attached_item_node_indices.append(new_item_node_idx)
                any_attached = True
                slot_label = {"left": "left hand", "right": "right hand", "back": "back", "head": "head"}[side]
                print(
                    f"[line {entry['lineno']}] {clan}/{unit_type}/{model_name}: attached '{item_name}' to {slot_label} "
                    f"(target_length={target_length:.4f}m, flip={entry['flip'][side]}, "
                    f"rotation_xyz={rotation_xyz}, offset_xyz={offset_xyz}, slide={slide})"
                )

            if not any_attached:
                print(
                    f"[line {entry['lineno']}] {clan}/{unit_type}/{model_name}: no hands requested -- "
                    f"writing an unmodified copy of the source mesh (identical to the base reference "
                    f"since nothing is attached, so this model still has its own mesh ready to rig/animate)"
                )

            # Merge any newly-attached item mesh(es) into the character
            # meshs own primitive/material/UV map -- REQUIRED for Meshy
            # compatibility (see merge_item_into_character_mesh docstring):
            # Meshy merges all meshes into one on upload/re-rig, and two
            # separately-UV-mapped meshes each spanning the full [0,1]
            # range collide once merged, which is what was causing the
            # item to inherit the characters texture (or vice versa)
            # specifically after Meshys own re-rig step.
            for item_node_idx in attached_item_node_indices:
                item_node = gltf["nodes"][item_node_idx]
                merge_item_into_character_mesh(
                    gltf, bin_data, char_mesh_idx=mesh_idx,
                    item_mesh_idx=item_node["mesh"], item_node_idx=item_node_idx,
                )

            gltf["buffers"][0]["byteLength"] = len(bin_data)

            # Repair known-abnormal material values seen in real Meshy
            # exports (see repair_material_lighting_properties docstring)
            # -- e.g. out-of-spec specular reflectivity and an
            # unconditional full-white emissiveFactor that was never an
            # intended design choice for this character, both of which
            # produce the washed-out/spotlight-glow look reported when
            # viewing these files in Meshy.
            repair_material_lighting_properties(
                gltf, label=f"[line {entry['lineno']}] {clan}/{unit_type}"
            )

            if dry_run:
                print(f"[line {entry['lineno']}] {clan}/{unit_type}: DRY RUN -- not writing {final_path}")
            else:
                final_path.parent.mkdir(parents=True, exist_ok=True)
                save_glb(str(final_path), gltf, bin_data)
                print(f"[line {entry['lineno']}] {clan}/{unit_type}: wrote {final_path} (source mesh at {rig_path} left untouched)")

                # Structural compliance check (see validate_glb.py) --
                # confirms the item was attached via portable glTF skinning
                # (not the old, Meshy-incompatible bone-parented-node
                # pattern) before this file gets handed off to any external
                # tool. Import here (not at module level) to avoid a
                # circular import, since validate_glb.py itself imports
                # from this module.
                import validate_glb
                report = validate_glb.validate(final_path)
                for e in report.errors:
                    print(f"[line {entry['lineno']}] {clan}/{unit_type}: VALIDATION ERROR: {e}", file=sys.stderr)
                for w in report.warnings:
                    print(f"[line {entry['lineno']}] {clan}/{unit_type}: validation warning: {w}", file=sys.stderr)
                if not report.ok:
                    print(f"[line {entry['lineno']}] {clan}/{unit_type}: {final_path} FAILED compliance check "
                          f"-- see errors above", file=sys.stderr)
                    errors += 1
                    continue
            updated += 1

        except Exception as e:  # noqa: BLE001 -- batch mode: one bad line shouldn't abort the run
            print(f"[line {entry['lineno']}] {clan}/{unit_type}: ERROR: {e}", file=sys.stderr)
            errors += 1

    print(f"\nDone. updated={updated} skipped={skipped} errors={errors} (of {len(entries)} entries)")
    return errors == 0


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def cylinder_command(args):
    gltf, bin_data = load_glb(args.input_glb)
    nodes = gltf["nodes"]

    world_matrices, _ = compute_world_matrices(nodes)
    hand_joints = find_hand_joints(nodes)

    positions, joints0, weights0, skin_joints, mesh_idx = get_skinned_mesh_data(gltf, bin_data)

    sides = ["left", "right"] if args.hand == "both" else [args.hand]
    for side in sides:
        node_idx = hand_joints.get(side)
        if node_idx is None:
            print(f"WARNING: could not find a '{side}' hand joint by name -- skipping.", file=sys.stderr)
            continue

        joint_world_pos = world_matrices[node_idx][:3, 3]
        hand_points = hand_vertex_cluster(positions, joints0, weights0, skin_joints, node_idx, args.weight_threshold)
        if len(hand_points) == 0:
            print(f"WARNING: no vertices found skinned to the {side} hand joint -- skipping.", file=sys.stderr)
            continue

        anchor, primary, flat_axis, third = compute_grip_frame(joint_world_pos, hand_points)
        third = fix_lateral_sign(third, side, joint_world_pos)
        # keep the frame right-handed after any sign flip
        flat_axis = np.cross(third, primary)
        flat_axis = flat_axis / np.linalg.norm(flat_axis)

        node_name = nodes[node_idx].get("name", f"node{node_idx}")
        print(
            f"{side.upper()} hand -> joint '{node_name}' (idx {node_idx}), "
            f"{len(hand_points)} vertices, anchor={anchor.round(4).tolist()}, "
            f"grip_axis={primary.round(4).tolist()}"
        )

        attach_item_to_hand(
            gltf, bin_data, world_matrices, node_idx,
            anchor, primary, flat_axis, third,
            args.radius, args.length, name_suffix=side,
        )

    # keep buffers[0].byteLength in sync
    gltf["buffers"][0]["byteLength"] = len(bin_data)

    save_glb(args.output_glb, gltf, bin_data)
    print(f"Wrote {args.output_glb}")


def batch_command(args):
    # Resolved off the GAME folder this was invoked from (or an explicit
    # --assets-root / $AEVUM_ASSETS_ROOT) -- never off this tools tree.
    # See utils/asset_paths.py.
    from asset_paths import resolve_assets_root, resolve_instructions
    assets_graphics_root = resolve_assets_root(getattr(args, "assets_root", None))
    instructions_path = resolve_instructions(assets_graphics_root, args.instructions)
    print(f"[attach_hand_item] assets root:  {assets_graphics_root}")
    print(f"[attach_hand_item] instructions: {instructions_path}")
    if not instructions_path.is_file():
        print(f"ERROR: instructions file not found: {instructions_path}", file=sys.stderr)
        sys.exit(1)

    # Auto-decimate any oversized source item .glb(s) BEFORE attaching, so
    # this single `batch` invocation is the one command needed to go from
    # "raw Meshy/source item files" to a ready-to-animate merged mesh --
    # no separate manual `decimate_items.py` step. Scoped to just the
    # clan(s) actually referenced by the filtered entries (not every clan in
    # the repo) so a narrow `--clan bard` run doesn't waste time scanning
    # clans that aren't even part of this invocation. Imported here (not at
    # module level) to avoid a circular import, since decimate_items.py
    # itself imports load_glb from this module. Uses decimate_items.py's own
    # hysteresis thresholds (only files > 10000 tris are ever touched, down
    # to 3000) -- see that module's docstring -- so this is a fast no-op
    # skip-check for every item already within budget, and safe to run on
    # every batch invocation, repeatedly, without re-lossifying anything.
    if not args.skip_decimate:
        import decimate_items
        entries_for_scope = filter_entries(
            parse_instructions_file(instructions_path),
            clan=args.clan, unit_type=args.unit_type, model=args.model,
        )
        clans_in_scope = sorted({entry["clan"] for entry in entries_for_scope})
        if not clans_in_scope:
            print(f"No entries match the given filter(s) (clan={args.clan!r}, unit_type={args.unit_type!r}, "
                  f"model={args.model!r}) -- skipping decimation pre-check too.", file=sys.stderr)
        else:
            decimate_errors = 0
            for clan_ in clans_in_scope:
                rc = decimate_items.main_with_args(
                    assets_root=assets_graphics_root,
                    clan=clan_,
                    blender=args.blender,
                    dry_run=args.dry_run,
                )
                if rc != 0:
                    decimate_errors += 1
            if decimate_errors:
                print(f"WARNING: decimation pre-check reported errors for {decimate_errors} clan(s) -- "
                      f"continuing with attach anyway (oversized items may still get merged in).", file=sys.stderr)
            print()

    ok = run_batch(
        assets_graphics_root, instructions_path,
        scale_multiplier=args.scale_multiplier,
        weight_threshold=args.weight_threshold,
        dry_run=args.dry_run,
        clan=args.clan,
        unit_type=args.unit_type,
        model=args.model,
    )

    # By default, immediately re-render a QA preview PNG for every entry
    # right after attaching -- so a single `batch` invocation is enough to
    # both update the .glb(s) AND refresh their preview screenshots,
    # without a separate manual preview_batch_items.py call. Imported here
    # (not at module level) to avoid a circular import, since
    # preview_batch_items.py itself imports from this module.
    if ok and not args.dry_run and not args.no_preview:
        import preview_batch_items
        print()
        preview_rc = preview_batch_items.main_with_args(
            instructions=instructions_path,
            assets_root=assets_graphics_root,
            blender=args.blender,
            direction=None,
            camera_pitch_deg=None,
            render_size=None,
            dry_run=False,
            clan=args.clan,
            unit_type=args.unit_type,
            model=args.model,
        )
        if preview_rc != 0:
            ok = False

    sys.exit(0 if ok else 1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    cyl = sub.add_parser("cylinder", help="attach a placeholder cylinder to one file's hand(s) (original behavior)")
    cyl.add_argument("input_glb")
    cyl.add_argument("output_glb")
    cyl.add_argument("--hand", choices=["left", "right", "both"], default="both")
    cyl.add_argument("--radius", type=float, default=0.015, help="placeholder cylinder radius, meters (default 0.015)")
    cyl.add_argument("--length", type=float, default=0.13, help="placeholder cylinder length, meters (default 0.13)")
    cyl.add_argument("--weight-threshold", type=float, default=0.5)
    cyl.set_defaults(func=cylinder_command)

    batch = sub.add_parser("batch", help="attach real item .glb meshes per scripts/model_definitions.txt")
    batch.add_argument("--assets-root", default=None,
                        help="path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, else cwd)")
    batch.add_argument("--instructions", default=None,
                        help="path to instructions file (default: model_definitions.txt in the assets root)")
    batch.add_argument("--clan", default=None,
                        help="restrict to lines matching this clan (e.g. bard) -- for iterating on a single unit "
                             "without editing the instructions file.")
    batch.add_argument("--unit-type", default=None,
                        help="restrict to lines matching this unit_type (e.g. scout).")
    batch.add_argument("--model", default=None,
                        help="restrict to the 'model' block with this exact model_name (e.g. bard_scout_dagger_raised) "
                             "-- for iterating on a single model without editing the instructions file.")
    batch.add_argument("--scale-multiplier", type=float, default=1.3,
                        help="item's long-axis length = hand bbox diagonal * this multiplier (default 1.3, "
                             "tuned so a 'small_dagger'-sized item lands around 0.3m on a human-scale hand)")
    batch.add_argument("--weight-threshold", type=float, default=0.5)
    batch.add_argument("--dry-run", action="store_true", help="print what would happen without writing any files")
    batch.add_argument("--skip-decimate", action="store_true",
                        help="skip the automatic pre-attach item-decimation pre-check (see decimate_items.py) -- "
                             "by default, every 'batch' invocation first decimates any in-scope clan's oversized "
                             "source item .glb(s) (> 10000 tris) down to 3000 tris before attaching; already-"
                             "decimated items are always a fast no-op skip, so this normally doesn't need disabling.")
    batch.add_argument("--no-preview", action="store_true",
                        help="skip the automatic post-batch QA preview render (see preview_batch_items.py) -- "
                             "by default, every successful non-dry-run 'batch' also re-renders a preview PNG "
                             "for each entry via Blender.")
    batch.add_argument("--blender", default=None,
                        help="explicit path to blender.exe for the automatic preview step, overriding auto-discovery "
                             "(forwarded to preview_batch_items.py -- ignored with --no-preview/--dry-run).")
    batch.set_defaults(func=batch_command)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
