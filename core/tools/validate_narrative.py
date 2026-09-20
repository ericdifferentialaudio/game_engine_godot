#!/usr/bin/env python3
"""Validate a game package's narrative content. Works for ANY game.

    python core/tools/validate_narrative.py games/slack_tide
    python core/tools/validate_narrative.py games/wardens --quiet

Catches what valid JSON and a compiling .ink cannot:

  * a dialogue choice routing to a knot nobody wrote
  * a check against a knowledge id that does not exist
  * an actor placed in a location that is not a place
  * a place linking to a place that is not there
  * an .ink story calling an EXTERNAL that CoreInkBindings will never bind
  * an .ink story gating on a token id the package does not define

Every one of these is the same bug in every game, so the logic lives in
`core/tools/narrative/` and this script is only the file-layout adapter.
A game needing extra rules imports `Findings` and adds to it.

Exits non-zero on any ERROR, so it can gate CI.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from narrative import dialogue_graph as dg          # noqa: E402
from narrative import ink_inspect                   # noqa: E402
from narrative import intel_query as iq             # noqa: E402

REPO = Path(__file__).resolve().parents[2]
BINDINGS = REPO / "core" / "addons" / "game_core" / "narrative" / "core_ink_bindings.gd"

## Files a package may use for each concept. First match wins, so a game can
## call its places `maps.json`, `places.json` or `sites.json` and still be
## validated without configuration.
PLACE_FILES = ("places.json", "maps.json", "sites.json")
PLACE_KEYS = ("places", "maps", "sites")
ACTOR_FILES = ("actors.json", "units.json")
ACTOR_KEYS = ("actors", "units")


def _first_list(pkg: Path, filenames: tuple[str, ...],
                keys: tuple[str, ...]) -> list[dict]:
    """Load the first file that exists and return its first matching list."""
    for name in filenames:
        doc = dg.load_json(pkg / name, required=False)
        if not doc:
            continue
        for key in keys:
            if isinstance(doc.get(key), list):
                return doc[key]
    return []


def validate(pkg: Path, quiet: bool = False) -> int:
    f = dg.Findings()

    # The query grammar this tool enforces must be the one core actually
    # evaluates. Both engine layers previously drifted from it in opposite
    # directions, so this is checked rather than assumed.
    for problem in iq.check_keys_match_core(REPO):
        f.err(f"TOOLING DRIFT: {problem}")

    intel_doc = dg.load_json(pkg / "intel.json", required=False)
    tokens = intel_doc.get("intel", []) if intel_doc else []
    known_ids = {t["id"] for t in tokens if "id" in t}
    groups = set(intel_doc.get("groups", []) or [])

    actors = _first_list(pkg, ACTOR_FILES, ACTOR_KEYS)
    places = _first_list(pkg, PLACE_FILES, PLACE_KEYS)
    place_ids = {p["id"] for p in places if "id" in p}

    # --- generic dialogue + placement checks ---------------------------------
    dg.check_package(actors, known_ids, place_ids, f, extra_valid=groups)
    dg.check_place_links(places, f)

    # --- compiled Ink stories -------------------------------------------------
    ink_dir = pkg / "ink"
    stories = sorted(ink_dir.glob("*.ink.json")) if ink_dir.is_dir() else []
    for story in stories:
        info = ink_inspect.describe(story, BINDINGS, known_ids)
        for name in info.get("unbound", []):
            f.err(f"{story.name}: calls EXTERNAL '{name}' "
                  f"that CoreInkBindings does not bind")
        if not quiet:
            print(f"  {info['name']}: ink v{info['ink_version']}, "
                  f"{len(info['externals'])} externals, "
                  f"{len(info.get('tokens', []))} tokens")

    summary = (f"{len(known_ids)} tokens - {len(actors)} actors - "
               f"{len(place_ids)} places - {len(stories)} ink stories")
    return f.report(summary)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("package", type=Path, help="path to games/<id>")
    ap.add_argument("--quiet", action="store_true",
                    help="suppress the per-story listing")
    args = ap.parse_args()

    pkg = args.package if args.package.is_absolute() else REPO / args.package
    if not pkg.is_dir():
        print(f"No such package: {pkg}", file=sys.stderr)
        return 2
    print(f"Validating {pkg.name}...")
    return validate(pkg, args.quiet)


if __name__ == "__main__":
    raise SystemExit(main())
