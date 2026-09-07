## Static helpers for reading data-driven game content (JSON).
##
## All game content is authored as JSON (validated offline by tools/validate_data.py)
## and converted into typed Resources at load time by the owning registry.
class_name DataLoader
extends RefCounted


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("DataLoader: file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("DataLoader: JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("DataLoader: root of %s must be an object" % path)
		return {}
	return json.data


static func load_json_array(path: String, key: String) -> Array:
	var data := load_json(path)
	var arr = data.get(key, [])
	if typeof(arr) != TYPE_ARRAY:
		push_error("DataLoader: '%s' in %s must be an array" % [key, path])
		return []
	return arr


## Copy dictionary keys onto an Object's exported properties (by matching name).
static func apply_fields(target: Object, data: Dictionary) -> void:
	for key in data.keys():
		var prop := String(key)
		if prop in target:
			target.set(prop, data[key])
