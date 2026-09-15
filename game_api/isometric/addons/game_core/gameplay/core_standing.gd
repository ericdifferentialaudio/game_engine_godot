## Per-NPC standing: how a character feels about the holder.
##
## Registered as the `CoreStanding` autoload.
##
## **Why this is a third system.** Standing is neither knowledge (it is not
## boolean — it is a position on a scale) nor a physical asset (it cannot be
## handed to someone else, and spending it is a consequence, not a transaction).
## So it is its own lightweight tracked value: a signed score per subject, with
## named tiers layered on top.
##
## **This is a framework, not a ruleset.** The core supplies the score, the
## tiers, decay and persistence. Each game defines what the tiers are called,
## what they are worth, and what moves them — in `game.json`:
##
##   "rules": {
##     "standing": {
##       "min": -100, "max": 100,
##       "decay_per_unit_time": 0.0, "decay_grace": 10.0,
##       "tiers": [
##         {"id": "hostile",  "at": -50}, {"id": "wary",      "at": -10},
##         {"id": "neutral",  "at": 0},   {"id": "friendly",  "at": 20},
##         {"id": "trusted",  "at": 50},  {"id": "confidant", "at": 80}
##       ]
##     }
##   }
##
## Scope is per-subject, where a subject is normally an NPC id. A game that
## wants standing to be *place-specific* (the same fence regarded differently in
## two towns) passes a place: `CoreStanding.score("fence", "player", "round_room")`
## keys on "fence@round_room".
class_name CoreStandingStore
extends Node

## Standing with a subject changed. [param delta] is the applied change.
signal standing_changed(holder: String, subject: String, value: float, delta: float)
## Standing crossed into a different named tier.
signal tier_changed(holder: String, subject: String, tier: String, previous: String)

const DEFAULT_MIN := -100.0
const DEFAULT_MAX := 100.0
## Used only when a game defines no tiers at all, so `tier()` always answers.
const FALLBACK_TIERS := [
	{"id": "hostile", "at": -50.0},
	{"id": "unfriendly", "at": -20.0},
	{"id": "neutral", "at": 0.0},
	{"id": "friendly", "at": 25.0},
	{"id": "trusted", "at": 60.0},
]

var default_holder: String = "player"

## holder -> key -> {"value": float, "touched_at": float}
var _standings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
	_standings.clear()


# --- Queries ------------------------------------------------------------------

## Current standing score with a subject, decayed to "now" if the game decays.
func score(subject: String, holder: String = "", place: String = "") -> float:
	var entry := _entry(_holder(holder), _key(subject, place), false)
	if entry.is_empty():
		return 0.0
	return _decayed(entry)


## The named tier the score currently falls in ("neutral" when undefined).
func tier(subject: String, holder: String = "", place: String = "") -> String:
	return tier_for_score(score(subject, holder, place))


## Which tier a raw score would fall in. Exposed so validators and UI can label
## a hypothetical score without mutating anything.
func tier_for_score(value: float) -> String:
	var best := "neutral"
	var best_at := -INF
	for t in tiers():
		var at := float(t.get("at", 0.0))
		if value >= at and at >= best_at:
			best = str(t.get("id", "neutral"))
			best_at = at
	return best


## Is standing with this subject at least the named tier? This is the form
## dialogue gates should use — `at_least("fence", "trusted")` survives a game
## re-tuning its numbers, where a bare score comparison would not.
func at_least(subject: String, tier_id: String, holder: String = "", place: String = "") -> bool:
	var required := tier_threshold(tier_id)
	if is_inf(required):
		push_warning("CoreStanding: unknown tier '%s'" % tier_id)
		return false
	return score(subject, holder, place) >= required


## The score at which a named tier begins, or INF if the tier is not defined.
func tier_threshold(tier_id: String) -> float:
	for t in tiers():
		if str(t.get("id", "")) == tier_id:
			return float(t.get("at", 0.0))
	return INF


## The game's tier ladder, lowest first.
func tiers() -> Array:
	var configured = CoreContext.rule("standing.tiers", null)
	var list: Array = configured if configured is Array and not configured.is_empty() \
			else FALLBACK_TIERS
	var sorted := list.duplicate()
	sorted.sort_custom(func(a, b): return float(a.get("at", 0.0)) < float(b.get("at", 0.0)))
	return sorted


## Every subject this holder has any standing with.
func subjects(holder: String = "") -> Array[String]:
	var out: Array[String] = []
	for key in _standings.get(_holder(holder), {}):
		out.append(str(key))
	out.sort()
	return out


# --- Mutations ----------------------------------------------------------------

## Move standing by [param delta], clamped to the game's range.
## Returns the new score.
func adjust(subject: String, delta: float, holder: String = "", place: String = "") -> float:
	var who := _holder(holder)
	var key := _key(subject, place)
	var entry := _entry(who, key, true)
	var before := _decayed(entry)
	var before_tier := tier_for_score(before)
	var after := clampf(before + delta, min_score(), max_score())

	entry["value"] = after
	entry["touched_at"] = CoreContext.now()

	if not is_equal_approx(before, after):
		standing_changed.emit(who, key, after, after - before)
		var after_tier := tier_for_score(after)
		if after_tier != before_tier:
			tier_changed.emit(who, key, after_tier, before_tier)
	return after


## Set standing outright (introductions, scripted story states, tests).
func set_score(subject: String, value: float, holder: String = "", place: String = "") -> void:
	var current := score(subject, holder, place)
	adjust(subject, value - current, holder, place)


## Drop all standing with a subject back to unknown.
func clear_subject(subject: String, holder: String = "", place: String = "") -> void:
	var holder_map: Dictionary = _standings.get(_holder(holder), {})
	holder_map.erase(_key(subject, place))


func min_score() -> float:
	return float(CoreContext.rule("standing.min", DEFAULT_MIN))


func max_score() -> float:
	return float(CoreContext.rule("standing.max", DEFAULT_MAX))


# --- Persistence --------------------------------------------------------------

func to_save_data() -> Dictionary:
	return _standings.duplicate(true)


func from_save_data(d: Dictionary) -> void:
	_standings = d.duplicate(true)


# --- Internals ----------------------------------------------------------------

## Standing drifts back toward zero after a grace period of neglect, if the
## game asks for it. Decay is computed lazily on read so no ticking is required
## and the FPS/iso time-unit difference is irrelevant.
func _decayed(entry: Dictionary) -> float:
	var rate := float(CoreContext.rule("standing.decay_per_unit_time", 0.0))
	var value := float(entry.get("value", 0.0))
	if rate <= 0.0 or is_zero_approx(value):
		return value
	var grace := float(CoreContext.rule("standing.decay_grace", 0.0))
	var elapsed := CoreContext.now() - float(entry.get("touched_at", 0.0)) - grace
	if elapsed <= 0.0:
		return value
	var decay := rate * elapsed
	return maxf(value - decay, 0.0) if value > 0.0 else minf(value + decay, 0.0)


func _entry(holder: String, key: String, create: bool) -> Dictionary:
	if not _standings.has(holder):
		if not create:
			return {}
		_standings[holder] = {}
	var holder_map: Dictionary = _standings[holder]
	if not holder_map.has(key):
		if not create:
			return {}
		holder_map[key] = {"value": 0.0, "touched_at": CoreContext.now()}
	return holder_map[key]


func _key(subject: String, place: String) -> String:
	return subject if place == "" else "%s@%s" % [subject, place]


func _holder(holder: String) -> String:
	return holder if holder != "" else default_holder
