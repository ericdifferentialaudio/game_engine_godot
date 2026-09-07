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
