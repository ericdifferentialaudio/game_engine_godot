## Tests for the shared place framework: the generic vocabulary (towns,
## castles, shrines, lairs, dungeons, portals, resources) and — more
## importantly — that a game can extend ALL of it: new categories, new traits,
## new fields, archetype inheritance, and procedural instantiation.
extends GutTest


func before_each() -> void:
	CoreRegistry.clear()
	CoreContext.reset()
	CoreContext.install(CoreEngineAdapter.new())


func _place(d: Dictionary) -> CorePlaceDefinition:
	return CoreDefinition.build(CorePlaceDefinition, d) as CorePlaceDefinition


# --- The generic vocabulary -------------------------------------------------------

func test_builtin_categories_carry_sensible_traits() -> void:
	assert_true(_place({"id": "a", "category": "village"}).is_settlement())
	assert_true(_place({"id": "b", "category": "castle"}).is_fortification())
	assert_true(_place({"id": "c", "category": "shrine"}).is_sacred())
	assert_true(_place({"id": "d", "category": "lair"}).is_dangerous())
	assert_true(_place({"id": "e", "category": "mine"}).is_economic())
	assert_true(_place({"id": "f", "category": "portal"}).is_transit())


func test_category_defaults_apply_without_being_restated() -> void:
	var castle := _place({"id": "greyhold", "category": "castle"})
	assert_eq(castle.defense_bonus, 75.0)
	assert_eq(castle.sight, 4)
	assert_true(castle.is_capturable())


func test_place_can_override_any_category_default() -> void:
	var weak := _place({"id": "ruined_castle", "category": "castle",
		"defense_bonus": 5.0, "capturable": false})
	assert_eq(weak.defense_bonus, 5.0)
	assert_false(weak.is_capturable())
	assert_true(weak.is_fortification(), "overriding a value keeps the category traits")


func test_unknown_category_still_works() -> void:
	# A game may invent a category the framework has never seen.
	var p := _place({"id": "lighthouse_1", "category": "lighthouse", "sight": 8})
	assert_eq(p.category, "lighthouse")
	assert_eq(p.sight, 8)
	assert_eq(p.visual_key, "place.lighthouse")
	assert_false(p.is_settlement())


# --- Extension case 1: a special dragon lair ----------------------------------------

func test_game_can_register_a_new_category_with_traits() -> void:
	CorePlaceDefinition.register_category("dragon_lair", {
		"dangerous": true, "capturable": true, "defense_bonus": 60.0, "sight": 3,
		"flying_only": true,
	})
	var lair := _place({"id": "cinderpeak", "category": "dragon_lair"})
	assert_true(lair.is_dangerous())
	assert_eq(lair.defense_bonus, 60.0)
	assert_true(lair.has_trait("flying_only"), "custom traits are queryable")
	assert_true("dragon_lair" in CorePlaceDefinition.known_categories())


func test_special_lair_with_boss_and_arbitrary_game_fields() -> void:
	var lair := _place({
		"id": "cinderpeak", "category": "dragon_lair", "display_name": "Cinderpeak",
		"boss": "ancient_red_dragon",
		"garrison": [{"unit": "drake", "count": 3, "respawn_after": 20}],
		"yields": {"treasure": 5},
		"traits": {"flying_only": true, "heat_damage": 3},
		"hoard_size": 9000,
		"hidden_until": {"has": "rumor_the_burning_peak"},
	})
	assert_true(lair.has_garrison())
	assert_eq(lair.boss, "ancient_red_dragon")

	# Boss is emitted first, then the rest of the garrison.
	var units := lair.garrison_units()
	assert_eq(units.size(), 2)
	assert_eq(units[0]["unit"], "ancient_red_dragon")
	assert_true(units[0]["boss"])
	assert_eq(units[1]["count"], 3)

	assert_eq(lair.yield_of("treasure"), 5.0)
	assert_eq(lair.trait_value("heat_damage"), 3, "non-boolean traits survive")
	assert_eq(lair.extra("hoard_size"), 9000, "unmapped game fields survive in raw")
	assert_false(lair.hidden_until.is_empty())


# --- Extension case 2: a special resource on an island --------------------------------

func test_island_resource_with_access_requirement() -> void:
	var shoal := _place({
		"id": "pearl_shoal", "category": "island_resource",
		"display_name": "Pearl Shoal",
		"yields": {"pearls": 3},
		"requires_access": "boat",
		"placement": "random_coast",
		"placement_rules": {"min_distance_from_land": 2},
		"traits": {"island": true, "storm_risk": 0.2, "economic": true},
		"capturable": true,
	})
	assert_eq(shoal.yield_of("pearls"), 3.0)
	assert_eq(shoal.requires_access, "boat")
	assert_eq(shoal.placement, "random_coast")
	assert_eq(shoal.placement_rules["min_distance_from_land"], 2)
	assert_true(shoal.has_trait("island"))
	assert_eq(shoal.trait_value("storm_risk"), 0.2)
	assert_true(shoal.is_economic(), "a game can opt into a framework trait")
	assert_true(shoal.is_capturable())


# --- Archetype inheritance ("generic, but built upon") ---------------------------------

func test_extends_inherits_archetype_and_applies_overrides() -> void:
	CoreRegistry.add_archetype("places", {
		"id": "village", "category": "village", "display_name": "Village",
		"population": 200, "yields": {"food": 1},
		"interactions": [{"kind": "dialogue", "dialogue": "villager_generic"}],
	})
	var place := CoreRegistry.instantiate("places", "village", {
		"id": "hollowmere", "display_name": "Hollowmere", "owner": "greywood",
	}) as CorePlaceDefinition

	assert_eq(place.id, "hollowmere")
	assert_eq(place.display_name, "Hollowmere")
	assert_eq(place.owner_id, "greywood")
	# Inherited, never restated:
	assert_eq(place.population, 200)
	assert_eq(place.yield_of("food"), 1.0)
	assert_true(place.is_settlement())
	assert_eq(place.interactions.size(), 1)


func test_deep_merge_overrides_one_nested_key_only() -> void:
	var merged := CoreRegistry.deep_merge(
		{"yields": {"food": 1, "gold": 2}, "traits": {"a": true}},
		{"yields": {"gold": 9}})
	assert_eq(merged["yields"]["gold"], 9, "overridden")
	assert_eq(merged["yields"]["food"], 1, "sibling preserved")
	assert_eq(merged["traits"]["a"], true, "untouched branch preserved")


func test_instantiate_from_unknown_archetype_is_survivable() -> void:
	var p := CoreRegistry.instantiate("places", "not_a_thing",
		{"id": "x", "category": "generic"}) as CorePlaceDefinition
	assert_not_null(p)
	assert_eq(p.id, "x")


# --- Containment: castles contain buildings, dungeons have levels ----------------------

func test_places_can_contain_places_and_lead_to_maps() -> void:
	var castle := _place({
		"id": "greyhold", "category": "castle",
		"contains": ["greyhold_courtyard", "greyhold_keep"],
		"leads_to": "greyhold_interior",
	})
	assert_eq(Array(castle.contains), ["greyhold_courtyard", "greyhold_keep"])
	assert_eq(castle.leads_to, "greyhold_interior")
	assert_true(castle.is_enterable(), "leads_to implies enterable")

	var room := _place({"id": "greyhold_keep", "category": "keep",
		"parent": "greyhold", "map": "greyhold_interior"})
	assert_eq(room.parent_place_id, "greyhold")
	assert_eq(room.map_id, "greyhold_interior")


# --- Placement is engine-neutral --------------------------------------------------------

func test_place_accepts_2d_tile_or_3d_position() -> void:
	var iso := _place({"id": "a", "category": "village", "coord": [7, 6]})
	assert_eq(iso.coord, Vector2i(7, 6))
	assert_eq(iso.placement, "fixed")

	var fps := _place({"id": "b", "category": "shop", "position": [3.0, 0.0, -12.0], "yaw": 90.0})
	assert_eq(fps.position, [3.0, 0.0, -12.0])
	assert_eq(fps.yaw, 90.0)
	assert_eq(fps.placement, "fixed")

	var generated := _place({"id": "c", "category": "ruins"})
	assert_eq(generated.placement, "random_land", "no anchor => generator places it")


# --- The shipped archetype library ---------------------------------------------------

func test_framework_ships_a_usable_generic_library() -> void:
	# Loaded by CoreRegistry._ready() from addons/game_core/data/places.json.
	var ids := CoreRegistry.archetype_ids("places")
	for expected in ["village", "town", "city", "castle", "shrine", "lair",
			"dungeon", "ruins", "portal", "mine", "inn"]:
		assert_true(expected in ids, "ships a '%s' archetype" % expected)


func test_shipped_archetypes_chain_correctly() -> void:
	# city extends town extends village -- three levels deep.
	var city := CoreRegistry.instantiate("places", "city",
		{"id": "aurelia"}) as CorePlaceDefinition
	assert_eq(city.category, "city")
	assert_eq(city.population, 12000, "own value wins")
	assert_eq(city.yield_of("gold"), 3.0)
	assert_true(city.is_settlement())
	assert_true(city.is_capturable())
	assert_eq(city.defense_bonus, 40.0, "from the city category traits")
	# Interactions were inherited from `town`, not redeclared on `city`.
	assert_eq(city.interactions.size(), 2)


func test_game_can_extend_a_shipped_archetype_into_something_special() -> void:
	# The full pattern: framework ships "lair"; the game builds a dragon lair.
	CoreRegistry.add_archetype("places", {
		"id": "dragon_lair", "extends": "lair", "category": "dragon_lair",
		"traits": {"flying_only": true},
		"garrison": [{"unit": "drake", "count": 3}],
	})
	var lair := CoreRegistry.instantiate("places", "dragon_lair", {
		"id": "cinderpeak", "display_name": "Cinderpeak",
		"boss": "ancient_red_dragon", "yields": {"treasure": 5},
	}) as CorePlaceDefinition

	assert_eq(lair.id, "cinderpeak")
	assert_eq(lair.boss, "ancient_red_dragon")
	assert_eq(lair.garrison_units().size(), 2)
	assert_eq(lair.yield_of("treasure"), 5.0)
