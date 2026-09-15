## Turns a `CoreLayoutDefinition` into a live tree of split containers.
##
## The whole screen is nested `HSplitContainer`/`VSplitContainer` nodes with a
## `CoreWindow` at each leaf. That gives draggable dividers between adjacent
## regions for free, with correct minimum-size propagation — none of which is
## true of manually positioned Controls.
##
## Window positions are fixed by the layout; only the split offsets move, and
## those are the player's, persisted to user preferences (not the save file:
## they depend on the player's screen, not the game state).
class_name CoreLayoutBuilder
extends RefCounted

## Where the player's chosen split ratios live. Deliberately **user prefs**,
## not save data: a layout tuned for a 4K monitor should apply to every save,
## and a save copied to another machine should not fight that machine's screen.
const PREFS_PATH := "user://ui_layout.cfg"

var layout: CoreLayoutDefinition
## Windows built by the last [method build], role -> CoreWindow.
var windows: Dictionary = {}
## The variant id actually chosen, for logging and tests.
var chosen_variant: String = ""

var _splits: Array = []           ## [{"path": String, "node": SplitContainer}]
var _prefs_key: String = ""


func _init(p_layout: CoreLayoutDefinition = null) -> void:
	layout = p_layout


## Build the screen into [param parent], choosing the variant that suits
## [param viewport_size]. Returns the root container.
func build(parent: Control, viewport_size: Vector2) -> Control:
	windows.clear()
	_splits.clear()

	if layout == null:
		push_error("CoreLayoutBuilder: no layout definition")
		return null

	var variant := layout.variant_for(viewport_size)
	chosen_variant = str(variant.get("id", ""))
	# Ratios are remembered per (layout, variant, resolution): the same player
	# windowing the game differently should not clobber their fullscreen setup.
	_prefs_key = "%s.%s.%dx%d" % [layout.id, chosen_variant,
			int(viewport_size.x), int(viewport_size.y)]

	var root_spec: Dictionary = variant.get("root", {})
	if root_spec.is_empty():
		push_error("CoreLayoutBuilder: layout '%s' has no root" % layout.id)
		return null

	var root := _build_node(root_spec, "root")
	if root != null:
		root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent.add_child(root)
	return root


## Tear down the built tree. Call before rebuilding a layout, and from tests,
## so windows deregister and no Controls are left orphaned.
func teardown(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.free()
	windows.clear()
	_splits.clear()


## Every role this build actually produced.
func roles() -> Array[String]:
	var out: Array[String] = []
	for role in windows:
		out.append(str(role))
	out.sort()
	return out


# --- Split ratio persistence ---------------------------------------------------

## Save the player's current divider positions.
func save_ratios() -> void:
	if _splits.is_empty():
		return
	var config := ConfigFile.new()
	config.load(PREFS_PATH)      # Keep other resolutions' entries intact.
	for entry in _splits:
		var node: SplitContainer = entry["node"]
		if is_instance_valid(node):
			config.set_value(_prefs_key, str(entry["path"]), node.split_offset)
	config.save(PREFS_PATH)


## Restore previously saved divider positions. Silently does nothing the first
## time a player runs the game, leaving the layout's authored defaults.
func load_ratios() -> void:
	var config := ConfigFile.new()
	if config.load(PREFS_PATH) != OK or not config.has_section(_prefs_key):
		return
	for entry in _splits:
		var node: SplitContainer = entry["node"]
		var path := str(entry["path"])
		if is_instance_valid(node) and config.has_section_key(_prefs_key, path):
			node.split_offset = int(config.get_value(_prefs_key, path))


## Forget saved ratios and return to the authored defaults.
func reset_ratios() -> void:
	var config := ConfigFile.new()
	config.load(PREFS_PATH)
	if config.has_section(_prefs_key):
		config.erase_section(_prefs_key)
		config.save(PREFS_PATH)


# --- Internals -----------------------------------------------------------------

func _build_node(spec: Dictionary, path: String) -> Control:
	# A leaf carries a role: build the window itself.
	if spec.has("role"):
		return _build_window(spec)

	var children: Array = spec.get("children", [])
	if children.is_empty():
		return null
	# A split with one child is just that child — lets a variant drop a window
	# without restructuring the whole tree.
	if children.size() == 1:
		return _build_node(children[0], path + ".0")

	var vertical := str(spec.get("orientation", "horizontal")) == "vertical"
	var split: SplitContainer = VSplitContainer.new() if vertical else HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var first := _build_node(children[0], path + ".0")
	if first != null:
		split.add_child(first)

	# More than two children nest as right-leaning splits of the same
	# orientation, so a three-row column is expressible without extra syntax.
	var rest_spec := spec.duplicate(true)
	rest_spec["children"] = children.slice(1)
	var rest := _build_node(rest_spec, path + ".1")
	if rest != null:
		split.add_child(rest)

	_apply_ratio(split, spec, vertical)
	_splits.append({"path": path, "node": split})
	return split


## Ratio is authored as a fraction of the parent (0..1), converted to a pixel
## offset once the container knows its real size — which is why this waits for
## a resize rather than setting an offset immediately.
func _apply_ratio(split: SplitContainer, spec: Dictionary, vertical: bool) -> void:
	var ratio := clampf(float(spec.get("ratio", 0.5)), 0.05, 0.95)
	split.resized.connect(func():
		if split.split_offset != 0:
			return    # The player (or restored prefs) already moved it.
		var extent := split.size.y if vertical else split.size.x
		if extent > 0.0:
			split.split_offset = int(extent * ratio)
	)


func _build_window(spec: Dictionary) -> Control:
	var type_name := str(spec.get("type", "text"))
	var script := CoreLayoutDefinition.script_for_type(type_name)
	if script == null:
		push_error("CoreLayoutBuilder: unknown window type '%s'" % type_name)
		return null

	var window: CoreWindow = script.new()
	window.role = str(spec.get("role", ""))
	window.title = str(spec.get("title", window.role))

	var min_size = spec.get("min_size", null)
	if min_size is Array and min_size.size() >= 2:
		window.minimum_window_size = Vector2i(int(min_size[0]), int(min_size[1]))

	# Per-type options, applied only when the layout bothers to specify them.
	for key in ["max_lines", "max_entries", "newest_first", "primary_stat", "keep_aspect"]:
		if spec.has(key) and key in window:
			window.set(key, spec[key])

	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if window.role != "":
		windows[window.role] = window
	return window
