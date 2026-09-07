## Static description of a map (built from maps.json).
##
## A map is any explorable space: overworld terrain, a town, a castle, a
## dungeon level, or a small interior. Maps form a tree via [member parent_id];
## traversal between them is through portals declared here.
class_name MapDefinition
extends Definition

enum Kind { OVERWORLD, REGION, TOWN, CASTLE, DUNGEON, INTERIOR, SPECIAL }

const KIND_NAMES := {
	"overworld": Kind.OVERWORLD, "region": Kind.REGION, "town": Kind.TOWN,
	"castle": Kind.CASTLE, "dungeon": Kind.DUNGEON, "interior": Kind.INTERIOR,
	"special": Kind.SPECIAL,
}

@export var kind: Kind = Kind.OVERWORLD
@export var parent_id: String = ""          ## "" for a root map.
@export var scene_path: String = ""         ## res:// path of the map scene.
@export var environment_key: String = ""    ## AssetRegistry key -> Environment preset.
@export var is_exterior: bool = true        ## Drives sky/fog/GI settings.
@export var portals: Array[Dictionary] = [] ## {id, target_map, target_spawn, requires(IntelQuery)?}
@export var spawns: Dictionary = {}         ## spawn_name -> {position:[x,y,z], yaw:deg}
@export var streaming: Dictionary = {}      ## {chunk_size, view_distance} for large exteriors
@export var music_key: String = ""
@export var spawn_tables: Array[Dictionary] = [] ## {actor, count, position?, respawn?} (M3 spawners)
@export var seed: int = 0                   ## For generated maps.
@export var short_description: String = ""  ## Printed on revisits (Zork "brief" mode).
@export var dark: bool = false              ## Needs a light source; see game.json "light".
@export var dark_description: String = ""   ## Printed instead of description when unlit.

var poi_ids: Array[String] = []             ## Filled by MapManager from pois.json.


static func from_dict(d: Dictionary) -> MapDefinition:
	return Definition.build(MapDefinition, d) as MapDefinition


func _apply(d: Dictionary) -> void:
	kind = KIND_NAMES.get(str(d.get("kind", "overworld")).to_lower(), Kind.SPECIAL)
	parent_id = d.get("parent", "")
	scene_path = d.get("scene", "")
	environment_key = d.get("environment", "")
	is_exterior = d.get("exterior", kind in [Kind.OVERWORLD, Kind.REGION, Kind.TOWN])
	portals = Definition._dict_array(d.get("portals", []))
	spawns = d.get("spawns", {})
	streaming = d.get("streaming", {})
	music_key = d.get("music", "")
	spawn_tables = Definition._dict_array(d.get("spawn_tables", []))
	seed = int(d.get("seed", 0))
	short_description = str(d.get("short_description", ""))
	dark = bool(d.get("dark", false))
	dark_description = str(d.get("dark_description", "It is pitch black. You are likely to be eaten by a grue."))


func get_portal(portal_id: String) -> Dictionary:
	for p in portals:
		if p.get("id", "") == portal_id:
			return p
	return {}


func get_spawn(spawn_name: String) -> Transform3D:
	var s: Dictionary = spawns.get(spawn_name, spawns.get("default", {}))
	var pos_arr: Array = s.get("position", [0, 1, 0])
	var pos := Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
	var yaw := deg_to_rad(float(s.get("yaw", 0.0)))
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func kind_name() -> String:
	return Kind.keys()[kind].to_lower()
