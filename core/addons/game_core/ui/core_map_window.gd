## Map window: a positional overview with clickable markers.
##
## The core keeps only the *model* of what is on the map — marker ids, their
## normalised positions and their icons. Actually drawing a hex grid or a 3D
## minimap is the graphics engine's business, so an engine subclasses this and
## overrides [method _draw_markers]. The base implementation places simple
## labelled buttons, which is enough to be genuinely usable (and testable)
## with no engine at all.
##
## Positions are normalised 0..1 so the map stays correct as the player drags
## the window's dividers.
##
## Specialised API:
##   set_marker(id, pos, icon) / remove_marker(id) / markers() / focus(pos)
class_name CoreMapWindow
extends CoreWindow

## Emitted in addition to the registry relay, for engine code that is already
## holding this window.
signal marker_clicked(marker_id: String)

var _canvas: Control
var _markers: Dictionary = {}     ## id -> {"pos": Vector2, "icon": String}
var _focus: Vector2 = Vector2(0.5, 0.5)


func _build() -> void:
	if minimum_window_size == Vector2i(120, 80):
		minimum_window_size = Vector2i(160, 160)
		custom_minimum_size = Vector2(minimum_window_size)

	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_canvas)


# --- Markers ------------------------------------------------------------------

## Add or move a marker. [param pos] is normalised 0..1 across the window.
func set_marker(id: String, pos: Vector2, icon: String = "•") -> void:
	if id == "":
		return
	_markers[id] = {
		"pos": Vector2(clampf(pos.x, 0.0, 1.0), clampf(pos.y, 0.0, 1.0)),
		"icon": icon,
	}
	_draw_markers()


func remove_marker(id: String) -> bool:
	if not _markers.erase(id):
		return false
	_draw_markers()
	return true


func has_marker(id: String) -> bool:
	return _markers.has(id)


func marker_position(id: String) -> Vector2:
	return _markers.get(id, {}).get("pos", Vector2.ZERO)


func markers() -> Dictionary:
	return _markers.duplicate(true)


func marker_count() -> int:
	return _markers.size()


## Centre the view on a normalised position. The base window records it;
## engine subclasses pan their real map.
func focus(pos: Vector2) -> void:
	_focus = Vector2(clampf(pos.x, 0.0, 1.0), clampf(pos.y, 0.0, 1.0))


func focus_point() -> Vector2:
	return _focus


## Activate a marker programmatically (tests, keyboard navigation).
func activate_marker(id: String) -> bool:
	if not _markers.has(id):
		return false
	_on_marker_pressed(id)
	return true


# --- Contract -----------------------------------------------------------------

func clear() -> void:
	_markers.clear()
	_draw_markers()


func describe() -> String:
	return "%s: %d markers" % [role, _markers.size()]


## Engines override this to draw a real map. The base draws clickable labels
## anchored at each marker's normalised position.
func _draw_markers() -> void:
	if _canvas == null:
		return
	# free(), not queue_free(): markers are redrawn on every change.
	for child in _canvas.get_children():
		_canvas.remove_child(child)
		child.free()

	for id in _markers:
		var marker: Dictionary = _markers[id]
		var pos: Vector2 = marker["pos"]
		var button := Button.new()
		button.text = str(marker["icon"])
		button.flat = true
		button.tooltip_text = str(id)
		button.anchor_left = pos.x
		button.anchor_top = pos.y
		button.anchor_right = pos.x
		button.anchor_bottom = pos.y
		button.pressed.connect(_on_marker_pressed.bind(str(id)))
		_canvas.add_child(button)


func _on_marker_pressed(id: String) -> void:
	marker_clicked.emit(id)
	CoreWindowRegistry.report_marker(role, id)
