#!/usr/bin/env python3
"""Scaffold a new game package under games/<id>/ with valid starter data.

Usage:
  python tools/new_game.py my_game --title "My Game" [--topology hex|square_iso]
                                   [--turns sequential|simultaneous|wego|realtime_pause]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMES_DIR = ROOT / "games"


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def starter_data(game_id: str, title: str, topology: str, turns: str) -> dict[str, dict]:
    """All starter documents keyed by file stem."""
    return {
        "game": {
            "id": game_id, "title": title, "version": "0.1.0", "description": "",
            "grid": {"topology": topology, "orientation": "pointy", "wrap_x": False},
            "turns": {"mode": turns, "timer_seconds": 0, "ticks_per_turn": 10, "seconds_per_tick": 1.0},
            "calendar": {"start_year": 1, "years_per_turn": 1, "eras": [{"id": "dawn", "label": "The Dawn", "from_turn": 1}]},
            "start_map": "overworld", "player_faction": "player", "max_map_depth": 3, "seed": 42,
            "currencies": ["gold"],
            "stats": {"health": 10, "strength": 2, "defense": 2, "moves": 2, "sight": 2, "perception": 0},
            "rules": {"fog": {"shared_vision_allies": True}, "intel": {"observe_units": True, "observe_sites": True}},
        },
        "terrains": {"terrains": [
            {"id": "ocean", "display_name": "Ocean", "domain": "sea", "color": "#1d4e89", "elevation": -1},
            {"id": "grassland", "display_name": "Grassland", "domain": "land", "color": "#6aa84f", "yields": {"gold": 1}},
            {"id": "hills", "display_name": "Hills", "domain": "land", "move_cost": 2, "color": "#8b7d5a", "elevation": 1, "defense_bonus": 25},
            {"id": "mountain", "display_name": "Mountain", "domain": "land", "passable": False, "color": "#6e6e73", "elevation": 2, "blocks_sight": True},
        ], "features": [
            {"id": "forest", "display_name": "Forest", "move_cost": 1, "blocks_sight": True, "defense_bonus": 25,
             "allowed_on": ["grassland", "hills"], "spawn_chance": 0.2},
        ]},
        "maps": {"maps": [{
            "id": "overworld", "display_name": "Overworld", "kind": "overworld", "size": [24, 16],
            "generator": {"type": "noise", "frequency": 0.09, "terrain_bands": [
                {"max_height": 0.4, "terrain": "ocean"}, {"max_height": 0.72, "terrain": "grassland"},
                {"max_height": 0.85, "terrain": "hills"}, {"max_height": 1.0, "terrain": "mountain"}]},
            "fog": "full", "starts": {"player": [5, 8], "rival": [18, 8]},
        }]},
        "units": {"units": [
            {"id": "hero", "display_name": "Hero", "kind": "hero",
             "stats": {"health": 12, "strength": 3, "moves": 3, "sight": 3, "perception": 2},
             "equipment_slots": ["weapon"], "level_curve": {"base_xp": 15, "growth": 1.5, "per_level": {"health": 2}}},
            {"id": "scout", "display_name": "Scout", "kind": "unit", "stats": {"health": 8, "strength": 2, "moves": 4, "sight": 3}, "ai_profile": "explorer"},
            {"id": "wolf", "display_name": "Wolf", "kind": "monster", "stats": {"health": 6, "strength": 3, "moves": 3, "sight": 2}, "ai_profile": "hunter", "xp_value": 4},
        ], "abilities": {}},
        "items": {"items": [
            {"id": "healing_herb", "display_name": "Healing Herb", "kind": "consumable", "value": 8,
             "use_effects": [{"kind": "reward", "stat_delta": {"health": 5}}]},
        ]},
        "factions": {"factions": [
            {"id": "player", "display_name": "Player", "color": "#3b82f6", "control": "human", "turn_order": 0,
             "starting_units": ["hero", "scout"], "resources": {"gold": 50}, "stances": {"rival": "peace", "wilds": "war"}, "trade_partners": ["rival"]},
            {"id": "rival", "display_name": "Rival", "color": "#c0392b", "control": "ai", "turn_order": 1,
             "starting_units": ["scout"], "resources": {"gold": 50}, "stances": {"player": "peace", "wilds": "war"}},
            {"id": "wilds", "display_name": "The Wilds", "color": "#7f8c8d", "control": "hostile", "default_stance": "war", "claims_start_territory": False},
        ]},
        "intel": {"intel": [
            {"id": "first_rumor", "title": "A first rumour", "summary": "Replace me.", "subject": "world", "scope": "global",
             "category": "rumor", "reliability": 0.5, "value": 10},
        ]},
        "intel_rules": {"derivations": [], "spread": [
            {"id": "trade_gossip", "between": "trade_partners", "chance": 0.15, "max_secrecy": 0.35, "reliability_loss": 0.2}],
            "contradiction": {"dispute_amount": 0.15, "flag_source_trust_loss": 0.2}},
        "sites": {"sites": [
            {"id": "first_landmark", "map": "overworld", "display_name": "A Weathered Signpost", "category": "ruins", "coord": [7, 8],
             "interactions": [{"kind": "intel", "tokens": ["first_rumor"], "once_per_faction": True, "message": "The signpost points somewhere interesting."}]},
            {"id": "wolf_den", "map": "overworld", "display_name": "Wolf Den", "category": "camp", "coord": [12, 10], "owner": "wilds",
             "spawns": [{"unit": "wolf", "faction": "wilds", "count": 1, "radius": 1, "respawn_turns": 8}]},
        ]},
        "ai_profiles": {"profiles": {
            "idle": {"behavior": "idle"}, "guard": {"behavior": "guard", "radius": 1}, "explorer": {"behavior": "explore"},
            "hunter": {"behavior": "hunt", "flee_below_health": 0.25}}, "abilities": {}},
        "assets": {"assets": {
            "site.ruins": {"type": "scene", "path": "res://framework/world/placeholder_prop.tscn"},
            "site.camp": {"type": "scene", "path": "res://framework/world/placeholder_prop.tscn"},
        }},
    }


README = """# {title}

Game package `{game_id}`.

- `game.json`        entry point: grid, turn mode, calendar, rules
- `terrains.json`    terrain + feature types
- `maps.json`        overworld + site sub-maps (generator or glyph layout)
- `units.json`       heroes / units / npcs / monsters / structures + ability catalog
- `items.json`       equipment, consumables, intel-bearing items, artifacts
- `factions.json`    players, AI, neutrals, monsters; diplomacy + starting kit
- `intel.json`       intel tokens
- `intel_rules.json` derivation / spread / contradiction rules
- `sites.json`       points of interest on tiles with interactions
- `ai_profiles.json` unit AI behaviours
- `assets.json`      logical asset keys -> res:// paths

Validate: `python tools/validate_data.py games/{game_id}`
Run:      `tools/godot.ps1 run {game_id}`    Smoke test: `tools/godot.ps1 smoke {game_id}`
"""


def scaffold(game_id: str, title: str, topology: str = "hex", turns: str = "sequential") -> Path:
    if not re.fullmatch(r"[a-z][a-z0-9_]*", game_id):
        raise SystemExit("game id must be snake_case: [a-z][a-z0-9_]*")
    pkg = GAMES_DIR / game_id
    if pkg.exists():
        raise SystemExit(f"{pkg} already exists")
    pkg.mkdir(parents=True)
    for stem, doc in starter_data(game_id, title, topology, turns).items():
        write_json(pkg / f"{stem}.json", doc)
    (pkg / "README.md").write_text(README.format(title=title, game_id=game_id), encoding="utf-8")
    return pkg


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("game_id")
    ap.add_argument("--title", default=None)
    ap.add_argument("--topology", default="hex", choices=["hex", "square_iso"])
    ap.add_argument("--turns", default="sequential", choices=["sequential", "simultaneous", "wego", "realtime_pause"])
    args = ap.parse_args(argv)
    pkg = scaffold(args.game_id, args.title or args.game_id.replace("_", " ").title(), args.topology, args.turns)
    print(f"created {pkg.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
