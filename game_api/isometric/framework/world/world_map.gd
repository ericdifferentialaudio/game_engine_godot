## Pure data model of one map: tiles, features, ownership, occupancy and
## per-faction fog-of-war. No rendering here; WorldRenderer observes it.
class_name WorldMap
extends RefCounted

## Visibility levels per faction per tile.
enum Vis { UNEXPLORED, EXPLORED, VISIBLE }


class Tile:
	var coord: Vector2i
	var terrain: TileDefinition
	var features: Array[String] = []
	var improvements: Array[String] = []
	var has_road: bool = false
	var owner_id: String = ""
	var site_id: String = ""
	var resource_id: String = ""
	var elevation: int = 0
	var metadata: Dictionary = {}

	func yields(feature_defs: Dictionary) -> Dictionary:
		var out := terrain.yields.duplicate() if terrain else {}
		for f in features:
			var fd: TileDefinition = feature_defs.get(f)
			if fd:
				for k in fd.yields:
					out[k] = out.get(k, 0) + fd.yields[k]
		return out

	func to_dict() -> Dictionary:
		return {
			"t": terrain.id if terrain else "", "f": features.duplicate(), "i": improvements.duplicate(),
			"r": has_road, "o": owner_id, "s": site_id, "res": resource_id, "e": elevation, "m": metadata,
		}


var map_id: String = ""
var topology: GridTopology
var tiles: Dictionary = {}          ## Vector2i -> Tile
var terrain_defs: Dictionary = {}   ## id -> TileDefinition
var feature_defs: Dictionary = {}   ## id -> TileDefinition
var fog: Dictionary = {}            ## faction_id -> Dictionary[Vector2i -> Vis]
var fog_mode: String = "full"
var _occupancy: Dictionary = {}     ## Vector2i -> Array[Unit]
var rng := RandomNumberGenerator.new()


func _init(p_map_id: String, p_topology: GridTopology, terrains: Dictionary, features: Dictionary) -> void:
	map_id = p_map_id
	topology = p_topology
	terrain_defs = terrains
	feature_defs = features


func width() -> int:
	return topology.width


func height() -> int:
	return topology.height


# --- Tiles -----------------------------------------------------------------------

func set_terrain(coord: Vector2i, terrain_id: String) -> Tile:
	var def: TileDefinition = terrain_defs.get(terrain_id)
	if def == null:
		push_error("WorldMap: unknown terrain '%s'" % terrain_id)
		return null
	var t: Tile = tiles.get(coord)
	if t == null:
		t = Tile.new()
		t.coord = coord
		tiles[coord] = t
	t.terrain = def
	t.elevation = def.elevation
	return t


func get_tile(coord: Vector2i) -> Tile:
	return tiles.get(topology.normalize(coord))


func terrain_definition(id: String) -> TileDefinition:
	return terrain_defs.get(id)


func feature_definition(id: String) -> TileDefinition:
	return feature_defs.get(id)


func add_feature(coord: Vector2i, feature_id: String) -> void:
	var t := get_tile(coord)
	if t and feature_defs.has(feature_id) and feature_id not in t.features:
		t.features.append(feature_id)
		EventBus.tile_changed.emit(coord, "features")


func remove_feature(coord: Vector2i, feature_id: String) -> void:
	var t := get_tile(coord)
	if t and t.features.has(feature_id):
		t.features.erase(feature_id)
		EventBus.tile_changed.emit(coord, "features")


func set_owner(coord: Vector2i, faction_id: String) -> void:
	var t := get_tile(coord)
	if t == null or t.owner_id == faction_id:
		return
	var old := t.owner_id
	t.owner_id = faction_id
	EventBus.tile_owner_changed.emit(coord, old, faction_id)
	EventBus.tile_changed.emit(coord, "owner")


func owner_of(coord: Vector2i) -> String:
	var t := get_tile(coord)
	return t.owner_id if t else ""


func blocks_sight(coord: Vector2i) -> bool:
	var t := get_tile(coord)
	if t == null:
		return true
	if t.terrain and t.terrain.blocks_sight:
		return true
	for f in t.features:
		var fd: TileDefinition = feature_defs.get(f)
		if fd and fd.blocks_sight:
			return true
	return false


func all_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in tiles.keys():
		out.append(c)
	return out


# --- Occupancy --------------------------------------------------------------------

func place_unit(unit: Unit, coord: Vector2i) -> void:
	remove_unit(unit)
	coord = topology.normalize(coord)
	if not _occupancy.has(coord):
		_occupancy[coord] = []
	_occupancy[coord].append(unit)
	unit.coord = coord


func remove_unit(unit: Unit) -> void:
	var list: Array = _occupancy.get(unit.coord, [])
	list.erase(unit)
	if list.is_empty():
		_occupancy.erase(unit.coord)


func units_at(coord: Vector2i) -> Array:
	return _occupancy.get(topology.normalize(coord), [])


func unit_at(coord: Vector2i) -> Unit:
	var list := units_at(coord)
	return list[0] if not list.is_empty() else null



# --- Fog of war -----------------------------------------------------------------

func _fog_for(faction_id: String) -> Dictionary:
	if not fog.has(faction_id):
		fog[faction_id] = {}
	return fog[faction_id]


func visibility(faction_id: String, coord: Vector2i) -> Vis:
	if fog_mode == "none":
		return Vis.VISIBLE
	return fog.get(faction_id, {}).get(topology.normalize(coord), Vis.UNEXPLORED)


func is_visible(faction_id: String, coord: Vector2i) -> bool:
	return visibility(faction_id, coord) == Vis.VISIBLE


func is_explored(faction_id: String, coord: Vector2i) -> bool:
	return visibility(faction_id, coord) != Vis.UNEXPLORED


## Downgrade all VISIBLE to EXPLORED (start of a recompute).
func clear_visible(faction_id: String) -> void:
	var f := _fog_for(faction_id)
	for c in f:
		if f[c] == Vis.VISIBLE:
			f[c] = Vis.EXPLORED


## Reveal coords at a level; returns coords whose level increased.
func reveal(faction_id: String, coords: Array, level: Vis = Vis.VISIBLE) -> Array[Vector2i]:
	var f := _fog_for(faction_id)
	var changed: Array[Vector2i] = []
	for c in coords:
		var n: Vector2i = topology.normalize(c)
		if not tiles.has(n):
			continue
		if int(f.get(n, Vis.UNEXPLORED)) < int(level):
			f[n] = level
			changed.append(n)
	return changed


## Sight flood from an origin with a sight budget. Blocking terrain/features are
## themselves visible but stop further propagation unless the observer stands
## on higher elevation (simple, fast, good enough for strategy scale).
func compute_sight(origin: Vector2i, sight: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [origin]
	var origin_tile := get_tile(origin)
	var origin_elev := origin_tile.elevation if origin_tile else 0
	var cost := {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if cost[current] >= sight:
			continue
		if current != origin and blocks_sight(current):
			var cur_tile := get_tile(current)
			if cur_tile and cur_tile.elevation >= origin_elev:
				continue
		for n in topology.neighbors(current):
			var nt := get_tile(n)
			if nt == null:
				continue
			var step := 1 + maxi(0, (nt.terrain.sight_cost if nt.terrain else 1) - 1)
			var c: int = cost[current] + step
			if c <= sight and c < cost.get(n, 1 << 30):
				cost[n] = c
				if n not in out:
					out.append(n)
				frontier.append(n)
	return out


# --- Serialisation ---------------------------------------------------------------

func to_save_data() -> Dictionary:
	var t := {}
	for c in tiles:
		t["%d,%d" % [c.x, c.y]] = tiles[c].to_dict()
	var f := {}
	for fid in fog:
		var entries := {}
		for c in fog[fid]:
			entries["%d,%d" % [c.x, c.y]] = int(fog[fid][c])
		f[fid] = entries
	return {"map_id": map_id, "w": topology.width, "h": topology.height, "tiles": t, "fog": f, "fog_mode": fog_mode}


func from_save_data(d: Dictionary) -> void:
	tiles.clear()
	fog.clear()
	_occupancy.clear()
	fog_mode = d.get("fog_mode", "full")
	topology.set_bounds(int(d.get("w", 0)), int(d.get("h", 0)))
	for key in d.get("tiles", {}):
		var c := _parse_coord(key)
		var td: Dictionary = d["tiles"][key]
		var t := set_terrain(c, td.get("t", ""))
		if t == null:
			continue
		t.features.assign(td.get("f", []))
		t.improvements.assign(td.get("i", []))
		t.has_road = bool(td.get("r", false))
		t.owner_id = td.get("o", "")
		t.site_id = td.get("s", "")
		t.resource_id = td.get("res", "")
		t.elevation = int(td.get("e", 0))
		t.metadata = td.get("m", {})
	for fid in d.get("fog", {}):
		var entries := {}
		for key in d["fog"][fid]:
			entries[_parse_coord(key)] = int(d["fog"][fid][key]) as Vis
		fog[fid] = entries


static func _parse_coord(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
