## Forces a fight, then runs follow-up interactions on the outcome.
##
##   {"kind": "combat", "target": "nearest_enemy"|"guardian",
##    "guardian": {"unit": "bone_warden", "faction": "monsters"},
##    "on_victory": [{"kind": "reward", "items": {"ancient_relic": 1}}],
##    "on_defeat":  [{"kind": "flag", "set_flags": ["fled_the_ossuary"]}],
##    "once": true}
##
## Resolution differs fundamentally between the engines (turn-based strength
## ratio vs. real-time damage), so it is delegated. The *consequences* are
## shared, which is the point.
class_name CoreCombatInteraction
extends CoreInteraction

signal resolved(holder: String, result: Dictionary)


func _on_setup() -> void:
	kind = "combat"


func _execute(holder: String, actor, target) -> void:
	var result := CoreContext.adapter.resolve_combat(holder, spec, actor, target)
	if result.is_empty():
		return
	resolved.emit(holder, result)

	var won := bool(result.get("victory", result.get("defender_died", false)))
	var follow_up: Array = spec.get("on_victory" if won else "on_defeat", [])
	for sub_spec in follow_up:
		if not (sub_spec is Dictionary):
			continue
		var inter := CoreInteractionFactory.create(sub_spec, owner_id)
		if inter:
			inter.run(holder, actor, target)
