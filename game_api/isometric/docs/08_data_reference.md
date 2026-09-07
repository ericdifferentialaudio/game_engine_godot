# 08 · Data Package Reference

A game is `games/<id>/` containing these files (all JSON, all schema-backed in `schemas/`,
all cross-checked by `tools/validate_data.py`):

| file | root key | model | required |
|---|---|---|---|
| `game.json` | — | `GameManager.game_config` | yes |
| `terrains.json` | `terrains`, `features` | `TileDefinition` | yes |
| `maps.json` | `maps` | `MapDefinition` | yes |
| `units.json` | `units`, `abilities` | `EntityDefinition`, `AbilitySet.catalog` | yes |
| `items.json` | `items` | `ItemDefinition` | yes |
| `factions.json` | `factions` | `Faction.FactionDefinition` | yes |
| `intel.json` | `intel` | `IntelToken` | yes |
| `intel_rules.json` | `derivations`, `spread`, `contradiction`, `observation` | `IntelRules` | optional |
| `sites.json` | `sites` | `SiteDefinition` | yes |
| `ai_profiles.json` | `profiles`, `abilities` | `AIController.profiles` | optional |
| `assets.json` | `assets` | `AssetRegistry.manifest` | yes |

## `game.json` keys
```
id, title, version, description
grid      {topology: hex|square_iso, orientation: pointy|flat, diagonals, tile_size:[w,h], wrap_x}
turns     {mode: sequential|simultaneous|wego|realtime_pause, timer_seconds, ticks_per_turn, seconds_per_tick}
calendar  {start_year, years_per_turn, year_suffix_neg, year_suffix_pos, eras:[{id,label,from_turn}]}
start_map, player_faction, max_map_depth, seed
currencies[]      resources tracked per faction (yields with these keys are collected)
stats{}           default stat block for units
rules{}           dotted lookups via GameManager.rule("a.b", default):
  movement.road_cost                    combat.randomness / base_damage / retaliation_scale / defender_terrain_bonus / attack_ends_turn
  fog.shared_vision_allies / owned_tile_sight / site_sight
  intel.observe_units / observe_sites / perception_reliability_per_point
  units.heal_per_turn                   sites.capture_on_enter
  economy.sell_ratio / track_all_yields victory.last_faction_standing / eliminate_on_no_units
  world.start_min_land_neighbors
```
Other files are documented in their model class headers (`framework/**/*.gd`) and in
docs 02–06.

## Save file layout (`user://saves/<slot>.json`)
```
version, game_id, timestamp, flags,
clock{turn,tick,era}, turns{active,order,committed},
world{current, stack, seed, states{map_id: {discovered_sites, sites, flags, visits, world{tiles,fog}}}},
factions{id: {resources, stances, flags, eliminated, home, stockpile, rng}},
units{serial, selected, units{uid: {def, faction, map, coord, home, level, xp, ap, name, flags, stats, inventory, statuses, abilities}}},
intel{journals{faction: {tokens{id: {reliability, provenance[], acquired_turn, confirmed_turn, known_false, revealed_applied}}, trust, watchers}}, rules{derived_once}, rng}
```
`SaveManager.SAVE_VERSION` gates `_migrate()`.

## Validation
```
python tools/validate_data.py games/<id>          # one package
python tools/validate_data.py --all --strict      # CI: warnings are errors
```
Errors: broken references (tokens, units, items, factions, sites, maps, terrains, glyphs),
bad enums, malformed queries, depth/cycle problems. Warnings: unreachable intel, flags
never set by data, asset keys missing from the manifest.
