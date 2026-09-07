#!/usr/bin/env python3
"""Validate a game package under games/<id>/ without needing Godot.

Checks performed (stdlib only, no external deps):
  * Every data file parses and has the expected top-level shape
  * game.json: grid topology, turn mode, start_map, player_faction exist
  * Map hierarchy: parents exist, no cycles, depth <= max_map_depth; layouts are rectangular
    and their glyphs resolve to terrains
  * Terrains/features: ids unique, features' allowed_on reference terrains
  * Sites reference existing maps; interaction kinds are known; portals target existing maps
  * Units: kinds valid, abilities exist, ai_profile exists, loot/starting items exist
  * Items: kinds/rarities valid, grants_intel tokens exist, slots consistent
  * Factions: control valid, stances reference factions, starting units/items/intel exist
  * Intel: reliability/secrecy in range, conflicts exist, reveals reference sites
  * intel_rules: derivations grant existing tokens; spread filters valid
  * IntelQuery objects are well-formed (same grammar as framework/intel/intel_query.gd)
  * Asset keys referenced by terrains/units/items/sites exist in assets.json (warning)
  * Every intel token is reachable (granted by some site/dialogue/item/unit/rule/ability) - warning

Usage:
  python tools/validate_data.py games/example_realm_iso
  python tools/validate_data.py --all [--strict]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMES_DIR = ROOT / "games"

KNOWN_INTERACTIONS = {"intel", "reward", "shop", "dialogue", "portal", "spawn", "combat", "flag"}
KNOWN_MAP_KINDS = {"overworld", "region", "city", "dungeon", "interior", "special"}
KNOWN_TOPOLOGIES = {"hex", "square_iso", "iso", "square"}
KNOWN_TURN_MODES = {"sequential", "simultaneous", "wego", "realtime_pause"}
KNOWN_UNIT_KINDS = {"hero", "unit", "npc", "monster", "structure"}
KNOWN_ITEM_KINDS = {"equipment", "consumable", "intel", "artifact", "resource", "key", "misc"}
KNOWN_RARITIES = {"common", "uncommon", "rare", "epic", "legendary", "unique"}
KNOWN_CONTROL = {"human", "ai", "neutral", "hostile"}
KNOWN_STANCES = {"war", "hostile", "peace", "friendly", "allied"}
KNOWN_CHANNELS = {"observed", "told", "read", "traded", "stolen", "spread", "derived", "scripted"}
KNOWN_SPREAD_FILTERS = {"all", "allies", "friendly", "peaceful", "enemies", "trade_partners", "neighbors"}
KNOWN_SCOPES = {"global", "region", "tile", "site", "unit", "faction", "item"}
QUERY_KEYS = {"has", "subject", "tag", "scope", "category", "fact", "provenance", "source", "contradicted",
              "flag", "faction_flag", "resource", "turn", "era", "owns_site", "unit_count", "stance",
              "all", "any", "not"}
COMPARE_OPS = {">=", ">", "<=", "<", "==", "=", "!="}
DATA_FILES = ["game", "terrains", "maps", "units", "items", "factions", "intel", "intel_rules", "sites", "assets", "ai_profiles"]
OPTIONAL_FILES = {"intel_rules", "ai_profiles"}


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


class Refs:
    """Cross-reference accumulators."""

    def __init__(self) -> None:
        self.req_tokens: set[str] = set()
        self.granted: set[str] = set()
        self.flags: set[str] = set()
        self.set_flags: set[str] = set()
        self.assets: set[str] = set()
        self.sites: set[str] = set()
        self.units: set[str] = set()
        self.items: set[str] = set()
        self.factions: set[str] = set()


def load_json(path: Path, rep: Report, required: bool = True) -> dict:
    if not path.exists():
        if required:
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


def _num_in_range(val, lo: float, hi: float) -> bool:
    try:
        return lo <= float(val) <= hi
    except (TypeError, ValueError):
        return False


def collect_query_refs(query, ctx: str, rep: Report, refs: Refs) -> None:
    """Validate an IntelQuery object and record token/flag/site/unit/faction references."""
    if not isinstance(query, dict):
        rep.error(f"{ctx}: query must be an object")
        return
    if not query:
        return
    keys = set(query) & QUERY_KEYS
    if len(keys) != 1:
        rep.error(f"{ctx}: query must have exactly one of the query keys, got {sorted(query)}")
        return
    key = keys.pop()
    val = query[key]
    if key == "has":
        refs.req_tokens.add(val)
        if not _num_in_range(query.get("min_reliability", 0), 0, 1):
            rep.error(f"{ctx}: min_reliability out of range")
    elif key in ("subject", "tag", "scope", "category"):
        if int(query.get("count", 1)) < 1:
            rep.error(f"{ctx}: count must be >= 1")
        if key == "scope" and val not in KNOWN_SCOPES:
            rep.warn(f"{ctx}: unknown scope '{val}'")
    elif key == "fact":
        if not (isinstance(val, list) and len(val) == 3):
            rep.error(f"{ctx}: fact must be [token_id, key, value]")
        else:
            refs.req_tokens.add(val[0])
    elif key in ("provenance", "source"):
        if not (isinstance(val, list) and len(val) == 2):
            rep.error(f"{ctx}: {key} must be [token_id, value]")
        else:
            refs.req_tokens.add(val[0])
            if key == "provenance" and val[1] not in KNOWN_CHANNELS:
                rep.error(f"{ctx}: unknown provenance channel '{val[1]}'")
    elif key == "contradicted":
        refs.req_tokens.add(val)
    elif key == "flag":
        refs.flags.add(val)
    elif key in ("resource", "unit_count"):
        if not (isinstance(val, list) and len(val) == 3 and val[1] in COMPARE_OPS):
            rep.error(f"{ctx}: {key} must be [id, op, number]")
        elif key == "unit_count":
            refs.units.add(val[0])
    elif key == "turn":
        if not (isinstance(val, list) and len(val) == 2 and val[0] in COMPARE_OPS):
            rep.error(f"{ctx}: turn must be [op, number]")
    elif key == "owns_site":
        refs.sites.add(val)
    elif key == "stance":
        if not (isinstance(val, list) and len(val) == 2 and val[1] in KNOWN_STANCES):
            rep.error(f"{ctx}: stance must be [faction_id, stance]")
        else:
            refs.factions.add(val[0])
    elif key in ("all", "any"):
        if not isinstance(val, list):
            rep.error(f"{ctx}: '{key}' must be a list")
        else:
            for i, sub in enumerate(val):
                collect_query_refs(sub, f"{ctx}.{key}[{i}]", rep, refs)
    elif key == "not":
        collect_query_refs(val, f"{ctx}.not", rep, refs)


def _validate_effect_list(effects, ctx: str, maps: dict, rep: Report, refs: Refs) -> None:
    if not isinstance(effects, list):
        rep.error(f"{ctx}: must be a list of interaction specs")
        return
    for i, spec in enumerate(effects):
        _validate_interaction(spec, f"{ctx}[{i}]", maps, rep, refs)


def _validate_interaction(inter, ctx: str, maps: dict, rep: Report, refs: Refs) -> None:
    if not isinstance(inter, dict):
        rep.error(f"{ctx}: must be an object")
        return
    kind = inter.get("kind")
    if kind not in KNOWN_INTERACTIONS:
        rep.error(f"{ctx}: unknown interaction kind '{kind}'")
        return
    if "requires" in inter:
        collect_query_refs(inter["requires"], f"{ctx}.requires", rep, refs)
    for flag in inter.get("flags", []):
        refs.flags.add(flag)
    if kind == "intel":
        for tok in inter.get("tokens", []):
            refs.granted.add(tok)
        for tok in inter.get("debunk", []) + inter.get("forget", []):
            refs.req_tokens.add(tok)
        if "channel" in inter and inter["channel"] not in KNOWN_CHANNELS:
            rep.error(f"{ctx}: unknown channel '{inter['channel']}'")
        if "reliability" in inter and not _num_in_range(inter["reliability"], 0, 1):
            rep.error(f"{ctx}: reliability out of range")
    elif kind == "reward":
        for item in inter.get("items", {}):
            refs.items.add(item)
        for flag in inter.get("set_flags", []):
            refs.set_flags.add(flag)
    elif kind == "shop":
        for j, entry in enumerate(inter.get("stock", [])):
            if "item" not in entry or "price" not in entry:
                rep.error(f"{ctx}.stock[{j}]: needs item and price")
            else:
                refs.items.add(entry["item"])
            if "requires" in entry:
                collect_query_refs(entry["requires"], f"{ctx}.stock[{j}].requires", rep, refs)
    elif kind == "dialogue":
        nodes = inter.get("nodes", {})
        start = inter.get("start")
        if start not in nodes:
            rep.error(f"{ctx}: start node '{start}' not in nodes")
        for nid, node in nodes.items():
            for tok in node.get("grant_intel", []):
                refs.granted.add(tok)
            for flag in node.get("set_flags", []):
                refs.set_flags.add(flag)
            if node.get("next") is not None and str(node["next"]) not in nodes:
                rep.error(f"{ctx}.nodes.{nid}: next '{node['next']}' does not exist")
            for k, choice in enumerate(node.get("choices", [])):
                nxt = choice.get("next")
                if nxt is not None and str(nxt) not in nodes:
                    rep.error(f"{ctx}.nodes.{nid}.choices[{k}]: next '{nxt}' does not exist")
                if "requires" in choice:
                    collect_query_refs(choice["requires"], f"{ctx}.nodes.{nid}.choices[{k}].requires", rep, refs)
            _validate_effect_list(node.get("effects", []), f"{ctx}.nodes.{nid}.effects", maps, rep, refs)
    elif kind == "portal":
        direction = inter.get("direction", "descend")
        if direction not in ("descend", "ascend"):
            rep.error(f"{ctx}: direction must be descend|ascend")
        target = inter.get("target_map")
        if direction == "descend" and target not in maps:
            rep.error(f"{ctx}: target_map '{target}' does not exist")
        tc = inter.get("target_coord", [0, 0])
        if not (isinstance(tc, list) and len(tc) == 2):
            rep.error(f"{ctx}: target_coord must be [x, y]")
    elif kind == "spawn":
        refs.units.add(inter.get("unit", ""))
        if inter.get("faction", "actor") != "actor":
            refs.factions.add(inter["faction"])
    elif kind == "combat":
        g = inter.get("guardian")
        if g:
            refs.units.add(g.get("unit", ""))
            refs.factions.add(g.get("faction", ""))
        _validate_effect_list(inter.get("on_victory", []), f"{ctx}.on_victory", maps, rep, refs)
    elif kind == "flag":
        for flag in inter.get("set_flags", []) + inter.get("clear_flags", []):
            refs.set_flags.add(flag)
        if "stance" in inter:
            s = inter["stance"]
            refs.factions.add(s.get("with", ""))
            if s.get("stance") not in KNOWN_STANCES:
                rep.error(f"{ctx}.stance: unknown stance '{s.get('stance')}'")
        if "share_intel" in inter:
            refs.factions.add(inter["share_intel"].get("to", ""))
            for tok in inter["share_intel"].get("tokens", []):
                refs.req_tokens.add(tok)


def _depth(maps: dict, mid: str, rep: Report) -> int:
    depth, seen = 0, {mid}
    cur = maps[mid].get("parent", "")
    while cur:
        if cur in seen:
            rep.error(f"map '{mid}': cycle in parent chain")
            return 99
        if cur not in maps:
            return depth + 1
        seen.add(cur)
        depth += 1
        cur = maps[cur].get("parent", "")
    return depth


def _validate_maps(maps: dict, terrains: dict, max_depth: int, rep: Report, refs: Refs) -> None:
    for mid, m in maps.items():
        if m.get("kind", "overworld") not in KNOWN_MAP_KINDS:
            rep.error(f"map '{mid}': unknown kind '{m.get('kind')}'")
        parent = m.get("parent", "")
        if parent and parent not in maps:
            rep.error(f"map '{mid}': parent '{parent}' does not exist")
        d = _depth(maps, mid, rep)
        if d > max_depth:
            rep.error(f"map '{mid}': depth {d} exceeds max_map_depth {max_depth}")
        if m.get("fog", "full") not in ("full", "explored_only", "none"):
            rep.error(f"map '{mid}': fog must be full|explored_only|none")
        layout = m.get("layout", [])
        if layout:
            if len({len(row) for row in layout}) != 1:
                rep.error(f"map '{mid}': layout rows must have equal length")
            glyphs = m.get("glyphs", {})
            for row in layout:
                for ch in row:
                    if ch not in glyphs:
                        rep.error(f"map '{mid}': glyph '{ch}' has no terrain mapping")
                    elif glyphs[ch] not in terrains:
                        rep.error(f"map '{mid}': glyph '{ch}' -> unknown terrain '{glyphs[ch]}'")
        else:
            size = m.get("size", [24, 16])
            if not (isinstance(size, list) and len(size) == 2 and all(int(v) > 0 for v in size)):
                rep.error(f"map '{mid}': size must be [w, h] > 0")
            for band in m.get("generator", {}).get("terrain_bands", []):
                for t in [band.get("terrain")] + [mb.get("terrain") for mb in band.get("by_moisture", [])]:
                    if t and t not in terrains:
                        rep.error(f"map '{mid}': generator band references unknown terrain '{t}'")
        for fid, coord in m.get("starts", {}).items():
            refs.factions.add(fid)
            if not (isinstance(coord, list) and len(coord) == 2):
                rep.error(f"map '{mid}': start for '{fid}' must be [x, y]")
        for key in ("environment", "music"):
            if m.get(key):
                refs.assets.add(m[key])


def _validate_terrains(doc: dict, rep: Report, refs: Refs) -> tuple[dict, dict]:
    terrains, features = {}, {}
    for t in doc.get("terrains", []):
        tid = t.get("id")
        if not tid:
            rep.error("terrains.json: terrain without id")
            continue
        if tid in terrains:
            rep.error(f"terrain '{tid}': duplicate id")
        terrains[tid] = t
        if t.get("domain", "land") not in ("land", "sea", "any"):
            rep.error(f"terrain '{tid}': domain must be land|sea|any")
        refs.assets.add(t.get("visual", f"tile.{tid}"))
    for f in doc.get("features", []):
        fid = f.get("id")
        if not fid:
            rep.error("terrains.json: feature without id")
            continue
        features[fid] = f
        for t in f.get("allowed_on", []):
            if t not in terrains:
                rep.error(f"feature '{fid}': allowed_on unknown terrain '{t}'")
        if not _num_in_range(f.get("spawn_chance", 0), 0, 1):
            rep.error(f"feature '{fid}': spawn_chance out of range")
        refs.assets.add(f.get("visual", f"feature.{fid}"))
    if not terrains:
        rep.error("terrains.json: at least one terrain is required")
    return terrains, features


def _validate_units(doc: dict, ai_doc: dict, rep: Report, refs: Refs, maps: dict) -> dict:
    units = {}
    abilities = dict(doc.get("abilities", {}))
    abilities.update(ai_doc.get("abilities", {}))
    profiles = ai_doc.get("profiles", {})
    for u in doc.get("units", []):
        uid = u.get("id")
        if not uid:
            rep.error("units.json: unit without id")
            continue
        if uid in units:
            rep.error(f"unit '{uid}': duplicate id")
        units[uid] = u
        if u.get("kind", "unit") not in KNOWN_UNIT_KINDS:
            rep.error(f"unit '{uid}': unknown kind '{u.get('kind')}'")
        for ab in u.get("abilities", []):
            if ab not in abilities:
                rep.error(f"unit '{uid}': unknown ability '{ab}'")
        prof = u.get("ai_profile", "")
        if prof and prof not in profiles:
            rep.warn(f"unit '{uid}': ai_profile '{prof}' not in ai_profiles.json (falls back to idle/guard)")
        for entry in u.get("loot", []):
            refs.items.add(entry.get("item", ""))
        for entry in u.get("starting_items", []):
            refs.items.add(entry if isinstance(entry, str) else entry.get("item", ""))
        ip = u.get("intel_profile", {})
        for key in ("on_sight", "carries", "on_defeat", "on_combat"):
            for tok in ip.get(key, []):
                refs.granted.add(tok)
        if u.get("dialogue"):
            _validate_interaction(dict(u["dialogue"], kind="dialogue"), f"unit '{uid}'.dialogue", maps, rep, refs)
        refs.assets.add(u.get("visual", f"unit.{uid}"))
        refs.assets.add(u.get("portrait", f"portrait.{uid}"))
    for aid, spec in abilities.items():
        if spec.get("target", "self") not in ("self", "tile", "unit", "enemy", "ally"):
            rep.error(f"ability '{aid}': bad target mode")
        if "requires" in spec:
            collect_query_refs(spec["requires"], f"ability '{aid}'.requires", rep, refs)
        _validate_effect_list(spec.get("effects", []), f"ability '{aid}'.effects", maps, rep, refs)
    return units


def _validate_items(doc: dict, rep: Report, refs: Refs, maps: dict) -> dict:
    items = {}
    for it in doc.get("items", []):
        iid = it.get("id")
        if not iid:
            rep.error("items.json: item without id")
            continue
        if iid in items:
            rep.error(f"item '{iid}': duplicate id")
        items[iid] = it
        kind = it.get("kind", "misc")
        if kind not in KNOWN_ITEM_KINDS:
            rep.error(f"item '{iid}': unknown kind '{kind}'")
        if it.get("rarity", "common") not in KNOWN_RARITIES:
            rep.error(f"item '{iid}': unknown rarity")
        if kind == "equipment" and not it.get("slot"):
            rep.error(f"item '{iid}': equipment needs a slot")
        for tok in it.get("grants_intel", []):
            refs.granted.add(tok)
        if "use_requires" in it:
            collect_query_refs(it["use_requires"], f"item '{iid}'.use_requires", rep, refs)
        _validate_effect_list(it.get("use_effects", []), f"item '{iid}'.use_effects", maps, rep, refs)
        refs.assets.add(it.get("icon", f"icon.item.{iid}"))
    return items


def _validate_factions(doc: dict, rep: Report, refs: Refs) -> dict:
    factions = {}
    for f in doc.get("factions", []):
        fid = f.get("id")
        if not fid:
            rep.error("factions.json: faction without id")
            continue
        if fid in factions:
            rep.error(f"faction '{fid}': duplicate id")
        factions[fid] = f
        if f.get("control", "ai") not in KNOWN_CONTROL:
            rep.error(f"faction '{fid}': control must be one of {sorted(KNOWN_CONTROL)}")
        for other, stance in f.get("stances", {}).items():
            refs.factions.add(other)
            if stance not in KNOWN_STANCES:
                rep.error(f"faction '{fid}': unknown stance '{stance}' toward '{other}'")
        if f.get("default_stance", "peace") not in KNOWN_STANCES:
            rep.error(f"faction '{fid}': unknown default_stance")
        for other in f.get("trade_partners", []):
            refs.factions.add(other)
        for entry in f.get("starting_units", []):
            refs.units.add(entry if isinstance(entry, str) else entry.get("unit", ""))
        for item in f.get("starting_items", {}):
            refs.items.add(item)
        for tok in f.get("starting_intel", []):
            refs.granted.add(tok)
    if sum(1 for f in factions.values() if f.get("control") == "human") != 1:
        rep.warn("factions.json: expected exactly one human-controlled faction")
    return factions


def _validate_sites(doc: dict, maps: dict, rep: Report, refs: Refs) -> dict:
    sites = {}
    for s in doc.get("sites", []):
        sid = s.get("id", "?")
        if sid in sites:
            rep.error(f"site '{sid}': duplicate id")
        sites[sid] = s
        if s.get("map") not in maps:
            rep.error(f"site '{sid}': map '{s.get('map')}' does not exist")
        coord = s.get("coord")
        if coord is not None and not (isinstance(coord, list) and len(coord) == 2):
            rep.error(f"site '{sid}': coord must be [x, y]")
        if s.get("placement", "fixed") not in ("fixed", "random_land"):
            rep.error(f"site '{sid}': placement must be fixed|random_land")
        if s.get("owner"):
            refs.factions.add(s["owner"])
        refs.assets.add(s.get("visual", f"site.{s.get('category', 'generic')}"))
        for tok in s.get("discover_intel", []):
            refs.granted.add(tok)
        for key in ("hidden_until", "enter_requires"):
            if key in s:
                collect_query_refs(s[key], f"site '{sid}'.{key}", rep, refs)
        for sp in s.get("spawns", []):
            refs.units.add(sp.get("unit", ""))
            if sp.get("faction"):
                refs.factions.add(sp["faction"])
        for i, inter in enumerate(s.get("interactions", [])):
            _validate_interaction(inter, f"site '{sid}' interaction[{i}]", maps, rep, refs)
    return sites


def _validate_intel(doc: dict, rules: dict, rep: Report, refs: Refs) -> dict:
    intel = {}
    for t in doc.get("intel", []):
        tid = t.get("id")
        if not tid:
            rep.error("intel.json: token without id")
            continue
        if tid in intel:
            rep.error(f"intel '{tid}': duplicate id")
        intel[tid] = t
        for key in ("reliability", "secrecy", "corroboration_step"):
            if key in t and not _num_in_range(t[key], 0, 1):
                rep.error(f"intel '{tid}': {key} out of range")
        if t.get("scope", "global") not in KNOWN_SCOPES:
            rep.warn(f"intel '{tid}': unknown scope '{t.get('scope')}'")
        if int(t.get("decay_turns", 0)) < 0:
            rep.error(f"intel '{tid}': decay_turns must be >= 0")
        for sid in t.get("reveals", {}).get("sites", []):
            refs.sites.add(sid)
        _validate_effect_list(t.get("effects", []), f"intel '{tid}'.effects", {}, rep, refs)
    for tid, t in intel.items():
        for c in t.get("conflicts", []):
            if c not in intel:
                rep.error(f"intel '{tid}': conflicts with unknown token '{c}'")
            elif tid not in intel[c].get("conflicts", []):
                rep.warn(f"intel '{tid}': conflict with '{c}' is not declared symmetrically")
    for i, rule in enumerate(rules.get("derivations", [])):
        ctx = f"intel_rules.derivations[{i}]"
        collect_query_refs(rule.get("when", {}), f"{ctx}.when", rep, refs)
        grant = rule.get("grant")
        if not grant:
            rep.error(f"{ctx}: missing grant")
        else:
            refs.granted.add(grant)
        if "reliability" in rule and not _num_in_range(rule["reliability"], 0, 1):
            rep.error(f"{ctx}: reliability out of range")
    for i, rule in enumerate(rules.get("spread", [])):
        ctx = f"intel_rules.spread[{i}]"
        if rule.get("between", "all") not in KNOWN_SPREAD_FILTERS:
            rep.error(f"{ctx}: unknown 'between' filter '{rule.get('between')}'")
        if rule.get("channel", "spread") not in KNOWN_CHANNELS:
            rep.error(f"{ctx}: unknown channel")
        if not _num_in_range(rule.get("chance", 0.1), 0, 1):
            rep.error(f"{ctx}: chance out of range")
    return intel


def validate_package(pkg: Path) -> Report:
    rep = Report()
    if not (pkg / "game.json").exists():
        rep.error(f"{pkg}: game.json not found")
        return rep
    docs = {name: load_json(pkg / f"{name}.json", rep, required=name not in OPTIONAL_FILES) for name in DATA_FILES}
    if not rep.ok:
        return rep
    game = docs["game"]
    refs = Refs()

    grid = game.get("grid", {})
    if grid.get("topology", "hex") not in KNOWN_TOPOLOGIES:
        rep.error(f"game.json: unknown grid.topology '{grid.get('topology')}'")
    turns = game.get("turns", {})
    if turns.get("mode", "sequential") not in KNOWN_TURN_MODES:
        rep.error(f"game.json: unknown turns.mode '{turns.get('mode')}'")
    max_depth = int(game.get("max_map_depth", 3))

    terrains, _features = _validate_terrains(docs["terrains"], rep, refs)
    maps = {m["id"]: m for m in docs["maps"].get("maps", []) if "id" in m}
    _validate_maps(maps, terrains, max_depth, rep, refs)
    start = game.get("start_map")
    if start not in maps:
        rep.error(f"game.json: start_map '{start}' not in maps.json")
    elif maps[start].get("parent"):
        rep.error("game.json: start_map must be a root map (no parent)")

    units = _validate_units(docs["units"], docs["ai_profiles"], rep, refs, maps)
    items = _validate_items(docs["items"], rep, refs, maps)
    factions = _validate_factions(docs["factions"], rep, refs)
    sites = _validate_sites(docs["sites"], maps, rep, refs)
    intel = _validate_intel(docs["intel"], docs["intel_rules"], rep, refs)
    assets = docs["assets"].get("assets", {})

    pf = game.get("player_faction", "")
    if pf not in factions:
        rep.error(f"game.json: player_faction '{pf}' not in factions.json")
    elif factions[pf].get("control") != "human":
        rep.warn(f"game.json: player_faction '{pf}' is not control=human")

    for tok in sorted(refs.req_tokens | refs.granted):
        if tok not in intel:
            rep.error(f"intel token '{tok}' referenced but not defined in intel.json")
    for uid in sorted(refs.units):
        if uid and uid not in units:
            rep.error(f"unit '{uid}' referenced but not defined in units.json")
    for iid in sorted(refs.items):
        if iid and iid not in items:
            rep.error(f"item '{iid}' referenced but not defined in items.json")
    for fid in sorted(refs.factions):
        if fid and fid not in factions:
            rep.error(f"faction '{fid}' referenced but not defined in factions.json")
    for sid in sorted(refs.sites):
        if sid not in sites:
            rep.error(f"site '{sid}' referenced but not defined in sites.json")
    for tid in intel:
        if tid not in refs.granted:
            rep.warn(f"intel '{tid}' is never granted by any data source")
    for flag in sorted(refs.flags - refs.set_flags):
        rep.warn(f"flag '{flag}' is required but never set by data (may be set by code)")
    for key in sorted(refs.assets):
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
