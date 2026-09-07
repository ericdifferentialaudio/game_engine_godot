## Runtime faction (player, AI civ, neutral tribe, monsters). Holds resources,
## diplomacy stances, its own intel journal (via IntelRegistry), stockpile and flags.
##
## factions.json:
## {"factions": [
##   {"id": "player", "display_name": "The Reachfolk", "color": "#3b82f6", "control": "human",
##    "starting_units": ["hero_ambassador", {"unit": "scout", "count": 1}], "start": [5, 5],
##    "resources": {"gold": 60, "food": 0}, "claims_start_territory": true,
##    "stances": {"greywood": "peace", "monsters": "war"}, "default_stance": "peace",
##    "trade_partners": ["greywood"], "ai": {"profile": "expansionist"},
##    "starting_intel": ["met_elders"], "starting_items": {"healing_herb": 2},
##    "turn_order": 0, "tags": ["major"], "metadata": {}}
## ]}
##
## control: human | ai | neutral | hostile   (neutral/hostile never take player-style turns)
class_name Faction
extends RefCounted

const STANCES := ["war", "hostile", "peace", "friendly", "allied"]


class FactionDefinition:
	var id: String = ""
	var display_name: String = ""
	var color: Color = Color.WHITE
	var control: String = "ai"
	var starting_units: Array = []
	var start_coord: Vector2i = Vector2i(-1, -1)
	var resources: Dictionary = {}
	var claims_start_territory: bool = true
	var stances: Dictionary = {}
	var default_stance: String = "peace"
	var trade_partners: PackedStringArray = []
	var ai: Dictionary = {}
	var starting_intel: PackedStringArray = []
	var starting_items: Dictionary = {}
	var turn_order: int = 0
	var tags: PackedStringArray = []
	var metadata: Dictionary = {}

	static func from_dict(d: Dictionary) -> FactionDefinition:
		var f := FactionDefinition.new()
		f.id = d.get("id", "")
		f.display_name = d.get("display_name", f.id.capitalize())
		f.color = Color.html(d.get("color", "#cccccc"))
		f.control = d.get("control", "ai")
		f.starting_units = d.get("starting_units", [])
		var s: Array = d.get("start", [])
		if s.size() == 2:
			f.start_coord = Vector2i(int(s[0]), int(s[1]))
		f.resources = d.get("resources", {})
		f.claims_start_territory = bool(d.get("claims_start_territory", f.control in ["human", "ai"]))
		f.stances = d.get("stances", {})
		f.default_stance = d.get("default_stance", "war" if f.control == "hostile" else "peace")
		f.trade_partners = PackedStringArray(d.get("trade_partners", []))
		f.ai = d.get("ai", {})
		f.starting_intel = PackedStringArray(d.get("starting_intel", []))
		f.starting_items = d.get("starting_items", {})
		f.turn_order = int(d.get("turn_order", 100))
		f.tags = PackedStringArray(d.get("tags", []))
		f.metadata = d.get("metadata", {})
		return f


var definition: FactionDefinition
var id: String = ""
var is_human: bool = false
var color: Color = Color.WHITE
var resources: Dictionary = {}
var stances: Dictionary = {}
var flags: Dictionary = {}
var eliminated: bool = false
var home_coord: Vector2i = Vector2i.ZERO
var stockpile := Inventory.new()
var ai_rng := RandomNumberGenerator.new()


func setup(def: FactionDefinition, seed_val: int) -> void:
	definition = def
	id = def.id
	is_human = def.control == "human"
	color = def.color
	resources = def.resources.duplicate()
	stances = def.stances.duplicate()
	stockpile.owner_id = id
	stockpile.faction_id = id
	stockpile.max_slots = 999
	ai_rng.seed = seed_val + hash(id)
	for cur in GameManager.game_config.get("currencies", []):
		if not resources.has(cur):
			resources[cur] = 0
	for item in def.starting_items:
		stockpile.add_item(item, int(def.starting_items[item]))
	for tok in def.starting_intel:
		IntelRegistry.acquire(id, tok, "scripted", "scripted", 1.0)


func takes_turns() -> bool:
	return definition.control in ["human", "ai"]


# --- Resources ------------------------------------------------------------------------

func get_resource(res: String) -> float:
	return float(resources.get(res, 0.0))


func add_resource(res: String, amount: float) -> void:
	resources[res] = get_resource(res) + amount
	EventBus.faction_resource_changed.emit(id, res, resources[res])


func spend_resource(res: String, amount: float) -> bool:
	if get_resource(res) < amount:
		return false
	add_resource(res, -amount)
	return true


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if get_resource(k) < float(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		add_resource(k, -float(cost[k]))
	return true


## Collect yields from owned tiles and pay unit upkeep (UPKEEP phase).
func collect_yields() -> void:
	var world := WorldManager.world
	if world == null:
		return
	var totals := {}
	for tile in world.tiles.values():
		if tile.owner_id == id:
			var y: Dictionary = tile.yields(world.feature_defs)
			for k in y:
				totals[k] = totals.get(k, 0.0) + float(y[k])
	var currencies: Array = GameManager.game_config.get("currencies", [])
	for k in totals:
		if k in currencies or GameManager.rule("economy.track_all_yields", false):
			add_resource(k, totals[k])
	for u in EntityRegistry.units_of(id):
		for k in u.definition.upkeep:
			add_resource(k, -float(u.definition.upkeep[k]))



# --- Diplomacy ---------------------------------------------------------------------------

func stance_toward(other_id: String) -> String:
	if other_id == id:
		return "allied"
	return stances.get(other_id, definition.default_stance)


func set_stance(other_id: String, stance: String, mutual: bool = true) -> void:
	if stance not in STANCES:
		return
	stances[other_id] = stance
	EventBus.diplomacy_changed.emit(id, other_id, stance)
	if mutual:
		var other := FactionRegistry.get_faction(other_id)
		if other:
			other.set_stance(id, stance, false)


func is_hostile_to(other_id: String) -> bool:
	return stance_toward(other_id) in ["war", "hostile"]


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value


# --- AI -------------------------------------------------------------------------------------

## Faction-level AI: move every unit via its AIController profile. Games override
## strategy by registering a Callable with FactionRegistry.register_faction_ai(profile, fn).
func run_ai_turn() -> void:
	var profile: String = definition.ai.get("profile", "")
	var custom := FactionRegistry.faction_ai_for(profile)
	if custom.is_valid():
		custom.call(self)
		return
	for u in EntityRegistry.units_of(id):
		if u.alive and u.map_id == WorldManager.current_id:
			AIController.act(u, ai_rng)


func on_turn_begin() -> void:
	for u in EntityRegistry.units_of(id):
		u.on_turn_begin()


func check_elimination() -> void:
	if eliminated or not takes_turns():
		return
	if EntityRegistry.units_of(id).is_empty() and GameManager.rule("victory.eliminate_on_no_units", true):
		eliminated = true
		EventBus.faction_eliminated.emit(id)


func to_save_data() -> Dictionary:
	return {
		"resources": resources.duplicate(), "stances": stances.duplicate(), "flags": flags.duplicate(),
		"eliminated": eliminated, "home": [home_coord.x, home_coord.y], "stockpile": stockpile.to_save_data(),
		"rng": ai_rng.state,
	}


func from_save_data(d: Dictionary) -> void:
	resources = d.get("resources", resources)
	stances = d.get("stances", stances)
	flags = d.get("flags", {})
	eliminated = bool(d.get("eliminated", false))
	var h: Array = d.get("home", [0, 0])
	home_coord = Vector2i(int(h[0]), int(h[1]))
	stockpile.from_save_data(d.get("stockpile", {}))
	ai_rng.state = int(d.get("rng", ai_rng.state))
