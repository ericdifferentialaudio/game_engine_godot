## Terrain-cost-aware Dijkstra/A* pathfinding and road-network generation,
## engine-agnostic.
##
## Ported from Aevum: Age of Shrines (C:\Aevum\engine\engine_map_pipeline.py,
## Sprint 23 "#166" — organic roads via least-resistance Dijkstra, replacing
## an earlier ring-based approach).
##
## Kept engine-agnostic (belongs in game_core, not either graphics engine)
## because both the isometric hex grid and any future grid-based world model
## need the same "connect settlements with roads that prefer cheap terrain"
## algorithm. No dependency on [GridTopology]/[WorldMap] (both iso-only) —
## callers inject [param neighbors_fn] and [param cost_fn] Callables instead,
## the same dependency-injection pattern [code]MapGenerator.register()[/code]
## already uses in the isometric engine.
##
## [param neighbors_fn]: [code]func(coord: Vector2i) -> Array[Vector2i][/code]
## [param cost_fn]: [code]func(coord: Vector2i) -> float[/code] — cost to
## enter [param coord]; return [constant INF_COST] for impassable.
## [param heuristic_fn] (optional): [code]func(a: Vector2i, b: Vector2i) -> float[/code],
## an admissible distance estimate for A*; omit for plain Dijkstra.
class_name CoreRoadBuilder
extends RefCounted

const INF_COST: float = 1.0e9

## Direct-spoke pass: an endpoint within this many hex/tile steps of another
## gets a direct road, ensuring nearby settlements are road-connected fast
## before the slower spanning-tree pass runs.
const DEFAULT_SPOKE_RADIUS: float = 40.0

## Short stub length (in tiles) for isolated minor endpoints (Aevum's
## "villages" pass): guarantees every minor site shows an approaching trail
## even when it is too far from anything for a full spoke.
const DEFAULT_STUB_LEN: int = 3


## Terrain-aware A* from [param start] to [param goal]. Returns the path
## (excluding start, including goal), or [] if unreachable or start==goal.
static func find_path(start: Vector2i, goal: Vector2i, neighbors_fn: Callable,
		cost_fn: Callable, heuristic_fn: Callable = Callable(), max_cost: float = INF_COST) -> Array[Vector2i]:
	if start == goal:
		return []
	var use_heuristic := heuristic_fn.is_valid()
	var open: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var g: Dictionary = {start: 0.0}
	var f: Dictionary = {start: (heuristic_fn.call(start, goal) if use_heuristic else 0.0)}
	var closed: Dictionary = {}

	while not open.is_empty():
		var best_i := 0
		for i in range(1, open.size()):
			if f.get(open[i], INF_COST) < f.get(open[best_i], INF_COST):
				best_i = i
		var current: Vector2i = open[best_i]
		open.remove_at(best_i)
		if current == goal:
			return _reconstruct(came, current)
		closed[current] = true
		for n in neighbors_fn.call(current):
			var nv: Vector2i = n
			if closed.has(nv):
				continue
			var step: float = float(cost_fn.call(nv))
			if step >= INF_COST:
				continue
			var tentative: float = float(g[current]) + step
			if tentative > max_cost:
				continue
			if tentative < g.get(nv, INF_COST):
				came[nv] = current
				g[nv] = tentative
				f[nv] = tentative + (float(heuristic_fn.call(nv, goal)) if use_heuristic else 0.0)
				if nv not in open:
					open.append(nv)
	return []


static func _reconstruct(came: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came.has(current):
		current = came[current]
		path.push_front(current)
	path.remove_at(0)
	return path


## Build a full road network connecting [param endpoints] (settlements,
## enclaves, points of interest, ...), in three passes mirroring Aevum's
## organic-road pipeline:
##
##   Pass 1 (spokes) — every endpoint within [param spoke_radius] of another
##     gets a direct terrain-following road immediately, so nearby sites are
##     always connected fast.
##   Pass 2 (MST)     — greedy nearest-neighbour spanning tree over whatever
##     is still unconnected, so the full network ends up connected.
##   Pass 3 (stubs)   — any endpoint in [param minor_endpoints] with no road
##     within [param stub_check_radius] of it gets a short
##     [param stub_len]-tile trail toward its nearest neighbour, so every
##     minor site shows at least an approaching trail even when too far
##     for a full spoke.
##
## [param distance_fn]: [code]func(a: Vector2i, b: Vector2i) -> float[/code],
## a cheap distance estimate used only to pick candidates (grid distance is
## fine; the actual road follows [method find_path]'s real terrain cost).
## [param on_road_tile]: [code]func(coord: Vector2i) -> void[/code], called
## once per tile of every stamped path so the caller can mark its own tile
## data (e.g. [code]tile.has_road = true[/code]).
##
## Returns the total number of distinct tiles touched by any road.
static func build_road_network(endpoints: Array[Vector2i], minor_endpoints: Array[Vector2i],
		neighbors_fn: Callable, cost_fn: Callable, distance_fn: Callable, on_road_tile: Callable,
		spoke_radius: float = DEFAULT_SPOKE_RADIUS, stub_len: int = DEFAULT_STUB_LEN) -> int:
	var all_pts: Array[Vector2i] = []
	var seen_pts: Dictionary = {}
	for p in endpoints + minor_endpoints:
		if not seen_pts.has(p):
			seen_pts[p] = true
			all_pts.append(p)
	if all_pts.size() < 2:
		return 0

	var touched: Dictionary = {}
	var stamp := func(a: Vector2i, b: Vector2i) -> void:
		for tile in find_path(a, b, neighbors_fn, cost_fn):
			if not touched.has(tile):
				touched[tile] = true
				on_road_tile.call(tile)

	# --- Pass 1: direct spokes between anything close enough -----------------
	var seeded: Dictionary = {}
	for a in endpoints:
		for b in endpoints:
			if a == b:
				continue
			if float(distance_fn.call(a, b)) > spoke_radius:
				continue
			var key := _edge_key(a, b)
			if seeded.has(key):
				continue
			seeded[key] = true
			stamp.call(a, b)

	# --- Pass 2: greedy nearest-neighbour spanning tree over everything ------
	var connected: Array[Vector2i] = [all_pts[0]]
	var remaining: Array[Vector2i] = all_pts.slice(1)
	while not remaining.is_empty():
		var best_a := Vector2i.ZERO
		var best_b := Vector2i.ZERO
		var best_dist := INF
		for c in connected:
			for u in remaining:
				var d: float = float(distance_fn.call(c, u))
				if d < best_dist:
					best_dist = d
					best_a = c
					best_b = u
		if best_dist == INF:
			break
		stamp.call(best_a, best_b)
		connected.append(best_b)
		remaining.erase(best_b)

	# --- Pass 3: short stubs for minor endpoints with no nearby road --------
	for p in minor_endpoints:
		var has_road := false
		for c in touched:
			var cv: Vector2i = c
			if cv == p or float(distance_fn.call(p, cv)) <= 2.0:
				has_road = true
				break
		if has_road:
			continue
		var nearest := Vector2i(-999999, -999999)
		var nearest_dist := INF
		for other in all_pts:
			if other == p:
				continue
			var d: float = float(distance_fn.call(p, other))
			if d < nearest_dist:
				nearest_dist = d
				nearest = other
		if nearest == Vector2i(-999999, -999999):
			continue
		var full_path := find_path(p, nearest, neighbors_fn, cost_fn)
		for i in mini(stub_len, full_path.size()):
			var tile: Vector2i = full_path[i]
			if not touched.has(tile):
				touched[tile] = true
				on_road_tile.call(tile)

	return touched.size()


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var lo := a
	var hi := b
	if hi.x < lo.x or (hi.x == lo.x and hi.y < lo.y):
		var t := lo
		lo = hi
		hi = t
	return "%d,%d|%d,%d" % [lo.x, lo.y, hi.x, hi.y]
