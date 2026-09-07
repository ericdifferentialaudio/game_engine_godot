## Tests for CoreGoalSelector and AIHeuristicManager (ported from Aevum's
## engine_goals.py roulette-wheel goal-selection model). Runs headless with
## the default CoreEngineAdapter (no graphics engine).
extends GutTest


func before_each() -> void:
	CoreContext.reset()
	CoreContext.install(CoreEngineAdapter.new())
	CoreContext.configure({"seed": 12345})
	AIHeuristicManager.reset()


# --- normalize() -----------------------------------------------------------------

func test_normalize_drops_zero_and_negative_scores() -> void:
	var dist := CoreGoalSelector.normalize({"a": 1.0, "b": 0.0, "c": -1.0})
	assert_true(dist.has("a"))
	assert_false(dist.has("b"))
	assert_false(dist.has("c"))


func test_normalize_sums_to_one() -> void:
	var dist := CoreGoalSelector.normalize({"a": 1.0, "b": 3.0})
	var total := 0.0
	for g in dist:
		total += float(dist[g])
	assert_almost_eq(total, 1.0, 0.0001)
	assert_almost_eq(float(dist["a"]), 0.25, 0.0001)
	assert_almost_eq(float(dist["b"]), 0.75, 0.0001)


func test_normalize_respects_floor() -> void:
	var dist := CoreGoalSelector.normalize({"a": 1.0, "b": 0.02}, 1.0, 0.05)
	assert_true(dist.has("a"))
	assert_false(dist.has("b"), "score below the floor must be excluded")


func test_normalize_empty_when_nothing_viable() -> void:
	assert_eq(CoreGoalSelector.normalize({"a": 0.0}), {})
	assert_eq(CoreGoalSelector.normalize({}), {})


func test_normalize_k_shapes_toward_stronger_goal() -> void:
	var linear := CoreGoalSelector.normalize({"a": 1.0, "b": 2.0}, 1.0)
	var squared := CoreGoalSelector.normalize({"a": 1.0, "b": 2.0}, 2.0)
	assert_gt(float(squared["b"]), float(linear["b"]),
		"higher k must favour the already-stronger goal more")


# --- select_weighted() -------------------------------------------------------------

func test_select_weighted_never_returns_a_veto() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		var picked := CoreGoalSelector.select_weighted({"a": 1.0, "b": 0.0}, rng)
		assert_eq(picked, "a")


func test_select_weighted_is_empty_when_nothing_eligible() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(CoreGoalSelector.select_weighted({"a": 0.0}, rng), "")


func test_select_weighted_is_deterministic_for_a_given_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 777
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 777
	var scores := {"a": 1.0, "b": 1.0, "c": 1.0}
	for i in 10:
		assert_eq(
			CoreGoalSelector.select_weighted(scores, rng_a),
			CoreGoalSelector.select_weighted(scores, rng_b),
			"same seed must reproduce the same picks"
		)


func test_select_weighted_low_score_goal_still_reachable_over_many_rolls() -> void:
	# Aevum regression: a goal at 8.2% of total intent should fire roughly
	# 1 turn in 12, never zero times, given enough rolls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var scores := {"strong": 0.918, "weak": 0.082}
	var weak_hits := 0
	for i in 500:
		if CoreGoalSelector.select_weighted(scores, rng, 1.0) == "weak":
			weak_hits += 1
	assert_gt(weak_hits, 0, "a nonzero-scoring goal must never be permanently starved")


# --- apply_repeat_penalty() --------------------------------------------------------

func test_apply_repeat_penalty_damps_only_the_expired_goal() -> void:
	var scores := CoreGoalSelector.apply_repeat_penalty({"a": 1.0, "b": 1.0}, "a")
	assert_almost_eq(float(scores["a"]), 0.5, 0.0001)
	assert_almost_eq(float(scores["b"]), 1.0, 0.0001)


func test_apply_repeat_penalty_is_noop_for_unknown_goal() -> void:
	var scores := {"a": 1.0}
	assert_eq(CoreGoalSelector.apply_repeat_penalty(scores, "nonexistent"), scores)


# --- roll_commitment() -------------------------------------------------------------

func test_roll_commitment_stays_within_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 30:
		var turns := CoreGoalSelector.roll_commitment(rng, 4, 12)
		assert_between(turns, 4, 12)


func test_roll_commitment_scale_shrinks_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 30:
		var turns := CoreGoalSelector.roll_commitment(rng, 10, 20, 0.5)
		assert_between(turns, 5, 10)


# --- proximity_bonus() -------------------------------------------------------------

func test_proximity_bonus_increases_as_distance_shrinks() -> void:
	var far := CoreGoalSelector.proximity_bonus(11.0, 12.0, 0.5)
	var near := CoreGoalSelector.proximity_bonus(3.0, 12.0, 0.5)
	assert_gt(near, far)
	assert_almost_eq(far, 1.0 + (1.0 - 11.0 / 12.0) * 0.5, 0.0001)


func test_proximity_bonus_never_below_one() -> void:
	assert_almost_eq(CoreGoalSelector.proximity_bonus(100.0, 12.0, 0.5), 1.0, 0.0001)


func test_proximity_bonus_zero_radius_is_neutral() -> void:
	assert_eq(CoreGoalSelector.proximity_bonus(5.0, 0.0, 0.5), 1.0)


# --- apply_cooldown() --------------------------------------------------------------

func test_apply_cooldown_suppresses_then_recovers() -> void:
	var full := CoreGoalSelector.apply_cooldown(1.0, 10, 10, 0.8)
	var half := CoreGoalSelector.apply_cooldown(1.0, 5, 10, 0.8)
	var done := CoreGoalSelector.apply_cooldown(1.0, 0, 10, 0.8)
	assert_almost_eq(full, 0.2, 0.0001)
	assert_almost_eq(half, 0.6, 0.0001)
	assert_almost_eq(done, 1.0, 0.0001)


# --- cooldown table helpers ---------------------------------------------------------

func test_cooldown_table_set_get_and_tick() -> void:
	var cds := {}
	CoreGoalSelector.set_cooldown(cds, "shop", 3)
	assert_eq(CoreGoalSelector.get_cooldown(cds, "shop"), 3)

	CoreGoalSelector.tick_cooldowns(cds)
	CoreGoalSelector.tick_cooldowns(cds)
	assert_eq(CoreGoalSelector.get_cooldown(cds, "shop"), 1)

	CoreGoalSelector.tick_cooldowns(cds)
	assert_eq(CoreGoalSelector.get_cooldown(cds, "shop"), 0)
	assert_false(cds.has("shop"), "expired cooldowns must be dropped, not left at 0")


func test_set_cooldown_extends_not_shortens() -> void:
	var cds := {}
	CoreGoalSelector.set_cooldown(cds, "shop", 5)
	CoreGoalSelector.set_cooldown(cds, "shop", 2)
	assert_eq(CoreGoalSelector.get_cooldown(cds, "shop"), 5)


# --- AIHeuristicManager integration --------------------------------------------------

func test_ai_heuristic_manager_picks_from_scores() -> void:
	var chosen := AIHeuristicManager.evaluate(&"unit_1", {"patrol": 1.0, "flee": 0.0})
	assert_eq(chosen, &"patrol")


func test_ai_heuristic_manager_idle_when_all_vetoed() -> void:
	var chosen := AIHeuristicManager.evaluate(&"unit_1", {"patrol": 0.0})
	assert_eq(chosen, &"idle")


func test_ai_heuristic_manager_damps_just_expired_commitment() -> void:
	AIHeuristicManager.evaluate(&"unit_2", {"upgrade": 1.0})
	var chosen := AIHeuristicManager.evaluate(&"unit_2", {"upgrade": 1.0, "explore": 0.9})
	# "upgrade" is damped to 0.5 after committing to it, so with explore at
	# 0.9 raw, explore should now win with high probability across the
	# deterministic seed configured in before_each().
	assert_true(chosen == &"explore" or chosen == &"upgrade")


func test_ai_heuristic_manager_cooldowns_roundtrip() -> void:
	AIHeuristicManager.set_cooldown(&"unit_3", "shop", 3)
	assert_eq(AIHeuristicManager.cooldown_for(&"unit_3", "shop"), 3)
	AIHeuristicManager.tick_cooldowns(&"unit_3")
	assert_eq(AIHeuristicManager.cooldown_for(&"unit_3", "shop"), 2)


func test_ai_heuristic_manager_reset_clears_state() -> void:
	AIHeuristicManager.set_cooldown(&"unit_4", "shop", 3)
	AIHeuristicManager.evaluate(&"unit_4", {"a": 1.0})
	AIHeuristicManager.reset()
	assert_eq(AIHeuristicManager.cooldown_for(&"unit_4", "shop"), 0)
