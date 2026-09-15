## Long-form narrative window: scrollable prose plus a choice list.
##
## This is where Ink renders. Text accumulates (a conversation log the player
## can scroll back through); choices are replaced wholesale each time the story
## stops for input.
##
## Specialised API:
##   append_line(text) / append_lines(lines) / set_choices(list) / clear_choices()
##
## Player action leaves via `CoreWindowRegistry.choice_selected`, not a direct
## call back into the story — the window does not know what a story is.
class_name CoreTextWindow
extends CoreWindow

## How many lines to keep before trimming the oldest. 0 = unlimited.
@export var max_lines: int = 500

var _scroll: ScrollContainer
var _log: VBoxContainer
var _choices: VBoxContainer
var _lines: Array[String] = []


func _build() -> void:
	if minimum_window_size == Vector2i(120, 80):
		minimum_window_size = Vector2i(280, 160)
		custom_minimum_size = Vector2(minimum_window_size)

	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_log)

	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_choices)


# --- Narrative ----------------------------------------------------------------

## Add one line of prose. Blank lines are ignored so Ink's paragraph breaks do
## not pile up as empty rows.
func append_line(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return
	_lines.append(trimmed)

	var label := Label.new()
	label.text = trimmed
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _log != null:
		_log.add_child(label)

	_trim()
	_scroll_to_bottom()


func append_lines(lines: Array) -> void:
	for line in lines:
		append_line(str(line))


## Everything currently in the log, oldest first. Lets tests and save code read
## the window without walking the node tree.
func lines() -> Array[String]:
	return _lines.duplicate()


func last_line() -> String:
	return _lines[-1] if not _lines.is_empty() else ""


# --- Choices ------------------------------------------------------------------

## Replace the choice list. [param choices] accepts the Dictionaries that
## `CoreInkEngine.choices()` produces, or plain strings.
func set_choices(choices: Array) -> void:
	clear_choices()
	if _choices == null:
		return
	var index := 0
	for choice in choices:
		var text := str(choice["text"]) if choice is Dictionary else str(choice)
		var idx := int(choice["index"]) if choice is Dictionary and choice.has("index") else index
		var button := Button.new()
		button.text = text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_choice_pressed.bind(idx, text))
		_choices.add_child(button)
		index += 1


func clear_choices() -> void:
	if _choices == null:
		return
	# free(), not queue_free(): choices are replaced many times per
	# conversation, and deferred frees would leave stale buttons parented for
	# the rest of the frame.
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.free()


func choice_count() -> int:
	return _choices.get_child_count() if _choices != null else 0


## Programmatically take a choice. Exists so tests and automated playthroughs
## drive the real UI path rather than a parallel one.
func press_choice(index: int) -> bool:
	if _choices == null or index < 0 or index >= _choices.get_child_count():
		return false
	var button := _choices.get_child(index) as Button
	if button == null:
		return false
	button.emit_signal("pressed")
	return true


# --- Contract -----------------------------------------------------------------

func clear() -> void:
	_lines.clear()
	if _log != null:
		for child in _log.get_children():
			_log.remove_child(child)
			child.free()
	clear_choices()


func describe() -> String:
	return "%s: %d lines, %d choices" % [role, _lines.size(), choice_count()]


## Reporting is deferred: a listener will almost always respond by calling
## [method set_choices], which frees these buttons — including the one whose
## `pressed` signal is still being dispatched. Deferring lets the signal finish
## unwinding first.
func _on_choice_pressed(index: int, text: String) -> void:
	CoreWindowRegistry.report_choice.call_deferred(role, index, text)


func _trim() -> void:
	if max_lines <= 0:
		return
	while _lines.size() > max_lines:
		_lines.remove_at(0)
		if _log != null and _log.get_child_count() > 0:
			var oldest := _log.get_child(0)
			_log.remove_child(oldest)
			oldest.free()


func _scroll_to_bottom() -> void:
	if _scroll == null or not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
