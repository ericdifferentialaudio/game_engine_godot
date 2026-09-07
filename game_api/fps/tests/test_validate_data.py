"""Tests for tools/validate_data.py and tools/new_game.py (stdlib unittest).

Run:  python -m unittest discover -s tests -v
"""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import validate_data as vd  # noqa: E402
import new_game  # noqa: E402


def _write(pkg: Path, name: str, data: dict) -> None:
    (pkg / name).write_text(json.dumps(data), encoding="utf-8")


def _minimal_package(pkg: Path) -> None:
    _write(pkg, "game.json", {"id": "t", "start_map": "root", "max_map_depth": 2})
    _write(pkg, "maps.json", {"maps": [
        {"id": "root", "kind": "overworld", "scene": "res://x/root.tscn",
         "spawns": {"default": {"position": [0, 1, 0]}},
         "portals": [{"id": "to_a", "target_map": "a", "target_spawn": "default"}]},
        {"id": "a", "kind": "town", "parent": "root", "scene": "res://x/a.tscn",
         "spawns": {"default": {"position": [0, 1, 0]}},
         "portals": [{"id": "to_b", "target_map": "b", "target_spawn": "default"}]},
        {"id": "b", "kind": "interior", "parent": "a", "scene": "res://x/b.tscn",
         "spawns": {"default": {"position": [0, 1, 0]}}},
    ]})
    _write(pkg, "pois.json", {"pois": [
        {"id": "p1", "map": "root", "display_name": "P1", "category": "landmark",
         "interactions": [{"kind": "intel", "tokens": ["tok"]}]},
    ]})
    _write(pkg, "intel.json", {"intel": [{"id": "tok", "title": "T", "subject": "s"}]})
    _write(pkg, "assets.json", {"assets": {
        "poi.landmark": {"type": "scene", "path": "res://a.tscn"},
        "portal.default": {"type": "scene", "path": "res://b.tscn"},
    }})


class ValidateDataTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.pkg = self.tmp / "t"
        self.pkg.mkdir()
        _minimal_package(self.pkg)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _load(self, name: str) -> dict:
        return json.loads((self.pkg / name).read_text(encoding="utf-8"))

    def test_minimal_package_is_valid(self) -> None:
        rep = vd.validate_package(self.pkg)
        self.assertEqual(rep.errors, [])
        self.assertEqual(rep.warnings, [])

    def test_example_realm_has_no_errors(self) -> None:
        rep = vd.validate_package(ROOT / "games" / "example_realm")
        self.assertEqual(rep.errors, [], rep.errors)

    def test_depth_limit_enforced(self) -> None:
        maps = self._load("maps.json")
        maps["maps"].append({"id": "c", "kind": "dungeon", "parent": "b", "scene": "res://x/c.tscn",
                             "spawns": {"default": {"position": [0, 0, 0]}}})
        _write(self.pkg, "maps.json", maps)
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("exceeds max_map_depth" in e for e in rep.errors), rep.errors)

    def test_cycle_detected(self) -> None:
        maps = self._load("maps.json")
        maps["maps"][0]["parent"] = "b"
        _write(self.pkg, "maps.json", maps)
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("cycle" in e or "no root map" in e for e in rep.errors), rep.errors)

    def test_unknown_portal_target_and_spawn(self) -> None:
        maps = self._load("maps.json")
        maps["maps"][0]["portals"].append({"id": "bad", "target_map": "nope"})
        maps["maps"][0]["portals"].append({"id": "bad_spawn", "target_map": "a", "target_spawn": "missing"})
        _write(self.pkg, "maps.json", maps)
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("target_map 'nope'" in e for e in rep.errors))
        self.assertTrue(any("spawn 'missing'" in e for e in rep.errors))

    def test_unknown_intel_reference(self) -> None:
        pois = self._load("pois.json")
        pois["pois"][0]["hidden_until"] = {"has": "ghost_token"}
        _write(self.pkg, "pois.json", pois)
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("ghost_token" in e for e in rep.errors), rep.errors)

    def test_bad_query_shape(self) -> None:
        pois = self._load("pois.json")
        pois["pois"][0]["hidden_until"] = {"has": "tok", "flag": "x"}
        _write(self.pkg, "pois.json", pois)
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("exactly one of" in e for e in rep.errors), rep.errors)

    def test_nested_query_collects_tokens(self) -> None:
        rep = vd.Report()
        tokens, flags = set(), set()
        vd.collect_query_refs({"all": [{"has": "a"}, {"not": {"any": [{"flag": "f"}, {"fact": ["b", "k", 1]}]}}]},
                              "ctx", rep, tokens, flags)
        self.assertEqual(rep.errors, [])
        self.assertEqual(tokens, {"a", "b"})
        self.assertEqual(flags, {"f"})

    def test_unknown_interaction_kind(self) -> None:
        pois = self._load("pois.json")
        pois["pois"][0]["interactions"].append({"kind": "teleport"})
        _write(self.pkg, "pois.json", pois)
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("unknown kind 'teleport'" in e for e in rep.errors))

    def test_dialogue_dangling_next(self) -> None:
        pois = self._load("pois.json")
        pois["pois"][0]["interactions"] = [{"kind": "dialogue", "start": "a", "nodes": {
            "a": {"text": "hi", "choices": [{"text": "x", "next": "missing"}]}}}]
        _write(self.pkg, "pois.json", pois)
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("unknown node 'missing'" in e for e in rep.errors))
        self.assertTrue(any("never granted" in w for w in rep.warnings))

    def test_missing_asset_key_is_warning(self) -> None:
        _write(self.pkg, "assets.json", {"assets": {}})
        rep = vd.validate_package(self.pkg)
        self.assertEqual(rep.errors, [])
        self.assertTrue(any("poi.landmark" in w for w in rep.warnings))


class CombatDataTests(unittest.TestCase):
    """Cross-reference checks for items/abilities/effects/actors/factions."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.pkg = self.tmp / "t"
        self.pkg.mkdir()
        _minimal_package(self.pkg)
        _write(self.pkg, "items.json", {"items": [
            {"id": "sword", "display_name": "Sword", "category": "weapon", "equip_slot": "main_hand",
             "abilities": ["slash"]},
            {"id": "relic", "display_name": "Relic", "category": "weapon", "equip_slot": "main_hand",
             "identified": False, "identify_intel": "tok", "requires": {"has": "tok"}},
        ]})
        _write(self.pkg, "abilities.json", {"abilities": [
            {"id": "slash", "display_name": "Slash", "targeting": "melee_arc"},
            {"id": "bolt", "display_name": "Bolt", "targeting": "projectile", "projectile": {"speed": 1},
             "apply_effects": [{"effect": "burning"}]},
        ]})
        _write(self.pkg, "effects.json", {"effects": [{"id": "burning", "display_name": "Burning"}]})
        _write(self.pkg, "factions.json", {"factions": [
            {"id": "player", "display_name": "P"},
            {"id": "undead", "display_name": "U", "relations": {"player": "hostile"}},
        ]})
        _write(self.pkg, "actors.json", {"actors": [
            {"id": "player", "display_name": "You", "role": "player", "faction": "player", "brain": "player",
             "resources": {"health": 100}},
            {"id": "skel", "display_name": "Skel", "role": "monster", "faction": "undead",
             "abilities": ["slash"], "equipment": {"main_hand": "sword"}, "resources": {"health": 10}},
        ]})

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _edit(self, name: str, fn) -> None:
        data = json.loads((self.pkg / name).read_text(encoding="utf-8"))
        fn(data)
        _write(self.pkg, name, data)

    def test_valid_combat_package(self) -> None:
        rep = vd.validate_package(self.pkg)
        self.assertEqual(rep.errors, [], rep.errors)

    def test_unknown_ability_on_item_and_actor(self) -> None:
        self._edit("items.json", lambda d: d["items"][0]["abilities"].append("ghost"))
        self._edit("actors.json", lambda d: d["actors"][1]["abilities"].append("ghost2"))
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("unknown ability 'ghost'" in e for e in rep.errors))
        self.assertTrue(any("unknown ability 'ghost2'" in e for e in rep.errors))

    def test_bad_equip_slot_and_unknown_effect(self) -> None:
        self._edit("items.json", lambda d: d["items"][0].update({"equip_slot": "tail"}))
        self._edit("abilities.json", lambda d: d["abilities"][1]["apply_effects"].append({"effect": "nope"}))
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("equip_slot 'tail'" in e for e in rep.errors))
        self.assertTrue(any("unknown effect 'nope'" in e for e in rep.errors))

    def test_unknown_faction_and_relation(self) -> None:
        self._edit("actors.json", lambda d: d["actors"][1].update({"faction": "elves"}))
        self._edit("factions.json", lambda d: d["factions"][1]["relations"].update({"dwarves": "allied"}))
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("faction 'elves' unknown" in e for e in rep.errors))
        self.assertTrue(any("unknown faction 'dwarves'" in e for e in rep.errors))

    def test_starting_equipment_must_be_equippable(self) -> None:
        self._edit("items.json", lambda d: d["items"].append({"id": "rock", "display_name": "Rock", "category": "misc"}))
        self._edit("game.json", lambda d: d.update({"starting_equipment": ["rock", "missing"]}))
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("'rock' is not equippable" in e for e in rep.errors))
        self.assertTrue(any("unknown item 'missing'" in e for e in rep.errors))

    def test_shop_item_must_exist_when_items_defined(self) -> None:
        self._edit("pois.json", lambda d: d["pois"][0]["interactions"].append(
            {"kind": "shop", "stock": [{"item": "phantom", "price": 1}]}))
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("item 'phantom' referenced by a POI" in e for e in rep.errors))

    def test_item_intel_refs_must_exist(self) -> None:
        self._edit("items.json", lambda d: d["items"][1].update({"identify_intel": "unknown_tok"}))
        rep = vd.validate_package(self.pkg)
        self.assertTrue(any("unknown_tok" in e for e in rep.errors))


class NewGameTests(unittest.TestCase):
    def test_scaffold_produces_valid_package(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        try:
            new_game.GAMES_DIR = tmp
            pkg = new_game.scaffold("scaffold_test", "Scaffold Test")
            rep = vd.validate_package(pkg)
            self.assertEqual(rep.errors, [], rep.errors)
            self.assertTrue((pkg / "maps").is_dir())
            with self.assertRaises(SystemExit):
                new_game.scaffold("Bad-Id", "x")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
