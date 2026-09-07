# 02 · Grid & World

## Topologies (`game.json → grid`)
| topology | storage coords | neighbours | notes |
|---|---|---|---|
| `hex` (default) | offset (col,row); `orientation: pointy` = odd-r, `flat` = odd-q | 6 | cube-coordinate distance, Civ 5/6 look |
| `square_iso` | (x,y) drawn as a 2:1 diamond | 4 or 8 (`diagonals`) | classic iso |

`GridTopology` is the only place that knows geometry: `neighbors`, `distance`, `ring`,
`to_world` / `to_tile` (pixel ↔ tile), `facing` (for direction sprites), and TileSet
shape/layout hints for the renderer. `wrap_x: true` makes a cylindrical world.

## WorldMap (model, no rendering)
* `tiles: Vector2i → Tile{terrain, features[], improvements[], has_road, owner_id, site_id, resource_id, elevation, metadata}`
* Occupancy index (`unit_at`, `units_at`) kept in sync by `place_unit/remove_unit`.
* **Fog per faction**: `UNEXPLORED → EXPLORED → VISIBLE`. `compute_sight(origin, range)`
  floods through neighbours; `blocks_sight` terrain/features stop propagation unless the
  observer is higher (`elevation`). `FogOfWar.recompute()` unions unit sight, owned-tile
  sight and site sight (+ allied vision when `rules.fog.shared_vision_allies`).
* Intel **reveals** (`IntelToken.reveals`) add *EXPLORED* knowledge without live vision.

## Terrains & features (`terrains.json`)
`TileDefinition` covers both. Terrain: `domain` (land/sea/any), `move_cost`, `passable`,
`yields`, `defense_bonus`, `sight_cost`, `blocks_sight`, `elevation`, `color` (blockout),
`spawn_weight`. Feature: additionally `allowed_on`, `spawn_chance`. Improvements/roads
are free-form strings on the tile (games define semantics).

## Maps (`maps.json`) & generation
* `generator.type: "noise"` — FastNoiseLite height + moisture, `terrain_bands` (optionally
  `by_moisture`), `edge_falloff` to keep coasts, features placed by `spawn_chance`.
* `layout` + `glyphs` — hand-authored ASCII rows (dungeons, interiors, scripted overworlds).
* Custom: `MapGenerator.register("my_type", callable)`.
* Deterministic: seed = `game.seed` (or `--seed=N`) + `hash(map_id)`; `WorldMap.rng` is
  seeded from it, so spawns/combat are reproducible per seed.

## Hierarchy & site descent
Maps form a tree via `parent`. Portals (a `portal` interaction on a site) call
`WorldManager.descend/ascend`. The stack is limited by `game.max_map_depth`. Parent maps
stay cached in memory while descended; per-map state (`discovered_sites`, `sites`, saved
world) lives in `WorldManager.map_states` and is serialised by `SaveManager`.

## Pathfinding
`Pathfinder.find_path` (A*) and `Pathfinder.reachable` (Dijkstra flood within AP budget).
Cost = terrain `move_cost` (+ feature costs) modified by the unit's `movement` block
(`domain`, `ignore_terrain`, `terrain_costs`, `impassable`, `uses_roads`). Enemy-occupied
tiles block; Civ rule "you can always enter a tile if you have any AP left" is applied in
`Unit.move_along`.

## Starts
Faction start = `factions.json start` → `maps.json starts[faction]` → random; refined by
`MapGenerator.find_start_near` which requires `rules.world.start_min_land_neighbors`
(default 6) passable land tiles within radius 2 so nobody starts on an islet.
