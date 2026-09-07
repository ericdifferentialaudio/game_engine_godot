## Generic stat block for a Unit. Base values come from the EntityDefinition
## (falling back to game.json "stats"); equipment, statuses and levels add
## modifiers. Current values (health, moves) are clamped to the modified max.
##
## Conventional stat names the engine itself reads:
##   health, strength, ranged, defense, moves, sight, perception (intel reliability bonus)
class_name CharacterStats
extends RefCounted

signal stat_changed(stat: String, value: float, max_value: float)

var base: Dictionary = {}        ## stat -> base max
var current: Dictionary = {}     ## stat -> current value
var modifiers: Dictionary = {}   ## source_id -> {stat: delta}


func define_from(defaults: Dictionary, overrides: Dictionary) -> void:
	base.clear()
	current.clear()
	for k in defaults:
		base[k] = float(defaults[k])
	for k in overrides:
		base[k] = float(overrides[k])
	for k in base:
		current[k] = base[k]


func has_stat(stat: String) -> bool:
	return base.has(stat)


func max_value(stat: String) -> float:
	var v: float = base.get(stat, 0.0)
	for src in modifiers:
		v += float(modifiers[src].get(stat, 0.0))
	return maxf(v, 0.0)


func get_value(stat: String) -> float:
	return current.get(stat, max_value(stat))


func set_value(stat: String, value: float) -> void:
	current[stat] = clampf(value, 0.0, max_value(stat))
	stat_changed.emit(stat, current[stat], max_value(stat))


func modify(stat: String, delta: float) -> void:
	set_value(stat, get_value(stat) + delta)


func restore(stat: String) -> void:
	set_value(stat, max_value(stat))


func restore_all() -> void:
	for k in base:
		restore(k)


func add_modifier(source_id: String, deltas: Dictionary) -> void:
	modifiers[source_id] = deltas.duplicate()
	for k in deltas:
		if current.has(k):
			set_value(k, current[k] + float(deltas[k]) if float(deltas[k]) > 0.0 else current[k])
		else:
			base[k] = base.get(k, 0.0)
			current[k] = max_value(k)


func remove_modifier(source_id: String) -> void:
	if modifiers.erase(source_id):
		for k in current.keys():
			set_value(k, current[k])


func raise_base(stat: String, delta: float) -> void:
	base[stat] = base.get(stat, 0.0) + delta
	if not current.has(stat):
		current[stat] = base[stat]
	else:
		set_value(stat, current[stat] + delta)


func to_save_data() -> Dictionary:
	return {"base": base.duplicate(), "current": current.duplicate(), "modifiers": modifiers.duplicate(true)}


func from_save_data(d: Dictionary) -> void:
	base = d.get("base", base)
	current = d.get("current", current)
	modifiers = d.get("modifiers", {})
