## Decides what an Actor does each frame. PlayerBrain reads input; AIBrain
## reads Perception and picks abilities/movement. Exactly one Brain per Actor.
class_name Brain
extends Node

var actor: Actor


func setup(p_actor: Actor) -> void:
	actor = p_actor
	_brain_ready()


func _brain_ready() -> void:
	pass


func _definition_applied(_def: ActorDefinition) -> void:
	pass


## Shared gravity/floor handling so both brains move the body consistently.
func apply_gravity(delta: float) -> void:
	if not actor.is_on_floor():
		actor.velocity.y -= actor.gravity * delta


func is_disabled() -> bool:
	return actor.is_dead or (actor.status_effects and (actor.status_effects.has_flag("stunned") or actor.status_effects.has_flag("rooted")))


func to_save_data() -> Dictionary:
	return {}


func from_save_data(_d: Dictionary) -> void:
	pass
