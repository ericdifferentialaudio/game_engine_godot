## Static description of a terrain type or tile feature (terrains.json).
##
## {"terrains": [
##    {"id": "grassland", "display_name": "Grassland", "domain": "land", "move_cost": 1,
##     "passable": true, "yields": {"food": 2}, "defense_bonus": 0, "sight_cost": 1,
##     "blocks_sight": false, "elevation": 0, "visual": "tile.grassland", "color": "#6aa84f",
##     "tags": ["flat"], "spawn_weight": 30, "metadata": {}}
##  ],
##  "features": [
##    {"id": "forest", "display_name": "Forest", "move_cost": 1, "defense_bonus": 25,
##     "blocks_sight": true, "yields": {"production": 1}, "visual": "feature.forest",
##     "allowed_on": ["grassland", "plains", "hills"], "spawn_chance": 0.25}
##  ]}
##
## Features layer on top of a terrain (forest on grassland). Improvements
## (roads, farms, mines) are tracked separately on the tile as strings and can be
## described in the game's metadata; they are deliberately open-ended.
class_name TileDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var is_feature: bool = false
@export var domain: String = "land"        ## land | sea | any
@export var move_cost: float = 1.0
@export var passable: bool = true
@export var yields: Dictionary = {}
@export var defense_bonus: float = 0.0     ## Percent.
@export var sight_cost: int = 1            ## Extra sight range consumed to see past.
@export var blocks_sight: bool = false
@export var elevation: int = 0             ## Higher elevation sees further/over lower.
@export var visual_key: String = ""
@export var color: Color = Color.GRAY      ## Blockout / minimap colour.
@export var tags: PackedStringArray = []
@export var spawn_weight: float = 1.0      ## Terrain generator weighting.
@export var spawn_chance: float = 0.0      ## Feature placement chance on allowed terrain.
@export var allowed_on: PackedStringArray = []
@export var metadata: Dictionary = {}


static func from_dict(d: Dictionary, feature: bool = false) -> TileDefinition:
	var t := TileDefinition.new()
	t.id = d.get("id", "")
	t.display_name = d.get("display_name", t.id.capitalize())
	t.is_feature = feature
	t.domain = d.get("domain", "land")
	t.move_cost = float(d.get("move_cost", 1.0))
	t.passable = bool(d.get("passable", true))
	t.yields = d.get("yields", {})
	t.defense_bonus = float(d.get("defense_bonus", 0.0))
	t.sight_cost = int(d.get("sight_cost", 1))
	t.blocks_sight = bool(d.get("blocks_sight", false))
	t.elevation = int(d.get("elevation", 0))
	t.visual_key = d.get("visual", "%s.%s" % ["feature" if feature else "tile", t.id])
	t.color = Color.html(d.get("color", "#888888")) if d.has("color") else Color.GRAY
	t.tags = PackedStringArray(d.get("tags", []))
	t.spawn_weight = float(d.get("spawn_weight", 1.0))
	t.spawn_chance = float(d.get("spawn_chance", 0.0))
	t.allowed_on = PackedStringArray(d.get("allowed_on", []))
	t.metadata = d.get("metadata", {})
	return t
