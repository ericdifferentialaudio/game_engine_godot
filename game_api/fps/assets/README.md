# assets/ — runtime art

Only **import-ready, engine-consumable** files live here (glTF 2.0 `.glb`, PNG/KTX2
textures, `.tres` materials/environments, `.tscn` prop scenes). Editable source
files (Blender `.blend`, Substance `.sbs`, PSD) go in `assets_src/` (git-LFS,
not shipped). Full conventions: `docs/06_asset_plan.md`.

```
assets/
  environments/     Environment .tres presets (sky, fog, GI, tonemap) – keyed env.*
  materials/        Shared StandardMaterial3D / ShaderMaterial .tres – keyed mat.*
  shaders/          .gdshader (terrain splat, water, foliage wind, triplanar)
  terrain/          Heightmaps (.exr 16/32-bit), splat masks, terrain chunk scenes
  architecture/     Modular kits: castle_kit/, town_kit/, dungeon_kit/ (snap to 1 m grid)
  props/            <prop_name>/<prop_name>.glb + textures + <prop_name>.tscn
  characters/       <char_name>/ rig + animations (glTF), keyed char.*
  foliage/          Trees/grass/rocks for MultiMeshInstance3D scattering
  vfx/              GPUParticles3D scenes, decals
  ui/               Fonts, icons, theme .tres
  audio/            music/ ambience/ sfx/ (ogg vorbis) – keyed music.* / sfx.*
```

Naming: `snake_case`. Textures `name_albedo.png`, `name_normal.png`,
`name_orm.png` (occlusion R, roughness G, metallic B), `name_emissive.png`.
LODs baked in glTF as `name_lod0..lod2` meshes, or auto-generated on import.

Audit with `python tools/asset_manifest.py --game example_realm`.
