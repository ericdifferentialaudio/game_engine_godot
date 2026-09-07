extends Node
## Autoload: VirtueSystem
## Tracks player/NPC virtue or morality state shared by both the isometric
## and FPS front ends. Populated during the Python -> GDScript port.
##
## Front ends (isometric, fps) MUST only interact with this through its
## public API and signals below -- never reach into internal state directly.

signal virtue_changed(virtue_id: StringName, old_value: float, new_value: float)

var _virtue_values: Dictionary = {}


func get_virtue(virtue_id: StringName) -> float:
	return _virtue_values.get(virtue_id, 0.0)


func set_virtue(virtue_id: StringName, value: float) -> void:
	var old_value: float = _virtue_values.get(virtue_id, 0.0)
	if is_equal_approx(old_value, value):
		return
	_virtue_values[virtue_id] = value
	virtue_changed.emit(virtue_id, old_value, value)


func reset() -> void:
	_virtue_values.clear()
