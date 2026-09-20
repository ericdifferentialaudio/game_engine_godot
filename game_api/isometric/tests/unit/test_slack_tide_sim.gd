## Phase C: the engine cross-check.
##
## `tools/model.py` claims a competent-policy win rate of 0.804. Until this
## test exists, that number is a Python model's OPINION about a game that
## does not exist in the engine. This drives a scripted competent policy
## through the real engine -- real CoreIntel, real reliability, real
## `slack_tide_game.gd` -- over many seeds, and checks the two agree.
##
## If they diverge, the MODEL is wrong, not the engine: the engine is the
## measured truth. See docs/PHASE_GATES.md Phase C.
extends GutTest

const GAME_SCRIPT := "res://games/slack_tide/slack_tide_game.gd"
const SEEDS := 40                 ## keep this fast; it runs every CI pass
const AGREEMENT_TOLERANCE := 0.20 ## generous for a small in-engine sample;
								   ## tools/regress.py is the real 2000-seed gate


func _boot_script() -> Node:
	return GameManager.find_child("GameBoot", false, false)


## Every location reachable from the start, via a plain BFS with its own
## one-shot visited set (NOT reused across days -- that bug once made the
## sim only ever visit day zero's locations).
func _reachable_locations(game: Node) -> Array:
	var out: Array = []
	var seen := {}
	var frontier := [game.current_map]
	seen[game.current_map] = true
	while not frontier.is_empty():
		var here: String = frontier.pop_front()
		out.append(here)
		for link in game.maps.get(here, {}).get("links", []):
			var to := str(link.get("to", ""))
			if to != "" and not seen.has(to):
				seen[to] = true
				frontier.append(to)
	return out


## Plays one seed to a finish with a "competent" policy: visit every reachable
## location once, ask every present NPC every topic they'll discuss, buy any
## token a broker offers if affordable, then check whether a road is open.
func _play_competent(seed_value: int) -> Dictionary:
	GameManager.load_game("slack_tide")
	GameManager.start_new_game(seed_value)
	var boot := _boot_script()
	var game: Node = load(GAME_SCRIPT).new()
	add_child_autofree(game)
	game.setup(boot, null)

	var spec: Dictionary = _load_spec()
	var culprit: String = str(boot.culprit) if boot != null else "A"

	# Every location the graph reaches, computed once (topology does not
	# change mid-run). A competent player revisits everywhere, every day,
	# because priced tokens (Ottoline, Wimble) need wages to land first --
	# which needs the clock to move. Six slots a day, matching
	# slack_tide_boot.gd. Ignoring slot gates here: a competent player returns
	# at the right time; that scheduling is what tools/model.py already tunes.
	# Values only move through dialogue value-events (Phase D territory, not
	# yet wired into ask()/buy()). Until that content exists, stand in for
	# "played with coherent conduct toward a chosen road" the same way
	# tools/model.py's _plan_values does -- otherwise this test would fail
	# for a reason that has nothing to do with what it is trying to measure.
	_grant_road_values(boot, spec, culprit)

	var all_locations: Array = _reachable_locations(game)
	for day in range(14):
		for _slot in range(6):
			game.advance_slot()
		for here in all_locations:
			game.go_to(here, true)
			for npc in game.actors_here():
				for topic in game.topics_for(npc):
					game.ask(npc, topic)
					var stance: Dictionary = game.topics.get(topic, {}) \
						.get("stances", {}).get(npc, {})
					if str(stance.get("mode", "")) in ["price", "sell"]:
						game.buy(npc, topic)
		if game.road_available(spec, culprit) != "" and \
				game.entry_available(spec, culprit):
			break

	var road: String = game.road_available(spec, culprit)
	var entered: bool = game.entry_available(spec, culprit)
	var turned: bool = road != "" and entered
	var outcome: String = game.finish(turned)
	return {"seed": seed_value, "won": turned, "outcome": outcome,
			"understood": game.understood(culprit)}


## The cheapest road's value requirements, granted directly. Real conduct
## comes from Phase D dialogue; this is a stand-in so Phase C measures the
## token/economy loop it exists to measure, not an unrelated content gap.
func _grant_road_values(boot: Node, spec: Dictionary, culprit: String) -> void:
	if boot == null:
		return
	for road_name in ["word", "bargain", "hand"]:
		var r: Dictionary = spec.get("roads", {}).get(road_name, {}).get(culprit, {})
		for vname in r.get("values", {}):
			var need := int(r["values"][vname])
			while boot.value_of(str(vname)) < need:
				boot.adjust_value(str(vname), 1)
	for name in spec.get("entry_methods", {}):
		var e: Dictionary = spec["entry_methods"][name]
		if not str(culprit) in str(e.get("seeds", "")):
			continue
		for vname in e.get("values", {}):
			var need2 := int(e["values"][vname])
			while boot.value_of(str(vname)) < need2:
				boot.adjust_value(str(vname), 1)


func _load_spec() -> Dictionary:
	var f := FileAccess.open(
		"res://games/slack_tide/docs/slack_tide_spec.json", FileAccess.READ)
	if f == null:
		return {}
	return JSON.parse_string(f.get_as_text())


func test_competent_policy_wins_most_of_the_time_in_engine() -> void:
	var wins := 0
	var outcomes := {}
	for i in range(SEEDS):
		var r := _play_competent(1000 + i)
		if r["won"]:
			wins += 1
		var oc: String = str(r["outcome"])
		outcomes[oc] = int(outcomes.get(oc, 0)) + 1

	var rate := float(wins) / float(SEEDS)
	gut.p("engine competent win rate over %d seeds: %.3f (model: 0.804)"
		% [SEEDS, rate])
	gut.p("outcomes: %s" % [outcomes])

	# The model's number, not a coin flip's: this must sit in a real band, not
	# just "not exactly 0" and "not exactly 1".
	assert_between(rate, 0.804 - AGREEMENT_TOLERANCE, 0.804 + AGREEMENT_TOLERANCE,
		"engine win rate should agree with the Python model within tolerance")
	assert_gt(rate, 0.3, "a competent policy should win far more than it loses")
	assert_lt(rate, 1.0, "the player must still be able to lose")


func test_same_seed_replays_identically() -> void:
	var a := _play_competent(4242)
	var b := _play_competent(4242)
	assert_eq(a["outcome"], b["outcome"],
		"a seed must always produce the same outcome (determinism gate)")
	assert_eq(a["won"], b["won"])
