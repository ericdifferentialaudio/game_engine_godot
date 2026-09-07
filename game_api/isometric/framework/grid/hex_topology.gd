## Hex grid (Civ 5/6 style). Storage coords are offset (col,row).
##   orientation "pointy" – odd-r offset (rows shifted), Civ style.
##   orientation "flat"   – odd-q offset (columns shifted).
## Internally converts to cube coordinates for distance.
class_name HexTopology
extends GridTopology

var pointy: bool = true

const POINTY_EVEN: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const POINTY_ODD: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const FLAT_EVEN: Array[Vector2i] = [Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]
const FLAT_ODD: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


func _on_configure(cfg: Dictionary) -> void:
	pointy = str(cfg.get("orientation", "pointy")).to_lower() != "flat"
	if not cfg.has("tile_size"):
		tile_size = Vector2(64, 56) if pointy else Vector2(56, 64)


func name() -> String:
	return "hex_pointy" if pointy else "hex_flat"


func _neighbor_offsets(c: Vector2i) -> Array[Vector2i]:
	if pointy:
		return POINTY_ODD if (c.y & 1) == 1 else POINTY_EVEN
	return FLAT_ODD if (c.x & 1) == 1 else FLAT_EVEN


func to_cube(c: Vector2i) -> Vector3i:
	var q: int
	var r: int
	if pointy:
		q = c.x - ((c.y - (c.y & 1)) >> 1)
		r = c.y
	else:
		q = c.x
		r = c.y - ((c.x - (c.x & 1)) >> 1)
	return Vector3i(q, r, -q - r)


func from_cube(cube: Vector3i) -> Vector2i:
	if pointy:
		return Vector2i(cube.x + ((cube.y - (cube.y & 1)) >> 1), cube.y)
	return Vector2i(cube.x, cube.y + ((cube.x - (cube.x & 1)) >> 1))


func distance(a: Vector2i, b: Vector2i) -> int:
	if wrap_x and width > 0:
		var best := _cube_dist(a, b)
		best = mini(best, _cube_dist(a, b + Vector2i(width, 0)))
		best = mini(best, _cube_dist(a, b - Vector2i(width, 0)))
		return best
	return _cube_dist(a, b)


func _cube_dist(a: Vector2i, b: Vector2i) -> int:
	var ca := to_cube(a)
	var cb := to_cube(b)
	return maxi(absi(ca.x - cb.x), maxi(absi(ca.y - cb.y), absi(ca.z - cb.z)))


func to_world(c: Vector2i) -> Vector2:
	var w := tile_size.x
	var h := tile_size.y
	if pointy:
		var x := w * (c.x + 0.5 * (c.y & 1))
		var y := h * 0.75 * c.y
		return Vector2(x, y)
	var x := w * 0.75 * c.x
	var y := h * (c.y + 0.5 * (c.x & 1))
	return Vector2(x, y)


func to_tile(p: Vector2) -> Vector2i:
	# Fractional axial -> cube rounding.
	var w := tile_size.x
	var h := tile_size.y
	var q: float
	var r: float
	if pointy:
		r = p.y / (h * 0.75)
		q = p.x / w - 0.5 * r
	else:
		q = p.x / (w * 0.75)
		r = p.y / h - 0.5 * q
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return normalize(from_cube(Vector3i(int(rq), int(rr), int(-rq - rr))))


func tileset_shape() -> TileSet.TileShape:
	return TileSet.TILE_SHAPE_HEXAGON


func tileset_layout() -> TileSet.TileLayout:
	return TileSet.TILE_LAYOUT_STACKED_OFFSET


func tileset_offset_axis() -> TileSet.TileOffsetAxis:
	return TileSet.TILE_OFFSET_AXIS_HORIZONTAL if pointy else TileSet.TILE_OFFSET_AXIS_VERTICAL


func outline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rx := tile_size.x * 0.5
	var ry := tile_size.y * 0.5
	var start := -90.0 if pointy else 0.0
	for i in 6:
		var ang := deg_to_rad(start + 60.0 * i)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts
