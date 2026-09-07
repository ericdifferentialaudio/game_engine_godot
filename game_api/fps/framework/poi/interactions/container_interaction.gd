## A container you can OPEN, TAKE FROM and PUT INTO (mailbox, sack, trophy case).
##   {"kind": "container", "contents": {"leaflet": 1}, "open_text": "Opening the mailbox reveals a leaflet.",
##    "empty_text": "The mailbox is empty.", "accepts": ["treasure"], "deposit_score": {"egg": 5},
##    "deposit_text": "You place it in the case.", "closed_until": <IntelQuery>, "closed_text": "It is locked."}
##
## Behaviour on interact:
##   1. if closed_until fails  -> narrate closed_text
##   2. if it holds contents   -> take them all (narrate open_text once, then a list)
##   3. else, if the player carries an item whose category/tag is in `accepts`
##      -> deposit it (scoring via deposit_score / item value)
##   4. else                   -> narrate empty_text
class_name ContainerInteraction
extends Interaction


func _on_setup() -> void:
	kind = "container"
	consumes_interaction = spec.get("consumes", true)
	var st := _state()
	if not st.has("contents"):
		st["contents"] = spec.get("contents", {}).duplicate()
	if not st.has("deposited"):
		st["deposited"] = {}


func contents() -> Dictionary:
	return _state()["contents"]


func deposited() -> Dictionary:
	return _state()["deposited"]


func _execute(by: Node) -> void:
	var closed: Dictionary = spec.get("closed_until", {})
	if not closed.is_empty() and not IntelRegistry.evaluate(closed):
		EventBus.notification.emit(str(spec.get("closed_text", "It is closed.")), "examine")
		return
	var st := _state()
	if not st.get("opened", false):
		st["opened"] = true
		if spec.get("open_text", "") != "":
			EventBus.notification.emit(str(spec["open_text"]), "examine")
		for flag in spec.get("open_flags", []):
			GameManager.set_flag(str(flag), true)
		for tok in spec.get("open_intel", []):
			IntelRegistry.acquire(str(tok), poi.definition.id if poi and "definition" in poi and poi.definition else "")
	var inv := Shop.inventory_of(by)
	if inv == null:
		return
	if not contents().is_empty():
		_take_all(inv)
		return
	if _try_deposit(inv):
		return
	EventBus.notification.emit(str(spec.get("empty_text", "It is empty.")), "examine")


func _take_all(inv: Inventory) -> void:
	var names: Array[String] = []
	for item_id in contents().keys():
		var count := int(contents()[item_id])
		var added := inv.add_item(item_id, count)
		if added > 0:
			var def := DefinitionRegistry.get_def("items", item_id) as ItemDefinition
			names.append(def.display_name if def else str(item_id))
		if added >= count:
			contents().erase(item_id)
		else:
			contents()[item_id] = count - added
	if not names.is_empty():
		EventBus.notification.emit("Taken: %s." % ", ".join(names), "pickup")


func _try_deposit(inv: Inventory) -> bool:
	var accepts: Array = spec.get("accepts", [])
	if accepts.is_empty():
		return false
	var scores: Dictionary = spec.get("deposit_score", {})
	for inst in inv.items.duplicate():
		var def: ItemDefinition = inst.def
		var ok := def.category_name() in accepts
		for t in def.tags:
			if t in accepts:
				ok = true
		if scores.has(def.id):
			ok = true
		if not ok:
			continue
		inv.remove_item(def.id, 1)
		deposited()[def.id] = deposited().get(def.id, 0) + 1
		var pts := int(scores.get(def.id, def.raw.get("treasure_score", 0)))
		if pts > 0:
			GameManager.add_score(pts, "deposit:%s" % def.id)
		EventBus.notification.emit(str(spec.get("deposit_text", "You put the %s inside.")).replace("%s", def.display_name), "pickup")
		for flag in spec.get("deposit_flags", []):
			GameManager.set_flag(str(flag), true)
		return true
	return false
