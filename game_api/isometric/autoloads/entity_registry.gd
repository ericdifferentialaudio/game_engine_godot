## Owns entity definitions (units.json), the ability catalog and AI profiles
## (ai_profiles.json), and every live Unit in the game across all maps.
extends Node

var definitions: Dictionary = {}   ## def_id -> EntityDefinition
var units: Dictionary = {}         ## unit_id -> Unit
var selected_unit_id: String = ""

var _next_serial: int = 1
var _container: Node2D = null


func _ready() -> void:
	EventBus.turn_phase_changed.connect(_on_turn_phase)


func load_definitions(units_path: String, ai_path: String = "") -> void:
	definitions.clear()
	var doc := DataLoader.load_json(units_path)
	for entry in doc.get("units", []):
		var def := EntityDefinition.from_dict(entry)
		definitions[def.id] = def
	AbilitySet.catalog = doc.get("abilities", {})
	if ai_path != "" and FileAccess.file_exists(ai_path):
		var ai := DataLoader.load_json(ai_path)
		AIController.profiles = ai.get("profiles", {})
		AbilitySet.catalog.merge(ai.get("abilities", {}), true)
	else:
		AIController.profiles = {}


func reset() -> void:
	for u in units.values():
		u.queue_free()
	units.clear()
	selected_unit_id = ""
	_next_serial = 1


func get_definition(def_id: String) -> EntityDefinition:
	return definitions.get(def_id)


func _ensure_container() -> Node2D:
	if _container == null or not is_instance_valid(_container):
		_container = Node2D.new()
		_container.name = "Units"
		_container.y_sort_enabled = true
		_container.z_index = 4
		if WorldManager.renderer:
			WorldManager.renderer.add_child(_container)
		else:
			add_child(_container)
	return _container


## Spawn a unit of [param def_id] for [param faction_id] at [param coord].
func spawn(def_id: String, faction_id: String, coord: Vector2i, map_id: String = "", forced_id: String = "") -> Unit:
	var def: EntityDefinition = definitions.get(def_id)
	if def == null:
		push_error("EntityRegistry: unknown unit definition '%s'" % def_id)
		return null
	if map_id == "":
		map_id = WorldManager.current_id
	var uid := forced_id if forced_id != "" else "%s_%d" % [def_id, _next_serial]
	_next_serial += 1
	var unit := Unit.new()
	_ensure_container().add_child(unit)
	unit.setup(uid, def, faction_id, map_id, coord)
	units[uid] = unit
	if WorldManager.world and map_id == WorldManager.current_id:
		WorldManager.world.place_unit(unit, coord)
	unit.teleport(coord, map_id)
	EventBus.unit_spawned.emit(uid, faction_id, coord)
	return unit


func remove_unit(unit_id: String) -> void:
	var u: Unit = units.get(unit_id)
	if u == null:
		return
	if WorldManager.world and u.map_id == WorldManager.current_id:
		WorldManager.world.remove_unit(u)
	units.erase(unit_id)
	if selected_unit_id == unit_id:
		deselect()
	u.queue_free()
	EventBus.unit_removed.emit(unit_id)


func get_unit(unit_id: String) -> Unit:
	return units.get(unit_id)


func units_of(faction_id: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units.values():
		if u.faction_id == faction_id and u.alive:
			out.append(u)
	return out


func units_on_map(map_id: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units.values():
		if u.map_id == map_id and u.alive:
			out.append(u)
	return out


func count_units(faction_id: String, def_id: String = "") -> int:
	var n := 0
	for u in units_of(faction_id):
		if def_id == "" or u.definition.id == def_id:
			n += 1
	return n


func heroes_of(faction_id: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units_of(faction_id):
		if u.is_hero():
			out.append(u)
	return out


## Re-attach units to the world model when a map becomes current.
func on_map_entered(map_id: String) -> void:
	var world := WorldManager.world
	for u in units.values():
		if u.map_id == map_id and world:
			world.place_unit(u, u.coord)
		u.teleport(u.coord)
	if _container and WorldManager.renderer and _container.get_parent() != WorldManager.renderer:
		_container.reparent(WorldManager.renderer)


## Move a unit (typically a hero party) into a sub-map.
func transfer_unit(unit_id: String, map_id: String, coord: Vector2i) -> void:
	var u := get_unit(unit_id)
	if u == null:
		return
	if WorldManager.world and u.map_id == WorldManager.current_id:
		WorldManager.world.remove_unit(u)
	u.teleport(coord, map_id)



# --- Selection (player) ----------------------------------------------------------------

func select(unit_id: String) -> void:
	if selected_unit_id == unit_id:
		return
	deselect()
	if units.has(unit_id):
		selected_unit_id = unit_id
		EventBus.unit_selected.emit(unit_id)


func deselect() -> void:
	if selected_unit_id != "":
		var prev := selected_unit_id
		selected_unit_id = ""
		EventBus.unit_deselected.emit(prev)


func selected() -> Unit:
	return units.get(selected_unit_id)


## Cycle to the next player unit that still has action points.
func select_next_idle(faction_id: String) -> Unit:
	var list := units_of(faction_id)
	if list.is_empty():
		return null
	var start := 0
	for i in list.size():
		if list[i].unit_id == selected_unit_id:
			start = i + 1
			break
	for k in list.size():
		var u := list[(start + k) % list.size()]
		if u.action_points > 0.0 and u.definition.is_mobile():
			select(u.unit_id)
			return u
	return null


## Non-turn-taking factions (monsters, neutrals) act at RESOLVE; their units refresh at BEGIN.
func _on_turn_phase(_turn: int, phase: int) -> void:
	if phase == TurnManager.Phase.BEGIN:
		for f in FactionRegistry.factions.values():
			if not f.takes_turns():
				f.on_turn_begin()
	elif phase == TurnManager.Phase.RESOLVE:
		for u in units.values():
			var f := FactionRegistry.get_faction(u.faction_id)
			if u.alive and f and not f.takes_turns() and u.map_id == WorldManager.current_id:
				AIController.act(u, f.ai_rng)


# --- Serialisation --------------------------------------------------------------------

func to_save_data() -> Dictionary:
	var out := {"serial": _next_serial, "selected": selected_unit_id, "units": {}}
	for uid in units:
		out["units"][uid] = units[uid].to_save_data()
	return out


func from_save_data(d: Dictionary) -> void:
	reset()
	for uid in d.get("units", {}):
		var ud: Dictionary = d["units"][uid]
		var c: Array = ud.get("coord", [0, 0])
		var u := spawn(ud.get("def", ""), ud.get("faction", ""), Vector2i(int(c[0]), int(c[1])), ud.get("map", ""), uid)
		if u:
			u.from_save_data(ud)
	_next_serial = int(d.get("serial", _next_serial))
	selected_unit_id = d.get("selected", "")
