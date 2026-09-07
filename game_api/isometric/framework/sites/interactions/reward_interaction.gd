## Grants resources, items, stats, statuses, xp or flags.
##   {"kind": "reward", "resources": {"gold": 25}, "items": {"healing_herb": 2},
##    "to": "actor"|"stockpile",  "stat_delta": {"health": 5}, "status": {...StatusEffects spec...},
##    "xp": 10, "set_flags": ["found_cache"], "set_faction_flags": ["met_elders"],
##    "heal_full": false, "once": true, "message": "You find a hidden cache."}
class_name RewardInteraction
extends Interaction


func _on_setup() -> void:
	kind = "reward"


func _execute(holder: String, actor: Unit, target) -> void:
	var faction := FactionRegistry.get_faction(holder)
	var recipient: Unit = target if target is Unit else actor
	if faction:
		for res in spec.get("resources", {}):
			faction.add_resource(res, float(spec["resources"][res]))
	var items: Dictionary = spec.get("items", {})
	if not items.is_empty():
		var inv: Inventory = null
		if spec.get("to", "actor") == "actor" and recipient and (recipient.is_hero() or recipient.definition.kind == "npc"):
			inv = recipient.inventory
		elif faction:
			inv = faction.stockpile
		if inv:
			for item in items:
				inv.add_item(item, int(items[item]))
	if recipient:
		for stat in spec.get("stat_delta", {}):
			recipient.stats.modify(stat, float(spec["stat_delta"][stat]))
		if spec.get("heal_full", false):
			recipient.stats.restore_all()
		if spec.has("status"):
			recipient.statuses.apply(spec["status"])
		if spec.has("xp"):
			recipient.gain_xp(int(spec["xp"]))
	for flag in spec.get("set_flags", []):
		GameManager.set_flag(flag, true)
	if faction:
		for flag in spec.get("set_faction_flags", []):
			faction.set_flag(flag, true)
	EventBus.reward_granted.emit(spec.get("id", "reward_%d" % spec.get("index", 0)), source_id())
