"""
scripts/subjects/clans.py

SubjectSpec builder for assets/graphics/clans/<clan>/<unit_type>/.

Encodes the per-unit_type animation-state rules from
assets/graphics/blender.md §3 / doc/CLAN_UNIT_ANIMATION_MATRIX.md §2-4:
    - melee unit_types get anim_attack; Elf specialist (Starbow) and
      "ranged" get anim_bow instead
    - magic clans additionally get anim_cast (plus Elf specialist, per the
      open question in ANIMATION_MATRIX §8 - included here, easy to drop)
    - anim_defend/anim_meditate are omitted per unit_type per §3's table
    - warship only gets anim_attack (ranged cannon), pending design for
      anim_defend

Each subject's source .glb files live anywhere under
    <clan>/<unit_type>/base_mesh/**/*.glb
and are matched to animation states by filename keyword (see
mesh_discovery.py) rather than a fixed filename — Meshy exports one .glb per
animation clip with inconsistent names, so this builder resolves per-state
meshes at spec-build time via mesh_discovery.discover_state_meshes().
Frames are written under
    <clan>/<unit_type>/anim_<state>/<direction>/NNNN.png

Per-state source resolution priority (highest wins):
    1. A Meshy-named .glb (filename containing meshy, case-insensitive)
       sitting directly in that states own anim_<state>/ folder -- see
       mesh_discovery.find_meshy_glb_in_anim_folder(). Drop a real,
       animated export from Meshy back into e.g. anim_attack/ and it
       is used for that states 6-direction sprite render instead of
       anything else -- this is how a unit animated in Meshy (using
       one of this pipelines own _final.glb outputs as the starting
       point) actually gets rendered into real sprite frames.
    2. attach_hand_item.py batch -anim <states own generated
       <clan>_<unit_type>_anim_<state>_final.glb (item attached, not
       yet animated in Meshy).
    3. The plain discovered clip/texture/base fallback from base_mesh/
       via mesh_discovery.discover_state_meshes().
"""
from __future__ import annotations

from pathlib import Path

from mesh_discovery import discover_state_meshes, find_meshy_glb_in_anim_folder
from render_config import ANIM_STATES, AnimState, SubjectSpec

CLANS = [
    "fighter", "mage", "cleric", "dwarf", "ranger", "elf",
    "rogue", "monk", "druid", "necromancer", "bard", "shaman",
]

UNIT_TYPES = [
    "chieftain", "common", "advanced", "specialist", "scout",
    "ranged", "defender", "seeker", "embarked", "warship",
]

MAGIC_CLANS = {"mage", "cleric", "elf", "monk", "druid", "necromancer", "bard", "shaman"}


def _states_for(unit_type: str, clan: str) -> list[AnimState]:
    """Mirrors the anim_states_for() rules from the (now-removed) directory
    scaffolding script / blender.md §3 table."""
    is_magic = clan in MAGIC_CLANS
    names: list[str] = []

    if unit_type in ("chieftain", "common", "advanced", "scout"):
        names += ["idle", "walk", "attack"]
        if is_magic:
            names.append("cast")
        names += ["death", "defend", "meditate"]
    elif unit_type == "specialist":
        names += ["idle", "walk"]
        names.append("bow" if clan == "elf" else "attack")
        if is_magic or clan == "elf":
            names.append("cast")
        names += ["death", "defend", "meditate"]
    elif unit_type == "ranged":
        names += ["idle", "walk", "bow", "death", "defend", "meditate"]
    elif unit_type == "defender":
        names += ["idle", "walk", "attack", "death", "defend", "meditate"]
    elif unit_type == "seeker":
        names += ["idle", "walk", "cast", "death", "meditate"]
    elif unit_type == "embarked":
        names += ["idle", "walk", "attack"]
        if clan in MAGIC_CLANS:
            names += ["bow", "cast"]
        names += ["death", "defend"]
    elif unit_type == "warship":
        names += ["idle", "walk", "attack", "death"]
    else:
        raise ValueError(f"Unknown clan unit_type: {unit_type}")

    return [ANIM_STATES[n] for n in names]


def build_specs(
    assets_root: Path,
    clans: list[str] | None = None,
    unit_types: list[str] | None = None,
) -> list[SubjectSpec]:
    """
    Build SubjectSpecs for assets_root/clans/<clan>/<unit_type>/.

    `clans` / `unit_types` optionally restrict the batch (e.g. re-render just
    one clan, or just "warship" across all clans).
    """
    clans_root = assets_root / "clans"
    selected_clans = clans or CLANS
    selected_types = unit_types or UNIT_TYPES

    specs: list[SubjectSpec] = []
    for clan in selected_clans:
        for unit_type in selected_types:
            unit_dir = clans_root / clan / unit_type
            states = _states_for(unit_type, clan)
            state_meshes = discover_state_meshes(
                unit_dir / "base_mesh",
                [s.name for s in states],
            )

            # Per-state item-attachment override: attach_hand_item.py's
            # batch "-anim <state>" mode writes a hand-item-attached mesh
            # to <unit_dir>/anim_<state>/<clan>_<unit_type>_anim_<state>_final.glb
            # (see that script's module docstring). When present, prefer it
            # over the plain discovered clip for that state, so a
            # differently-posed/rotated item (e.g. dagger raised for
            # "attack" vs. lowered for "walk") actually gets rendered.
            for state in states:
                anim_dir = unit_dir / f"anim_{state.name}"
                override_path = anim_dir / f"{clan}_{unit_type}_anim_{state.name}_final.glb"
                if override_path.is_file():
                    state_meshes[state.name] = override_path

                # Higher-priority override: a Meshy-animated .glb dropped
                # back into anim_<state>/ after animating this states
                # (item-attached or plain) mesh in Meshy -- see
                # mesh_discovery.find_meshy_glb_in_anim_folder(). Once this
                # exists it supersedes BOTH the plain discovered clip AND
                # the attach_hand_item.py _final.glb override above, since
                # it carries the real baked animation this pipeline
                # ultimately needs to render into 6-direction sprite
                # frames.
                meshy_path = find_meshy_glb_in_anim_folder(anim_dir)
                if meshy_path is not None:
                    state_meshes[state.name] = meshy_path

            specs.append(
                SubjectSpec(
                    subject_id=f"clans/{clan}/{unit_type}",
                    state_meshes=state_meshes,
                    output_root=unit_dir,
                    states=states,
                )
            )
    return specs
