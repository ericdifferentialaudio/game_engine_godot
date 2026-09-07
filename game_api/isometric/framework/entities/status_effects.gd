## Turn-scoped buffs/debuffs on a Unit. Defined inline by the applier:
##   {"id": "poisoned", "turns": 3, "modifiers": {"strength": -1}, "per_turn": {"health": -1}, "tags": ["poison"]}
## Durations tick down at UPKEEP of the owning faction's turn.
class_name StatusEffects
extends RefCounted

var owner: Unit
var active: Dictionary = {}   ## status_id -> {turns, modifiers, per_turn, tags}


func _init(p_owner: Unit) -> void:
	owner = p_owner


func apply(spec: Dictionary) -> void:
	var id: String = spec.get("id", "")
	if id == "":
		return
	remove(id, false)
	active[id] = {
		"turns": int(spec.get("turns", 1)),
		"modifiers": spec.get("modifiers", {}),
		"per_turn": spec.get("per_turn", {}),
		"tags": spec.get("tags", []),
	}
	if owner and not active[id]["modifiers"].is_empty():
		owner.stats.add_modifier("status:%s" % id, active[id]["modifiers"])
	EventBus.unit_status_applied.emit(owner.unit_id if owner else "", id)


func remove(id: String, notify: bool = true) -> void:
	if not active.erase(id):
		return
	if owner:
		owner.stats.remove_modifier("status:%s" % id)
	if notify:
		EventBus.unit_status_removed.emit(owner.unit_id if owner else "", id)


func has(id: String) -> bool:
	return active.has(id)


func has_tag(tag: String) -> bool:
	for s in active.values():
		if tag in s["tags"]:
			return true
	return false


## Called once per turn for the owner.
func tick() -> void:
	for id in active.keys():
		var s: Dictionary = active[id]
		for stat in s["per_turn"]:
			owner.stats.modify(stat, float(s["per_turn"][stat]))
		s["turns"] -= 1
		if s["turns"] <= 0:
			remove(id)
	if owner and owner.stats.has_stat("health") and owner.stats.get_value("health") <= 0.0:
		owner.die("status")


func to_save_data() -> Dictionary:
	return active.duplicate(true)


func from_save_data(d: Dictionary) -> void:
	active = d.duplicate(true)
	if owner:
		for id in active:
			if not active[id].get("modifiers", {}).is_empty():
				owner.stats.add_modifier("status:%s" % id, active[id]["modifiers"])
