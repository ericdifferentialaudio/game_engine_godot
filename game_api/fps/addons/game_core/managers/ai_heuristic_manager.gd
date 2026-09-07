extends Node
## Autoload: AIHeuristicManager
## Shared AI influence-map / heuristic decision logic. Placeholder pending
## the Python -> GDScript port. Kept engine-agnostic: this node must never
## reference isometric- or fps-specific scene nodes directly.

signal heuristic_evaluated(agent_id: StringName, chosen_action: StringName)


func evaluate(agent_id: StringName, _context: Dictionary) -> StringName:
	# TODO: port influence-map / heuristic scoring logic from the existing
	# Python isometric and fps prototypes once source paths are provided.
	var chosen_action: StringName = &"idle"
	heuristic_evaluated.emit(agent_id, chosen_action)
	return chosen_action
