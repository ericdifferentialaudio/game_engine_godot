## A concrete item (or stack) owned by someone. Wraps an ItemDefinition with
## per-instance state: count, affixes, identification, durability, custom name.
class_name ItemInstance
extends RefCounted

static var _next_uid: int = 1

var uid: int
var def: ItemDefinition
var count: int = 1
var affixes: Array[Dictionary] = []   ## M4: {"id", "stats": {...}, "effects": [...]} generated modifiers
var identified: bool = true
var durability: float = 0.0
var custom_name: String = ""
var bound_to: String = ""             ## actor id if soulbound/quest-bound


static func create(item_def: ItemDefinition, p_count: int = 1) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.uid = _next_uid
	_next_uid += 1
	inst.def = item_def
	inst.count = maxi(1, p_count)
	inst.identified = item_def.identified_by_default
	inst.durability = item_def.durability
	return inst


func id() -> String:
	return def.id


func display_name() -> String:
	if custom_name != "":
		return custom_name
	if not identified:
		return "Unidentified %s" % def.category_name().capitalize()
	return def.display_name


func weight() -> float:
	return def.weight * count


func value() -> int:
	var v := def.value
	for a in affixes:
		v += int(a.get("value", 0))
	return v * count


func can_stack_with(other: ItemInstance) -> bool:
	return def.stackable and other.def == def and affixes.is_empty() and other.affixes.is_empty() \
		and identified == other.identified and custom_name == other.custom_name


func space_left() -> int:
	return maxi(0, def.max_stack - count)


## Flat stat modifiers including affixes (only if identified: unknown items give base only).
func total_stats() -> Dictionary:
	var out := def.stats.duplicate()
	if identified:
		for a in affixes:
			for k in a.get("stats", {}):
				out[k] = out.get(k, 0.0) + a["stats"][k]
	return out


func total_stats_percent() -> Dictionary:
	var out := def.stats_percent.duplicate()
	if identified:
		for a in affixes:
			for k in a.get("stats_percent", {}):
				out[k] = out.get(k, 0.0) + a["stats_percent"][k]
	return out


func total_effects() -> Array[String]:
	var out := def.effects.duplicate()
	if identified:
		for a in affixes:
			for e in a.get("effects", []):
				out.append(str(e))
	return out


func total_abilities() -> Array[String]:
	var out := def.abilities.duplicate()
	if identified:
		for a in affixes:
			for e in a.get("abilities", []):
				out.append(str(e))
	return out


func total_procs() -> Array[Dictionary]:
	var out := def.procs.duplicate()
	if identified:
		for a in affixes:
			for p in a.get("procs", []):
				out.append(p)
	return out


func identify() -> void:
	if identified:
		return
	identified = true
	EventBus.item_identified.emit(def.id)


func split(amount: int) -> ItemInstance:
	amount = clampi(amount, 1, count - 1)
	var other := ItemInstance.create(def, amount)
	other.identified = identified
	other.custom_name = custom_name
	count -= amount
	return other


func to_dict() -> Dictionary:
	var d := {"id": def.id, "count": count}
	if not affixes.is_empty():
		d["affixes"] = affixes
	if not identified:
		d["identified"] = false
	if def.durability > 0.0:
		d["durability"] = durability
	if custom_name != "":
		d["custom_name"] = custom_name
	if bound_to != "":
		d["bound_to"] = bound_to
	return d


static func from_dict(d: Dictionary) -> ItemInstance:
	var item_def := DefinitionRegistry.get_def("items", str(d.get("id", ""))) as ItemDefinition
	if item_def == null:
		return null
	var inst := create(item_def, int(d.get("count", 1)))
	inst.affixes = Definition._dict_array(d.get("affixes", []))
	inst.identified = bool(d.get("identified", item_def.identified_by_default))
	inst.durability = float(d.get("durability", item_def.durability))
	inst.custom_name = str(d.get("custom_name", ""))
	inst.bound_to = str(d.get("bound_to", ""))
	return inst
