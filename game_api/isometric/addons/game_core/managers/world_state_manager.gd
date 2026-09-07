extends Node
## Autoload: WorldStateManager
## Shared world-state / consequence graph. Stores discrete "facts" that
## either engine's gameplay logic can commit and query, independent of
## rendering. Populated during the Python -> GDScript port.

signal fact_committed(fact_id: StringName, value: Variant)

var _facts: Dictionary = {}


func has_fact(fact_id: StringName) -> bool:
	return _facts.has(fact_id)


func get_fact(fact_id: StringName, default_value: Variant = null) -> Variant:
	return _facts.get(fact_id, default_value)


func commit_fact(fact_id: StringName, value: Variant) -> void:
	_facts[fact_id] = value
	fact_committed.emit(fact_id, value)


func reset() -> void:
	_facts.clear()
