## Tests for GridTopology.line()/has_line_of_sight(), ported from Aevum's
## _hex_line()/has_line_of_sight() (combat_engine.py) and generalised to
## work for any topology + any blocks_sight terrain/feature. Builds a
## minimal WorldMap directly (no full game package needed).
extends GutTest

var world: WorldMap


func before_each() -> void:
	var topo := SquareIsoTopology.new()
	topo.configure({"diagonals": true, "tile_size": [64, 32]})
	topo.set_bounds(20, 20)

	var plains := TileDefinition.from_dict({"id": "plains", "domain": "land", "blocks_sight": false})
	var mountain := TileDefinition.from_dict({"id": "mountain", "domain": "land", "blocks_sight": true})
	var terrains := {"plains": plains, "mountain": mountain}

	world = WorldMap.new("test_map", topo, terrains, {})
	for x in 20:
		for y in 20:
			world.set_terrain(Vector2i(x, y), "plains")


func test_line_includes_both_endpoints() -> void:
	var pts := world.topology.line(Vector2i(0, 0), Vector2i(5, 0))
	assert_eq(pts[0], Vector2i(0, 0))
	assert_eq(pts[-1], Vector2i(5, 0))


func test_line_same_point_returns_single_tile() -> void:
	var pts := world.topology.line(Vector2i(3, 3), Vector2i(3, 3))
	assert_eq(pts, [Vector2i(3, 3)] as Array[Vector2i])


func test_has_line_of_sight_true_on_open_ground() -> void:
	assert_true(world.topology.has_line_of_sight(world, Vector2i(0, 0), Vector2i(5, 5)))


func test_has_line_of_sight_false_when_blocked_by_mountain() -> void:
	world.set_terrain(Vector2i(2, 2), "mountain")
	assert_false(world.topology.has_line_of_sight(world, Vector2i(0, 0), Vector2i(4, 4)))


func test_has_line_of_sight_ignores_blocking_terrain_at_endpoints() -> void:
	# Mountain AT the attacker's own tile must not block its own sight.
	world.set_terrain(Vector2i(0, 0), "mountain")
	assert_true(world.topology.has_line_of_sight(world, Vector2i(0, 0), Vector2i(3, 0)))


func test_has_line_of_sight_blocked_by_feature_not_just_terrain() -> void:
	var wall := TileDefinition.from_dict({"id": "wall", "blocks_sight": true}, true)
	world.feature_defs["wall"] = wall
	world.add_feature(Vector2i(2, 0), "wall")
	assert_false(world.topology.has_line_of_sight(world, Vector2i(0, 0), Vector2i(4, 0)))
