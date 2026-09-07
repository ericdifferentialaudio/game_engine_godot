## Presents a DialogueInteraction. Registered in group "dialogue_ui".
extends PanelContainer

@onready var _speaker: Label = %SpeakerLabel
@onready var _text: RichTextLabel = %DialogueText
@onready var _choices: VBoxContainer = %Choices

var _dialogue: DialogueInteraction = null


func _ready() -> void:
	add_to_group("dialogue_ui")
	visible = false


func open(dialogue: DialogueInteraction) -> void:
	_dialogue = dialogue
	visible = true
	GameManager.set_state(GameManager.State.DIALOGUE)
	_render()


func _render() -> void:
	for c in _choices.get_children():
		c.queue_free()
	if _dialogue == null or _dialogue.current == "":
		_close()
		return
	_speaker.text = _dialogue.speaker()
	_text.text = _dialogue.current_text()
	var choices := _dialogue.available_choices()
	if choices.is_empty():
		var b := Button.new()
		b.text = "Continue"
		b.pressed.connect(_close)
		_choices.add_child(b)
		return
	for i in choices.size():
		var b := Button.new()
		b.text = choices[i].get("text", "...")
		b.pressed.connect(func():
			_dialogue.choose(i)
			_render())
		_choices.add_child(b)


func _close() -> void:
	if _dialogue:
		_dialogue.end()
	_dialogue = null
	visible = false
	if GameManager.state == GameManager.State.DIALOGUE:
		GameManager.set_state(GameManager.State.PLAYING)
