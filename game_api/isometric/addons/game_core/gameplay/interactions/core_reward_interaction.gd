## Grants resources, items, stat changes, xp or flags.
##
##   {"kind": "reward", "resources": {"gold": 25}, "items": {"healing_herb": 2},
##    "to": "actor"|"stockpile", "stat_delta": {"health": 5}, "xp": 10,
##    "heal_full": false, "status": {"id": "blessed", "turns": 3},
##    "set_flags": ["found_cache"], "set_holder_flags": ["met_elders"],
##    "once": true, "message": "You find a hidden cache."}
##
## Items go to the actor's inventory when it has one, otherwise to the holder's
## stockpile via the engine adapter.
class_name CoreRewardInteraction
extends CoreInteraction

signal granted(holder: String, reward_id: String)


func _on_setup() -> void:
	kind = "reward"


func _execute(holder: String, actor, target) -> void:
	var recipient = target if target != null else actor

	for res in spec.get("resources", {}):
		CoreContext.adapter.add_resource(holder, str(res), float(spec["resources"][res]))

	var items: Dictionary = spec.get("items", {})
	if not items.is_empty():
		var inv := _inventory_of(recipient) if spec.get("to", "actor") == "actor" else null
		for item_id in items:
			var n := int(items[item_id])
			if inv != null:
				inv.add_item(str(item_id), n)
			else:
				CoreContext.adapter.add_to_stockpile(holder, str(item_id), n)

	var stats := _stats_of(recipient)
	if stats != null:
		for stat in spec.get("stat_delta", {}):
			stats.modify(str(stat), float(spec["stat_delta"][stat]))
		if spec.get("heal_full", false):
			stats.restore_all()

	if spec.has("status") and recipient != null and recipient is Object \
			and recipient.has_method("apply_status"):
		recipient.apply_status(spec["status"])
	if spec.has("xp") and recipient != null and recipient is Object \
			and recipient.has_method("gain_xp"):
		recipient.gain_xp(int(spec["xp"]))

	for flag in spec.get("set_flags", []):
		CoreContext.set_flag(str(flag), true)
	for flag in spec.get("set_holder_flags", spec.get("set_faction_flags", [])):
		CoreContext.set_holder_flag(holder, str(flag), true)

	granted.emit(holder, str(spec.get("id", owner_id)))


func _inventory_of(node) -> CoreInventory:
	if node != null and node is Object and "inventory" in node and node.inventory is CoreInventory:
		return node.inventory
	return null


func _stats_of(node) -> CoreStats:
	if node != null and node is Object and "stats" in node and node.stats is CoreStats:
		return node.stats
	return null
