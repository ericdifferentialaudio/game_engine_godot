## Base class for every data-driven definition loaded by DefinitionRegistry.
##
## Subclasses override [method _apply] to map JSON keys onto typed fields.
## Common fields (id, display_name, tags, metadata) are handled here.
class_name Definition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var tags: PackedStringArray = []
@export var metadata: Dictionary = {}

## Raw source dictionary, kept for game-specific extension keys.
var raw: Dictionary = {}


## Build an instance of the concrete subclass from a JSON dictionary.
static func build(script: GDScript, d: Dictionary) -> Definition:
	var def: Definition = script.new()
	def.raw = d
	def.id = str(d.get("id", ""))
	def.display_name = str(d.get("display_name", def.id))
	def.description = str(d.get("description", ""))
	def.tags = PackedStringArray(d.get("tags", []))
	def.metadata = d.get("metadata", {})
	def._apply(d)
	return def


## Override to read type-specific fields.
func _apply(_d: Dictionary) -> void:
	pass


func has_tag(tag: String) -> bool:
	return tag in tags


static func _vec3(v, fallback := Vector3.ZERO) -> Vector3:
	if v is Array and v.size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback


static func _str_array(v) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for e in v:
			out.append(str(e))
	return out


static func _dict_array(v) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		for e in v:
			if e is Dictionary:
				out.append(e)
	return out
