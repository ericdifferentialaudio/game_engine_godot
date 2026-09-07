## Grants items, currency and/or flags.
##   {"kind": "reward", "id": "cache_ruins", "items": {"potion_minor": 2},
##    "currency": {"gold": 50}, "set_flags": ["found_ruins_cache"], "once": true}
class_name RewardInteraction
extends Interaction


func _on_setup() -> void:
	kind = "reward"


func _execute(by: Node) -> void:
	var inventory := Shop.inventory_of(by)
	var items: Dictionary = spec.get("items", {})
	for item_id in items:
		var count := int(items[item_id])
		if inventory and inventory.has_method("add_item"):
			inventory.add_item(item_id, count)
		else:
			EventBus.item_acquired.emit(item_id, count)
	var currency: Dictionary = spec.get("currency", {})
	for cur in currency:
		if inventory and inventory.has_method("add_currency"):
			inventory.add_currency(cur, int(currency[cur]))
	for flag in spec.get("set_flags", []):
		GameManager.set_flag(flag, true)
	var poi_id: String = poi.definition.id if poi and "definition" in poi else ""
	EventBus.reward_granted.emit(spec.get("id", poi_id), poi_id)
	var msg: String = spec.get("message", "")
	if msg != "":
		EventBus.notification.emit(msg, "reward")
