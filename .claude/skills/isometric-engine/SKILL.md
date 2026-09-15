---
name: isometric-engine
description: Working on the 2D hex/isometric engine API layer (game_api/isometric/) or a game built on it such as games/paragon or games/aevum — grid topology, turns, world map generation, roads, fog of war, line of sight, sites/POIs, factions and diplomacy. Use when the task mentions isometric, iso, hex, tiles, turn-based, IsoEngineAdapter, MapGenerator, or the Aevum port.
---

# Isometric engine API layer (`game_api/isometric/`)

A standalone Godot 4 project (Mobile renderer, 2D) that renders and drives
turn-based grid games via the shared `game_core` platform. Imported from the
upstream "IntelForge Iso Engine" — historically the richer of the two, so the
core adopted its implementations where the engines diverged.

## Layout

```
game_api/isometric/
  addons/game_core/        SYNCED COPY of core/addons/game_core — never edit here
  autoloads/               game_manager, game_clock, turn_manager, world_manager,
                           entity_registry, faction_registry, item_registry,
                           intel_registry, data_loader, asset_registry,
                           event_bus, save_manager
  framework/               grid/ world/ entities/ intel/ sites/ combat/ economy/ ui/
  scripts/iso_engine_adapter.gd   the engine seam implementation
  games/<id>/              SYNCED COPY of games/<id> — never edit here
  tests/unit/              GUT tests
  bootstrap.json · project.godot · .gutconfig.json · ENGINE_README.md
```

## The seam — `IsoEngineAdapter`

Boot installs it: `CoreContext.install(IsoEngineAdapter.new())`. Contract:

| Method | Isometric implementation |
|---|---|
| `now()` | `GameClock.turn` — **turns** |
| `distance(a, b)` | hex/iso tile distance, `Vector2i` |
| `can_see(obs, target)` | sight stat vs. tile distance |
| `position_of(id)` | `Vector2i` tile coord |
| `are_hostile(a, b)` | faction diplomacy |
| `unit_count(holder, def)` | `EntityRegistry.count_units` |
| `holder_flag` / `holder_resource` | per-faction flag / faction stockpile |
| `stance(holder, other)` | diplomacy stance |
| `owns_site(holder, site)` | controls the site's tile |
| `notify(text, category)` | HUD toast |
| `reveal()` | clears fog of war |

**Time is turns here.** A token's `decay_turns: 10` means ten turns.

## Subsystems worth knowing

- **`GridTopology`** — `line()` and `has_line_of_sight()` are topology-agnostic
  (world-space lerp, not hex-only cube coords); anything flagged `blocks_sight`
  on a terrain or feature blocks. `CombatResolver.resolve()` is gated behind LoS
  when `rules.combat.require_line_of_sight` is set.
- **`MapGenerator.build_roads()`** — delegates to the core's `CoreRoadBuilder`
  (terrain-cost Dijkstra/A* `find_path()` plus a 3-pass network: direct spokes →
  greedy MST → short stubs for isolated minor sites). `CoreRoadBuilder` lives in
  `core/` because it only takes injected Callables (neighbors/cost/distance).
- **Monster weakness** — data-driven via `EntityDefinition.metadata`
  (`weak_to` / `resists` / `damage_type`), gated on an intel token like any other
  fact. Never hardcode a clan/lair table.
- **Goal selection** — `CoreGoalSelector` (roulette-wheel weighted selection,
  repeat penalty, commitment roll, proximity bonus, cooldown) is wired into
  `AIHeuristicManager` with per-agent cooldown/commitment dictionaries. It draws
  from `CoreContext.rng()` so runs are deterministic.

## Running it

```powershell
godot --path game_api/isometric                            # editor/play
godot --headless --path game_api/isometric -- --smoke       # full engine smoke suite (37)
./tools/sync_game.ps1 -Game paragon -Engine isometric
```

## Games on this layer

- `games/paragon/` — the first real iso game; 29 design docs landed from the
  former `C:\UIV`. **Read `games/paragon/activeContext.md` first.**
- `games/aevum/` — related to the ongoing port of good algorithms from the
  standalone Python project `C:\Aevum\engine` (a separate hex-grid strategy
  game). The port is **cherry-picked by value and translated to GDScript**, never
  a wholesale code dump.

## Rules

1. `addons/game_core/` and `games/<id>/` here are **copies**. Edit the originals,
   then `./tools/sync_core.ps1` / `./tools/sync_game.ps1 -Game <id> -Engine isometric`.
2. Anything the FPS engine would also need belongs in `core/`. Pure algorithms
   with injected dependencies belong in `core/` too (see `CoreRoadBuilder`).
3. Legacy duplicates still present here (`ItemDefinition`, `IntelToken`,
   `IntelQuery`, `Inventory`, `Stats`, `Interaction`, `Shop`, `StatusEffects`,
   `SiteDefinition`, `PoiDefinition`) are being retired — prefer `Core*`.
4. Known gap: no package uses `places.json` yet (still `sites.json` / `pois.json`).
   Converting one is an explicit next step.
5. Finish with `./tools/run_tests.ps1`. Baseline: isometric 10/10 (4 + 6
   line-of-sight), iso smoke 37/37.
