## Movement-cost aware A* over the WorldMap for a specific unit.
##
## Costs come from TileDefinition.move_cost, modified by the unit's movement
## profile (EntityDefinition.movement: {"domain": "land"|"sea"|"air", "ignore_terrain": bool,
## "terrain_costs": {"forest": 1}, "impassable": ["mountain"]}). Enemy-occupied tiles
## block; tiles unexplored by the unit's faction are assumed passable at base cost
## (so players can plan into fog, like Civ).
class_name Pathfinder
extends RefCounted

const INF_COST := 1.0e9


## Returns an Array[Vector2i] path (excluding start, including goal) or [] if unreachable.
static func find_path(world: WorldMap, unit: Unit, start: Vector2i, goal: Vector2i, max_cost: float = INF_COST) -> Array[Vector2i]:
	var topo := world.topology
	if not topo.in_bounds(goal) or start == goal:
		return []
	if move_cost(world, unit, goal) >= INF_COST:
		return []
	var open := [start]
	var came := {}
	var g := {start: 0.0}
	var f := {start: float(topo.distance(start, goal))}
	var closed := {}
	while not open.is_empty():
		# Pick lowest f (open lists stay small on strategy maps).
		var best_i := 0
		for i in range(1, open.size()):
			if f.get(open[i], INF_COST) < f.get(open[best_i], INF_COST):
				best_i = i
		var current: Vector2i = open[best_i]
		open.remove_at(best_i)
		if current == goal:
			return _reconstruct(came, current)
		closed[current] = true
		for n in topo.neighbors(current):
			if closed.has(n):
				continue
			var step := move_cost(world, unit, n)
			if step >= INF_COST:
				continue
			var tentative: float = g[current] + step
			if tentative > max_cost:
				continue
			if tentative < g.get(n, INF_COST):
				came[n] = current
				g[n] = tentative
				f[n] = tentative + float(topo.distance(n, goal))
				if n not in open:
					open.append(n)
	return []


## Tiles reachable with [param budget] movement points (Dijkstra flood).
static func reachable(world: WorldMap, unit: Unit, start: Vector2i, budget: float) -> Dictionary:
	var cost := {start: 0.0}
	var frontier := [start]
	while not frontier.is_empty():
		var best_i := 0
		for i in range(1, frontier.size()):
			if cost[frontier[i]] < cost[frontier[best_i]]:
				best_i = i
		var current: Vector2i = frontier[best_i]
		frontier.remove_at(best_i)
		for n in world.topology.neighbors(current):
			var step := move_cost(world, unit, n)
			if step >= INF_COST:
				continue
			var c: float = cost[current] + step
			if c <= budget and c < cost.get(n, INF_COST):
				cost[n] = c
				if n not in frontier:
					frontier.append(n)
	cost.erase(start)
	return cost


## Cost for [param unit] to enter [param coord]; INF_COST if impassable.
static func move_cost(world: WorldMap, unit: Unit, coord: Vector2i) -> float:
	var tile := world.get_tile(coord)
	if tile == null:
		return INF_COST
	var terrain: TileDefinition = tile.terrain
	if terrain == null:
		return INF_COST
	var movement: Dictionary = unit.definition.movement if unit and unit.definition else {}
	var domain: String = movement.get("domain", "land")
	if terrain.id in movement.get("impassable", []):
		return INF_COST
	if domain != "air":
		if terrain.domain != domain and terrain.domain != "any":
			return INF_COST
		if not terrain.passable and not movement.get("ignore_terrain", false):
			return INF_COST
	# Occupancy: enemy units block, friendly units allow pass-through (no stacking end-turn is
	# enforced by Unit.move_along, not here).
	if unit:
		var occupant := world.unit_at(coord)
		if occupant and occupant != unit and occupant.faction_id != unit.faction_id:
			return INF_COST
	var cost := float(terrain.move_cost)
	if movement.get("ignore_terrain", false) or domain == "air":
		cost = 1.0
	var overrides: Dictionary = movement.get("terrain_costs", {})
	if overrides.has(terrain.id):
		cost = float(overrides[terrain.id])
	for feature_id in tile.features:
		var fdef: TileDefinition = world.feature_definition(feature_id)
		if fdef:
			cost += float(fdef.move_cost)
	if tile.has_road and movement.get("uses_roads", true):
		cost = minf(cost, float(GameManager.rule("movement.road_cost", 0.5)))
	return maxf(cost, 0.1)


static func _reconstruct(came: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came.has(current):
		current = came[current]
		path.push_front(current)
	path.remove_at(0)
	return path
