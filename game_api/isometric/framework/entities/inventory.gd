## Item + equipment container. Attached to a Unit (heroes/NPCs/monster loot) or a
## Faction (stockpile). Currencies live on Faction.resources, not here.
##
## Using an item runs its use_effects (Interaction specs) and grants_intel to the
## owner's faction; equipping applies ItemDefinition.modifiers to the unit stats.
class_name Inventory
extends RefCounted

var owner_id: String = ""
var faction_id: String = ""
var items: Dictionary = {}       ## item_id -> count
var equipped: Dictionary = {}    ## slot -> item_id
var max_slots: int = 40
var stats: CharacterStats = null  ## Optional: equipment modifiers target this.
var allowed_slots: PackedStringArray = []


func add_item(item_id: String, count: int = 1) -> bool:
	var def := ItemRegistry.get_definition(item_id)
	if def == null:
		push_error("Inventory: unknown item '%s'" % item_id)
		return false
	if def.unique and items.has(item_id):
		return false
	if not items.has(item_id) and items.size() >= max_slots:
		EventBus.notification.emit("Inventory full.", "warning")
		return false
	var cap := def.max_stack if def.stackable else 1
	items[item_id] = mini(items.get(item_id, 0) + count, cap)
	if def.kind == "artifact" and stats and not def.modifiers.is_empty():
		stats.add_modifier("item:%s" % item_id, def.modifiers)
	EventBus.item_acquired.emit(owner_id, item_id, count)
	return true


func remove_item(item_id: String, count: int = 1) -> bool:
	if items.get(item_id, 0) < count:
		return false
	items[item_id] -= count
	if items[item_id] <= 0:
		items.erase(item_id)
		for slot in equipped.keys():
			if equipped[slot] == item_id:
				unequip(slot)
		if stats:
			stats.remove_modifier("item:%s" % item_id)
	EventBus.item_removed.emit(owner_id, item_id, count)
	return true


func has_item(item_id: String, count: int = 1) -> bool:
	return items.get(item_id, 0) >= count


func count(item_id: String) -> int:
	return items.get(item_id, 0)


## Consume/read an item. Returns false if requirements fail.
func use_item(item_id: String, user: Node = null) -> bool:
	var def := ItemRegistry.get_definition(item_id)
	if def == null or not has_item(item_id) or not def.is_usable():
		return false
	if not def.use_requires.is_empty() and not IntelRegistry.evaluate(def.use_requires, faction_id):
		EventBus.notification.emit("You cannot make sense of this yet.", "warning")
		return false
	for tok in def.grants_intel:
		IntelRegistry.acquire(faction_id, tok, item_id, "read")
	for spec in def.use_effects:
		var inter := InteractionFactory.create(spec, user)
		if inter:
			inter.run_for_holder(faction_id, item_id, user)
	EventBus.item_used.emit(owner_id, item_id)
	if def.consume_on_use:
		remove_item(item_id, 1)
	return true


func equip(item_id: String) -> bool:
	var def := ItemRegistry.get_definition(item_id)
	if def == null or not def.is_equippable() or not has_item(item_id):
		return false
	if not allowed_slots.is_empty() and def.slot not in allowed_slots:
		return false
	if equipped.has(def.slot):
		unequip(def.slot)
	equipped[def.slot] = item_id
	if stats:
		stats.add_modifier("equip:%s" % def.slot, def.modifiers)
	EventBus.item_equipped.emit(owner_id, item_id, def.slot)
	return true


func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	var item_id: String = equipped[slot]
	equipped.erase(slot)
	if stats:
		stats.remove_modifier("equip:%s" % slot)
	EventBus.item_unequipped.emit(owner_id, item_id, slot)


func total_value() -> int:
	var v := 0
	for id in items:
		var def := ItemRegistry.get_definition(id)
		if def:
			v += def.value * items[id]
	return v


func to_save_data() -> Dictionary:
	return {"items": items.duplicate(), "equipped": equipped.duplicate()}


func from_save_data(d: Dictionary) -> void:
	items = d.get("items", {})
	equipped = d.get("equipped", {})
	if stats:
		for slot in equipped:
			var def := ItemRegistry.get_definition(equipped[slot])
			if def:
				stats.add_modifier("equip:%s" % slot, def.modifiers)
