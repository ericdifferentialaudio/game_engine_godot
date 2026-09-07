# 09 · Setup & Roadmap

## Requirements
* Godot **4.7.x** (project features: `4.7`, `Mobile`). Configure the binary once:
  `godot.local.json` → `{"godot_bin": "C:\\Tools\\Godot\\4.7.2\\godot_console.exe"}`
  (git-ignored; or set `$env:GODOT_BIN`; or have `godot` on PATH).
* Python 3.10+ (stdlib only) for tooling and tests.
* VS Code: `.vscode/` ships tasks (Check / Import / Edit / Run / Smoke / Validate / Tests /
  Placeholders / CI: Everything), launch configs (godot-tools, debugpy) and JSON-schema
  wiring for every data file.

## First run
```powershell
cd c:\game_engine_iso
python tools\validate_data.py --all --strict
python -m unittest discover -s tests -v
python tools\gen_placeholders.py
tools\godot.ps1 check          # import + compile every .gd, load every .tscn
tools\godot.ps1 smoke          # headless end-to-end run, exit 0 on success
tools\godot.ps1 run            # play example_realm_iso
```

## Making a game
1. `python tools\new_game.py my_game --title "My Game" --topology hex --turns sequential`
2. Edit `games/my_game/*.json` (schemas give autocompletion in VS Code).
3. `python tools\validate_data.py games\my_game` until clean.
4. `python tools\gen_placeholders.py --game my_game` → `tools\godot.ps1 run my_game`.
5. Add real art by filling `assets.json` paths (see doc 07).
6. Game-specific code (custom interactions, generators, AI, combat) goes in a per-game
   autoload or scene that calls the `register()` hooks listed in doc 01.

## What exists (v0.1)
Grid (hex/iso) · procedural + layout maps · site descent with depth limit · per-faction
fog · pathfinding · factions/diplomacy/yields · heroes/units/NPCs/monsters/structures ·
stats/equipment/inventory/statuses/abilities/levels · unit AI behaviours · deterministic
combat resolver · sites with 8 interaction kinds · dialogue + shops (with intel brokering) ·
intel: journals, provenance, corroboration, contradiction/debunk, decay, reveals, derivation,
spread, trade, 20 query predicates · 4 turn modes + phases + clock/eras · HUD, journal,
dialogue, shop panels · save/load · validator, scaffolder, placeholder generator, asset
audit, headless compile check and smoke test · reference game.

## Roadmap (suggested order)
1. **Production & cities** — `structure` kind is ready; add a `CityManager` (build queue,
   tile working, growth) as a framework module + `production.json`.
2. **Tech/civics** — a `tech.json` tree gating units/abilities via `IntelQuery`
   (`{"faction_flag": "tech.bronze"}` already works as the gate).
3. **Diplomacy screen** — trade intel/resources; `IntelRegistry.transfer` + `Faction.set_stance` exist.
4. **Espionage units** — spy unit with `stolen`-channel abilities and `secrecy` checks.
5. **WeGo order queues** — `Unit.queue_order/execute_orders` + RESOLVE hook.
6. **Animation & audio** — facing-aware `SpriteFrames`, `music.*` playback on `world_loaded`.
7. **Multiplayer** — turn modes and seeded RNG are already deterministic; serialise commits.
8. **GDExtension hot paths** — sight flood / pathfinding in C++ if maps exceed ~100×100.
