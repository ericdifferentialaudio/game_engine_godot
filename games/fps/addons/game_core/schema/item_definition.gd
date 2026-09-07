class_name ItemDefinition
extends Resource
## Shared data contract for an inventory/world item, usable by both games.

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var stack_size: int = 1
@export var tags: PackedStringArray = []
