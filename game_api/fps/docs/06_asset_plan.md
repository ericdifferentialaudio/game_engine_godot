# 06 — Graphics Asset Plan

## Pipeline
```
assets_src/ (Blender/Substance, git-LFS, not shipped)
    │  export glTF 2.0 (.glb, +Y up, metres, apply transforms, tangents on)
    ▼
assets/<category>/<name>/<name>.glb + <name>_albedo|_normal|_orm|_emissive.png
    │  Godot import (auto LODs, BCn compression, material remaps to .tres)
    ▼
assets/<category>/<name>/<name>.tscn   ← what assets.json keys point to
```
Rules: **glTF 2.0 only** for meshes; **PBR metal/roughness**; textures power-of-two,
≤ 2048 for props, ≤ 4096 for hero/terrain; ORM packed (R occlusion, G roughness,
B metallic). Modular kits snap to a **1 m grid**, pivot at floor-back-left corner.

## Logical asset keys (`games/<id>/assets.json`)
```
env.<biome>.<time>          Environment presets
mat.<family>.<variant>      shared materials
poi.<category>[.<variant>]  POI visuals (fallback poi.<category> → poi.generic)
portal.<variant>            portal visuals
kit.<set>.<piece>           modular architecture pieces
char.<name>                 NPC/creature scenes
fx.<name>, music.<name>, sfx.<name>
```
Keys give art independence: blockout with placeholders now, swap the manifest
later. Missing keys resolve to `framework/rendering/placeholder_prop.tscn`
(magenta box) so nothing crashes and gaps are obvious.

## Production phases
| Phase | Deliverable | Notes |
|-------|-------------|-------|
| 0 Blockout | placeholder markers (done), grey-box kits (1 m cubes/walls/stairs) | validate map flow & intel pacing |
| 1 Core kits | `castle_kit`, `town_kit`, `dungeon_kit` (~40 pieces each), 6 terrain materials, 3 sky/env presets per biome | the reusable backbone for all fantasy games |
| 2 POI props | chest, signpost, shrine, ledger/book, counter, notice board, campfire, well, statue | one per `poi.<category>` + 2 variants |
| 3 Characters | generic NPC base mesh + 6 outfits, 3 informant archetypes, first-person hands | shared rig, glTF animations |
| 4 Foliage & terrain | 6 trees, 8 shrubs/grass, 6 rocks, splat textures, heightmap sets | scatter via MultiMesh |
| 5 VFX/UI | portal glow, discovery pulse, intel "ping", fog volumes, journal theme | GPUParticles3D + decals |

## Budgets (see docs/05 for scene totals)
| asset class | tris (LOD0) | textures | LODs |
|-------------|-------------|----------|------|
| small prop  | ≤ 4k        | 1×1024 set | 2 |
| kit piece   | ≤ 6k        | shared trim sheets 2048 | 3 |
| hero prop / landmark | ≤ 60k | 2×2048 | 3 |
| NPC         | ≤ 30k       | 2048 body + 1024 head | 3 |
| tree        | ≤ 12k (+ billboard LOD) | 2048 bark + 1024 leaves | 3 + impostor |

## Tracking
- `assets.json` per game is the manifest; add `lods` and `budget_tris` metadata.
- `python tools/asset_manifest.py --game <id> --csv inventory.csv` reports naming
  violations and missing files for the art backlog.
- Placeholder-first policy: every new POI category gets a `poi.<category>` key
  pointing at `poi_marker.tscn` until real art lands.

## Licensing/sourcing
Prefer CC0 / own art. Track third-party licences in `assets/LICENSES.md` (create
on first import). Kits like Kenney/Quaternius (CC0) are acceptable for blockout.
