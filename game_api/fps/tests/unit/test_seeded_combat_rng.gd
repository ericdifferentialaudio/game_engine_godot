extends GutTest
## FPS combat randomness must come from the shared seeded generator
## (`CoreContext.rng()`), so a seeded game replays identically and scripted
## checks cannot flake. See Future work #11 in activeContext.md.


var _saved_rules: Dictionary = {}
var _saved_seed: int = 0
var _saved_state: int = 0


func before_each() -> void:
	_saved_rules = CoreContext.rules.duplicate(true)
	_saved_seed = CoreContext.rng().seed
	_saved_state = CoreContext.rng().state


func after_each() -> void:
	CoreContext.rules = _saved_rules
	CoreContext.rng().seed = _saved_seed
	CoreContext.rng().state = _saved_state


func _rolls(count: int, from: Callable) -> Array[float]:
	var out: Array[float] = []
	for i in count:
		out.append(from.call())
	return out


# --- The components no longer own a private generator -------------------------

func test_damageable_rng_is_the_shared_generator() -> void:
	var d := Damageable.new()
	autofree(d)
	assert_same(d.rng, CoreContext.rng(), "Damageable.rng must be CoreContext.rng()")


func test_ability_caster_rng_is_the_shared_generator() -> void:
	var c := AbilityCaster.new()
	autofree(c)
	assert_same(c._rng, CoreContext.rng(), "AbilityCaster._rng must be CoreContext.rng()")


func test_two_damageables_share_one_generator() -> void:
	var a := Damageable.new()
	var b := Damageable.new()
	autofree(a)
	autofree(b)
	assert_same(a.rng, b.rng, "one generator for the whole run, not one per actor")


# --- A seed replays identically ----------------------------------------------

func test_dodge_rolls_replay_from_the_same_seed() -> void:
	var d := Damageable.new()
	autofree(d)

	CoreContext.configure({"seed": 12345})
	var first := _rolls(16, func(): return d.rng.randf())

	CoreContext.configure({"seed": 12345})
	var second := _rolls(16, func(): return d.rng.randf())

	assert_eq(first, second, "same seed -> same dodge/crit rolls")


func test_different_seeds_diverge() -> void:
	var d := Damageable.new()
	autofree(d)

	CoreContext.configure({"seed": 12345})
	var first := _rolls(16, func(): return d.rng.randf())

	CoreContext.configure({"seed": 999})
	var second := _rolls(16, func(): return d.rng.randf())

	assert_ne(first, second, "a different seed must produce a different run")


func test_seeded_dodge_outcome_sequence_is_reproducible() -> void:
	var d := Damageable.new()
	autofree(d)

	var run := func() -> Array[bool]:
		var outcomes: Array[bool] = []
		for i in 20:
			var info := DamageInfo.single("slash", 10.0)
			DamageCalculator.resolve(info, 0.0, {}, [], 0.25, d.rng)
			outcomes.append(info.dodged)
		return outcomes

	CoreContext.configure({"seed": 4242})
	var first: Array[bool] = run.call()
	CoreContext.configure({"seed": 4242})
	var second: Array[bool] = run.call()

	assert_eq(first, second, "the wounded-thief class of flake cannot recur under a seed")
	assert_true(first.has(true), "0.25 dodge should hit at least once in 20 rolls")
	assert_true(first.has(false), "0.25 dodge should miss at least once in 20 rolls")


# --- Guard: no ad-hoc generators creep back into combat code ------------------

func test_no_ad_hoc_random_in_fps_combat_sources() -> void:
	var sources := [
		"res://framework/actor/components/damageable.gd",
		"res://framework/actor/components/ability_caster.gd",
		"res://framework/actor/brains/ai_brain.gd",
	]
	var offenders: Array[String] = []
	for path in sources:
		var text := FileAccess.get_file_as_string(path)
		assert_ne(text, "", "readable: %s" % path)
		for line in text.split("\n"):
			var code := str(line).strip_edges()
			if code.begins_with("#"):
				continue
			if code.contains("RandomNumberGenerator.new()") \
					or code.contains("randomize()") \
					or code.contains(" randf(") or code.begins_with("randf(") \
					or code.contains(" randf_range(") or code.begins_with("randf_range(") \
					or code.contains(" randi(") or code.begins_with("randi("):
				offenders.append("%s: %s" % [path, code])
	assert_eq(offenders, [] as Array[String],
		"combat randomness must route through CoreContext.rng()")
