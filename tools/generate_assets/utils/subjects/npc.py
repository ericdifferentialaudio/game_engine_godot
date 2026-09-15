"""
scripts/subjects/npc.py

SubjectSpec builder for assets/graphics/npc/.

NPCs are currently flat, single-pose reference art
(npc_<name>_<n>.png - e.g. npc_shopkeep_1.png, npc_join_fighter.png) with no
combat animation needs; they're map/dialogue portraits, not playable units.
This builder gives them just `idle` (a light breathing/blink loop) and
`walk` (for the handful that wander town tiles, e.g. npc_street_*,
npc_town_*), skipping the combat state machine entirely.

Subjects are named after the existing flat file stem (prefix "npc_" and any
trailing numeric variant suffix stripped), each becoming its own subject
folder so multiple numbered variants of the same character concept
(npc_pub_1..8, npc_castle_1..9) don't collide - pass explicit `names` to
build_specs to control this precisely for now, since NPC naming is looser
than clans/dragons/monsters.

Source .glb files live anywhere under
    npc/<name>/base_mesh/**/*.glb
matched to states by filename keyword (see mesh_discovery.py). Frames are
written under
    npc/<name>/anim_<state>/<direction>/NNNN.png
"""
from __future__ import annotations

from pathlib import Path

from mesh_discovery import discover_state_meshes
from render_config import ANIM_STATES, SubjectSpec

NPC_STATE_NAMES = ["idle", "walk"]


def discover_names(assets_root: Path) -> list[str]:
    """
    Best-effort enumeration of NPC subject names from the existing flat
    art tree (npc/npc_<name>.png -> "<name>"), for callers that want to seed
    `names` from what's already on disk rather than hand-listing it.
    """
    npc_root = assets_root / "npc"
    names: set[str] = set()
    for png in npc_root.glob("npc_*.png"):
        stem = png.stem[len("npc_"):]
        names.add(stem)
    return sorted(names)


def build_specs(
    assets_root: Path,
    names: list[str] | None = None,
) -> list[SubjectSpec]:
    """
    `names` should be explicit NPC subject folder names (see module docstring
    for why auto-discovery from the flat file list is not used by default).
    If omitted, falls back to discover_names() as a starting point.
    """
    npc_root = assets_root / "npc"
    selected_names = names or discover_names(assets_root)

    specs: list[SubjectSpec] = []
    for name in selected_names:
        subject_dir = npc_root / name
        states = [ANIM_STATES[n] for n in NPC_STATE_NAMES]
        state_meshes = discover_state_meshes(
            subject_dir / "base_mesh",
            [s.name for s in states],
        )
        specs.append(
            SubjectSpec(
                subject_id=f"npc/{name}",
                state_meshes=state_meshes,
                output_root=subject_dir,
                states=states,
            )
        )
    return specs
