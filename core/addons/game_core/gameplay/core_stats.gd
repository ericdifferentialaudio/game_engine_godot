## Generic stat block shared by both graphics engines.
##
## Base values come from a CoreUnitDefinition (falling back to the game's default
## stat block); equipment, statuses and levels contribute named modifiers.
## Current values are always clamped to the modified maximum.
##
## Stat names the platform itself reads (all optional):
##   health, strength, ranged, defense, moves, sight, perception
##
## API:
##   stats.define_from(defaults, overrides)
##   stats.get_value(stat) / set_value(stat, v) / modify(stat, delta)
##   stats.max_value(stat) / restore(stat) / restore_all()
##   stats.add_modifier(source_id, {stat: delta}) / remove_modifier(source_id)
class_name CoreStats
extends RefCounted

signal stat_changed(stat: String, value: float, max_value: float)
signal depleted(stat: String)     ## A stat hit zero (health -> death, etc.).

var base: Dictionary = {}         ## stat -> base max
var current: Dictionary = {}      ## stat -> current value
var modifiers: Dictionary = {}    ## source_id -> {stat: delta}


## Seed the block from a defaults dictionary plus per-unit overrides.
func define_from(defaults: Dictionary, overrides: Dictionary = {}) -> void:
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


func stat_names() -> Array:
	return base.keys()


## Base value plus every active modifier, floored at 0.
func max_value(stat: String) -> float:
	var v: float = base.get(stat, 0.0)
	for src in modifiers:
		v += float(modifiers[src].get(stat, 0.0))
	return maxf(v, 0.0)


func get_value(stat: String) -> float:
	return current.get(stat, max_value(stat))


func set_value(stat: String, value: float) -> void:
	var capped := clampf(value, 0.0, max_value(stat))
	current[stat] = capped
	stat_changed.emit(stat, capped, max_value(stat))
	if capped <= 0.0:
		depleted.emit(stat)


func modify(stat: String, delta: float) -> void:
	set_value(stat, get_value(stat) + delta)


## Fraction of maximum, 0..1 (0 if the stat has no maximum).
func ratio(stat: String) -> float:
	var m := max_value(stat)
	return get_value(stat) / m if m > 0.0 else 0.0


func restore(stat: String) -> void:
	set_value(stat, max_value(stat))


func restore_all() -> void:
	for k in base:
		restore(k)


## Add (or replace) a named modifier group, e.g. "equip:weapon" or "status:poison".
func add_modifier(source_id: String, deltas: Dictionary) -> void:
	remove_modifier(source_id)
	modifiers[source_id] = deltas.duplicate()
	for k in deltas:
		if not base.has(k):
			base[k] = 0.0
		if not current.has(k):
			current[k] = max_value(k)
		else:
			set_value(k, current[k])


func remove_modifier(source_id: String) -> void:
	if modifiers.erase(source_id):
		for k in current.keys():
			set_value(k, current[k])


## Permanent growth (levelling): raises the base and the current value together.
func raise_base(stat: String, delta: float) -> void:
	base[stat] = base.get(stat, 0.0) + delta
	if not current.has(stat):
		current[stat] = base[stat]
	else:
		set_value(stat, current[stat] + delta)


func to_save_data() -> Dictionary:
	return {"base": base.duplicate(), "current": current.duplicate(),
		"modifiers": modifiers.duplicate(true)}


func from_save_data(d: Dictionary) -> void:
	base = d.get("base", base)
	current = d.get("current", current)
	modifiers = d.get("modifiers", {})
