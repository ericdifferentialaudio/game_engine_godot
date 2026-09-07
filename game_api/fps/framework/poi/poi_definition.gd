## Static description of a Point of Interest (from pois.json).
##
## A POI is "something worth visiting" on a map. What happens when you interact
## is defined by an ordered list of [member interactions], each handled by an
## Interaction strategy (see framework/poi/interactions/). Examples:
##   shop     – opens a shop inventory
##   intel    – grants intel tokens (optionally gated / one-shot)
##   reward   – grants items/currency/flags
##   dialogue – runs a dialogue tree that may itself grant intel
##   portal   – shortcut to MapManager.traverse_portal
class_name PoiDefinition
extends Definition

@export var map_id: String = ""
@export var category: String = "generic"   ## shop | informant | landmark | cache | shrine | npc ...
@export var visual_key: String = ""        ## AssetRegistry scene key
@export var position: Array = [0, 0, 0]
@export var yaw: float = 0.0
@export var discover_radius: float = 12.0  ## Auto-discover when player enters.
@export var interact_radius: float = 3.0
@export var hidden_until: Dictionary = {}  ## IntelQuery; POI invisible until satisfied.
@export var interactions: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> PoiDefinition:
	return Definition.build(PoiDefinition, d) as PoiDefinition


func _apply(d: Dictionary) -> void:
	map_id = d.get("map", "")
	category = d.get("category", "generic")
	visual_key = d.get("visual", "poi.%s" % category)
	position = d.get("position", [0, 0, 0])
	yaw = float(d.get("yaw", 0.0))
	discover_radius = float(d.get("discover_radius", 12.0))
	interact_radius = float(d.get("interact_radius", 3.0))
	hidden_until = d.get("hidden_until", {})
	interactions = Definition._dict_array(d.get("interactions", []))
