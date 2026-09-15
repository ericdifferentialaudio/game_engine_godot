---
name: core-platform
description: Working on the shared engine-agnostic platform (core/addons/game_core/) — CoreContext, CoreEngineAdapter, CoreRegistry, definitions and archetypes, CoreStats, CoreInventory, the intel system (reliability, corroboration, provenance, decay, contradiction, spread, trade), places, interactions, goal selection and road building. Use when the task mentions core, game_core, Core* classes, intel, registry, definitions, or the engine seam.
---

# Core platform (`core/addons/game_core/`)

Everything a game needs that is **not graphics**: units, items, NPCs, monsters,
factions, places, stats, inventory, interactions, and a deep information/"intel"
system. It never references either renderer.

## Layout

```
core/
  addons/game_core/
    core_context.gd          autoload: the engine seam
    core_engine_adapter.gd   base class each engine extends (headless default)
    data/                    CoreDataLoader
    schema/                  CoreDefinition + subclasses
    gameplay/                CoreStats, CoreInventory, intel types
    managers/                CoreRegistry, CoreIntel, CoreGoalSelector,
                             CoreRoadBuilder, ...
  data/                      shared .tres/.json instances
  tests/unit/                GUT tests for the platform in isolation
```

`core/project.godot` is a **minimal headless test harness**, not a playable game.

## The one rule

Core never references a graphics engine. Every engine-dependent question goes
through `CoreContext.adapter`. The default `CoreEngineAdapter` is fully
functional and headless, so core systems and unit tests run with no renderer.

If you need a new engine-dependent fact: add a method to `CoreEngineAdapter`
with a safe default, then implement it in `IsoEngineAdapter` and
`FpsEngineAdapter`. Alternatively inject `Callable`s (the `CoreRoadBuilder`
pattern) when the dependency is a pure algorithm's neighbors/cost/distance.

## Key APIs (full reference: `docs/API.md`)

- **`CoreContext`** — `install(adapter)` · `configure(config)` · `reset()` ·
  `now()` · `set_flag` / `has_flag` · `rule("dotted.path", default)` · `rng()` ·
  `to_save_data()` / `from_save_data()`. Signals `adapter_installed`, `flag_set`.
  `rng()` is the **shared seeded RNG** — all randomness must come from it so a
  seeded game replays identically in both engines.
- **`CoreRegistry`** — `load_package(path)` · `get_def(type, id)` ·
  `register_type(...)` · `load_archetypes()` / `add_archetype()` /
  `archetype_ids()` / `instantiate()`. Archetype inheritance is generic across
  every definition type.
- **`CoreIntel`** — `evaluate(query, holder)` and the journal/corroboration/
  provenance/decay/contradiction/debunk machinery, plus exchange (derivation,
  spread, trade, give). `CoreProvenance.make(source, channel, at, trust, via)`.
- **`CoreStats`** — `define_from(defaults, overrides)` · `get_value`/`set_value` ·
  `modify` · `ratio` · `add_modifier(source, deltas)` / `remove_modifier` ·
  `raise_base`. Modifier sources are namespaced `equip:weapon`, `status:poison`,
  `item:relic`. Conventional stats: `health` `strength` `ranged` `defense`
  `moves` `sight` `perception`.
- **`CoreInventory`** — items + equipment + currency; set `inv.stats = my_stats`
  to make equipping auto-apply the item's stats as an `equip:<slot>` modifier.
  A failing `requires` query emits `use_refused` and changes nothing.

## Conventions

- Persistence: `to_save_data() -> Dictionary` / `from_save_data(d) -> void`.
- Typed GDScript throughout; `class_name Core*` for anything shared.
- **Lenient JSON.** Authored data writes single-element lists as bare strings and
  `equipment` as a slot map. Always use `CoreDataLoader.str_array()` /
  `packed_str_array()` — never a raw `PackedStringArray(...)` cast.
- Time is the host engine's unit (turns vs. game seconds); only subtract and compare.
- Prefer signals over calling back into callers.

## Adding a subsystem

1. `CoreDefinition` subclass in `core/addons/game_core/schema/`.
2. `CoreRegistry.register_type(...)`.
3. GUT test in `core/tests/unit/`.
4. `./tools/sync_core.ps1` — **mandatory**, Godot can't resolve `res://` across
   project roots.
5. `./tools/run_tests.ps1` — baseline core 130/130.

## Current direction

See `activeContext.md`. In flight: `CoreMapDefinition` + portals (recursive
containment: overworld → town → tavern → cellar), converting a package to
`places.json`, and retiring the engines' duplicate classes one subsystem at a
time (`DataLoader` → `Definition` → `ItemDefinition` → `Stats` → `Inventory` →
intel types → `Interaction` → unit/faction defs → site/POI defs), keeping all
suites green at every step.
