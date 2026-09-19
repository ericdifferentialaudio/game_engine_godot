# Active Context

_Keep this file short. Update in place â€” do not let it grow into a changelog.
Full history lives in git log; full design lives in docs/ARCHITECTURE.md and
docs/API.md._

## What this is

A game engine platform with **three APIs**:

- **common** (`core/addons/game_core/`) â€” all context, data, data structures
  and simulation. Knows nothing about either renderer.
- **isometric** (`game_api/isometric/`) â€” 2D hex/iso renderer, grid, fog, camera.
- **3D/FPS** (`game_api/fps/`) â€” first-person renderer, navmesh, raycasts.

The rule: if two different renderers would both need it, it belongs in common.
Engines plug in with `CoreContext.install(<Adapter>.new())`; every
engine-dependent question goes through `CoreEngineAdapter`.

## Current state

Common owns: definitions + archetype inheritance (`CoreRegistry`), items,
units, factions, places, stats, inventory, intel (journals, corroboration,
provenance, decay, contradiction, debunk) and intel exchange (derivation,
spread, trade, give), interactions (8 kinds) and live places.

Both engines boot with the core installed and feed it their real game package.

**First real game: `games/zork/`** (fps layer). 15 rooms as separate 3D maps,
troll + thief with branching dialogue whose answers are `check`ed against the
intel journal (true tokens vs. false rumours linked by `conflicts`; `debunk`
marks lies). Engine gained: melee execution, actor spawning/death/loot,
`examine`/`pickup`/`container` interactions, talkable actors (`ActorTalk`),
`DialogueUi`, narration-log HUD with score/moves, dark rooms + light sources,
`boot_script` hook, `tools/sync_game.ps1`. fps now 23/23 Â· zork boot check 8/8
Â· zork playtest 48/48 (troll, thief, cyclops) (`tools/zork_playtest.gd`).

**Verified** (Godot 4.7.2, `tools/run_tests.ps1`):
core 130/130 (94 + 24 goal-selector + 12 road-builder) Â· isometric 10/10
(4 + 6 line-of-sight) Â· fps 4/4 Â· iso smoke 37/37 Â· fps boot check 8/8.

**Aevum port (in progress).** Porting good algorithms/practice from the
standalone Python project `C:\Aevum\engine` (a separate, unrelated hex-grid
strategy game) into `game_core`/the isometric engine, translated to
GDScript â€” not a wholesale code dump, cherry-picked by value. Landed so far:

1. `CoreGoalSelector` (`core/addons/game_core/managers/core_goal_selector.gd`),
   ported from `engine/engine_goals.py` â€” roulette-wheel weighted goal
   selection (normalize/select_weighted/apply_repeat_penalty/
   roll_commitment/proximity_bonus/apply_cooldown), draws from the shared
   `CoreContext.rng()` for determinism. Wired into `AIHeuristicManager`
   (was an explicit TODO placeholder stub) with per-agent cooldown/
   commitment Dictionaries. 24 GUT tests.
2. `CoreRoadBuilder` (`core/addons/game_core/managers/core_road_builder.gd`),
   ported from `engine/engine_map_pipeline.py`'s Dijkstra/A* organic-road
   pipeline (Sprint 23 "#166") â€” terrain-cost-aware `find_path()` plus
   `build_road_network()`'s 3-pass model (direct spokes -> greedy MST ->
   short stubs for isolated minor sites). Kept in `core/` (not the iso
   engine) since it depends only on injected Callables
   (neighbors/cost/distance), no GridTopology/WorldMap coupling, so any
   future grid-based world model can reuse it. Wired into the isometric
   engine's `MapGenerator.build_roads()`. 12 GUT tests.
3. Isometric combat, ported from `engine/combat_engine.py`:
   `GridTopology.line()`/`has_line_of_sight()` (generalised from Aevum's
   hex-only cube-coordinate line + hardcoded "only Mountain blocks" to any
   topology via world-space lerp, and any terrain/feature flagged
   `blocks_sight`), gating `CombatResolver.resolve()` behind LoS
   (`rules.combat.require_line_of_sight`); and a data-driven monster-
   weakness/damage-type bonus (`_apply_monster_weakness`, generalised from
   Aevum's hardcoded clan/lair model to `EntityDefinition.metadata`
   `weak_to`/`resists`/`damage_type`, gated on an intel token like any
   other fact). 6 GUT tests (`game_api/isometric/tests/unit/test_line_of_sight.gd`).

## Known gaps

- Neither example package has a `places.json` yet â€” still on the old
  `sites.json` / `pois.json`. Places are proven in tests, not yet consumed
  end-to-end by real content.
- Both engines still contain their own `ItemDefinition`, `IntelToken`,
  `IntelQuery`, `Inventory`, `Stats`/`CharacterStats`, `Interaction`, `Shop`,
  `StatusEffects`, `SiteDefinition`/`PoiDefinition`. Inert but redundant.
- `C:\game_engine` and `C:\game_engine_iso` are fully absorbed (content-level
  audit passed; they are plain folders, not git repos) and can be deleted.

## Narrative / asset / screen framework (landed)

Shared infrastructure for text-and-conversation games. See **docs/NARRATIVE.md**.

- **Ink** via vendored `inkgd` (`core/addons/inkgd/`, `godot4` branch pinned at
  `fea9098`, `mono/` excluded; see its `VENDOR.md`). Confirmed the right choice
  over GodotInk: that one needs .NET in all three project roots. `CoreInkEngine`
  is the **only** file referencing inkgd, so the runtime is swappable.
  `inklecate` 1.2.1 vendored at `tools/inklecate/` — not a build dependency,
  compiled `.ink.json` is committed.
- **Two asset systems, both façades over what already existed** (not new
  stores): `CoreKnowledge` (boolean, over `CoreIntel` — `knows()` is
  belief-thresholded, so a 0.3-reliability rumour is *heard* but not *known*)
  and `CoreAssets` (counted, over `CoreInventory`; currency vs. item resolved
  by `CoreItemDefinition.category`).
- **`CoreStanding`** — per-NPC relationship as a third lightweight value, with
  named tiers/decay left to each game (`rules.standing`). Optional place
  qualifier (`fence@round_room`) subsumes the aevum pub-relationship model.
- **`CoreContextBuilder`** — hybrid: slow scalars pushed as Ink variables,
  volatile state as external functions, so a mid-conversation gain is visible
  to the next condition. `watch()` keeps the snapshot live.
- **Pattern library** `core/ink/patterns/patterns.ink` — barter · interrogate ·
  persuade · confide, as tunnels returning an outcome code.
- **Validators** — static pass + context simulation, as GUT tests and as a CLI
  (`core/tools/validate_ink.gd`, exits non-zero on errors).
- **Windows in core** (`core/addons/game_core/ui/`) — `CoreWindow` contract,
  text/graphics/map/units/icon_text types, `CoreWindowRegistry` (role lookup,
  null when absent), and a data-driven nested-`SplitContainer` layout with
  aspect-keyed variants. Split ratios -> `user://ui_layout.cfg` (user prefs,
  not save data). Sample: `games/zork/layout.json`.
- **`CoreSaveBundle`** — one nested dict of all core state, including Ink's own
  JSON, so engine SaveManagers need no edit when a core system is added.
- **Demo:** `games/zork/ink/round_room_fence.ink` — a Round Room fence gated on
  currency AND knowledge AND standing, granting an item AND a token, rendered
  through registered windows by registry lookup only. **Purely additive**: it
  reuses existing zork ids (`zorkmid`, `brass_lantern`, `know_trapdoor`,
  `rumor_rug_worthless`, `know_grue`), so the 48/48 playtest is untouched.
- `sync_core.ps1` now syncs `addons/game_core`, `addons/inkgd` and
  `ink/patterns`.

**Verified:** core 211/211 · isometric 15/15 · fps 36/36 ·
iso smoke 40/40 · fps boot 8/8 · zork boot 8/8 · zork playtest 48/48
(all five checks green via `tools/run_tests.ps1`, re-confirmed 2026-09-19).

**Flaky-test fix (2026-09-15).** The zork playtest failed ~30% of runs on
"wounded thief flag set". Not a regression in the feature: the check landed a
single scripted blow on the thief, who has `dodge: 0.25`, and `Damageable.rng`
is an unseeded `RandomNumberGenerator`, so a quarter of runs dodged it and the
0.35 flee threshold was never crossed. The check tests the wound *reaction*, so
it now hits repeatedly until he is below threshold (the retry shape the troll
fight already used). 10/10 consecutive clean runs after the fix.
The underlying cause (ad-hoc unseeded generators in FPS combat) is now fixed —
see "Seeded FPS combat RNG" below.

### Outstanding on this feature

1. ~~Neither engine's `SaveManager` calls `CoreSaveBundle` yet~~ — **done
   2026-09-19**, see "Core save bundle in both engines" above.
2. No engine subclasses `CoreMapWindow` yet; the base draws simple markers.
   The iso engine should override `_draw_markers()` with a real minimap.
3. `CoreGraphicsWindow.set_image()` resolves via an optional adapter method
   `resolve_texture(id)` that neither adapter implements yet, so art windows
   stay blank until an engine provides it.
4. The old `DialogueManager` autoload scaffold is now superseded by
   `CoreInkEngine` but not yet removed (it is one of the 4 unintegrated
   scaffolds in Future work #9).
5. Validators are not yet wired into `tools/run_tests.ps1` as a gate; they run
   as GUT tests, and the CLI is available for writers.

## Next planned

Working list, in order. Tick items off here as they land; move the detail into
the section above and delete the entry.

- [x] **1. Seeded FPS combat RNG** (was Future work #11) — landed 2026-09-15,
      see "Seeded FPS combat RNG" below.
- [x] **2. `CoreSaveBundle` wired into both `SaveManager`s** — landed
      2026-09-19, see "Core save bundle in both engines" below.
- [ ] **3. Gate the Ink validators in `tools/run_tests.ps1`.** Add a runtime
      check row calling `core/tools/validate_ink.gd` headless (it already exits
      non-zero on errors), so a broken `.ink` fails the merge gate rather than
      only a GUT run. (Outstanding #5.)
- [ ] **4. Drop the superseded `DialogueManager` autoload.** `CoreInkEngine`
      replaces it; remove the script, the autoload line in all three
      `project.godot` files, and re-run `sync_core.ps1`. Fold the verdict into
      Future work #9 for the other three scaffolds. (Outstanding #4.)
- [ ] **5. Real minimap: subclass `CoreMapWindow` in the iso engine** and
      override `_draw_markers()`. (Outstanding #2.)
- [ ] **6. Implement `resolve_texture(id)` on both adapters** so
      `CoreGraphicsWindow.set_image()` stops rendering blank. (Outstanding #3.)
- [ ] **7. Fix the flaky core Ink test.**
      `test_core_ink_integration.gd:test_layout_without_a_status_window_degrades_quietly`
      fails intermittently (3 "Method/function failed. Returning: Variant()"
      engine errors around line 201) — it also failed on clean `HEAD`, so it is
      not a regression from item 1, but it makes `core` a 210/211 coin-flip.

Then the numbered **Future work** backlog below, unchanged.

## Core save bundle in both engines (landed 2026-09-19)

Closes Outstanding #1. Both `SaveManager`s now write core state as a single
`"core"` key (`CoreSaveBundle.collect()`) and restore it with
`CoreSaveBundle.apply()`, so **adding a core system no longer touches either
engine's SaveManager** — only `CoreSaveBundle.SYSTEMS` and the next
`sync_core.ps1`. Save versions bumped: **fps 2 -> 3**, **isometric 1 -> 2**,
each with a migration that synthesises a `"core"` section from the old
engine-side `flags` when one is absent. Systems that had no pre-bundle
equivalent (assets, standing, ink) stay absent, and `apply()` skips them rather
than wiping live state — so an old save loads without silently zeroing anything.

Two ordering decisions worth keeping: `apply()` runs **after** the engine-layer
restores, so `CoreContext.flags` wins over any engine-side mirror of the same
state; and the bundle carries the RNG seed *and* `state`, so a reloaded game
continues the random stream rather than restarting it (asserted in the iso test).

Tests: `game_api/fps/tests/unit/test_save_bundle_wiring.gd` (6) — section
present, round-trip through a real `user://` save file, **save mid-Ink-
conversation and resume at the same knot**, v2 migration, migration leaving
unknown systems alone, and no re-migration of a current save;
`game_api/isometric/tests/unit/test_save_bundle_wiring.gd` (5) — the same,
minus Ink (this project has no compiled `.ink.json`; only `core/` does), plus
the RNG-continuity check. `tools/smoke_test.gd` gained 3 checks asserting core
standing/flags survive the real save→load path. fps **36/36**, iso **15/15**,
iso smoke **40/40**.

## Seeded FPS combat RNG (landed 2026-09-15)

Closes the old Future work #11 and the root cause behind the wounded-thief
flake. `Damageable.rng` and `AbilityCaster._rng` were each an unseeded
`RandomNumberGenerator.new()`; both are now **computed properties returning
`CoreContext.rng()`**, so every dodge, crit, damage-range and effect-chance roll
comes off the one shared seeded generator. Keeping the property names means no
call site changed (`DamageCalculator.resolve(..., rng)`,
`DamageInfo.from_ranges(ranges, _rng, actor)`, `roll_crit(..., _rng)`).
`AIBrain`'s two bare `randf_range()` calls (wander wait, wander point) were
routed through the same generator — they were the last unseeded draws in the
FPS framework. `games/zork/game.json` gained `"seed": 1980` so the playtest is
actually reproducible rather than merely reproducible-in-principle.

New `game_api/fps/tests/unit/test_seeded_combat_rng.gd` (7 tests): identity of
the shared generator, one generator shared across actors, same seed replays,
different seeds diverge, a 20-roll dodge *outcome* sequence replays exactly, and
a source-scanning guard that fails if `RandomNumberGenerator.new()`,
`randomize()`, `randf()`, `randf_range()` or `randi()` reappears in the three
combat files. fps is now **30/30**.

## Future work

1. **`CoreMapDefinition` + portals** â€” the recursive containment tree that
   makes `contains` / `leads_to` real (overworld -> town -> tavern -> cellar;
   castle -> courtyard -> keep; dungeon -> levels).
2. **Convert one example package** to `places.json` + the unified field names,
   as end-to-end proof of the place vocabulary.
3. **Retire the duplicate classes**, tests green at each step:
   `DataLoader` -> `Definition` -> `ItemDefinition` -> `Stats` -> `Inventory`
   -> `IntelToken`/`IntelQuery`/`IntelJournal` -> `Interaction` -> unit/faction
   defs -> `SiteDefinition`/`PoiDefinition`. Keep an engine subclass only where
   behaviour genuinely differs.
   Wire `game_api/fps/tests/engine/` into the runner **first** â€” it covers
   exactly the classes this touches.
4. **World model into common**: tiles, terrain, ownership, fog *state*,
   garrison respawn. Engines keep only rendering.
5. `Shop`/economy and `StatusEffects` into common.
6. Combat as a pluggable `CoreCombatResolver` â€” the two engines genuinely
   differ (Civ-style strength ratio vs. 3D damage types/resistances), so this
   is an interface, not one shared implementation.
7. Merge the 21 `schemas/*.json` into one shared set; point both
   `tools/validate_data.py` at it.
8. Adapt `.github/workflows/ci.yml.reference` to the monorepo and enable it.
9. Decide keep-vs-drop on the 4 unintegrated scaffold managers
   (`VirtueSystem`, `WorldStateManager`, `DialogueManager`,
   `AIHeuristicManager`).
10. Start the first real game under `games/`: **Paragon** (`games/paragon/`, isometric) â€” design docs
    landed 2026-09-07 (29 `.md` from the former `C:\UIV`); read `games/paragon/activeContext.md` first.
11. ~~Route FPS combat RNG through `CoreContext.rng()`~~ - **done 2026-09-15**,
    see "Seeded FPS combat RNG" above. The iso layer and all of `core/` already
    used the shared generator; the FPS layer now does too.

## Working notes

- After **any** edit under `core/addons/game_core/`, run
  `./tools/sync_core.ps1` (Godot cannot resolve `res://` across project roots).
  `-Check` verifies without copying.
- `tools/run_tests.ps1` runs all five checks and exits non-zero on failure.
- A `class_name` that a project has never referenced may be **missing from its
  stale `.godot/global_script_class_cache.cfg`**, giving a confusing
  `Identifier "X" not declared in the current scope` at parse time even though
  the file is right there (hit with `CoreSaveBundle`). Fix:
  `godot --headless --import --path <project>`, or `run_tests.ps1 -Import`.
- Data parsing is deliberately lenient: authored JSON writes single-element
  lists as bare strings and `equipment` as a slot map. Use
  `CoreDataLoader.str_array()` / `packed_str_array()`, never a raw
  `PackedStringArray(...)` cast on JSON.
