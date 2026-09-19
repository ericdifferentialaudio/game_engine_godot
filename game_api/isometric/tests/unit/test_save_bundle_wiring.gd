extends GutTest
## SaveManager must persist core state through CoreSaveBundle, so that adding a
## core system needs no edit to either engine's SaveManager. Also covers the
## v1 -> v2 migration of saves written before the "core" section existed.
##
## The mid-conversation Ink case is covered in the fps layer's twin of this
## file: this project has no compiled `.ink.json` of its own (only `core/` does;
## `sync_core.ps1` brings across `ink/patterns`, which is uncompiled source).
## See "Next planned" item 2 in activeContext.md.

const HOLDER := "player"


func before_each() -> void:
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()


func after_each() -> void:
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()


# --- The bundle is actually written and read ---------------------------------

func test_save_data_carries_a_core_section() -> void:
	var data := SaveManager.build_save_data()
	assert_true(data.has("core"), "SaveManager must embed CoreSaveBundle output")
	assert_eq(CoreSaveBundle.version_of(data["core"]), CoreSaveBundle.VERSION)
	assert_true(data["core"].has("context"), "every core system travels in the bundle")


func test_core_state_round_trips_through_build_save_data() -> void:
	CoreStanding.set_score("barkeep", 27.0, HOLDER)
	CoreContext.set_flag("heard_the_rumour")

	# Serialise for real: the bundle has to survive JSON, not just a dict copy.
	var json := JSON.stringify(SaveManager.build_save_data())
	var parsed: Dictionary = JSON.parse_string(json)

	CoreStanding.reset()
	CoreContext.reset()
	assert_eq(CoreStanding.score("barkeep", HOLDER), 0.0, "precondition: wiped")

	CoreSaveBundle.apply(parsed.get("core", {}))

	assert_eq(CoreStanding.score("barkeep", HOLDER), 27.0, "standing restored")
	assert_true(CoreContext.has_flag("heard_the_rumour"), "core flags restored")


func test_the_shared_rng_position_survives_the_bundle() -> void:
	CoreContext.configure({"seed": 7})
	CoreContext.rng().randf()
	CoreContext.rng().randf()
	var bundle := CoreSaveBundle.collect()
	var next_expected := CoreContext.rng().randf()

	CoreContext.configure({"seed": 7})   # rewind to the very start of the stream
	CoreSaveBundle.apply(bundle)

	assert_almost_eq(CoreContext.rng().randf(), next_expected, 0.0000001,
			"a reloaded game must continue the RNG stream, not restart it")


# --- Migration: a v1 save predates the bundle entirely ------------------------

func test_v1_save_without_a_core_section_still_loads() -> void:
	var legacy := {
		"version": 1,
		"game_id": GameManager.game_id,
		"flags": {"legacy_flag": true},
	}
	var migrated := SaveManager._migrate(legacy)

	assert_eq(int(migrated["version"]), SaveManager.SAVE_VERSION, "version bumped")
	assert_true(migrated.has("core"), "a core section is synthesised")
	assert_true(bool(migrated["core"]["context"]["flags"].get("legacy_flag", false)),
			"old engine-side flags are carried into CoreContext")


func test_migrated_v1_save_leaves_systems_it_never_knew_about_alone() -> void:
	CoreStanding.set_score("barkeep", 15.0, HOLDER)
	var migrated := SaveManager._migrate({"version": 1, "flags": {}})
	CoreSaveBundle.apply(migrated["core"])
	assert_eq(CoreStanding.score("barkeep", HOLDER), 15.0,
			"no standing section in a v1 save must not wipe live standing")
