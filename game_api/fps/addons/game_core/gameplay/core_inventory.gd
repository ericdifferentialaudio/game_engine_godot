## Item + equipment + currency container, shared by both graphics engines.
##
## Attach one to a unit (hero, NPC, monster loot) or to a faction/town stockpile.
## Equipping applies the item's `stats` to an optional CoreStats block; using an
## item runs its `use_effects`, grants its `grants_intel`, and is gated by its
## `requires` intel query.
##
## API:
##   inv.add_item(id, count) / remove_item(id, count) / has_item(id, count)
##   inv.use_item(id) / equip(id) / unequip(slot)
##   inv.add_currency(id, amount) / spend_currency(id, amount) / currency(id)
##   inv.total_value() / total_weight()
class_name CoreInventory
extends RefCounted

signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_used(item_id: String)
signal item_equipped(item_id: String, slot: String)
signal item_unequipped(item_id: String, slot: String)
signal currency_changed(currency_id: String, new_amount: int)
signal use_refused(item_id: String, reason: String)

var owner_id: String = ""
var holder: String = ""             ## Intel holder this inventory answers to.
var items: Dictionary = {}          ## item_id -> count
var equipped: Dictionary = {}       ## slot -> item_id
var currencies: Dictionary = {}     ## currency_id -> amount
var max_slots: int = 40
var max_weight: float = 0.0         ## 0 = unlimited
var stats: CoreStats = null         ## Optional: equipment modifiers target this.
var allowed_slots: PackedStringArray = []


func _init(p_owner: String = "", p_holder: String = "") -> void:
	owner_id = p_owner
	holder = p_holder if p_holder != "" else p_owner


func _def(item_id: String) -> CoreItemDefinition:
	return CoreRegistry.get_def("items", item_id) as CoreItemDefinition


# --- Items --------------------------------------------------------------------

func add_item(item_id: String, count: int = 1) -> bool:
	var def := _def(item_id)
	if def == null:
		return false
	if def.unique and items.has(item_id):
		return false
	if not items.has(item_id) and items.size() >= max_slots:
		CoreContext.adapter.notify("Inventory full.", "warning")
		return false
	if max_weight > 0.0 and total_weight() + def.weight * count > max_weight:
		CoreContext.adapter.notify("Too heavy to carry.", "warning")
		return false
	var cap := def.max_stack if def.stackable else 1
	items[item_id] = mini(items.get(item_id, 0) + count, cap)
	# Artifacts modify stats simply by being held.
	if def.category == CoreItemDefinition.Category.ARTIFACT and stats and not def.stats.is_empty():
		stats.add_modifier("item:%s" % item_id, def.stats)
	item_added.emit(item_id, count)
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
	item_removed.emit(item_id, count)
	return true


func has_item(item_id: String, count: int = 1) -> bool:
	return items.get(item_id, 0) >= count


func count(item_id: String) -> int:
	return items.get(item_id, 0)


func items_of_category(category: int) -> Array[String]:
	var out: Array[String] = []
	for id in items:
		var def := _def(id)
		if def and def.category == category:
			out.append(id)
	return out


## Consume/read an item. Returns false (with `use_refused`) if gated or unusable.
func use_item(item_id: String) -> bool:
	var def := _def(item_id)
	if def == null or not has_item(item_id) or not def.is_usable():
		return false
	if not def.requires.is_empty() and not CoreIntel.evaluate(def.requires, holder):
		use_refused.emit(item_id, "requires")
		CoreContext.adapter.notify("You cannot make sense of this yet.", "warning")
		return false
	if not _meets_stat_requirements(def):
		use_refused.emit(item_id, "requires_stats")
		return false
	for token_id in def.grants_intel:
		CoreIntel.acquire(holder, token_id, item_id, "read")
	item_used.emit(item_id)
	if def.consumed_on_use:
		remove_item(item_id, 1)
	return true


# --- Equipment ----------------------------------------------------------------

func equip(item_id: String) -> bool:
	var def := _def(item_id)
	if def == null or not def.is_equippable() or not has_item(item_id):
		return false
	if not allowed_slots.is_empty() and def.equip_slot not in allowed_slots:
		return false
	if not def.requires.is_empty() and not CoreIntel.evaluate(def.requires, holder):
		use_refused.emit(item_id, "requires")
		return false
	if not _meets_stat_requirements(def):
		use_refused.emit(item_id, "requires_stats")
		return false
	if equipped.has(def.equip_slot):
		unequip(def.equip_slot)
	equipped[def.equip_slot] = item_id
	if stats:
		stats.add_modifier("equip:%s" % def.equip_slot, def.stats)
	item_equipped.emit(item_id, def.equip_slot)
	return true


func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	var item_id: String = equipped[slot]
	equipped.erase(slot)
	if stats:
		stats.remove_modifier("equip:%s" % slot)
	item_unequipped.emit(item_id, slot)


func equipped_in(slot: String) -> String:
	return equipped.get(slot, "")


# --- Currency -----------------------------------------------------------------

func currency(currency_id: String) -> int:
	return int(currencies.get(currency_id, 0))


func add_currency(currency_id: String, amount: int) -> void:
	currencies[currency_id] = currency(currency_id) + amount
	currency_changed.emit(currency_id, currencies[currency_id])


func spend_currency(currency_id: String, amount: int) -> bool:
	if currency(currency_id) < amount:
		return false
	add_currency(currency_id, -amount)
	return true


# --- Aggregates ---------------------------------------------------------------

func total_value() -> int:
	var v := 0
	for id in items:
		var def := _def(id)
		if def:
			v += def.value * items[id]
	return v


func total_weight() -> float:
	var w := 0.0
	for id in items:
		var def := _def(id)
		if def:
			w += def.weight * items[id]
	return w


func to_save_data() -> Dictionary:
	return {"items": items.duplicate(), "equipped": equipped.duplicate(),
		"currencies": currencies.duplicate()}


func from_save_data(d: Dictionary) -> void:
	items = d.get("items", {})
	equipped = d.get("equipped", {})
	currencies = d.get("currencies", {})
	if stats:
		for slot in equipped:
			var def := _def(equipped[slot])
			if def:
				stats.add_modifier("equip:%s" % slot, def.stats)


func _meets_stat_requirements(def: CoreItemDefinition) -> bool:
	if stats == null or def.requires_stats.is_empty():
		return true
	for stat in def.requires_stats:
		if stats.get_value(stat) < float(def.requires_stats[stat]):
			return false
	return true
