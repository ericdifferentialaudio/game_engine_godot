## Data-driven screen layout: which windows a game has, where they sit, and how
## much room each gets by default.
##
## A layout is a **tree of splits with a window at each leaf**, which is exactly
## how Godot's `HSplitContainer`/`VSplitContainer` model it. Expressing it as
## data means a new game defines its own screen without touching shared code.
##
## JSON shape (games/<id>/layout.json):
##
##   {
##     "variants": [
##       {
##         "id": "wide", "min_aspect": 1.5,
##         "root": {
##           "orientation": "horizontal", "ratio": 0.68,
##           "children": [
##             {"orientation": "vertical", "ratio": 0.6, "children": [
##               {"role": "scene",    "type": "graphics"},
##               {"role": "dialogue", "type": "text", "min_size": [320, 200]}
##             ]},
##             {"orientation": "vertical", "ratio": 0.5, "children": [
##               {"role": "party",  "type": "units"},
##               {"role": "status", "type": "icon_text"}
##             ]}
##           ]
##         }
##       },
##       { "id": "tall", "min_aspect": 0.0, "root": { ... } }
##     ]
##   }
##
## Variants are chosen at startup by the real viewport's aspect ratio: the
## best match is the one with the highest `min_aspect` the viewport still meets.
## That is how one game supports both an ultrawide monitor and a tall window
## without any runtime repositioning.
class_name CoreLayoutDefinition
extends Resource

## Window type keys usable in a leaf, mapped to their implementing script.
const WINDOW_TYPES := {
	"text": "core_text_window.gd",
	"graphics": "core_graphics_window.gd",
	"map": "core_map_window.gd",
	"units": "core_unit_display_window.gd",
	"icon_text": "core_icon_text_window.gd",
}

const UI_ROOT := "res://addons/game_core/ui/"

@export var id: String = ""
@export var variants: Array = []


## Build from a parsed JSON dictionary.
static func from_dict(d: Dictionary) -> CoreLayoutDefinition:
	var layout := CoreLayoutDefinition.new()
	layout.id = str(d.get("id", ""))
	layout.variants = d.get("variants", [])
	# A layout may skip the variants wrapper entirely and give a single root.
	if layout.variants.is_empty() and d.has("root"):
		layout.variants = [{"id": "default", "min_aspect": 0.0, "root": d["root"]}]
	return layout


## Load from a JSON file. Returns null (with a pushed error) if unusable, so a
## game with a broken layout fails loudly at boot rather than silently.
static func load_file(path: String) -> CoreLayoutDefinition:
	if not FileAccess.file_exists(path):
		push_error("CoreLayoutDefinition: no layout at %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CoreLayoutDefinition: could not open %s" % path)
		return null
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("CoreLayoutDefinition: %s is not a JSON object" % path)
		return null
	return from_dict(parsed)


## Pick the variant best suited to a viewport size.
##
## "Best" = the variant with the largest `min_aspect` that the viewport's aspect
## still satisfies, so a 21:9 screen prefers a "ultrawide" variant over "wide"
## over "tall". Falls back to the first variant so there is always an answer.
func variant_for(viewport_size: Vector2) -> Dictionary:
	if variants.is_empty():
		return {}
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var best: Dictionary = {}
	var best_aspect := -INF
	for v in variants:
		if not (v is Dictionary):
			continue
		var min_aspect := float(v.get("min_aspect", 0.0))
		var min_width := float(v.get("min_width", 0.0))
		if aspect >= min_aspect and viewport_size.x >= min_width and min_aspect > best_aspect:
			best = v
			best_aspect = min_aspect
	return best if not best.is_empty() else variants[0]


## The layout tree for a viewport, or {} when nothing is defined.
func root_for(viewport_size: Vector2) -> Dictionary:
	var variant := variant_for(viewport_size)
	return variant.get("root", {})


func variant_ids() -> Array[String]:
	var out: Array[String] = []
	for v in variants:
		if v is Dictionary:
			out.append(str(v.get("id", "")))
	return out


## Every window role this layout declares, across all variants. Used to verify
## that the roles a game's code expects actually exist somewhere.
func declared_roles() -> Array[String]:
	var out: Array[String] = []
	for v in variants:
		if v is Dictionary:
			_collect_roles(v.get("root", {}), out)
	out.sort()
	return out


static func script_for_type(type_name: String) -> GDScript:
	if not WINDOW_TYPES.has(type_name):
		return null
	return load(UI_ROOT + WINDOW_TYPES[type_name]) as GDScript


func _collect_roles(node: Dictionary, out: Array[String]) -> void:
	if node.is_empty():
		return
	if node.has("role"):
		var role := str(node["role"])
		if role != "" and role not in out:
			out.append(role)
		return
	for child in node.get("children", []):
		if child is Dictionary:
			_collect_roles(child, out)
