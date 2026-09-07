# Game Platform API

The platform is **one set of game mechanics** (`core/addons/game_core/`) driven
by **two interchangeable graphics engines** (`game_api/isometric/`,
`game_api/fps/`). Everything below is engine-agnostic unless marked otherwise.

```
                     ┌──────────────────────────────┐
   your game  ─────► │  game_core  (this document)  │
                     │  units · items · intel ·     │
                     │  factions · stats · registry │
                     └───────────────┬──────────────┘
                                     │ CoreEngineAdapter
                     ┌───────────────┴──────────────┐
                     ▼                              ▼
        game_api/isometric (2D hex/iso)   game_api/fps (3D first person)
```

## The one rule

Core code **never** references a graphics engine. Every engine-dependent
question (where is this? who can see it? what time is it?) goes through
`CoreContext.adapter`. That is why the same `items.json` and the same intel
query JSON work unchanged in both engines.

---

## `CoreContext` (autoload)

The seam between the platform and whichever engine is hosting it.

| Method | Returns | Description |
|---|---|---|
| `install(adapter)` | – | Install the engine adapter. Called once at boot. |
| `configure(config)` | – | Set `rules` and the deterministic seed from `game.json`. |
| `reset()` | – | Clear per-run state (flags), keep the adapter. |
| `now()` | `float` | Current time in the **host engine's unit** (turns / game seconds). |
| `set_flag(flag, value=true)` | – | Set a global progression flag. |
| `has_flag(flag)` | `bool` | Read a global flag. |
| `rule(path, default)` | `Variant` | Dotted rule lookup, e.g. `rule("combat.randomness", 0.2)`. |
| `rng()` | `RandomNumberGenerator` | Shared seeded RNG — a seeded game replays identically in both engines. |
| `to_save_data()` / `from_save_data(d)` | `Dictionary` / – | Persistence. |

Signals: `adapter_installed(adapter)`, `flag_set(flag, value)`.

> **Time units.** The isometric engine reports `now()` in **turns**; the FPS
> engine reports **game seconds**. Core code only ever *subtracts and compares*
> these values, so an intel token's `decay_turns: 10` means "10 turns" in the
> iso engine and "10 seconds of game time" in the FPS engine. Author your data
> for the engine you are targeting.

---

## `CoreEngineAdapter`

Base class each graphics engine extends. The default implementation is
**fully functional and headless**, so core systems and unit tests run with no
graphics engine at all.

| Method | Default | Isometric | FPS |
|---|---|---|---|
| `now()` | internal clock | `GameClock.turn` | `GameClock.now()` seconds |
| `distance(a, b)` | `0.0` | hex/iso tile distance (`Vector2i`) | metres (`Vector3`) |
| `can_see(obs, target)` | `false` | sight stat vs tile distance | `Perception` component raycast |
| `position_of(id)` | `null` | `Vector2i` tile coord | `Vector3` world position |
| `are_hostile(a, b)` | `false` | faction diplomacy | faction data + player reputation |
| `unit_count(holder, def)` | `0` | `EntityRegistry.count_units` | actors in the `actors` group |
| `holder_flag(holder, flag)` | `false` | per-faction flag | global flag (single player) |
| `holder_resource(holder, id)` | `0.0` | faction stockpile | player inventory currency |
| `stance(holder, other)` | `"neutral"` | diplomacy stance | reputation mapped to stance |
| `owns_site(holder, site)` | `false` | controls the site's tile | POI cleared flag |
| `notify(text, category)` | no-op | HUD toast | HUD toast |
| `reveal(holder, reveals)` | no-op | clears fog of war | marks maps/POIs discovered |

Stances: `allied` · `friendly` · `neutral` · `wary` · `hostile` · `war`.

---

## `CoreRegistry` (autoload)

Loads and stores every data-driven definition.

| Method | Returns | Description |
|---|---|---|
| `register_type(name, script, file, key, optional=false)` | – | Teach the registry a new data type. |
| `load_package(base_path)` | – | Load every registered type from a game folder. |
| `load_type(name)` | – | Reload one type. |
| `add(name, def)` | – | Register a runtime-generated definition. |
| `get_def(name, id)` | `CoreDefinition` | Look up one definition. |
| `has(name, id)` | `bool` | Existence check (no warning). |
| `all(name)` / `ids(name)` | `Array` | Every definition / every id. |
| `with_tag(name, tag)` | `Array` | Filter by tag. |
| `filter(name, property, value)` | `Array` | Filter by any property. |
| `clear()` | – | Drop everything. |

Built-in types: `items`, `units`, `intel`, `factions`. Each graphics engine
registers its own extra types (`maps`, `terrains`, `sites`, `pois`) against the
same registry.

Adding a data type is two lines:

```gdscript
CoreRegistry.register_type("quests", MyQuestDefinition, "quests.json", "quests", true)
CoreRegistry.load_type("quests")
```

Signals: `package_loaded(base_path)`, `type_loaded(type_name, count)`.

---

## `CoreIntel` (autoload)

Information as a first-class resource — the deepest shared mechanic. A
**holder** is a faction id (isometric) or `"player"` (FPS).

| Method | Returns | Description |
|---|---|---|
| `journal_for(holder)` | `CoreIntelJournal` | Get/create a holder's journal. |
| `acquire(holder, token_id, source, channel, trust)` | `bool` | Learn a token, or corroborate one already held. |
| `knows(holder, token_id, min_reliability=0)` | `bool` | Belief check. |
| `evaluate(query, holder)` | `bool` | Run an intel query (see below). |
| `forget(holder, token_id)` | – | Drop a token. |
| `debunk(holder, token_id)` | – | Mark as a proven lie **and** penalise every other token from the same source. |
| `spread(from, to, token_id)` | `bool` | Propagate between holders; blocked by `secrecy`. |
| `trade(from, to, token_id)` | `int` | Sell a token; returns price (`value × reliability`) or `-1` if refused. |
| `prune_stale(holder)` | `Array[String]` | Emit `expired` for newly stale tokens. Call once per turn/tick. |
| `to_save_data()` / `from_save_data(d)` | `Dictionary` / – | Persistence. |

Channels: `observed` · `told` · `read` · `traded` · `stolen` · `spread` ·
`derived` · `scripted`.

Signals: `acquired` · `updated` · `expired` · `spread_completed` · `traded` ·
`contradiction_found` · `debunked`.

**Corroboration model.** Acquiring a token you already hold from a *new* source
raises reliability by `corroboration_step × trust` and refreshes its decay
window. Re-acquiring from the *same* source does nothing. This is what makes
"ask three different people" a real mechanic.

```gdscript
CoreIntel.acquire("blue", "crypt_location", "scout", "observed")     # reliability 0.4
CoreIntel.acquire("blue", "crypt_location", "scout", "told")         # no change
CoreIntel.acquire("blue", "crypt_location", "innkeeper", "told")     # reliability 0.7
```

### `CoreIntelJournal`

`add` · `has(id)` · `get_token(id)` · `forget(id)` · `clear()` · `size()` ·
`known(now, allow_stale)` · `tokens_about(subject, now)` ·
`tokens_with_tag(tag, now)` · `tokens_in_scope(scope, now)` ·
`tokens_in_category(cat, now)` · `tradeable(now)` · `contradictions()`.

### `CoreIntelQuery` — the gating language

A query is plain JSON, evaluated against a holder. Used by item `requires`,
ability gates, shop stock, dialogue options, portals and rewards.

| Form | Meaning |
|---|---|
| `{"has": "id"}` | holder holds the token |
| `{"has": "id", "min_reliability": 0.7}` | …believed at least this strongly |
| `{"has": "id", "allow_stale": true}` | …even if decayed |
| `{"has": "id", "max_age": 5}` | …learned within N time units |
| `{"subject": "baron", "count": 2}` | knows ≥ N tokens about a subject |
| `{"tag": "location", "count": 1}` | knows ≥ N with a tag |
| `{"scope": "site"}` / `{"category": "military"}` | by scope / category |
| `{"fact": ["id", "key", "value"]}` | the token's `facts[key] == value` |
| `{"provenance": ["id", "observed"]}` | arrived via that channel |
| `{"source": ["id", "scout"]}` | that source vouched for it |
| `{"contradicted": "id"}` | holder also holds a conflicting token |
| `{"flag": "gate_open"}` | global flag |
| `{"holder_flag": "met_elders"}` | holder-scoped flag |
| `{"resource": ["gold", ">=", 50]}` | holder stockpile |
| `{"time": [">=", 10]}` | engine clock |
| `{"owns_site": "id"}` | holder controls the site |
| `{"unit_count": ["scout", ">=", 1]}` | holder owns ≥ N of a unit |
| `{"stance": ["red", "war"]}` | diplomatic stance |
| `{"all": [...]}` `{"any": [...]}` `{"not": {...}}` | boolean grouping |

An empty query `{}` is always true. `CoreIntelQuery.is_valid_shape(q)` checks a
query offline (for validators) with no game state.

```json
{"all": [
  {"has": "crypt_location", "min_reliability": 0.6},
  {"not": {"contradicted": "crypt_location"}},
  {"resource": ["gold", ">=", 100]}
]}
```

---

## Interactions — the universal "do something" primitive

Used by places, item use, abilities, dialogue nodes and intel token effects.
A spec is plain JSON with a `kind`; the shared gating keys work on **every**
kind:

| Key | Meaning |
|---|---|
| `requires` | `CoreIntelQuery` the acting holder must satisfy |
| `flags` / `holder_flags` | global / holder-scoped flags that must be true |
| `once` | runs a single time ever |
| `once_per_holder` | runs once per faction/player |
| `chance` | 0..1, rolled on the shared seeded RNG |
| `consumes` | stop the list here (default `true`) |
| `message` | notification routed to the engine HUD |

Built-in kinds (both engines' sets, unified):

| Kind | Effect |
|---|---|
| `intel` | grant / `debunk` / `forget` / `share` tokens |
| `reward` | resources, items, `stat_delta`, `xp`, `heal_full`, flags |
| `flag` | flags, **quest stages**, diplomacy `stance` |
| `portal` | descend into another map |
| `spawn` | spawn units (`"faction": "actor"` = the acting holder) |
| `shop` | open trade; stock is itself intel-gateable |
| `dialogue` | start a tree, granting "we've met" intel |
| `combat` | fight, then run `on_victory` / `on_defeat` sub-interactions |

```gdscript
CoreInteractionFactory.register("ritual", MyRitualInteraction)   # add a kind
var list := CoreInteractionFactory.create_all(place_def.interactions, place_id, state)
CoreInteractionFactory.run_all(list, "blue", actor)              # ordered dispatch
```

Quests need no subsystem — `{"kind": "flag", "quest": {"id": "sunken_crypt",
"stage": "cleared"}}` records `quest.sunken_crypt.cleared` and emits
`CoreContext.quest_stage_reached`. Query with `has_quest_stage()` /
`quest_stages()`.

### `CorePlace` — a live place

`discover(holder)` · `is_revealed_to()` · `can_enter()` · `interact()` ·
`capture()` · `spawn_garrison()` · `to_save_data()` / `from_save_data()`.
`interact()` checks the intel gate and any `requires_access` capability,
records discovery, then dispatches the interaction list in order.

## Intel exchange (`CoreIntelRules`)

Loaded from `intel_rules.json` via `CoreIntel.load_rules(path)`. This is what
makes knowledge *move*.

**Derivations** — infer what nobody told you. Run automatically on every
acquisition, so a chain completes the moment its last clue lands:

```json
{"id": "triangulate_crypt",
 "when": {"all": [{"has": "rumor_crypt_west", "min_reliability": 0.5},
                  {"has": "rumor_crypt_reeds", "min_reliability": 0.5},
                  {"has": "ruin_inscription"}]},
 "grant": "crypt_location", "reliability": 0.65, "once": true}
```

**Spread** — knowledge leaks between holders, filtered by relationship,
category and secrecy, arriving degraded. The effective roll is
`chance × (1 − secrecy)`, so secretive intel leaks rarely even when eligible.

```json
{"id": "trade_gossip", "between": "trade_partners", "chance": 0.15,
 "max_secrecy": 0.35, "reliability_loss": 0.2, "categories": ["rumor"]}
```

Relations (`trade_partners`, `neighbors`, `allies`, `all`) resolve through
`CoreEngineAdapter.related_holders()` — factions in the isometric engine, a
single `"player"` holder in the FPS engine.

**Deliberate exchange**

| Call | Semantics |
|---|---|
| `CoreIntel.trade(from, to, id)` | priced at `value × reliability`; `-1` if refused |
| `CoreIntel.give(from, to, id)` | free hand-over; **ignores secrecy** — the holder chose to tell |
| `CoreIntel.spread(from, to, id)` | one probabilistic leak, gated by secrecy |
| `CoreIntel.debunk(holder, id)` | prove a lie; every other token from that source loses trust |

**Contradiction** — holding two conflicting tokens disputes both by
`dispute_amount`, so believing a lie and the truth at once leaves you sure of
neither.

`CoreIntel.tick()` runs derive → spread → expire; call it once per turn
(isometric) or on a timer (FPS).

---

## Schema classes (the data contract)

All extend `CoreDefinition`, which supplies `id`, `display_name`,
`description`, `tags`, `metadata`, plus `has_tag(tag)` and `extra(key)` —
`extra()` reads any JSON key the engine does not know about, so games can carry
their own fields without losing them.

### `CoreItemDefinition` (`items.json`)

Merged superset of both engines. `category` (FPS) and `kind` (iso) are aliases;
so are `equip_slot`/`slot`, `stats`/`modifiers`, `consumed_on_use`/`consume_on_use`,
and `requires`/`use_requires`.

Categories: `weapon` `armor` `accessory` `consumable` `ammo` `key` `tome`
`material` `quest` `currency` `artifact` `resource` `misc`.

| Group | Fields |
|---|---|
| Basics | `category` `rarity` `weight` `value` `stackable` `max_stack` `unique` |
| Equipment | `equip_slot` `two_handed` `stats` `stats_percent` `damage` `resistances` `durability` |
| Behaviour | `effects` `abilities` `procs` `use_effects` `use_ability` `teaches_ability` `consumed_on_use` `grants_intel` |
| Gating | `requires` (intel query) `requires_stats` `identified_by_default` `identify_intel` `lore_intel` |
| Visuals | `icon_key` `visual_key` `view_model_key` (FPS) `affix_pool` |

Helpers: `category_name()` `is_equippable()` `is_usable()` `is_weapon()`
`average_damage()`.

### `CoreUnitDefinition` (`units.json`)

Anything alive or agentive: player, hero, NPC, monster, town guard, structure.
Roles: `player` `hero` `npc` `monster` `animal` `structure` `caravan` `prop`.

`role` `faction_id` `stats` `abilities` `equipment` `inventory` `loot`
`ai_profile` `intel_profile` `dialogue_id` `level` `xp_value` `mobile`
`hostile_by_default` `visual_key` `portrait_key` `move_speed`.

Helpers: `is_hero()` `is_mobile()` `base_stat(name)` `roll_loot(rng)`.

> `move_speed` is generic: tiles-per-turn in the iso engine, metres-per-second
> in the FPS engine.

### `CoreIntelToken` (`intel.json`)

`title` `summary` `subject` `scope` `category` `facts` `base_reliability`
`corroboration_step` `decay_turns` `conflicts` `secrecy` `spreadable`
`tradeable` `value` `reveals` `effects`.

Runtime (per journal instance): `reliability` `provenance` `acquired_at`
`confirmed_at` `known_false` `revealed_applied`.

Helpers: `duplicate_instance()` `sources()` `corroborate(prov)` `dispute(amt)`
`is_stale(now)` `age(now)` `time_remaining(now)` `trade_value()`.

Scopes: `global` `region` `tile` `site` `unit` `faction` `item`.

### `CoreFactionDefinition` (`factions.json`)

`color` `starting_reputation` `hostile_to` `allied_to` `default_stance`
`playable` `takes_turns` `resources` `ai_profile` `starting_intel` `banner_key`.
Helpers: `stance_toward(id)` `is_hostile_to(id)`.

### `CorePlaceDefinition` (`places.json`)

**Any place worth visiting**: town, village, city, castle, keep, tower, shrine,
temple, lair, dungeon, crypt, cave, ruins, portal, gate, mine, farm, market,
inn, cache, landmark — and anything a game invents. Replaces the isometric
`SiteDefinition` and the FPS `PoiDefinition`.

| Group | Fields |
|---|---|
| Identity | `category` `map_id` `parent_place_id` |
| Placement | `coord` (2D) · `position`/`yaw` (3D) · `placement` `placement_rules` |
| Control | `owner_id` `capturable` `defense_bonus` `sight` `yields` |
| Population | `garrison` `boss` `population` |
| Access | `hidden_until` `enter_requires` `requires_access` `discover_intel` `discover_radius` `interact_radius` |
| Behaviour | `interactions` `contains` `leads_to` |
| Extension | `traits` (+ anything else, via `extra()`) |
| Visuals | `visual_key` `icon_key` `music_key` `environment_key` |

Query by **trait**, not by category string — that way a game's `dragon_lair`
answers correctly without the framework knowing it exists:

```gdscript
place.is_settlement()  place.is_fortification()  place.is_sacred()
place.is_dangerous()   place.is_economic()       place.is_transit()
place.is_enterable()   place.is_capturable()     place.has_garrison()
place.has_trait("flying_only")      # game-defined boolean
place.trait_value("storm_risk", 0)  # game-defined value
place.garrison_units()              # boss first, then garrison
place.yield_of("pearls")
```

## Extending everything

Four independent mechanisms, usable together. None require touching the core.

**1. Archetype inheritance** — inherit a base, state only the deltas.
Dictionaries deep-merge; arrays and scalars replace.

```json
{"id": "hollowmere", "extends": "village", "display_name": "Hollowmere",
 "owner": "greywood"}
```

The framework ships `village` `town` `city` `castle` `tower` `shrine` `temple`
`lair` `dungeon` `ruins` `cache` `portal` `mine` `resource` `inn` `landmark`
in `addons/game_core/data/places.json`. Chains are arbitrarily deep
(`city` → `town` → `village`) and cycles are reported, not fatal.

**2. New categories** — plain strings; registering only supplies defaults.

```gdscript
CorePlaceDefinition.register_category("dragon_lair", {
    "dangerous": true, "capturable": true, "defense_bonus": 60.0,
    "flying_only": true,
})
```

**3. Arbitrary traits and fields** — anything unmapped survives in `raw`.

```json
{"id": "cinderpeak", "extends": "lair", "category": "dragon_lair",
 "boss": "ancient_red_dragon", "yields": {"treasure": 5},
 "traits": {"flying_only": true, "heat_damage": 3},
 "hoard_size": 9000,
 "hidden_until": {"has": "rumor_the_burning_peak"}}
```

`place.trait_value("heat_damage")` → `3`; `place.extra("hoard_size")` → `9000`.

**4. Runtime instantiation** — build from an archetype with no authored entry,
for procedural generation:

```gdscript
var shoal := CoreRegistry.instantiate("places", "resource", {
    "id": "pearl_shoal", "category": "island_resource",
    "yields": {"pearls": 3}, "requires_access": "boat",
    "placement": "random_coast",
    "traits": {"island": true, "storm_risk": 0.2},
}) as CorePlaceDefinition
```

Registry support for all of this is generic — `load_archetypes()`,
`add_archetype()`, `archetype_ids()` and `instantiate()` work for **every**
definition type, not just places.

### `CoreProvenance`

One link in a token's chain of custody: `source_id` `channel` `at` `trust`
`via_holder` `note`. Built with `CoreProvenance.make(source, channel, at, trust, via)`.

---

## Gameplay components

### `CoreStats`

Base values + named modifier groups; current values always clamped to the
modified maximum.

`define_from(defaults, overrides)` · `has_stat` · `stat_names()` ·
`max_value(stat)` · `get_value` · `set_value` · `modify(stat, delta)` ·
`ratio(stat)` · `restore` · `restore_all` · `add_modifier(source, deltas)` ·
`remove_modifier(source)` · `raise_base(stat, delta)` ·
`to_save_data()` / `from_save_data(d)`.

Signals: `stat_changed(stat, value, max_value)`, `depleted(stat)`.

Modifier sources are namespaced by convention: `equip:weapon`, `status:poison`,
`item:relic`. Conventional stats the platform reads: `health` `strength`
`ranged` `defense` `moves` `sight` `perception`.

```gdscript
var stats := CoreStats.new()
stats.define_from({"health": 10.0, "strength": 5.0}, unit_def.stats)
stats.add_modifier("equip:weapon", {"strength": 2.0})   # max 7
stats.remove_modifier("equip:weapon")                   # back to 5
```

### `CoreInventory`

Items + equipment + currency. Attach to a unit or to a faction/town stockpile.

`add_item(id, count)` · `remove_item(id, count)` · `has_item` · `count(id)` ·
`items_of_category(cat)` · `use_item(id)` · `equip(id)` · `unequip(slot)` ·
`equipped_in(slot)` · `currency(id)` · `add_currency` · `spend_currency` ·
`total_value()` · `total_weight()` · `to_save_data()` / `from_save_data(d)`.

Signals: `item_added` `item_removed` `item_used` `item_equipped`
`item_unequipped` `currency_changed` `use_refused(item_id, reason)`.

Setting `inv.stats = my_stats` makes equipping automatically apply and remove
the item's `stats` as an `equip:<slot>` modifier. Using or equipping an item
whose `requires` query fails emits `use_refused` and changes nothing.

---

## Writing a game

```gdscript
# 1. Boot: bind the platform to this project's graphics engine.
CoreContext.install(IsoEngineAdapter.new())        # or FpsEngineAdapter.new()

# 2. Load the data package.
var config := CoreDataLoader.load_json("res://games/my_game/game.json")
CoreContext.configure(config)
CoreRegistry.load_package("res://games/my_game")

# 3. Build an actor from shared definitions.
var def := CoreRegistry.get_def("units", "hero") as CoreUnitDefinition
var stats := CoreStats.new()
stats.define_from(config.get("stats", {}), def.stats)

var inv := CoreInventory.new("hero", "player")
inv.stats = stats
for item_id in def.equipment:
    inv.add_item(item_id)
    inv.equip(item_id)

# 4. Gate content on knowledge.
if CoreIntel.evaluate({"has": "crypt_location", "min_reliability": 0.6}, "player"):
    open_the_crypt_portal()
```

Only step 1 differs between the two engines.

## Extending the platform

1. Add a `CoreDefinition` subclass under `core/addons/game_core/schema/`.
2. `CoreRegistry.register_type(...)` it.
3. Add a GUT test under `core/tests/unit/`.
4. `./tools/sync_core.ps1` then `./tools/run_tests.ps1`.

Engine-specific behaviour never goes in `core/` — add it to the relevant
`CoreEngineAdapter` subclass instead.
