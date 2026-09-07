## Populates a WorldMap from a MapDefinition. Two built-in strategies plus a
## registration hook for game-specific generators.
##
##  * "layout" – hand-authored rows of glyphs (MapDefinition.layout + glyphs).
##  * "noise"  – FastNoiseLite height/moisture bands:
##      {"type": "noise", "sea_level": 0.38, "mountain_level": 0.8, "frequency": 0.08,
##       "terrain_bands": [
##          {"max_height": 0.38, "terrain": "ocean"},
##          {"max_height": 0.42, "terrain": "coast"},
##          {"max_height": 0.7,  "by_moisture": [{"max": 0.3, "terrain": "desert"}, {"max": 0.6, "terrain": "plains"}, {"max": 1.0, "terrain": "grassland"}]},
##          {"max_height": 0.8,  "terrain": "hills"},
##          {"max_height": 1.0,  "terrain": "mountain"}],
##       "features": true}
##
## Custom: MapGenerator.register("my_type", Callable) where the callable takes
## (world: WorldMap, def: MapDefinition, rng: RandomNumberGenerator).
class_name MapGenerator
extends RefCounted

static var _custom: Dictionary = {}


static func register(type: String, generator: Callable) -> void:
	_custom[type] = generator


static func generate(world: WorldMap, def: MapDefinition, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + int(def.generator.get("seed_offset", 0))
	world.rng.seed = rng.seed
	world.topology.set_bounds(def.size.x, def.size.y)
	world.fog_mode = def.fog_mode
	var type: String = def.generator.get("type", "layout" if not def.layout.is_empty() else "noise")
	if _custom.has(type):
		_custom[type].call(world, def, rng)
	elif type == "layout" or not def.layout.is_empty():
		_from_layout(world, def)
	else:
		_from_noise(world, def, rng)
	if def.generator.get("features", true):
		_place_features(world, rng)


static func _from_layout(world: WorldMap, def: MapDefinition) -> void:
	var fallback := _first_terrain(world)
	for y in def.layout.size():
		var row := def.layout[y]
		for x in row.length():
			var glyph := row[x]
			var terrain: String = def.glyphs.get(glyph, "")
			if terrain == "" or not world.terrain_defs.has(terrain):
				if terrain != "":
					push_warning("MapGenerator: glyph '%s' -> unknown terrain '%s'" % [glyph, terrain])
				terrain = fallback
			world.set_terrain(Vector2i(x, y), terrain)


static func _from_noise(world: WorldMap, def: MapDefinition, rng: RandomNumberGenerator) -> void:
	var g := def.generator
	var height := FastNoiseLite.new()
	height.seed = rng.randi()
	height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height.frequency = float(g.get("frequency", 0.08))
	height.fractal_octaves = 4
	var moisture := FastNoiseLite.new()
	moisture.seed = rng.randi()
	moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture.frequency = float(g.get("moisture_frequency", 0.05))
	var bands: Array = g.get("terrain_bands", _default_bands(world))
	var edge_falloff := float(g.get("edge_falloff", 0.35))
	var fallback := _first_terrain(world)
	for y in def.size.y:
		for x in def.size.x:
			var h := (height.get_noise_2d(x, y) + 1.0) * 0.5
			if edge_falloff > 0.0 and not world.topology.wrap_x:
				var ex := minf(float(x), float(def.size.x - 1 - x)) / float(def.size.x)
				var ey := minf(float(y), float(def.size.y - 1 - y)) / float(def.size.y)
				var e := clampf(minf(ex, ey) / edge_falloff, 0.0, 1.0)
				h *= lerpf(0.4, 1.0, e)
			elif edge_falloff > 0.0:
				var ey := minf(float(y), float(def.size.y - 1 - y)) / float(def.size.y)
				h *= lerpf(0.4, 1.0, clampf(ey / edge_falloff, 0.0, 1.0))
			var m := (moisture.get_noise_2d(x, y) + 1.0) * 0.5
			var terrain := _pick_band(bands, h, m, fallback)
			world.set_terrain(Vector2i(x, y), terrain)


static func _pick_band(bands: Array, h: float, m: float, fallback: String) -> String:
	for band in bands:
		if h <= float(band.get("max_height", 1.0)):
			if band.has("by_moisture"):
				for mb in band["by_moisture"]:
					if m <= float(mb.get("max", 1.0)):
						return mb.get("terrain", fallback)
				return fallback
			return band.get("terrain", fallback)
	return fallback


static func _default_bands(world: WorldMap) -> Array:
	# Derive a sensible band list from whatever terrains exist, ordered by elevation.
	var land: Array = []
	var sea: Array = []
	for t in world.terrain_defs.values():
		(sea if t.domain == "sea" else land).append(t)
	land.sort_custom(func(a, b): return a.elevation < b.elevation)
	var out := []
	if not sea.is_empty():
		out.append({"max_height": 0.4, "terrain": sea[0].id})
	var span := 0.6 / maxf(1.0, float(land.size()))
	for i in land.size():
		out.append({"max_height": 0.4 + span * (i + 1), "terrain": land[i].id})
	if out.is_empty():
		out.append({"max_height": 1.0, "terrain": _first_terrain(world)})
	return out


static func _place_features(world: WorldMap, rng: RandomNumberGenerator) -> void:
	for fdef in world.feature_defs.values():
		if fdef.spawn_chance <= 0.0:
			continue
		for tile in world.tiles.values():
			if not fdef.allowed_on.is_empty() and tile.terrain.id not in fdef.allowed_on:
				continue
			if rng.randf() < fdef.spawn_chance:
				tile.features.append(fdef.id)


static func _first_terrain(world: WorldMap) -> String:
	for id in world.terrain_defs:
		return id
	return ""


## Find a free, passable land tile near a preferred coordinate (for spawns).
static func find_land_near(world: WorldMap, preferred: Vector2i, max_radius: int = 12) -> Vector2i:
	for r in range(0, max_radius + 1):
		for c in world.topology.ring(preferred, r):
			if is_free_land(world, c):
				return c
	return preferred


static func is_free_land(world: WorldMap, c: Vector2i) -> bool:
	var t := world.get_tile(c)
	return t != null and t.terrain != null and t.terrain.passable and t.terrain.domain == "land" and world.unit_at(c) == null


## Build a road network connecting [param endpoints] (major sites — always
## get direct spokes to each other) and [param minor_endpoints] (settlements
## that only need a short approach stub if nothing else reached them),
## using [CoreRoadBuilder]'s terrain-cost-aware Dijkstra/A* (ported from
## Aevum: Age of Shrines' organic-road pipeline). Marks [code]tile.has_road[/code]
## on every touched tile. Returns the number of tiles touched.
static func build_roads(world: WorldMap, unit: Unit, endpoints: Array[Vector2i],
		minor_endpoints: Array[Vector2i] = [], spoke_radius: float = CoreRoadBuilder.DEFAULT_SPOKE_RADIUS,
		stub_len: int = CoreRoadBuilder.DEFAULT_STUB_LEN) -> int:
	var neighbors_fn := func(c: Vector2i) -> Array[Vector2i]:
		return world.topology.neighbors(c)
	var cost_fn := func(c: Vector2i) -> float:
		return Pathfinder.move_cost(world, unit, c)
	var distance_fn := func(a: Vector2i, b: Vector2i) -> float:
		return float(world.topology.distance(a, b))
	var on_road_tile := func(c: Vector2i) -> void:
		var tile := world.get_tile(c)
		if tile and tile.terrain and tile.terrain.domain != "sea":
			tile.has_road = true
	return CoreRoadBuilder.build_road_network(
		endpoints, minor_endpoints, neighbors_fn, cost_fn, distance_fn, on_road_tile,
		spoke_radius, stub_len
	)


## Find a good *start* location: free land with at least [param min_land_neighbors]
## passable land tiles within radius 2 so factions never start on a one-tile islet.
static func find_start_near(world: WorldMap, preferred: Vector2i, min_land_neighbors: int = 6, max_radius: int = 16) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -1
	for r in range(0, max_radius + 1):
		for c in world.topology.ring(preferred, r):
			if not is_free_land(world, c):
				continue
			var land := 0
			for n in world.topology.ring(c, 2):
				if n != c:
					var t := world.get_tile(n)
					if t and t.terrain and t.terrain.passable and t.terrain.domain == "land":
						land += 1
			if land >= min_land_neighbors:
				return c
			if land > best_score:
				best_score = land
				best = c
	return best if best != Vector2i(-1, -1) else find_land_near(world, preferred, max_radius)
