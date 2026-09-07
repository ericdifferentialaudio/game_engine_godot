## Game-time authority: turn counter, calendar labels, eras, and ticks for
## time-based modes. All expiry/decay in the engine (intel, statuses) is
## measured in *turns* via [method now], never wall-clock time.
##
## calendar (game.json):
##   {"start_year": -4000, "years_per_turn": 40, "year_suffix_neg": "BC", "year_suffix_pos": "AD",
##    "eras": [{"id": "ancient", "label": "Ancient Era", "from_turn": 1}, {"id": "classical", "from_turn": 60}]}
## turns (game.json):
##   {"mode": "realtime_pause", "ticks_per_turn": 10, "seconds_per_tick": 1.0}
extends Node

var turn: int = 0
var tick: int = 0                       ## Ticks within the current turn (time-based modes).
var ticks_per_turn: int = 10
var seconds_per_tick: float = 1.0
var paused: bool = true                 ## Real-time modes start paused.
var current_era: String = ""

var _calendar: Dictionary = {}
var _accum: float = 0.0
var _realtime: bool = false


func configure(calendar: Dictionary, turns: Dictionary) -> void:
	_calendar = calendar
	ticks_per_turn = maxi(1, int(turns.get("ticks_per_turn", 10)))
	seconds_per_tick = maxf(0.05, float(turns.get("seconds_per_tick", 1.0)))
	_realtime = turns.get("mode", "sequential") == "realtime_pause"


func reset() -> void:
	turn = 0
	tick = 0
	_accum = 0.0
	paused = true
	current_era = ""


## The current absolute time in turns (fractional in time-based modes).
func now() -> float:
	return float(turn) + float(tick) / float(ticks_per_turn)


func advance_turn() -> void:
	turn += 1
	tick = 0
	_update_era()


func year_label() -> String:
	var start := int(_calendar.get("start_year", 1))
	var ypt := int(_calendar.get("years_per_turn", 1))
	var year := start + (turn - 1) * ypt
	if year < 0:
		return "%d %s" % [-year, _calendar.get("year_suffix_neg", "BC")]
	return "%d %s" % [year, _calendar.get("year_suffix_pos", "AD")]


func era_label() -> String:
	for e in _calendar.get("eras", []):
		if e.get("id", "") == current_era:
			return e.get("label", current_era.capitalize())
	return current_era.capitalize()


func toggle_paused() -> void:
	set_paused(not paused)


func set_paused(p: bool) -> void:
	if paused == p:
		return
	paused = p
	EventBus.clock_paused.emit(paused)


func _process(delta: float) -> void:
	if not _realtime or paused or GameManager.state != GameManager.State.PLAYING:
		return
	_accum += delta
	while _accum >= seconds_per_tick:
		_accum -= seconds_per_tick
		tick += 1
		EventBus.clock_tick.emit(tick, 1)
		if tick >= ticks_per_turn:
			TurnManager.request_turn_end_from_clock()
			return


func _update_era() -> void:
	var best := ""
	for e in _calendar.get("eras", []):
		if turn >= int(e.get("from_turn", 1)):
			best = e.get("id", "")
	if best != current_era:
		current_era = best
		EventBus.era_changed.emit(current_era)


func to_save_data() -> Dictionary:
	return {"turn": turn, "tick": tick, "era": current_era}


func from_save_data(d: Dictionary) -> void:
	turn = int(d.get("turn", 0))
	tick = int(d.get("tick", 0))
	current_era = d.get("era", "")
	paused = true
