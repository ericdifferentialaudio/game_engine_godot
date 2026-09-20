extends GutTest
## SaveManager must persist core state through CoreSaveBundle, so that adding a
## core system needs no edit to either engine's SaveManager. Also covers the
## v2 -> v3 migration of saves written before the "core" section existed.
## See "Next planned" item 2 in activeContext.md.

## The package under test is deliberately the engine's own example_realm, not
## a real game: this covers SaveManager/CoreSaveBundle wiring, so it should not
## break when a game package is renamed or retired (as zork was).
const HOLDER := "player"
const PACKAGE := "example_realm"
const CURRENCY := "gold"
const STORY := "res://games/example_realm/ink/round_room_fence.ink.json"


func before_all() -> void:
	if CoreContext.adapter == null or CoreContext.adapter.engine_id != "fps":
		CoreContext.install(FpsEngineAdapter.new())
	assert_true(GameManager.load_game(PACKAGE), "%s package loads" % PACKAGE)


func before_each() -> void:
	GameManager.start_new_game_headless()
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()


func after_each() -> void:
	CoreInkEngine.unload()
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()


func after_all() -> void:
	# Do not leave test slots behind in user://saves/ for the next run to list.
	for slot in ["test_bundle", "test_bundle_ink", "test_bundle_probe"]:
		DirAccess.remove_absolute("user://saves/%s.json" % slot)


# --- The bundle is actually written and read ---------------------------------

func test_save_data_carries_a_core_section() -> void:
	CoreAssets.give(CURRENCY, 4, HOLDER)
	var data := _save_dict()
	assert_true(data.has("core"), "SaveManager must embed CoreSaveBundle output")
	assert_eq(CoreSaveBundle.version_of(data["core"]), CoreSaveBundle.VERSION)
	assert_true(data["core"].has("assets"), "every core system travels in the bundle")


func test_core_state_round_trips_through_a_real_save_file() -> void:
	CoreAssets.give(CURRENCY, 9, HOLDER)
	CoreStanding.set_score("fence", 42.0, HOLDER)
	CoreContext.set_flag("met_the_fence")

	assert_true(SaveManager.save_game("test_bundle"), "save written")

	# Wipe everything, as a fresh boot would.
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()
	assert_eq(CoreAssets.amount(CURRENCY, HOLDER), 0, "precondition: wiped")

	assert_true(SaveManager.load_game("test_bundle"), "save loaded")

	assert_eq(CoreAssets.amount(CURRENCY, HOLDER), 9, "assets restored")
	assert_eq(CoreStanding.score("fence", HOLDER), 42.0, "standing restored")
	assert_true(CoreContext.has_flag("met_the_fence"), "core flags restored")


func test_saving_mid_conversation_restores_the_same_knot() -> void:
	assert_true(CoreInkEngine.load_story(STORY), "the fence story loads")
	CoreInkBindings.new(HOLDER, "fence", "round_room").bind_all(CoreInkEngine)
	CoreInkEngine.continue_all()
	var path_before := CoreInkEngine.current_path()

	assert_true(SaveManager.save_game("test_bundle_ink"), "save written mid-conversation")

	CoreInkEngine.unload()
	assert_false(CoreInkEngine.is_loaded(), "precondition: story unloaded")

	assert_true(SaveManager.load_game("test_bundle_ink"), "save loaded")

	assert_true(CoreInkEngine.is_loaded(), "the story itself came back")
	assert_eq(CoreInkEngine.story_path, STORY, "the same story, not a fresh one")
	assert_eq(CoreInkEngine.current_path(), path_before,
			"the conversation resumed at the knot it was saved in")


# --- Migration: a v2 save predates the bundle entirely ------------------------

func test_v2_save_without_a_core_section_still_loads() -> void:
	var legacy := {
		"version": 2,
		"game_id": GameManager.game_id,
		"flags": {"legacy_flag": true},
		"clock": {},
		"maps": {},
		"intel": {},
		"player": {},
	}
	var migrated := SaveManager._migrate(legacy)

	assert_eq(int(migrated["version"]), SaveManager.SAVE_VERSION, "version bumped")
	assert_true(migrated.has("core"), "a core section is synthesised")
	assert_true(bool(migrated["core"]["context"]["flags"].get("legacy_flag", false)),
			"old engine-side flags are carried into CoreContext")


func test_migrated_v2_save_leaves_systems_it_never_knew_about_alone() -> void:
	CoreAssets.give(CURRENCY, 5, HOLDER)
	var migrated := SaveManager._migrate({"version": 2, "flags": {}})
	CoreSaveBundle.apply(migrated["core"])
	assert_eq(CoreAssets.amount(CURRENCY, HOLDER), 5,
			"no assets section in a v2 save must not wipe live assets")


func test_a_v3_save_is_not_re_migrated() -> void:
	CoreAssets.give(CURRENCY, 2, HOLDER)
	var data := _save_dict()
	assert_eq(int(data["version"]), SaveManager.SAVE_VERSION,
			"a fresh save is already current, so _migrate is never reached")


func _save_dict() -> Dictionary:
	assert_true(SaveManager.save_game("test_bundle_probe"), "save written")
	var text := FileAccess.get_file_as_string("user://saves/test_bundle_probe.json")
	var parsed = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "the save file is valid JSON")
	return parsed if parsed is Dictionary else {}
