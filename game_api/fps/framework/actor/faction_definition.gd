## Faction data (factions.json): who hates whom, and player standing thresholds.
##
##   {"id": "townsfolk", "relations": {"crypt_undead": "hostile", "bandits": "hostile"},
##    "default_relation": "neutral", "player_reputation": 0,
##    "reputation_thresholds": {"hostile": -50, "unfriendly": -10, "friendly": 25, "allied": 75}}
class_name FactionDefinition
extends Definition

enum Relation { HOSTILE, UNFRIENDLY, NEUTRAL, FRIENDLY, ALLIED }
const RELATION_NAMES := {"hostile": Relation.HOSTILE, "unfriendly": Relation.UNFRIENDLY,
	"neutral": Relation.NEUTRAL, "friendly": Relation.FRIENDLY, "allied": Relation.ALLIED}

@export var relations: Dictionary = {}            ## faction_id -> relation name
@export var default_relation: Relation = Relation.NEUTRAL
@export var starting_reputation: int = 0
@export var reputation_thresholds: Dictionary = {"hostile": -50, "unfriendly": -10, "friendly": 25, "allied": 75}
@export var attack_on_sight_below: Relation = Relation.HOSTILE
@export var price_modifiers: Dictionary = {}      ## relation name -> multiplier, e.g. {"friendly": 0.9}


func _apply(d: Dictionary) -> void:
	relations = d.get("relations", {})
	default_relation = RELATION_NAMES.get(str(d.get("default_relation", "neutral")), Relation.NEUTRAL)
	starting_reputation = int(d.get("player_reputation", 0))
	var th: Dictionary = d.get("reputation_thresholds", {})
	for k in reputation_thresholds.keys():
		reputation_thresholds[k] = int(th.get(k, reputation_thresholds[k]))
	attack_on_sight_below = RELATION_NAMES.get(str(d.get("attack_on_sight_below", "hostile")), Relation.HOSTILE)
	price_modifiers = d.get("price_modifiers", {})


func relation_to(other_faction: String) -> Relation:
	if other_faction == id:
		return Relation.ALLIED
	return RELATION_NAMES.get(str(relations.get(other_faction, "")), default_relation)


## Relation towards the player derived from reputation.
func relation_from_reputation(rep: int) -> Relation:
	if rep <= int(reputation_thresholds["hostile"]):
		return Relation.HOSTILE
	if rep <= int(reputation_thresholds["unfriendly"]):
		return Relation.UNFRIENDLY
	if rep >= int(reputation_thresholds["allied"]):
		return Relation.ALLIED
	if rep >= int(reputation_thresholds["friendly"]):
		return Relation.FRIENDLY
	return Relation.NEUTRAL


static func relation_name(r: Relation) -> String:
	return Relation.keys()[r].to_lower()
