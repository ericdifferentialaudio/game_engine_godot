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
var actors: Dictionary = {}   ## spawn key -> Actor

@onready var _poi_container: Node3D = _ensure_child("POIs")
@onready var _portal_container: Node3D = _ensure_child("Portals")
@onready var _actor_container: Node3D = _ensure_child("Actors")
@onready var _world_env: WorldEnvironment = _find_or_create_env()


func setup(def: MapDefinition, poi_defs: Array, spawn_name: String) -> void:
	definition = def
	_apply_environment()
	_spawn_portals()
	_spawn_pois(poi_defs)
	_spawn_player(spawn_name)
	_spawn_actors()
	_restore_loot()
	_on_map_setup()


# --- Actors ------------------------------------------------------------------

## Spawn actors declared in maps.json spawn_tables:
##   {"actor": "troll", "key": "troll", "position": [x,y,z], "yaw": 0,
##    "unless_flag": "troll_dead", "requires": <IntelQuery>}
## A Marker3D named Spawn_<key> overrides the position. Actors recorded as
## killed in this map's state are not respawned.
func _spawn_actors() -> void:
	var st := MapManager.get_map_state(definition.id)
	var killed: Array = st.get("killed", [])
	for i in definition.spawn_tables.size():
		var entry: Dictionary = definition.spawn_tables[i]
		var actor_id := str(entry.get("actor", ""))
		var key := str(entry.get("key", "%s_%d" % [actor_id, i]))
		if actor_id == "" or key in killed:
			continue
		if entry.get("unless_flag", "") != "" and GameManager.has_flag(str(entry["unless_flag"])):
			continue
		if entry.get("flag", "") != "" and not GameManager.has_flag(str(entry["flag"])):
			continue
		var req: Dictionary = entry.get("requires", {})
		if not req.is_empty() and not IntelRegistry.evaluate(req):
			continue
		var count := int(entry.get("count", 1))
		for n in count:
			spawn_actor(actor_id, key if count == 1 else "%s_%d" % [key, n],
				_marker_transform("Spawn_" + key, entry.get("position", null), entry.get("yaw", 0.0)))


func spawn_actor(actor_id: String, key: String, xf: Transform3D) -> Actor:
	var def := DefinitionRegistry.get_def("actors", actor_id) as ActorDefinition
	if def == null:
		return null
	var body := Actor.new()
	body.name = "Actor_" + key
	body.actor_def_id = actor_id
	body.spawned_by_map = definition.id
	body.spawn_key = key
	body.collision_layer = 1 << 4   # NPC
	body.collision_mask = 1         # World
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(def.size.get("radius", 0.4))
	capsule.height = float(def.size.get("height", 1.9))
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	body.add_child(shape)
	var brain: Brain = AIBrain.new() if def.brain == "ai" else Brain.new()
	brain.name = "Brain"
	body.add_child(brain)
	body.add_child(AssetRegistry.instance_scene(def.visual_key))
	_actor_container.add_child(body)
	body.global_transform = xf
	var talk_specs: Array = def.raw.get("interactions", [])
	if not talk_specs.is_empty():
		var talk := ActorTalk.new()
		talk.name = "ActorTalk"
		body.add_child(talk)
		talk.setup(body, talk_specs)
	actors[key] = body
	return body


# --- Loot on the floor -------------------------------------------------------

func register_loot(pickup: WorldPickup, key: String, items: Dictionary) -> void:
	var st := MapManager.get_map_state(definition.id)
	if not st.has("loot"):
		st["loot"] = {}
	var p := pickup.global_position
	st["loot"][pickup.name] = {"items": items.duplicate(), "label": pickup.label,
		"position": [p.x, p.y, p.z], "key": key}


func unregister_loot(pickup: WorldPickup) -> void:
	var st := MapManager.get_map_state(definition.id)
	if st.has("loot"):
		st["loot"].erase(pickup.name)


func _restore_loot() -> void:
	var st := MapManager.get_map_state(definition.id)
	for pname in st.get("loot", {}):
		var d: Dictionary = st["loot"][pname]
		var pickup := WorldPickup.new()
		pickup.name = pname
		pickup.items = d.get("items", {}).duplicate()
		pickup.label = d.get("label", "some items")
		_actor_container.add_child(pickup)
		var pos: Array = d.get("position", [0, 0, 0])
		pickup.global_position = Vector3(pos[0], pos[1], pos[2])


## Is the room lit? Dark rooms need the player to carry an item listed in
## game.json "light_sources" (e.g. a lit lantern) or a light flag to be set.
func is_lit() -> bool:
	if not definition.dark:
		return true
	var cfg: Dictionary = GameManager.game_config
	if cfg.get("light_flag", "") != "" and GameManager.has_flag(str(cfg["light_flag"])):
		return true
	var player := GameManager.player
	var inv := Shop.inventory_of(player) if player else null
	if inv:
		for item_id in cfg.get("light_sources", []):
			if inv.has_item(str(item_id)):
				return true
	return false


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
		portal.locked_message = str(p.get("locked_message", portal.locked_message))
		portal.blocked_by_actor = str(p.get("blocked_by", ""))
		portal.blocked_message = str(p.get("blocked_message", ""))
		portal.travel_text = str(p.get("travel_text", ""))
		portal.visual_key = str(p.get("visual", "portal.default"))
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
