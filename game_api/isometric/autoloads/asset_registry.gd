## Indirection layer between game data and concrete asset paths (2D pipeline).
##
## Game JSON never hardcodes res:// paths for art. It references logical asset
## keys ("tile.grassland", "unit.scout", "portrait.bertha", "icon.item.map")
## which the per-game assets.json manifest resolves to real resources. This
## lets us swap art packs, run on placeholder art, and share assets across games.
##
## Manifest format (assets.json):
## {
##   "assets": {
##     "tileset.world":   {"type": "tileset",       "path": "res://assets/tiles/hex_placeholder.tres"},
##     "tile.grassland":  {"type": "tile",          "tileset": "tileset.world", "source": 0, "atlas": [0, 0]},
##     "unit.scout":      {"type": "sprite_frames", "path": "res://assets/units/scout/scout.tres", "facings": 6},
##     "portrait.bertha": {"type": "texture",       "path": "res://assets/characters/portraits/bertha.png"},
##     "icon.item.map":   {"type": "texture",       "path": "res://assets/items/icons/map.png"},
##     "site.ruins":      {"type": "scene",         "path": "res://assets/structures/ruins/ruins.tscn"},
##     "shader.fog":      {"type": "shader",        "path": "res://assets/shaders/fog_of_war.gdshader"},
##     "music.overworld": {"type": "audio",         "path": "res://assets/audio/music/overworld.ogg"}
##   }
## }
##
## Missing assets never crash the game: scenes fall back to a placeholder
## sprite, textures fall back to a generated coloured swatch (colour derived
## from the key so units/terrains stay distinguishable in blockout).
extends Node

const KNOWN_TYPES := ["tileset", "tile", "texture", "sprite_frames", "scene", "shader", "audio", "font", "environment"]
const PLACEHOLDER_SCENE := "res://framework/world/placeholder_prop.tscn"

var manifest: Dictionary = {}
var _cache: Dictionary = {}
var _placeholder_textures: Dictionary = {}


func load_manifest(path: String) -> void:
	manifest = DataLoader.load_json(path).get("assets", {})
	_cache.clear()
	for key in manifest:
		var t: String = manifest[key].get("type", "")
		if t != "" and t not in KNOWN_TYPES:
			push_warning("AssetRegistry: '%s' has unknown type '%s'" % [key, t])


func has_asset(key: String) -> bool:
	return manifest.has(key)


func get_asset_path(key: String) -> String:
	return manifest.get(key, {}).get("path", "")


func get_asset_meta(key: String) -> Dictionary:
	return manifest.get(key, {})


## Load (and cache) the resource for a logical key. Returns null only for
## unknown non-visual types; visual types get placeholders.
func load_asset(key: String) -> Resource:
	if _cache.has(key):
		return _cache[key]
	var entry: Dictionary = manifest.get(key, {})
	var path: String = entry.get("path", "")
	var type: String = entry.get("type", "")
	var res: Resource = null
	if path != "" and ResourceLoader.exists(path):
		res = load(path)
	else:
		match type:
			"scene", "":
				if path != "" or type == "scene":
					push_warning("AssetRegistry: '%s' missing (%s); using placeholder scene" % [key, path])
				res = load(PLACEHOLDER_SCENE)
			"texture":
				res = placeholder_texture(key)
			"sprite_frames":
				res = _placeholder_frames(key)
			_:
				push_warning("AssetRegistry: asset '%s' (%s) not found at %s" % [key, type, path])
	_cache[key] = res
	return res


## Instance a scene asset by key; returns a Node2D (placeholder if missing).
func instance_scene(key: String) -> Node2D:
	var res := load_asset(key)
	if res is PackedScene:
		var inst = (res as PackedScene).instantiate()
		if inst is Node2D:
			return inst
		inst.queue_free()
	push_error("AssetRegistry: '%s' is not a 2D PackedScene" % key)
	return Node2D.new()


func load_texture(key: String) -> Texture2D:
	var res := load_asset(key)
	if res is Texture2D:
		return res
	return placeholder_texture(key)


func load_sprite_frames(key: String) -> SpriteFrames:
	var res := load_asset(key)
	if res is SpriteFrames:
		return res
	return _placeholder_frames(key)


## Resolve a "tile" entry to {tileset: TileSet, source: int, atlas: Vector2i}.
func resolve_tile(key: String) -> Dictionary:
	var entry: Dictionary = manifest.get(key, {})
	if entry.get("type", "") != "tile":
		return {}
	var ts := load_asset(entry.get("tileset", ""))
	var atlas: Array = entry.get("atlas", [0, 0])
	return {
		"tileset": ts if ts is TileSet else null,
		"source": int(entry.get("source", 0)),
		"atlas": Vector2i(int(atlas[0]), int(atlas[1])),
	}


## Deterministic colour for a key so blockout art is readable.
func key_color(key: String) -> Color:
	var h := float(hash(key) % 360) / 360.0
	return Color.from_hsv(h, 0.55, 0.85)


## Coloured swatch texture generated at runtime (cached per key).
func placeholder_texture(key: String, size: int = 48) -> Texture2D:
	if _placeholder_textures.has(key):
		return _placeholder_textures[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := key_color(key)
	var r := size * 0.42
	var centre := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(centre) <= r:
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_textures[key] = tex
	return tex


func _placeholder_frames(key: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.add_frame("idle", placeholder_texture(key))
	return sf


## Background loading for large maps (call before a transition).
func preload_async(keys: Array) -> void:
	for key in keys:
		var path := get_asset_path(key)
		if path != "" and ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
