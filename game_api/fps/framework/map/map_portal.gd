## A traversal point between maps (door, cave mouth, stairs, town gate...).
##
## Interactable: the player looks at it and presses "interact". Portals may be
## gated by an IntelQuery in [member requires] (e.g. you must have learned the
## password to enter the thieves' den).
class_name MapPortal
extends Area3D

var portal_id: String = ""
var target_map: String = ""
var label: String = ""
var requires: Dictionary = {}
var locked_message: String = "You lack the knowledge to pass here."
var blocked_by_actor: String = ""     ## spawn key of an actor that must be dead/absent
var blocked_message: String = ""
var travel_text: String = ""          ## narrated when traversed
var visual_key: String = "portal.default"

var _interactable: Interactable


func _ready() -> void:
	collision_layer = 1 << 3  # "Portal"
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 1.0)
	shape.shape = box
	shape.position.y = 1.5
	add_child(shape)

	var visual := AssetRegistry.instance_scene(visual_key)
	add_child(visual)

	_interactable = Interactable.new()
	_interactable.prompt = "Enter %s" % label
	_interactable.interacted.connect(_on_interact)
	add_child(_interactable)


func is_unlocked() -> bool:
	return requires.is_empty() or IntelRegistry.evaluate(requires)


## An actor standing guard (alive, on this map) blocks the way.
func is_blocked() -> bool:
	if blocked_by_actor == "":
		return false
	var map := MapManager.current_map
	if map and map.get("actors") != null and map.actors.has(blocked_by_actor):
		var guard = map.actors[blocked_by_actor]
		return is_instance_valid(guard) and not guard.is_dead
	return false


func _on_interact(_by: Node) -> void:
	if not is_unlocked():
		EventBus.notification.emit(locked_message, "locked")
		return
	if is_blocked():
		EventBus.notification.emit(blocked_message if blocked_message != "" else "Something blocks the way.", "locked")
		return
	if travel_text != "":
		EventBus.notification.emit(travel_text, "travel")
	MapManager.traverse_portal(portal_id)
