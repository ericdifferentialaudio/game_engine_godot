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

**First real game: `games/slack_tide/`** (isometric layer, 2D text-led with a
UI). **Renamed from `zork` on 2026-09-19** — the 3D rooms, props, fps copies,
playtest and unit tests were deleted; what survives is the *mechanic*, which
is the part that was ever worth keeping. The `zork` package no longer exists.

Slack Tide: a deckhand on a ferry where the tide has stopped turning. 75
information tokens with reliability (0–100), provenance-by-method (overheard
30 … witnessed 90), corroboration (+20, cap 95), perishable hearsay (<50 loses
5/day to a floor of 10) and `conflicts` groups. **Three possible culprits, one
real per seed**, so the same rumour is true on one run and false on the next.
15 locations (11 scene cards with hotspots, 4 tile maps), 25 items, 6
factions, 8 values, a wage/board economy with Slack inflation (+4%/day from
day 6, cap +60%) and an information market where selling raises a token's
*spread* and weakens it as leverage.

`intel.json` is **generated** — edit `docs/slack_tide_spec.json` and run
`tools/convert_slack_tide.py` (the only game-specific tool; it encodes this
game's 0–100 reliability model, so it stays in the package).

**Shared narrative validation (2026-09-19).** `core/tools/validate_narrative.py`
+ `core/tools/narrative/{dialogue_graph,ink_inspect}.py`. Engine-agnostic and
game-agnostic: dangling dialogue knots, checks against non-existent tokens,
actors in places that don't exist, and **Ink stories calling an EXTERNAL that
`CoreInkBindings` never binds** — the last of which compiles with exit 0 and
crashes only when a player reaches that line, so nothing else catches it.
File layout is *discovered*, not configured (`places|maps|sites.json`,
`actors|units.json`), so it runs on all six games with no per-game setup:
aevum 65 tokens/140 actors, chorus, hollow_ledger, paragon 10/6, slack_tide
75/6, wardens — **all 0 errors**. `run_tests.ps1` now runs it over every
directory under `games/`. Verified by fault injection (broken knot, typo'd
token, unbound EXTERNAL → all caught, exit 1).

**Validator reconciliation (2026-09-19).** `game_api/{iso,fps}/tools/validate_data.py`
each carried their own copy of the `CoreIntelQuery` grammar and had **drifted
in opposite directions**: iso invented `era`/`turn`/`faction_flag` (core never
evaluates them, so such a query silently returns false) and omitted core's
`holder_flag`/`time`; fps knew only 8 of core's 19 keys and wrongly rejected
valid data. A package accepted by one engine could be rejected by the other.
Both now import `core/tools/narrative/intel_query.py`, whose
`check_keys_match_core()` reads `CoreIntelQuery.KEYS` from the GDScript and
errors on drift — verified by injecting a bogus key. The bulk of each
validator stays engine-local, because grid topology and portals/spawns really
are different things; only the shared grammar moved.

**Three engine bugs found and fixed** (`docs/CORE_REQUESTS.md`, a new file
for needs a game/engine has of core — filed, not patched in place):

- **CR-001 (resolved).** The iso engine had a *second live* query evaluator at
  `framework/intel/intel_query.gd` with a different grammar; 19 authored
  queries used `faction_flag`, which core never evaluated. `CoreIntelQuery`
  gained `era` (via a new `CoreEngineAdapter.era()`) and an `ALIASES` map
  (`faction_flag`→`holder_flag`, `turn`→`time`); the engine-local evaluator now
  does `const KEYS := CoreIntelQuery.KEYS` so the two cannot drift again. No
  authored data changed. 9 new tests in `test_core_intel_query_aliases.gd`.
- **CR-002 (resolved).** `TurnManager.start()` with an empty turn order looped
  forever — `_activate_faction(0)` ended the turn, which began the next, which
  activated faction 0 again. Unreachable until a package had no factions;
  presented as a silent headless hang.
- **CR-003 (resolved).** `CoreInkValidator` recognised only `=== knots ===`,
  not stitches (`= name`) or gather labels (`- (name)`) — so a normally-written
  conversation hub reported every internal divert as broken. `corvin.ink` went
  from 12 false errors to 0.

**Narrative packages on the iso engine.** A package declaring
`"presentation": "2d_ui_*"` has no terrains, units or generated hex world.
`GameManager.is_narrative_package()` now skips world generation (it was failing
on every tile with `unknown terrain ''`), `validate_data.py` skips the
strategy-schema checks, and `--smoke` runs a narrative boot check instead of
`SmokeTest`. Result: `NARRATIVE BOOT (slack_tide): 4/4 passed, 75 tokens`.

`slack_tide_boot.gd` was rewritten against the **real** iso API — it had been
written against fps assumptions and called `Shop.give_currency`,
`EventBus.day_advanced`, `CoreIntel.journal_of` and others that do not exist
there. It now drives off `EventBus.turn_started` (one turn = one slot, six
slots = a day) and uses `CoreAssets.give/spend` and `CoreIntel.journal_for`.

Dialogue is moving to **Ink**, because `knows()` *is* the reliability model
(`CoreKnowledge` is a façade over `CoreIntel`: 0.3 reads false, corroborated
reads true), so a writer types `{ knows("c1b") }` instead of hand-maintaining
`min_reliability` on every branch. `ink/corvin.ink` is the proven port — all
10 externals bound, all 6 tokens exist. `inklecate.exe` is vendored and
`run.ps1` recompiles stale `.ink` automatically. The topic matrix stays JSON:
Ink is bad at enumeration, and `topics.json` must be machine-checkable for
solvability. See `games/slack_tide/docs/INFORMATION_ARCHITECTURE.md`.

Engine finding: the presentation doc assumed a shared GUI layout API still had
to be built. It **already exists** (`core/addons/game_core/ui/`) — the five
windows map onto `CoreLayoutDefinition.WINDOW_TYPES` with zero core changes,
and `CoreMapWindow` already has clickable markers, which is the hotspot
mechanism. See `games/slack_tide/docs/SLACK_TIDE_PRESENTATION.md` §10.1.

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

**Verified:** core 211/211 · isometric 26/26 · fps 36/36 · core ink OK ·
zork ink OK · iso smoke 40/40 · fps boot 8/8 · zork boot 8/8 ·
zork playtest 48/48 (all **nine** checks green via `tools/run_tests.ps1`,
2026-09-19).

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

**All five closed 2026-09-19** — see "Core save bundle in both engines" and
"Narrative gate, minimap, art seam" below:

1. ~~Neither engine's `SaveManager` calls `CoreSaveBundle`.~~
2. ~~No engine subclasses `CoreMapWindow`.~~ Now `IsoMapWindow`; the fps layer
   still has no map window, which is correct — a first-person game's map is a
   game-level design decision, not an engine default.
3. ~~`resolve_texture(id)` unimplemented on both adapters.~~
4. ~~`DialogueManager` superseded but not removed.~~
5. ~~Validators not wired into `tools/run_tests.ps1` as a gate.~~

## Next planned

Working list, in order. Tick items off here as they land; move the detail into
the section above and delete the entry.

- [x] **1. Seeded FPS combat RNG** (was Future work #11) — landed 2026-09-15,
      see "Seeded FPS combat RNG" below.
- [x] **2. `CoreSaveBundle` wired into both `SaveManager`s** — landed
      2026-09-19, see "Core save bundle in both engines" below.
- [x] **3. Ink validators gated in `tools/run_tests.ps1`** — 2026-09-19.
- [x] **4. `DialogueManager` removed** — 2026-09-19.
- [x] **5. Real iso minimap (`IsoMapWindow`)** — 2026-09-19.
- [x] **6. `resolve_texture(id)` on both adapters** — 2026-09-19.
- [x] **7. Flaky core Ink test fixed** — 2026-09-19 (a real UI bug, not a bad
      test; see below).

All seven items are done; see "Narrative gate, minimap, art seam" below. Next
up is the numbered **Future work** backlog below.

## Narrative gate, minimap, art seam (landed 2026-09-19)

Closes Outstanding #2–#5 and the flaky Ink test.

**Ink validators are now a merge gate.** `tools/run_tests.ps1` gained an
`$inkChecks` stage running `tools/validate_ink.gd` headless for `core` and for
`fps`'s zork story; it already exited non-zero on ERROR findings. Passing
`--package=res://games/zork` (a base path, not a bare game id) matters: with the
package loaded the simulation resolves real items/tokens and finds **4**
reachable choices instead of 3 — without it, the knowledge-gated branch was
silently never exercised.

**`DialogueManager` is gone** — a 25-line unimplemented placeholder superseded
by `CoreInkEngine`. Removed the script, the entry in `game_core_plugin.gd`'s
`AUTOLOADS`, the line in all three `project.godot` files, and the row in
`docs/ARCHITECTURE.md`. Nothing referenced it. Three scaffolds remain for
Future work #9.

**`IsoMapWindow`** (`game_api/isometric/framework/ui/iso_map_window.gd`) is a
real minimap: terrain painted from `TileDefinition.color` (already documented as
the "blockout / minimap colour", so no new data), fog-aware (unexplored skipped,
explored dimmed 45%), faction-coloured unit pips, roads lightened. It draws on a
layer *behind* the base class's marker canvas, so every inherited marker/focus/
registry behaviour is untouched and game code never learns which window is
installed. Redraws are rate-limited to 10 Hz and driven by EventBus
(`visibility_changed`/`unit_moved`/`unit_died`/`tile_owner_changed`/
`turn_started`/`world_loaded`) rather than by callers remembering to refresh.
`coord_at()`/`normalised_of()` convert between tile and window space.
**Enemy units are drawn only where the viewer has vision** — a minimap that
leaked positions would quietly undo fog of war.

**`resolve_texture(id)`** now exists on both adapters, resolving logical art
keys through each engine's `AssetRegistry`. The two deliberately differ: iso
returns `AssetRegistry.load_texture()`, whose generated colour swatch means an
art window shows something identifiable before the art pass; fps returns null
for unknown keys, so `set_image()` reports false and the frame stays blank
(a wrong portrait is worse than none). Also added the missing
`CoreWindowRegistry.get_map_window()` / `get_graphics_window()` typed lookups —
the registry had them for text/unit/icon_text only, a real gap once engines
started subclassing.

**The flaky Ink test was a real UI bug**, not a bad test. `CoreTextWindow._scroll_to_bottom()`
did `await get_tree().process_frame` then guarded `is_instance_valid(_scroll)` —
but an await suspends *the window itself*, so when a test tore its layout down
before the frame landed, Godot logged "Resumed function after await, but class
instance is gone" and GUT attributed the stray engine errors to whichever test
was running. The guard could never help: it never ran. Now a `call_deferred`,
which is simply dropped when its target is gone. Reproduced at ~1 in 8 runs
before; **0 failures and 0 "instance is gone" errors in 8 consecutive full core
runs** after. Any `await` in a UI teardown path is suspect for the same reason.

Tests: `game_api/isometric/tests/unit/test_iso_map_window.gd` (11) — registry
lookup by role, all inherited marker behaviour still intact, coordinate
round-trip, safety with no world loaded, rate-limited refresh, and the
`resolve_texture` seam end-to-end through a real `CoreGraphicsWindow`.
iso **26/26**. `run_tests.ps1` now runs **nine** checks, not five.

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
9. Decide keep-vs-drop on the 3 remaining unintegrated scaffold managers
   (`VirtueSystem`, `WorldStateManager`, `AIHeuristicManager`).
   `DialogueManager` was the fourth and was dropped 2026-09-19;
   `AIHeuristicManager` is now genuinely used by `CoreGoalSelector`.
10. Start the first real game under `games/`: **Paragon** (`games/paragon/`, isometric) â€” design docs
    landed 2026-09-07 (29 `.md` from the former `C:\UIV`); read `games/paragon/activeContext.md` first.
11. ~~Route FPS combat RNG through `CoreContext.rng()`~~ - **done 2026-09-15**,
    see "Seeded FPS combat RNG" above. The iso layer and all of `core/` already
    used the shared generator; the FPS layer now does too.

## Game package delivery fixed (2026-09-19)

`games/<id>/` is now unambiguously the single source of truth, and the engine
copies are generated artifacts.

The bug: `run_tests.ps1` only ever checked **`slack_tide`** for staleness, so
`aevum` and `paragon` had silently drifted — the engine was running older data
than the source, with nothing reporting it — and `chorus`, `hollow_ledger` and
`wardens` had no engine copy at all, meaning half the catalogue could not be
launched through the API. Both copies were also *tracked*, so the same
`units.json` existed twice in git and could legitimately disagree.

- **Routing is data-driven**: each `game.json` declares `"engine"`
  (`isometric` | `fps`, default `isometric`). No mapping lives in the tooling.
- **`sync_game.ps1 -All`** syncs every package to its declared engine;
  `-Game <id>` still does one, and `-Engine` still overrides.
- **`run_tests.ps1` runs `-All -Check`** — drift now fails the suite instead of
  waiting to be noticed.
- **`game_api/*/games/*` is gitignored** (except the `example_realm*` fixtures,
  which have no `games/` source), and the 3 tracked copies were untracked.

All 6 packages now sync clean and run: core 220/220, iso 26/26, fps 17/17,
iso smoke 40/40, aevum smoke 40/40 on *fresh* data, slack_tide 75 tokens,
fps boot 8/8, both `validate_data.py --all` green (wardens is validated for
the first time). Verified by fault injection: touching `games/aevum/` makes
`-All -Check` exit 1.

## Working notes

- After **any** edit under `core/addons/game_core/`, run
  `./tools/sync_core.ps1` (Godot cannot resolve `res://` across project roots).
  `-Check` verifies without copying.
- `tools/run_tests.ps1` runs all **nine** checks (3 GUT suites · 2 Ink
  validators · 4 runtime integrations) and exits non-zero on failure.
- Never `await get_tree().process_frame` in UI code that can be freed while
  suspended — the coroutine belongs to the node, so no `is_instance_valid()`
  guard after the await can save you; it never runs. Use `call_deferred`, which
  is dropped silently. This caused a 1-in-8 flake (see below).
- A `class_name` that a project has never referenced may be **missing from its
  stale `.godot/global_script_class_cache.cfg`**, giving a confusing
  `Identifier "X" not declared in the current scope` at parse time even though
  the file is right there (hit with `CoreSaveBundle`). Fix:
  `godot --headless --import --path <project>`, or `run_tests.ps1 -Import`.
- Data parsing is deliberately lenient: authored JSON writes single-element
  lists as bare strings and `equipment` as a slot map. Use
  `CoreDataLoader.str_array()` / `packed_str_array()`, never a raw
  `PackedStringArray(...)` cast on JSON.
