## Base class for all actor components. Components are child Nodes of an Actor;
## the Actor discovers them by class and calls [method setup] once, before
## [method _actor_ready]. Keep components independent — talk to siblings via
## [member actor] accessors, never by node path.
class_name ActorComponent
extends Node

var actor: Actor


func setup(p_actor: Actor) -> void:
	actor = p_actor
	_actor_ready()


## Called once the actor and all sibling components exist.
func _actor_ready() -> void:
	pass


## Called after the actor definition has been applied (stats, resources...).
func _definition_applied(_def: ActorDefinition) -> void:
	pass


func to_save_data() -> Dictionary:
	return {}


func from_save_data(_d: Dictionary) -> void:
	pass
