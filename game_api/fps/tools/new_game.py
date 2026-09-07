#!/usr/bin/env python3
"""Scaffold a new game package under games/<id>/ with valid starter data.

Usage:
  python tools/new_game.py my_game --title "My Game"
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


def scaffold(game_id: str, title: str) -> Path:
    if not re.fullmatch(r"[a-z][a-z0-9_]*", game_id):
        raise SystemExit("game id must be snake_case: [a-z][a-z0-9_]*")
    pkg = GAMES_DIR / game_id
    if pkg.exists():
        raise SystemExit(f"{pkg} already exists")
    (pkg / "maps").mkdir(parents=True)

    write_json(pkg / "game.json", {
        "id": game_id,
        "title": title,
        "version": "0.1.0",
        "description": "",
        "start_map": "overworld",
        "start_spawn": "default",
        "max_map_depth": 4,
        "time_scale": 60.0,
        "start_time": 8.0,
        "currencies": ["gold"],
        "stats": {"strength": 10, "agility": 10, "intellect": 10, "perception": 5, "armor": 0,
                  "crit_chance": 0.05, "dodge": 0.0, "move_speed": 4.5},
        "resources": {"mana": {"max": 50, "regen": 1.0}, "stamina": {"max": 100, "regen": 12.0}},
        "equip_slots": ["main_hand", "off_hand", "head", "body", "hands", "feet", "ring_1", "ring_2", "amulet", "ammo"],
        "combat": {"armor_constant": 50, "max_resistance": 0.75, "min_resistance": -1.0},
        "unarmed_ability": "punch",
        "default_hotbar": [],
        "starting_inventory": {"gold": 50},
        "starting_equipment": [],
    })
    write_json(pkg / "items.json", {"items": [
        {"id": "gold", "display_name": "Gold", "category": "currency", "value": 1},
    ]})
    write_json(pkg / "abilities.json", {"abilities": [
        {"id": "punch", "display_name": "Punch", "targeting": "melee_arc", "range": 1.5,
         "damage": {"blunt": [1, 2]}, "cooldown": 0.6, "costs": {"stamina": 3}},
    ]})
    write_json(pkg / "effects.json", {"effects": []})
    write_json(pkg / "factions.json", {"factions": [
        {"id": "player", "display_name": "Adventurer"},
        {"id": "townsfolk", "display_name": "Townsfolk", "relations": {"player": "friendly"}, "player_reputation": 10},
        {"id": "monsters", "display_name": "Monsters", "default_relation": "hostile"},
    ]})
    write_json(pkg / "actors.json", {"actors": [
        {"id": "player", "display_name": "You", "role": "player", "faction": "player", "brain": "player",
         "stats": {"strength": 10, "agility": 10, "intellect": 10, "perception": 5, "armor": 0, "move_speed": 4.5},
         "resources": {"health": 100, "mana": 50, "stamina": 100}, "abilities": ["punch"]},
    ]})
    write_json(pkg / "maps.json", {"maps": [{
        "id": "overworld",
        "display_name": "Overworld",
        "kind": "overworld",
        "scene": f"res://games/{game_id}/maps/overworld.tscn",
        "environment": "env.forest.day",
        "spawns": {"default": {"position": [0, 1, 0], "yaw": 0}},
        "portals": [],
    }]})
    write_json(pkg / "pois.json", {"pois": [{
        "id": "first_landmark",
        "map": "overworld",
        "display_name": "A Weathered Signpost",
        "category": "landmark",
        "position": [5, 0, -5],
        "interactions": [{"kind": "intel", "tokens": ["first_rumor"], "once": True,
                          "message": "The signpost points somewhere interesting."}],
    }]})
    write_json(pkg / "intel.json", {"intel": [{
        "id": "first_rumor",
        "title": "A first rumour",
        "summary": "Replace me.",
        "subject": "world",
        "category": "rumor",
        "reliability": 0.5,
    }]})
    write_json(pkg / "assets.json", {"assets": {
        "env.forest.day": {"type": "environment", "path": "res://assets/environments/forest_day.tres"},
        "portal.default": {"type": "scene", "path": "res://assets/props/portal_marker/portal_marker.tscn"},
        "poi.landmark": {"type": "scene", "path": "res://assets/props/poi_marker/poi_marker.tscn"},
    }})
    (pkg / "README.md").write_text(
        f"# {title}\n\nGame package `{game_id}`.\n\n"
        "- `game.json`  – entry point, start map, stats\n"
        "- `maps.json`  – map hierarchy & portals\n"
        "- `pois.json`  – points of interest & interactions\n"
        "- `intel.json` – intel tokens\n"
        "- `items.json` / `abilities.json` / `effects.json` – items, abilities (melee & spells), status effects\n"
        "- `actors.json` / `factions.json` – player archetype, NPCs, monsters, bosses; faction relations\n"
        "- `assets.json`– logical asset keys -> res:// paths\n"
        "- `maps/`      – map scenes (.tscn) using MapRoot\n\n"
        f"Validate: `python tools/validate_data.py games/{game_id}`\n"
        f"Run:      `godot --path . -- --game={game_id}`\n",
        encoding="utf-8",
    )
    return pkg


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("game_id")
    ap.add_argument("--title", default=None)
    args = ap.parse_args(argv)
    pkg = scaffold(args.game_id, args.title or args.game_id.replace("_", " ").title())
    print(f"created {pkg.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
