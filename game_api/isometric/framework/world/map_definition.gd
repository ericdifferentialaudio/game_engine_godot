## Static description of a map (maps.json). A map is the overworld or a site
## sub-map (city interior, dungeon level). Maps form a tree via parent_id and
## are entered/left through portals declared on sites (see SiteDefinition).
##
## {"maps": [
##   {"id": "overworld", "display_name": "The Reach", "kind": "overworld",
##    "size": [40, 28], "generator": {"type": "noise", "sea_level": 0.38, "seed_offset": 0,
##                                   "terrain_bands": [...], "features": true},
##    "layout": ["~~~^^^", ...],            optional hand-authored rows using terrain "glyph"s
##    "glyphs": {"~": "ocean", ".": "grassland"},
##    "environment": "env.temperate", "music": "music.overworld",
##    "fog": "full"|"explored_only"|"none",
##    "starts": {"player": [5, 5], "rivals": [[30, 20]]},
##    "tags": [], "metadata": {}}
## ]}
class_name MapDefinition
extends Resource

enum Kind { OVERWORLD, REGION, CITY, DUNGEON, INTERIOR, SPECIAL }

const KIND_NAMES := {
	"overworld": Kind.OVERWORLD, "region": Kind.REGION, "city": Kind.CITY,
	"dungeon": Kind.DUNGEON, "interior": Kind.INTERIOR, "special": Kind.SPECIAL,
}

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.OVERWORLD
@export var parent_id: String = ""
@export var size: Vector2i = Vector2i(24, 16)
@export var generator: Dictionary = {}
@export var layout: PackedStringArray = []
@export var glyphs: Dictionary = {}
@export var environment_key: String = ""
@export var music_key: String = ""
@export var fog_mode: String = "full"       ## full | explored_only | none
@export var starts: Dictionary = {}
@export var tags: PackedStringArray = []
@export var metadata: Dictionary = {}

var site_ids: Array[String] = []             ## Filled by WorldManager from sites.json.


static func from_dict(d: Dictionary) -> MapDefinition:
	var m := MapDefinition.new()
	m.id = d.get("id", "")
	m.display_name = d.get("display_name", m.id)
	m.kind = KIND_NAMES.get(str(d.get("kind", "overworld")).to_lower(), Kind.SPECIAL)
	m.parent_id = d.get("parent", "")
	var sz: Array = d.get("size", [24, 16])
	m.size = Vector2i(int(sz[0]), int(sz[1]))
	m.generator = d.get("generator", {})
	m.layout = PackedStringArray(d.get("layout", []))
	m.glyphs = d.get("glyphs", {})
	m.environment_key = d.get("environment", "")
	m.music_key = d.get("music", "")
	m.fog_mode = d.get("fog", "full")
	m.starts = d.get("starts", {})
	m.tags = PackedStringArray(d.get("tags", []))
	m.metadata = d.get("metadata", {})
	if not m.layout.is_empty():
		m.size = Vector2i(m.layout[0].length(), m.layout.size())
	return m


func kind_name() -> String:
	return Kind.keys()[kind].to_lower()
