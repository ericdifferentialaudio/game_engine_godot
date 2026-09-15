## End-to-end proof of the narrative stack: Ink engine + bindings + the two
## asset systems + standing + the shared pattern library, driving the real
## compiled zork demo story.
##
## The scene under test gates one choice on three different systems at once
## (currency, knowledge, relationship) and, on success, grants both a physical
## asset and a new piece of knowledge.
extends GutTest

const STORY := "res://ink/round_room_fence.ink.json"
const HOLDER := "player"
const FENCE := "fence"

const INTEL := [
	{"id": "know_trapdoor", "title": "A trap door beneath the rug", "category": "secret",
	 "reliability": 1.0, "secrecy": 0.0, "conflicts": ["rumor_rug_worthless"]},
	{"id": "rumor_rug_worthless", "title": "The rug is just a rug", "category": "rumor",
	 "reliability": 0.3, "secrecy": 0.0, "conflicts": ["know_trapdoor"]},
	{"id": "know_grue", "title": "What a grue is", "category": "lore",
	 "reliability": 1.0, "secrecy": 0.0},
]

const ITEMS := [
	{"id": "zorkmid", "display_name": "Zorkmid", "category": "currency", "value": 1},
	{"id": "brass_lantern", "display_name": "Brass Lantern", "category": "misc", "value": 5},
]

var _bindings: CoreInkBindings
var _adapter: CoreEngineAdapter


func before_each() -> void:
	CoreRegistry.clear()
	for d in INTEL:
		CoreRegistry.add("intel", CoreDefinition.build(CoreIntelToken, d))
	for d in ITEMS:
		CoreRegistry.add("items", CoreDefinition.build(CoreItemDefinition, d))

	CoreIntel.reset()
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()
	CoreContext.rules = {
		"standing": {"tiers": [
			{"id": "stranger", "at": -100.0},
			{"id": "neutral", "at": 0.0},
			{"id": "friendly", "at": 25.0},
			{"id": "trusted", "at": 60.0},
		]},
	}
	_adapter = CoreEngineAdapter.new()
	CoreContext.install(_adapter)
	CoreContext.configure({"seed": 4242})

	assert_true(CoreInkEngine.load_story(STORY), "demo story should load")
	_bindings = CoreInkBindings.new(HOLDER, FENCE)
	_bindings.bind_all(CoreInkEngine)


func after_each() -> void:
	CoreInkEngine.unload()


## Advance to the choice list and return the choice texts.
func _run_to_choices() -> Array[String]:
	CoreInkEngine.continue_all()
	var texts: Array[String] = []
	for c in CoreInkEngine.choices():
		texts.append(str(c["text"]))
	return texts


func _choose_containing(fragment: String) -> bool:
	for c in CoreInkEngine.choices():
		if str(c["text"]).contains(fragment):
			return CoreInkEngine.choose(int(c["index"]))
	return false


# --- The three-way gate --------------------------------------------------------

func test_story_opens_and_offers_choices() -> void:
	var choices := _run_to_choices()
	assert_gt(choices.size(), 0, "the fence should offer something to say")


func test_wares_are_hidden_below_the_relationship_threshold() -> void:
	CoreAssets.give("zorkmid", 10, HOLDER)
	CoreKnowledge.learn("know_trapdoor", "seen", HOLDER)
	# Standing left at 0 ("neutral"), below "friendly".
	var choices := _run_to_choices()
	for text in choices:
		assert_false(text.contains("for sale"),
				"a merely neutral acquaintance must not be offered the wares")


func test_wares_appear_once_trusted() -> void:
	CoreStanding.set_score(FENCE, 40.0, HOLDER)
	var choices := _run_to_choices()
	var found := false
	for text in choices:
		if text.contains("for sale"):
			found = true
	assert_true(found, "at 'friendly' the wares should be on offer")


func test_purchase_requires_the_currency() -> void:
	CoreStanding.set_score(FENCE, 40.0, HOLDER)
	_run_to_choices()
	assert_true(_choose_containing("for sale"))
	_run_to_choices()
	# No zorkmids: the affordable branch must not be offered.
	for c in CoreInkEngine.choices():
		assert_false(str(c["text"]).contains("Buy the lantern"),
				"cannot be offered a purchase with an empty purse")


func test_successful_purchase_grants_asset_and_knowledge() -> void:
	CoreStanding.set_score(FENCE, 40.0, HOLDER)
	CoreAssets.give("zorkmid", 5, HOLDER)
	assert_false(CoreKnowledge.knows("know_grue", HOLDER), "precondition")

	_run_to_choices()
	assert_true(_choose_containing("for sale"))
	_run_to_choices()
	assert_true(_choose_containing("Buy the lantern"))
	CoreInkEngine.continue_all()

	assert_true(CoreAssets.has("brass_lantern", 1, HOLDER),
			"the physical asset should have changed hands")
	assert_eq(CoreAssets.amount("zorkmid", HOLDER), 2,
			"three zorkmids should have been spent")
	assert_true(CoreKnowledge.knows("know_grue", HOLDER),
			"the same beat should also have granted knowledge")


# --- Knowledge fidelity --------------------------------------------------------

func test_what_the_fence_says_is_only_a_rumour() -> void:
	_run_to_choices()
	assert_true(_choose_containing("house on the hill"))
	CoreInkEngine.continue_all()

	assert_true(CoreKnowledge.heard_of("rumor_rug_worthless", HOLDER),
			"the player has now heard the fence's version")
	assert_false(CoreKnowledge.knows("rumor_rug_worthless", HOLDER),
			"a shifty source at trust 0.4 yields a rumour, not a fact")


func test_confiding_real_knowledge_buys_standing() -> void:
	CoreKnowledge.learn("know_trapdoor", "seen it", HOLDER)
	var before := CoreStanding.score(FENCE, HOLDER)

	_run_to_choices()
	assert_true(_choose_containing("under the rug"))
	CoreInkEngine.continue_all()

	assert_gt(CoreStanding.score(FENCE, HOLDER), before,
			"telling him something true should improve standing")
	assert_true(CoreContext.has_flag("told_fence_about_trapdoor"),
			"the world should remember the confidence")


func test_confide_choice_absent_without_the_knowledge() -> void:
	var choices := _run_to_choices()
	for text in choices:
		assert_false(text.contains("under the rug"),
				"cannot volunteer a secret the player does not hold")


# --- Persistence ---------------------------------------------------------------

func test_save_and_restore_mid_conversation() -> void:
	CoreStanding.set_score(FENCE, 40.0, HOLDER)
	CoreAssets.give("zorkmid", 5, HOLDER)
	_run_to_choices()
	assert_true(_choose_containing("for sale"))
	var mid := _run_to_choices()

	var saved := CoreInkEngine.to_save_data()
	assert_ne(saved.get("state", ""), "", "ink state should be captured")

	CoreInkEngine.unload()
	CoreInkEngine.from_save_data(saved)
	_bindings.bind_all(CoreInkEngine)

	var restored: Array[String] = []
	for c in CoreInkEngine.choices():
		restored.append(str(c["text"]))
	assert_eq(restored, mid,
			"restoring mid-conversation should present the same choices")
