## Headless end-to-end self-test run via `godot --headless -- --game=<id> --smoke`.
## Exercises: world generation, factions/units spawned, pathfinding, turn loop
## across several turns, intel acquire/corroborate/derive/query, site discovery,
## save -> load round trip. Prints a report and quits 0/1.
class_name SmokeTest
extends Node

const TURNS_TO_RUN := 4

var _fails: Array[String] = []
var _passes: int = 0


func run() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await get_tree().process_frame
	_check(WorldManager.world != null, "world generated")
	_check(WorldManager.world and WorldManager.world.tiles.size() > 0, "world has tiles (%d)" % (WorldManager.world.tiles.size() if WorldManager.world else 0))
	_check(FactionRegistry.factions.size() > 0, "factions instantiated (%d)" % FactionRegistry.factions.size())
	_check(EntityRegistry.units.size() > 0, "units spawned (%d)" % EntityRegistry.units.size())
	_check(WorldManager.sites.size() > 0, "sites built (%d)" % WorldManager.sites.size())
	_check(TurnManager.running and GameClock.turn == 1, "turn loop started at turn 1 (turn=%d)" % GameClock.turn)

	# --- Shared game_core platform ------------------------------------------
	# Proves the engine adapter is installed and the core registry was fed the
	# same package, not left silently empty.
	_check(CoreContext.adapter != null and CoreContext.adapter.engine_id == "isometric",
		"core adapter installed (%s)" % (CoreContext.adapter.engine_id if CoreContext.adapter else "none"))
	_check(is_equal_approx(CoreContext.now(), GameClock.now()),
		"core clock tracks engine clock (%.2f)" % CoreContext.now())
	_check(CoreRegistry.ids("items").size() > 0,
		"core items loaded (%d)" % CoreRegistry.ids("items").size())
	_check(CoreRegistry.ids("units").size() > 0,
		"core units loaded (%d)" % CoreRegistry.ids("units").size())
	_check(CoreRegistry.ids("intel").size() > 0,
		"core intel loaded (%d)" % CoreRegistry.ids("intel").size())
	_check(CoreRegistry.ids("factions").size() > 0,
		"core factions loaded (%d)" % CoreRegistry.ids("factions").size())

	var player := GameManager.player_faction_id
	var units := EntityRegistry.units_of(player)
	_check(not units.is_empty(), "player has units")
	if not units.is_empty():
		var u := units[0]
		var reach := Pathfinder.reachable(WorldManager.world, u, u.coord, u.action_points)
		_check(not reach.is_empty(), "pathfinder finds reachable tiles (%d)" % reach.size())
		if reach.size() < 3:
			var w := WorldManager.world
			print("  debug unit %s at %s ap=%.1f terrain=%s" % [u.unit_id, u.coord, u.action_points, w.get_tile(u.coord).terrain.id])
			for n in w.topology.neighbors(u.coord):
				var t := w.get_tile(n)
				var occ := w.unit_at(n)
				print("    nb %s terrain=%s cost=%.1f occ=%s" % [n, t.terrain.id if t else "?", Pathfinder.move_cost(w, u, n), occ.unit_id if occ else "-"])
		if not reach.is_empty():
			var goal: Vector2i = reach.keys()[0]
			for c in reach:
				if WorldManager.world.unit_at(c) == null:
					goal = c
					break
			var moved := u.move_to(goal)
			_check(moved > 0, "unit moved %d tiles to %s" % [moved, goal])
		_check(WorldManager.world.is_visible(player, u.coord), "fog: own unit tile visible")

	# Intel: acquire, corroborate, query, derive.
	var token_ids := IntelRegistry.definitions.keys()
	_check(token_ids.size() > 0, "intel definitions loaded (%d)" % token_ids.size())
	if token_ids.size() > 0:
		var tid: String = token_ids[0]
		var tok := IntelRegistry.acquire(player, tid, "smoke_a", "told")
		_check(tok != null and IntelRegistry.has(player, tid), "intel acquired '%s'" % tid)
		var before := tok.reliability if tok else 0.0
		IntelRegistry.acquire(player, tid, "smoke_b", "told")
		_check(tok and tok.reliability >= before, "corroboration did not lower reliability (%.2f -> %.2f)" % [before, tok.reliability if tok else 0.0])
		_check(IntelRegistry.evaluate({"has": tid}, player), "query {has} passes")
		_check(not IntelRegistry.evaluate({"not": {"has": tid}}, player), "query {not has} fails")
		_check(IntelRegistry.evaluate({"provenance": [tid, "told"]}, player), "query {provenance} passes")
		_check(IntelRegistry.evaluate({"turn": [">=", 1]}, player), "query {turn} passes")
	for i in IntelRegistry.rules.derivations.size():
		var rule: Dictionary = IntelRegistry.rules.derivations[i]
		for sub in rule.get("when", {}).get("all", []):
			if sub.has("has"):
				IntelRegistry.acquire(player, sub["has"], "smoke_derive", "told", 1.0)
		_check(IntelRegistry.has(player, rule.get("grant", "")), "derivation '%s' granted '%s'" % [rule.get("id"), rule.get("grant")])
		break

	# Turn loop.
	var start_turn := GameClock.turn
	for i in TURNS_TO_RUN:
		TurnManager.commit_faction(player)
		await get_tree().process_frame
		await get_tree().process_frame
	_check(GameClock.turn >= start_turn + TURNS_TO_RUN - 1, "turns advanced (%d -> %d)" % [start_turn, GameClock.turn])

	# Save / load round trip.
	var data := SaveManager.build_save_data()
	var json := JSON.stringify(data)
	_check(json.length() > 100, "save data serialises (%d bytes)" % json.length())
	var units_before := EntityRegistry.units.size()
	var tiles_before := WorldManager.world.tiles.size()
	var intel_before := IntelRegistry.journal_for(player).tokens.size()
	var parsed: Dictionary = JSON.parse_string(json)
	var ok: bool = SaveManager.apply_save_data(parsed, "smoke")
	_check(ok, "save data re-applied")
	_check(EntityRegistry.units.size() == units_before, "units restored (%d == %d)" % [EntityRegistry.units.size(), units_before])
	_check(WorldManager.world.tiles.size() == tiles_before, "tiles restored (%d == %d)" % [WorldManager.world.tiles.size(), tiles_before])
	_check(IntelRegistry.journal_for(player).tokens.size() == intel_before, "intel restored (%d == %d)" % [IntelRegistry.journal_for(player).tokens.size(), intel_before])
	_check(GameClock.turn >= start_turn, "clock restored (turn %d)" % GameClock.turn)
	await get_tree().process_frame
	_check(SaveManager.save_game("smoke"), "save written to user://saves/smoke.json")

	print("\nSMOKE: %d passed, %d failed" % [_passes, _fails.size()])
	for f in _fails:
		printerr("  FAIL  ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("ok    ", label)
	else:
		_fails.append(label)
		printerr("FAIL  ", label)
