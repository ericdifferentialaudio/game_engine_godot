#!/usr/bin/env python3
"""
generate_assets/utils/list_animation_library.py

Browses/searches Meshy's free Animation Library (GET
/openapi/v1/animations/library -- see
https://docs.meshy.ai/en/api/animation-library) to help you pick an
action_id for a '-- anim <state> action_id: <int>' line in
model_definitions.txt (see attach_hand_item.parse_instructions_file's
docstring, and meshy_animate.py's module docstring for how action_id
entries are animated). This call consumes NO Meshy credits -- safe to run
as often as you like.

Usage:
    python list_animation_library.py --search attack
    python list_animation_library.py --category Fighting
    python list_animation_library.py --category Fighting --sub-category AttackingwithWeapon
    python list_animation_library.py --action-ids 4,92
    python list_animation_library.py --search walk --json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent           # generate_assets/utils/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                        # generate_assets/
_MAIN_SCRIPTS_DIR = _SCRIPTS_DIR / "main_scripts"
for _p in (_SCRIPTS_DIR, _SCRIPT_DIR, _MAIN_SCRIPTS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from attach_hand_item import read_api_key  # noqa: E402
from meshy_client import MeshyClient  # noqa: E402
from asset_paths import resolve_assets_root, resolve_instructions  # noqa: E402


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--assets-root", type=Path, default=None,
                    help="Path to the game's graphics/ assets folder, for locating the API key "
                         "(default: $AEVUM_ASSETS_ROOT, else cwd). Ignored if $MESHY_API_KEY is set.")
    p.add_argument("--instructions", type=Path, default=None,
                    help="Path to model_definitions.txt, for the Meshy API key (default: the one "
                         "in the assets root). Ignored if $MESHY_API_KEY is set.")
    p.add_argument("--search", default=None, help="Case-insensitive substring match on name or key.")
    p.add_argument("--category", default=None,
                    choices=["WalkAndRun", "BodyMovements", "DailyActions", "Fighting", "Dancing"],
                    help="Exact match on category.")
    p.add_argument("--sub-category", default=None, help="Exact match on sub_category.")
    p.add_argument("--action-ids", default=None,
                    help="Comma-separated action_id list to resolve specific ids (max 200).")
    p.add_argument("--json", action="store_true", help="Print raw JSON instead of a formatted table.")
    return p


def main() -> int:
    args = build_arg_parser().parse_args()
    assets_root = resolve_assets_root(args.assets_root)
    instructions_path = resolve_instructions(assets_root, args.instructions)

    try:
        api_key = read_api_key(instructions_path)
    except (ValueError, OSError) as e:
        print(f"ERROR: could not resolve a Meshy API key: {e}", file=sys.stderr)
        return 1

    action_ids = None
    if args.action_ids:
        try:
            action_ids = [int(x.strip()) for x in args.action_ids.split(",") if x.strip()]
        except ValueError:
            print(f"ERROR: --action-ids must be a comma-separated list of integers, got {args.action_ids!r}",
                  file=sys.stderr)
            return 1

    client = MeshyClient(api_key)
    animations = client.list_animation_library(
        search=args.search, category=args.category, sub_category=args.sub_category, action_ids=action_ids,
    )

    if args.json:
        print(json.dumps(animations, indent=2))
        return 0

    if not animations:
        print("No animations matched.", file=sys.stderr)
        return 0

    print(f"{'action_id':>9}  {'name':<32} {'category':<16} {'sub_category':<24} key")
    for a in animations:
        print(f"{a['action_id']:>9}  {a['name']:<32} {a['category']:<16} {a.get('sub_category', ''):<24} {a['key']}")
    print(f"\n{len(animations)} animation(s). Use the action_id in a "
          f"'-- anim <state> action_id: <int>' line in model_definitions.txt.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
