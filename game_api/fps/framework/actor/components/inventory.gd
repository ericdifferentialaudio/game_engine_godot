## Item container: stacks of ItemInstance plus currencies.
##
## Convenience `add_item(id, count)` / `remove_item(id, count)` keep the
## data-driven interactions (rewards, shops) simple; UI and equipment work with
## ItemInstance objects directly.
class_name Inventory
extends ActorComponent

signal changed
signal item_added(inst: ItemInstance, count: int)
signal item_removed(item_id: String, count: int)
signal currency_changed(currency_id: String, amount: int)

@export var max_slots: int = 40
@export var max_weight: float = 0.0        ## 0 = unlimited

var items: Array[ItemInstance] = []
var currencies: Dictionary = {}             ## currency_id -> int


func _actor_ready() -> void:
	var cfg: Dictionary = GameManager.game_config.get("inventory", {})
	max_slots = int(cfg.get("max_slots", max_slots))
	max_weight = float(cfg.get("max_weight", max_weight))


func _definition_applied(def: ActorDefinition) -> void:
	for item_id in def.inventory:
		add_item(item_id, int(def.inventory[item_id]))


# --- Add / remove ------------------------------------------------------------

## Add [param count] of an item by id. Returns the number actually added.
func add_item(item_id: String, count: int = 1) -> int:
	var def := DefinitionRegistry.get_def("items", item_id) as ItemDefinition
	if def == null:
		return 0
	if def.category == ItemDefinition.Category.CURRENCY:
		add_currency(item_id, count)
		return count
	var remaining := count
	# Fill existing stacks first.
	if def.stackable:
		for inst in items:
			if inst.def == def and inst.affixes.is_empty() and inst.space_left() > 0:
				var n := mini(inst.space_left(), remaining)
				inst.count += n
				remaining -= n
				item_added.emit(inst, n)
				if remaining <= 0:
					break
	# New stacks.
	while remaining > 0:
		if not _can_add_slot(def):
			break
		var n := mini(def.max_stack, remaining)
		var inst := ItemInstance.create(def, n)
		items.append(inst)
		remaining -= n
		item_added.emit(inst, n)
	var added := count - remaining
	if added > 0:
		EventBus.item_acquired.emit(item_id, added)
		changed.emit()
	elif remaining > 0:
		EventBus.notification.emit("Inventory full.", "warning")
	return added


## Add an existing instance (loot, unequip). Merges into stacks when possible.
func add_instance(inst: ItemInstance) -> bool:
	if inst.def.category == ItemDefinition.Category.CURRENCY:
		add_currency(inst.def.id, inst.count)
		return true
	for other in items:
		if other.can_stack_with(inst) and other.space_left() >= inst.count:
			other.count += inst.count
			item_added.emit(other, inst.count)
			changed.emit()
			return true
	if not _can_add_slot(inst.def):
		EventBus.notification.emit("Inventory full.", "warning")
		return false
	items.append(inst)
	item_added.emit(inst, inst.count)
	EventBus.item_acquired.emit(inst.def.id, inst.count)
	changed.emit()
	return true


func remove_item(item_id: String, count: int = 1) -> bool:
	if count_of(item_id) < count:
		return false
	var remaining := count
	for i in range(items.size() - 1, -1, -1):
		var inst := items[i]
		if inst.def.id != item_id:
			continue
		var n := mini(inst.count, remaining)
		inst.count -= n
		remaining -= n
		if inst.count <= 0:
			items.remove_at(i)
		if remaining <= 0:
			break
	item_removed.emit(item_id, count)
	EventBus.item_removed.emit(item_id, count)
	changed.emit()
	return true


func remove_instance(inst: ItemInstance) -> bool:
	var idx := items.find(inst)
	if idx < 0:
		return false
	items.remove_at(idx)
	item_removed.emit(inst.def.id, inst.count)
	changed.emit()
	return true


func _can_add_slot(def: ItemDefinition) -> bool:
	if items.size() >= max_slots:
		return false
	if max_weight > 0.0 and total_weight() + def.weight > max_weight:
		return false
	return true


# --- Queries -----------------------------------------------------------------

func count_of(item_id: String) -> int:
	var n := 0
	for inst in items:
		if inst.def.id == item_id:
			n += inst.count
	return n


func has_item(item_id: String, count: int = 1) -> bool:
	return count_of(item_id) >= count


func find_first(item_id: String) -> ItemInstance:
	for inst in items:
		if inst.def.id == item_id:
			return inst
	return null


func find_by_uid(uid: int) -> ItemInstance:
	for inst in items:
		if inst.uid == uid:
			return inst
	return null


func by_category(category: ItemDefinition.Category) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for inst in items:
		if inst.def.category == category:
			out.append(inst)
	return out


func total_weight() -> float:
	var w := 0.0
	for inst in items:
		w += inst.weight()
	return w


func slots_used() -> int:
	return items.size()


# --- Currency ----------------------------------------------------------------

func add_currency(currency_id: String, amount: int) -> void:
	currencies[currency_id] = currencies.get(currency_id, 0) + amount
	currency_changed.emit(currency_id, currencies[currency_id])
	EventBus.currency_changed.emit(currency_id, currencies[currency_id])


func spend_currency(currency_id: String, amount: int) -> bool:
	if get_currency(currency_id) < amount:
		return false
	add_currency(currency_id, -amount)
	return true


func get_currency(currency_id: String) -> int:
	return currencies.get(currency_id, 0)


# --- Persistence -------------------------------------------------------------

func to_save_data() -> Dictionary:
	var arr := []
	for inst in items:
		arr.append(inst.to_dict())
	return {"items": arr, "currencies": currencies.duplicate()}


func from_save_data(d: Dictionary) -> void:
	items.clear()
	for entry in d.get("items", []):
		var inst := ItemInstance.from_dict(entry)
		if inst:
			items.append(inst)
	currencies = d.get("currencies", {})
	changed.emit()
