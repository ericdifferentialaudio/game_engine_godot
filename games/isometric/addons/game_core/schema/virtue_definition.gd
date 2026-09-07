class_name VirtueDefinition
extends Resource
## Shared data contract describing a single virtue/morality axis tracked
## by VirtueSystem (e.g. "honesty", "courage").

@export var virtue_id: StringName = &""
@export var display_name: String = ""
@export var min_value: float = -100.0
@export var max_value: float = 100.0
@export var default_value: float = 0.0
