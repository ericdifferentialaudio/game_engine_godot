#!/usr/bin/env python3
"""Convert the Python Aevum data package into an isometric-engine game package.

Reads the authoring data from the original pygame project (``assets/data/*.json``)
and emits the eleven schema-backed files the isometric engine layer expects
(see ``game_api/isometric/docs/08_data_reference.md``).

The conversion is deliberately a *script* rather than hand-written JSON so that
re-running it after an upstream data change is mechanical, and so every mapping
decision is auditable in one place.

Usage:
  python games/aevum/tools/convert_aevum_data.py --source C:\\Aevum --out games/aevum
  python games/aevum/tools/convert_aevum_data.py --check     # non-zero exit if output is stale
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# Aevum -> engine stat names. The engine's conventional stats are health /
# strength / defense / moves / sight / perception; Aevum's extra stats (mana,
# range, stealth, arcane, luck, resistance, endurance, intellect) are carried
# through verbatim and declared in game.json so CoreStats.define_from knows them.
# --------------------------------------------------------------------------
STAT_MAP = {
    "atk": "strength",
    "def": "defense",
    "mov": "moves",
    "hp": "health",
    "vis": "sight",
    "mp": "mana",
    "rng": "reach",
    "stl": "stealth",
    "arc": "arcane",
    "lck": "luck",
    "res": "resilience",
    "end": "endurance",
    "int_stat": "intellect",
}

# Clan order is fixed so ids, colours and turn order are deterministic.
CLAN_IDS = ["fighter", "mage", "cleric", "dwarf", "ranger", "elf",
            "rogue", "monk", "druid", "necromancer", "bard", "shaman"]

# Aevum terrain id -> engine terrain id (the engine package uses 'grassland'
# singular and 'sacred' is modelled as a distinct terrain).
TERRAIN_RENAME = {"grasslands": "grassland"}

DATA_FILES = ["game", "terrains", "maps", "units", "items", "factions",
              "intel", "intel_rules", "sites", "assets", "ai_profiles"]

# Keys inside lair_monsters.json / lair_bosses.json that are not biomes.
NON_BIOME_KEYS = {"universal_special_hexes", "loot_tables"}


def biomes_of(section: dict) -> list[str]:
    return [k for k, v in section.items()
            if not k.startswith("_") and k not in NON_BIOME_KEYS and isinstance(v, dict)]


def rgb_to_hex(rgb) -> str:
    if isinstance(rgb, str) and rgb.startswith("#"):
        return rgb.lower()
    if isinstance(rgb, (list, tuple)) and len(rgb) >= 3:
        return "#%02x%02x%02x" % (int(rgb[0]), int(rgb[1]), int(rgb[2]))
    return "#888888"


def map_stats(base: dict) -> dict:
    """Translate an Aevum ``base`` stat block, dropping zero-valued extras."""
    out: dict[str, float] = {}
    for key, val in (base or {}).items():
        name = STAT_MAP.get(key)
        if name is None:
            continue
        if val in (None, 0) and name not in ("health", "strength", "defense", "moves", "sight"):
            continue
        out[name] = val
    return out


def terrain_id(raw: str) -> str:
    return TERRAIN_RENAME.get(raw, raw)


def load(source: Path, name: str) -> dict:
    path = source / "assets" / "data" / f"{name}.json"
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def write(out: Path, name: str, payload: dict) -> None:
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{name}.json"
    with path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(payload, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


# ==========================================================================
# game.json
# ==========================================================================
def build_game(src: dict) -> dict:
    return {
        "id": "aevum",
        "title": "Aevum: Age of Shrines",
        "version": "0.1.0",
        "description": (
            "Eight of twelve clans race across a hex world to meditate every shrine and "
            "become Avatar, build a Seeker, steal the Dragon's egg and carry it home "
            "uncontested - or eliminate every rival first."
        ),
        "grid": {"topology": "hex", "orientation": "pointy", "tile_size": [64, 56], "wrap_x": False},
        "turns": {"mode": "simultaneous", "timer_seconds": 0, "ticks_per_turn": 10, "seconds_per_tick": 1.0},
        "calendar": {
            "start_year": 1, "years_per_turn": 1,
            "year_suffix_neg": "BR", "year_suffix_pos": "AR",
            "eras": [
                {"id": "founding", "label": "The Founding", "from_turn": 1},
                {"id": "contest", "label": "The Contest of Shrines", "from_turn": 40},
                {"id": "wake", "label": "The Dragon's Waking", "from_turn": 120},
            ],
        },
        "boot_script": "aevum_boot.gd",
        "start_map": "aevum",
        "player_faction": "fighter",
        "max_map_depth": 3,
        "seed": 42,
        "currencies": ["gold"],
        # Default stat block: every stat any unit may carry must appear here.
        "stats": {
            "health": 6, "strength": 2, "defense": 2, "moves": 3, "sight": 2,
            "perception": 0, "mana": 0, "reach": 1, "stealth": 0, "arcane": 0,
            "luck": 0, "resilience": 0, "endurance": 0, "intellect": 0,
        },
        "rules": {
            "movement": {"road_cost": 0.5},
            "combat": {
                "randomness": 0.2, "base_damage": 1, "retaliation_scale": 0.6,
                "defender_terrain_bonus": True, "attack_ends_turn": True,
            },
            "fog": {"shared_vision_allies": True, "owned_tile_sight": 1, "site_sight": 2},
            "intel": {"observe_units": True, "observe_sites": True,
                      "perception_reliability_per_point": 0.02},
            "units": {"heal_per_turn": 1},
            "sites": {"capture_on_enter": True},
            "economy": {"sell_ratio": 0.5, "track_all_yields": False},
            "victory": {"last_faction_standing": True, "eliminate_on_no_units": True},
            # Aevum-specific rules, consumed by the game's own GDScript modules.
            "aevum": {
                "active_clans": 8,
                "sacred_ground_radius": 2,
                "shrine_distance_from_enclave": [8, 12],
                "shrine_camp_penalty_turns": 3,
                "meditation_turns": {"direct": 1, "secondhand": 3, "unknown": 12},
                "avatar_requires_all_shrines": True,
                "seeker_requires_avatar": True,
                "egg_carrier_move_penalty": 1,
                "dragon_wake_radius": 8,
                "dragon_damage_negated_per_turn": 5,
                "monster_weakness_bonus": 3,
                "monster_resistance_malus": 1,
            },
        },
    }


# ==========================================================================
# terrains.json
# ==========================================================================
def build_terrains(src: dict) -> dict:
    terrains = []
    for raw_id, spec in src["terrain"]["terrain"].items():
        tid = terrain_id(raw_id)
        passable = bool(spec.get("passable_all", True))
        entry = {
            "id": tid,
            "display_name": spec.get("label", tid.title()),
            "domain": "land",
            "move_cost": spec.get("move_cost") or 1,
            "passable": passable,
            "color": rgb_to_hex(spec.get("color")),
            "defense_bonus": int(spec.get("def_bonus", 0)) * 25,
            "visual": f"tile.{tid}",
            "tags": [],
        }
        if spec.get("vis_penalty"):
            entry["blocks_sight"] = True
        if not passable:
            entry["tags"].append("impassable")
        if spec.get("notes"):
            entry["metadata"] = {"notes": spec["notes"]}
        terrains.append(entry)

    # Aevum's world is coastal/naval-capable; the source terrain table has no
    # water rows because water was produced by the generator. Add them here.
    terrains.append({
        "id": "ocean", "display_name": "Ocean", "domain": "sea", "move_cost": 1,
        "passable": True, "color": "#1d4e89", "elevation": -2,
        "visual": "tile.ocean", "yields": {"gold": 1}, "tags": ["water", "deep"],
    })
    terrains.append({
        "id": "coast", "display_name": "Coast", "domain": "sea", "move_cost": 1,
        "passable": True, "color": "#3b82c4", "elevation": -1,
        "visual": "tile.coast", "yields": {"gold": 1}, "tags": ["water", "coastal"],
    })
    return {"terrains": terrains, "features": []}


# ==========================================================================
# maps.json
# ==========================================================================
def build_maps(src: dict) -> dict:
    lair_layout = [
        "#############",
        "#....#......#",
        "#.##.#.####.#",
        "#.#........##",
        "#.#.####...##",
        "#...#...##..#",
        "##.##.#..##.#",
        "#..........##",
        "#############",
    ]
    return {
        "maps": [
            {
                "id": "aevum",
                "display_name": "Aevum",
                "kind": "overworld",
                "size": [64, 48],
                "generator": {
                    "type": "noise",
                    "frequency": 0.075,
                    "moisture_frequency": 0.05,
                    "edge_falloff": 0.32,
                    "features": False,
                    "terrain_bands": [
                        {"max_height": 0.34, "terrain": "ocean"},
                        {"max_height": 0.40, "terrain": "coast"},
                        {"max_height": 0.70, "by_moisture": [
                            {"max": 0.25, "terrain": "plains"},
                            {"max": 0.50, "terrain": "grassland"},
                            {"max": 0.75, "terrain": "forest"},
                            {"max": 1.0, "terrain": "swamp"},
                        ]},
                        {"max_height": 0.84, "terrain": "hills"},
                        {"max_height": 1.0, "terrain": "mountain"},
                    ],
                },
                "environment": "env.overworld",
                "music": "music.overworld",
                "fog": "full",
                "tags": ["root"],
            },
            {
                "id": "lair_cave", "display_name": "Cave Lair", "kind": "dungeon",
                "parent": "aevum", "fog": "explored_only",
                "glyphs": {"#": "mountain", ".": "plains"},
                "layout": lair_layout,
                "environment": "env.cave", "music": "music.lair", "tags": ["lair"],
            },
            {
                "id": "lair_crypt", "display_name": "Crypt Lair", "kind": "dungeon",
                "parent": "aevum", "fog": "explored_only",
                "glyphs": {"#": "mountain", ".": "plains"},
                "layout": lair_layout,
                "environment": "env.crypt", "music": "music.lair", "tags": ["lair"],
            },
        ]
    }


# ==========================================================================
# units.json
# ==========================================================================
def _movement_for(clan: str, src: dict, mountain_ok: bool = False) -> dict:
    """Clan terrain exceptions become per-unit terrain_costs."""
    move = {"domain": "land", "uses_roads": True}
    costs = {}
    for raw, cost in src["terrain"].get("movement_exceptions", {}).get(clan, {}).items():
        costs[terrain_id(raw)] = cost
    if costs:
        move["terrain_costs"] = costs
    if not (mountain_ok or "mountain" in costs):
        move["impassable"] = ["mountain"]
    return move


def _unit_meta(spec: dict) -> dict:
    """Carry Aevum-only production/ability flags into metadata for the GDScript rules."""
    keys = ("build_turns", "requires_building", "requires_avatar", "requires_tech",
            "requires_structure", "max_per_clan", "spell_tier_max", "can_carry_egg",
            "can_meditate", "can_attack", "triggers_zoc", "ignores_zoc", "passive",
            "unlock_building", "mp_from_clan_tier", "is_naval", "sea_only", "spawn_at")
    return {k: spec[k] for k in keys if k in spec and spec[k] is not None}


def _base_unit(uid: str, name: str, kind: str, spec: dict, movement: dict,
               ai_profile: str = "guard") -> dict:
    entry = {
        "id": uid,
        "display_name": name,
        "kind": kind,
        "visual": f"unit.{uid}",
        "stats": map_stats(spec.get("base") or spec),
        "movement": movement,
        "ai_profile": ai_profile,
        "tags": [],
    }
    if spec.get("_description"):
        entry["description"] = spec["_description"]
    gold = spec.get("gold_cost")
    if gold:
        entry["cost"] = {"gold": gold}
        entry["upkeep"] = {"gold": max(1, round(gold / 60))}
    meta = _unit_meta(spec)
    if meta:
        entry["metadata"] = meta
    return entry


def build_units(src: dict) -> dict:
    ut = src["unit_types"]
    units: list[dict] = []
    # Specialty units each carry a unique named ability; collected here so the
    # ability catalog stays the single source of truth the validator checks.
    extra_abilities: dict[str, dict] = {}

    # -- Universal per-clan unit types (scout / archer / defender / chieftain / seeker)
    for type_id in ("scout", "archer", "defender", "chieftain", "seeker"):
        spec = ut["unit_types"][type_id]
        for clan in CLAN_IDS:
            uid = f"{clan}_{type_id}"
            unit = _base_unit(
                uid, f"{clan.title()} {type_id.title()}", "unit", spec,
                _movement_for(clan, src, mountain_ok=(clan == "ranger")),
                ai_profile={"scout": "explorer", "seeker": "seeker",
                            "defender": "guard"}.get(type_id, "aggressor"),
            )
            unit["tags"] = [type_id, clan]
            unit["metadata"] = dict(unit.get("metadata", {}), clan=clan, unit_type=type_id)
            if type_id in ("seeker", "chieftain"):
                unit["kind"] = "hero"
                unit["abilities"] = ["meditate", "seek_egg"] if type_id == "seeker" \
                    else ["meditate", "propose_alliance"]
            elif spec.get("can_meditate"):
                unit["abilities"] = ["meditate"]
            units.append(unit)

    # -- The common -> advanced -> specialty clan ladder
    for tier, section in (("clan", "common_units"), ("advanced", "advanced_units"),
                          ("specialty", "specialty_units")):
        for key, spec in ut[section].items():
            if key.startswith("_"):
                continue
            clan = spec.get("clan_id", key)
            uid = spec.get("template_id") or f"{clan}_{tier}"
            unit = _base_unit(
                uid, spec.get("name", uid.title()), "unit", spec,
                _movement_for(clan, src, mountain_ok=(clan in ("ranger", "dwarf"))),
                ai_profile="aggressor",
            )
            unit["tags"] = [tier, clan]
            unit["metadata"] = dict(unit.get("metadata", {}), clan=clan, unit_type=tier)
            abilities = ["meditate"] if spec.get("can_meditate") else []
            if isinstance(spec.get("ability"), dict) and spec["ability"].get("id"):
                abilities.append(spec["ability"]["id"])
                unit["metadata"]["ability"] = spec["ability"]
                extra_abilities[spec["ability"]["id"]] = spec["ability"]
            if abilities:
                unit["abilities"] = abilities
            units.append(unit)

    # -- Naval units (sea domain)
    for key, spec in ut.get("naval_units", {}).items():
        if key.startswith("_"):
            continue
        unit = _base_unit(key, key.title(), "unit", spec, {"domain": "sea"},
                          ai_profile="aggressor")
        unit["tags"] = ["naval"]
        units.append(unit)

    # -- Roaming monsters (the Wilds faction) and the Dragon
    for key, spec in src["monsters"]["monsters"].items():
        merged = dict(spec)
        merged["base"] = spec.get("base_stats", {})
        unit = _base_unit(key, spec.get("name", key.title()), "monster", merged,
                          {"domain": "land"},
                          ai_profile="dragon" if key == "dragon" else "hunter")
        unit["tags"] = ["monster", spec.get("zone", "outer")]
        unit["xp_value"] = int(spec.get("tier", 1)) * 6
        unit["aggression"] = 0.9 if key == "dragon" else 0.7
        unit["metadata"] = dict(unit.get("metadata", {}),
                                tier=spec.get("tier", 1),
                                weakness_pool=spec.get("weakness_pool", []),
                                resistance_pool=spec.get("resistance_pool", []))
        unit["intel_profile"] = {"on_sight": [f"seen_{key}"],
                                 "on_combat": [f"weakness_{key}"]}
        units.append(unit)

    units.extend(_lair_units(src))

    # De-duplicate by id, keeping the first definition.
    seen: dict[str, dict] = {}
    for unit in units:
        seen.setdefault(unit["id"], unit)

    abilities = build_abilities(src)
    for aid, spec in extra_abilities.items():
        passive = spec.get("type") == "passive"
        abilities[aid] = {
            "display_name": spec.get("name", aid.replace("_", " ").title()),
            "cost_ap": 0 if passive else 1,
            "cooldown": 0 if passive else 3,
            "target": "self" if passive else "enemy",
            "range": 0 if passive else 1,
            "effects": [{
                "kind": "flag",
                "set_flags": [f"used_{aid}"],
                "message": spec.get("description", ""),
            }],
        }
    return {"units": list(seen.values()), "abilities": abilities}


def _lair_units(src: dict) -> list[dict]:
    out: list[dict] = []
    for biome in biomes_of(src["lair_monsters"]):
        spec = src["lair_monsters"][biome]
        for role in ("basic", "suppressor"):
            mon = spec.get(role)
            if not isinstance(mon, dict):
                continue
            uid = mon.get("template_id", f"{biome}_{role}")
            unit = _base_unit(uid, mon.get("name", uid.title()), "monster",
                              {"base": mon}, {"domain": "land"}, ai_profile="guard")
            unit["tags"] = ["lair", biome]
            unit["xp_value"] = 4
            unit["metadata"] = {"biome": biome, "role": role,
                                "weakness": mon.get("weakness", []),
                                "resistance": mon.get("resistance", [])}
            out.append(unit)
    for biome in biomes_of(src["lair_bosses"]):
        for tier, boss in src["lair_bosses"][biome].items():
            if not isinstance(boss, dict) or "template_id" not in boss:
                continue
            unit = _base_unit(boss["template_id"], boss.get("name", "Boss"), "monster",
                              {"base": boss}, {"domain": "land"}, ai_profile="guard")
            unit["tags"] = ["lair", "boss", biome]
            unit["xp_value"] = 20
            unit["metadata"] = {"biome": biome, "tier": tier,
                                "weakness": boss.get("weakness", [])}
            unit["intel_profile"] = {"on_defeat": [f"cleared_lair_{biome}"]}
            out.append(unit)
    return out


# ==========================================================================
# abilities (part of units.json)
# ==========================================================================
def build_abilities(src: dict) -> dict:
    abilities: dict[str, dict] = {
        "meditate": {
            "display_name": "Meditate",
            "cost_ap": 1, "cooldown": 0, "target": "self",
            "effects": [{
                "kind": "flag", "set_faction_flags": ["meditating"],
                "message": "The unit kneels at the shrine and begins to meditate.",
            }],
        },
        "seek_egg": {
            "display_name": "Seek the Egg",
            "cost_ap": 1, "cooldown": 3, "target": "self",
            "effects": [{
                "kind": "intel", "tokens": ["egg_location"], "channel": "derived",
                "reliability": 0.4,
                "message": "The Seeker senses the egg's pull.",
            }],
        },
        "propose_alliance": {
            "display_name": "Propose Alliance",
            "cost_ap": 1, "cooldown": 5, "target": "unit", "range": 1,
            "effects": [{
                "kind": "flag", "set_faction_flags": ["alliance_offered"],
                "message": "The Chieftain offers terms.",
            }],
        },
    }
    # Spells become targeted abilities; mana cost is carried in metadata for the
    # magic rules module, since the engine's ability cost is AP-based.
    for spell in src["spells"].get("spells", []):
        abilities[f"spell_{spell['id']}"] = {
            "display_name": spell.get("name", spell["id"].title()),
            "cost_ap": 1,
            "cooldown": max(1, int(spell.get("tier", 1))),
            "target": "self" if not spell.get("range") else "tile",
            "range": int(spell.get("range", 0)),
            "effects": [{
                "kind": "flag",
                "set_flags": [f"cast_{spell['id']}"],
                "message": spell.get("desc", ""),
            }],
        }
    return abilities


# ==========================================================================
# items.json
# ==========================================================================
def _item_entry(raw: dict, kind: str, rarity: str = "common") -> dict:
    effect = raw.get("effect", {}) or {}
    modifiers = {STAT_MAP[k]: v for k, v in effect.items() if k in STAT_MAP}
    special = {k: v for k, v in effect.items() if k not in STAT_MAP}
    slot = raw.get("slot", "any")
    entry = {
        "id": raw["id"],
        "display_name": raw.get("name", raw["id"].title()),
        "description": raw.get("desc", ""),
        "kind": kind,
        "slot": "trinket" if slot == "any" else slot,
        "icon": f"icon.item.{raw['id']}",
        "rarity": rarity,
        "value": int(raw.get("cost") or (raw.get("cost_range") or [0])[0] or 0),
        "tags": list(raw.get("source", [])),
    }
    if modifiers:
        entry["modifiers"] = modifiers
    if special:
        entry["metadata"] = {"effects": special}
    if kind == "consumable":
        entry["consume_on_use"] = True
        entry["stackable"] = True
    return entry


def build_items(src: dict) -> dict:
    items: list[dict] = []
    groups = src["items"]

    for raw in groups["items"].get("standard", []):
        effect = raw.get("effect", {}) or {}
        consumable = any(k in effect for k in ("heal_combat", "cast_once", "reveal_shrines"))
        items.append(_item_entry(raw, "consumable" if consumable else "equipment"))
    for section, kind, rarity in (("weapons", "equipment", "rare"),
                                  ("armour", "equipment", "rare"),
                                  ("armor", "equipment", "rare")):
        for raw in groups["items"].get(section, []):
            items.append(_item_entry(raw, kind, rarity))
    for raw in groups.get("artifacts", []):
        items.append(_item_entry(raw, "artifact", "legendary"))
    for raw in groups.get("island", []):
        items.append(_item_entry(raw, "consumable", "uncommon"))
    for pool_file in ("castle_items", "town_items"):
        for raw in src[pool_file].get("pool", []):
            if isinstance(raw, dict) and "id" in raw:
                items.append(_item_entry(raw, "equipment", "uncommon"))

    # The dragon egg: the object the whole game is about.
    items.append({
        "id": "dragon_egg",
        "display_name": "The Dragon's Egg",
        "description": "Warm to the touch, and heavier than it has any right to be. "
                       "Carry it home to win.",
        "kind": "artifact", "slot": "carried", "icon": "icon.item.dragon_egg",
        "rarity": "unique", "value": 0, "unique": True,
        "tags": ["quest", "egg"],
        "metadata": {"move_penalty": 1, "blocks_attack": True},
    })

    seen: dict[str, dict] = {}
    for item in items:
        seen.setdefault(item["id"], item)

    # Town armoury/store pools name items the upstream data never defined a
    # stat block for. Emit a minimal, honest stub so shop stock resolves; these
    # are flagged for a design pass rather than silently invented.
    for stub in sorted(_referenced_shop_items(src) - set(seen)):
        seen[stub] = {
            "id": stub,
            "display_name": stub.replace("_", " ").title(),
            "description": "",
            "kind": "equipment",
            "slot": "trinket",
            "icon": f"icon.item.{stub}",
            "rarity": "common",
            "value": 60,
            "tags": ["shop", "stub"],
            "metadata": {"needs_design": True},
        }
    return {"items": list(seen.values())}


def _referenced_shop_items(src: dict) -> set[str]:
    refs: set[str] = set()
    for tid, town in src["towns"]["towns"].items():
        if tid.startswith("_"):
            continue
        refs.update(town.get("armory_pool", []))
        refs.update(town.get("store_pool", []))
    return refs


# ==========================================================================
# factions.json  (12 clans + the Wilds + the Dragon)
# ==========================================================================
def build_factions(src: dict) -> dict:
    virtues = src["virtues"].get("clan_virtues", {})
    factions = []
    for order, clan in enumerate(src["clans"]["clans"]):
        cid = clan["id"]
        factions.append({
            "id": cid,
            "display_name": clan.get("name", cid.title()),
            "color": rgb_to_hex(clan.get("color_hex") or clan.get("color")),
            "control": "human" if order == 0 else "ai",
            "turn_order": order,
            "starting_units": [f"{cid}_chieftain", f"{cid}_scout", f"{cid}_scout",
                               f"{cid}_defender"],
            "resources": {"gold": 200},
            "claims_start_territory": True,
            "default_stance": "peace",
            "stances": {"wilds": "war", "dragon": "war"},
            "ai": {"profile": "clan_standard"},
            "tags": ["clan"],
            "metadata": {
                "magic_tier": clan.get("magic_tier", 0),
                "shrine_bonus": clan.get("shrine_bonus"),
                "passive": clan.get("passive"),
                "specialty_unit": clan.get("specialty_unit"),
                "specialty_building": clan.get("specialty_building"),
                "virtues": virtues.get(cid, {}),
                "start_territory_radius": 2,
            },
        })
    factions.append({
        "id": "wilds", "display_name": "The Wilds", "color": "#7f8c8d",
        "control": "hostile", "starting_units": [],
        "claims_start_territory": False, "default_stance": "war",
        "tags": ["monsters"],
    })
    factions.append({
        "id": "dragon", "display_name": "The Dragon", "color": "#8e2f1c",
        "control": "hostile", "starting_units": [],
        "claims_start_territory": False, "default_stance": "war",
        "tags": ["unique", "dragon"],
    })
    return {"factions": factions}


# ==========================================================================
# sites.json  (shrines, enclaves, towns, villages, lairs, the Veil)
# ==========================================================================
def build_sites(src: dict) -> dict:
    sites: list[dict] = []

    # -- One shrine per clan, placed on random land by the shrine rules module.
    for sid, shrine in src["shrines"]["shrine_definitions"].items():
        clan = shrine["clan_id"]
        sites.append({
            "id": sid,
            "map": "aevum",
            "display_name": shrine.get("name", sid),
            "description": shrine.get("flavor", ""),
            "category": "shrine",
            "placement": "random_land",
            "visual": "site.shrine",
            "sight": 2,
            "capturable": False,
            "discover_intel": [f"location_{sid}"],
            # Meditation itself is a multi-turn process driven by aevum_boot.gd
            # (mantra tier -> turns), triggered by the unit's "meditate" ability
            # while standing on this hex, not an instant site-entry effect. The
            # only automatic site interaction is a passive rumour once any clan
            # has achieved Avatar status.
            "interactions": [{
                "kind": "intel",
                "tokens": ["avatar_declared"],
                "channel": "observed",
                "reliability": 1.0,
                "requires": {"faction_flag": "is_avatar"},
                "once_per_faction": True,
                "message": "Word spreads that a clan has walked every shrine.",
            }],
            "tags": ["shrine", clan],
            "metadata": {
                "clan": clan,
                "bonus_stat": STAT_MAP.get(shrine.get("bonus_stat"), shrine.get("bonus_stat")),
                "bonus_label": shrine.get("bonus_label"),
                "sacred_ground_radius": shrine.get("sacred_ground_radius", 2),
                "placement_rule": shrine.get("placement", {}),
            },
        })

    # -- Clan enclaves (home capitals; the egg must be carried back to one).
    for clan in CLAN_IDS:
        sites.append({
            "id": f"enclave_{clan}",
            "map": "aevum",
            "display_name": f"{clan.title()} Enclave",
            "category": "enclave",
            "placement": "random_land",
            "visual": "site.enclave",
            "owner": clan,
            "sight": 3,
            "defense_bonus": 25,
            "capturable": True,
            "yields": {"gold": 5},
            "tags": ["enclave", "home", clan],
            "metadata": {"clan": clan, "is_home": True},
        })

    sites.extend(_town_sites(src))
    sites.extend(_lair_sites(src))

    # -- The Veil: where the Dragon sleeps and the egg lies.
    sites.append({
        "id": "the_veil",
        "map": "aevum",
        "display_name": "The Veil",
        "description": "The air here is wrong. Something enormous is breathing.",
        "category": "veil",
        "placement": "random_land",
        "visual": "site.veil",
        "sight": 0,
        "hidden_until": {"has": "egg_location", "min_reliability": 0.6},
        "discover_intel": ["veil_found"],
        "spawns": [{"unit": "dragon", "faction": "dragon", "count": 1, "radius": 0}],
        "interactions": [{
            "kind": "reward",
            "items": {"dragon_egg": 1},
            "to": "actor",
            "requires": {"has": "egg_location", "min_reliability": 0.6},
            "once": True,
            "message": "Beneath the Veil, warm and terrible, lies the Dragon's egg. You take it.",
        }],
        "tags": ["veil", "dragon", "egg"],
        "metadata": {"holds_egg": True, "wake_radius": 8},
    })
    return {"sites": sites}


def _town_sites(src: dict) -> list[dict]:
    """Towns become shop + pub-dialogue sites; the pub is the intel market."""
    out: list[dict] = []
    for tid, town in src["towns"]["towns"].items():
        if tid.startswith("_"):
            continue
        stock = [{"item": item, "price": 0} for item in
                 list(town.get("armory_pool", [])) + list(town.get("store_pool", []))]
        interactions = [{
            "kind": "shop",
            "shop_id": f"shop_{tid}",
            "currency": "gold",
            "buys_intel": True,
            "intel_price_multiplier": 1.0,
            "stock": stock,
            "message": f"The markets of {town.get('name', tid)} are open.",
        }, {
            "kind": "intel",
            "tokens": ["pub_rumour", "egg_location_false"],
            "channel": "told",
            "reliability": 0.35,
            "once_per_faction": True,
            "message": "Talk in the pub turns to the shrines, and to the Dragon.",
        }]
        # A town with a Contemplation Hall teaches mantras - the knowledge that
        # turns a twelve-turn meditation into a one-turn one.
        if town.get("contemplation_hall"):
            interactions.append({
                "kind": "intel",
                "tokens": [f"mantra_{clan}" for clan in CLAN_IDS],
                "channel": "read",
                "reliability": 0.8,
                "once_per_faction": True,
                "message": "In the Contemplation Hall the mantras are recited aloud.",
            })
        out.append({
            "id": tid,
            "map": "aevum",
            "display_name": town.get("name", tid.title()),
            "description": town.get("desc", ""),
            "category": "town",
            "placement": "random_land",
            "visual": "site.town",
            "sight": 2,
            "capturable": False,
            "yields": {"gold": 3},
            "interactions": interactions,
            "tags": ["town", "shop", "pub"],
            "metadata": {
                "theme": town.get("theme"),
                "contemplation_hall": town.get("contemplation_hall"),
                "special_services": town.get("special_services", []),
                "pub_personality_pool": town.get("pub_personality_pool", []),
            },
        })
    return out


def _lair_sites(src: dict) -> list[dict]:
    """One lair entrance per biome, descending into the shared lair maps."""
    out: list[dict] = []
    for biome in biomes_of(src["lair_monsters"]):
        target = "lair_crypt" if biome in ("crypt", "ruined") else "lair_cave"
        basic = src["lair_monsters"][biome].get("basic", {})
        guard = basic.get("template_id")
        site = {
            "id": f"lair_{biome}",
            "map": "aevum",
            "display_name": f"{biome.title()} Lair",
            "category": "lair",
            "placement": "random_land",
            "visual": "site.lair",
            "sight": 1,
            "capturable": True,
            "discover_intel": [f"location_lair_{biome}"],
            "interactions": [{
                "kind": "portal",
                "target_map": target,
                "direction": "descend",
                "message": f"You descend into the {biome} lair.",
            }],
            "tags": ["lair", biome],
            "metadata": {"biome": biome},
        }
        if guard:
            site["spawns"] = [{"unit": guard, "faction": "wilds",
                               "count": 2, "radius": 1, "respawn_turns": 10}]
        out.append(site)
    return out


# ==========================================================================
# intel.json  (mantras, shrine locations, monster weaknesses, the egg)
# ==========================================================================
def build_intel(src: dict) -> dict:
    tokens: list[dict] = []

    # -- Where each shrine is, and the mantra that shortens its meditation.
    for sid, shrine in src["shrines"]["shrine_definitions"].items():
        tokens.append({
            "id": f"location_{sid}",
            "title": f"Location of the {shrine.get('name', sid)}",
            "summary": "You know where this shrine stands.",
            "subject": sid, "scope": "site", "category": "location",
            "reliability": 0.9, "corroboration_step": 0.05,
            "spreadable": True, "tradeable": True, "value": 40,
            "reveals": {"sites": [sid], "radius": 2},
            "tags": ["shrine", "location"],
        })
        tokens.append({
            "id": f"mantra_{shrine['clan_id']}",
            "title": f"Mantra of the {shrine.get('name', sid)}",
            "summary": "The word spoken to enter the shrine's silence quickly.",
            "subject": sid, "scope": "site", "category": "password",
            "reliability": 0.8, "corroboration_step": 0.1,
            "spreadable": True, "tradeable": True, "value": 90,
            "tags": ["mantra", shrine["clan_id"]],
            "metadata": {"meditation_tier": "direct"},
        })

    # -- Monster weaknesses (+3 damage when known) and sightings.
    for key, mon in src["monsters"]["monsters"].items():
        tokens.append({
            "id": f"weakness_{key}",
            "title": f"Weakness of the {mon.get('name', key.title())}",
            "summary": mon.get("desc", ""),
            "subject": key, "scope": "unit", "category": "military",
            "reliability": 0.7, "corroboration_step": 0.1,
            "spreadable": True, "tradeable": True, "value": 50,
            "tags": ["weakness", "monster"],
            "metadata": {"weakness_pool": mon.get("weakness_pool", []),
                         "resistance_pool": mon.get("resistance_pool", [])},
        })
        tokens.append({
            "id": f"seen_{key}",
            "title": f"{mon.get('name', key.title())} sighted",
            "subject": key, "scope": "unit", "category": "military",
            "reliability": 0.6, "decay_turns": 12,
            "spreadable": True, "tradeable": True, "value": 10,
            "tags": ["sighting"],
        })

    # -- Lair locations and clearances.
    for biome in biomes_of(src["lair_monsters"]):
        tokens.append({
            "id": f"location_lair_{biome}",
            "title": f"Location of the {biome} lair",
            "subject": f"lair_{biome}", "scope": "site", "category": "location",
            "reliability": 0.8, "spreadable": True, "tradeable": True, "value": 30,
            "reveals": {"sites": [f"lair_{biome}"], "radius": 1},
            "tags": ["lair", "location"],
        })
        tokens.append({
            "id": f"cleared_lair_{biome}",
            "title": f"The {biome} lair is cleared",
            "subject": f"lair_{biome}", "scope": "site", "category": "fact",
            "reliability": 1.0, "spreadable": True, "value": 15,
            "tags": ["lair"],
        })

    tokens.extend(_egg_tokens())

    seen: dict[str, dict] = {}
    for token in tokens:
        seen.setdefault(token["id"], token)
    return {"intel": list(seen.values())}


def _egg_tokens() -> list[dict]:
    """The spine of the game: the egg, the Veil, and a lie about both."""
    return [
        {
            "id": "egg_location",
            "title": "Where the Dragon's egg lies",
            "summary": "The Veil hides it. A Seeker who knows this can walk to it.",
            "subject": "the_veil", "scope": "site", "category": "secret",
            "reliability": 0.5, "corroboration_step": 0.15,
            "secrecy": 0.9, "spreadable": False, "tradeable": True, "value": 400,
            "conflicts": ["egg_location_false"],
            "reveals": {"sites": ["the_veil"], "radius": 2},
            "tags": ["egg", "victory"],
        },
        {
            "id": "egg_location_false",
            "title": "Where the Dragon's egg lies (a lie)",
            "summary": "A confident, wrong answer, sold in three pubs at once.",
            "subject": "the_veil", "scope": "site", "category": "rumor",
            "reliability": 0.4, "spreadable": True, "tradeable": True, "value": 60,
            "conflicts": ["egg_location"],
            "tags": ["egg", "false"],
        },
        {
            "id": "veil_found",
            "title": "The Veil has been found",
            "subject": "the_veil", "scope": "site", "category": "fact",
            "reliability": 1.0, "spreadable": True, "value": 120,
            "tags": ["egg"],
        },
        {
            "id": "pub_rumour",
            "title": "Pub talk",
            "summary": "Half of it is true.",
            "subject": "aevum", "scope": "global", "category": "rumor",
            "reliability": 0.35, "decay_turns": 20,
            "spreadable": True, "tradeable": False, "value": 5,
            "tags": ["rumour"],
        },
        {
            "id": "avatar_declared",
            "title": "A clan has become Avatar",
            "subject": "aevum", "scope": "faction", "category": "diplomatic",
            "reliability": 1.0, "spreadable": True, "value": 80,
            "tags": ["avatar"],
        },
    ]


# ==========================================================================
# intel_rules.json
# ==========================================================================
def build_intel_rules(src: dict) -> dict:
    return {
        "derivations": [{
            "id": "triangulate_egg",
            "description": "Sighting the Veil and hearing the pub talk pins the egg.",
            "when": {"all": [
                {"has": "veil_found"},
                {"has": "pub_rumour", "min_reliability": 0.3},
            ]},
            "grant": "egg_location",
            "reliability": 0.75,
            "once": True,
        }],
        "spread": [
            {"tokens": ["pub_rumour"], "filter": "all", "chance": 0.15, "decay": 0.05},
            {"tokens": ["avatar_declared"], "filter": "all", "chance": 0.5},
            {"tokens": ["egg_location_false"], "filter": "all", "chance": 0.2},
        ],
        "contradiction": {"resolve": "reliability", "penalty": 0.2},
        "observation": {"units": True, "sites": True},
    }


# ==========================================================================
# ai_profiles.json
# ==========================================================================
def build_ai_profiles(src: dict) -> dict:
    return {
        "profiles": {
            "idle": {"behavior": "idle"},
            "guard": {"behavior": "guard", "radius": 1, "attack_range": 2},
            "explorer": {"behavior": "explore"},
            "aggressor": {"behavior": "hunt", "flee_below_health": 0.2},
            "hunter": {"behavior": "hunt", "sight_bonus": 1, "flee_below_health": 0.3},
            "seeker": {"behavior": "explore", "flee_below_health": 0.9},
            "dragon": {"behavior": "guard", "radius": 8, "attack_range": 1},
            "clan_standard": {"behavior": "explore"},
        },
        "abilities": {},
    }


# ==========================================================================
# assets.json  (placeholder-backed; real art is imported in a later phase)
# ==========================================================================
def build_assets(terrains: dict, units: dict, items: dict, sites: dict) -> dict:
    assets: dict[str, dict] = {}

    for tile in terrains["terrains"]:
        assets[tile["visual"]] = {
            "type": "texture",
            "path": f"res://assets/tiles/placeholder/{tile['id']}.png",
        }
    for unit in units["units"]:
        assets[unit["visual"]] = {
            "type": "sprite_frames",
            "path": f"res://assets/units/{unit['id']}/frames.tres",
            "facings": 6,
        }
        # The validator resolves a portrait key for every unit, defaulting to
        # portrait.<id>; declare them so the manifest is complete.
        assets[f"portrait.{unit['id']}"] = {
            "type": "texture",
            "path": f"res://assets/characters/portraits/{unit['id']}.png",
        }
    for item in items["items"]:
        assets[item["icon"]] = {
            "type": "texture",
            "path": f"res://assets/items/icons/{item['id']}.png",
        }
    for site in sites["sites"]:
        visual = site.get("visual")
        if visual and visual not in assets:
            name = visual.split(".", 1)[1]
            assets[visual] = {"type": "scene",
                              "path": f"res://assets/structures/{name}/{name}.tscn"}
    for key in ("env.overworld", "env.cave", "env.crypt"):
        assets[key] = {"type": "environment",
                       "path": f"res://assets/env/{key.split('.')[1]}.tres"}
    for key in ("music.overworld", "music.lair"):
        assets[key] = {"type": "audio",
                       "path": f"res://assets/audio/{key.split('.')[1]}.ogg"}
    return {"assets": assets}


# ==========================================================================
# entry point
# ==========================================================================
SOURCE_FILES = ["terrain", "clans", "unit_types", "monsters", "lair_monsters",
                "lair_bosses", "items", "castle_items", "town_items", "shrines",
                "towns", "villages", "virtues", "spells", "technologies",
                "buildings", "structures"]


def convert(source: Path) -> dict[str, dict]:
    src = {name: load(source, name) for name in SOURCE_FILES}

    terrains = build_terrains(src)
    units = build_units(src)
    items = build_items(src)
    sites = build_sites(src)
    return {
        "game": build_game(src),
        "terrains": terrains,
        "maps": build_maps(src),
        "units": units,
        "items": items,
        "factions": build_factions(src),
        "intel": build_intel(src),
        "intel_rules": build_intel_rules(src),
        "sites": sites,
        "ai_profiles": build_ai_profiles(src),
        "assets": build_assets(terrains, units, items, sites),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Convert Aevum data to a Godot package.")
    parser.add_argument("--source", default=r"C:\Aevum",
                        help="root of the original Python Aevum project")
    parser.add_argument("--out", default=str(Path(__file__).resolve().parents[1]),
                        help="destination game package directory")
    parser.add_argument("--check", action="store_true",
                        help="do not write; exit non-zero if output would change")
    args = parser.parse_args(argv)

    source = Path(args.source)
    out = Path(args.out)
    if not (source / "assets" / "data").is_dir():
        print(f"error: no assets/data under {source}", file=sys.stderr)
        return 2

    payloads = convert(source)
    stale = []
    for name, payload in payloads.items():
        target = out / f"{name}.json"
        new = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
        old = target.read_text(encoding="utf-8") if target.exists() else None
        if old != new:
            stale.append(name)
            if not args.check:
                write(out, name, payload)

    if args.check:
        if stale:
            print("STALE: " + ", ".join(sorted(stale)), file=sys.stderr)
            return 1
        print("up to date")
        return 0

    counts = {
        "terrains": len(payloads["terrains"]["terrains"]),
        "maps": len(payloads["maps"]["maps"]),
        "units": len(payloads["units"]["units"]),
        "abilities": len(payloads["units"]["abilities"]),
        "items": len(payloads["items"]["items"]),
        "factions": len(payloads["factions"]["factions"]),
        "intel": len(payloads["intel"]["intel"]),
        "sites": len(payloads["sites"]["sites"]),
        "assets": len(payloads["assets"]["assets"]),
    }
    print(f"wrote {len(payloads)} files to {out}")
    for key, val in counts.items():
        print(f"  {key:>10}: {val}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
