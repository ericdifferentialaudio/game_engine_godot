## Item definitions (items.json) and convenience lookups by kind/tag.
extends Node

var definitions: Dictionary = {}   ## item_id -> ItemDefinition


func load_definitions(path: String) -> void:
	definitions.clear()
	for entry in DataLoader.load_json_array(path, "items"):
		var def := ItemDefinition.from_dict(entry)
		if def.id == "":
			push_error("ItemRegistry: item without id in %s" % path)
			continue
		definitions[def.id] = def


func get_definition(item_id: String) -> ItemDefinition:
	return definitions.get(item_id)


func has(item_id: String) -> bool:
	return definitions.has(item_id)


func items_of_kind(kind: String) -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for d in definitions.values():
		if d.kind == kind:
			out.append(d)
	return out


func items_with_tag(tag: String) -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for d in definitions.values():
		if tag in d.tags:
			out.append(d)
	return out


## Items that would grant a given intel token when used (for "where can I learn X" tooling).
func items_granting(token_id: String) -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for d in definitions.values():
		if token_id in d.grants_intel:
			out.append(d)
	return out
