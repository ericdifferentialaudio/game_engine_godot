## Strategy camera: WASD/arrow pan, edge scroll, wheel zoom, focus-on-request,
## clamped to the current map. Attach to a Camera2D in the main scene.
class_name IsoCamera
extends Camera2D

@export var pan_speed: float = 900.0
@export var edge_scroll_margin: float = 24.0
@export var edge_scroll: bool = true
@export var min_zoom: float = 0.4
@export var max_zoom: float = 3.0
@export var zoom_step: float = 0.12

var _limits := Rect2()
var _drag_last := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	make_current()
	EventBus.world_loaded.connect(_on_world_loaded)
	EventBus.camera_focus_requested.connect(focus_tile)
	EventBus.unit_selected.connect(func(uid):
		var u := EntityRegistry.get_unit(uid)
		if u:
			focus_tile(u.coord))


func _on_world_loaded(_map_id: String, _depth: int) -> void:
	if WorldManager.renderer:
		_limits = WorldManager.renderer.map_rect()
	var player := FactionRegistry.player()
	if player:
		focus_tile(player.home_coord)
	else:
		position = _limits.get_center()


func focus_tile(coord: Vector2i) -> void:
	if WorldManager.world:
		position = WorldManager.world.topology.to_world(coord)
		_clamp()


func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
	dir.y = Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")
	if edge_scroll and get_viewport():
		var mp := get_viewport().get_mouse_position()
		var vs := get_viewport_rect().size
		if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
			if mp.x < edge_scroll_margin:
				dir.x -= 1
			elif mp.x > vs.x - edge_scroll_margin:
				dir.x += 1
			if mp.y < edge_scroll_margin:
				dir.y -= 1
			elif mp.y > vs.y - edge_scroll_margin:
				dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * delta / zoom.x
		_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_by(1.0 + zoom_step, get_global_mouse_position())
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_by(1.0 / (1.0 + zoom_step), get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = event.pressed
		_drag_last = event.position
	elif event is InputEventMouseMotion and _dragging:
		position -= (event.position - _drag_last) / zoom.x
		_drag_last = event.position
		_clamp()


func _zoom_by(factor: float, anchor: Vector2) -> void:
	var new_zoom := clampf(zoom.x * factor, min_zoom, max_zoom)
	var before := anchor
	zoom = Vector2.ONE * new_zoom
	var after := get_global_mouse_position()
	position += before - after
	_clamp()


func _clamp() -> void:
	if _limits.size == Vector2.ZERO:
		return
	position.x = clampf(position.x, _limits.position.x, _limits.end.x)
	position.y = clampf(position.y, _limits.position.y, _limits.end.y)
