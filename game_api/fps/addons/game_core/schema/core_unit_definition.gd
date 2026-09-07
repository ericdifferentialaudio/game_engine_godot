## Unified definition for anything alive or agentive: player, NPC, monster,
## hero, town guard, caravan. Merged from the FPS `actors.json` and the
## isometric `units.json`.
##
## Purely data — no Node2D/Node3D. Each graphics engine maps [member visual_key]
## and [member move_speed] onto its own representation (a sprite on a hex tile,
## or a CharacterBody3D with a navmesh agent).
##
## JSON (units.json):
##   {"id": "bone_warden", "display_name": "Bone Warden", "role": "monster",
##    "faction": "undead", "stats": {"health": 20, "strength": 6, "moves": 2},
##    "abilities": ["chill_touch"], "loot": [{"item": "bone_dust", "chance": 0.5}],
##    "ai_profile": "aggressive", "visual": "unit.bone_warden", "tags": ["undead"]}
class_name CoreUnitDefinition
extends CoreDefinition

## Broad behavioural role; games may add their own via tags.
const ROLES := ["player", "hero", "npc", "monster", "animal", "structure", "caravan", "prop"]

@export var role: String = "npc"
@export var faction_id: String = ""
@export var stats: Dictionary = {}            ## stat -> base max (health, strength, moves, sight...)
@export var abilities: PackedStringArray = []
@export var equipment: PackedStringArray = [] ## item ids equipped on spawn
@export var equipment_slots: Dictionary = {}  ## slot -> item_id, when authored as a map
@export var inventory: Dictionary = {}        ## item_id -> count on spawn
@export var loot: Array[Dictionary] = []      ## [{"item": id, "count": 1, "chance": 0.5}]
@export var ai_profile: String = ""
@export var intel_profile: Dictionary = {}    ## {"on_combat": [token_ids], "on_seen": [...]}
@export var dialogue_id: String = ""
@export var level: int = 1
@export var xp_value: int = 0
@export var mobile: bool = true
@export var hostile_by_default: bool = false

# --- Presentation (resolved per graphics engine via CoreAssetRegistry) ----------
@export var visual_key: String = ""           ## iso sprite key / 3D scene key
@export var portrait_key: String = ""
@export var move_speed: float = 1.0           ## iso: tiles per turn; fps: metres/second


func _apply(d: Dictionary) -> void:
	role = str(d.get("role", d.get("kind", "npc")))
	faction_id = str(d.get("faction", d.get("faction_id", "")))
	stats = d.get("stats", {})
	abilities = CoreDataLoader.packed_str_array(d.get("abilities", []))
	# May be authored as a list of item ids or as a slot -> item_id map.
	equipment = CoreDataLoader.packed_str_array(d.get("equipment", []))
	equipment_slots = d.get("equipment", {}) if d.get("equipment") is Dictionary else {}
	inventory = d.get("inventory", {})
	loot = CoreDataLoader.dict_array(d.get("loot", []))
	ai_profile = str(d.get("ai_profile", ""))
	intel_profile = d.get("intel_profile", {})
	dialogue_id = str(d.get("dialogue", d.get("dialogue_id", "")))
	level = int(d.get("level", 1))
	xp_value = int(d.get("xp_value", 0))
	mobile = bool(d.get("mobile", role != "structure" and role != "prop"))
	hostile_by_default = bool(d.get("hostile", false))
	visual_key = str(d.get("visual", "unit.%s" % id))
	portrait_key = str(d.get("portrait", "portrait.%s" % id))
	move_speed = float(d.get("move_speed", float(stats.get("moves", 1.0))))


func is_hero() -> bool:
	return role in ["player", "hero"]


func is_mobile() -> bool:
	return mobile


func base_stat(stat: String, fallback: float = 0.0) -> float:
	return float(stats.get(stat, fallback))


## Roll this unit's loot table with the supplied RNG. Returns item_id -> count.
func roll_loot(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for entry in loot:
		if rng.randf() <= float(entry.get("chance", 1.0)):
			var item_id := str(entry.get("item", ""))
			if item_id != "":
				out[item_id] = out.get(item_id, 0) + int(entry.get("count", 1))
	return out
