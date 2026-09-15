#!/usr/bin/env python3
"""
scripts/main_scripts/rig_base_models.py

"Step 0" of the pipeline (see scripts/README.md): rigs the raw, UNRIGGED
per-unit_type base models at clans/<clan>/_models/<clan>_<unit_type>.glb
(confirmed, across all 120 files in this repo as of this session, to have
zero skins / a single mesh node -- plain Meshy exports with no skeleton at
all) via Meshy's real Rigging API, saving the result to
clans/<clan>/<unit_type>/base_mesh/<clan>_<unit_type>_rigged.glb -- the
exact path attach_hand_item.py batch requires as its rig input (see that
script's resolve_output_paths()).

Without this step, attach_hand_item.py batch has nothing to attach items
to for any (clan, unit_type) that hasn't already been rigged by hand.

FILENAME NORMALIZATION: clans/<clan>/_models/ was found (this session) to
contain several typo'd filenames that don't match the canonical
<clan>_<unit_type> convention (utils/subjects/clans.py's own CLANS/
UNIT_TYPES lists), inherited from the same kind of inconsistency
blender.md already documented for the flat concept-art PNGs:
    bard_chieftan.glb, cleric_chieftan.glb, ... (chieftain -> chieftan, ALL
        12 clans)
    dwaf_embarked.glb        (dwarf_embarked)
    elf_sout.glb              (elf_scout)
    necromance_seeker.glb     (necromancer_seeker)
    chaman_ranged.glb         (shaman_ranged)
This script renames these IN PLACE (same content, new name) the first time
it scans a clan, so every subsequent run resolves <clan>_<unit_type>.glb
directly with no fuzzy keyword matching required. --dry-run reports
planned renames without touching anything.

TIMESTAMP-DRIVEN (see generate_assets.py for the full cascade this script
is one stage of): a (clan, unit_type) is rigged if-and-only-if its raw
_models/<clan>_<unit_type>.glb is newer than the existing
base_mesh/<clan>_<unit_type>_rigged.glb (or that file doesn't exist yet).
Already up-to-date pairs are skipped -- safe/fast/idempotent to re-run
after ANY subset of base models change.

NOTE ON MESH RESOLUTION: an earlier version of this script pre-decimated
the raw base model before every rig() call, based on an initial (mistaken)
theory that Meshy's rigging endpoint silently auto-decimates dense
uploads. Real testing this session disproved that: even a 1,200-triangle
input still came back from Meshy rigged at ~200 triangles, and the
official Meshy API docs document no density-based decimation/quality
parameter at all (only a hard 300,000-face REJECT limit). The low
triangle count Meshy returns appears to be its own standard auto-rigging
output resolution, independent of input density.

REVISED STRATEGY (Meshy mesh output is a THROWAWAY placeholder): because
that ~200-tri ceiling can't be lifted, Meshy's own rigged_character_glb_url
is no longer written directly to base_mesh/<clan>_<unit_type>_rigged.glb.
Instead, for each (clan, unit_type):
    1. The raw base model is uploaded to rig() unmodified (as before) and
       Meshy's rigged/animated result is downloaded to a THROWAWAY path
       under base_mesh/_meshy_raw/ -- only its Armature (skeleton) and any
       animation data are ever used from this file.
    2. scripts/utils/decimate_for_meshy.py is invoked (via Blender,
       --target-triangles=OPTIMIZED_TARGET_TRIANGLES, default 30000) against
       the SAME raw base model to produce a much higher-fidelity, game-ready
       mesh at base_mesh/<clan>_<unit_type>_optimized.glb.
    3. scripts/utils/bind_meshy_rig.py (also via Blender) binds Meshy's
       armature/animation from step 1 onto the optimized mesh from step 2,
       writing the final result to base_mesh/<clan>_<unit_type>_rigged.glb
       -- the same path/contract attach_hand_item.py has always expected,
       so nothing downstream needs to change.

Usage (run from inside scripts/main_scripts/ -- see scripts/README.md's
top-level note):
    python rig_base_models.py --dry-run
    python rig_base_models.py --clan bard
    python rig_base_models.py --clan bard --unit-type scout
    python rig_base_models.py --clan bard --unit-type scout --force
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent             # scripts/main_scripts/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                          # scripts/
_UTILS_DIR = _SCRIPTS_DIR / "utils"
for _p in (_SCRIPT_DIR, _SCRIPTS_DIR, _UTILS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from attach_hand_item import read_api_key  # noqa: E402
from meshy_client import MeshyClient, download_glb, get_credit_total, reset_credit_total  # noqa: E402
from subjects.clans import CLANS, UNIT_TYPES  # noqa: E402
from render import find_blender, _run_filtered  # noqa: E402
from asset_paths import resolve_assets_root, resolve_instructions  # noqa: E402

# See module docstring's "REVISED STRATEGY" -- Meshy's own rigged mesh
# output is a throwaway placeholder; the real in-game mesh is this
# Blender-decimated target instead.
OPTIMIZED_TARGET_TRIANGLES = 30000
_DECIMATE_FOR_MESHY = _UTILS_DIR / "decimate_for_meshy.py"
_BIND_MESHY_RIG = _UTILS_DIR / "bind_meshy_rig.py"

# clan/unit_type filename typos found in clans/<clan>/_models/ this session
# (see module docstring) -- renamed to the canonical <clan>_<unit_type>.glb
# on first scan. Keyed by (clan, unit_type) -> the literal typo'd stem
# (without .glb) actually found on disk.
_KNOWN_TYPOS: dict[tuple[str, str], str] = {}
for _clan in CLANS:
    _KNOWN_TYPOS[(_clan, "chieftain")] = f"{_clan}_chieftan"
_KNOWN_TYPOS[("dwarf", "embarked")] = "dwaf_embarked"
_KNOWN_TYPOS[("elf", "scout")] = "elf_sout"
_KNOWN_TYPOS[("necromancer", "seeker")] = "necromance_seeker"
_KNOWN_TYPOS[("shaman", "ranged")] = "chaman_ranged"


def normalize_filenames(assets_root: Path, *, clan: str | None = None, dry_run: bool = False) -> int:
    """
    Renames any known-typo'd clans/<clan>/_models/*.glb file to its
    canonical <clan>_<unit_type>.glb name. Returns the number of files
    renamed (or that WOULD be renamed, under --dry-run). Safe/idempotent --
    a clan already using canonical names has nothing to rename.
    """
    renamed = 0
    clans = [clan] if clan else CLANS
    for c in clans:
        models_dir = assets_root / "clans" / c / "_models"
        if not models_dir.is_dir():
            continue
        for unit_type in UNIT_TYPES:
            canonical = models_dir / f"{c}_{unit_type}.glb"
            if canonical.is_file():
                continue
            typo_stem = _KNOWN_TYPOS.get((c, unit_type))
            if typo_stem is None:
                continue
            typo_path = models_dir / f"{typo_stem}.glb"
            if not typo_path.is_file():
                continue
            if dry_run:
                print(f"{typo_path}: DRY RUN -- would rename to {canonical.name}")
            else:
                typo_path.rename(canonical)
                print(f"{typo_path}: renamed to {canonical.name}")
            renamed += 1
    return renamed


def discover_base_models(assets_root: Path, *, clan: str | None = None,
                          unit_type: str | None = None) -> list[tuple[str, str, Path]]:
    """All (clan, unit_type, raw_model_path) triples with a canonical
    clans/<clan>/_models/<clan>_<unit_type>.glb present on disk, optionally
    restricted by clan/unit_type."""
    out = []
    clans = [clan] if clan else CLANS
    unit_types = [unit_type] if unit_type else UNIT_TYPES
    for c in clans:
        for u in unit_types:
            p = assets_root / "clans" / c / "_models" / f"{c}_{u}.glb"
            if p.is_file():
                out.append((c, u, p))
    return out


def needs_rig(raw_path: Path, rigged_path: Path) -> bool:
    """True if rigged_path is missing or older than raw_path (timestamp
    cascade -- see generate_assets.py)."""
    if not rigged_path.is_file():
        return True
    return raw_path.stat().st_mtime > rigged_path.stat().st_mtime


def rig_one(client, clan: str, unit_type: str, raw_path: Path, rigged_path: Path, *,
            meshy_raw_path: Path, optimized_path: Path, blender_exe: Path | None,
            dry_run: bool = False) -> bool:
    """Rigs exactly one (clan, unit_type)'s raw base model, writing
    rigged_path -- the FINAL asset (Blender-optimized mesh + Meshy's
    armature/animation), per the module docstring's "REVISED STRATEGY".
    Returns True on success (or on a dry-run that would succeed), False on
    error."""
    label = f"{clan}/{unit_type}"
    if dry_run:
        print(f"{label}: DRY RUN -- would rig {raw_path} -> {meshy_raw_path} (throwaway), "
              f"decimate {raw_path} -> {optimized_path} (target={OPTIMIZED_TARGET_TRIANGLES} tris), "
              f"then bind -> {rigged_path}")
        return True

    # Step 1: rig via Meshy, download its (throwaway) mesh + real armature/animation.
    print(f"{label}: rigging {raw_path} via Meshy (throwaway mesh output) ...")
    try:
        _rig_task_id, rigged_url = client.rig(raw_path)
    except Exception as e:  # noqa: BLE001 -- one bad model shouldn't abort the whole batch
        print(f"{label}: ERROR rigging: {e}", file=sys.stderr)
        return False

    try:
        download_glb(rigged_url, meshy_raw_path)
    except Exception as e:  # noqa: BLE001 -- one bad model shouldn't abort the whole batch
        print(f"{label}: ERROR downloading Meshy rig result: {e}", file=sys.stderr)
        return False
    print(f"{label}: wrote throwaway Meshy rig output -- {meshy_raw_path}")

    # Step 2: Blender-decimate the raw model to the game-ready target budget.
    print(f"{label}: decimating {raw_path} -> {optimized_path} (target={OPTIMIZED_TARGET_TRIANGLES} tris) ...")
    cmd = [
        str(blender_exe), "--background",
        "--python", str(_DECIMATE_FOR_MESHY), "--",
        "--input", str(raw_path), "--output", str(optimized_path),
        "--target-triangles", str(OPTIMIZED_TARGET_TRIANGLES),
    ]
    rc = _run_filtered(cmd)
    if rc != 0:
        print(f"{label}: ERROR: decimate_for_meshy.py exited with code {rc}", file=sys.stderr)
        return False

    # Step 3: bind Meshy's armature/animation onto the optimized mesh.
    print(f"{label}: binding Meshy rig onto optimized mesh -> {rigged_path} ...")
    cmd = [
        str(blender_exe), "--background",
        "--python", str(_BIND_MESHY_RIG), "--",
        "--optimized", str(optimized_path), "--meshy-anim", str(meshy_raw_path),
        "--output", str(rigged_path),
    ]
    rc = _run_filtered(cmd)
    if rc != 0:
        print(f"{label}: ERROR: bind_meshy_rig.py exited with code {rc}", file=sys.stderr)
        return False

    print(f"{label}: wrote {rigged_path}")
    return True


def main_with_args(*, assets_root=None, instructions=None,
                    clan=None, unit_type=None, dry_run=False, force=False, blender=None) -> int:
    assets_root = resolve_assets_root(assets_root)
    instructions = resolve_instructions(assets_root, instructions)
    # blender kwarg is now used again -- see module docstring's "REVISED
    # STRATEGY" (decimate_for_meshy.py / bind_meshy_rig.py both run inside
    # Blender's own Python, requiring blender.exe to be located).
    normalize_filenames(assets_root, clan=clan, dry_run=dry_run)

    models = discover_base_models(assets_root, clan=clan, unit_type=unit_type)
    if not models:
        print(f"No base models found (clan={clan!r}, unit_type={unit_type!r}) under {assets_root / 'clans'} -- "
              f"nothing to do.", file=sys.stderr)
        return 0

    client = None if dry_run else MeshyClient(read_api_key(instructions))

    blender_exe = None
    if not dry_run:
        try:
            blender_exe = find_blender(blender)
        except FileNotFoundError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            return 1

    rigged = skipped = errors = 0
    for c, u, raw_path in models:
        base_mesh_dir = assets_root / "clans" / c / u / "base_mesh"
        rigged_path = base_mesh_dir / f"{c}_{u}_rigged.glb"
        optimized_path = base_mesh_dir / f"{c}_{u}_optimized.glb"
        meshy_raw_path = base_mesh_dir / "_meshy_raw" / f"{c}_{u}_rig_raw.glb"
        if not force and not needs_rig(raw_path, rigged_path):
            print(f"{c}/{u}: {rigged_path} up to date -- skipping")
            skipped += 1
            continue

        ok = rig_one(client, c, u, raw_path, rigged_path,
                     meshy_raw_path=meshy_raw_path, optimized_path=optimized_path,
                     blender_exe=blender_exe, dry_run=dry_run)
        if ok:
            rigged += 1
        else:
            errors += 1

    print(f"\nDone. rigged={rigged} skipped={skipped} errors={errors} (of {len(models)} base models)")
    return 0 if errors == 0 else 1


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--assets-root", type=Path, default=None,
                    help="Path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, else cwd).")
    p.add_argument("--instructions", type=Path, default=None,
                    help="Path to model_definitions.txt (for the Meshy API key -- default: the one in the assets root).")
    p.add_argument("--clan", default=None, help="Restrict to this clan (e.g. bard).")
    p.add_argument("--unit-type", default=None, help="Restrict to this unit_type (e.g. scout).")
    p.add_argument("--dry-run", action="store_true", help="Report what would happen without calling Meshy or writing anything.")
    p.add_argument("--force", action="store_true", help="Re-rig even if the existing rigged file is already up to date.")
    p.add_argument("--blender", default=None, help="Explicit path to blender.exe, overriding auto-discovery.")
    return p


def main() -> int:
    args = build_arg_parser().parse_args()
    # Reset here, not inside main_with_args, since generate_assets.py calls
    # main_with_args directly (possibly once per (clan, unit_type) pair)
    # and owns its own single end-of-run credit reset+report instead (see
    # meshy_animate.py's main() for the identical reasoning).
    if not args.dry_run:
        reset_credit_total()
    rc = main_with_args(
        assets_root=args.assets_root, instructions=args.instructions,
        clan=args.clan, unit_type=args.unit_type,
        dry_run=args.dry_run, force=args.force, blender=args.blender,
    )
    if not args.dry_run:
        print(f"Meshy credits used this run: {get_credit_total()}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
