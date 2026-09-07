#!/usr/bin/env python3
"""Validate a game package under games/<id>/ without needing Godot.

Checks performed (stdlib only, no external deps):
  * JSON parses and has the expected top-level shape
  * Map hierarchy: parents exist, no cycles, depth <= max_map_depth
  * Portals target existing maps and spawns
  * POIs reference existing maps; interaction kinds are known
  * Intel references (tokens granted/required anywhere) exist in intel.json
  * IntelQuery objects are well-formed
  * Asset keys referenced by maps/POIs exist in assets.json
  * Every intel token is reachable (granted by at least one POI) - warning only

Usage:
  python tools/validate_data.py games/example_realm
  python tools/validate_data.py --all [--strict]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMES_DIR = ROOT / "games"
KNOWN_INTERACTIONS = {"intel", "reward", "shop", "dialogue", "portal", "examine", "pickup", "container"}


def _token_ids(entries) -> set:
    """grant_intel accepts "id" or {"token": "id", "reliability": x}."""
    out = set()
    for e in entries or []:
        if isinstance(e, dict):
            if e.get("token"):
                out.add(e["token"])
        else:
            out.add(e)
    return out
KNOWN_MAP_KINDS = {"overworld", "region", "town", "castle", "dungeon", "interior", "special"}
QUERY_KEYS = {"has", "subject", "tag", "fact", "flag", "all", "any", "not"}


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    @property
    def ok(self) -> bool:
        return not self.errors


def load_json(path: Path, rep: Report) -> dict:
    if not path.exists():
        rep.error(f"missing file: {path.name}")
        return {}
    try:
        with path.open(encoding="utf-8") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        rep.error(f"{path.name}: JSON error line {exc.lineno}: {exc.msg}")
        return {}
    if not isinstance(data, dict):
        rep.error(f"{path.name}: root must be an object")
        return {}
    return data


def collect_query_refs(query, ctx: str, rep: Report, tokens: set[str], flags: set[str]) -> None:
    """Validate an IntelQuery object and record token/flag references."""
    if not isinstance(query, dict):
        rep.error(f"{ctx}: query must be an object")
        return
    if not query:
        return
    keys = set(query) & QUERY_KEYS
    if len(keys) != 1:
        rep.error(f"{ctx}: query must have exactly one of {sorted(QUERY_KEYS)}, got {sorted(query)}")
        return
    key = keys.pop()
    val = query[key]
    if key == "has":
        tokens.add(val)
        if not (0 <= float(query.get("min_reliability", 0)) <= 1):
            rep.error(f"{ctx}: min_reliability out of range")
    elif key in ("subject", "tag"):
        if int(query.get("count", 1)) < 1:
            rep.error(f"{ctx}: count must be >= 1")
    elif key == "fact":
        if not (isinstance(val, list) and len(val) == 3):
            rep.error(f"{ctx}: fact must be [token_id, key, value]")
        else:
            tokens.add(val[0])
    elif key == "flag":
        flags.add(val)
    elif key in ("all", "any"):
        if not isinstance(val, list):
            rep.error(f"{ctx}: '{key}' must be a list")
        else:
            for i, sub in enumerate(val):
                collect_query_refs(sub, f"{ctx}.{key}[{i}]", rep, tokens, flags)
    elif key == "not":
        collect_query_refs(val, f"{ctx}.not", rep, tokens, flags)


def _validate_maps(maps: dict, max_depth: int, rep: Report, refs: dict) -> None:
    for mid, m in maps.items():
        if m.get("kind") not in KNOWN_MAP_KINDS:
            rep.error(f"map '{mid}': unknown kind '{m.get('kind')}'")
        if not str(m.get("scene", "")).startswith("res://"):
            rep.error(f"map '{mid}': scene must be a res:// path")
        parent = m.get("parent", "")
        if parent and parent not in maps:
            rep.error(f"map '{mid}': parent '{parent}' does not exist")
        if m.get("environment"):
            refs["assets"].add(m["environment"])
        if "default" not in m.get("spawns", {}):
            rep.warn(f"map '{mid}': no 'default' spawn")
        for p in m.get("portals", []):
            pid = p.get("id", "?")
            tgt = p.get("target_map")
            if tgt not in maps:
                rep.error(f"map '{mid}' portal '{pid}': target_map '{tgt}' does not exist")
            else:
                spawn = p.get("target_spawn", "default")
                if spawn not in maps[tgt].get("spawns", {}):
                    rep.error(f"map '{mid}' portal '{pid}': spawn '{spawn}' missing on '{tgt}'")
            if "requires" in p:
                collect_query_refs(p["requires"], f"map '{mid}' portal '{pid}'.requires", rep, refs["req_tokens"], refs["flags"])

    if not any(not m.get("parent") for m in maps.values()):
        rep.error("maps.json: no root map (a map without 'parent')")
    for mid in maps:
        depth, cur, seen = 0, mid, set()
        while maps.get(cur, {}).get("parent"):
            if cur in seen:
                rep.error(f"map '{mid}': cycle in parent chain")
                break
            seen.add(cur)
            cur = maps[cur]["parent"]
            depth += 1
        if depth > max_depth:
            rep.error(f"map '{mid}': depth {depth} exceeds max_map_depth {max_depth}")


def _validate_interaction(inter: dict, ctx: str, poi: dict, maps: dict, rep: Report, refs: dict) -> None:
    kind = inter.get("kind")
    if kind not in KNOWN_INTERACTIONS:
        rep.error(f"{ctx}: unknown kind '{kind}'")
        return
    if "requires" in inter:
        collect_query_refs(inter["requires"], f"{ctx}.requires", rep, refs["req_tokens"], refs["flags"])
    refs["flags"].update(inter.get("flags", []))
    if kind == "intel":
        if not inter.get("tokens"):
            rep.error(f"{ctx}: intel interaction has no tokens")
        refs["granted"].update(inter.get("tokens", []))
    elif kind == "reward":
        refs["set_flags"].update(inter.get("set_flags", []))
        refs["items"].update(inter.get("items", {}).keys())
    elif kind == "shop":
        for j, entry in enumerate(inter.get("stock", [])):
            if "item" not in entry or "price" not in entry:
                rep.error(f"{ctx}.stock[{j}]: needs 'item' and 'price'")
            elif "item" in entry:
                refs["items"].add(entry["item"])
            if "requires" in entry:
                collect_query_refs(entry["requires"], f"{ctx}.stock[{j}].requires", rep, refs["req_tokens"], refs["flags"])
    elif kind in ("examine", "pickup"):
        refs["granted"].update(_token_ids(inter.get("grant_intel", [])))
        refs["set_flags"].update(inter.get("set_flags", []))
        refs["items"].update(inter.get("items", {}).keys())
        refs["items"].update(inter.get("requires_item", {}).keys())
        if kind == "pickup" and not inter.get("items"):
            rep.error(f"{ctx}: pickup interaction has no items")
        for alt in inter.get("text_if", []):
            if "flag" in alt:
                refs["flags"].add(alt["flag"])
    elif kind == "container":
        refs["granted"].update(inter.get("open_intel", []))
        refs["set_flags"].update(inter.get("open_flags", []))
        refs["set_flags"].update(inter.get("deposit_flags", []))
        refs["items"].update(inter.get("contents", {}).keys())
        refs["items"].update(inter.get("deposit_score", {}).keys())
        if "closed_until" in inter:
            collect_query_refs(inter["closed_until"], f"{ctx}.closed_until", rep, refs["req_tokens"], refs["flags"])
    elif kind == "dialogue":
        nodes = inter.get("nodes", {})
        if inter.get("start") not in nodes:
            rep.error(f"{ctx}: start node '{inter.get('start')}' missing")
        for nid, node in nodes.items():
            refs["granted"].update(_token_ids(node.get("grant_intel", [])))
            refs["granted"].update(node.get("debunk", []))
            refs["set_flags"].update(node.get("set_flags", []))
            refs["set_flags"].update(node.get("clear_flags", []))
            refs["items"].update(node.get("give_items", {}).keys())
            refs["items"].update(node.get("take_items", {}).keys())
            nxt = node.get("next")
            if nxt is not None and nxt not in nodes:
                rep.error(f"{ctx} node '{nid}': next -> unknown node '{nxt}'")
            for c in node.get("choices", []):
                for key in ("next", "next_pass", "next_fail"):
                    nxt = c.get(key)
                    if nxt is not None and nxt not in nodes:
                        rep.error(f"{ctx} node '{nid}': choice {key} -> unknown node '{nxt}'")
                if "check" in c and "next_pass" not in c and "next_fail" not in c:
                    rep.warn(f"{ctx} node '{nid}': choice has a check but neither next_pass nor next_fail")
                for key in ("requires", "check"):
                    if key in c:
                        collect_query_refs(c[key], f"{ctx} node '{nid}' choice.{key}", rep, refs["req_tokens"], refs["flags"])
                refs["items"].update(c.get("requires_item", {}).keys())
                refs["set_flags"].update(c.get("set_flags", []))
    elif kind == "portal":
        portal_ids = {p.get("id") for p in maps.get(poi.get("map"), {}).get("portals", [])}
        if inter.get("portal_id") not in portal_ids:
            rep.error(f"{ctx}: portal_id '{inter.get('portal_id')}' not defined on map")


DAMAGE_TYPES = {"physical", "slash", "pierce", "blunt", "fire", "frost", "lightning",
                "poison", "arcane", "holy", "shadow", "true"}
DEFAULT_SLOTS = ["main_hand", "off_hand", "head", "body", "hands", "feet", "ring_1", "ring_2", "amulet", "ammo"]


def load_optional(path: Path, key: str, rep: Report) -> dict:
    """Optional data file: missing is fine, malformed is an error."""
    if not path.exists():
        return {}
    doc = load_json(path, rep)
    return {e["id"]: e for e in doc.get(key, []) if isinstance(e, dict) and "id" in e}


def _validate_items(game: dict, items: dict, abilities: dict, effects: dict, rep: Report, refs: dict) -> None:
    slots = set(game.get("equip_slots", DEFAULT_SLOTS)) | {"ring"}
    currencies = set(game.get("currencies", []))
    for iid, it in items.items():
        ctx = f"item '{iid}'"
        slot = it.get("equip_slot", "")
        if slot and slot not in slots:
            rep.error(f"{ctx}: equip_slot '{slot}' not in game.json equip_slots")
        if it.get("category") == "currency" and iid not in currencies:
            rep.warn(f"{ctx}: currency item not listed in game.json currencies")
        for a in it.get("abilities", []) + [it.get("use_ability", ""), it.get("teaches_ability", "")]:
            if a and a not in abilities:
                rep.error(f"{ctx}: unknown ability '{a}'")
        for e in it.get("effects", []):
            if e not in effects:
                rep.error(f"{ctx}: unknown effect '{e}'")
        for p in it.get("procs", []):
            if p.get("ability") and p["ability"] not in abilities:
                rep.error(f"{ctx}.procs: unknown ability '{p['ability']}'")
            if p.get("effect") and p["effect"] not in effects:
                rep.error(f"{ctx}.procs: unknown effect '{p['effect']}'")
        if "requires" in it:
            collect_query_refs(it["requires"], f"{ctx}.requires", rep, refs["req_tokens"], refs["flags"])
        for key in ("identify_intel", "lore_intel"):
            if it.get(key):
                refs["req_tokens"].add(it[key])
        if it.get("lore_intel"):
            refs["granted"].add(it["lore_intel"])
        if it.get("identified") is False and not it.get("identify_intel"):
            rep.warn(f"{ctx}: unidentified item has no identify_intel")


def _validate_actors(game: dict, items: dict, abilities: dict, effects: dict, actors: dict,
                     factions: dict, rep: Report, refs: dict) -> None:
    slots = set(game.get("equip_slots", DEFAULT_SLOTS))
    for aid, ab in abilities.items():
        ctx = f"ability '{aid}'"
        for ae in ab.get("apply_effects", []):
            if ae.get("effect") not in effects:
                rep.error(f"{ctx}: unknown effect '{ae.get('effect')}'")
        if ab.get("summon_actor") and ab["summon_actor"] not in actors:
            rep.error(f"{ctx}: summon_actor '{ab['summon_actor']}' unknown")
        if "requires" in ab:
            collect_query_refs(ab["requires"], f"{ctx}.requires", rep, refs["req_tokens"], refs["flags"])
        proj = ab.get("projectile", {})
        if ab.get("targeting") == "projectile" and not proj:
            rep.warn(f"{ctx}: projectile targeting without 'projectile' block")
        if proj.get("ammo") and proj["ammo"] not in items:
            rep.error(f"{ctx}.projectile.ammo: unknown item '{proj['ammo']}'")
    for eid, ef in effects.items():
        for imm in ef.get("immunities", []):
            if imm not in effects and imm not in DAMAGE_TYPES:
                rep.warn(f"effect '{eid}': immunity '{imm}' is neither an effect id nor a damage type")
    for aid, ac in actors.items():
        ctx = f"actor '{aid}'"
        if ac.get("faction") and ac["faction"] not in factions:
            rep.error(f"{ctx}: faction '{ac['faction']}' unknown")
        for a in ac.get("abilities", []):
            if a not in abilities:
                rep.error(f"{ctx}: unknown ability '{a}'")
        for slot, item in ac.get("equipment", {}).items():
            if slot not in slots:
                rep.error(f"{ctx}.equipment: slot '{slot}' invalid")
            if item not in items:
                rep.error(f"{ctx}.equipment: unknown item '{item}'")
        for item in ac.get("inventory", {}):
            if item not in items:
                rep.error(f"{ctx}.inventory: unknown item '{item}'")
        for ph in ac.get("phases", []):
            for a in ph.get("abilities", []):
                if a not in abilities:
                    rep.error(f"{ctx}.phases: unknown ability '{a}'")
            for e in ph.get("effects", []):
                if e not in effects:
                    rep.error(f"{ctx}.phases: unknown effect '{e}'")
        if ac.get("weakness_intel"):
            refs["req_tokens"].add(ac["weakness_intel"])
        if ac.get("role") == "player" and ac.get("brain", "player") != "player":
            rep.error(f"{ctx}: player role must use brain 'player'")
        if "health" not in ac.get("resources", {}) and "max_health" not in ac.get("stats", {}):
            rep.warn(f"{ctx}: no health defined")
    for fid, fa in factions.items():
        for other in fa.get("relations", {}):
            if other not in factions:
                rep.error(f"faction '{fid}': relation to unknown faction '{other}'")
    currencies = set(game.get("currencies", []))
    for a in [game.get("unarmed_ability", "")] + list(game.get("default_hotbar", [])):
        if a and a not in abilities:
            rep.error(f"game.json: unknown ability '{a}'")
    for item in game.get("starting_inventory", {}):
        if item not in currencies and item not in items:
            rep.error(f"game.json.starting_inventory: unknown item '{item}'")
    for item in game.get("starting_equipment", []):
        if item not in items:
            rep.error(f"game.json.starting_equipment: unknown item '{item}'")
        elif not items[item].get("equip_slot"):
            rep.error(f"game.json.starting_equipment: '{item}' is not equippable")


def validate_package(pkg: Path) -> Report:
    rep = Report()
    game = load_json(pkg / "game.json", rep)
    maps_doc = load_json(pkg / "maps.json", rep)
    pois_doc = load_json(pkg / "pois.json", rep)
    intel_doc = load_json(pkg / "intel.json", rep)
    assets_doc = load_json(pkg / "assets.json", rep)
    if not rep.ok:
        return rep

    items = load_optional(pkg / "items.json", "items", rep)
    abilities = load_optional(pkg / "abilities.json", "abilities", rep)
    effects = load_optional(pkg / "effects.json", "effects", rep)
    actors = load_optional(pkg / "actors.json", "actors", rep)
    factions = load_optional(pkg / "factions.json", "factions", rep)

    max_depth = int(game.get("max_map_depth", 4))
    maps = {m["id"]: m for m in maps_doc.get("maps", []) if "id" in m}
    intel = {t["id"]: t for t in intel_doc.get("intel", []) if "id" in t}
    assets = assets_doc.get("assets", {})
    refs = {"req_tokens": set(), "granted": set(), "flags": set(), "set_flags": set(), "assets": set(),
            "items": set()}

    if items or abilities or effects or actors or factions:
        _validate_items(game, items, abilities, effects, rep, refs)
        _validate_actors(game, items, abilities, effects, actors, factions, rep, refs)

    start = game.get("start_map")
    if start not in maps:
        rep.error(f"game.json: start_map '{start}' not in maps.json")
    elif game.get("start_spawn", "default") not in maps[start].get("spawns", {}):
        rep.error("game.json: start_spawn not defined on start_map")

    _validate_maps(maps, max_depth, rep, refs)

    poi_ids: set[str] = set()
    for poi in pois_doc.get("pois", []):
        pid = poi.get("id", "?")
        if pid in poi_ids:
            rep.error(f"poi '{pid}': duplicate id")
        poi_ids.add(pid)
        if poi.get("map") not in maps:
            rep.error(f"poi '{pid}': map '{poi.get('map')}' does not exist")
        refs["assets"].add(poi.get("visual", f"poi.{poi.get('category', 'generic')}"))
        if "hidden_until" in poi:
            collect_query_refs(poi["hidden_until"], f"poi '{pid}'.hidden_until", rep, refs["req_tokens"], refs["flags"])
        for i, inter in enumerate(poi.get("interactions", [])):
            _validate_interaction(inter, f"poi '{pid}' interaction[{i}]", poi, maps, rep, refs)

    # Actors may carry POI-style interactions (talkable NPCs) and death hooks.
    for aid, ac in actors.items():
        for i, inter in enumerate(ac.get("interactions", [])):
            _validate_interaction(inter, f"actor '{aid}' interaction[{i}]", {"map": None}, maps, rep, refs)
        if ac.get("death_intel"):
            refs["granted"].add(ac["death_intel"])
        if ac.get("death_flag"):
            refs["set_flags"].add(ac["death_flag"])
        refs["items"].update(ac.get("drops", {}).keys())
    # Map portals / spawn tables reference flags too.
    for mid, m in maps.items():
        for p in m.get("portals", []):
            if p.get("visual"):
                refs["assets"].add(p["visual"])
        for i, s in enumerate(m.get("spawn_tables", [])):
            if s.get("actor") not in actors:
                rep.error(f"map '{mid}' spawn_tables[{i}]: unknown actor '{s.get('actor')}'")
            for key in ("unless_flag", "flag"):
                if s.get(key):
                    refs["flags"].add(s[key])
            if "requires" in s:
                collect_query_refs(s["requires"], f"map '{mid}' spawn_tables[{i}].requires", rep, refs["req_tokens"], refs["flags"])
    for key in ("light_sources",):
        refs["items"].update(game.get(key, []))

    for tok in refs["req_tokens"] | refs["granted"]:
        if tok not in intel:
            rep.error(f"intel token '{tok}' referenced but not defined in intel.json")
    for tid, t in intel.items():
        for c in t.get("conflicts", []):
            if c not in intel:
                rep.error(f"intel '{tid}': conflicts with unknown token '{c}'")
        if not 0 <= float(t.get("reliability", 0.5)) <= 1:
            rep.error(f"intel '{tid}': reliability out of range")
        if tid not in refs["granted"]:
            rep.warn(f"intel '{tid}' is never granted by any POI")
    for flag in sorted(refs["flags"] - refs["set_flags"]):
        rep.warn(f"flag '{flag}' is required but never set by data (may be set by code)")
    if items:
        for item in sorted(refs["items"]):
            if item not in items:
                rep.error(f"item '{item}' referenced by a POI (shop/reward) but not defined in items.json")
    for key in sorted(refs["assets"] | {"portal.default"}):
        if key not in assets:
            rep.warn(f"asset key '{key}' not in assets.json (placeholder will be used)")
    return rep


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("package", nargs="?", help="path to games/<id>")
    ap.add_argument("--all", action="store_true", help="validate every package under games/")
    ap.add_argument("--strict", action="store_true", help="treat warnings as errors")
    args = ap.parse_args(argv)

    if args.all:
        pkgs = sorted(p for p in GAMES_DIR.iterdir() if (p / "game.json").exists())
    elif args.package:
        pkgs = [Path(args.package).resolve()]
    else:
        ap.error("give a package path or --all")

    exit_code = 0
    for pkg in pkgs:
        rep = validate_package(pkg)
        print(f"== {pkg.name}: {len(rep.errors)} error(s), {len(rep.warnings)} warning(s)")
        for e in rep.errors:
            print(f"  ERROR   {e}")
        for w in rep.warnings:
            print(f"  WARNING {w}")
        if rep.errors or (args.strict and rep.warnings):
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
