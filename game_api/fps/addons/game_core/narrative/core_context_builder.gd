## Assembles the current game context and pushes it into an Ink story.
##
## Dialogue has to react to the whole situation, not just a prerequisite chain.
## That context is delivered two ways, deliberately:
##
## 1. **Ink variables** — a snapshot of slow-moving scalars (location, time of
##    day, stat bands, standing tier, npc identity). Cheap to read in
##    conditions, and readable inside text with `{location}`.
## 2. **External functions** (`CoreInkBindings`) — everything volatile.
##    Evaluated at the moment Ink asks, so an asset gained *mid-conversation*
##    is immediately visible to the next condition in the same scene.
##
## The split matters: a snapshot alone would go stale the instant a
## conversation changed anything, and functions alone would make simple text
## interpolation awkward. Mutating bindings call back into [method refresh] via
## [method watch], so even the snapshot half self-heals.
##
## Usage:
##   var ctx := CoreContextBuilder.new()
##   ctx.location = "round_room"
##   ctx.npc_id = "fence"
##   ctx.stat_bands = {"intellect": [["dull", 0], ["sharp", 12]]}
##   ctx.push(CoreInkEngine)
class_name CoreContextBuilder
extends RefCounted

## Pushed to Ink after a refresh, so a game can log/debug what the story sees.
signal context_pushed(values: Dictionary)

## Ink variable names this builder writes. A story need not declare all of them;
## `CoreInkEngine.var_set` silently skips names the story does not know, so one
## builder serves stories of very different complexity.
## Note `npc_id`, not `npc`: `npc` is a parameter name in the shared pattern
## library, and Ink forbids a global sharing a name with a knot argument.
const VARIABLES := [
	"location", "time_of_day", "npc_id", "npc_standing", "npc_standing_score",
	"turn",
]

var holder: String = "player"
## Where the conversation is happening. Free-form; games choose the vocabulary.
var location: String = ""
## Who it is with. Also used to resolve standing.
var npc_id: String = ""
## Optional place qualifier for standing lookups.
var place: String = ""

## Named bands for continuous stats, so writers compare words not numbers:
##   {"intellect": [["dull", 0], ["average", 8], ["sharp", 14]]}
## Produces an Ink variable per stat: `intellect_band`.
var stat_bands: Dictionary = {}

## Extra game-specific values pushed verbatim: {"ink_var_name": value}.
var extras: Dictionary = {}

var _engine: Node = null


## Push the snapshot into a loaded story. Safe to call repeatedly.
func push(engine: Node) -> Dictionary:
	_engine = engine
	var values := build()
	for key in values:
		engine.var_set(key, values[key])
	context_pushed.emit(values)
	return values


## Re-push the snapshot. Called automatically when a watched store mutates.
func refresh() -> void:
	if _engine != null and _engine.is_loaded():
		push(_engine)


## Keep the snapshot live for the duration of a conversation: any asset,
## knowledge or standing change re-pushes the variables. The external functions
## are already live, so this only exists to keep the two halves consistent.
func watch() -> void:
	_connect(CoreAssets.asset_gained)
	_connect(CoreAssets.asset_lost)
	_connect(CoreStanding.standing_changed)
	_connect(CoreKnowledge.learned)
	_connect(CoreKnowledge.forgotten)


## Stop watching. Call when the conversation ends.
func unwatch() -> void:
	_disconnect(CoreAssets.asset_gained)
	_disconnect(CoreAssets.asset_lost)
	_disconnect(CoreStanding.standing_changed)
	_disconnect(CoreKnowledge.learned)
	_disconnect(CoreKnowledge.forgotten)


## The context as a plain Dictionary — also what the simulation validator
## inspects and what a debug window can display.
func build() -> Dictionary:
	var values := {
		"location": location,
		"time_of_day": time_of_day(),
		"npc_id": npc_id,
		"npc_standing": CoreStanding.tier(npc_id, holder, place) if npc_id != "" else "",
		"npc_standing_score": CoreStanding.score(npc_id, holder, place) if npc_id != "" else 0.0,
		"turn": CoreContext.now(),
	}
	for stat_name in stat_bands:
		values["%s_band" % stat_name] = band_for(str(stat_name))
	for key in extras:
		values[str(key)] = extras[key]
	return values


## Current phase of day, from `game.json`'s `day_phases` via the engine clock.
## Games without a clock get "day" — never an error, because narrative should
## not break on an optional system.
func time_of_day() -> String:
	var phases = CoreContext.rule("day_phases", null)
	if not (phases is Dictionary) or phases.is_empty():
		return str(CoreContext.rule("default_time_of_day", "day"))
	var hour := fmod(maxf(CoreContext.now(), 0.0), 24.0)
	var best := ""
	var best_at := -1.0
	for phase in phases:
		var at := float(phases[phase])
		if hour >= at and at >= best_at:
			best = str(phase)
			best_at = at
	if best == "":
		# Before the first phase of the day: the last phase is still running.
		var latest := ""
		var latest_at := -1.0
		for phase in phases:
			if float(phases[phase]) > latest_at:
				latest_at = float(phases[phase])
				latest = str(phase)
		return latest
	return best


## The band name a stat currently falls in, "" when unbanded.
func band_for(stat_name: String) -> String:
	var bands = stat_bands.get(stat_name, [])
	if not (bands is Array) or bands.is_empty():
		return ""
	var stats := CoreContext.adapter.stats_of(holder)
	var value := stats.get_value(stat_name) if stats != null else 0.0
	var best := ""
	var best_at := -INF
	for band in bands:
		if not (band is Array) or band.size() < 2:
			continue
		var at := float(band[1])
		if value >= at and at >= best_at:
			best = str(band[0])
			best_at = at
	return best


func _connect(sig: Signal) -> void:
	if not sig.is_connected(_on_store_changed):
		sig.connect(_on_store_changed)


func _disconnect(sig: Signal) -> void:
	if sig.is_connected(_on_store_changed):
		sig.disconnect(_on_store_changed)


## Store signals carry different argument counts; this absorbs all of them.
func _on_store_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	refresh()
