## "TAKE" an object. Items go into the inventory, the POI vanishes, and the
## fact that it was taken is persisted in the map state.
##   {"kind": "pickup", "items": {"brass_lantern": 1}, "message": "Taken.",
##    "grant_intel": [...], "set_flags": [...], "score": 5, "requires": <IntelQuery>}
class_name PickupInteraction
extends Interaction


func _on_setup() -> void:
	kind = "pickup"
	spec["once"] = true


func can_run(by: Node) -> bool:
	if _state().get("taken", false):
		return false
	if poi is PointOfInterest and (poi as PointOfInterest).is_taken():
		return false
	return super.can_run(by)


func _execute(by: Node) -> void:
	var inv := Shop.inventory_of(by)
	var items: Dictionary = spec.get("items", {})
	var names: Array[String] = []
	var all_taken := true
	for item_id in items:
		var count := int(items[item_id])
		var def := DefinitionRegistry.get_def("items", item_id) as ItemDefinition
		var added := inv.add_item(item_id, count) if inv else 0
		if added < count:
			all_taken = false
		if added > 0:
			names.append(def.display_name if def else str(item_id))
	if not all_taken:
		EventBus.notification.emit("Your load is too heavy.", "warning")
		spec["once"] = false   # let them try again later
		return
	spec["once"] = true
	_state()["taken"] = true
	var msg: String = spec.get("message", "Taken." if names.size() <= 1 else "Taken: %s." % ", ".join(names))
	EventBus.notification.emit(msg, "pickup")
	var poi_id: String = poi.definition.id if poi and "definition" in poi and poi.definition else ""
	for tok in spec.get("grant_intel", []):
		IntelRegistry.acquire(str(tok), poi_id)
	for flag in spec.get("set_flags", []):
		GameManager.set_flag(str(flag), true)
	if spec.has("score"):
		GameManager.add_score(int(spec["score"]), "pickup:%s" % poi_id)
	if poi is PointOfInterest:
		(poi as PointOfInterest).set_taken()
