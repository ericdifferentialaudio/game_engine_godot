# 02 — Maps, Recursive Submaps & Portals

## Model
Maps form a **tree** declared in `maps.json`. Each map has a `kind`, an optional
`parent`, named `spawns`, and `portals` to other maps.

```
overworld (OVERWORLD, depth 0)
├─ hollowmere (TOWN, 1)
│   └─ marrow_shop (INTERIOR, 2)
├─ crypt_l1 (DUNGEON, 1)
│   └─ crypt_l2 (DUNGEON, 2)
│       └─ ... (until max_map_depth)
└─ blackspire (CASTLE, 1)
    ├─ great_hall (INTERIOR, 2)
    └─ undercroft (DUNGEON, 2)
```

`game.json → max_map_depth` (default 4) is the hard recursion limit. `MapManager`
validates depth at load and refuses `descend()` past it at runtime, emitting a
notification. This keeps procedurally generated dungeon chains bounded.

### Kinds and their defaults
| kind        | exterior | typical content                                 | streaming |
|-------------|----------|-------------------------------------------------|-----------|
| overworld   | yes      | terrain, roads, landmarks, entrances            | chunked   |
| region      | yes      | sub-area of overworld (a valley, an island)     | chunked   |
| town        | yes      | modular kit buildings, NPC informants, shops    | single    |
| castle      | yes/no   | kit-based, many interiors as children           | single    |
| dungeon     | no       | modular dungeon kit, sublevels as children      | single    |
| interior    | no       | shop/inn/room; small, fast load                 | single    |
| special     | –        | anything else (dream, memory, pocket dimension) | –         |

## Traversal semantics (`MapManager`)
- `descend(child)` — pushes current map on the stack, loads child. Blocked at depth limit.
- `ascend()` — pops and reloads the parent at the portal's `target_spawn`.
- `traverse_portal(id)` — picks descend/ascend automatically from the hierarchy;
  lateral links (e.g. a teleport between two dungeons) rebuild the stack from the
  static tree so breadcrumbs stay correct.
- Portals may carry `requires` (an IntelQuery). Locked portals show a message.

## Per-map persistence
`MapManager.map_states[map_id]` holds `discovered_pois`, per-POI state (`pois`),
`flags`, `visits`. POIs read/write through `PointOfInterest.get_state()`, so a
once-only chest stays opened after leaving and re-entering. Shops persist stock
under the reserved map id `__shops__`.

## Authoring a map scene
1. Create `games/<id>/maps/<map>.tscn`, root `Node3D` with script `MapRoot`
   (or a subclass).
2. Add `WorldEnvironment` (optional — the preset from `assets.json` will be applied),
   `DirectionalLight3D`, geometry with collision on layer **World (1)**.
3. Optionally place `Marker3D` nodes named `POI_<poi_id>` / `Portal_<portal_id>`;
   data-driven objects snap to them, otherwise JSON positions are used.
4. For big exteriors add a `TerrainStreamer` child pointing at a chunk folder.
5. Until the scene exists, `placeholder_map.tscn` is used automatically so the
   whole hierarchy is playable from data alone (great for blockout & design review).

## Future: procedural sublevels
Because children are just `MapDefinition`s, a generator can append definitions
at runtime (`MapManager.definitions[new_id] = def`) and portals into them, as
long as it respects `max_depth`. Planned as a GDExtension module.
