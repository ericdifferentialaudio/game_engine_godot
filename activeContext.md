# Active Context

_Keep this file short. Update in place — do not let it grow into a changelog.
Full history lives in git log; full design lives in docs/ARCHITECTURE.md._

## Last changes
- **Imported both reference engines.** `C:\game_engine` (FPS/3D "IntelForge")
  -> `game_api/fps/`; `C:\game_engine_iso` (isometric "IntelForge Iso") ->
  `game_api/isometric/`. Each layer now holds the original engine's
  `framework/`, `scenes/`, `assets/`, `schemas/`, `tools/`, `docs/`, `games/`,
  with the engine's own autoloads under `autoloads/` and its original
  `project.godot` kept as `project.reference.godot` for diffing.
- **Key correction:** both references were already Godot 4 GDScript, NOT Python
  prototypes as previously assumed. They share a common ancestor
  (`data_loader.gd` was byte-identical), so this was a merge/refactor, not a
  port. The obsolete `core/tools/migrate_*_python/` placeholders were removed.
- **Built the shared platform** in `core/addons/game_core/`, all API-driven:
  - `CoreContext` + `CoreEngineAdapter` — the single seam between the platform
    and a graphics engine. Core code never references iso/fps autoloads.
  - `CoreRegistry` (data types), `CoreIntel` (journals, corroboration, decay,
    provenance, contradiction, debunk, spread, trade).
  - Schema: `CoreDefinition`, `CoreItemDefinition`, `CoreUnitDefinition`,
    `CoreIntelToken`, `CoreFactionDefinition`, `CoreProvenance`.
  - Gameplay: `CoreStats`, `CoreInventory`, `CoreIntelJournal`,
    `CoreIntelQuery`, `CoreDataLoader`.
  - Where the two engines disagreed, the isometric version was the superset
    (turn-decay, provenance, secrecy) and the FPS fields were folded in as
    aliases, so one `items.json`/`intel.json` works in either engine.
- **Adapters written:** `IsoEngineAdapter` (time = turns, hex/iso distance,
  fog reveal) and `FpsEngineAdapter` (time = game seconds, 3D distance,
  reputation-based stance).
- **Docs:** new `docs/API.md` documents every public call. `tools/sync_core.ps1`
  propagates `core/addons/game_core` into both layers (`-Check` to verify).
- **Verified on Godot 4.7.2:** all three projects import clean; test suites
  green — core 37/37, isometric 4/4, fps 4/4.

## Last changes (cont.) — the core is now LIVE in both engines
- `CoreContext.install(...)` is called from both `scenes/main.gd`; each
  `GameManager.load_game()` now also runs `CoreContext.configure(cfg)` +
  `CoreRegistry.load_package(...)`, and `start_new_game()` resets core state.
  The FPS layer re-points the shared `units` type at its `actors.json`.
- **Deleted the 5 obsolete scaffold schema classes.** `ItemDefinition` and
  `UnitDefinition` there collided with the engines' own classes and were
  breaking *both* projects at boot. They were unreferenced and superseded by
  the `Core*` equivalents. `docs/RESOURCE_SCHEMA.md` now redirects to `API.md`.
- Restored real `[application]`/`[input]`/`[layer_names]`/`[rendering]` settings
  into both `project.godot` files from `project.reference.godot` — the scaffold
  configs had `run/main_scene=""`, so neither engine could actually run.
- **Fixed a real data bug the unit tests missed:** the FPS package authors
  single-element lists as bare strings and `equipment` as a `slot -> item` map.
  Added `CoreDataLoader.str_array/packed_str_array` leniency, used by every
  schema class, plus a regression test.
- Added runtime integration checks (iso `--smoke`, fps `--boot-check`) that
  assert the adapter is installed, the core clock tracks the engine clock, and
  the real package actually populated `CoreRegistry`. Both wired into
  `tools/run_tests.ps1`.

## Verified
- core 38/38 · isometric 4/4 · fps 4/4 unit tests
- isometric smoke 32/32 · fps boot check 8/8 (real data: iso 6 items/6 units/
  18 intel/4 factions; fps 13 items/5 units/7 intel/5 factions)
- `tools/run_tests.ps1` runs all five and exits 0.

## In progress
- Nothing mid-flight. `main` is green.

## Next planned
- Retire the duplicate classes now that the core is live and provably loading
  the same data. Suggested order, tests green at each step:
  `DataLoader` -> `Definition` -> `ItemDefinition` -> `Stats`/`CharacterStats`
  -> `Inventory` -> `IntelToken`/`IntelQuery`/`IntelJournal` -> unit/faction
  definitions. Each engine keeps its own subclass only where behaviour differs.
- Port the interaction system up into `core/` as `CoreInteraction` — 7
  near-identical kinds duplicated across both engines (dialogue, intel, portal,
  reward, shop, flag, spawn) plus `InteractionFactory`. Biggest remaining
  duplication.
- Then `Shop`/economy and `StatusEffects` (also duplicated in both).
- Combat genuinely differs (iso `CombatResolver` strength-ratio vs fps
  `DamageCalculator` damage types/resistances) — make it a pluggable
  `CoreCombatResolver` interface rather than one shared implementation.
- Merge the 21 `schemas/*.json` into one shared set; point both engines'
  `tools/validate_data.py` at it.
- Convert one example package to the unified field names as proof, then start
  the first real game project under `games/` (still empty).
- Consider CI: upstream `game_engine` had `.github/workflows/ci.yml` that was
  not carried over.
- Decide keep-vs-drop on the 4 remaining scaffold managers (`VirtueSystem`,
  `WorldStateManager`, `DialogueManager`, `AIHeuristicManager`) — unrelated to
  the imported engines and still unintegrated.
