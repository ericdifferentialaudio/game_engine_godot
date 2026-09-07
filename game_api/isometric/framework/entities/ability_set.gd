## Active abilities a Unit can use (defined in units.json "abilities_catalog" or
## inline per game in ai_profiles.json "abilities"). An ability is a gated bundle
## of Interaction specs with a target mode and action-point cost:
##
##   {"id": "scout_report", "display_name": "Send Report", "cost_ap": 1, "cooldown": 3,
##    "target": "self"|"tile"|"unit"|"enemy"|"ally", "range": 0,
##    "requires": {"has": "..."}, "effects": [{"kind": "intel", "tokens": ["..."]}]}
class_name AbilitySet
extends RefCounted

static var catalog: Dictionary = {}   ## ability_id -> spec (loaded by EntityRegistry)

var owner: Unit
var ids: Array[String] = []
var cooldowns: Dictionary = {}        ## ability_id -> turns remaining


func _init(p_owner: Unit, p_ids: PackedStringArray) -> void:
	owner = p_owner
	for id in p_ids:
		ids.append(id)


static func spec_of(id: String) -> Dictionary:
	return catalog.get(id, {})


func can_use(id: String, target = null) -> bool:
	var spec := spec_of(id)
	if spec.is_empty() or id not in ids or cooldowns.get(id, 0) > 0:
		return false
	if owner.action_points < float(spec.get("cost_ap", 1)):
		return false
	var req: Dictionary = spec.get("requires", {})
	if not req.is_empty() and not IntelRegistry.evaluate(req, owner.faction_id):
		return false
	var mode: String = spec.get("target", "self")
	var range_: int = int(spec.get("range", 0))
	match mode:
		"self":
			return true
		"tile":
			return target is Vector2i and WorldManager.world.topology.distance(owner.coord, target) <= range_
		"unit", "enemy", "ally":
			if not (target is Unit):
				return false
			if WorldManager.world.topology.distance(owner.coord, target.coord) > range_:
				return false
			if mode == "enemy":
				return FactionRegistry.are_hostile(owner.faction_id, target.faction_id)
			if mode == "ally":
				return not FactionRegistry.are_hostile(owner.faction_id, target.faction_id)
			return true
	return false


func use(id: String, target = null) -> bool:
	if not can_use(id, target):
		return false
	var spec := spec_of(id)
	owner.spend_action_points(float(spec.get("cost_ap", 1)))
	cooldowns[id] = int(spec.get("cooldown", 0))
	var target_node: Node = target if target is Node else owner
	for eff in spec.get("effects", []):
		var inter := InteractionFactory.create(eff, target_node)
		if inter:
			inter.run_for_holder(owner.faction_id, owner.unit_id, owner, target)
	EventBus.ability_used.emit(owner.unit_id, id, target)
	return true


func tick() -> void:
	for id in cooldowns.keys():
		cooldowns[id] = maxi(0, cooldowns[id] - 1)


func to_save_data() -> Dictionary:
	return {"ids": ids.duplicate(), "cooldowns": cooldowns.duplicate()}


func from_save_data(d: Dictionary) -> void:
	ids.assign(d.get("ids", ids))
	cooldowns = d.get("cooldowns", {})
