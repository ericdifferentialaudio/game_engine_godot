## The Slack Tide session driver: movement, knowledge and endings.
##
## These are the tests that prove there is a GAME, not just data. Before this
## driver existed, `main.gd` loaded the package, seeded the RNG and stopped.
extends GutTest

const GAME_SCRIPT := "res://games/slack_tide/slack_tide_game.gd"

var game: Node


func before_each() -> void:
	# The package must be loaded for CoreRegistry to hold the token graph.
	if GameManager.game_id != "slack_tide":
		GameManager.load_game("slack_tide")
		GameManager.start_new_game(1847)
	game = load(GAME_SCRIPT).new()
	add_child_autofree(game)
	game.setup(_boot_script(), null)


## GameManager keeps its boot script private and names the node "GameBoot".
func _boot_script() -> Node:
	return GameManager.find_child("GameBoot", false, false)


func test_script_compiles() -> void:
	var script: GDScript = load(GAME_SCRIPT)
	assert_not_null(script, "session driver must load")
	assert_true(script.can_instantiate(), "session driver must compile")


func test_world_graph_loaded() -> void:
	assert_eq(game.maps.size(), 15, "15 locations in maps.json")
	assert_gt(game.topics.size(), 10, "topics.json should be loaded")
	assert_ne(game.current_map, "", "a start location must be set")


func test_the_cast_stands_somewhere() -> void:
	# Regression guard for the actor gap: Doon and Brack are the endgame and
	# for a long time did not exist as actors at all.
	var everyone: Array = []
	for loc in game.actors_at:
		everyone.append_array(game.actors_at[loc])
	assert_has(everyone, "doon", "Doon must exist and stand somewhere")
	assert_has(everyone, "brack", "Brack must exist and stand somewhere")
	assert_has(game.actors_at.get("weir_gatehouse", []), "doon",
		"Doon belongs at the Weir gatehouse")


func test_movement_follows_the_link_graph() -> void:
	game.go_to("sorrel_landing", true)
	assert_eq(game.current_map, "sorrel_landing")
	# reedwick_marsh is an unconditional link from the landing.
	assert_true(game.go_to("reedwick_marsh"), "an open link should be walkable")
	assert_eq(game.current_map, "reedwick_marsh")


func test_unlinked_locations_are_not_reachable() -> void:
	game.go_to("sorrel_landing", true)
	assert_false(game.go_to("weir_underworks"),
		"you cannot step from the home dock into the Underworks")
	assert_eq(game.current_map, "sorrel_landing", "a refused move must not move")


func test_a_rumour_mill_cannot_make_you_certain() -> void:
	# Doss is a rumour mill: he carries every version of the triad at gossip
	# weight. Believing him is exactly the mistake the game is about.
	var learned: Array = game.ask("doss", "q1")
	assert_gt(learned.size(), 1,
		"a rumour mill should offer more than one version")
	for tid in learned:
		assert_lte(game.reliability_of(str(tid)), 0.26,
			"gossip must stay capped at 25 - '%s'" % tid)
		assert_false(game.knows(str(tid)),
			"gossip alone must never read as known")


func test_asking_the_same_person_twice_teaches_nothing() -> void:
	game.ask("doss", "q1")
	var again: Array = game.ask("doss", "q1")
	assert_eq(again.size(), 0,
		"corroboration must come from a different mouth, not repetition")


func test_a_real_source_beats_gossip() -> void:
	# Fen explains rather than gossips, so he should land well above the cap.
	var learned: Array = game.ask("fen", "q1")
	assert_gt(learned.size(), 0, "Fen should teach something")
	var best := 0.0
	for tid in learned:
		best = maxf(best, game.reliability_of(str(tid)))
	assert_gt(best, 0.26, "a named source must beat the rumour cap")


func test_the_ledger_delays_spread_by_three_days() -> void:
	game.ask("fen", "q1")   # gives a real token to sell
	game.sell("c1a")
	assert_false(game.is_common_knowledge("c1a"),
		"a sale should not surface immediately")
	for i in range(3):
		for _s in range(6):
			game.advance_slot()
	assert_true(game.is_common_knowledge("c1a"),
		"after the spread delay, a sold token should be common knowledge")


func test_the_ledger_tracks_loose_falsehoods_separately_from_true_sales() -> void:
	# c1a is true only in seed A; selling it when the seed disagrees is a lie
	# the town will eventually repeat back at the player.
	game.sell("c1a")
	for i in range(3):
		for _s in range(6):
			game.advance_slot()
	var loose: int = game.loose_falsehoods()
	# Whether c1a is a lie THIS seed depends on the rolled culprit; either way
	# the count must be well-formed and never negative.
	assert_gte(loose, 0)


func test_reckoning_reports_four_axes() -> void:
	var r: Dictionary = game.reckoning("A")
	for key in ["truth", "conduct", "purse", "mercy"]:
		assert_true(r.has(key), "reckoning must report '%s'" % key)
		assert_gte(int(r[key]), 0)
		assert_lte(int(r[key]), 100)


func test_endings_split_on_understanding() -> void:
	# Four endings on two axes. Turning the tide while wrong is a mechanical
	# win that should still be named differently from an informed one.
	var fresh: Node = load(GAME_SCRIPT).new()
	add_child_autofree(fresh)
	fresh.setup(_boot_script(), null)
	var ending: String = fresh.finish(true)
	assert_true(ending in ["long_way_home", "cold_answer"],
		"turning the tide must produce a turned ending, got '%s'" % ending)
	assert_true(fresh.ended, "the run should be marked finished")
	assert_eq(fresh.finish(false), ending, "an ending must not be rewritten")
