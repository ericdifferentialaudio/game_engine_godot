extends GutTest
## Engine mechanics added for the Zork game, exercised against the real zork
## package: dialogue answers tied to intel tokens, debunking, container /
## pickup / examine interactions, melee execution and scoring.


class FakePoi:
	extends Node3D
	var definition: PoiDefinition
	var _st := {}
	func get_state() -> Dictionary:
		return _st


var _player: Actor


func before_all() -> void:
	if CoreContext.adapter == null or CoreContext.adapter.engine_id != "fps":
		CoreContext.install(FpsEngineAdapter.new())
	assert_true(GameManager.load_game("zork"), "zork package loads")


func before_each() -> void:
	GameManager.start_new_game_headless()
	GameManager.score = 0
	GameManager._score_sources.clear()
	MapManager.map_states.clear()
	_player = _make_actor("player", true)


func after_each() -> void:
	for a in get_tree().get_nodes_in_group("actors"):
		a.queue_free()


func _make_actor(def_id: String, is_player: bool) -> Actor:
	var a := Actor.new()
	a.actor_def_id = def_id
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	a.add_child(shape)
	var brain: Brain = PlayerBrain.new() if is_player else Brain.new()
	a.add_child(brain)
	add_child_autofree(a)
	if is_player:
		GameManager.player = a
	return a


func _dialogue(actor_id: String, index: int = 0) -> DialogueInteraction:
	var def := DefinitionRegistry.get_def("actors", actor_id) as ActorDefinition
	var spec: Dictionary = def.raw["interactions"][index].duplicate(true)
	spec["index"] = index
	var poi := FakePoi.new()
	poi.definition = PoiDefinition.from_dict({"id": actor_id, "display_name": def.display_name})
	add_child_autofree(poi)
	var d := InteractionFactory.create(spec, poi) as DialogueInteraction
	d._by = _player
	return d


func _start_at(d: DialogueInteraction, node: String) -> void:
	d.current = node
	d._enter(node)


func _choice_index(d: DialogueInteraction, text_prefix: String) -> int:
	var choices := d.available_choices()
	for i in choices.size():
		if str(choices[i]["text"]).begins_with(text_prefix):
			return i
	return -1


func _poi_with(spec: Dictionary, poi_id: String = "test_poi") -> Interaction:
	var poi := FakePoi.new()
	poi.definition = PoiDefinition.from_dict({"id": poi_id, "map": "kitchen", "display_name": poi_id})
	add_child_autofree(poi)
	spec["index"] = 0
	return InteractionFactory.create(spec, poi)


# --- Dialogue: answers are checked against what the player actually knows ----

func test_troll_name_bluff_fails_without_the_token() -> void:
	var d := _dialogue("troll")
	_start_at(d, "greet")
	d.choose(_choice_index(d, "'I know your name"))
	assert_eq(d.current, "name_challenge")
	var idx := _choice_index(d, "'Greldok.'")
	assert_true(idx >= 0, "the right answer is always offered as text")
	d.choose(idx)
	assert_eq(d.last_result, "fail", "saying the name without knowing it is a bluff")
	assert_eq(d.current, "name_bluff")
	d.advance()
	assert_eq(d.current, "fight")
	assert_false(GameManager.has_flag("troll_pacified"))


func test_troll_name_succeeds_with_reliable_token_and_debunks_rumor() -> void:
	IntelRegistry.acquire("know_troll_name", "cellar_carving", 0.85)
	IntelRegistry.acquire("rumor_troll_name_false", "attic_scrawl", 0.2)
	var d := _dialogue("troll")
	_start_at(d, "greet")
	d.choose(_choice_index(d, "'I know your name"))
	d.choose(_choice_index(d, "'Greldok.'"))
	assert_eq(d.last_result, "pass")
	assert_eq(d.current, "name_right")
	assert_true(GameManager.has_flag("troll_pacified"))
	assert_true(IntelRegistry.is_debunked("rumor_troll_name_false"), "the false rumour is marked false")
	assert_eq(IntelRegistry.get_token("rumor_troll_name_false").reliability, 0.0)
	assert_eq(IntelRegistry.get_token("know_troll_name").reliability, 1.0, "the truth is confirmed")
	assert_eq(GameManager.score, 10)


func test_wrong_name_from_false_rumor_routes_to_fight() -> void:
	IntelRegistry.acquire("rumor_troll_name_false", "attic_scrawl", 0.2)
	var d := _dialogue("troll")
	_start_at(d, "name_challenge")
	d.choose(_choice_index(d, "'Mr. Chompers.'"))
	assert_eq(d.last_result, "fail", "the rumour's fact does not match the real name")
	assert_eq(d.current, "name_wrong")
	d.advance()
	assert_eq(d.current, "fight")


func test_low_reliability_token_is_not_enough() -> void:
	IntelRegistry.acquire("know_troll_name", "troll_hint", 0.2)   # the troll's own taunt
	var d := _dialogue("troll")
	_start_at(d, "name_challenge")
	d.choose(_choice_index(d, "'Greldok.'"))
	assert_eq(d.last_result, "fail", "min_reliability 0.5 gate holds")


func test_item_gated_choice_requires_and_consumes_item() -> void:
	var d := _dialogue("troll")
	_start_at(d, "greet")
	assert_eq(_choice_index(d, "Offer him the lunch"), -1, "no lunch, no offer")
	_player.inventory.add_item("lunch", 1)
	var idx := _choice_index(d, "Offer him the lunch")
	assert_true(idx >= 0)
	d.choose(idx)
	assert_eq(d.current, "offer_lunch")
	assert_false(_player.inventory.has_item("lunch"), "take_items removed the lunch")
	assert_true(IntelRegistry.is_debunked("rumor_troll_loves_food"))


func test_thief_name_check_pass_and_free_egg_opening() -> void:
	IntelRegistry.acquire("know_thief_true_name", "dead_adventurer", 0.6)
	IntelRegistry.acquire("know_thief_is_thief", "dead_adventurer", 0.9)
	_player.inventory.add_item("jewelled_egg", 1)
	var d := _dialogue("thief")
	_start_at(d, "greet")
	var idx := _choice_index(d, "Address him by name")
	assert_true(idx >= 0, "offered once two things about the thief are known")
	d.choose(idx)
	d.choose(_choice_index(d, "'Tarbel Flathead.'"))
	assert_eq(d.last_result, "pass")
	assert_true(GameManager.has_flag("thief_named"))
	d.choose(_choice_index(d, "'Open the egg"))
	assert_true(_player.inventory.has_item("golden_canary"))
	assert_true(_player.inventory.has_item("jewelled_egg"), "free opening keeps the shell")


func test_thief_false_name_from_visitors_book_fails() -> void:
	IntelRegistry.acquire("rumor_thief_name_false", "gallery_plaque", 0.3)
	var d := _dialogue("thief")
	_start_at(d, "name_challenge")
	d.choose(_choice_index(d, "'Sir Reginald"))
	assert_eq(d.last_result, "fail")
	assert_eq(d.current, "name_wrong")
	d.advance()
	assert_eq(d.current, "fight")
	assert_true(IntelRegistry.is_debunked("rumor_thief_name_false"))


func test_headless_auto_walk_terminates() -> void:
	var d := _dialogue("thief")
	d.run(_player)
	assert_true(d.is_finished())


# --- Interactions -------------------------------------------------------------

func test_container_gives_contents_then_accepts_treasure_with_score() -> void:
	var inter := _poi_with({"kind": "container", "contents": {"leaflet": 1}, "accepts": ["treasure"]}) as ContainerInteraction
	inter.run(_player)
	assert_true(_player.inventory.has_item("leaflet"))
	inter.run(_player)   # empty now, nothing to deposit
	assert_eq(GameManager.score, 0)
	_player.inventory.add_item("jewelled_egg", 1)
	inter.run(_player)
	assert_false(_player.inventory.has_item("jewelled_egg"), "treasure deposited")
	assert_eq(GameManager.score, 5, "treasure_score awarded")
	assert_eq(int(inter.deposited().get("jewelled_egg", 0)), 1)


func test_pickup_marks_taken_and_only_runs_once() -> void:
	var inter := _poi_with({"kind": "pickup", "items": {"rope": 1}})
	assert_true(inter.can_run(_player))
	inter.run(_player)
	assert_true(_player.inventory.has_item("rope"))
	assert_false(inter.can_run(_player))


func test_examine_grants_intel_with_reliability_and_flags() -> void:
	var inter := _poi_with({"kind": "examine", "text": "x", "grant_intel": ["know_grating"], "reliability": 0.8,
		"set_flags": ["leaves_moved"]})
	inter.run(_player)
	assert_true(GameManager.has_flag("leaves_moved"))
	assert_almost_eq(IntelRegistry.get_token("know_grating").reliability, 0.8, 0.001)


func test_requires_item_blocks_and_missing_text_is_exposed() -> void:
	var inter := _poi_with({"kind": "examine", "text": "unlocked", "requires_item": {"skeleton_key": 1},
		"missing_item_text": "no key"})
	assert_false(inter.can_run(_player))
	assert_eq(inter.missing_item_text(_player), "no key")
	_player.inventory.add_item("skeleton_key", 1)
	assert_true(inter.can_run(_player))


func test_debunk_without_prior_token_records_it_as_false() -> void:
	IntelRegistry.debunk("rumor_rug_worthless", "test")
	assert_true(IntelRegistry.has("rumor_rug_worthless"))
	assert_eq(IntelRegistry.get_token("rumor_rug_worthless").reliability, 0.0)
	assert_false(IntelRegistry.evaluate({"has": "rumor_rug_worthless", "min_reliability": 0.1}))


# --- Combat --------------------------------------------------------------------

func test_melee_hits_troll_in_front_and_misses_behind() -> void:
	var troll := _make_actor("troll", false)
	_player.global_position = Vector3.ZERO
	_player.rotation.y = 0.0                 # facing -Z
	troll.global_position = Vector3(0, 0, -1.5)
	var hp_before: float = troll.health.current
	var def := DefinitionRegistry.get_def("abilities", "punch") as AbilityDefinition
	_player.ability_caster._execute(def, null)
	assert_lt(troll.health.current, hp_before, "troll in front takes damage")
	var hp_mid: float = troll.health.current
	troll.global_position = Vector3(0, 0, 1.5)  # behind
	_player.ability_caster._execute(def, null)
	assert_eq(troll.health.current, hp_mid, "troll behind is untouched")


func test_weapon_damage_is_added_when_ability_scales_with_weapon() -> void:
	_player.inventory.add_item("elvish_sword", 1)   # zork_boot auto-wields a weapon when unarmed
	if _player.equipment.main_weapon() == null:
		_player.equipment.equip(_player.inventory.find_first("elvish_sword"))
	assert_eq(_player.equipment.main_weapon().def.id, "elvish_sword")
	var slash := DefinitionRegistry.get_def("abilities", "sword_slash") as AbilityDefinition
	var info := _player.ability_caster.build_damage(slash)
	assert_true(info.amounts.has("slash"))
	assert_gt(float(info.amounts["slash"]), 5.0, "sword ranges (5-9) + strength scaling + attack stat")


func test_killing_troll_sets_death_flag_and_drops_axe() -> void:
	var troll := _make_actor("troll", false)
	troll.global_position = Vector3(3, 0, 3)
	troll.take_damage(DamageInfo.single("true", 9999.0, _player))
	assert_true(troll.is_dead)
	assert_true(GameManager.has_flag("troll_dead"))
	assert_true(IntelRegistry.has("troll_dead"))
	var found := false
	for c in get_children():
		if c is WorldPickup and c.items.has("bloody_axe"):
			found = true
			c.queue_free()
	assert_true(found, "troll's axe dropped as a WorldPickup")


func test_score_source_only_counts_once() -> void:
	assert_true(GameManager.add_score(5, "deposit:egg"))
	assert_false(GameManager.add_score(5, "deposit:egg"))
	assert_eq(GameManager.score, 5)

