extends GdTest


func before_each() -> void:
	DamageCalculator.configure({"armor_constant": 50, "max_resistance": 0.75, "min_resistance": -1.0})


func test_armor_mitigation_diminishing() -> void:
	assert_approx(DamageCalculator.armor_mitigation(0), 0.0)
	assert_approx(DamageCalculator.armor_mitigation(50), 0.5)
	assert_approx(DamageCalculator.armor_mitigation(150), 0.75)
	assert_lt(DamageCalculator.armor_mitigation(100000), 1.0, "never reaches 100%")


func test_physical_damage_uses_armor() -> void:
	var info := DamageInfo.single("slash", 100.0)
	var total := DamageCalculator.resolve(info, 50.0, {})
	assert_approx(total, 50.0)
	assert_approx(info.mitigated, 50.0)


func test_elemental_damage_ignores_armor_uses_resistance() -> void:
	var info := DamageInfo.single("fire", 100.0)
	var total := DamageCalculator.resolve(info, 500.0, {"fire": 0.25})
	assert_approx(total, 75.0)


func test_vulnerability_increases_damage() -> void:
	var info := DamageInfo.single("holy", 40.0)
	var total := DamageCalculator.resolve(info, 0.0, {"holy": -0.5})
	assert_approx(total, 60.0)


func test_resistance_is_clamped() -> void:
	var info := DamageInfo.single("frost", 100.0)
	DamageCalculator.resolve(info, 0.0, {"frost": 2.0})
	assert_approx(info.total, 25.0, 0.001, "capped at max_resistance 0.75")


func test_immunity_zeroes_type() -> void:
	var info := DamageInfo.new()
	info.add("poison", 30.0)
	info.add("slash", 10.0)
	DamageCalculator.resolve(info, 0.0, {}, ["poison"])
	assert_approx(info.final_amounts["poison"], 0.0)
	assert_approx(info.final_amounts["slash"], 10.0)


func test_true_damage_bypasses_everything() -> void:
	var info := DamageInfo.single("true", 25.0)
	DamageCalculator.resolve(info, 1000.0, {"true": 0.9}, ["true"])
	# immunity list is honoured even for "true" only if listed; here it IS listed -> 0
	assert_approx(info.total, 0.0)
	var info2 := DamageInfo.single("true", 25.0)
	DamageCalculator.resolve(info2, 1000.0, {"true": 0.9})
	assert_approx(info2.total, 25.0)


func test_crit_multiplies() -> void:
	var info := DamageInfo.single("fire", 10.0)
	info.is_crit = true
	info.crit_multiplier = 2.0
	DamageCalculator.resolve(info, 0.0, {})
	assert_approx(info.total, 20.0)


func test_dodge_with_seeded_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var dodged := 0
	for i in 200:
		var info := DamageInfo.single("slash", 10.0)
		DamageCalculator.resolve(info, 0.0, {}, [], 0.5, rng)
		if info.dodged:
			dodged += 1
	assert_gt(dodged, 60, "roughly half should dodge")
	assert_lt(dodged, 140, "roughly half should dodge")


func test_from_ranges_midpoint_without_rng() -> void:
	var info := DamageInfo.from_ranges({"slash": [4, 8], "fire": 3})
	assert_approx(info.amounts["slash"], 6.0)
	assert_approx(info.amounts["fire"], 3.0)
	assert_eq(info.primary_type(), "slash")


func test_scaling_adds_to_primary() -> void:
	var info := DamageInfo.single("fire", 10.0)
	DamageCalculator.apply_scaling(info, {"intellect": 0.5}, {"intellect": 20.0})
	assert_approx(info.amounts["fire"], 20.0)
