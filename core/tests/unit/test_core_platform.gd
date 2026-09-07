## Tests for the shared, engine-agnostic platform: definitions, registry,
## stats, inventory, intel journal/query. These run with no graphics engine
## installed, proving the core is truly engine-independent.
extends GutTest

const ITEMS := [
	{"id": "iron_sword", "display_name": "Iron Sword", "category": "weapon",
	 "equip_slot": "weapon", "value": 40, "weight": 3.0, "stats": {"strength": 2},
	 "damage": {"physical": [4, 6]}, "tags": ["melee"]},
	{"id": "healing_herb", "category": "consumable", "value": 8, "max_stack": 10},
	{"id": "smugglers_map", "category": "tome", "value": 60,
	 "grants_intel": ["crypt_location"], "requires": {"flag": "can_read"}},
]

const INTEL := [
	{"id": "crypt_location", "title": "The Sunken Crypt", "subject": "crypt",
	 "scope": "site", "category": "location", "reliability": 0.4,
	 "decay_turns": 10, "value": 100, "secrecy": 0.0,
	 "conflicts": ["crypt_is_myth"], "facts": {"map": "crypt"}, "tags": ["location"]},
	{"id": "crypt_is_myth", "subject": "crypt", "reliability": 0.9, "secrecy": 0.0},
]


func before_each() -> void:
	CoreRegistry.clear()
	for d in ITEMS:
		CoreRegistry.add("items", CoreDefinition.build(CoreItemDefinition, d))
	for d in INTEL:
		CoreRegistry.add("intel", CoreDefinition.build(CoreIntelToken, d))
	CoreIntel.reset()
	CoreContext.reset()
	CoreContext.install(CoreEngineAdapter.new())


# --- Definitions ---------------------------------------------------------------

func test_item_definition_parses_fps_style_fields() -> void:
	var sword := CoreRegistry.get_def("items", "iron_sword") as CoreItemDefinition
	assert_eq(sword.category, CoreItemDefinition.Category.WEAPON)
	assert_true(sword.is_equippable())
	assert_true(sword.is_weapon())
	assert_eq(sword.equip_slot, "weapon")
	assert_almost_eq(sword.average_damage(), 5.0, 0.001)


func test_item_definition_accepts_isometric_kind_and_modifiers() -> void:
	var def := CoreDefinition.build(CoreItemDefinition, {
		"id": "relic", "kind": "artifact", "modifiers": {"sight": 1},
		"slot": "trinket", "consume_on_use": false,
	}) as CoreItemDefinition
	assert_eq(def.category, CoreItemDefinition.Category.ARTIFACT)
	assert_eq(def.stats, {"sight": 1})
	assert_eq(def.equip_slot, "trinket")
	assert_false(def.consumed_on_use)


func test_string_list_fields_tolerate_real_world_authoring() -> void:
	# Regression: the FPS example package authors single-element lists as bare
	# strings and equipment as a slot -> item map. Both must parse, not crash.
	var unit := CoreDefinition.build(CoreUnitDefinition, {
		"id": "bandit", "tags": "melee",
		"abilities": "bandit_stab",
		"equipment": {"body": "leather_jerkin"},
	}) as CoreUnitDefinition
	assert_eq(Array(unit.abilities), ["bandit_stab"])
	assert_eq(Array(unit.tags), ["melee"])
	assert_eq(Array(unit.equipment), ["leather_jerkin"])
	assert_eq(unit.equipment_slots, {"body": "leather_jerkin"})

	# A normal list still works, and empty/missing stays empty.
	var normal := CoreDefinition.build(CoreUnitDefinition, {
		"id": "warden", "abilities": ["cleave", "ward"],
	}) as CoreUnitDefinition
	assert_eq(Array(normal.abilities), ["cleave", "ward"])
	assert_eq(normal.equipment.size(), 0)
	assert_eq(normal.equipment_slots, {})


func test_definition_keeps_unknown_keys_in_raw() -> void:
	var def := CoreDefinition.build(CoreItemDefinition, {"id": "x", "my_game_key": 42})
	assert_eq(def.extra("my_game_key"), 42)


func test_unit_definition_defaults_and_loot() -> void:
	var unit := CoreDefinition.build(CoreUnitDefinition, {
		"id": "bone_warden", "role": "monster", "stats": {"health": 20, "moves": 2},
		"loot": [{"item": "bone_dust", "count": 2, "chance": 1.0},
				 {"item": "never", "chance": 0.0}],
	}) as CoreUnitDefinition
	assert_eq(unit.display_name, "Bone Warden")
	assert_eq(unit.base_stat("health"), 20.0)
	assert_true(unit.is_mobile())
	assert_false(unit.is_hero())
	var rng := RandomNumberGenerator.new()
	assert_eq(unit.roll_loot(rng), {"bone_dust": 2})


func test_faction_definition_stances() -> void:
	var f := CoreDefinition.build(CoreFactionDefinition, {
		"id": "crown", "hostile_to": ["undead"], "allied_to": ["merchants"],
	}) as CoreFactionDefinition
	assert_eq(f.stance_toward("undead"), "hostile")
	assert_eq(f.stance_toward("merchants"), "allied")
	assert_eq(f.stance_toward("strangers"), "neutral")
	assert_true(f.is_hostile_to("undead"))


# --- Registry -------------------------------------------------------------------

func test_registry_lookup_and_filters() -> void:
	assert_true(CoreRegistry.has("items", "iron_sword"))
	assert_eq(CoreRegistry.ids("items").size(), 3)
	assert_eq(CoreRegistry.with_tag("items", "melee").size(), 1)
	assert_eq(CoreRegistry.filter("items", "rarity", "common").size(), 3)


# --- Stats -----------------------------------------------------------------------

func test_stats_modifiers_and_clamping() -> void:
	var stats := CoreStats.new()
	stats.define_from({"health": 10.0, "strength": 5.0})
	assert_eq(stats.get_value("health"), 10.0)

	stats.add_modifier("equip:weapon", {"strength": 2.0})
	assert_eq(stats.max_value("strength"), 7.0)

	stats.remove_modifier("equip:weapon")
	assert_eq(stats.max_value("strength"), 5.0)

	stats.modify("health", -100.0)
	assert_eq(stats.get_value("health"), 0.0)   # clamped, never negative
	stats.restore_all()
	assert_eq(stats.get_value("health"), 10.0)


func test_stats_emit_depleted_signal() -> void:
	var stats := CoreStats.new()
	stats.define_from({"health": 5.0})
	watch_signals(stats)
	stats.modify("health", -5.0)
	assert_signal_emitted(stats, "depleted")


func test_stats_ratio_and_save_roundtrip() -> void:
	var stats := CoreStats.new()
	stats.define_from({"health": 20.0})
	stats.set_value("health", 5.0)
	assert_almost_eq(stats.ratio("health"), 0.25, 0.001)

	var restored := CoreStats.new()
	restored.from_save_data(stats.to_save_data())
	assert_eq(restored.get_value("health"), 5.0)


# --- Inventory --------------------------------------------------------------------

func test_inventory_add_remove_and_value() -> void:
	var inv := CoreInventory.new("hero", "player")
	assert_true(inv.add_item("iron_sword"))
	assert_true(inv.add_item("healing_herb", 3))
	assert_eq(inv.count("healing_herb"), 3)
	assert_eq(inv.total_value(), 40 + 24)
	assert_almost_eq(inv.total_weight(), 3.0, 0.001)

	assert_true(inv.remove_item("healing_herb", 3))
	assert_false(inv.has_item("healing_herb"))
	assert_false(inv.remove_item("healing_herb"))   # nothing left


func test_inventory_equip_applies_stat_modifier() -> void:
	var stats := CoreStats.new()
	stats.define_from({"strength": 5.0})
	var inv := CoreInventory.new("hero", "player")
	inv.stats = stats

	inv.add_item("iron_sword")
	assert_true(inv.equip("iron_sword"))
	assert_eq(stats.max_value("strength"), 7.0)
	assert_eq(inv.equipped_in("weapon"), "iron_sword")

	inv.unequip("weapon")
	assert_eq(stats.max_value("strength"), 5.0)


func test_inventory_use_is_gated_by_intel_query() -> void:
	var inv := CoreInventory.new("hero", "player")
	inv.add_item("smugglers_map")
	# requires {"flag": "can_read"} which is not set yet
	assert_false(inv.use_item("smugglers_map"))
	assert_false(CoreIntel.knows("player", "crypt_location"))

	CoreContext.set_flag("can_read", true)
	assert_true(inv.use_item("smugglers_map"))
	assert_true(CoreIntel.knows("player", "crypt_location"))


func test_inventory_currency() -> void:
	var inv := CoreInventory.new("hero")
	inv.add_currency("gold", 100)
	assert_true(inv.spend_currency("gold", 40))
	assert_eq(inv.currency("gold"), 60)
	assert_false(inv.spend_currency("gold", 999))
	assert_eq(inv.currency("gold"), 60)
