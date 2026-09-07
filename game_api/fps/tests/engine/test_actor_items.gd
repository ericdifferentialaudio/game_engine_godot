extends GdTest


func before_each() -> void:
	GameClock.configure(GameManager.game_config)
	IntelRegistry.reset_journal()


func test_actor_auto_creates_components_and_applies_definition() -> void:
	var a := make_actor("skeleton_soldier")
	assert_not_null(a.health)
	assert_not_null(a.stats)
	assert_not_null(a.equipment)
	assert_not_null(a.faction)
	assert_approx(a.health.maximum, 45.0)
	assert_approx(a.stat("armor"), 8.0)
	assert_eq(a.faction.faction_id, "crypt_undead")
	assert_true(a.ability_caster.knows("skeleton_claw"))
	assert_true(a.is_in_group("monster"))


func test_inventory_stacking_and_removal() -> void:
	var a := make_actor()
	var inv := a.inventory
	assert_eq(inv.add_item("potion_minor", 15), 15)
	assert_eq(inv.slots_used(), 2, "max_stack 10 -> two stacks")
	assert_eq(inv.count_of("potion_minor"), 15)
	assert_true(inv.remove_item("potion_minor", 12))
	assert_eq(inv.count_of("potion_minor"), 3)
	assert_eq(inv.slots_used(), 1)
	assert_false(inv.remove_item("potion_minor", 99))
	inv.add_item("gold", 30)
	assert_eq(inv.get_currency("gold"), 30, "currency items route to currencies")
	assert_true(inv.spend_currency("gold", 10))
	assert_false(inv.spend_currency("gold", 100))


func test_inventory_slot_limit() -> void:
	var a := make_actor()
	a.inventory.max_slots = 2
	a.inventory.add_item("rusty_sword", 1)
	a.inventory.add_item("iron_cap", 1)
	assert_eq(a.inventory.add_item("leather_jerkin", 1), 0, "full")


func test_equipment_applies_stats_and_abilities() -> void:
	var a := make_actor("player")
	var base_armor := a.stat("armor")
	a.inventory.add_item("leather_jerkin")
	a.inventory.add_item("rusty_sword")
	assert_true(a.equipment.equip(a.inventory.find_first("leather_jerkin")))
	assert_approx(a.stat("armor"), base_armor + 6.0)
	assert_true(a.equipment.equip(a.inventory.find_first("rusty_sword")))
	assert_true(a.ability_caster.knows("sword_slash"), "weapon grants ability")
	assert_eq(a.inventory.count_of("rusty_sword"), 0, "moved out of inventory")
	a.equipment.unequip("main_hand")
	assert_false(a.ability_caster.knows("sword_slash"), "granted ability removed")
	assert_eq(a.inventory.count_of("rusty_sword"), 1, "back in inventory")
	a.equipment.unequip("body")
	assert_approx(a.stat("armor"), base_armor)


func test_two_handed_clears_off_hand() -> void:
	var a := make_actor("player")
	a.inventory.add_item("hunting_bow")
	a.inventory.add_item("rusty_sword")
	a.stats.set_base("agility", 10)
	a.equipment.equip(a.inventory.find_first("rusty_sword"))
	var sword := a.equipment.unequip("main_hand")
	a.inventory.remove_instance(sword)
	a.equipment._apply_slot("off_hand", sword)
	assert_not_null(a.equipment.get_item("off_hand"))
	assert_true(a.equipment.equip(a.inventory.find_first("hunting_bow")))
	assert_null(a.equipment.get_item("off_hand"), "2H weapon clears off hand")


func test_intel_gated_relic_requires_knowledge() -> void:
	var a := make_actor("player")
	a.inventory.add_item("relic_ossuary")
	var relic := a.inventory.find_first("relic_ossuary")
	assert_false(relic.identified, "relic starts unidentified")
	assert_false(a.equipment.equip(relic), "cannot equip without lore intel")
	IntelRegistry.acquire("lore_ossuary_relic", "ledger", 0.9)
	assert_true(a.equipment.equip(relic), "equippable once intel is known & reliable")
	assert_true(a.ability_caster.knows("bone_ward"))


func test_stat_requirement_blocks_equip() -> void:
	var a := make_actor("player")
	a.stats.set_base("agility", 5)
	a.inventory.add_item("hunting_bow")
	assert_false(a.equipment.equip(a.inventory.find_first("hunting_bow")))
	a.stats.set_base("agility", 8)
	assert_true(a.equipment.equip(a.inventory.find_first("hunting_bow")))


func test_actor_save_roundtrip() -> void:
	var a := make_actor("player")
	a.inventory.add_item("potion_minor", 4)
	a.inventory.add_item("leather_jerkin")
	a.equipment.equip(a.inventory.find_first("leather_jerkin"))
	a.status_effects.apply("bone_ward")
	a.health.current = 42.0
	var data := a.to_save_data()

	var b := make_actor("player")
	b.from_save_data(data)
	assert_approx(b.health.current, 42.0)
	assert_eq(b.inventory.count_of("potion_minor"), 4)
	assert_not_null(b.equipment.get_item("body"))
	assert_true(b.status_effects.has("bone_ward"))
	assert_approx(b.stat("armor"), a.stat("armor"))
