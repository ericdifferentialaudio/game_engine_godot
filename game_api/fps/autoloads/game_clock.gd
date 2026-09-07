## Game-time clock. Everything time-based in the framework (intel expiry, NPC
## schedules, status-effect durations, world events) uses game seconds from
## [method now], never wall-clock time, so saves and pausing behave correctly.
##
## Configured from game.json:
##   "time_scale": 60.0          game seconds per real second (60 => 1 real min = 1 game hour)
##   "start_time": 8.0           starting hour of day 1
##   "day_phases": {"dawn": 5, "day": 7, "dusk": 18, "night": 20}   hour boundaries
extends Node

const SECONDS_PER_DAY := 86400.0
const DEFAULT_PHASES := {"dawn": 5.0, "day": 7.0, "dusk": 18.0, "night": 20.0}

var time_scale: float = 60.0
var running: bool = true
var phases: Dictionary = DEFAULT_PHASES.duplicate()

var _elapsed: float = 0.0            ## Game seconds since day 1, 00:00.
var _last_hour: int = -1
var _last_day: int = -1
var _last_phase: String = ""
var _timers: Array[Dictionary] = []  ## {id, at, callable, repeat}
var _next_timer_id: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func configure(cfg: Dictionary) -> void:
	time_scale = float(cfg.get("time_scale", 60.0))
	var start_hour := float(cfg.get("start_time", 8.0))
	_elapsed = start_hour * 3600.0
	var p: Dictionary = cfg.get("day_phases", {})
	for k in DEFAULT_PHASES:
		phases[k] = float(p.get(k, DEFAULT_PHASES[k]))
	_timers.clear()
	_last_hour = -1
	_last_day = -1
	_last_phase = ""
	_emit_changes()


func _process(delta: float) -> void:
	if not running:
		return
	advance(delta * time_scale)


## Advance by game seconds (also used by tests and sleeping/waiting).
func advance(game_seconds: float) -> void:
	if game_seconds <= 0.0:
		return
	_elapsed += game_seconds
	_fire_timers()
	_emit_changes()


# --- Queries -----------------------------------------------------------------

func now() -> float:
	return _elapsed


func day() -> int:
	return int(_elapsed / SECONDS_PER_DAY) + 1


func hour() -> int:
	return int(fmod(_elapsed, SECONDS_PER_DAY) / 3600.0)


func minute() -> int:
	return int(fmod(_elapsed, 3600.0) / 60.0)


## Fractional hour of day, 0..24.
func hour_of_day() -> float:
	return fmod(_elapsed, SECONDS_PER_DAY) / 3600.0


func day_phase() -> String:
	var h := hour_of_day()
	if h >= phases["night"] or h < phases["dawn"]:
		return "night"
	if h >= phases["dusk"]:
		return "dusk"
	if h >= phases["day"]:
		return "day"
	return "dawn"


func is_between_hours(start_h: float, end_h: float) -> bool:
	var h := hour_of_day()
	if start_h <= end_h:
		return h >= start_h and h < end_h
	return h >= start_h or h < end_h  # wraps midnight


func format_time() -> String:
	return "Day %d, %02d:%02d" % [day(), hour(), minute()]


## Game seconds until the next occurrence of [param hour_h] (0..24).
func seconds_until_hour(hour_h: float) -> float:
	var target := hour_h * 3600.0
	var today := fmod(_elapsed, SECONDS_PER_DAY)
	var diff := target - today
	if diff <= 0.0:
		diff += SECONDS_PER_DAY
	return diff


# --- Scheduling --------------------------------------------------------------

func schedule_in(game_seconds: float, callable: Callable, repeat: bool = false) -> int:
	var id := _next_timer_id
	_next_timer_id += 1
	_timers.append({"id": id, "at": _elapsed + game_seconds, "callable": callable,
		"interval": game_seconds if repeat else 0.0})
	return id


func schedule_at_hour(hour_h: float, callable: Callable, daily: bool = false) -> int:
	var id := schedule_in(seconds_until_hour(hour_h), callable)
	if daily:
		_timers[-1]["interval"] = SECONDS_PER_DAY
	return id


func cancel(timer_id: int) -> void:
	for i in range(_timers.size() - 1, -1, -1):
		if _timers[i]["id"] == timer_id:
			_timers.remove_at(i)


func _fire_timers() -> void:
	var i := 0
	while i < _timers.size():
		var t := _timers[i]
		if t["at"] <= _elapsed:
			var c: Callable = t["callable"]
			if c.is_valid():
				c.call()
			if t["interval"] > 0.0 and c.is_valid():
				t["at"] += t["interval"]
				i += 1
			else:
				_timers.remove_at(i)
		else:
			i += 1


func _emit_changes() -> void:
	var h := hour()
	var d := day()
	var p := day_phase()
	if h != _last_hour:
		_last_hour = h
		EventBus.hour_changed.emit(h)
	if d != _last_day:
		_last_day = d
		EventBus.day_changed.emit(d)
	if p != _last_phase:
		_last_phase = p
		EventBus.day_phase_changed.emit(p)


# --- Serialisation -----------------------------------------------------------

func to_save_data() -> Dictionary:
	return {"elapsed": _elapsed, "time_scale": time_scale}


func from_save_data(d: Dictionary) -> void:
	_elapsed = float(d.get("elapsed", _elapsed))
	time_scale = float(d.get("time_scale", time_scale))
	_timers.clear()  # Systems re-register schedules on load.
	_last_hour = -1
	_last_day = -1
	_last_phase = ""
	_emit_changes()
