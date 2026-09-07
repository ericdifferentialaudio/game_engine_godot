## Moves the actor to another map (dungeon entrance, city gate, stairs, warp).
##
##   {"kind": "portal", "target_map": "crypt_l1", "target_spawn": "entrance",
##    "requires": {"has": "crypt_location"},
##    "message": "You descend into the dark."}
##
## The descent itself is engine-specific (tile sub-map vs. loading a 3D scene),
## so it is delegated to the adapter.
class_name CorePortalInteraction
extends CoreInteraction

signal traversed(holder: String, target_map: String)


func _on_setup() -> void:
	kind = "portal"


func _execute(holder: String, actor, _target) -> void:
	var target_map := str(spec.get("target_map", spec.get("map", "")))
	if target_map == "":
		push_warning("CorePortalInteraction: no target_map on '%s'" % owner_id)
		return
	var spawn := str(spec.get("target_spawn", spec.get("spawn", "default")))
	if CoreContext.adapter.traverse(holder, target_map, spawn, actor):
		traversed.emit(holder, target_map)
