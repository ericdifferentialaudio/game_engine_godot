## Static description of a Site — a point of interest that lives on a tile (sites.json).
## Villages, ruins, shrines, dungeon entrances, resource nodes, encounter markers, cities.
##
## {"sites": [
##   {"id": "hollowmere", "map": "overworld", "display_name": "Hollowmere", "category": "village",
##    "coord": [7, 6] | "placement": "random_land", "visual": "site.village", "owner": "greywood",
##    "hidden_until": {"has": "rumor_hollowmere"},          IntelQuery (per visiting faction)
##    "discover_intel": ["seen_hollowmere"],                tokens granted on first sight/entry
##    "enter_requires": {"has": "..."},                     gate for interactions
##    "interactions": [ {kind: intel|reward|shop|dialogue|portal|spawn|combat|flag ...} ],
##    "spawns": [{"unit": "wolf", "faction": "monsters", "count": 2, "radius": 1, "respawn_turns": 10}],
##    "yields": {"gold": 1}, "defense_bonus": 25, "sight": 2,
##    "tags": ["settlement"], "metadata": {}}
## ]}
class_name SiteDefinition
extends Resource

@export var id: String = ""
@export var map_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = "generic"    ## village | city | ruins | shrine | dungeon | camp | resource | encounter | generic
@export var coord: Vector2i = Vector2i(-1, -1)
@export var placement: String = "fixed"     ## fixed | random_land
@export var visual_key: String = ""
@export var owner_id: String = ""
@export var hidden_until: Dictionary = {}
@export var discover_intel: PackedStringArray = []
@export var enter_requires: Dictionary = {}
@export var interactions: Array[Dictionary] = []
@export var spawns: Array[Dictionary] = []
@export var yields: Dictionary = {}
@export var defense_bonus: float = 0.0
@export var sight: int = 2
@export var capturable: bool = false
@export var tags: PackedStringArray = []
@export var metadata: Dictionary = {}


static func from_dict(d: Dictionary) -> SiteDefinition:
	var s := SiteDefinition.new()
	s.id = d.get("id", "")
	s.map_id = d.get("map", "")
	s.display_name = d.get("display_name", s.id.capitalize())
	s.description = d.get("description", "")
	s.category = d.get("category", "generic")
	var c: Array = d.get("coord", [])
	if c.size() == 2:
		s.coord = Vector2i(int(c[0]), int(c[1]))
	s.placement = d.get("placement", "fixed" if c.size() == 2 else "random_land")
	s.visual_key = d.get("visual", "site.%s" % s.category)
	s.owner_id = d.get("owner", "")
	s.hidden_until = d.get("hidden_until", {})
	s.discover_intel = PackedStringArray(d.get("discover_intel", []))
	s.enter_requires = d.get("enter_requires", {})
	s.interactions.assign(d.get("interactions", []))
	s.spawns.assign(d.get("spawns", []))
	s.yields = d.get("yields", {})
	s.defense_bonus = float(d.get("defense_bonus", 0.0))
	s.sight = int(d.get("sight", 2))
	s.capturable = bool(d.get("capturable", s.category in ["city", "village", "camp"]))
	s.tags = PackedStringArray(d.get("tags", []))
	s.metadata = d.get("metadata", {})
	return s
