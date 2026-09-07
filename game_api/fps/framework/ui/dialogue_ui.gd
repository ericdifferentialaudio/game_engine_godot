## Terminal-style conversation panel. Lives in group "dialogue_ui" so
## DialogueInteraction finds it. Builds its own controls so a game only needs
## to instance the node.
##
## Keys 1-9 pick a choice, Enter/E continues a choice-less node, Esc leaves.
class_name DialogueUi
extends CanvasLayer

const FONT_COLOR := Color(0.75, 1.0, 0.75)
const DIM_COLOR := Color(0.45, 0.65, 0.45)

var dialogue: DialogueInteraction = null

var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label


func _ready() -> void:
	add_to_group("dialogue_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	_panel.visible = false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 120
	_panel.offset_right = -120
	_panel.offset_top = -420
	_panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.03, 0.0, 0.94)
	style.border_color = DIM_COLOR
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", DIM_COLOR)
	box.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("default_color", FONT_COLOR)
	box.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	box.add_child(_choices)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", DIM_COLOR)
	_hint.text = "[1-9] choose   [Enter] continue   [Esc] leave"
	box.add_child(_hint)


func open(d: DialogueInteraction) -> void:
	dialogue = d
	GameManager.set_dialogue_open(true)
	_panel.visible = true
	_refresh()


func close() -> void:
	if dialogue:
		dialogue.finish()
	dialogue = null
	_panel.visible = false
	GameManager.set_dialogue_open(false)


func _refresh() -> void:
	if dialogue == null or dialogue.is_finished():
		close()
		return
	_speaker.text = dialogue.speaker().to_upper()
	_text.text = dialogue.current_text()
	for c in _choices.get_children():
		c.queue_free()
	var choices := dialogue.available_choices()
	for i in choices.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, choices[i].get("text", "...")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_color_override("font_color", FONT_COLOR)
		b.pressed.connect(_pick.bind(i))
		_choices.add_child(b)
	_hint.text = "[1-9] choose   [Esc] leave" if not choices.is_empty() else "[Enter/E] continue"


func _pick(i: int) -> void:
	if dialogue == null:
		return
	dialogue.choose(i)
	_refresh()


func _continue() -> void:
	if dialogue == null:
		return
	if dialogue.nodes.get(dialogue.current, {}).get("next", null) == null:
		close()
	else:
		dialogue.advance()
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or dialogue == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode >= KEY_1 and k.keycode <= KEY_9:
			var idx := k.keycode - KEY_1
			if idx < dialogue.available_choices().size():
				_pick(idx)
			get_viewport().set_input_as_handled()
		elif k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
			if dialogue.available_choices().is_empty():
				_continue()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
