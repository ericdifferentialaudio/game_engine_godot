## Party / unit roster window.
##
## Shows a list of characters with their vital bars — the "who is with me and
## how are they doing" panel. Units are supplied as plain Dictionaries so this
## window is not coupled to any particular actor class; the two graphics
## engines model their units very differently, but both can describe one.
##
## Unit dictionary shape (every key optional except id):
##   {"id": "player", "name": "You", "icon": "🙂",
##    "stats": {"health": {"value": 42, "max": 60}}, "status": "poisoned"}
##
## Specialised API:
##   set_units(list) / update_unit(id, data) / units() / selected_unit()
class_name CoreUnitDisplayWindow
extends CoreWindow

## Which stat to draw as the primary bar, when a unit supplies it.
@export var primary_stat: String = "health"

var _list: VBoxContainer
var _units: Array[Dictionary] = []
var _selected: String = ""


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


# --- Units --------------------------------------------------------------------

## Replace the whole roster.
func set_units(unit_list: Array) -> void:
	_units.clear()
	for u in unit_list:
		if u is Dictionary and str(u.get("id", "")) != "":
			_units.append((u as Dictionary).duplicate(true))
	_rebuild()


## Update one unit in place, merging the supplied keys. Returns false if that
## unit is not on the roster — callers should not have to check first.
func update_unit(id: String, data: Dictionary) -> bool:
	for i in _units.size():
		if str(_units[i].get("id", "")) == id:
			for key in data:
				_units[i][key] = data[key]
			_rebuild()
			return true
	return false


func units() -> Array[Dictionary]:
	return _units.duplicate(true)


func unit_count() -> int:
	return _units.size()


func has_unit(id: String) -> bool:
	for u in _units:
		if str(u.get("id", "")) == id:
			return true
	return false


## The unit the player last clicked, "" if none.
func selected_unit() -> String:
	return _selected


# --- Contract -----------------------------------------------------------------

func clear() -> void:
	_units.clear()
	_selected = ""
	_rebuild()


func describe() -> String:
	return "%s: %d units" % [role, _units.size()]


func _rebuild() -> void:
	if _list == null:
		return
	# free(), not queue_free(): the roster is rebuilt on every update.
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()

	for unit in _units:
		var id := str(unit.get("id", ""))
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header := Button.new()
		header.text = "%s %s" % [str(unit.get("icon", "")), str(unit.get("name", id))]
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.flat = true
		header.pressed.connect(_on_unit_pressed.bind(id))
		row.add_child(header)

		var stats: Dictionary = unit.get("stats", {})
		if stats.has(primary_stat):
			var stat: Dictionary = stats[primary_stat]
			var bar := ProgressBar.new()
			bar.max_value = maxf(float(stat.get("max", 1.0)), 1.0)
			bar.value = clampf(float(stat.get("value", 0.0)), 0.0, bar.max_value)
			bar.custom_minimum_size = Vector2(0, 10)
			row.add_child(bar)

		var status := str(unit.get("status", ""))
		if status != "":
			var label := Label.new()
			label.text = status
			row.add_child(label)

		_list.add_child(row)


func _on_unit_pressed(id: String) -> void:
	_selected = id
	CoreWindowRegistry.report_entry(role, id)
