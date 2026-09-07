# 07 — Setup & Roadmap

## Toolchain
1. **Godot 4.7.2 stable** — installed at `C:\Tools\Godot\4.7.2\`
   (`godot.exe` = editor, `godot_console.exe` = same binary with console output,
   `godot.cmd` = shim). That folder is on the **user PATH**, so `godot` works in any
   new terminal. Other machines: unzip the official Windows build anywhere and
   either add it to PATH, set `GODOT_BIN`, or copy `godot.local.example.json` →
   `godot.local.json` (git-ignored) with the path.
2. **Git** — `winget install Git.Git`; then `git init` here and enable LFS for `assets_src/`.
3. **Python 3.10+** — present (3.14). Used by `tools/`.
4. **VS Code** — extension `geequlim.godot-tools` (installed) + Python. `.vscode/`
   ships settings (editor path, GDScript LSP on 6005), tasks and launch configs.
5. Optional (native modules): **Visual Studio 2022 Build Tools** (C++), `pip install scons`.
6. Optional: **Blender 4.x** for glTF export.

## Running
```powershell
.\tools\godot.ps1 check                         # headless: import + compile every .gd, load every .tscn
.\tools\godot.ps1 test                          # headless: in-engine unit tests (tests/godot/test_*.gd)
.\tools\godot.ps1 edit                          # open the Godot editor on this project
.\tools\godot.ps1 run                           # run default game (bootstrap.json)
.\tools\godot.ps1 run example_realm             # run a specific package
.\tools\godot.ps1 import                        # (re)generate .godot/ import cache
python tools\validate_data.py --all --strict    # data sanity (no Godot needed)
python -m unittest discover -s tests            # tooling tests
python tools\new_game.py my_realm --title "My Realm"
python tools\asset_manifest.py --game example_realm
```
Or in VS Code: **Ctrl+Shift+B** runs "Godot: Check"; the Tasks menu has Run/Edit/
Validate/CI; **F5** launches the game under the GDScript debugger (the Godot editor
must be open once for the LSP/debugger to connect).

`.godot/` is generated and git-ignored. `gdextension/intelforge.gdextension.disabled`
is intentionally disabled (rename to `.gdextension` after building `bin/`), because
Godot auto-loads every `.gdextension` it finds and errors if the DLL is missing.

## Engine verification status
`tools\godot.ps1 check` → 31 scripts + 7 scenes compile clean under Godot 4.7.2;
`godot --headless -- --game=example_realm` boots the full loop (only expected
"missing art → placeholder" warnings).

## Controls (example)
WASD move, Shift sprint, Space jump, **E** interact, **J** journal, Esc pause.

## Roadmap (revised for full combat + magic)
### M0 – Skeleton ✅
Autoloads, map hierarchy w/ depth limit, POI + interaction strategies, intel
tokens/queries/journal, save/load, placeholders, example package, validators, docs.

### M1 – Foundations ✅
- `GameClock` (game time, phases, scheduling) — intel expiry moved off wall-clock.
- `DefinitionRegistry` + `Definition` base; types: maps, pois, intel, **items,
  actors, factions, effects, abilities** (schemas + validator + scaffolder).
- **Actor/component architecture**: Health, Stats (modifier stack), Resources,
  StatusEffects, Inventory (ItemInstance stacks), Equipment (intel/stat gated),
  AbilityCaster, Perception, Faction, Damageable, PlayerBrain, AIBrain.
- `DamageInfo` / `DamageCalculator` (armour curve, resistances, immunities, crit, dodge).
- In-engine test runner (`tools\godot.ps1 test`, 30 tests) + GitHub Actions CI.
- Docs 08 (actors), 09 (items), 10 (combat design).

### M2 – Combat core
Ability execution pipeline (targeting, projectiles, melee arcs, procs), hit
feedback, view-model, blocking/dodge, consumables, loot tables, damage numbers,
one melee weapon + one spell + a test dummy fully playable.

### M3 – Monsters & AI
Utility AI over abilities, patrol/schedule/investigate, group alerts, spawners
with persistence, navmesh baking, 3 archetypes + Bone-Warden boss with
intel-gated weakness reveal.

### M4 – Magic items & progression
Affix generation, identification via intel/sage/scroll, grimoires, XP and/or
knowledge unlocks, durability, item lore as intel sources.

### M5 – NPCs, dialogue, quests, factions
Dialogue resources, schedules & memory, disposition, quest/objective system
with intel-style objectives, reputation consequences, shop/dialogue/quest UI.

### M6 – Map generation
Seeded dungeon graph generator (kit-based, lock/key + intel-gate solvability),
overworld heightmap/biome/roads/settlements, town layouts; save = seed + delta;
editor placement plugin; Terrain3D or native chunk builder.

### M7 – World sim & polish
Day/night driving env presets, weather, economy drift, adaptive audio, full UI
screens, settings, localization, autosave, export presets.
