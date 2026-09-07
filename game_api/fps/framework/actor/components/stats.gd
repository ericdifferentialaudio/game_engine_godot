## Stat block with a source-tagged modifier stack.
##
##   final = (base + sum(flat mods)) * (1 + sum(percent mods))
##
## Modifiers are grouped by [b]source[/b] (e.g. "equip:main_hand", "effect:burning#3")
## so a whole source can be removed at once when gear is unequipped or an
## effect expires. Stat names are free-form strings defined by the game
## (game.json "stats" gives base defaults for the player).
class_name Stats
extends ActorComponent

signal stat_changed(stat: String, final_value: float)

var base: Dictionary = {}                 ## stat -> float
var _flat: Dictionary = {}                ## source -> {stat -> float}
var _percent: Dictionary = {}             ## source -> {stat -> float}
var _cache: Dictionary = {}               ## stat -> final
var _dirty: bool = true


func _definition_applied(def: ActorDefinition) -> void:
	for k in def.stats:
		base[k] = float(def.stats[k])
	_invalidate()


func set_base(stat: String, value: float) -> void:
	base[stat] = value
	_invalidate([stat])


func add_base(stat: String, delta: float) -> void:
	set_base(stat, base.get(stat, 0.0) + delta)


func get_base(stat: String, default: float = 0.0) -> float:
	return base.get(stat, default)


## Replace all modifiers for [param source].
func set_modifiers(source: String, flat: Dictionary, percent: Dictionary = {}) -> void:
	var touched := _touched_by(source)
	if flat.is_empty():
		_flat.erase(source)
	else:
		_flat[source] = flat.duplicate()
	if percent.is_empty():
		_percent.erase(source)
	else:
		_percent[source] = percent.duplicate()
	for k in flat: touched[k] = true
	for k in percent: touched[k] = true
	_invalidate(touched.keys())


func remove_modifiers(source: String) -> void:
	var touched := _touched_by(source)
	_flat.erase(source)
	_percent.erase(source)
	_invalidate(touched.keys())


func has_source(source: String) -> bool:
	return _flat.has(source) or _percent.has(source)


func get_final(stat: String, default: float = 0.0) -> float:
	if _dirty:
		_rebuild()
	if _cache.has(stat):
		return _cache[stat]
	return default


## All stats that have a base or any modifier, with final values.
func all_final() -> Dictionary:
	if _dirty:
		_rebuild()
	return _cache.duplicate()


func flat_total(stat: String) -> float:
	var t := 0.0
	for src in _flat:
		t += float(_flat[src].get(stat, 0.0))
	return t


func percent_total(stat: String) -> float:
	var t := 0.0
	for src in _percent:
		t += float(_percent[src].get(stat, 0.0))
	return t


func _touched_by(source: String) -> Dictionary:
	var touched := {}
	for k in _flat.get(source, {}): touched[k] = true
	for k in _percent.get(source, {}): touched[k] = true
	return touched


func _invalidate(stat_names: Array = []) -> void:
	_dirty = true
	if stat_names.is_empty():
		return
	# Emit lazily after rebuild for the touched stats.
	_rebuild()
	for s in stat_names:
		stat_changed.emit(s, _cache.get(s, 0.0))


func _rebuild() -> void:
	_cache.clear()
	var names := {}
	for k in base: names[k] = true
	for src in _flat:
		for k in _flat[src]: names[k] = true
	for src in _percent:
		for k in _percent[src]: names[k] = true
	for k in names:
		_cache[k] = (base.get(k, 0.0) + flat_total(k)) * (1.0 + percent_total(k))
	_dirty = false


func to_save_data() -> Dictionary:
	return {"base": base.duplicate()}  # Modifiers are re-applied by their sources on load.


func from_save_data(d: Dictionary) -> void:
	base = d.get("base", {})
	_invalidate()
