# IntelForge Engine

A **Godot 4 (Forward+)** framework for first-person, information/intel-driven
fantasy games. Games are data packages (`games/<id>/`) layered on a reusable
framework: recursive map hierarchy (overworld → towns/castles/dungeons → sub-levels,
depth-limited), points of interest with pluggable interactions, and a first-class
**intel** system (tokens with reliability, corroboration, expiry, contradictions,
and a query language that gates shops, portals and rewards).

Combat and magic are first-class: every living thing is an **Actor** built from
components (Health, Stats, Equipment, AbilityCaster, Perception, Faction…), items
are behavioural (effects, granted abilities, procs) and can be gated or identified
by intel, and all of it is data in `games/<id>/*.json`.

```
core/        autoloads: EventBus, GameClock, DefinitionRegistry, AssetRegistry, GameManager,
             MapManager, IntelRegistry, SaveManager
framework/   reusable gameplay: actor/ (components, brains) combat/ items/ map/ poi/ intel/
             economy/ rendering/ ui/ data/
games/       one folder per game (JSON + map scenes)  → example_realm/
assets/      runtime art (glTF/PBR) + environment presets + shaders
assets_src/  DCC sources (LFS, not shipped)
scenes/      main.tscn, player.tscn, hud.tscn
schemas/     JSON Schemas for every data type
tools/       godot.ps1 (check/test/run/edit), validate_data.py, new_game.py, asset_manifest.py
tests/       Python tooling tests + tests/godot/ in-engine unit tests
gdextension/ optional C++ hot paths (terrain, intel graph)
docs/        01 architecture · 02 maps · 03 intel · 04 POIs · 05 rendering · 06 assets ·
             07 setup/roadmap · 08 actors · 09 items · 10 combat design
```

Quick start: see `docs/07_roadmap_and_setup.md`.

```powershell
python tools\validate_data.py --all
godot --path . -- --game=example_realm
```
