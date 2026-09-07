extends GdTest


func before_each() -> void:
	GameClock.configure(GameManager.game_config)
	IntelRegistry.reset_journal()
	GameManager.start_new_game_headless()


func test_damage_pipeline_kills_actor() -> void:
	var a := make_actor("skeleton_soldier")   # 45 hp, armor 8, pierce 0.5 resist, holy -0.5
	var died := []
	a.died.connect(func(k): died.append(k))
	var info := DamageInfo.single("holy", 20.0)
	info.can_be_dodged = false
	var dealt := a.take_damage(info)
	assert_approx(dealt, 30.0, 0.001, "holy vulnerability +50%")
	assert_approx(a.health.current, 15.0)
	var info2 := DamageInfo.single("pierce", 100.0)
	info2.can_be_dodged = false
	a.take_damage(info2)
	assert_true(a.is_dead)
	assert_eq(died.size(), 1)
	assert_approx(a.take_damage(DamageInfo.single("fire", 10.0)), 0.0, 0.001, "dead actors take no damage")


func test_status_effects_modify_stats_and_expire() -> void:
	var a := make_actor("player")
	var base_armor := a.stat("armor")
	assert_true(a.status_effects.apply("bone_ward"))
	assert_approx(a.stat("armor"), base_armor + 15.0)
	assert_true(a.status_effects.is_immune_to("poisoned"))
	assert_false(a.status_effects.apply("poisoned"), "immune")
	GameClock.advance(31.0)
	a.status_effects._process(0.0)
	assert_false(a.status_effects.has("bone_ward"), "expired after 30 game seconds")
	assert_approx(a.stat("armor"), base_armor)


func test_status_effect_stacking_and_ticks() -> void:
	var a := make_actor("bandit_cutpurse")  # 35 hp
	a.status_effects.apply("poisoned")
	a.status_effects.apply("poisoned")
	a.status_effects.apply("poisoned")
	a.status_effects.apply("poisoned")
	assert_eq(a.status_effects.stacks("poisoned"), 3, "max_stacks 3")
	var hp := a.health.current
	GameClock.advance(2.1)
	a.status_effects._process(0.0)
	assert_lt(a.health.current, hp, "tick damage applied")
	assert_approx(hp - a.health.current, 3.0, 0.001, "1 poison x 3 stacks, no armor for poison")


func test_ability_caster_costs_and_cooldown() -> void:
	var a := make_actor("player")
	a.ability_caster.learn("firebolt")
	var mana := a.resources.get_current("mana")
	assert_true(a.ability_caster.can_cast("firebolt")["ok"])
	assert_true(a.ability_caster.cast("firebolt", Vector3.FORWARD))
	assert_approx(a.resources.get_current("mana"), mana - 12.0)
	assert_eq(a.ability_caster.can_cast("firebolt")["reason"], "casting", "0.4s cast time in progress")
	a.ability_caster.is_casting = false
	assert_eq(a.ability_caster.can_cast("firebolt")["reason"], "cooldown")
	a.resources.modify("mana", -1000)
	a.ability_caster.cooldowns.clear()
	assert_eq(a.ability_caster.can_cast("firebolt")["reason"], "resources")


func test_faction_hostility_and_reputation() -> void:
	var skel := make_actor("skeleton_soldier")
	var bandit := make_actor("bandit_cutpurse")
	var villager := make_actor("npc_generic")
	var player := Actor.new()
	player.actor_def_id = "player"
	player.add_child(PlayerBrain.new())
	spawn(player)
	assert_true(player.is_player())
	assert_true(skel.is_hostile_to(bandit), "undead default hostile")
	assert_true(villager.is_hostile_to(skel))
	assert_false(villager.is_hostile_to(player), "townsfolk start friendly to player (rep 10)")
	GameManager.change_reputation("townsfolk", -100)
	assert_true(villager.is_hostile_to(player), "reputation collapse -> hostile")
	GameManager.change_reputation("townsfolk", 100)
	assert_false(villager.is_hostile_to(player))
	var info := DamageInfo.single("slash", 1.0, player)
	info.can_be_dodged = false
	villager.take_damage(info)
	assert_true(villager.is_hostile_to(player), "attacked NPC becomes a personal enemy")


func test_definition_registry_queries() -> void:
	assert_true(DefinitionRegistry.has("items", "relic_ossuary"))
	assert_false(DefinitionRegistry.has("items", "nope"))
	assert_gt(DefinitionRegistry.all("abilities").size(), 5)
	var weapons := DefinitionRegistry.all("items").filter(func(d): return d.is_weapon())
	assert_gt(weapons.size(), 2)
	var relic := DefinitionRegistry.get_def("items", "relic_ossuary") as ItemDefinition
	assert_eq(relic.rarity, "unique")
	assert_approx(relic.average_damage(), 12.0)  # (5+9)/2 + (4+6)/2
