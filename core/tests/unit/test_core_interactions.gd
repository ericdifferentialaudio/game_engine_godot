## Tests for the shared interaction system and live places.
##
## Correctness target is the real authored content from the reference games:
## the same gating, ordering, once-semantics and quest stages that
## example_realm_iso/sites.json relies on.
extends GutTest

## Records what the "engine" was asked to do, so core logic can be tested with
## no graphics engine present.
class SpyAdapter extends CoreEngineAdapter:
	var spawned: Array = []
	var traversed: Array = []
	var shops: Array = []
	var dialogues: Array = []
	var resources: Array = []
	var notices: Array = []
	var stances: Array = []
	var combat_result: Dictionary = {}
	var access: Array[String] = []
	var holders: Array[String] = []
	var relations: Dictionary = {}
	var holder_flags: Dictionary = {}

	func _init() -> void:
		engine_id = "spy"

	func spawn_units(spec: Dictionary, holder: String, _near = null) -> Array[String]:
		spawned.append({"spec": spec, "holder": holder})
		var out: Array[String] = []
		for i in int(spec.get("count", 1)):
			out.append("%s_%d" % [str(spec.get("unit", "unit")), i])
		return out

	func traverse(holder: String, target_map: String, target_spawn: String, _actor = null) -> bool:
		traversed.append({"holder": holder, "map": target_map, "spawn": target_spawn})
		return true

	func open_shop(holder: String, shop_spec: Dictionary, _actor = null) -> bool:
		shops.append({"holder": holder, "spec": shop_spec})
		return true

	func start_dialogue(holder: String, dialogue_id: String, _actor = null) -> bool:
		dialogues.append({"holder": holder, "dialogue": dialogue_id})
		return true

	func resolve_combat(_holder: String, _spec: Dictionary, _actor = null, _target = null) -> Dictionary:
		return combat_result

	func add_resource(holder: String, resource_id: String, amount: float) -> void:
		resources.append({"holder": holder, "res": resource_id, "amount": amount})

	func notify(text: String, category: String = "info") -> void:
		notices.append({"text": text, "category": category})

	func set_stance(holder: String, other: String, stance: String) -> void:
		stances.append({"holder": holder, "other": other, "stance": stance})

	func has_access(_holder: String, a: String) -> bool:
		return a in access

	func all_holders() -> Array[String]:
		return holders

	func related_holders(holder: String, relation: String) -> Array[String]:
		var out: Array[String] = []
		for h in relations.get("%s|%s" % [holder, relation], []):
			out.append(str(h))
		return out

	func holder_flag(holder: String, flag: String) -> bool:
		return bool(holder_flags.get("%s|%s" % [holder, flag], false))

	func set_holder_flag(holder: String, flag: String, value: bool) -> bool:
		holder_flags["%s|%s" % [holder, flag]] = value
		return true


const INTEL := [
	{"id": "rumor_crypt_west", "subject": "crypt", "category": "rumor",
	 "reliability": 0.35, "secrecy": 0.1, "value": 15},
	{"id": "rumor_crypt_reeds", "subject": "crypt", "category": "rumor",
	 "reliability": 0.5, "secrecy": 0.3, "value": 20},
	{"id": "ruin_inscription", "subject": "ruins", "category": "lore",
	 "reliability": 0.7, "secrecy": 0.2, "value": 12},
	{"id": "crypt_location", "subject": "crypt", "category": "location",
	 "reliability": 0.8, "secrecy": 0.6, "value": 60},
	{"id": "state_secret", "subject": "crown", "category": "secret",
	 "reliability": 1.0, "secrecy": 0.95},
]

var spy: SpyAdapter


func before_each() -> void:
	CoreRegistry.clear()
	for d in INTEL:
		CoreRegistry.add("intel", CoreDefinition.build(CoreIntelToken, d))
	CoreIntel.reset()
	CoreContext.reset()
	spy = SpyAdapter.new()
	CoreContext.install(spy)
	CoreContext.configure({"seed": 4242})


func _run(spec: Dictionary, holder: String = "blue", actor = null) -> bool:
	var inter := CoreInteractionFactory.create(spec, "test_place")
	return inter != null and inter.run(holder, actor)


# --- The factory ------------------------------------------------------------------

func test_all_kinds_from_both_engines_are_available() -> void:
	for kind in ["intel", "reward", "flag", "portal", "spawn", "shop", "dialogue", "combat"]:
		assert_true(CoreInteractionFactory.has_kind(kind), "kind '%s' exists" % kind)


func test_games_can_register_their_own_kind() -> void:
	CoreInteractionFactory.register("ritual", CoreFlagInteraction)
	assert_true(CoreInteractionFactory.has_kind("ritual"))
	assert_not_null(CoreInteractionFactory.create({"kind": "ritual"}))


func test_unknown_kind_is_survivable() -> void:
	assert_null(CoreInteractionFactory.create({"kind": "does_not_exist"}))


# --- Shared gating (every kind gets it) ---------------------------------------------

func test_requires_gate_blocks_until_intel_is_held() -> void:
	var spec := {"kind": "flag", "set_flags": ["opened"],
		"requires": {"has": "crypt_location"}}
	assert_false(_run(spec))
	assert_false(CoreContext.has_flag("opened"))

	CoreIntel.acquire("blue", "crypt_location", "sage", "told")
	assert_true(_run(spec))
	assert_true(CoreContext.has_flag("opened"))


func test_once_runs_a_single_time_ever() -> void:
	var inter := CoreInteractionFactory.create(
		{"kind": "reward", "resources": {"gold": 10}, "once": true}, "cache")
	assert_true(inter.run("blue"))
	assert_false(inter.run("blue"), "second run blocked")
	assert_false(inter.run("red"), "blocked for everyone")
	assert_eq(spy.resources.size(), 1)


func test_once_per_holder_runs_again_for_a_different_holder() -> void:
	var inter := CoreInteractionFactory.create(
		{"kind": "reward", "resources": {"gold": 10}, "once_per_holder": true}, "cache")
	assert_true(inter.run("blue"))
	assert_false(inter.run("blue"))
	assert_true(inter.run("red"), "a different holder may still run it")
	assert_eq(spy.resources.size(), 2)


func test_holder_flag_gate() -> void:
	var spec := {"kind": "flag", "set_flags": ["x"], "holder_flags": ["met_elders"]}
	assert_false(_run(spec))
	CoreContext.set_holder_flag("blue", "met_elders", true)
	assert_true(_run(spec))


func test_message_is_routed_to_the_engine() -> void:
	_run({"kind": "flag", "set_flags": ["a"], "message": "You find a hidden cache."})
	assert_eq(spy.notices.size(), 1)
	assert_eq(spy.notices[0]["text"], "You find a hidden cache.")


# --- Individual kinds -----------------------------------------------------------------

func test_intel_interaction_grants_debunks_and_shares() -> void:
	_run({"kind": "intel", "tokens": ["rumor_crypt_west", "ruin_inscription"],
		"channel": "told"})
	assert_true(CoreIntel.knows("blue", "rumor_crypt_west"))
	assert_true(CoreIntel.knows("blue", "ruin_inscription"))

	_run({"kind": "intel", "tokens": [], "debunk": ["rumor_crypt_west"]})
	assert_false(CoreIntel.knows("blue", "rumor_crypt_west"), "debunked")

	_run({"kind": "intel", "share": {"to": "red", "tokens": ["ruin_inscription"]}})
	assert_true(CoreIntel.knows("red", "ruin_inscription"), "scripted leak")


func test_flag_interaction_records_quest_stages() -> void:
	watch_signals(CoreContext)
	_run({"kind": "flag", "quest": {"id": "sunken_crypt", "stage": "cleared"},
		"set_flags": ["crypt_cleared"]})
	assert_true(CoreContext.has_quest_stage("sunken_crypt", "cleared"))
	assert_true(CoreContext.has_flag("crypt_cleared"))
	assert_eq(CoreContext.quest_stages("sunken_crypt"), ["cleared"] as Array[String])
	assert_signal_emitted(CoreContext, "quest_stage_reached")


func test_flag_interaction_changes_stance() -> void:
	_run({"kind": "flag", "stance": {"with": "greywood", "stance": "friendly"}})
	assert_eq(spy.stances.size(), 1)
	assert_eq(spy.stances[0]["stance"], "friendly")


func test_portal_interaction_delegates_traversal() -> void:
	_run({"kind": "portal", "target_map": "crypt_l1", "target_spawn": "entrance"})
	assert_eq(spy.traversed.size(), 1)
	assert_eq(spy.traversed[0]["map"], "crypt_l1")


func test_spawn_interaction_resolves_actor_faction() -> void:
	_run({"kind": "spawn", "unit": "wolf", "faction": "actor", "count": 2})
	assert_eq(spy.spawned.size(), 1)
	assert_eq(spy.spawned[0]["spec"]["faction"], "blue", "'actor' resolves to the holder")
	assert_eq(spy.spawned[0]["spec"]["count"], 2)


func test_shop_stock_is_filtered_by_intel_gates() -> void:
	var inter := CoreInteractionFactory.create({"kind": "shop", "shop": "marrow", "stock": [
		"healing_herb",
		{"item": "tide_charts", "requires": {"has": "rumor_crypt_reeds"}},
	]}, "marrow_counter") as CoreShopInteraction

	assert_eq(inter.visible_stock("blue").size(), 1, "gated item hidden")
	CoreIntel.acquire("blue", "rumor_crypt_reeds", "smuggler", "told")
	assert_eq(inter.visible_stock("blue").size(), 2, "gated item revealed")

	inter.run("blue")
	assert_eq(spy.shops.size(), 1)


func test_dialogue_interaction_grants_meeting_intel() -> void:
	_run({"kind": "dialogue", "dialogue": "elder_maren", "tokens": ["ruin_inscription"]})
	assert_eq(spy.dialogues[0]["dialogue"], "elder_maren")
	assert_true(CoreIntel.knows("blue", "ruin_inscription"))


func test_combat_runs_on_victory_follow_ups() -> void:
	spy.combat_result = {"victory": true}
	_run({"kind": "combat", "target": "guardian",
		"on_victory": [{"kind": "reward", "resources": {"gold": 50}}]})
	assert_eq(spy.resources.size(), 1, "victory reward granted")

	spy.resources.clear()
	spy.combat_result = {"victory": false}
	_run({"kind": "combat", "on_victory": [{"kind": "reward", "resources": {"gold": 50}}],
		"on_defeat": [{"kind": "flag", "set_flags": ["fled"]}]})
	assert_eq(spy.resources.size(), 0, "no reward on defeat")
	assert_true(CoreContext.has_flag("fled"))


# --- Ordered dispatch -------------------------------------------------------------------

func test_run_all_stops_at_the_first_consuming_interaction() -> void:
	var specs := [
		{"kind": "flag", "set_flags": ["first"], "consumes": false},
		{"kind": "flag", "set_flags": ["second"]},
		{"kind": "flag", "set_flags": ["third"]},
	]
	var list := CoreInteractionFactory.create_all(specs, "place", {})
	var ran := CoreInteractionFactory.run_all(list, "blue")
	assert_eq(ran, 2)
	assert_true(CoreContext.has_flag("first"))
	assert_true(CoreContext.has_flag("second"))
	assert_false(CoreContext.has_flag("third"), "stopped after a consuming interaction")


func test_run_all_skips_gated_entries_and_continues() -> void:
	var specs := [
		{"kind": "flag", "set_flags": ["gated"], "requires": {"has": "crypt_location"}},
		{"kind": "flag", "set_flags": ["fallback"]},
	]
	var list := CoreInteractionFactory.create_all(specs, "place", {})
	assert_eq(CoreInteractionFactory.run_all(list, "blue"), 1)
	assert_false(CoreContext.has_flag("gated"))
	assert_true(CoreContext.has_flag("fallback"))


# --- Live places ---------------------------------------------------------------------

func _place(d: Dictionary) -> CorePlace:
	return CorePlace.new(CoreDefinition.build(CorePlaceDefinition, d) as CorePlaceDefinition)


func test_place_discovery_grants_intel_once() -> void:
	var p := _place({"id": "hollowmere", "category": "village",
		"discover_intel": ["ruin_inscription"]})
	watch_signals(p)
	assert_true(p.discover("blue"))
	assert_true(CoreIntel.knows("blue", "ruin_inscription"))
	assert_signal_emitted(p, "discovered")
	assert_false(p.discover("blue"), "already discovered")


func test_hidden_place_is_invisible_until_the_rumour_is_known() -> void:
	var p := _place({"id": "cinderpeak", "category": "lair",
		"hidden_until": {"has": "rumor_crypt_west"}})
	assert_false(p.is_revealed_to("blue"))
	assert_false(p.discover("blue"))

	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told")
	assert_true(p.is_revealed_to("blue"))
	assert_true(p.discover("blue"))


func test_island_place_requires_access_capability() -> void:
	var p := _place({"id": "pearl_shoal", "category": "resource",
		"requires_access": "boat",
		"interactions": [{"kind": "reward", "resources": {"pearls": 3}}]})
	assert_eq(p.interact("blue"), 0, "no boat, no landing")

	spy.access = ["boat"]
	assert_eq(p.interact("blue"), 1)
	assert_eq(spy.resources[0]["res"], "pearls")


func test_place_runs_interactions_in_order_and_persists_state() -> void:
	var p := _place({"id": "standing_stones", "category": "ruins", "interactions": [
		{"kind": "intel", "tokens": ["ruin_inscription"], "once": true, "consumes": false},
		{"kind": "reward", "resources": {"gold": 25}, "once": true},
	]})
	assert_eq(p.interact("blue"), 2)
	assert_true(CoreIntel.knows("blue", "ruin_inscription"))

	# `once` holds across a save/load round trip.
	var saved := p.to_save_data()
	var restored := _place({"id": "standing_stones", "category": "ruins", "interactions": [
		{"kind": "intel", "tokens": ["ruin_inscription"], "once": true, "consumes": false},
		{"kind": "reward", "resources": {"gold": 25}, "once": true},
	]})
	restored.from_save_data(saved)
	assert_eq(restored.interact("blue"), 0, "once-only interactions stay done")


func test_capturable_place_changes_owner() -> void:
	var p := _place({"id": "wolf_den", "category": "camp", "owner": "wilds"})
	watch_signals(p)
	assert_true(p.capture("blue"))
	assert_eq(p.owner_id, "blue")
	assert_signal_emitted(p, "owner_changed")

	var shrine := _place({"id": "crypt_shrine", "category": "shrine"})
	assert_false(shrine.capture("blue"), "shrines are not capturable by default")


func test_place_spawns_its_garrison_through_the_engine() -> void:
	var p := _place({"id": "cinderpeak", "category": "lair", "owner": "monsters",
		"boss": "ancient_red_dragon",
		"garrison": [{"unit": "drake", "count": 3}]})
	var ids := p.spawn_garrison()
	assert_eq(spy.spawned.size(), 2, "boss + garrison entry")
	assert_eq(spy.spawned[0]["spec"]["unit"], "ancient_red_dragon")
	assert_eq(ids.size(), 4, "1 boss + 3 drakes")
