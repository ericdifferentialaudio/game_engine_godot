# 07 · Rendering & Asset Pipeline (2D)

## Renderer
Godot 4.7 **2D, Mobile renderer**, pixel-snapped. `WorldRenderer` (created by
`WorldManager`) draws:

| layer (z) | content | source |
|---|---|---|
| Terrain (0) | `TileMapLayer` with a `TileSet` built at bind time | `tile.<terrain>` keys or generated hex/diamond swatches from `TileDefinition.color` |
| Features (1) | `Sprite2D` per feature | `feature.<id>` textures (placeholder circle if missing) |
| Borders (2) | `Line2D` outline in owner colour | tile owner |
| Sites (3) | instanced scene | `site.<category>` scenes (placeholder marker if missing) |
| Units (4) | `Unit` nodes (AnimatedSprite2D + label + health bar), Y-sorted | `unit.<id>` SpriteFrames (placeholder frame if missing) |
| Fog (5) | `Polygon2D` per non-visible tile (dark = unexplored, dim = explored) | per-viewer-faction fog |
| Overlay (6) | `TileCursor`: hover/selection outline, reachable range, path preview | input |

`IsoCamera` (Camera2D): WASD/arrows, edge scroll, wheel zoom around cursor, middle-drag,
clamped to `WorldRenderer.map_rect()`, focuses selected unit / `camera_focus_requested`.

## Asset manifest (`assets.json`)
Data never references `res://` directly; it references **keys**. Types:
`tileset`, `tile` (tileset + source + atlas), `texture`, `sprite_frames` (+`facings`),
`scene`, `shader`, `audio`, `font`, `environment`. Missing entries degrade gracefully:
scenes → `framework/world/placeholder_prop.tscn`, textures → coloured swatch keyed by
name, sprite_frames → single "idle" swatch. Games are playable with **zero art**.

Key conventions: `tile.<terrain>`, `feature.<id>`, `unit.<def>`, `portrait.<def>`,
`icon.item.<id>`, `site.<category>`, `env.<name>`, `music.<name>`, `shader.<name>`.

## Folder plan (`assets/`)
```
tiles/         terrain tilesets (.png atlases + .tres TileSet)  placeholder/ (generated)
features/      forest, marsh, reeds… overlays
units/<id>/    sprite sheets + frames.tres (SpriteFrames), 6 facings for hex / 8 for iso
characters/portraits/   64–256 px portraits
items/icons/   32–64 px icons
structures/<id>/  site scenes (.tscn) — may include animation, lights (2D), labels
ui/            theme, panels, cursors        vfx/  particles, hit flashes
audio/{music,sfx,ambience}                   shaders/  fog_of_war, tile_highlight, unit_outline
fonts/
```
`assets_src/` holds DCC sources (Aseprite, Blender for pre-rendered iso sprites) — not shipped.

## Tools
* `python tools/gen_placeholders.py [--game id] [--force]` — writes PNG placeholders for
  every terrain/feature/portrait/icon path in the manifest (pure stdlib PNG writer).
* `python tools/asset_manifest.py --game id` — present/missing/bad-type/unmanifested/unreferenced audit.
* Shaders in `assets/shaders/` are ready to attach: fog (level uniform), highlight (pulse), outline.

## Authoring real art
1. Tiles: one atlas per tileset, `TileSet` shape must match topology (`TILE_SHAPE_HEXAGON`
   + `STACKED_OFFSET` for pointy hex, `TILE_SHAPE_ISOMETRIC` + `DIAMOND_DOWN` for iso).
   Then switch manifest entries to `{"type": "tile", "tileset": "tileset.world", "source": n, "atlas": [x, y]}`.
2. Units: `SpriteFrames` resource with animations `idle`, `walk_<facing>`, `attack`, `die`.
   `Unit.facing` (0..5 / 0..7) is available for direction-aware animation names.
3. Sites: any `Node2D` scene; optionally implement `configure(name, color)`.
