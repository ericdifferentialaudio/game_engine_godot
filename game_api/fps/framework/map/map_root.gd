## Base script for every map scene. Attach to the root Node3D of a map scene.
##
## Responsibilities:
##  * apply the environment preset for the map,
##  * spawn POIs and portals from data (or bind to hand-placed ones by id),
##  * place the player at the requested spawn,
##  * expose hooks for terrain streaming on large exterior maps.
##
## Hand-placed markers: put Marker3D children named `POI_<poi_id>` or
## `Portal_<portal_id>` in the scene and the data-driven objects will be
## spawned at those transforms. Otherwise positions come from JSON.
class_name MapRoot
extends Node3D

const PLAYER_SCENE := "res://scenes/player.tscn"

var definition: MapDefinition
var pois: Dictionary = {}     ## poi_id -> PointOfInterest
var portals: Dictionary = {}  ## portal_id -> MapPortal

@onready var _poi_container: Node3D = _ensure_child("POIs")
@onready var _portal_container: Node3D = _ensure_child("Portals")
@onready var _world_env: WorldEnvironment = _find_or_create_env()


func setup(def: MapDefinition, poi_defs: Array, spawn_name: String) -> void:
	definition = def
	_apply_environment()
	_spawn_portals()
	_spawn_pois(poi_defs)
	_spawn_player(spawn_name)
	_on_map_setup()


## Override in map-specific scripts (terrain streaming, ambient systems...).
func _on_map_setup() -> void:
	pass


func _apply_environment() -> void:
	if definition.environment_key == "":
		return
	var env := AssetRegistry.load_asset(definition.environment_key)
	if env is Environment:
		_world_env.environment = env


func _spawn_portals() -> void:
	for p in definition.portals:
		var portal := MapPortal.new()
		portal.portal_id = p.get("id", "")
		portal.target_map = p.get("target_map", "")
		portal.requires = p.get("requires", {})
		portal.label = p.get("label", portal.target_map)
		portal.name = "Portal_" + portal.portal_id
		_portal_container.add_child(portal)
		portal.global_transform = _marker_transform("Portal_" + portal.portal_id, p.get("position", null), p.get("yaw", 0.0))
		portals[portal.portal_id] = portal


func _spawn_pois(poi_defs: Array) -> void:
	for pd in poi_defs:
		var poi := PointOfInterest.new()
		poi.definition = pd
		poi.name = "POI_" + pd.id
		_poi_container.add_child(poi)
		poi.global_transform = _marker_transform("POI_" + pd.id, pd.position, pd.yaw)
		poi.build()
		pois[pd.id] = poi


func _spawn_player(spawn_name: String) -> void:
	var existing := get_tree().get_first_node_in_group("player")
	var player: Node3D
	if existing:
		player = existing
	else:
		var scene: PackedScene = load(PLAYER_SCENE)
		player = scene.instantiate()
		get_tree().current_scene.add_child(player)
	var xf := definition.get_spawn(spawn_name)
	player.global_transform = xf
	if player is Actor:
		(player as Actor).velocity = Vector3.ZERO
	EventBus.player_spawned.emit(player)


func _marker_transform(marker_name: String, position, yaw) -> Transform3D:
	var marker := find_child(marker_name, true, false)
	if marker is Node3D:
		return (marker as Node3D).global_transform
	var pos := Vector3.ZERO
	if position is Array and position.size() == 3:
		pos = Vector3(position[0], position[1], position[2])
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(yaw))), pos)


func _ensure_child(child_name: String) -> Node3D:
	var n := get_node_or_null(child_name)
	if n == null:
		n = Node3D.new()
		n.name = child_name
		add_child(n)
	return n


func _find_or_create_env() -> WorldEnvironment:
	for c in get_children():
		if c is WorldEnvironment:
			return c
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	add_child(we)
	return we
