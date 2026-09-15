## Renderer-agnostic measurement of how *chaotic* a game package is.
##
## "Chaos" here is a precise, optimizable quantity: variance in outcome and
## experience ACROSS seeds, never irreproducibility within one. A seeded run
## must always replay identically (see `CoreContext.rng()`); what we want is
## for two different seeds -- or two slightly different player choices -- to
## diverge into genuinely different stories.
##
## Four tiers of chaos, ranked by interest-per-unit-of-unfairness:
##   1. Epistemic     -- the player's MODEL of the world is wrong, and findably so
##   2. Combinatorial -- structural draws that cascade (virtue draw, debt graph)
##   3. Social        -- conduct has visible, rumour-driven consequences
##   4. Mechanical    -- dice. Cheapest and least interesting; we CAP this.
##
## Used by the per-engine chaos harnesses, which feed it episode records and
## ask for a scorecard. Lives in core/ because both renderers need it.
class_name CoreChaosMetrics
extends RefCounted

## Weights per tier. Mechanical variance is deliberately weighted low -- raising
## combat randomness is not an achievement, it is noise.
const TIER_WEIGHTS := {
	"epistemic": 0.40,
	"combinatorial": 0.25,
	"social": 0.25,
	"mechanical": 0.10,
}

## A run whose competent-policy win rate drops below this is not "chaotic",
## it is broken. Gate, never a score component.
const DEFAULT_SOLVABILITY_FLOOR := 0.55


## Shannon entropy (base 2) over the frequency of values in `samples`,
## normalised to 0..1 against the maximum possible for that many distinct
## outcomes. 1.0 = every outcome equally likely; 0.0 = always the same result.
static func outcome_entropy(samples: Array) -> float:
	if samples.size() <= 1:
		return 0.0
	var counts := {}
	for s in samples:
		var key := str(s)
		counts[key] = int(counts.get(key, 0)) + 1
	if counts.size() <= 1:
		return 0.0
	var total := float(samples.size())
	var h := 0.0
	for key in counts:
		var p := float(counts[key]) / total
		if p > 0.0:
			h -= p * (log(p) / log(2.0))
	var max_h := log(float(counts.size())) / log(2.0)
	return 0.0 if max_h <= 0.0 else clampf(h / max_h, 0.0, 1.0)


## How far two runs drift apart. `a` and `b` are ordered state hashes sampled at
## the same checkpoints. Returns the fraction of checkpoints that differ, which
## is what "one different choice, a different story" actually looks like.
static func trajectory_divergence(a: Array, b: Array) -> float:
	var n: int = mini(a.size(), b.size())
	if n <= 0:
		return 0.0
	var differing := 0
	for i in range(n):
		if str(a[i]) != str(b[i]):
			differing += 1
	return float(differing) / float(n)


## Fraction of the reachable world actually touched across all episodes.
## Low coverage means the game funnels every player down one corridor.
static func state_coverage(visited: Array, reachable_total: int) -> float:
	if reachable_total <= 0:
		return 0.0
	var unique := {}
	for v in visited:
		unique[str(v)] = true
	return clampf(float(unique.size()) / float(reachable_total), 0.0, 1.0)


## Rewards a long tail of rare events. A game where the same three things happen
## every run scores near 0; one with many seldom-seen events scores high.
## `events` is a flat list of event ids observed across all episodes.
static func event_rarity_tail(events: Array, rare_threshold: float = 0.10) -> float:
	if events.is_empty():
		return 0.0
	var counts := {}
	for e in events:
		var key := str(e)
		counts[key] = int(counts.get(key, 0)) + 1
	if counts.size() <= 1:
		return 0.0
	var total := float(events.size())
	var rare := 0
	for key in counts:
		if (float(counts[key]) / total) <= rare_threshold:
			rare += 1
	return clampf(float(rare) / float(counts.size()), 0.0, 1.0)


## Epistemic chaos: how often the player held a belief that was wrong, AND how
## often that wrongness was discoverable. A lie nobody can catch is not chaos,
## it is a bug -- so we multiply by the refutation rate.
static func epistemic_score(false_beliefs_held: int, refutable: int, total_beliefs: int) -> float:
	if total_beliefs <= 0:
		return 0.0
	var wrongness := clampf(float(false_beliefs_held) / float(total_beliefs), 0.0, 1.0)
	var fairness := 1.0
	if false_beliefs_held > 0:
		fairness = clampf(float(refutable) / float(false_beliefs_held), 0.0, 1.0)
	return wrongness * fairness


## Combine tier subscores into one number. Input values are each 0..1.
static func weighted_score(tiers: Dictionary) -> float:
	var total := 0.0
	for tier in TIER_WEIGHTS:
		total += float(tiers.get(tier, 0.0)) * float(TIER_WEIGHTS[tier])
	return clampf(total, 0.0, 1.0)


## The full scorecard. `episodes` is an Array of Dictionaries produced by a
## chaos harness; see `chaos_harness.gd` in either engine for the shape:
##   { outcome: String, won: bool, visited: Array, events: Array,
##     false_beliefs_held: int, refutable_beliefs: int, total_beliefs: int,
##     deterministic: bool }
##
## Returns per-metric values, the weighted `score`, and a `gates` block.
## `passed` is true ONLY if every gate holds -- this is what stops
## "maximise chaos" from degenerating into "delete the win condition".
static func scorecard(episodes: Array, opts: Dictionary = {}) -> Dictionary:
	var floor_value := float(opts.get("solvability_floor", DEFAULT_SOLVABILITY_FLOOR))
	var reachable := int(opts.get("reachable_total", 0))

	var outcomes: Array = []
	var visited: Array = []
	var events: Array = []
	var wins := 0
	var false_held := 0
	var refutable := 0
	var beliefs := 0
	var deterministic := true

	for ep in episodes:
		if typeof(ep) != TYPE_DICTIONARY:
			continue
		outcomes.append(ep.get("outcome", "unknown"))
		if ep.get("won", false):
			wins += 1
		for v in ep.get("visited", []):
			visited.append(v)
		for e in ep.get("events", []):
			events.append(e)
		false_held += int(ep.get("false_beliefs_held", 0))
		refutable += int(ep.get("refutable_beliefs", 0))
		beliefs += int(ep.get("total_beliefs", 0))
		if not ep.get("deterministic", true):
			deterministic = false

	var n := maxi(episodes.size(), 1)
	var win_rate := float(wins) / float(n)

	var tiers := {
		"epistemic": epistemic_score(false_held, refutable, beliefs),
		"combinatorial": outcome_entropy(outcomes),
		"social": event_rarity_tail(events),
		"mechanical": state_coverage(visited, reachable),
	}

	var gates := {
		"solvable": win_rate >= floor_value,
		"deterministic": deterministic,
	}
	var all_gates_pass := true
	for g in gates.values():
		if not g:
			all_gates_pass = false

	return {
		"episodes": episodes.size(),
		"tiers": tiers,
		"score": weighted_score(tiers),
		"win_rate": win_rate,
		"solvability_floor": floor_value,
		"gates": gates,
		"passed": all_gates_pass,
	}
