## Turn structure and turn-order authority.
##
## Modes (game.json "turns.mode"):
##   sequential      – classic Civ: factions act one after another; each commits.
##   simultaneous    – all factions act in the same ACTIONS phase; turn ends when
##                     every faction commits (or the optional timer expires).
##   wego            – like simultaneous but orders are queued and resolved in
##                     RESOLVE (units expose queue_order()/execute_orders()).
##   realtime_pause  – GameClock ticks continuously; every ticks_per_turn ticks a
##                     turn boundary fires. Space toggles pause.
##
## Every turn walks the phases BEGIN → UPKEEP → ACTIONS → RESOLVE → END and
## emits EventBus.turn_phase_changed for each so systems (yields, intel decay,
## spread, statuses, AI) hook the phase they care about without ordering bugs.
extends Node

enum Mode { SEQUENTIAL, SIMULTANEOUS, WEGO, REALTIME_PAUSE }
enum Phase { IDLE, BEGIN, UPKEEP, ACTIONS, RESOLVE, END }

const MODE_NAMES := {
	"sequential": Mode.SEQUENTIAL, "simultaneous": Mode.SIMULTANEOUS,
	"wego": Mode.WEGO, "realtime_pause": Mode.REALTIME_PAUSE,
}

var mode: Mode = Mode.SEQUENTIAL
var phase: Phase = Phase.IDLE
var timer_seconds: float = 0.0          ## 0 = no timer (simultaneous/wego).
var active_faction_id: String = ""      ## Sequential mode only.
var turn_order: Array[String] = []
var committed: Dictionary = {}          ## faction_id -> bool for this turn
var running: bool = false

var _timer_left: float = 0.0
var _turn_ending: bool = false


func configure(turns: Dictionary) -> void:
	mode = MODE_NAMES.get(str(turns.get("mode", "sequential")).to_lower(), Mode.SEQUENTIAL)
	timer_seconds = float(turns.get("timer_seconds", 0.0))


func mode_name() -> String:
	return Mode.keys()[mode].to_lower()


func phase_name() -> String:
	return Phase.keys()[phase].to_lower()


## Begin the first turn. Called by GameManager.start_new_game().
func start() -> void:
	running = true
	turn_order.assign(FactionRegistry.turn_order())
	_begin_turn()


func stop() -> void:
	running = false
	phase = Phase.IDLE


# --- Turn flow ------------------------------------------------------------------

func _begin_turn() -> void:
	GameClock.advance_turn()
	committed.clear()
	for f in turn_order:
		committed[f] = false
	_turn_ending = false
	_set_phase(Phase.BEGIN)
	EventBus.turn_started.emit(GameClock.turn)
	_set_phase(Phase.UPKEEP)
	_set_phase(Phase.ACTIONS)
	_timer_left = timer_seconds
	match mode:
		Mode.SEQUENTIAL:
			_activate_faction(0)
		Mode.REALTIME_PAUSE:
			# Clock drives the boundary; AI acts during ticks.
			active_faction_id = ""
			_run_ai_for_all()
		_:
			active_faction_id = ""
			_run_ai_for_all()


func _activate_faction(index: int) -> void:
	if index >= turn_order.size():
		_end_turn()
		return
	active_faction_id = turn_order[index]
	var faction := FactionRegistry.get_faction(active_faction_id)
	if faction == null or faction.eliminated:
		committed[active_faction_id] = true
		_activate_faction(index + 1)
		return
	EventBus.active_faction_changed.emit(active_faction_id)
	if not faction.is_human:
		faction.run_ai_turn()
		commit_faction(active_faction_id)


func _run_ai_for_all() -> void:
	for fid in turn_order:
		var f := FactionRegistry.get_faction(fid)
		if f and not f.is_human and not f.eliminated:
			f.run_ai_turn()
			commit_faction(fid)


## A faction declares it is done for this turn (End Turn button / AI finished).
func commit_faction(faction_id: String) -> void:
	if not running or phase != Phase.ACTIONS or not committed.has(faction_id):
		return
	if committed[faction_id]:
		return
	committed[faction_id] = true
	EventBus.faction_turn_committed.emit(faction_id, GameClock.turn)
	match mode:
		Mode.SEQUENTIAL:
			_activate_faction(turn_order.find(faction_id) + 1)
		Mode.REALTIME_PAUSE:
			pass  # Clock decides.
		_:
			if _all_committed():
				_end_turn()


func request_turn_end_from_clock() -> void:
	if mode == Mode.REALTIME_PAUSE and phase == Phase.ACTIONS:
		_end_turn()


## Force the turn to end regardless of commits (debug / timer expiry).
func force_end_turn() -> void:
	if running and phase == Phase.ACTIONS:
		_end_turn()


func _all_committed() -> bool:
	for f in committed:
		if not committed[f]:
			return false
	return true


func _end_turn() -> void:
	if _turn_ending:
		return
	_turn_ending = true
	_set_phase(Phase.RESOLVE)
	_set_phase(Phase.END)
	EventBus.turn_ended.emit(GameClock.turn)
	if running and GameManager.state != GameManager.State.GAME_OVER:
		call_deferred("_begin_turn")


func _set_phase(p: Phase) -> void:
	phase = p
	EventBus.turn_phase_changed.emit(GameClock.turn, phase)


func is_faction_active(faction_id: String) -> bool:
	if not running or phase != Phase.ACTIONS:
		return false
	if mode == Mode.SEQUENTIAL:
		return active_faction_id == faction_id
	return not committed.get(faction_id, true)


func _process(delta: float) -> void:
	if not running or phase != Phase.ACTIONS or timer_seconds <= 0.0:
		return
	if mode in [Mode.SIMULTANEOUS, Mode.WEGO] and GameManager.state == GameManager.State.PLAYING:
		_timer_left -= delta
		if _timer_left <= 0.0:
			_end_turn()


func time_left() -> float:
	return _timer_left if timer_seconds > 0.0 else -1.0


func to_save_data() -> Dictionary:
	return {"active": active_faction_id, "order": turn_order.duplicate(), "committed": committed.duplicate()}


func from_save_data(d: Dictionary) -> void:
	turn_order.assign(d.get("order", FactionRegistry.turn_order()))
	committed = d.get("committed", {})
	active_faction_id = d.get("active", "")
	running = true
	_turn_ending = false
	phase = Phase.ACTIONS
