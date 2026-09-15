"""
scripts/subjects/monsters.py

SubjectSpec builder for assets/graphics/monsters/<tier>_<monster>/.

Monsters use a simpler animation set than clan units (no bow/cast/defend/
meditate - monsters are wild map encounters, not garrison-able clan troops):
    idle, walk, attack, death

Frame width by tier (tools/build_spritesheets.py FRAME_WIDTHS):
    t1 -> 64px, t2 -> 80px, t3 -> 96px

Source .glb files live anywhere under
    monsters/<tier>_<monster>/base_mesh/**/*.glb
matched to states by filename keyword (see mesh_discovery.py). Frames are
written under
    monsters/<tier>_<monster>/anim_<state>/<direction>/NNNN.png
"""
from __future__ import annotations

from pathlib import Path

from mesh_discovery import discover_state_meshes
from render_config import ANIM_STATES, SubjectSpec

TIER_RENDER_SIZES = {
    "t1": 64,
    "t2": 80,
    "t3": 96,
}

MONSTERS_BY_TIER = {
    "t1": ["basilisk", "goblin", "harpy", "orc", "skeleton", "warg"],
    "t2": ["demon", "drake", "elemental", "troll", "wraith"],
    "t3": [],  # none yet on disk as of 08/30/2026 - add here as they're added
}

MONSTER_STATE_NAMES = ["idle", "walk", "attack", "death"]


def build_specs(
    assets_root: Path,
    tiers: list[str] | None = None,
    monsters: list[str] | None = None,
) -> list[SubjectSpec]:
    """
    `tiers` restricts to e.g. ["t1"]; `monsters` restricts to specific
    monster names regardless of tier (e.g. re-render just "goblin").
    """
    monsters_root = assets_root / "monsters"
    selected_tiers = tiers or list(MONSTERS_BY_TIER)

    specs: list[SubjectSpec] = []
    for tier in selected_tiers:
        for monster in MONSTERS_BY_TIER.get(tier, []):
            if monsters and monster not in monsters:
                continue
            folder_name = f"{tier}_{monster}"
            subject_dir = monsters_root / folder_name
            states = [ANIM_STATES[n] for n in MONSTER_STATE_NAMES]
            state_meshes = discover_state_meshes(
                subject_dir / "base_mesh",
                [s.name for s in states],
            )
            specs.append(
                SubjectSpec(
                    subject_id=f"monsters/{folder_name}",
                    state_meshes=state_meshes,
                    output_root=subject_dir,
                    states=states,
                    render_size=TIER_RENDER_SIZES.get(tier, 64),
                )
            )
    return specs
