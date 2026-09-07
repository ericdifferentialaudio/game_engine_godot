## Static helpers for reading data-driven game content (JSON).
##
## Engine-agnostic: no Node2D/Node3D, no scene tree. Both the isometric and the
## FPS graphics engines feed the same JSON through this loader.
##
## API:
##   CoreDataLoader.load_json(path) -> Dictionary
##   CoreDataLoader.load_json_array(path, key) -> Array
##   CoreDataLoader.apply_fields(object, dict) -> void
class_name CoreDataLoader
extends RefCounted


## Read a JSON file whose root is an object. Returns {} on any failure.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("CoreDataLoader: file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("CoreDataLoader: JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("CoreDataLoader: root of %s must be an object" % path)
		return {}
	return json.data


## Read one named array out of a JSON object file. Returns [] on any failure.
static func load_json_array(path: String, key: String) -> Array:
	var data := load_json(path)
	var arr = data.get(key, [])
	if typeof(arr) != TYPE_ARRAY:
		push_error("CoreDataLoader: '%s' in %s must be an array" % [key, path])
		return []
	return arr


## Copy dictionary keys onto an Object's properties (by matching name).
static func apply_fields(target: Object, data: Dictionary) -> void:
	for key in data.keys():
		var prop := String(key)
		if prop in target:
			target.set(prop, data[key])


## Coerce a JSON value into Array[String].
##
## Authored data is inconsistent in the wild: a single-element list is often
## written as a bare string, and slot maps ({"body": "jerkin"}) are sometimes
## used where a plain list is expected. Both are accepted here so one schema
## reads either engine's packages.
static func str_array(v) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for e in v:
			out.append(str(e))
	elif v is Dictionary:
		for k in v:
			out.append(str(v[k]))
	elif v != null and str(v) != "":
		out.append(str(v))
	return out


## Coerce a JSON value into a PackedStringArray, with the same leniency.
static func packed_str_array(v) -> PackedStringArray:
	return PackedStringArray(str_array(v))


## Coerce a JSON value into Array[Dictionary].
static func dict_array(v) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if v is Array:
		for e in v:
			if e is Dictionary:
				out.append(e)
	return out


## Numeric comparison used by rules/queries: op is one of >= > <= < == = !=
static func compare(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		">": return a > b
		"<=": return a <= b
		"<": return a < b
		"==", "=": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
	return false
