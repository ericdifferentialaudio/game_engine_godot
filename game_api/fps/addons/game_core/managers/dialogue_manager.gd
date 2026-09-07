extends Node
## Autoload: DialogueManager
## Shared dialogue/branching-conversation system. Placeholder pending the
## Python -> GDScript port of the existing dialogue logic.

signal dialogue_started(dialogue_id: StringName)
signal dialogue_line_shown(speaker_id: StringName, text: String)
signal dialogue_ended(dialogue_id: StringName)

var _active_dialogue_id: StringName = &""


func is_dialogue_active() -> bool:
	return _active_dialogue_id != &""


func start_dialogue(dialogue_id: StringName) -> void:
	_active_dialogue_id = dialogue_id
	dialogue_started.emit(dialogue_id)


func end_dialogue() -> void:
	var finished_id := _active_dialogue_id
	_active_dialogue_id = &""
	dialogue_ended.emit(finished_id)
