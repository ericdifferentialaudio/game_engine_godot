## Mouse -> tile interaction for the human player: hover highlight, select unit
## or tile, right-click to move/attack the selected unit, reachable-range overlay.
## Purely presentational + input; all rules live in Unit/Pathfinder.
class_name TileCursor
extends Node2D

var hovered: Vector2i = Vector2i(-1, -1)
var selected_tile: Vector2i = Vector2i(-1, -1)

var _hover_poly: Line2D
var _select_poly: Line2D
var _range: Node2D
var _path: Line2D


func _ready() -> void:
	z_index = 6
	_hover_poly = _make_outline(Color(1, 1, 1, 0.8), 2.0)
	_select_poly = _make_outline(Color(1, 0.85, 0.2, 1.0), 3.0)
	_range = Node2D.new()
	add_child(_range)
	_path = Line2D.new()
	_path.width = 3.0
	_path.default_color = Color(0.3, 0.9, 1.0, 0.8)
	add_child(_path)
	EventBus.world_loaded.connect(func(_m, _d): _rebuild_outlines())
	EventBus.unit_selected.connect(func(_u): _refresh_range())
	EventBus.unit_deselected.connect(func(_u): _clear_range())
	EventBus.unit_moved.connect(func(_u, _f, _t): _refresh_range())
	EventBus.unit_action_points_changed.connect(func(_u, _r): _refresh_range())
	EventBus.turn_started.connect(func(_t): _refresh_range())


func _make_outline(color: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.closed = true
	l.width = width
	l.default_color = color
	l.visible = false
	add_child(l)
	return l


func _rebuild_outlines() -> void:
	var outline := WorldManager.world.topology.outline() if WorldManager.world else PackedVector2Array()
	_hover_poly.points = outline
	_select_poly.points = outline
	_clear_range()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLAYING or WorldManager.world == null:
		return
	var world := WorldManager.world
	if event is InputEventMouseMotion:
		var c := world.topology.to_tile(get_global_mouse_position())
		if c != hovered:
			hovered = c
			var valid := world.tiles.has(c)
			_hover_poly.visible = valid
			if valid:
				_hover_poly.position = world.topology.to_world(c)
				EventBus.tile_hovered.emit(c)
			_update_path_preview()
	elif event.is_action_pressed("select"):
		var c := world.topology.to_tile(get_global_mouse_position())
		if not world.tiles.has(c):
			return
		selected_tile = c
		_select_poly.visible = true
		_select_poly.position = world.topology.to_world(c)
		EventBus.tile_selected.emit(c)
		var own := _own_unit_at(c)
		if own:
			EntityRegistry.select(own.unit_id)
		else:
			EntityRegistry.deselect()
	elif event.is_action_pressed("command"):
		var c := world.topology.to_tile(get_global_mouse_position())
		if world.tiles.has(c):
			EventBus.tile_commanded.emit(c)
			_command(c)
	elif event.is_action_pressed("next_unit"):
		EntityRegistry.select_next_idle(GameManager.player_faction_id)


func _own_unit_at(c: Vector2i) -> Unit:
	for u in WorldManager.world.units_at(c):
		if u.faction_id == GameManager.player_faction_id:
			return u
	return null


func _command(c: Vector2i) -> void:
	var u := EntityRegistry.selected()
	if u == null or u.faction_id != GameManager.player_faction_id:
		return
	if not TurnManager.is_faction_active(u.faction_id):
		EventBus.notification.emit("Not your turn.", "warning")
		return
	var target := WorldManager.world.unit_at(c)
	if target and FactionRegistry.are_hostile(u.faction_id, target.faction_id):
		if WorldManager.world.topology.distance(u.coord, target.coord) <= 1:
			u.attack(target)
		else:
			u.move_toward_target(target.coord)
			if WorldManager.world.topology.distance(u.coord, target.coord) <= 1 and u.action_points > 0.0:
				u.attack(target)
	else:
		u.move_to(c)
	_refresh_range()


func _refresh_range() -> void:
	_clear_range()
	var u := EntityRegistry.selected()
	if u == null or WorldManager.world == null or u.faction_id != GameManager.player_faction_id:
		return
	var reach := Pathfinder.reachable(WorldManager.world, u, u.coord, u.action_points)
	var outline := WorldManager.world.topology.outline()
	for c in reach:
		var p := Polygon2D.new()
		p.polygon = outline
		p.color = Color(0.3, 0.7, 1.0, 0.22)
		p.position = WorldManager.world.topology.to_world(c)
		_range.add_child(p)


func _clear_range() -> void:
	for c in _range.get_children():
		c.queue_free()
	_path.points = PackedVector2Array()


func _update_path_preview() -> void:
	_path.points = PackedVector2Array()
	var u := EntityRegistry.selected()
	if u == null or WorldManager.world == null or not WorldManager.world.tiles.has(hovered):
		return
	var path := Pathfinder.find_path(WorldManager.world, u, u.coord, hovered)
	if path.is_empty():
		return
	var pts := PackedVector2Array([WorldManager.world.topology.to_world(u.coord)])
	for c in path:
		pts.append(WorldManager.world.topology.to_world(c))
	_path.points = pts
