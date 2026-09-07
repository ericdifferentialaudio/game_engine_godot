## Marker component that makes its parent interactable by the player's
## InteractionRay. Parent must be a CollisionObject3D on the "Interactable" or
## "Portal" physics layer so the raycast can hit it.
class_name Interactable
extends Node

signal focused
signal unfocused
signal interacted(by: Node)

@export var prompt: String = "Interact"
@export var enabled: bool = true


func focus() -> void:
	if enabled:
		focused.emit()
		EventBus.interaction_prompt.emit(prompt, true)


func unfocus() -> void:
	unfocused.emit()
	EventBus.interaction_prompt.emit("", false)


func interact(by: Node) -> void:
	if enabled:
		interacted.emit(by)
