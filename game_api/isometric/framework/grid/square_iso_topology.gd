## Square grid drawn as an isometric diamond (classic 2:1 iso).
## "diagonals": true gives 8 neighbours (Chebyshev distance), else 4 (Manhattan).
class_name SquareIsoTopology
extends GridTopology

var diagonals: bool = true

const FOUR: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)]
const EIGHT: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


func _on_configure(cfg: Dictionary) -> void:
	diagonals = bool(cfg.get("diagonals", true))


func name() -> String:
	return "square_iso"


func _neighbor_offsets(_c: Vector2i) -> Array[Vector2i]:
	return EIGHT if diagonals else FOUR


func distance(a: Vector2i, b: Vector2i) -> int:
	var d := (a - b).abs()
	if wrap_x and width > 0:
		d.x = mini(d.x, width - d.x)
	return maxi(d.x, d.y) if diagonals else d.x + d.y


func to_world(c: Vector2i) -> Vector2:
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	return Vector2((c.x - c.y) * hw, (c.x + c.y) * hh)


func to_tile(p: Vector2) -> Vector2i:
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	var fx := (p.x / hw + p.y / hh) * 0.5
	var fy := (p.y / hh - p.x / hw) * 0.5
	return normalize(Vector2i(int(roundf(fx)), int(roundf(fy))))


func tileset_shape() -> TileSet.TileShape:
	return TileSet.TILE_SHAPE_ISOMETRIC


func tileset_layout() -> TileSet.TileLayout:
	return TileSet.TILE_LAYOUT_DIAMOND_DOWN


func outline() -> PackedVector2Array:
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	return PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)])
