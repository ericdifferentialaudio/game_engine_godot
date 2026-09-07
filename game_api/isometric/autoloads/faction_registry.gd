## Owns faction definitions and live Faction instances; answers relationship
## questions (hostility, alliances, trade partners) for combat, fog and intel spread.
extends Node

var definitions: Dictionary = {}   ## faction_id -> Faction.FactionDefinition
var factions: Dictionary = {}      ## faction_id -> Faction

static var _faction_ai: Dictionary = {}   ## profile -> Callable(faction)


func _ready() -> void:
	EventBus.turn_phase_changed.connect(_on_turn_phase)
	EventBus.active_faction_changed.connect(_on_active_faction)
	EventBus.unit_removed.connect(func(_u): for f in factions.values(): f.check_elimination())


func load_definitions(path: String) -> void:
	definitions.clear()
	for entry in DataLoader.load_json_array(path, "factions"):
		var def := Faction.FactionDefinition.from_dict(entry)
		definitions[def.id] = def


func reset() -> void:
	factions.clear()


func instantiate_all() -> void:
	factions.clear()
	for id in definitions:
		var f := Faction.new()
		f.setup(definitions[id], WorldManager.seed_value)
		factions[id] = f


static func register_faction_ai(profile: String, fn: Callable) -> void:
	_faction_ai[profile] = fn


static func faction_ai_for(profile: String) -> Callable:
	return _faction_ai.get(profile, Callable())


func get_faction(id: String) -> Faction:
	return factions.get(id)


func player() -> Faction:
	return factions.get(GameManager.player_faction_id)


func faction_ids() -> Array[String]:
	var out: Array[String] = []
	for id in factions:
		out.append(id)
	return out


## Factions that take turns, ordered by turn_order then id.
func turn_order() -> Array[String]:
	var list: Array[String] = []
	for id in factions:
		if factions[id].takes_turns():
			list.append(id)
	list.sort_custom(func(a, b):
		var da: Faction.FactionDefinition = definitions[a]
		var db: Faction.FactionDefinition = definitions[b]
		return da.turn_order < db.turn_order if da.turn_order != db.turn_order else a < b)
	return list


func are_hostile(a: String, b: String) -> bool:
	if a == b or a == "" or b == "":
		return false
	var fa := get_faction(a)
	var fb := get_faction(b)
	if fa == null or fb == null:
		return false
	return fa.is_hostile_to(b) or fb.is_hostile_to(a)


## Relationship filters used by intel spread rules and shared vision.
func relationship_matches(a: String, b: String, filter: String) -> bool:
	var fa := get_faction(a)
	if fa == null or a == b:
		return false
	match filter:
		"all":
			return true
		"allies":
			return fa.stance_toward(b) == "allied"
		"friendly":
			return fa.stance_toward(b) in ["friendly", "allied"]
		"peaceful":
			return not are_hostile(a, b)
		"enemies":
			return are_hostile(a, b)
		"trade_partners":
			return b in fa.definition.trade_partners
		"neighbors":
			return _share_border(a, b)
	return false


func _share_border(a: String, b: String) -> bool:
	var world := WorldManager.world
	if world == null:
		return false
	for tile in world.tiles.values():
		if tile.owner_id != a:
			continue
		for n in world.topology.neighbors(tile.coord):
			if world.owner_of(n) == b:
				return true
	return false


func _on_turn_phase(_turn: int, phase: int) -> void:
	if phase == TurnManager.Phase.UPKEEP:
		for f in factions.values():
			f.collect_yields()
			if TurnManager.mode != TurnManager.Mode.SEQUENTIAL:
				f.on_turn_begin()
	elif phase == TurnManager.Phase.END:
		_check_victory()


func _on_active_faction(faction_id: String) -> void:
	var f := get_faction(faction_id)
	if f:
		f.on_turn_begin()


func _check_victory() -> void:
	if not GameManager.rule("victory.last_faction_standing", true):
		return
	var alive: Array[String] = []
	for id in factions:
		var f: Faction = factions[id]
		if f.takes_turns() and not f.eliminated:
			alive.append(id)
	if alive.size() == 1 and factions.size() > 1 and turn_order().size() > 1:
		GameManager.end_game(alive[0], "last_faction_standing")


func to_save_data() -> Dictionary:
	var out := {}
	for id in factions:
		out[id] = factions[id].to_save_data()
	return out


func from_save_data(d: Dictionary) -> void:
	instantiate_all()
	for id in d:
		if factions.has(id):
			factions[id].from_save_data(d[id])
