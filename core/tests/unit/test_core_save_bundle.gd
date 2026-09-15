## The aggregate save bundle: every core system round-trips through one dict.
extends GutTest

const HOLDER := "player"

const INTEL := [
	{"id": "know_grue", "title": "grue", "reliability": 1.0, "secrecy": 0.0},
]
const ITEMS := [
	{"id": "zorkmid", "display_name": "Zorkmid", "category": "currency", "value": 1},
	{"id": "brass_lantern", "display_name": "Brass Lantern", "category": "misc"},
]


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
	CoreContext.rules = {}
	CoreContext.install(CoreEngineAdapter.new())
	CoreContext.configure({"seed": 11})


func after_each() -> void:
	CoreInkEngine.unload()


func test_bundle_round_trips_every_system() -> void:
	CoreAssets.give("zorkmid", 7, HOLDER)
	CoreAssets.give("brass_lantern", 1, HOLDER)
	CoreKnowledge.learn("know_grue", "the fence", HOLDER)
	CoreStanding.set_score("fence", 35.0, HOLDER)
	CoreContext.set_flag("met_the_fence")

	var bundle := CoreSaveBundle.collect()
	assert_eq(CoreSaveBundle.version_of(bundle), CoreSaveBundle.VERSION)

	# Wipe everything, as a fresh boot would.
	CoreIntel.reset()
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()
	assert_false(CoreAssets.has("zorkmid", 1, HOLDER), "precondition: wiped")

	CoreSaveBundle.apply(bundle)

	assert_eq(CoreAssets.amount("zorkmid", HOLDER), 7)
	assert_true(CoreAssets.has("brass_lantern", 1, HOLDER))
	assert_true(CoreKnowledge.knows("know_grue", HOLDER))
	assert_eq(CoreStanding.score("fence", HOLDER), 35.0)
	assert_true(CoreContext.has_flag("met_the_fence"))


func test_bundle_includes_ink_state_mid_conversation() -> void:
	assert_true(CoreInkEngine.load_story("res://ink/round_room_fence.ink.json"))
	CoreInkBindings.new(HOLDER, "fence").bind_all(CoreInkEngine)
	CoreInkEngine.continue_all()

	var bundle := CoreSaveBundle.collect()
	assert_true(bundle.has("ink"), "ink state should travel in the bundle")
	assert_ne(str(bundle["ink"].get("state", "")), "",
			"a conversation in progress should have recorded state")


func test_missing_sections_are_skipped() -> void:
	CoreAssets.give("zorkmid", 3, HOLDER)
	# A save written before a system existed simply has no section for it.
	CoreSaveBundle.apply({"version": 1})
	assert_eq(CoreAssets.amount("zorkmid", HOLDER), 3,
			"an absent section must leave the live system untouched")


func test_empty_bundle_is_harmless() -> void:
	CoreSaveBundle.apply({})
	assert_eq(CoreSaveBundle.version_of({}), 0, "a pre-bundle save reports version 0")
