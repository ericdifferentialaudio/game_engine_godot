## Abstract grid geometry. Everything that touches coordinates (neighbours,
## distance, rings, screen<->tile) goes through a topology so a game can pick
## hex or square-isometric in game.json without touching gameplay code.
##
## Tiles are always addressed as Vector2i "storage" coordinates:
##   hex        – offset coordinates (col, row), odd-r (pointy) or odd-q (flat)
##   square_iso – plain (x, y) grid coordinates drawn as a diamond
class_name GridTopology
extends RefCounted

var width: int = 0
var height: int = 0
var wrap_x: bool = false
var tile_size := Vector2(64, 32)   ## Pixel footprint of one tile on screen.


func configure(cfg: Dictionary) -> void:
	wrap_x = bool(cfg.get("wrap_x", false))
	var ts: Array = cfg.get("tile_size", [64, 32])
	tile_size = Vector2(float(ts[0]), float(ts[1]))
	_on_configure(cfg)


func _on_configure(_cfg: Dictionary) -> void:
	pass


func set_bounds(w: int, h: int) -> void:
	width = w
	height = h


func name() -> String:
	return "abstract"


func in_bounds(c: Vector2i) -> bool:
	if c.y < 0 or c.y >= height:
		return false
	if wrap_x:
		return true
	return c.x >= 0 and c.x < width


## Normalise a coordinate for wrap-around worlds.
func normalize(c: Vector2i) -> Vector2i:
	if wrap_x and width > 0:
		return Vector2i(posmod(c.x, width), c.y)
	return c


func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in _neighbor_offsets(c):
		var n := normalize(c + d)
		if in_bounds(n):
			out.append(n)
	return out


func _neighbor_offsets(_c: Vector2i) -> Array[Vector2i]:
	return []


func distance(_a: Vector2i, _b: Vector2i) -> int:
	return 0


## All in-bounds coordinates within [param radius] (inclusive) of centre.
func ring(centre: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var visited := {centre: true}
	var frontier: Array[Vector2i] = [centre]
	out.append(centre)
	for _i in radius:
		var next: Array[Vector2i] = []
		for c in frontier:
			for n in neighbors(c):
				if not visited.has(n):
					visited[n] = true
					next.append(n)
					out.append(n)
		frontier = next
	return out


## Tile -> pixel centre in world space.
func to_world(_c: Vector2i) -> Vector2:
	return Vector2.ZERO


## Pixel world position -> tile coordinate (nearest).
func to_tile(_p: Vector2) -> Vector2i:
	return Vector2i.ZERO


## Direction index (0..N-1) from a to adjacent b, for unit facing sprites.
func facing(a: Vector2i, b: Vector2i) -> int:
	var offs := _neighbor_offsets(a)
	var d := b - a
	if wrap_x and width > 0:
		if d.x > width / 2:
			d.x -= width
		elif d.x < -width / 2:
			d.x += width
	for i in offs.size():
		if offs[i] == d:
			return i
	return 0


func facing_count() -> int:
	return _neighbor_offsets(Vector2i.ZERO).size()


## Godot TileSet shape/layout hints so WorldRenderer can build TileMapLayers.
func tileset_shape() -> TileSet.TileShape:
	return TileSet.TILE_SHAPE_SQUARE


func tileset_layout() -> TileSet.TileLayout:
	return TileSet.TILE_LAYOUT_STACKED


func tileset_offset_axis() -> TileSet.TileOffsetAxis:
	return TileSet.TILE_OFFSET_AXIS_HORIZONTAL


## Polygon outline (local pixels around the tile centre) for cursors/overlays.
func outline() -> PackedVector2Array:
	return PackedVector2Array()


static func create(cfg: Dictionary) -> GridTopology:
	var kind := str(cfg.get("topology", "hex")).to_lower()
	var topo: GridTopology
	match kind:
		"square_iso", "iso", "square":
			topo = SquareIsoTopology.new()
		_:
			topo = HexTopology.new()
	topo.configure(cfg)
	return topo
