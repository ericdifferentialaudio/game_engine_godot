class_name UnitDefinition
extends Resource
## Shared data contract for a "unit" (character/NPC/agent) usable by both
## the isometric and fps games. Any field added here is available to both
## games simultaneously -- this is the actual point of the shared core.

@export var unit_id: StringName = &""
@export var display_name: String = ""
@export var max_health: float = 100.0
@export var move_speed: float = 4.0
@export var base_virtues: Dictionary = {}   # virtue_id (StringName) -> float
@export var tags: PackedStringArray = []
