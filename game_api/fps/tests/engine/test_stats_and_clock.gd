extends GdTest


func test_stats_modifier_stack() -> void:
	var s := Stats.new()
	spawn(s)
	s.set_base("armor", 10.0)
	assert_approx(s.get_final("armor"), 10.0)
	s.set_modifiers("equip:body", {"armor": 6.0})
	assert_approx(s.get_final("armor"), 16.0)
	s.set_modifiers("effect:bone_ward", {"armor": 15.0})
	assert_approx(s.get_final("armor"), 31.0)
	s.set_modifiers("effect:sunder", {}, {"armor": -0.5})
	assert_approx(s.get_final("armor"), 15.5, 0.001, "(10+6+15)*(1-0.5)")
	s.remove_modifiers("equip:body")
	assert_approx(s.get_final("armor"), 12.5)
	s.remove_modifiers("effect:sunder")
	s.remove_modifiers("effect:bone_ward")
	assert_approx(s.get_final("armor"), 10.0)
	assert_approx(s.get_final("nonexistent", 7.0), 7.0, 0.001, "default for unknown stat")


func test_stats_change_signal() -> void:
	var s := Stats.new()
	spawn(s)
	var seen := []
	s.stat_changed.connect(func(n, v): seen.append([n, v]))
	s.set_base("move_speed", 4.0)
	s.set_modifiers("effect:haste", {}, {"move_speed": 0.25})
	assert_eq(seen.size(), 2)
	assert_approx(seen[1][1], 5.0)


func test_game_clock_time_math() -> void:
	GameClock.configure({"time_scale": 60, "start_time": 8.0})
	assert_eq(GameClock.day(), 1)
	assert_eq(GameClock.hour(), 8)
	assert_eq(GameClock.day_phase(), "day")
	GameClock.advance(10.5 * 3600.0)
	assert_eq(GameClock.hour(), 18)
	assert_eq(GameClock.minute(), 30)
	assert_eq(GameClock.day_phase(), "dusk")
	GameClock.advance(6 * 3600.0)   # 18:30 + 6h = Day 2, 00:30
	assert_eq(GameClock.day(), 2)
	assert_eq(GameClock.hour(), 0)
	assert_eq(GameClock.minute(), 30)
	assert_eq(GameClock.day_phase(), "night")
	assert_true(GameClock.is_between_hours(22, 5), "wraps midnight")
	assert_false(GameClock.is_between_hours(6, 12))
	assert_approx(GameClock.seconds_until_hour(3.0), 2.5 * 3600.0)


func test_game_clock_scheduling() -> void:
	GameClock.configure({"time_scale": 60, "start_time": 0.0})
	var fired := []
	GameClock.schedule_in(100.0, func(): fired.append("once"))
	var rep := GameClock.schedule_in(50.0, func(): fired.append("rep"), true)
	GameClock.advance(60.0)
	assert_eq(fired, ["rep"])
	GameClock.advance(60.0)
	assert_eq(fired, ["rep", "once", "rep"])
	GameClock.cancel(rep)
	GameClock.advance(500.0)
	assert_eq(fired.size(), 3, "cancelled timer must not fire")


func test_intel_expiry_uses_game_clock() -> void:
	GameClock.configure({"time_scale": 60, "start_time": 0.0})
	IntelRegistry.reset_journal()
	var tok := IntelRegistry.acquire("schedule_ossuary_guard", "test")
	assert_not_null(tok)
	assert_false(tok.is_expired())
	GameClock.advance(tok.expires_after + 1.0)
	assert_true(tok.is_expired(), "expires after game-seconds elapse")
	assert_false(IntelRegistry.evaluate({"has": "schedule_ossuary_guard"}), "expired intel fails 'has'")
