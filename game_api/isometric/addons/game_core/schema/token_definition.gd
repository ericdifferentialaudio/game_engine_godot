class_name TokenDefinition
extends Resource
## Shared data contract for an "information token" -- a discrete piece of
## knowledge/lore/clue that either game's dialogue or world-state systems
## can reference and unlock.

@export var token_id: StringName = &""
@export var display_name: String = ""
@export var summary: String = ""
@export var related_fact_ids: PackedStringArray = []
