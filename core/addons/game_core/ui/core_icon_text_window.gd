## General-purpose icon + text list.
##
## The workhorse window type: inventory lists, status readouts, notifications,
## emoji-annotated lines. Anything that is "a short line, optionally with a
## symbol beside it, sometimes clickable".
##
## Icons are referenced by a logical key (an emoji, or a key the host engine's
## asset registry resolves) rather than a `res://` path, so shared systems never
## hard-code a game's art.
##
## Specialised API:
##   set_entry(id, icon, text) / add_entry(...) / remove_entry(id) / entries()
class_name CoreIconTextWindow
extends CoreWindow

## Show newest entries first (notifications) rather than oldest (inventory).
@export var newest_first: bool = false
## Trim beyond this many entries. 0 = unlimited.
@export var max_entries: int = 0

var _list: VBoxContainer
var _entries: Dictionary = {}     ## id -> {"icon": String, "text": String}
var _order: Array[String] = []


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


# --- Entries ------------------------------------------------------------------

## Add or update an entry. Keyed by [param id], so calling it again with the
## same id updates in place — which is what a status line ("Zorkmids: 5")
## wants, rather than accumulating duplicates.
func set_entry(id: String, icon: String, text: String) -> void:
	if id == "":
		return
	var is_new := not _entries.has(id)
	_entries[id] = {"icon": icon, "text": text}
	if is_new:
		if newest_first:
			_order.push_front(id)
		else:
			_order.append(id)
	_trim()
	_rebuild()


## Append an entry under a generated id, for things that are never updated
## (notifications, log lines).
func add_entry(icon: String, text: String) -> String:
	var id := "entry_%d" % (_order.size() + _entries.size() + 1)
	while _entries.has(id):
		id += "_"
	set_entry(id, icon, text)
	return id


func remove_entry(id: String) -> bool:
	if not _entries.erase(id):
		return false
	_order.erase(id)
	_rebuild()
	return true


func has_entry(id: String) -> bool:
	return _entries.has(id)


func entry_text(id: String) -> String:
	return str(_entries.get(id, {}).get("text", ""))


## All entries in display order, as {"id", "icon", "text"}.
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _order:
		var e: Dictionary = _entries[id]
		out.append({"id": id, "icon": e["icon"], "text": e["text"]})
	return out


func entry_count() -> int:
	return _order.size()


# --- Contract -----------------------------------------------------------------

func clear() -> void:
	_entries.clear()
	_order.clear()
	_rebuild()


func describe() -> String:
	return "%s: %d entries" % [role, entry_count()]


func _trim() -> void:
	if max_entries <= 0:
		return
	while _order.size() > max_entries:
		var dropped: String = _order[-1] if newest_first else _order[0]
		_order.erase(dropped)
		_entries.erase(dropped)


func _rebuild() -> void:
	if _list == null:
		return
	# free(), not queue_free(): the list is rebuilt on every entry change, so
	# deferred frees would accumulate detached rows within a single frame.
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()

	for id in _order:
		var entry: Dictionary = _entries[id]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var icon := Label.new()
		icon.text = str(entry["icon"])
		icon.custom_minimum_size = Vector2(24, 0)
		row.add_child(icon)

		var label := Label.new()
		label.text = str(entry["text"])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var button := Button.new()
		button.flat = true
		button.tooltip_text = str(entry["text"])
		button.pressed.connect(_on_entry_pressed.bind(id))
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(button)

		_list.add_child(row)


func _on_entry_pressed(id: String) -> void:
	CoreWindowRegistry.report_entry(role, id)
