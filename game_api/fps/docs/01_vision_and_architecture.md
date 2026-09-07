# 01 — Vision & Architecture

## What we are building
A reusable **framework on Godot 4 (Forward+)** for first-person fantasy games whose
core loop is *gathering, weighing and spending information*. Combat may exist, but
the interesting verbs are: explore → discover POI → extract intel → corroborate /
resolve contradictions → unlock (shops, portals, rewards) → go deeper.

Genre/theme is data, not code: the framework never mentions "fantasy". Every game
is a **package** under `games/<id>/` made of JSON + map scenes.

## Layering (dependency flows downward only)
```
┌──────────────────────────────────────────────────────────────┐
│ games/<id>/         content: JSON data, map .tscn, art keys   │
├──────────────────────────────────────────────────────────────┤
│ framework/          reusable gameplay: map, poi, intel,       │
│                     character, economy, rendering, ui         │
├──────────────────────────────────────────────────────────────┤
│ core/ (autoloads)   EventBus, GameManager, MapManager,        │
│                     IntelRegistry, AssetRegistry, SaveManager │
├──────────────────────────────────────────────────────────────┤
│ Godot 4 Forward+    Vulkan/D3D12, SDFGI, volumetrics, TAA     │
│ gdextension/        optional C++ hot paths                    │
└──────────────────────────────────────────────────────────────┘
```
Rules:
1. `core/` and `framework/` never import from `games/`.
2. Cross-system communication goes through `EventBus` signals (see
   `core/event_bus.gd` — the canonical list of engine events).
3. Art is referenced by **logical key** (`poi.cache`, `env.forest.day`) resolved
   by `AssetRegistry`; never by `res://` path from game data.
4. Everything the player changes is serialisable via `to_save_data()` /
   `from_save_data()` on each system.

## Runtime flow
```
main.tscn → Main._ready()
  MapManager.set_world_root(World)
  GameManager.load_game(id)      ← reads games/<id>/game.json
      AssetRegistry.load_manifest
      IntelRegistry.load_definitions
      MapManager.load_definitions (maps + pois, validates hierarchy)
  GameManager.start_new_game()
      MapManager.enter_root_map(start_map)
          instantiates map scene (or placeholder_map.tscn)
          MapRoot.setup(def, pois, spawn)
              applies Environment preset, spawns portals + POIs, spawns/moves player
```

## Singletons (autoloads)
| Autoload        | Responsibility |
|-----------------|----------------|
| `EventBus`      | Global signals. No logic. |
| `GameClock`     | Game time (scaled), day/phase, scheduling. All durations/expiry use it. |
| `DefinitionRegistry` | Loads every `games/<id>/*.json` type into typed `Definition`s; (type, id) lookup. |
| `GameManager`   | State machine (menu/play/pause/journal), game package loading, flags, faction reputation. |
| `MapManager`    | Map definitions, recursive submap stack + depth limit, portal traversal, per-map persisted state. |
| `IntelRegistry` | Intel definitions + player journal, corroboration, expiry, `IntelQuery` gating, unlock watchers. |
| `AssetRegistry` | Logical key → resource, placeholder fallback, threaded preloading. |
| `SaveManager`   | Versioned JSON saves in `user://saves/`. |

## Extension points for a specific game
- New interaction kinds: `InteractionFactory.register("bribe", MyBribeInteraction)`.
- Map-specific behaviour: subclass `MapRoot`, override `_on_map_setup()`.
- Custom UI: any node in group `dialogue_ui` / `shop_ui` implementing `open(...)`.
- Extra intel semantics: extend `IntelQuery.evaluate` (keep the schema in sync).
- Native performance: `gdextension/` (see its README).

## Non-goals (for now)
Multiplayer, mod loading from outside `res://`, and a visual quest editor. The
data layout is designed so these can be added without restructuring.
