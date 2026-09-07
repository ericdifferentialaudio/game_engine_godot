extends Node
## Autoload: AIHeuristicManager
## Shared AI goal-selection: weighted/roulette-wheel choice over a raw score
## dictionary, using [CoreGoalSelector] (ported from Aevum: Age of Shrines'
## engine_goals.py). Kept engine-agnostic: this node must never reference
## isometric- or fps-specific scene nodes directly.
##
## [param context] passed to [method evaluate] is a raw score Dictionary,
## action name (String/StringName) -> float score. A 0.0 (or absent) score is
## a hard veto; everything else keeps a strictly positive chance of being
## picked, weighted by [param k] (see CoreGoalSelector's model doc).
##
## Per-agent cooldown/commitment state is kept in [member _cooldowns] and
## [member _commitments], keyed by agent_id, since GDScript has no
## getattr()/setattr() equivalent for arbitrary caller objects.

signal heuristic_evaluated(agent_id: StringName, chosen_action: StringName)

var _cooldowns: Dictionary = {}     ## agent_id -> {action -> remaining_turns}
var _commitments: Dictionary = {}   ## agent_id -> currently committed action


## Evaluate a raw score dictionary and pick one action by weighted roulette.
## Returns &"idle" when nothing scores above the floor (all vetoed/empty).
func evaluate(agent_id: StringName, context: Dictionary, k: float = CoreGoalSelector.K_UNIT,
		score_floor: float = CoreGoalSelector.DEFAULT_FLOOR) -> StringName:
	var scores: Dictionary = context.duplicate()
	var just_expired: String = str(_commitments.get(agent_id, ""))
	if just_expired != "":
		scores = CoreGoalSelector.apply_repeat_penalty(scores, just_expired)

	var picked := CoreGoalSelector.select_weighted(scores, CoreContext.rng(), k, score_floor)
	var chosen_action: StringName = StringName(picked) if picked != "" else &"idle"

	_commitments[agent_id] = str(chosen_action) if chosen_action != &"idle" else ""
	heuristic_evaluated.emit(agent_id, chosen_action)
	return chosen_action


## Remaining cooldown turns for [param action] on [param agent_id].
func cooldown_for(agent_id: StringName, action: String) -> int:
	return CoreGoalSelector.get_cooldown(_cooldowns.get(agent_id, {}), action)


## Start (or extend) a post-achievement cooldown for [param action].
func set_cooldown(agent_id: StringName, action: String, turns: int) -> void:
	if not _cooldowns.has(agent_id):
		_cooldowns[agent_id] = {}
	CoreGoalSelector.set_cooldown(_cooldowns[agent_id], action, turns)


## Tick every cooldown for [param agent_id] down by one turn.
func tick_cooldowns(agent_id: StringName) -> void:
	if _cooldowns.has(agent_id):
		CoreGoalSelector.tick_cooldowns(_cooldowns[agent_id])


## Clear all per-agent state (cooldowns, commitments). Call on run reset.
func reset() -> void:
	_cooldowns.clear()
	_commitments.clear()
