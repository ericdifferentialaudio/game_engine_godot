## Sets/clears progression flags and quest stages, and can change diplomacy.
##
##   {"kind": "flag", "set_flags": ["bridge_repaired"], "clear_flags": [],
##    "set_holder_flags": ["met_elders"],
##    "quest": {"id": "find_crypt", "stage": "located"},
##    "stance": {"with": "greywood", "stance": "friendly"}}
##
## Quests are represented as stage flags — "quest.<id>.<stage>" — so a game
## needs no quest subsystem to track progress, but may layer one on by
## listening for [signal CoreQuests.stage_reached].
class_name CoreFlagInteraction
extends CoreInteraction


func _on_setup() -> void:
	kind = "flag"


func _execute(holder: String, _actor, _target) -> void:
	for f in spec.get("set_flags", []):
		CoreContext.set_flag(str(f), true)
	for f in spec.get("clear_flags", []):
		CoreContext.set_flag(str(f), false)

	for f in spec.get("set_holder_flags", spec.get("set_faction_flags", [])):
		CoreContext.set_holder_flag(holder, str(f), true)

	if spec.has("quest"):
		var q: Dictionary = spec["quest"]
		CoreContext.set_quest_stage(str(q.get("id", "")), str(q.get("stage", "")), holder)

	if spec.has("stance"):
		var s: Dictionary = spec["stance"]
		CoreContext.adapter.set_stance(holder, str(s.get("with", "")),
			str(s.get("stance", "neutral")))
