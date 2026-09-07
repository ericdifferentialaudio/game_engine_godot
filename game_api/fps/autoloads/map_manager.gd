## Owns the map hierarchy: loading/unloading map scenes, the recursive submap
## stack (with a hard depth limit), portal traversal, and per-map persisted state.
##
## Hierarchy model
## ---------------
##   overworld (depth 0)
##     ├── town        (depth 1)
##     │     └── shop interior (depth 2)
##     └── dungeon     (depth 1)
##           └── dungeon level 2 (depth 2)
##                 └── ... up to max_depth
##
## Maps are described by MapDefinition resources (built from maps.json). Entering
## a child map pushes onto [member _stack]; returning pops. Each map's runtime
## state (opened chests, discovered POIs, etc.) is kept in [member map_states]
## keyed by map id so it survives unload/reload and is serialisable by SaveManager.
extends Node

const DEFAULT_MAX_DEPTH := 4

var max_depth: int = DEFAULT_MAX_DEPTH
var definitions: Dictionary = {}     ## map_id -> MapDefinition
var poi_definitions: Dictionary = {} ## poi_id -> PoiDefinition
var map_states: Dictionary = {}      ## map_id -> Dictionary (persisted)

var current_map: Node3D = null
var current_id: String = ""

var _stack: Array[String] = []       ## Ancestor chain, root first (excludes current).
var _pending_spawn: String = "default"
var _world_root: Node3D = null


func _ready() -> void:
	EventBus.poi_discovered.connect(_on_poi_discovered)


func set_world_root(root: Node3D) -> void:
	_world_root = root


# --- Definitions -------------------------------------------------------------

## Pull map & POI definitions from DefinitionRegistry (call after load_package).
func load_definitions() -> void:
	definitions.clear()
	poi_definitions.clear()
	for def in DefinitionRegistry.all("maps"):
		def.poi_ids.clear()
		definitions[def.id] = def
	for poi in DefinitionRegistry.all("pois"):
		poi_definitions[poi.id] = poi
		if definitions.has(poi.map_id):
			definitions[poi.map_id].poi_ids.append(poi.id)
	_validate_hierarchy()


## Register a runtime-generated map (procedural sublevels). Respects max_depth.
func add_runtime_map(def: MapDefinition) -> bool:
	if def.parent_id != "" and depth_of(def.parent_id) + 1 > max_depth:
		push_warning("MapManager: cannot add '%s'; would exceed max_depth" % def.id)
		return false
	definitions[def.id] = def
	DefinitionRegistry.add("maps", def)
	return true


func get_definition(map_id: String) -> MapDefinition:
	return definitions.get(map_id)


func get_poi_definition(poi_id: String) -> PoiDefinition:
	return poi_definitions.get(poi_id)


func get_pois_for_map(map_id: String) -> Array[PoiDefinition]:
	var out: Array[PoiDefinition] = []
	var def: MapDefinition = definitions.get(map_id)
	if def:
		for pid in def.poi_ids:
			out.append(poi_definitions[pid])
	return out


## Depth of a map in the static hierarchy (root = 0).
func depth_of(map_id: String) -> int:
	var depth := 0
	var def: MapDefinition = definitions.get(map_id)
	while def and def.parent_id != "":
		depth += 1
		def = definitions.get(def.parent_id)
		if depth > 64:
			push_error("MapManager: cycle detected in map hierarchy near '%s'" % map_id)
			break
	return depth


func _validate_hierarchy() -> void:
	for id in definitions:
		var def: MapDefinition = definitions[id]
		if def.parent_id != "" and not definitions.has(def.parent_id):
			push_error("MapManager: map '%s' references unknown parent '%s'" % [id, def.parent_id])
		var d := depth_of(id)
		if d > max_depth:
			push_error("MapManager: map '%s' is at depth %d, exceeding max_depth %d" % [id, d, max_depth])
		for portal in def.portals:
			if not definitions.has(portal.get("target_map", "")):
				push_error("MapManager: portal '%s' in '%s' targets unknown map" % [portal.get("id"), id])


# --- Runtime traversal -------------------------------------------------------

func current_depth() -> int:
	return _stack.size()


func enter_root_map(map_id: String, spawn: String = "default") -> void:
	_stack.clear()
	_load_map(map_id, spawn)


## Traverse a portal defined on the current map.
func traverse_portal(portal_id: String) -> void:
	var def: MapDefinition = definitions.get(current_id)
	if def == null:
		return
	var portal := def.get_portal(portal_id)
	if portal.is_empty():
		push_error("MapManager: unknown portal '%s' on '%s'" % [portal_id, current_id])
		return
	var target: String = portal["target_map"]
	var spawn: String = portal.get("target_spawn", "default")
	var target_def: MapDefinition = definitions.get(target)
	if target_def == null:
		return

	if target_def.parent_id == current_id:
		descend(target, spawn)
	elif def.parent_id == target:
		ascend(spawn)
	else:
		# Lateral / teleport: rebuild stack from static hierarchy.
		var chain: Array[String] = []
		var d: MapDefinition = target_def
		while d and d.parent_id != "":
			chain.push_front(d.parent_id)
			d = definitions.get(d.parent_id)
		_stack = chain
		EventBus.map_transition.emit(current_id, target, portal_id)
		_load_map(target, spawn)


func descend(child_id: String, spawn: String = "default") -> void:
	if _stack.size() + 1 > max_depth:
		push_warning("MapManager: cannot descend into '%s'; max depth %d reached" % [child_id, max_depth])
		EventBus.notification.emit("You cannot go any deeper.", "warning")
		return
	var from := current_id
	_stack.append(current_id)
	EventBus.map_transition.emit(from, child_id, "")
	_load_map(child_id, spawn)


func ascend(spawn: String = "return") -> void:
	if _stack.is_empty():
		push_warning("MapManager: already at root map")
		return
	var from := current_id
	var parent: String = _stack.pop_back()
	EventBus.map_transition.emit(from, parent, "")
	_load_map(parent, spawn)


# --- Per-map persisted state -------------------------------------------------

func get_map_state(map_id: String) -> Dictionary:
	if not map_states.has(map_id):
		map_states[map_id] = {"discovered_pois": [], "flags": {}, "visits": 0}
	return map_states[map_id]


func _on_poi_discovered(poi_id: String, map_id: String) -> void:
	var st := get_map_state(map_id)
	if not st["discovered_pois"].has(poi_id):
		st["discovered_pois"].append(poi_id)


# --- Loading -----------------------------------------------------------------

func _load_map(map_id: String, spawn: String) -> void:
	var def: MapDefinition = definitions.get(map_id)
	if def == null:
		push_error("MapManager: unknown map '%s'" % map_id)
		return
	if _world_root == null:
		push_error("MapManager: world root not set; call set_world_root() from the main scene")
		return

	if current_map:
		EventBus.map_unloading.emit(current_id)
		current_map.queue_free()
		current_map = null

	_pending_spawn = spawn
	current_id = map_id
	var scene: PackedScene = null
	if ResourceLoader.exists(def.scene_path):
		scene = load(def.scene_path)
	if scene == null:
		push_warning("MapManager: scene '%s' missing for map '%s'; using placeholder" % [def.scene_path, map_id])
		scene = load("res://framework/map/placeholder_map.tscn")
	current_map = scene.instantiate()
	_world_root.add_child(current_map)
	if current_map.has_method("setup"):
		current_map.setup(def, get_pois_for_map(map_id), spawn)
	get_map_state(map_id)["visits"] += 1
	EventBus.map_loaded.emit(map_id, current_depth())


# --- Serialisation -----------------------------------------------------------

func to_save_data() -> Dictionary:
	return {"current": current_id, "stack": _stack.duplicate(), "states": map_states.duplicate(true)}


func from_save_data(data: Dictionary) -> void:
	map_states = data.get("states", {})
	_stack.assign(data.get("stack", []))
	var target: String = data.get("current", "")
	if target != "":
		_load_map(target, "return")
