# The Chorus of Unspoken Names

Game package `chorus`.

- `game.json`        entry point: grid, turn mode, calendar, rules
- `terrains.json`    terrain + feature types
- `maps.json`        overworld + site sub-maps (generator or glyph layout)
- `units.json`       heroes / units / npcs / monsters / structures + ability catalog
- `items.json`       equipment, consumables, intel-bearing items, artifacts
- `factions.json`    players, AI, neutrals, monsters; diplomacy + starting kit
- `intel.json`       intel tokens
- `intel_rules.json` derivation / spread / contradiction rules
- `sites.json`       points of interest on tiles with interactions
- `ai_profiles.json` unit AI behaviours
- `assets.json`      logical asset keys -> res:// paths

Validate: `python tools/validate_data.py games/chorus`
Run:      `tools/godot.ps1 run chorus`    Smoke test: `tools/godot.ps1 smoke chorus`
