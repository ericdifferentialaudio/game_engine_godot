## The window contract, the registry, and the data-driven layout builder.
extends GutTest

const LAYOUT := {
	"id": "test",
	"variants": [
		{"id": "wide", "min_aspect": 1.4, "root": {
			"orientation": "horizontal", "ratio": 0.7, "children": [
				{"orientation": "vertical", "ratio": 0.4, "children": [
					{"role": "scene", "type": "graphics"},
					{"role": "dialogue", "type": "text", "min_size": [320, 200]},
				]},
				{"orientation": "vertical", "ratio": 0.5, "children": [
					{"role": "party", "type": "units"},
					{"role": "status", "type": "icon_text"},
				]},
			]}},
		{"id": "tall", "min_aspect": 0.0, "root": {
			"orientation": "vertical", "ratio": 0.5, "children": [
				{"role": "dialogue", "type": "text"},
				{"role": "status", "type": "icon_text"},
			]}},
	],
}

var _root: Control
var _builder: CoreLayoutBuilder


func before_each() -> void:
	CoreWindowRegistry.clear()
	_root = Control.new()
	add_child_autofree(_root)
	_builder = CoreLayoutBuilder.new(CoreLayoutDefinition.from_dict(LAYOUT))


func after_each() -> void:
	# Windows are freed immediately (not queued) so the tree is clean before
	# GUT counts orphans.
	if is_instance_valid(_root):
		_builder.teardown(_root)


# --- Layout selection ----------------------------------------------------------

func test_wide_viewport_selects_the_wide_variant() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	assert_eq(_builder.chosen_variant, "wide")


func test_tall_viewport_selects_the_tall_variant() -> void:
	_builder.build(_root, Vector2(800, 1200))
	assert_eq(_builder.chosen_variant, "tall")


func test_layout_declares_every_role_across_variants() -> void:
	var layout := CoreLayoutDefinition.from_dict(LAYOUT)
	var roles := layout.declared_roles()
	for expected in ["dialogue", "party", "scene", "status"]:
		assert_has(roles, expected)


# --- Building ------------------------------------------------------------------

func test_build_produces_a_split_container_tree() -> void:
	var root := _builder.build(_root, Vector2(1920, 1080))
	assert_true(root is HSplitContainer,
			"a horizontal root split should be an HSplitContainer, not a positioned Control")
	assert_eq(root.get_child_count(), 2, "a split holds exactly two sides")
	assert_true(root.get_child(0) is VSplitContainer, "the left side nests a vertical split")


func test_build_registers_every_window() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	for role in ["scene", "dialogue", "party", "status"]:
		assert_true(CoreWindowRegistry.has_window(role),
				"role '%s' should be registered at scene-ready time" % role)


func test_windows_honour_their_minimum_size() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	var dialogue := CoreWindowRegistry.window_for("dialogue")
	assert_eq(dialogue.custom_minimum_size, Vector2(320, 200))


func test_three_children_nest_without_extra_syntax() -> void:
	var spec := {"id": "t", "variants": [{"id": "d", "min_aspect": 0.0, "root": {
		"orientation": "vertical", "ratio": 0.33, "children": [
			{"role": "a", "type": "text"},
			{"role": "b", "type": "text"},
			{"role": "c", "type": "text"},
		]}}]}
	var builder := CoreLayoutBuilder.new(CoreLayoutDefinition.from_dict(spec))
	builder.build(_root, Vector2(1000, 1000))
	assert_eq(builder.roles(), ["a", "b", "c"] as Array[String])


# --- Registry ------------------------------------------------------------------

func test_lookup_of_a_missing_role_fails_gracefully() -> void:
	_builder.build(_root, Vector2(800, 1200))   # tall variant: no map, no party
	assert_null(CoreWindowRegistry.window_for("map"),
			"a game without a map window must return null, not error")
	assert_false(CoreWindowRegistry.append_line("map", "ignored"),
			"pushing to an absent window is a no-op, not a crash")


func test_typed_lookup_rejects_the_wrong_window_type() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	assert_null(CoreWindowRegistry.get_text_window("party"),
			"a units window must not be returned as a text window")
	assert_not_null(CoreWindowRegistry.get_text_window("dialogue"))


func test_unregister_on_exit() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	assert_true(CoreWindowRegistry.has_window("dialogue"))
	var window := CoreWindowRegistry.window_for("dialogue")
	window.get_parent().remove_child(window)
	window.free()
	assert_false(CoreWindowRegistry.has_window("dialogue"))


# --- Window behaviour ----------------------------------------------------------

func test_text_window_accumulates_lines_and_replaces_choices() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	var w := CoreWindowRegistry.get_text_window("dialogue")

	w.append_line("The fence looks up.")
	w.append_line("   ")                    # blank: should be ignored
	w.append_line("\"Don't know you.\"")
	assert_eq(w.lines().size(), 2)
	assert_eq(w.last_line(), "\"Don't know you.\"")

	w.set_choices([{"index": 0, "text": "Ask about the house."},
			{"index": 1, "text": "Leave."}])
	assert_eq(w.choice_count(), 2)
	w.set_choices([{"index": 0, "text": "Only one now."}])
	assert_eq(w.choice_count(), 1, "choices are replaced wholesale, not appended")


func test_text_window_reports_choices_through_the_registry() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	var w := CoreWindowRegistry.get_text_window("dialogue")
	watch_signals(CoreWindowRegistry)

	w.set_choices([{"index": 7, "text": "Buy the lantern."}])
	assert_true(w.press_choice(0))
	# The report is deferred so the button can be freed safely by the handler.
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(
			CoreWindowRegistry, "choice_selected", ["dialogue", 7, "Buy the lantern."])


func test_icon_text_window_updates_entries_in_place() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	var w := CoreWindowRegistry.get_icon_text_window("status")

	w.set_entry("zorkmid", "$", "Zorkmids: 5")
	w.set_entry("zorkmid", "$", "Zorkmids: 2")
	assert_eq(w.entry_count(), 1, "same id updates rather than duplicating")
	assert_eq(w.entry_text("zorkmid"), "Zorkmids: 2")

	w.set_entry("lantern", "*", "Brass lantern")
	assert_eq(w.entry_count(), 2)
	assert_true(w.remove_entry("lantern"))
	assert_false(w.has_entry("lantern"))


func test_unit_window_sets_and_updates_units() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	var w := CoreWindowRegistry.get_unit_window("party")

	w.set_units([{"id": "player", "name": "You",
			"stats": {"health": {"value": 60, "max": 60}}}])
	assert_eq(w.unit_count(), 1)
	assert_true(w.update_unit("player", {"status": "wounded"}))
	assert_eq(str(w.units()[0]["status"]), "wounded")
	assert_false(w.update_unit("nobody", {}), "updating an absent unit reports false")


func test_map_window_markers() -> void:
	var spec := {"id": "m", "variants": [{"id": "d", "min_aspect": 0.0,
		"root": {"orientation": "vertical", "children": [
			{"role": "map", "type": "map"}, {"role": "x", "type": "text"}]}}]}
	var builder := CoreLayoutBuilder.new(CoreLayoutDefinition.from_dict(spec))
	builder.build(_root, Vector2(1000, 800))
	var w := CoreWindowRegistry.window_for("map") as CoreMapWindow

	w.set_marker("white_house", Vector2(0.25, 0.4), "H")
	assert_true(w.has_marker("white_house"))
	assert_eq(w.marker_position("white_house"), Vector2(0.25, 0.4))

	watch_signals(CoreWindowRegistry)
	assert_true(w.activate_marker("white_house"))
	assert_signal_emitted_with_parameters(
			CoreWindowRegistry, "marker_activated", ["map", "white_house"])


func test_clear_all_empties_every_window() -> void:
	_builder.build(_root, Vector2(1920, 1080))
	CoreWindowRegistry.get_text_window("dialogue").append_line("something")
	CoreWindowRegistry.get_icon_text_window("status").set_entry("a", "-", "b")

	CoreWindowRegistry.clear_all()

	assert_eq(CoreWindowRegistry.get_text_window("dialogue").lines().size(), 0)
	assert_eq(CoreWindowRegistry.get_icon_text_window("status").entry_count(), 0)


func test_sample_game_layout_file_is_valid() -> void:
	var layout := CoreLayoutDefinition.load_file("res://ink/sample_layout.json")
	assert_not_null(layout, "the shipped sample layout should parse")
	assert_eq(layout.id, "sample")
	assert_has(layout.variant_ids(), "wide")
	assert_has(layout.declared_roles(), "dialogue")
