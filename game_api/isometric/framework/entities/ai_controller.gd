## Per-unit AI behaviour selected by EntityDefinition.ai_profile (ai_profiles.json).
##
## {"profiles": {
##    "idle":     {"behavior": "idle"},
##    "wander":   {"behavior": "wander", "radius": 3},
##    "guard":    {"behavior": "guard", "radius": 1, "attack_range": 1},
##    "explorer": {"behavior": "explore"},
##    "hunter":   {"behavior": "hunt", "sight_bonus": 1, "flee_below_health": 0.25},
##    "schedule": {"behavior": "schedule"}
##  },
##  "abilities": { ...AbilitySet catalog... }}
##
## Games register custom behaviours with AIController.register_behavior(name, Callable(unit, profile, rng)).
## Faction-level AI (production, diplomacy) lives in Faction.run_ai_turn; this file is unit-level.
class_name AIController
extends RefCounted

static var profiles: Dictionary = {}
static var _custom: Dictionary = {}


static func register_behavior(behavior: String, fn: Callable) -> void:
	_custom[behavior] = fn


static func act(unit: Unit, rng: RandomNumberGenerator) -> void:
	var profile: Dictionary = profiles.get(unit.definition.ai_profile, {})
	var behavior: String = profile.get("behavior", "idle" if unit.definition.kind != "monster" else "guard")
	if _custom.has(behavior):
		_custom[behavior].call(unit, profile, rng)
		return
	match behavior:
		"wander":
			_wander(unit, int(profile.get("radius", 3)), rng)
		"guard":
			_guard(unit, profile, rng)
		"explore":
			_explore(unit, rng)
		"hunt":
			_hunt(unit, profile, rng)
		"schedule":
			_schedule(unit)
		_:
			pass


static func _nearest_enemy(unit: Unit, max_dist: int) -> Unit:
	var world := WorldManager.world
	var best: Unit = null
	var best_d := max_dist + 1
	for other in EntityRegistry.units_on_map(unit.map_id):
		if other == unit or not FactionRegistry.are_hostile(unit.faction_id, other.faction_id):
			continue
		var d := world.topology.distance(unit.coord, other.coord)
		if d < best_d:
			best_d = d
			best = other
	return best


static func _wander(unit: Unit, radius: int, rng: RandomNumberGenerator) -> void:
	var world := WorldManager.world
	var home: Vector2i = unit.home_coord
	var options := Pathfinder.reachable(world, unit, unit.coord, unit.action_points)
	var keys := options.keys()
	keys.shuffle()
	for c in keys:
		if world.topology.distance(home, c) <= radius and world.unit_at(c) == null:
			unit.move_to(c)
			return


static func _guard(unit: Unit, profile: Dictionary, rng: RandomNumberGenerator) -> void:
	var enemy := _nearest_enemy(unit, int(profile.get("attack_range", 1)) + int(profile.get("radius", 1)))
	if enemy:
		if WorldManager.world.topology.distance(unit.coord, enemy.coord) <= 1:
			unit.attack(enemy)
		else:
			unit.move_toward_target(enemy.coord)
			if WorldManager.world.topology.distance(unit.coord, enemy.coord) <= 1 and unit.action_points > 0:
				unit.attack(enemy)
	elif profile.get("radius", 1) > 0 and rng.randf() < 0.3:
		_wander(unit, int(profile.get("radius", 1)), rng)


static func _explore(unit: Unit, rng: RandomNumberGenerator) -> void:
	var world := WorldManager.world
	var options := Pathfinder.reachable(world, unit, unit.coord, unit.action_points)
	var best: Vector2i = unit.coord
	var best_score := -1
	for c in options:
		if world.unit_at(c) != null:
			continue
		var score := 0
		for n in world.topology.ring(c, unit.sight_range()):
			if not world.is_explored(unit.faction_id, n):
				score += 1
		score += rng.randi_range(0, 2)
		if score > best_score:
			best_score = score
			best = c
	if best != unit.coord:
		unit.move_to(best)


static func _hunt(unit: Unit, profile: Dictionary, rng: RandomNumberGenerator) -> void:
	var hp_frac := unit.stats.get_value("health") / maxf(1.0, unit.stats.max_value("health"))
	if hp_frac < float(profile.get("flee_below_health", 0.0)):
		_wander(unit, 6, rng)
		return
	var enemy := _nearest_enemy(unit, unit.sight_range() + int(profile.get("sight_bonus", 0)))
	if enemy:
		_guard(unit, {"attack_range": 1, "radius": 99}, rng)
	else:
		_explore(unit, rng)


static func _schedule(unit: Unit) -> void:
	if unit.definition.schedule.is_empty():
		return
	var turn := GameClock.turn
	for entry in unit.definition.schedule:
		var mod := int(entry.get("turn_mod", 1))
		if mod > 0 and turn % mod == int(entry.get("phase", 0)):
			var c: Array = entry.get("coord", [])
			if c.size() == 2:
				unit.move_toward_target(Vector2i(int(c[0]), int(c[1])))
			return
