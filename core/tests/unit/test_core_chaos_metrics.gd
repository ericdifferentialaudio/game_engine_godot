## Tests for CoreChaosMetrics -- the renderer-agnostic chaos scorecard used by
## both engines' chaos harnesses. Runs headless (no graphics engine).
##
## The central invariant under test: chaos is variance ACROSS seeds, and a high
## score must never be reachable by breaking solvability or determinism.
extends GutTest


func before_each() -> void:
	CoreContext.reset()
	CoreContext.install(CoreEngineAdapter.new())
	CoreContext.configure({"seed": 12345})


# --- outcome_entropy() -----------------------------------------------------------

func test_entropy_is_zero_when_every_run_ends_the_same() -> void:
	assert_almost_eq(CoreChaosMetrics.outcome_entropy(["win", "win", "win", "win"]), 0.0, 0.001)


func test_entropy_is_one_for_a_perfectly_even_split() -> void:
	assert_almost_eq(CoreChaosMetrics.outcome_entropy(["win", "loss", "win", "loss"]), 1.0, 0.001)


func test_entropy_handles_empty_and_single_samples() -> void:
	assert_eq(CoreChaosMetrics.outcome_entropy([]), 0.0)
	assert_eq(CoreChaosMetrics.outcome_entropy(["win"]), 0.0)


func test_lopsided_split_scores_below_even_split() -> void:
	var lopsided := CoreChaosMetrics.outcome_entropy(["win", "win", "win", "loss"])
	var even := CoreChaosMetrics.outcome_entropy(["win", "loss", "win", "loss"])
	assert_lt(lopsided, even)
	assert_gt(lopsided, 0.0)


# --- trajectory_divergence() -----------------------------------------------------

func test_identical_trajectories_do_not_diverge() -> void:
	assert_eq(CoreChaosMetrics.trajectory_divergence(["a", "b", "c"], ["a", "b", "c"]), 0.0)


func test_fully_different_trajectories_diverge_completely() -> void:
	assert_eq(CoreChaosMetrics.trajectory_divergence(["a", "b"], ["x", "y"]), 1.0)


func test_partial_divergence_is_the_fraction_of_differing_checkpoints() -> void:
	assert_almost_eq(CoreChaosMetrics.trajectory_divergence(["a", "b", "c", "d"], ["a", "b", "x", "y"]), 0.5, 0.001)


func test_divergence_compares_only_the_overlapping_prefix() -> void:
	assert_eq(CoreChaosMetrics.trajectory_divergence(["a", "b"], ["a", "b", "c", "d"]), 0.0)
	assert_eq(CoreChaosMetrics.trajectory_divergence([], ["a"]), 0.0)


# --- state_coverage() ------------------------------------------------------------

func test_coverage_counts_distinct_places_not_repeat_visits() -> void:
	assert_almost_eq(CoreChaosMetrics.state_coverage(["r1", "r1", "r1", "r2"], 4), 0.5, 0.001)


func test_coverage_is_zero_when_nothing_is_reachable() -> void:
	assert_eq(CoreChaosMetrics.state_coverage(["r1"], 0), 0.0)


func test_coverage_is_clamped_at_one() -> void:
	assert_eq(CoreChaosMetrics.state_coverage(["a", "b", "c"], 2), 1.0)


# --- event_rarity_tail() ---------------------------------------------------------

func test_a_game_that_always_does_the_same_thing_has_no_rare_tail() -> void:
	assert_eq(CoreChaosMetrics.event_rarity_tail(["hit", "hit", "hit"]), 0.0)


func test_rare_events_are_rewarded() -> void:
	# 'common' dominates; the nine one-off events are each <=10% of the total.
	var events := []
	for i in range(21):
		events.append("common")
	for i in range(9):
		events.append("rare_%d" % i)
	assert_gt(CoreChaosMetrics.event_rarity_tail(events), 0.5)


func test_empty_event_log_scores_zero() -> void:
	assert_eq(CoreChaosMetrics.event_rarity_tail([]), 0.0)


# --- epistemic_score() -----------------------------------------------------------

func test_believing_nothing_false_scores_zero_epistemic_chaos() -> void:
	assert_eq(CoreChaosMetrics.epistemic_score(0, 0, 10), 0.0)


func test_unrefutable_lies_score_zero_because_they_are_unfair() -> void:
	# Ten false beliefs, none of them discoverable: that is a bug, not chaos.
	assert_eq(CoreChaosMetrics.epistemic_score(10, 0, 10), 0.0)


func test_fully_refutable_lies_score_full_epistemic_chaos() -> void:
	assert_almost_eq(CoreChaosMetrics.epistemic_score(10, 10, 10), 1.0, 0.001)


func test_half_refutable_lies_score_proportionally() -> void:
	# 5 of 10 beliefs false, all 5 refutable -> 0.5 wrongness * 1.0 fairness.
	assert_almost_eq(CoreChaosMetrics.epistemic_score(5, 5, 10), 0.5, 0.001)


func test_epistemic_score_is_zero_with_no_beliefs_at_all() -> void:
	assert_eq(CoreChaosMetrics.epistemic_score(0, 0, 0), 0.0)


# --- weighted_score() ------------------------------------------------------------

func test_weights_sum_to_one() -> void:
	var total := 0.0
	for tier in CoreChaosMetrics.TIER_WEIGHTS:
		total += float(CoreChaosMetrics.TIER_WEIGHTS[tier])
	assert_almost_eq(total, 1.0, 0.001)


func test_mechanical_chaos_is_worth_less_than_epistemic_chaos() -> void:
	# The core thesis: dice are the cheapest form of unpredictability.
	var dice_only := CoreChaosMetrics.weighted_score({"mechanical": 1.0})
	var knowledge_only := CoreChaosMetrics.weighted_score({"epistemic": 1.0})
	assert_lt(dice_only, knowledge_only)


func test_perfect_scores_in_every_tier_give_one() -> void:
	assert_almost_eq(CoreChaosMetrics.weighted_score({
		"epistemic": 1.0, "combinatorial": 1.0, "social": 1.0, "mechanical": 1.0,
	}), 1.0, 0.001)


# --- scorecard() -----------------------------------------------------------------

func _episode(outcome: String, won: bool) -> Dictionary:
	return {
		"outcome": outcome, "won": won,
		"visited": ["a", "b"], "events": ["e1"],
		"false_beliefs_held": 1, "refutable_beliefs": 1, "total_beliefs": 4,
		"deterministic": true,
	}


func test_scorecard_reports_win_rate_and_episode_count() -> void:
	var card := CoreChaosMetrics.scorecard([
		_episode("win", true), _episode("loss", false),
		_episode("win", true), _episode("stalemate", false),
	], {"reachable_total": 4})
	assert_eq(card["episodes"], 4)
	assert_almost_eq(float(card["win_rate"]), 0.5, 0.001)


func test_solvability_gate_fails_when_the_game_becomes_unwinnable() -> void:
	# Maximum outcome variety, but nobody ever wins: must NOT pass.
	var card := CoreChaosMetrics.scorecard([
		_episode("loss", false), _episode("stalemate", false),
		_episode("death", false), _episode("timeout", false),
	], {"reachable_total": 4})
	assert_gt(float(card["score"]), 0.0, "chaotic outcomes still score")
	assert_false(card["gates"]["solvable"], "solvability gate must catch it")
	assert_false(card["passed"], "an unwinnable game must never pass")


func test_nondeterminism_fails_the_gate_even_when_everything_else_is_good() -> void:
	var ep := _episode("win", true)
	ep["deterministic"] = false
	var card := CoreChaosMetrics.scorecard([ep, _episode("loss", false), _episode("win", true)],
		{"reachable_total": 2})
	assert_false(card["gates"]["deterministic"])
	assert_false(card["passed"])


func test_a_healthy_chaotic_game_passes_every_gate() -> void:
	var card := CoreChaosMetrics.scorecard([
		_episode("win_alone", true), _episode("win_together", true),
		_episode("win_silent", true), _episode("loss", false),
	], {"reachable_total": 2, "solvability_floor": 0.55})
	assert_true(card["gates"]["solvable"])
	assert_true(card["gates"]["deterministic"])
	assert_true(card["passed"])
	assert_gt(float(card["score"]), 0.0)


func test_scorecard_tolerates_an_empty_run() -> void:
	var card := CoreChaosMetrics.scorecard([])
	assert_eq(card["episodes"], 0)
	assert_eq(float(card["win_rate"]), 0.0)
	assert_false(card["passed"], "no evidence is not a pass")


func test_scorecard_ignores_malformed_episode_records() -> void:
	var card := CoreChaosMetrics.scorecard([_episode("win", true), "not a dictionary", 42],
		{"reachable_total": 2})
	assert_eq(card["episodes"], 3)
	assert_almost_eq(float(card["win_rate"]), 1.0 / 3.0, 0.001)


func test_default_solvability_floor_is_applied_when_not_specified() -> void:
	var card := CoreChaosMetrics.scorecard([_episode("win", true)], {"reachable_total": 2})
	assert_almost_eq(float(card["solvability_floor"]), CoreChaosMetrics.DEFAULT_SOLVABILITY_FLOOR, 0.001)
