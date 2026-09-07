## Faction membership and hostility checks. Player reputation with factions is
## stored globally in GameManager.reputation so it persists across actors.
class_name Faction
extends ActorComponent

var faction_id: String = "neutral"
var personal_hostiles: Array[String] = []   ## actor uids this actor hates regardless of faction (M3: memory)


func _definition_applied(def: ActorDefinition) -> void:
	faction_id = def.faction_id


func definition() -> FactionDefinition:
	return DefinitionRegistry.get_def("factions", faction_id) as FactionDefinition


## Relation from this actor's faction toward [param other].
func relation_to(other: Actor) -> FactionDefinition.Relation:
	if other == null:
		return FactionDefinition.Relation.NEUTRAL
	if other.actor_uid in personal_hostiles:
		return FactionDefinition.Relation.HOSTILE
	var def := definition()
	if def == null:
		return FactionDefinition.Relation.NEUTRAL
	if other.is_player():
		return def.relation_from_reputation(GameManager.get_reputation(faction_id))
	var other_faction := other.faction.faction_id if other.faction else "neutral"
	return def.relation_to(other_faction)


func is_hostile_to(other: Actor) -> bool:
	var def := definition()
	var threshold := def.attack_on_sight_below if def else FactionDefinition.Relation.HOSTILE
	return relation_to(other) <= threshold


func is_friendly_to(other: Actor) -> bool:
	return relation_to(other) >= FactionDefinition.Relation.FRIENDLY


func make_personal_enemy(other: Actor) -> void:
	if other and other.actor_uid not in personal_hostiles:
		personal_hostiles.append(other.actor_uid)


func to_save_data() -> Dictionary:
	return {"faction": faction_id, "hostiles": personal_hostiles}


func from_save_data(d: Dictionary) -> void:
	faction_id = str(d.get("faction", faction_id))
	personal_hostiles.assign(d.get("hostiles", []))
