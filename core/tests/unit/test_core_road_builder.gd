## Tests for CoreRoadBuilder (ported from Aevum's engine_map_pipeline.py
## Dijkstra/A* road-network builder). Uses a small synthetic square grid via
## Callables, so this runs with no graphics engine and no GridTopology/
## WorldMap dependency, proving the module is truly engine-agnostic.
extends GutTest

const INF_COST := CoreRoadBuilder.INF_COST
const GRID_W := 10
const GRID_H := 10

var _blocked: Dictionary   ## Vector2i -> true for impassable tiles


func before_each() -> void:
	_blocked = {}


func _neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n: Vector2i = c + d
		if n.x >= 0 and n.x < GRID_W and n.y >= 0 and n.y < GRID_H:
			out.append(n)
	return out


func _cost(c: Vector2i) -> float:
	if _blocked.has(c):
		return INF_COST
	return 1.0


func _manhattan(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


# --- find_path() -------------------------------------------------------------------

func test_find_path_returns_empty_for_same_start_and_goal() -> void:
	var path := CoreRoadBuilder.find_path(Vector2i(1, 1), Vector2i(1, 1), _neighbors, _cost)
	assert_eq(path, [] as Array[Vector2i])


func test_find_path_finds_a_route_on_open_grid() -> void:
	var path := CoreRoadBuilder.find_path(Vector2i(0, 0), Vector2i(3, 3), _neighbors, _cost)
	assert_eq(path[-1], Vector2i(3, 3))
	assert_eq(path.size(), 6)   # Manhattan distance 6 at cost 1/step


func test_find_path_returns_empty_when_goal_is_impassable() -> void:
	_blocked[Vector2i(2, 2)] = true
	var path := CoreRoadBuilder.find_path(Vector2i(0, 0), Vector2i(2, 2), _neighbors, _cost)
	assert_eq(path, [] as Array[Vector2i])


func test_find_path_routes_around_a_wall() -> void:
	# Wall across column x=2, leaving a gap at y=5.
	for y in GRID_H:
		if y != 5:
			_blocked[Vector2i(2, y)] = true
	var path := CoreRoadBuilder.find_path(Vector2i(0, 0), Vector2i(4, 0), _neighbors, _cost)
	assert_true(path.has(Vector2i(2, 5)), "path must detour through the only gap")
	assert_eq(path[-1], Vector2i(4, 0))


func test_find_path_prefers_cheaper_terrain() -> void:
	# Row y=0 is expensive (cost 5/tile); row y=1 is cheap (cost 1/tile).
	# The direct route along y=0 costs 5*5=25; detouring down to y=1 and back
	# costs 6*1+5=11, so a cost-aware search must avoid travelling along y=0.
	var cost_fn := func(c: Vector2i) -> float:
		return 5.0 if c.y == 0 else 1.0
	var path := CoreRoadBuilder.find_path(Vector2i(0, 0), Vector2i(5, 0), _neighbors, cost_fn)
	assert_false(path.has(Vector2i(2, 0)),
		"A* must detour around the expensive row rather than crossing it directly")


func test_find_path_respects_max_cost() -> void:
	var path := CoreRoadBuilder.find_path(Vector2i(0, 0), Vector2i(9, 9), _neighbors, _cost, Callable(), 3.0)
	assert_eq(path, [] as Array[Vector2i])


func test_find_path_with_heuristic_matches_without() -> void:
	var no_heuristic := CoreRoadBuilder.find_path(Vector2i(0, 0), Vector2i(5, 5), _neighbors, _cost)
	var with_heuristic := CoreRoadBuilder.find_path(Vector2i(0, 0), Vector2i(5, 5), _neighbors, _cost, _manhattan)
	assert_eq(no_heuristic.size(), with_heuristic.size())
	assert_eq(no_heuristic[-1], with_heuristic[-1])


# --- build_road_network() -----------------------------------------------------------

func test_build_road_network_needs_at_least_two_points() -> void:
	var touched: Dictionary = {}
	var on_tile := func(c: Vector2i) -> void: touched[c] = true
	var count := CoreRoadBuilder.build_road_network(
		[Vector2i(0, 0)], [], _neighbors, _cost, _manhattan, on_tile)
	assert_eq(count, 0)
	assert_true(touched.is_empty())


func test_build_road_network_connects_all_major_endpoints() -> void:
	var touched: Dictionary = {}
	var on_tile := func(c: Vector2i) -> void: touched[c] = true
	var endpoints: Array[Vector2i] = [Vector2i(0, 0), Vector2i(9, 0), Vector2i(0, 9)]
	CoreRoadBuilder.build_road_network(endpoints, [], _neighbors, _cost, _manhattan, on_tile)
	for e in endpoints:
		assert_true(touched.has(e), "endpoint %s must be on the road network" % e)


func test_build_road_network_spanning_tree_reaches_far_endpoint_beyond_spoke_radius() -> void:
	var touched: Dictionary = {}
	var on_tile := func(c: Vector2i) -> void: touched[c] = true
	var endpoints: Array[Vector2i] = [Vector2i(0, 0), Vector2i(9, 9)]
	# Spoke radius 1 is far too small for a direct spoke; the MST pass must
	# still connect it since it is the only other endpoint.
	CoreRoadBuilder.build_road_network(endpoints, [], _neighbors, _cost, _manhattan, on_tile, 1.0)
	assert_true(touched.has(Vector2i(9, 9)))


func test_build_road_network_gives_isolated_minor_endpoint_a_stub() -> void:
	var touched: Dictionary = {}
	var on_tile := func(c: Vector2i) -> void: touched[c] = true
	var endpoints: Array[Vector2i] = [Vector2i(0, 0)]
	var minor: Array[Vector2i] = [Vector2i(9, 9)]
	CoreRoadBuilder.build_road_network(endpoints, minor, _neighbors, _cost, _manhattan, on_tile, 40.0, 3)
	# Stub is capped at 3 tiles of the path toward the nearest endpoint —
	# the isolated minor endpoint itself should get a visible approach trail.
	assert_true(touched.size() > 0)


func test_build_road_network_skips_minor_endpoint_already_near_a_road() -> void:
	# Two major endpoints far apart (spoke_radius=0 disables spokes, so only
	# the MST connects them) stamp a straight road through (2,0). A minor
	# endpoint at (2,1) is within 2 tiles of that road, so pass 3 must add no
	# further tiles for it; a minor endpoint at (9,9) (far from any road) must
	# still get a stub.
	var endpoints: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 0)]

	var touched_near: Dictionary = {}
	var on_tile_near := func(c: Vector2i) -> void: touched_near[c] = true
	var near_count := CoreRoadBuilder.build_road_network(
		endpoints, [Vector2i(2, 1)], _neighbors, _cost, _manhattan, on_tile_near, 0.0)

	var touched_far: Dictionary = {}
	var on_tile_far := func(c: Vector2i) -> void: touched_far[c] = true
	var far_count := CoreRoadBuilder.build_road_network(
		endpoints, [Vector2i(9, 9)], _neighbors, _cost, _manhattan, on_tile_far, 0.0)

	assert_lt(near_count, far_count,
		"a minor endpoint already near a road must add fewer tiles than a distant, unconnected one")
