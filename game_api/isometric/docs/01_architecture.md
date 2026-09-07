# 01 · Vision & Architecture

## Vision
A reusable Godot 4 platform for **isometric / hex, tile-based, turn- or time-based
strategy games** where *what you know* matters as much as *what you own*. Think Civ 6
macro loop (explore → expand → exploit → exterminate) with a Thief/Disco-Elysium
attitude to information: rumours, sources, lies, decay, and gated content.

Every game is a **data package** (`games/<id>/`). The framework never hardcodes a
setting. If a mechanic can be expressed as data + a pluggable strategy, it is.

## Layering
```
scenes/main.tscn  ─►  core autoloads  ─►  framework classes  ─►  games/<id>/*.json
   (boot, camera,     (state, registries,   (models, nodes,        (content)
    cursor, HUD)       turn/clock, save)     strategies)
```
* **core/** — autoload singletons. They own *runtime state* and load data through
  `DataLoader`. They never reference UI. Cross-cutting events go through **EventBus**.
* **framework/** — typed `Resource`/`RefCounted` models built from JSON (`*Definition`),
  runtime nodes (`Unit`, `WorldRenderer`), and strategy hooks (`GridTopology`,
  `MapGenerator`, `Interaction`, `CombatResolver`, `AIController`).
* **games/** — JSON only (plus optional per-game scenes/scripts if a game needs them).

## Autoload responsibilities
| Autoload | Owns |
|---|---|
| `EventBus` | Every engine-level signal (turns, world, units, intel, items, UI, persistence). |
| `AssetRegistry` | Logical asset key → resource; placeholder generation for missing art. |
| `GameManager` | Package loading order, high-level state machine, global flags, `rule()` lookup. |
| `GameClock` | Turn number, ticks (real-time modes), calendar/era labels; `now()` in turns. |
| `TurnManager` | Turn modes, phases, turn order, commits, timers. |
| `FactionRegistry` | Faction definitions/instances, relationships, victory check. |
| `ItemRegistry` | Item definitions. |
| `EntityRegistry` | Unit definitions, ability catalog, AI profiles, all live units, selection. |
| `IntelRegistry` | Token definitions, per-faction journals, rules (derive/spread/contradict). |
| `WorldManager` | Terrain/map/site definitions, live `WorldMap`, sites, descent stack, renderer. |
| `SaveManager` | Versioned JSON aggregate of every `to_save_data()`. |

## Load order (GameManager.load_game)
assets → items → intel(+rules) → factions → units(+ai) → world config → terrains/maps/sites → clock → turns.
`start_new_game()` then: reset journals/factions/units/clock → generate root map → instantiate
factions → place starting units/territory & site spawns → `PLAYING` → `TurnManager.start()`.

## Extension points (register at startup, e.g. from a per-game autoload)
* `MapGenerator.register(type, Callable(world, def, rng))`
* `InteractionFactory.register(kind, GDScript)`
* `AIController.register_behavior(name, Callable(unit, profile, rng))`
* `FactionRegistry.register_faction_ai(profile, Callable(faction))`
* `CombatResolver.active = MyResolver.new()`
* Any `EventBus` signal.

## Conventions
* GDScript: tabs, typed where inference is ambiguous (Godot treats "cannot infer" as an
  error), `##` doc comments on every class and public method.
* IDs are `snake_case`; asset keys are dotted (`tile.grassland`, `unit.scout`).
* Everything that persists implements `to_save_data()/from_save_data()`.
* Time is measured in **turns** (`GameClock.now()`), never wall-clock.
