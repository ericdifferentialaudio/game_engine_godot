"""
scripts/preview_batch_items.py

Plain-Python wrapper (run with a normal `python`, NOT Blender's own
interpreter) that renders a one-shot QA preview PNG for EVERY entry in
scripts/model_definitions.txt (or a custom --instructions file), so you can
eyeball how each hand-item attachment (rig or per-animation-state variant)
actually looks before spending time animating it.

For each parsed 'model' block it:
    1. Resolves that model's merged output .glb the same way
       attach_hand_item.py's own batch mode does
       (attach_hand_item.resolve_output_paths() -- shared logic, so this
       can never disagree with where batch mode actually wrote the file):
         clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb
    2. If that .glb doesn't exist yet (attach_hand_item.py batch hasn't been
       run, or that model errored/was skipped), warns and skips it rather
       than silently doing nothing.
    3. Otherwise invokes Blender headlessly against the existing
       render_final_preview.py (one PNG per mesh, same fixed camera/
       lighting as the main sprite pipeline) writing
       "<final_stem>_preview.png" next to that .glb -- e.g.
         clans/bard/scout/base_mesh/_models/bard_scout_dagger_raised_final_preview.png

Usage (run from inside scripts/ -- see scripts/README.md's top-level note;
paths otherwise resolve off this script's own location regardless of cwd):
    python utils/preview_batch_items.py
    python utils/preview_batch_items.py --dry-run
    python utils/preview_batch_items.py --instructions model_definitions.txt
    python utils/preview_batch_items.py --direction e --camera-pitch-deg 30
    python utils/preview_batch_items.py --blender "C:\\path\\to\\blender.exe"

Blender discovery reuses render.py's find_blender() (same --blender /
AEVUM_BLENDER / PATH / well-known-install-dir search order), so there's
only one place that logic lives.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

# This file lives in scripts/utils/ -- scripts/main_scripts/ (attach_hand_item.py,
# render.py), scripts/ itself, and scripts/utils/ (this file's own dir, e.g.
# render_final_preview.py) all need to be importable regardless of cwd.
_SCRIPT_DIR = Path(__file__).resolve().parent           # scripts/utils/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                        # scripts/
_MAIN_SCRIPTS_DIR = _SCRIPTS_DIR / "main_scripts"
for _p in (_SCRIPTS_DIR, _SCRIPT_DIR, _MAIN_SCRIPTS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from attach_hand_item import parse_instructions_file, resolve_output_paths, filter_entries  # noqa: E402
from render import find_blender, _run_filtered  # noqa: E402
from asset_paths import resolve_assets_root, resolve_instructions  # noqa: E402

_RENDER_FINAL_PREVIEW = _SCRIPT_DIR / "render_final_preview.py"


def _copy_into_common_preview_dir(assets_root, clan, unit_type, model_name, preview_path):
    """
    Copies a just-rendered preview PNG into a shared, flat
    clans/<clan>/_previews/ directory (in addition to leaving the
    original next to its .glb, which other tooling -- e.g.
    attach_hand_item.py batchs auto-preview step -- already relies on),
    named "<unit_type>__<model_name>_preview.png" so every preview for a
    clan can be scrolled through in one folder without digging into each
    units nested base_mesh/_models/ subfolder.
    """
    common_dir = assets_root / "clans" / clan / "_previews"
    common_dir.mkdir(parents=True, exist_ok=True)
    dest = common_dir / f"{unit_type}__{model_name}_preview.png"
    shutil.copyfile(preview_path, dest)
    return dest


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Render a one-shot Blender QA preview PNG for every entry in "
                    "an attach_hand_item.py batch instructions file."
    )
    p.add_argument("--instructions", type=Path, default=None,
                    help="Path to the instructions file (default: model_definitions.txt in the assets root).")
    p.add_argument("--clan", default=None,
                    help="Restrict to lines matching this clan (e.g. bard).")
    p.add_argument("--unit-type", default=None,
                    help="Restrict to lines matching this unit_type (e.g. scout).")
    p.add_argument("--model", default=None,
                    help="Restrict to the 'model' block with this exact model_name (e.g. bard_scout_dagger_raised).")
    p.add_argument("--assets-root", type=Path, default=None,
                    help="Path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, else cwd).")
    p.add_argument("--blender", default=None,
                    help="Explicit path to blender.exe, overriding auto-discovery.")
    p.add_argument("--direction", default=None,
                    help="Forwarded to render_final_preview.py's --direction "
                         "(default: that script's own default, 'se').")
    p.add_argument("--camera-pitch-deg", type=float, default=None,
                    help="Forwarded to render_final_preview.py's --camera-pitch-deg "
                         "(default: that script's own default, 0 -- flat QA shot).")
    p.add_argument("--render-size", type=int, default=None,
                    help="Forwarded to render_final_preview.py's --render-size.")
    p.add_argument("--dry-run", action="store_true",
                    help="Print what would be rendered without invoking Blender.")
    return p


def main_with_args(*, instructions=None, assets_root=None, blender=None,
                    direction=None, camera_pitch_deg=None, render_size=None, dry_run=False,
                    clan=None, unit_type=None, model=None) -> int:
    """
    Core entry point, callable directly (not just via CLI argv) -- used by
    attach_hand_item.py's `batch` subcommand to automatically re-render
    previews right after attaching, without shelling out to a second
    `python preview_batch_items.py` process.
    """
    assets_root = resolve_assets_root(assets_root)
    instructions_path = resolve_instructions(assets_root, instructions)
    if not instructions_path.is_file():
        print(f"ERROR: instructions file not found: {instructions_path}", file=sys.stderr)
        return 1

    try:
        blender_exe = None if dry_run else find_blender(blender)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    entries = parse_instructions_file(instructions_path)
    entries = filter_entries(entries, clan=clan, unit_type=unit_type, model=model)
    if not entries:
        print(f"No entries match the given filter(s) (clan={clan!r}, unit_type={unit_type!r}, model={model!r}) -- nothing to do.", file=sys.stderr)
        return 0
    rendered = skipped = errors = 0

    for entry in entries:
        clan, unit_type, model_name = entry["clan"], entry["unit_type"], entry["model_name"]
        label = f"{clan}/{unit_type}/{model_name}"

        source_path, final_path = resolve_output_paths(assets_root, entry)
        if source_path is None:
            print(f"[line {entry['lineno']}] {label}: source mesh not resolved -- "
                  f"run attach_hand_item.py batch first -- skipping preview", file=sys.stderr)
            skipped += 1
            continue
        if not final_path.is_file():
            print(f"[line {entry['lineno']}] {label}: {final_path} does not exist yet -- "
                  f"run attach_hand_item.py batch first -- skipping preview", file=sys.stderr)
            skipped += 1
            continue

        out_path = final_path.with_name(final_path.stem + "_preview.png")

        cmd_args = ["--mesh", str(final_path), "--out", str(out_path)]
        if direction is not None:
            cmd_args += ["--direction", direction]
        if camera_pitch_deg is not None:
            cmd_args += ["--camera-pitch-deg", str(camera_pitch_deg)]
        if render_size is not None:
            cmd_args += ["--render-size", str(render_size)]

        if dry_run:
            print(f"[line {entry['lineno']}] {label}: DRY RUN -- would render {final_path} -> {out_path}")
            rendered += 1
            continue

        cmd = [
            str(blender_exe), "--background",
            "--python", str(_RENDER_FINAL_PREVIEW), "--",
            *cmd_args,
        ]
        print(f"[line {entry['lineno']}] {label}: rendering {final_path} -> {out_path}", flush=True)
        rc = _run_filtered(cmd)
        if rc != 0:
            print(f"[line {entry['lineno']}] {label}: ERROR: Blender exited with code {rc}", file=sys.stderr)
            errors += 1
            continue
        rendered += 1

        _copy_into_common_preview_dir(assets_root, clan, unit_type, model_name, out_path)

    print(f"\nDone. rendered={rendered} skipped={skipped} errors={errors} (of {len(entries)} entries)")
    return 0 if errors == 0 else 1


def main() -> int:
    args = build_arg_parser().parse_args()
    return main_with_args(
        instructions=args.instructions,
        assets_root=args.assets_root,
        blender=args.blender,
        direction=args.direction,
        camera_pitch_deg=args.camera_pitch_deg,
        render_size=args.render_size,
        dry_run=args.dry_run,
        clan=args.clan,
        unit_type=args.unit_type,
        model=args.model,
    )


if __name__ == "__main__":
    sys.exit(main())
