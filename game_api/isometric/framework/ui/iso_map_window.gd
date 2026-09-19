## A real minimap for the isometric engine.
##
## `CoreMapWindow` keeps only the *model* of what is on a map — marker ids and
## their normalised positions — and draws simple labelled buttons, which is
## enough to be testable with no engine present. This subclass supplies the
## engine half: the actual terrain, fog and unit positions of the live
## `WorldMap`, painted with `TileDefinition.color` (already documented as the
## "blockout / minimap colour", so no new data is needed).
##
## Register it in a layout exactly like the base window, with `role: "map"`.
## Everything that talks to it — `set_marker()`, `focus()`, the registry's
## `marker_activated` relay — is inherited and unchanged, so game code never
## learns which of the two is installed.
class_name IsoMapWindow
extends CoreMapWindow

## Faction whose fog of war the minimap is drawn through. Empty means the
## current player faction, resolved lazily so the window can be built before
## `GameManager` has one.
@export var viewer_faction: String = ""

## Unexplored tiles are skipped entirely; explored-but-not-visible tiles are
## dimmed by this much. A remembered coastline should read as *remembered*.
@export var explored_dim: float = 0.45

## Redraw at most this often. The minimap follows the whole world, so a naive
## redraw on every unit move is the obvious performance trap.
@export var max_redraw_hz: float = 10.0

var _terrain: Control
var _last_draw_msec: int = 0
var _pending: bool = false


func _build() -> void:
	super()
	# The terrain layer goes *behind* the marker canvas the base class made,
	# so inherited markers keep working and stay on top.
	_terrain = Control.new()
	_terrain.name = "TerrainLayer"
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_terrain.draw.connect(_draw_terrain)
	add_child(_terrain)
	move_child(_terrain, 0)

	resized.connect(_request_redraw)


func _ready() -> void:
	super()
	# Follow the world rather than making every caller remember to refresh.
	EventBus.visibility_changed.connect(func(_f, _r): _request_redraw())
	EventBus.unit_moved.connect(func(_u, _a, _b): _request_redraw())
	EventBus.unit_died.connect(func(_u, _k): _request_redraw())
	EventBus.tile_owner_changed.connect(func(_c, _a, _b): _request_redraw())
	EventBus.turn_started.connect(func(_t): _request_redraw())
	EventBus.world_loaded.connect(func(_m, _d): _request_redraw())


## Repaint, rate-limited. Safe to call as often as you like.
func refresh() -> void:
	_request_redraw()


func _request_redraw() -> void:
	if _pending:
		return
	var interval := int(1000.0 / maxf(1.0, max_redraw_hz))
	var since := Time.get_ticks_msec() - _last_draw_msec
	if since >= interval:
		_redraw_now()
		return
	_pending = true
	get_tree().create_timer((interval - since) / 1000.0).timeout.connect(_redraw_now)


func _redraw_now() -> void:
	_pending = false
	_last_draw_msec = Time.get_ticks_msec()
	if is_instance_valid(_terrain):
		_terrain.queue_redraw()


# --- Painting -----------------------------------------------------------------

func _draw_terrain() -> void:
	var world = _world()
	if world == null or world.tiles.is_empty():
		return

	var faction := _viewer()
	var cols: int = maxi(1, world.width())
	var rows: int = maxi(1, world.height())
	var area := _terrain.size
	# One cell per tile, square, centred: an aspect-correct minimap of a
	# non-square window must letterbox rather than stretch the world.
	var cell := minf(area.x / float(cols), area.y / float(rows))
	var origin := Vector2(
			(area.x - cell * cols) * 0.5,
			(area.y - cell * rows) * 0.5)
	var size := Vector2(cell, cell).ceil()

	for coord in world.tiles:
		var tile = world.tiles[coord]
		var vis: int = world.visibility(faction, coord)
		if vis == WorldMap.Vis.UNEXPLORED:
			continue
		var colour: Color = tile.terrain.color if tile.terrain != null else Color.DIM_GRAY
		if tile.has_road:
			colour = colour.lightened(0.25)
		if vis != WorldMap.Vis.VISIBLE:
			colour = colour.darkened(explored_dim)
		var at := origin + Vector2(coord.x, coord.y) * cell
		_terrain.draw_rect(Rect2(at, size), colour, true)

	_draw_units(world, faction, origin, cell)


## Units as faction-coloured pips on top of the terrain.
func _draw_units(world, faction: String, origin: Vector2, cell: float) -> void:
	var radius := maxf(1.0, cell * 0.3)
	for unit in EntityRegistry.units.values():
		if unit == null or not unit.alive:
			continue
		# Fog applies to the minimap too: you see your own units, and enemies
		# only where you currently have vision. A minimap that leaks positions
		# would quietly undo the whole fog-of-war system.
		if not world.is_visible(faction, unit.coord):
			continue
		var centre := origin + (Vector2(unit.coord.x, unit.coord.y) + Vector2(0.5, 0.5)) * cell
		_terrain.draw_circle(centre, radius, _faction_color(unit.faction_id))


func _faction_color(faction_id: String) -> Color:
	var faction := FactionRegistry.get_faction(faction_id)
	return faction.color if faction != null else Color.WHITE


# --- Coordinate mapping -------------------------------------------------------

## Tile under a normalised 0..1 point, or null when the world has none there.
## Lets callers turn a click on the minimap into a real map coordinate.
func coord_at(normalised: Vector2):
	var world = _world()
	if world == null:
		return null
	var coord := Vector2i(
			int(normalised.x * world.width()),
			int(normalised.y * world.height()))
	return coord if world.tiles.has(coord) else null


## Inverse of [method coord_at]: where a tile sits, 0..1, for `set_marker()`.
func normalised_of(coord: Vector2i) -> Vector2:
	var world = _world()
	if world == null:
		return Vector2(0.5, 0.5)
	return Vector2(
			(coord.x + 0.5) / maxf(1.0, world.width()),
			(coord.y + 0.5) / maxf(1.0, world.height()))


func describe() -> String:
	var world = _world()
	var tiles: int = world.tiles.size() if world != null else 0
	return "%s: %d markers over %d tiles" % [role, marker_count(), tiles]


func _world():
	return WorldManager.world


func _viewer() -> String:
	if viewer_faction != "":
		return viewer_faction
	return GameManager.player_faction_id
