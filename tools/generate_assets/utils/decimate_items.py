"""
scripts/decimate_items.py

Plain-Python wrapper (run with a normal `python`, NOT Blender's own
interpreter) that scans every clans/<clan>/_items/*.glb file across ALL
clans, and decimates (via Blender's Decimate modifier, see
decimate_for_meshy.py) any file whose total triangle count exceeds
--threshold-triangles (default 10000) down to --target-triangles (default
3000), OVERWRITING the original file in place (no backups -- see session
log for rationale).

HYSTERESIS: the trigger threshold (10000) is intentionally much higher than
the target (3000) it decimates down to. This is what makes the script SAFE
TO RE-RUN against files it has already downsampled: an already-processed
file sits at ~3000 tris, which is nowhere near the 10000 trigger, so a
rerun (even repeated many times) will just report it as skipped and leave
it untouched -- no repeated lossy re-decimation, no corruption. Use
--dry-run at any time to confirm nothing would change before doing a real
run.

WHY THIS EXISTS: real item source files in this repo have been found as
high as ~3,074,912 triangles (every clans/<clan>/_items/<clan>_banner.glb)
and ~107,090 triangles (clans/bard/_items/small_dagger.glb) -- absurdly
dense for small handheld/mounted props. This matters for two independent
reasons:
    1. attach_hand_item.py merges an item's full geometry into the
       character mesh before handing it to Meshy for rigging/animation;
       an oversized item mesh alone can push the MERGED file's total
       triangle count high enough to trigger Meshy's own emergency
       auto-decimation fallback on the CHARACTER too (see
       decimate_for_meshy.py's module docstring for the full story).
    2. Every one of these .glb files is committed to this git repo --
       multi-hundred-megabyte source item files bloat repo size for no
       visual benefit at the small scale these props are actually
       rendered at (isometric sprite frames).

Usage (run from inside scripts/ -- see scripts/README.md's top-level note;
paths otherwise resolve off this script's own location regardless of cwd):
    python utils/decimate_items.py --dry-run
    python utils/decimate_items.py
    python utils/decimate_items.py --threshold-triangles 10000 --target-triangles 3000 --clan bard
    python utils/decimate_items.py --blender "C:\\path\\to\\blender.exe"

Blender discovery reuses render.py's find_blender() (same --blender /
AEVUM_BLENDER / PATH / well-known-install-dir search order).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# This file lives in scripts/utils/ -- scripts/main_scripts/ (attach_hand_item.py,
# render.py), scripts/ itself, and scripts/utils/ (this file's own dir) all
# need to be importable regardless of cwd.
_SCRIPT_DIR = Path(__file__).resolve().parent           # scripts/utils/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                        # scripts/
_MAIN_SCRIPTS_DIR = _SCRIPTS_DIR / "main_scripts"
for _p in (_SCRIPTS_DIR, _SCRIPT_DIR, _MAIN_SCRIPTS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from attach_hand_item import load_glb  # noqa: E402
from render import find_blender, _run_filtered  # noqa: E402
from asset_paths import resolve_assets_root  # noqa: E402

DEFAULT_TARGET_TRIANGLES = 3000
DEFAULT_THRESHOLD_TRIANGLES = 10000  # trigger point -- must stay well above DEFAULT_TARGET_TRIANGLES
                                      # so a rerun against already-decimated files is a no-op (hysteresis).
_DECIMATE_FOR_MESHY = _SCRIPT_DIR / "decimate_for_meshy.py"


def count_triangles(glb_path: Path) -> int:
    """Total triangle count across every mesh primitive in glb_path (sum
    of indices_count // 3 for indexed primitives)."""
    gltf, _bin_data = load_glb(str(glb_path))
    total = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "indices" not in prim:
                continue
            idx_count = gltf["accessors"][prim["indices"]]["count"]
            total += idx_count // 3
    return total


def discover_item_files(assets_root: Path, clan: str | None = None) -> list[Path]:
    """All clans/<clan>/_items/*.glb files, optionally restricted to one
    clan."""
    pattern = f"clans/{clan}/_items/*.glb" if clan else "clans/*/_items/*.glb"
    return sorted(assets_root.glob(pattern))


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--assets-root", type=Path, default=None,
                    help="Path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, else cwd).")
    p.add_argument("--clan", default=None, help="Restrict to this clan's _items/ folder (e.g. bard).")
    p.add_argument("--threshold-triangles", type=int, default=DEFAULT_THRESHOLD_TRIANGLES,
                    help=f"Trigger point -- only files with STRICTLY MORE triangles than this are "
                         f"decimated at all (default: {DEFAULT_THRESHOLD_TRIANGLES}). Kept well above "
                         f"--target-triangles on purpose (hysteresis) so re-running this script against "
                         f"already-decimated files is always a safe no-op.")
    p.add_argument("--target-triangles", type=int, default=DEFAULT_TARGET_TRIANGLES,
                    help=f"Triangle budget that files over --threshold-triangles are decimated down to "
                         f"(default: {DEFAULT_TARGET_TRIANGLES}).")
    p.add_argument("--blender", default=None, help="Explicit path to blender.exe, overriding auto-discovery.")
    p.add_argument("--dry-run", action="store_true",
                    help="Report which files would be decimated (and their current triangle counts) "
                         "without invoking Blender or writing anything.")
    return p


def main_with_args(*, assets_root=None, clan=None,
                    threshold_triangles=DEFAULT_THRESHOLD_TRIANGLES,
                    target_triangles=DEFAULT_TARGET_TRIANGLES,
                    blender=None, dry_run=False) -> int:
    assets_root = resolve_assets_root(assets_root)
    files = discover_item_files(assets_root, clan=clan)
    if not files:
        print(f"No item files found (clan={clan!r}) under {assets_root / 'clans'} -- nothing to do.", file=sys.stderr)
        return 0

    try:
        blender_exe = None if dry_run else find_blender(blender)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    decimated = skipped = errors = 0

    for path in files:
        try:
            current_tris = count_triangles(path)
        except Exception as e:  # noqa: BLE001 -- one bad file shouldn't abort the whole scan
            print(f"{path}: ERROR reading triangle count: {e}", file=sys.stderr)
            errors += 1
            continue

        if current_tris <= threshold_triangles:
            print(f"{path}: {current_tris} tris <= {threshold_triangles} (threshold) -- skipping")
            skipped += 1
            continue

        if dry_run:
            print(f"{path}: {current_tris} tris > {threshold_triangles} (threshold) -- DRY RUN, "
                  f"would decimate to {target_triangles}")
            decimated += 1
            continue

        print(f"{path}: {current_tris} tris > {threshold_triangles} (threshold) -- decimating in place "
              f"to {target_triangles} ...", flush=True)
        cmd = [
            str(blender_exe), "--background",
            "--python", str(_DECIMATE_FOR_MESHY), "--",
            "--input", str(path), "--output", str(path),
            "--target-triangles", str(target_triangles),
        ]
        rc = _run_filtered(cmd)
        if rc != 0:
            print(f"{path}: ERROR: Blender exited with code {rc}", file=sys.stderr)
            errors += 1
            continue

        try:
            final_tris = count_triangles(path)
            print(f"{path}: decimated {current_tris} -> {final_tris} tris")
        except Exception as e:  # noqa: BLE001 -- decimation succeeded; recount failure is just informational
            print(f"{path}: WARNING: decimation succeeded but re-counting triangles failed: {e}", file=sys.stderr)
        decimated += 1

    print(f"\nDone. decimated={decimated} skipped={skipped} errors={errors} (of {len(files)} item files)")
    return 0 if errors == 0 else 1


def main() -> int:
    args = build_arg_parser().parse_args()
    return main_with_args(
        assets_root=args.assets_root,
        clan=args.clan,
        threshold_triangles=args.threshold_triangles,
        target_triangles=args.target_triangles,
        blender=args.blender,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    sys.exit(main())
