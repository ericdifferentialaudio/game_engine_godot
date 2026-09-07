## A faction / allegiance group, shared by both graphics engines.
##
## In the isometric engine a faction is a playable or AI empire that takes
## turns; in the FPS engine it is an allegiance the player builds reputation
## with. Both use the same definition and the same hostility rules.
##
## JSON (factions.json):
##   {"id": "crown", "display_name": "The Crown", "color": [0.8, 0.1, 0.1],
##    "starting_reputation": 0, "hostile_to": ["undead"], "allied_to": ["merchants"],
##    "playable": true, "resources": {"gold": 100}, "ai_profile": "expansionist"}
class_name CoreFactionDefinition
extends CoreDefinition

const STANCES := ["allied", "friendly", "neutral", "wary", "hostile", "war"]

@export var color: Color = Color.WHITE
@export var starting_reputation: int = 0
@export var hostile_to: PackedStringArray = []
@export var allied_to: PackedStringArray = []
@export var default_stance: String = "neutral"
@export var playable: bool = false
@export var takes_turns: bool = true          ## false = ambient (monsters, wildlife)
@export var resources: Dictionary = {}        ## resource_id -> starting amount
@export var ai_profile: String = ""
@export var starting_intel: PackedStringArray = []
@export var banner_key: String = ""


func _apply(d: Dictionary) -> void:
	var c = d.get("color", null)
	if c is Array and c.size() >= 3:
		color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0)
	elif c is String:
		color = Color(c)
	starting_reputation = int(d.get("starting_reputation", 0))
	hostile_to = CoreDataLoader.packed_str_array(d.get("hostile_to", []))
	allied_to = CoreDataLoader.packed_str_array(d.get("allied_to", []))
	default_stance = str(d.get("default_stance", "neutral"))
	playable = bool(d.get("playable", false))
	takes_turns = bool(d.get("takes_turns", true))
	resources = d.get("resources", {})
	ai_profile = str(d.get("ai_profile", ""))
	starting_intel = CoreDataLoader.packed_str_array(d.get("starting_intel", []))
	banner_key = str(d.get("banner", "banner.%s" % id))


## Static stance declared in data (runtime diplomacy may override it).
func stance_toward(other_id: String) -> String:
	if other_id == id:
		return "allied"
	if other_id in hostile_to:
		return "hostile"
	if other_id in allied_to:
		return "allied"
	return default_stance


func is_hostile_to(other_id: String) -> bool:
	return stance_toward(other_id) in ["hostile", "war"]
