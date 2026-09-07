## Indirection layer between game data and concrete asset paths.
##
## Game JSON never hardcodes res:// paths for art. It references logical asset
## keys ("prop.chest.wooden", "env.forest.day") which the per-game assets.json
## manifest resolves to real resources. This lets us swap art packs, provide
## placeholder/blockout art, and share assets across games.
##
## Manifest format (assets.json):
## {
##   "assets": {
##     "prop.chest.wooden": {"type": "scene", "path": "res://assets/props/chest_wooden/chest_wooden.tscn", "lods": 3},
##     "env.forest.day":    {"type": "environment", "path": "res://assets/environments/forest_day.tres"},
##     "mat.stone.castle":  {"type": "material", "path": "res://assets/materials/stone_castle.tres"}
##   }
## }
extends Node

const PLACEHOLDER_SCENE := "res://framework/rendering/placeholder_prop.tscn"

var manifest: Dictionary = {}
var _cache: Dictionary = {}


func load_manifest(path: String) -> void:
	manifest = DataLoader.load_json(path).get("assets", {})
	_cache.clear()


func has_asset(key: String) -> bool:
	return manifest.has(key)


func get_asset_path(key: String) -> String:
	return manifest.get(key, {}).get("path", "")


func get_asset_meta(key: String) -> Dictionary:
	return manifest.get(key, {})


## Load (and cache) the resource for a logical key. Falls back to a placeholder
## for scenes so blockout levels still run before art exists.
func load_asset(key: String) -> Resource:
	if _cache.has(key):
		return _cache[key]
	var entry: Dictionary = manifest.get(key, {})
	var path: String = entry.get("path", "")
	var res: Resource = null
	if path != "" and ResourceLoader.exists(path):
		res = load(path)
	elif entry.get("type", "") == "scene" or path == "":
		push_warning("AssetRegistry: '%s' missing (%s); using placeholder" % [key, path])
		res = load(PLACEHOLDER_SCENE)
	else:
		push_warning("AssetRegistry: asset '%s' not found at %s" % [key, path])
	_cache[key] = res
	return res


## Instance a scene asset by key; returns a Node3D (placeholder if missing).
func instance_scene(key: String) -> Node3D:
	var res := load_asset(key)
	if res is PackedScene:
		return (res as PackedScene).instantiate()
	push_error("AssetRegistry: '%s' is not a PackedScene" % key)
	return Node3D.new()


## Background loading for large maps (call before a transition).
func preload_async(keys: Array) -> void:
	for key in keys:
		var path := get_asset_path(key)
		if path != "" and ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
