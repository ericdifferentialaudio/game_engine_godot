# Active Context

_Keep this file short. Update in place — do not let it grow into a changelog.
Full history lives in git log; full design lives in docs/ARCHITECTURE.md and
docs/API.md._

## What this is

A game engine platform with **three APIs**:

- **common** (`core/addons/game_core/`) — all context, data, data structures
  and simulation. Knows nothing about either renderer.
- **isometric** (`game_api/isometric/`) — 2D hex/iso renderer, grid, fog, camera.
- **3D/FPS** (`game_api/fps/`) — first-person renderer, navmesh, raycasts.

The rule: if two different renderers would both need it, it belongs in common.
Engines plug in with `CoreContext.install(<Adapter>.new())`; every
engine-dependent question goes through `CoreEngineAdapter`.

## Current state

Common owns: definitions + archetype inheritance (`CoreRegistry`), items,
units, factions, places, stats, inventory, intel (journals, corroboration,
provenance, decay, contradiction, debunk) and intel exchange (derivation,
spread, trade, give), interactions (8 kinds) and live places.

Both engines boot with the core installed and feed it their real game package.

**Verified** (Godot 4.7.2, `tools/run_tests.ps1`):
core 94/94 · isometric 4/4 · fps 4/4 · iso smoke 37/37 · fps boot check 8/8.

## Known gaps

- Neither example package has a `places.json` yet — still on the old
  `sites.json` / `pois.json`. Places are proven in tests, not yet consumed
  end-to-end by real content.
- Both engines still contain their own `ItemDefinition`, `IntelToken`,
  `IntelQuery`, `Inventory`, `Stats`/`CharacterStats`, `Interaction`, `Shop`,
  `StatusEffects`, `SiteDefinition`/`PoiDefinition`. Inert but redundant.
- `C:\game_engine` and `C:\game_engine_iso` are fully absorbed (content-level
  audit passed; they are plain folders, not git repos) and can be deleted.

## Next planned

1. **`CoreMapDefinition` + portals** — the recursive containment tree that
   makes `contains` / `leads_to` real (overworld -> town -> tavern -> cellar;
   castle -> courtyard -> keep; dungeon -> levels).
2. **Convert one example package** to `places.json` + the unified field names,
   as end-to-end proof of the place vocabulary.
3. **Retire the duplicate classes**, tests green at each step:
   `DataLoader` -> `Definition` -> `ItemDefinition` -> `Stats` -> `Inventory`
   -> `IntelToken`/`IntelQuery`/`IntelJournal` -> `Interaction` -> unit/faction
   defs -> `SiteDefinition`/`PoiDefinition`. Keep an engine subclass only where
   behaviour genuinely differs.
   Wire `game_api/fps/tests/engine/` into the runner **first** — it covers
   exactly the classes this touches.
4. **World model into common**: tiles, terrain, ownership, fog *state*,
   garrison respawn. Engines keep only rendering.
5. `Shop`/economy and `StatusEffects` into common.
6. Combat as a pluggable `CoreCombatResolver` — the two engines genuinely
   differ (Civ-style strength ratio vs. 3D damage types/resistances), so this
   is an interface, not one shared implementation.
7. Merge the 21 `schemas/*.json` into one shared set; point both
   `tools/validate_data.py` at it.
8. Adapt `.github/workflows/ci.yml.reference` to the monorepo and enable it.
9. Decide keep-vs-drop on the 4 unintegrated scaffold managers
   (`VirtueSystem`, `WorldStateManager`, `DialogueManager`,
   `AIHeuristicManager`).
10. Start the first real game under `games/` (still empty).

## Working notes

- After **any** edit under `core/addons/game_core/`, run
  `./tools/sync_core.ps1` (Godot cannot resolve `res://` across project roots).
  `-Check` verifies without copying.
- `tools/run_tests.ps1` runs all five checks and exits non-zero on failure.
- Data parsing is deliberately lenient: authored JSON writes single-element
  lists as bare strings and `equipment` as a slot map. Use
  `CoreDataLoader.str_array()` / `packed_str_array()`, never a raw
  `PackedStringArray(...)` cast on JSON.
