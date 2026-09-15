---
name: fps-engine
description: Working on the 3D first-person engine API layer (game_api/fps/) or a game built on it such as games/zork — actors, melee/hitscan combat, rooms/maps, POIs, interactions, dialogue, narration HUD, light sources. Use when the task mentions fps, first-person, 3D, zork, FpsEngineAdapter, actors, or boot-check/playtest.
---

# FPS engine API layer (`game_api/fps/`)

A standalone Godot 4 project (Forward+, 3D) that renders and drives games via
the shared `game_core` platform. Imported from the upstream "IntelForge Engine".

## Layout

```
game_api/fps/
  addons/game_core/        SYNCED COPY of core/addons/game_core — never edit here
  autoloads/               game_manager, game_clock, event_bus, map_manager,
                           data_loader, definition_registry, intel_registry,
                           asset_registry, save_manager
  framework/               actor/ combat/ data/ economy/ intel/ items/ map/
                           poi/ rendering/ ui/
  scripts/fps_engine_adapter.gd   the engine seam implementation
  games/<id>/              SYNCED COPY of games/<id> — never edit here
  tests/                   GUT tests (unit/ and engine/)
  bootstrap.json · project.godot · .gutconfig.json · ENGINE_README.md
```

## The seam — `FpsEngineAdapter`

Boot installs it: `CoreContext.install(FpsEngineAdapter.new())`. It is the
**only** place the platform learns anything 3D. Its contract (see `docs/API.md`):

| Method | FPS implementation |
|---|---|
| `now()` | `GameClock.now()` — **game seconds** |
| `distance(a, b)` | metres, `Vector3` |
| `can_see(obs, target)` | `Perception` component raycast |
| `position_of(id)` | `Vector3` world position |
| `are_hostile(a, b)` | faction data + player reputation |
| `unit_count(holder, def)` | actors in the `actors` group |
| `holder_flag` / `holder_resource` | global flag / player inventory currency |
| `stance(holder, other)` | reputation mapped to a stance string |
| `owns_site(holder, site)` | POI cleared flag |
| `notify(text, category)` | HUD toast / narration log |
| `reveal()` | flags maps/POIs discovered |

Need a new engine-dependent fact in core? Add a method here and a default on
`CoreEngineAdapter` — do **not** import an FPS class into `core/`.

**Time is seconds here.** A token's `decay_turns: 10` means ten seconds of game
time. Author FPS data accordingly.

## Running it

```powershell
godot --path game_api/fps                                 # editor/play
godot --headless --path game_api/fps -- --boot-check       # platform wiring (8 checks)
godot --headless --path game_api/fps -- --game=zork --boot-check
godot --headless --path game_api/fps -- --game=zork --playtest   # 48 scripted assertions
```

`--game=<id>` selects the package under `games/`. `boot_script` in the game's
config is the per-game hook run at startup.

## Games on this layer

`games/zork/` — 15 rooms as separate 3D maps; troll, thief and cyclops with
branching dialogue whose answers are `check`ed against the intel journal (true
tokens vs. false rumours linked by `conflicts`; `debunk` marks lies). Exercises
melee execution, actor spawning/death/loot, `examine`/`pickup`/`container`
interactions, talkable actors (`ActorTalk`), `DialogueUi`, the narration-log HUD
with score/moves, and dark rooms + light sources.

## Rules

1. `game_api/fps/addons/game_core/` and `game_api/fps/games/<id>/` are **copies**.
   Edit `core/addons/game_core/` and `games/<id>/`, then run
   `./tools/sync_core.ps1` / `./tools/sync_game.ps1 -Game <id>`.
2. Anything the isometric engine would also need belongs in `core/`, not here.
3. This layer still carries legacy duplicates (`ItemDefinition`, `IntelToken`,
   `IntelQuery`, `Inventory`, `CharacterStats`, `Interaction`, `Shop`,
   `StatusEffects`, `PoiDefinition`). They are being retired — prefer the `Core*`
   class in new code; do not deepen the dependency on the duplicates.
4. `game_api/fps/tests/engine/` is **not yet wired into the runner** — it should
   be, before the duplicate-class retirement (see `activeContext.md`).
5. Finish with `./tools/run_tests.ps1`. Baseline: fps 23/23, boot check 8/8,
   zork boot 8/8, zork playtest 48/48.
