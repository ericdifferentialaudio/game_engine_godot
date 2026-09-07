## Descend into / return from a site sub-map, carrying the acting unit (and its
## stacked companions) along.
##   {"kind": "portal", "target_map": "sunken_crypt_1", "target_coord": [3, 3], "direction": "descend"|"ascend",
##    "requires": {"has": "crypt_location", "min_reliability": 0.6}, "message": "You descend into the dark."}
class_name PortalInteraction
extends Interaction


func _on_setup() -> void:
	kind = "portal"


func can_run(by) -> bool:
	if not super.can_run(by):
		return false
	# Only heroes/mobile units of the player or AI travel through portals.
	return by is Unit and by.definition.is_mobile()


func _execute(_holder: String, actor: Unit, _target) -> void:
	if actor == null:
		return
	var direction: String = spec.get("direction", "descend")
	var target_map: String = spec.get("target_map", "")
	var tc: Array = spec.get("target_coord", [0, 0])
	var coord := Vector2i(int(tc[0]), int(tc[1]))
	var travellers: Array = WorldManager.world.units_at(actor.coord).duplicate() if WorldManager.world else [actor]
	var portal_id := "%s_%d" % [source_id(), spec.get("index", 0)]
	if direction == "ascend":
		WorldManager.ascend(portal_id)
	else:
		if target_map == "":
			return
		WorldManager.descend(target_map, portal_id)
	if WorldManager.current_id != target_map and direction != "ascend":
		return  # Depth limit or bad target.
	for u in travellers:
		if u is Unit and u.faction_id == actor.faction_id:
			EntityRegistry.transfer_unit(u.unit_id, WorldManager.current_id, MapGenerator.find_land_near(WorldManager.world, coord))
			if WorldManager.world:
				WorldManager.world.place_unit(u, u.coord)
	WorldManager.refresh_all_visibility()
	EventBus.camera_focus_requested.emit(actor.coord)
