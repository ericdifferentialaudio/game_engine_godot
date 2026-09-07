## Base class for every data-driven definition loaded by CoreRegistry.
##
## Subclasses override [method _apply] to map JSON keys onto typed fields.
## Common fields (id, display_name, description, tags, metadata) are handled here.
## The original JSON is kept in [member raw] so games may carry extension keys the
## engine does not know about without losing them.
##
## API:
##   CoreDefinition.build(script, dict) -> CoreDefinition
##   def.has_tag(tag) -> bool
##   def.extra(key, default) -> Variant     # read an unmapped raw key
class_name CoreDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var tags: PackedStringArray = []
@export var metadata: Dictionary = {}

## Raw source dictionary, kept for game-specific extension keys.
var raw: Dictionary = {}


## Build an instance of the concrete subclass from a JSON dictionary.
static func build(script: GDScript, d: Dictionary) -> CoreDefinition:
	var def: CoreDefinition = script.new()
	def.raw = d
	def.id = str(d.get("id", ""))
	def.display_name = str(d.get("display_name", def.id.capitalize()))
	def.description = str(d.get("description", ""))
	def.tags = CoreDataLoader.packed_str_array(d.get("tags", []))
	def.metadata = d.get("metadata", {})
	def._apply(d)
	return def


## Override to read type-specific fields.
func _apply(_d: Dictionary) -> void:
	pass


func has_tag(tag: String) -> bool:
	return tag in tags


## Read a key from the raw JSON that no typed field claimed.
func extra(key: String, default = null):
	return raw.get(key, default)
