## Shared goal-selection primitives for AI decision-making, engine-agnostic.
##
## Ported from Aevum: Age of Shrines (C:\Aevum\engine\engine_goals.py, 08/2026
## redesign) — kept the same model, translated to GDScript idioms.
##
## WHY THIS MODEL EXISTS
## ----------------------
## A naive argmax() goal-picker means a raw score of 1.0 always wins and any
## second-best option is dead code no matter how close it scored. Measured in
## Aevum: one goal scored a flat 1.000 and won every single turn; a goal at
## 8.2% of total intent (which should fire roughly 1 turn in 12) fired NEVER
## because it always lost the tie-break. Locking the winner in for N turns
## after that (a "commitment") then made it self-reinforcing.
##
## THE MODEL
## ---------
## Scores are normalized into a probability distribution summing to 1.0, and
## the goal is picked by roulette-wheel (cumulative-distribution) sampling:
##
##   goal A = 10%, goal B = 25%  ->  roll in [0.00,0.10) picks A
##                                   roll in [0.10,0.35) picks B
##
## Invariant: no goal is ever blocked unless its score is exactly 0.0. A zero
## is a hard veto (missing prerequisite, wrong unit type, already done) and
## stays a veto; every non-zero score keeps a strictly positive probability
## every turn.
##
## All sampling must draw from the shared seeded [method CoreContext.rng],
## never [RandomNumberGenerator.new()] ad hoc, so a seed reproduces a run
## exactly (see CoreContext.rng() -- "a seeded game replays identically in
## both engines").
class_name CoreGoalSelector
extends RefCounted

## Shaping exponent per decision level: p ~ score**k.
##   k=1   -> pure proportional (most varied)
##   k=2   -> favours strong goals, tails stay alive
##   k=3+  -> near-deterministic
## Faction/settlement-level intent should be decisive; per-unit autonomy
## benefits from more variety.
const K_FACTION: float = 2.0
const K_SETTLEMENT: float = 2.0
const K_UNIT: float = 1.5

## Scores at or below this are treated as noise and excluded from sampling.
## Deliberately small: the point of the model is that low-but-real options
## remain reachable.
const DEFAULT_FLOOR: float = 0.05

## A goal that just expired is damped for one selection so it cannot instantly
## re-win and re-lock (the classic "stuck on one goal for the whole game" bug).
const REPEAT_PENALTY: float = 0.5


## Turn raw scores into a probability distribution that sums to 1.0.
##
## Entries at or below [param score_floor], and all zeros/negatives, are
## dropped -- a 0.0 score is a hard veto, not a small chance. Returns {} when
## nothing is eligible.
static func normalize(scores: Dictionary, k: float = 1.0, score_floor: float = 0.0) -> Dictionary:
	var viable: Dictionary = {}
	for goal in scores:
		var s: float = float(scores[goal])
		if s > 0.0 and s > score_floor:
			viable[goal] = s
	if viable.is_empty():
		return {}
	var weights: Dictionary = {}
	var total := 0.0
	for goal in viable:
		var w: float = pow(viable[goal], k)
		weights[goal] = w
		total += w
	if total <= 0.0:
		return {}
	var dist: Dictionary = {}
	for goal in weights:
		dist[goal] = weights[goal] / total
	return dist


## Roulette-wheel selection over [param scores].
##
## Walks the cumulative distribution and returns the first goal whose running
## total exceeds a single random roll, so each goal is chosen with
## probability proportional to its normalized weight. Returns "" if nothing
## is eligible (every score was <= score_floor / a veto).
static func select_weighted(scores: Dictionary, rng: RandomNumberGenerator, k: float = 1.0, score_floor: float = 0.0) -> String:
	var dist := normalize(scores, k, score_floor)
	if dist.is_empty():
		return ""
	var goals: Array = dist.keys()
	goals.sort()  # deterministic ordering, independent of Dictionary iteration order
	var roll := rng.randf()
	var cumulative := 0.0
	for goal in goals:
		cumulative += float(dist[goal])
		if roll < cumulative:
			return str(goal)
	return str(goals[-1])  # float-rounding guard


## Damp the goal that just finished its commitment, so a holder that spent
## many turns on one goal does not immediately re-pick it.
static func apply_repeat_penalty(scores: Dictionary, just_expired: String) -> Dictionary:
	if just_expired == "" or not scores.has(just_expired):
		return scores
	var out := scores.duplicate()
	out[just_expired] = float(out[just_expired]) * REPEAT_PENALTY
	return out


## Randomized commitment duration in turns.
##
## A fixed duration makes behaviour metronomic and predictable; a rolled
## range gives variability. [param scale] applies per-holder temperament
## (steady holders commit longer, opportunists shorter).
static func roll_commitment(rng: RandomNumberGenerator, lo: int, hi: int, scale: float = 1.0) -> int:
	var lo_s: int = maxi(1, int(round(lo * scale)))
	var hi_s: int = maxi(lo_s, int(round(hi * scale)))
	return rng.randi_range(lo_s, hi_s)


## Multiplier that makes a goal more attractive the closer its target is.
##
## prox = max(0, 1 - distance/radius), returned as (1 + prox*weight), so it
## amplifies an already-valid score and can never resurrect a 0.0 veto.
##
## This is what lets an agent finish a trip: a goal 11 tiles from its target
## scores x1.05, but after walking to 3 tiles away it scores x1.45, so when
## its commitment expires the goal usually re-wins instead of being abandoned
## a few tiles short of the objective.
static func proximity_bonus(distance: float, radius: float, weight: float) -> float:
	if radius <= 0.0:
		return 1.0
	var prox: float = maxf(0.0, 1.0 - (distance / radius))
	return 1.0 + prox * weight


## Suppress a goal that was recently achieved, decaying back to full strength.
##
## At [code]remaining == duration[/code] the score is multiplied by
## [code]1 - depth[/code]; the multiplier rises linearly to 1.0 as the
## cooldown ticks away. Keeps an agent that just finished a goal from
## instantly repeating it.
static func apply_cooldown(score: float, remaining: int, duration: int, depth: float = 0.8) -> float:
	if remaining <= 0 or duration <= 0:
		return score
	var frac: float = minf(1.0, float(remaining) / float(duration))
	return score * maxf(0.0, 1.0 - frac * depth)


# --- Cooldown table helpers ----------------------------------------------------
## GDScript has no equivalent of Python's getattr()/setattr() on an arbitrary
## object, so cooldowns are kept in a plain Dictionary the caller owns
## (e.g. a field on a save-scoped holder record: `goal_cooldowns: Dictionary`).

## Remaining cooldown turns for [param goal] (0 if none).
static func get_cooldown(cooldowns: Dictionary, goal: String) -> int:
	return int(cooldowns.get(goal, 0))


## Start (or extend) a post-achievement cooldown for [param goal].
static func set_cooldown(cooldowns: Dictionary, goal: String, turns: int) -> void:
	if turns <= 0 or goal == "":
		return
	cooldowns[goal] = maxi(int(cooldowns.get(goal, 0)), turns)


## Decrement every cooldown by one turn and drop the expired entries.
static func tick_cooldowns(cooldowns: Dictionary) -> void:
	for goal in cooldowns.keys():
		var remaining: int = int(cooldowns[goal]) - 1
		if remaining <= 0:
			cooldowns.erase(goal)
		else:
			cooldowns[goal] = remaining
