## Slack Tide's screen actually builds, and every role the game pushes content
## to exists in the layout.
##
## This is the test that would have caught `layout.json` being inert data: it
## was authored, documented and shipped for weeks without anything ever calling
## CoreLayoutBuilder on it.
extends GutTest

const LAYOUT := "res://games/slack_tide/layout.json"
const UI_SCRIPT := "res://games/slack_tide/slack_tide_ui.gd"

var _root: Control
var _builder: CoreLayoutBuilder


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1600, 900)
	add_child_autofree(_root)


func after_each() -> void:
	if _builder != null:
		_builder.teardown(_root)
		_builder = null
	CoreWindowRegistry.clear()


func _build(size: Vector2) -> void:
	var def := CoreLayoutDefinition.load_file(LAYOUT)
	assert_not_null(def, "layout.json should load")
	_builder = CoreLayoutBuilder.new(def)
	_builder.build(_root, size)


func test_layout_file_loads() -> void:
	var def := CoreLayoutDefinition.load_file(LAYOUT)
	assert_not_null(def, "slack_tide layout.json must parse")
	assert_eq(def.id, "slack_tide")
	assert_gt(def.variants.size(), 1, "needs wide and tall variants")


func test_wide_variant_builds_all_five_windows() -> void:
	_build(Vector2(1600, 900))
	assert_eq(_builder.chosen_variant, "wide",
		"a 16:9 viewport should pick the wide variant")
	for role in ["scene", "narration", "journal", "map", "status"]:
		assert_true(_builder.windows.has(role),
			"wide layout must provide the '%s' window" % role)


func test_tall_variant_drops_the_map_gracefully() -> void:
	# The contract: a role a variant omits returns null, and callers do
	# nothing rather than crash. This is what lets one game support a phone
	# aspect and an ultrawide without a single conditional in game code.
	_build(Vector2(600, 1000))
	assert_eq(_builder.chosen_variant, "tall")
	assert_false(_builder.windows.has("map"),
		"the tall variant deliberately drops the map")
	assert_null(CoreWindowRegistry.get_map_window("map"),
		"an absent role must return null, not error")


func test_narration_is_a_text_window_with_choices() -> void:
	_build(Vector2(1600, 900))
	var w := CoreWindowRegistry.get_text_window("narration")
	assert_not_null(w, "narration must be a CoreTextWindow")
	w.append_line("The tide has been out for eleven hours.")
	w.set_choices(["Ask Hesper", "Say nothing"])
	assert_eq(w.choice_count(), 2)
	assert_string_contains(w.last_line(), "eleven hours")


func test_choice_click_reports_through_the_registry() -> void:
	_build(Vector2(1600, 900))
	var w := CoreWindowRegistry.get_text_window("narration")
	watch_signals(CoreWindowRegistry)
	w.set_choices(["Call it", "Bluff", "Let it go"])
	assert_true(w.press_choice(1), "pressing a choice should succeed")
	# Reporting is deferred so the pressed signal can finish unwinding.
	await get_tree().process_frame
	assert_signal_emitted(CoreWindowRegistry, "choice_selected")


func test_status_entries_update_in_place() -> void:
	_build(Vector2(1600, 900))
	var w := CoreWindowRegistry.get_icon_text_window("status")
	assert_not_null(w)
	w.set_entry("purse", "o", "Tallies: 3")
	w.set_entry("purse", "o", "Tallies: 9")
	assert_eq(w.entry_count(), 1, "same id must update, not accumulate")
	assert_string_contains(w.entry_text("purse"), "9")


func test_map_markers_are_the_hotspot_mechanism() -> void:
	_build(Vector2(1600, 900))
	var w := CoreWindowRegistry.get_map_window("map")
	assert_not_null(w)
	w.set_marker("salt_steps", Vector2(0.3, 0.6), "*")
	assert_true(w.has_marker("salt_steps"))
	watch_signals(CoreWindowRegistry)
	assert_true(w.activate_marker("salt_steps"))
	assert_signal_emitted(CoreWindowRegistry, "marker_activated")


func test_ui_script_parses() -> void:
	# A GDScript with a syntax error or a call to a non-existent core method
	# still "exists" on disk; loading it is what proves it compiles.
	var script: GDScript = load(UI_SCRIPT)
	assert_not_null(script, "slack_tide_ui.gd must load")
	assert_true(script.can_instantiate(), "slack_tide_ui.gd must compile")
