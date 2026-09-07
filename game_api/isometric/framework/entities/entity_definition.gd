## Static description of anything that can stand on a tile (units.json).
##
## kinds:
##   hero     – persistent main character: levels, equipment slots, persists across maps
##   unit     – Civ-style military/civilian unit (scout, warrior, settler, worker)
##   npc      – dialogue / trade / schedule; an intel source; usually neutral faction
##   monster  – hostile wandering/guarding entity with loot & spawn tables
##   structure– immobile tile occupant (city centre, outpost, camp) that can be "owned"
##
## {"units": [
##   {"id": "scout", "display_name": "Scout", "kind": "unit", "visual": "unit.scout",
##    "portrait": "portrait.scout", "stats": {"health": 10, "strength": 5, "moves": 3, "sight": 3},
##    "movement": {"domain": "land", "terrain_costs": {"hills": 1}, "uses_roads": true},
##    "abilities": ["scout_report"], "equipment_slots": [], "tags": ["recon"],
##    "cost": {"production": 30}, "upkeep": {"gold": 1},
##    "ai_profile": "explorer", "aggression": 0.2,
##    "loot": [{"item": "hide", "chance": 0.5}], "xp_value": 5,
##    "intel_profile": {"on_sight": ["scout_seen"], "carries": ["patrol_routes"], "leak_chance": 0.1},
##    "dialogue": {...}, "schedule": [{"turn_mod": 10, "coord": [3,4]}],
##    "level_curve": {"base_xp": 20, "growth": 1.5, "per_level": {"health": 2, "strength": 1}},
##    "metadata": {}}
## ]}
class_name EntityDefinition
extends Resource

const KINDS := ["hero", "unit", "npc", "monster", "structure"]

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: String = "unit"
@export var visual_key: String = ""
@export var portrait_key: String = ""
@export var stats: Dictionary = {}          ## stat -> max/start value (health, strength, moves, sight, ...)
@export var movement: Dictionary = {}
@export var abilities: PackedStringArray = []
@export var equipment_slots: PackedStringArray = []
@export var tags: PackedStringArray = []
@export var cost: Dictionary = {}
@export var upkeep: Dictionary = {}
@export var ai_profile: String = ""
@export var aggression: float = 0.0
@export var loot: Array[Dictionary] = []
@export var xp_value: int = 0
@export var intel_profile: Dictionary = {}  ## {on_sight: [...], carries: [...], on_defeat: [...], leak_chance}
@export var dialogue: Dictionary = {}       ## DialogueInteraction spec (npc/hero)
@export var shop: Dictionary = {}           ## ShopInteraction spec
@export var schedule: Array[Dictionary] = []
@export var level_curve: Dictionary = {}
@export var starting_items: Array = []
@export var can_capture: bool = false
@export var blocks_tile: bool = true
@export var metadata: Dictionary = {}


static func from_dict(d: Dictionary) -> EntityDefinition:
	var e := EntityDefinition.new()
	e.id = d.get("id", "")
	e.display_name = d.get("display_name", e.id.capitalize())
	e.description = d.get("description", "")
	e.kind = d.get("kind", "unit")
	if e.kind not in KINDS:
		push_warning("EntityDefinition '%s': unknown kind '%s'" % [e.id, e.kind])
	e.visual_key = d.get("visual", "unit.%s" % e.id)
	e.portrait_key = d.get("portrait", "portrait.%s" % e.id)
	e.stats = d.get("stats", {})
	e.movement = d.get("movement", {"domain": "land"})
	e.abilities = PackedStringArray(d.get("abilities", []))
	e.equipment_slots = PackedStringArray(d.get("equipment_slots", []))
	e.tags = PackedStringArray(d.get("tags", []))
	e.cost = d.get("cost", {})
	e.upkeep = d.get("upkeep", {})
	e.ai_profile = d.get("ai_profile", "")
	e.aggression = float(d.get("aggression", 0.0))
	e.loot.assign(d.get("loot", []))
	e.xp_value = int(d.get("xp_value", 0))
	e.intel_profile = d.get("intel_profile", {})
	e.dialogue = d.get("dialogue", {})
	e.shop = d.get("shop", {})
	e.schedule.assign(d.get("schedule", []))
	e.level_curve = d.get("level_curve", {})
	e.starting_items = d.get("starting_items", [])
	e.can_capture = bool(d.get("can_capture", false))
	e.blocks_tile = bool(d.get("blocks_tile", e.kind != "npc"))
	e.metadata = d.get("metadata", {})
	return e


func is_mobile() -> bool:
	return kind != "structure" and float(stats.get("moves", 0)) > 0.0


func is_hostile_by_default() -> bool:
	return kind == "monster"
