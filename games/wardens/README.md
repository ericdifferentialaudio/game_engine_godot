# Wardens of the Verdant Hush

Game package `wardens`.

- `game.json`  – entry point, start map, stats
- `maps.json`  – map hierarchy & portals
- `pois.json`  – points of interest & interactions
- `intel.json` – intel tokens
- `items.json` / `abilities.json` / `effects.json` – items, abilities (melee & spells), status effects
- `actors.json` / `factions.json` – player archetype, NPCs, monsters, bosses; faction relations
- `assets.json`– logical asset keys -> res:// paths
- `maps/`      – map scenes (.tscn) using MapRoot

Validate: `python tools/validate_data.py games/wardens`
Run:      `godot --path . -- --game=wardens`
