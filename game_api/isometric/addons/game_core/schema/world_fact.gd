class_name WorldFact
extends Resource
## Shared data contract describing a single discrete world-state fact
## definition (the "shape", not the runtime value -- runtime values live
## in WorldStateManager).

@export var fact_id: StringName = &""
@export var description: String = ""
@export var default_value: Variant = null
