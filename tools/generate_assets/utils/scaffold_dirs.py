"""
scripts/scaffold_dirs.py

Directory-scaffolding script for assets/graphics/clans/<clan>/<unit_type>/,
implementing blender.md §2's target structure (see that file for the full
spec/rationale). No `bpy` dependency -- plain Python, safe to run outside
Blender.

For every (clan, unit_type) pair this creates (if missing; never deletes,
renames, or touches existing files):
    base_image/
    base_mesh/
    spritesheet/image/
    spritesheet/json/
    anim_<state>/<direction>/   for every state in
                                subjects.clans._states_for(unit_type, clan)
                                and every direction in render_config.DIRECTIONS

_states_for() (imported from subjects/clans.py, the SAME function the render
pipeline itself uses to decide which anim_<state> folders a given clan/
unit_type combination needs) is the single source of truth here, so this
script's output can never drift from what render_cli.py actually expects to
render into -- e.g. "scout" gets anim_idle/anim_walk/anim_attack/anim_death/
anim_defend/anim_meditate (+ anim_cast for magic clans), "ranged" gets
anim_bow instead of anim_attack, etc. (full table: blender.md §3).

This is purely additive: it never deletes, renames, or moves anything, and
never touches file contents (mkdir(parents=True, exist_ok=True) only) --
per blender.md §4's explicit scope note, existing flat concept-art PNGs and
any already-populated anim_XXX/ frames are left completely alone.

Usage (plain `python`, run from inside scripts/ -- see scripts/README.md's
top-level note):
    python utils/scaffold_dirs.py --dry-run
    python utils/scaffold_dirs.py --dry-run --clan bard
    python utils/scaffold_dirs.py --clan bard --unit-type scout
    python utils/scaffold_dirs.py            # scaffolds all 12 clans x 10 unit_types
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from render_config import DIRECTIONS  # noqa: E402
from subjects.clans import CLANS, UNIT_TYPES, _states_for  # noqa: E402

from asset_paths import resolve_assets_root  # noqa: E402


def planned_dirs(unit_dir: Path, unit_type: str, clan: str) -> list[Path]:
    """All directories (relative to unit_dir's parent) this unit_type/clan
    pair should have, per blender.md §2's target structure."""
    dirs = [
        unit_dir / "base_image",
        unit_dir / "base_mesh",
        unit_dir / "spritesheet" / "image",
        unit_dir / "spritesheet" / "json",
    ]
    for state in _states_for(unit_type, clan):
        anim_dir = unit_dir / f"anim_{state.name}"
        for direction in DIRECTIONS:
            dirs.append(anim_dir / direction)
    return dirs


def scaffold(assets_root: Path, clans: list[str], unit_types: list[str], dry_run: bool) -> dict[str, int]:
    clans_root = assets_root / "clans"
    created = existing = 0

    for clan in clans:
        for unit_type in unit_types:
            unit_dir = clans_root / clan / unit_type
            dirs = planned_dirs(unit_dir, unit_type, clan)
            new_here = [d for d in dirs if not d.is_dir()]

            if new_here:
                print(f"{clan}/{unit_type}: {len(new_here)} folder(s) to create"
                      f"{' (DRY RUN)' if dry_run else ''}:")
                for d in new_here:
                    rel = d.relative_to(clans_root)
                    print(f"    {rel}")
                    if not dry_run:
                        d.mkdir(parents=True, exist_ok=True)
                created += len(new_here)
            existing += len(dirs) - len(new_here)

    return {"created": created, "existing": existing}


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Scaffold the base_image/base_mesh/anim_<state>/spritesheet folder "
                    "structure for clans/<clan>/<unit_type>/ per blender.md §2. "
                    "Purely additive -- never deletes/renames/touches existing files."
    )
    p.add_argument("--assets-root", type=Path, default=None,
                    help="Path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, else cwd).")
    p.add_argument("--clan", action="append", dest="clans", default=None,
                    help="Restrict to one clan (repeatable). Default: all 12 clans.")
    p.add_argument("--unit-type", action="append", dest="unit_types", default=None,
                    help="Restrict to one unit_type (repeatable). Default: all 10 unit_types.")
    p.add_argument("--dry-run", action="store_true",
                    help="Print what would be created without creating anything.")
    return p


def main() -> int:
    args = build_arg_parser().parse_args()
    clans = args.clans or CLANS
    unit_types = args.unit_types or UNIT_TYPES

    unknown_clans = [c for c in clans if c not in CLANS]
    unknown_types = [u for u in unit_types if u not in UNIT_TYPES]
    if unknown_clans:
        print(f"ERROR: unknown clan(s): {unknown_clans} (known: {CLANS})", file=sys.stderr)
        return 1
    if unknown_types:
        print(f"ERROR: unknown unit_type(s): {unknown_types} (known: {UNIT_TYPES})", file=sys.stderr)
        return 1

    counts = scaffold(resolve_assets_root(args.assets_root), clans, unit_types, args.dry_run)
    verb = "would be created" if args.dry_run else "created"
    print(f"\nDone. {counts['created']} folder(s) {verb}, {counts['existing']} already present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
