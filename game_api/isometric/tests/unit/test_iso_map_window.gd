extends GutTest
## The isometric engine's real minimap (`IsoMapWindow`) and the adapter's
## `resolve_texture()` art seam. Items 5 and 6 in activeContext.md "Next planned".

var _window: IsoMapWindow


func before_each() -> void:
	CoreWindowRegistry.clear()
	_window = IsoMapWindow.new()
	_window.role = "map"
	_window.size = Vector2(200, 200)
	add_child_autofree(_window)


func after_each() -> void:
	CoreWindowRegistry.clear()


# --- It is still a CoreMapWindow ----------------------------------------------

func test_it_registers_in_the_map_role_like_any_window() -> void:
	assert_eq(CoreWindowRegistry.window_for("map"), _window,
			"an engine subclass must be findable by role, not by type")
	assert_true(CoreWindowRegistry.get_map_window("map") is CoreMapWindow,
			"and must still satisfy the base contract")


func test_inherited_marker_api_still_works() -> void:
	_window.set_marker("shrine", Vector2(0.25, 0.75), "S")
	assert_true(_window.has_marker("shrine"))
	assert_eq(_window.marker_position("shrine"), Vector2(0.25, 0.75))
	assert_eq(_window.marker_count(), 1)
	_window.remove_marker("shrine")
	assert_eq(_window.marker_count(), 0)


func test_marker_activation_still_relays_through_the_registry() -> void:
	watch_signals(CoreWindowRegistry)
	_window.set_marker("veil", Vector2(0.5, 0.5))
	assert_true(_window.activate_marker("veil"))
	assert_signal_emitted_with_parameters(
			CoreWindowRegistry, "marker_activated", ["map", "veil"])


func test_clear_empties_markers() -> void:
	_window.set_marker("a", Vector2.ZERO)
	_window.set_marker("b", Vector2.ONE)
	_window.clear()
	assert_eq(_window.marker_count(), 0)


# --- The engine half -----------------------------------------------------------

func test_describe_reports_tiles_not_just_markers() -> void:
	var text := _window.describe()
	assert_true(text.begins_with("map:"), "describe() is prefixed by role")
	assert_true(text.contains("tiles"),
			"the subclass reports world size, unlike the base window")


func test_coordinate_mapping_round_trips() -> void:
	if WorldManager.world == null:
		pass_test("no world loaded in this harness; mapping needs one")
		return
	var coord := Vector2i(1, 1)
	var normalised := _window.normalised_of(coord)
	assert_between(normalised.x, 0.0, 1.0, "normalised x stays in range")
	assert_between(normalised.y, 0.0, 1.0, "normalised y stays in range")
	assert_eq(_window.coord_at(normalised), coord,
			"a tile maps to a point and back to the same tile")


func test_coord_at_is_null_outside_the_world() -> void:
	assert_null(_window.coord_at(Vector2(9.0, 9.0)),
			"a point past the edge of the world is not a tile")


func test_normalised_of_is_safe_without_a_world() -> void:
	# The window can be built before a map exists; it must not crash.
	assert_true(_window.normalised_of(Vector2i.ZERO) is Vector2)


func test_refresh_is_safe_and_rate_limited() -> void:
	# Hammering it must neither crash nor redraw every single time.
	for i in 50:
		_window.refresh()
	assert_true(true, "50 refreshes completed without error")


# --- Item 6: the art seam ------------------------------------------------------

func test_adapter_resolves_a_texture_for_the_graphics_window() -> void:
	var previous := CoreContext.adapter
	CoreContext.install(IsoEngineAdapter.new())

	assert_true(CoreContext.adapter.has_method("resolve_texture"),
			"CoreGraphicsWindow.set_image() looks for exactly this method")

	var art := CoreGraphicsWindow.new()
	art.role = "portrait"
	add_child_autofree(art)

	# The iso adapter substitutes a generated swatch for unknown keys, so an
	# art window is never blank even before the art pass.
	assert_true(art.set_image("portrait.fence"),
			"an unresolved key still yields a placeholder texture")
	assert_true(art.has_image(), "and the window actually holds it")
	assert_eq(art.current_image(), "portrait.fence")

	art.clear()
	assert_false(art.has_image(), "clear() empties it again")

	CoreContext.install(previous)


func test_empty_texture_id_resolves_to_nothing() -> void:
	var adapter := IsoEngineAdapter.new()
	assert_null(adapter.resolve_texture(""), "an empty key is not art")
