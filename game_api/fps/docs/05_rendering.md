# 05 — Rendering Strategy (Godot 4 Forward+)

## Why Forward+
Clustered forward renderer over Vulkan (D3D12 selectable) with: PBR metal/rough,
**SDFGI** (real-time GI for open worlds), **VoxelGI** (baked-quality GI for
interiors), SSAO/SSIL, SSR, volumetric fog, glow, TAA / FSR 2 upscaling, mesh LOD
auto-generation, occlusion culling, decals, and `DirectionalLight3D` PSSM shadows.
It covers "modern graphics" without us maintaining a renderer.

## Per-kind lighting recipes
| kind      | GI                       | shadows                    | atmosphere |
|-----------|--------------------------|----------------------------|------------|
| exterior  | SDFGI (6 cascades)       | 1 directional, 4 splits, 8k atlas | procedural/physical sky, fog + volumetric fog (`env.forest.day`) |
| town      | SDFGI + ReflectionProbes at squares | directional + few shadowed omnis | dusk presets, volumetrics for torches |
| interior  | VoxelGI (baked) or SDFGI small | shadowed omni/spot ≤ 4 visible | volumetric fog for candle/dust (`env.interior.candle`) |
| dungeon   | SDFGI w/ occlusion, SSIL  | shadowed torches (pooled)  | heavy fog, low ambient, desaturated (`env.dungeon.damp`) |

Environment presets are `.tres` under `assets/environments/`, referenced by key
from `maps.json`. Change look per game without touching scenes.

## Quality tiers
`framework/rendering/render_settings.gd` defines LOW→ULTRA (FSR2 scale, TAA, SDFGI,
SSR, SSAO/SSIL, volumetrics, shadow atlas). Apply from a settings menu:
`RenderSettings.apply(RenderSettings.Tier.HIGH, get_viewport(), env)`.

## Terrain (exteriors)
- Heightmap workflow: 16/32-bit EXR → chunk meshes (`TerrainStreamer` +
  `TerrainChunkBuilder` native module) or the **Terrain3D** GDExtension (drop-in).
- `assets/shaders/terrain_splat.gdshader`: 4-layer splat + slope-driven rock +
  triplanar cliffs + distance detail fade.
- Foliage: `MultiMeshInstance3D` scatter per chunk, wind via shader, LOD by distance.
- Chunk size 256 m, view distance 2 chunks (~640 m) default; tune per game.

## Performance budgets (1080p, mid-range GPU, 60 fps target)
| item | budget |
|------|--------|
| visible triangles | ≤ 3 M exterior, ≤ 1.5 M interior |
| draw calls | ≤ 2500 |
| shadowed lights on screen | 1 directional + 4 omni/spot |
| texture VRAM | ≤ 3 GB (BCn / ASTC compressed) |
| per-prop tris | props ≤ 8k, hero props ≤ 60k, characters ≤ 30k |
| LODs | 3 per mesh, auto-generated on import unless authored |

## Conventions
- Physics layers: 1 World, 2 Player, 3 Interactable, 4 Portal, 5 NPC.
- Camera: FOV 80, near 0.05 (first-person hands), far 4000.
- Colour: ACES tonemap, linear workflow, sRGB albedo, `_orm` packed textures.
- Use `VisibleOnScreenNotifier3D`/occluders for interiors; bake `OccluderInstance3D` for towns and dungeons.
