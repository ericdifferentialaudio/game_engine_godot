# IntelForge Iso Engine

A **Godot 4.7 (2D)** framework for isometric / hex tile-based, **turn-based or
time-based** strategy games in the Civ 6 mould — with information (**intel**)
as a first-class resource. Sister project of `C:\game_engine` (first-person
IntelForge): same data-package philosophy, same EventBus/registry patterns,
different perspective and gameplay loop.

Games are pure data packages (`games/<id>/*.json`) layered on a reusable
framework: hex or square-iso grid, procedural or hand-authored maps with
depth-limited site descent (city interiors, dungeons), factions with
diplomacy, units/heroes/NPCs/monsters/structures, items, sites with pluggable
interactions, and a deep intel system (per-faction journals, reliability,
provenance chains, corroboration, contradiction, decay in turns, derivation
rules, inter-faction spread, trading and debunking).

```
core/         autoloads: EventBus, AssetRegistry, GameManager, GameClock, TurnManager,
              FactionRegistry, ItemRegistry, EntityRegistry, IntelRegistry, WorldManager, SaveManager
framework/    grid/ (topologies, A*)  world/ (tiles, map model, generator, fog, renderer, camera, cursor)
              entities/ (definitions, Unit, Faction, stats, inventory, statuses, abilities, AI)
              intel/ (token, provenance, journal, rules, query)  sites/ (+ interactions/)
              combat/  economy/  ui/
games/        one folder per game → example_realm_iso/ (reference package)
assets/       2D art: tiles/ features/ units/ characters/ items/ structures/ ui/ vfx/ audio/ shaders/ fonts/
assets_src/   DCC sources (not shipped)
scenes/       main.tscn (boot + camera + cursor), hud.tscn
schemas/      JSON Schemas for every data file (wired into VS Code)
tools/        godot.ps1, check_scripts.gd, smoke_test.gd, validate_data.py, new_game.py,
              asset_manifest.py, gen_placeholders.py
tests/        Python unit tests for tooling + reference data
docs/         01 architecture · 02 grid & world · 03 turns & time · 04 entities · 05 intel deep-dive
              06 sites & interactions · 07 rendering & assets · 08 data reference · 09 setup & roadmap
```

## Quick start

```powershell
python tools\validate_data.py --all --strict        # data cross-reference checks
python -m unittest discover -s tests -v             # tooling tests
python tools\gen_placeholders.py                    # blockout PNGs for tiles/portraits/icons
tools\godot.ps1 check                               # compile every script + scene headlessly
tools\godot.ps1 smoke                               # headless end-to-end run (world, turns, intel, save/load)
tools\godot.ps1 run                                 # play the default game (bootstrap.json)
tools\godot.ps1 edit                                # open the Godot editor
python tools\new_game.py my_game --title "My Game" --topology hex --turns simultaneous
```

Godot binary resolution: `$env:GODOT_BIN` → `godot.local.json` → `godot` on PATH.

## Controls (reference HUD)

WASD / arrows / edge-scroll pan · wheel zoom · middle-drag pan · **LMB** select tile/unit ·
**RMB** move/attack with selected unit · **.** next idle unit · **Enter** end turn ·
**J** intel journal · **Space** pause clock (real-time mode) · **Esc** pause.

See `docs/09_setup_and_roadmap.md` for the full setup and what to build next.
