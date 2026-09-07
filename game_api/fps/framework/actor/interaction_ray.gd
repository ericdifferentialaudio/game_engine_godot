## Raycast from the camera that finds Interactable components and forwards
## the "interact" action to them.
class_name InteractionRay
extends RayCast3D

@export var reach: float = 3.0

var _current: Interactable = null


func _ready() -> void:
	target_position = Vector3(0, 0, -reach)
	collision_mask = (1 << 2) | (1 << 3)  # Interactable | Portal
	collide_with_areas = true
	collide_with_bodies = true


func _physics_process(_delta: float) -> void:
	var found: Interactable = null
	if is_colliding():
		var col := get_collider()
		if col:
			for child in col.get_children():
				if child is Interactable and child.enabled:
					found = child
					break
	if found != _current:
		if _current:
			_current.unfocus()
		_current = found
		if _current:
			_current.focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current:
		_current.interact(_owning_actor())


## Walk up to the Actor that owns this ray (Player > Head > Camera > Ray).
func _owning_actor() -> Node:
	var n: Node = self
	while n and not (n is Actor):
		n = n.get_parent()
	return n if n else (owner if owner else get_parent())
