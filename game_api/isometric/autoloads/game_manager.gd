## Top-level game state machine and entry point for a "game package".
##
## A game package lives in res://games/<game_id>/ and is described by game.json.
## GameManager loads the package, hands each data file to the owning registry,
## and drives the high-level state (menu / playing / paused / dialogue / journal).
##
## game.json (key fields):
##   id, title, version, description
##   grid:        {"topology": "hex"|"square_iso", "orientation": "pointy"|"flat", "tile_size": [w,h], "wrap_x": bool}
##   turns:       {"mode": "sequential"|"simultaneous"|"wego"|"realtime_pause", "timer_seconds": 0, "ticks_per_turn": 10}
##   calendar:    {"start_year": -4000, "years_per_turn": 40, "eras": [{"id":"ancient","from_turn":1}, ...]}
##   start_map:   map id from maps.json
##   player_faction: faction id controlled by the local human
##   rules:       free-form game rules dictionary (combat, fog, intel_spread...)
##   currencies:  ["gold", ...]  resources tracked per faction
##   stats:       default stat block for units without their own
##   max_map_depth: site descent limit
extends Node

enum State { BOOT, MAIN_MENU, LOADING, PLAYING, PAUSED, DIALOGUE, JOURNAL, GAME_OVER }

const GAMES_ROOT := "res://games/"
const DATA_FILES := ["game", "terrains", "maps", "units", "items", "factions", "intel", "intel_rules", "sites", "assets", "ai_profiles"]

var state: State = State.BOOT
var game_id: String = ""
var game_config: Dictionary = {}
var flags: Dictionary = {}                 ## Arbitrary bool progression flags (global).
var player_faction_id: String = ""
var smoke_mode: bool = false               ## Set by main.gd when run with --smoke.

var _previous_state: State = State.BOOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func package_path(id: String = game_id) -> String:
	return GAMES_ROOT.path_join(id)


func data_path(file: String, id: String = game_id) -> String:
	return package_path(id).path_join("%s.json" % file)


## Load a game package by id (folder name under res://games/).
func load_game(id: String) -> bool:
	var cfg := DataLoader.load_json(data_path("game", id))
	if cfg.is_empty():
		push_error("GameManager: could not load game package '%s'" % id)
		return false
	game_id = id
	game_config = cfg
	player_faction_id = cfg.get("player_faction", "")
	set_state(State.LOADING)

	# Shared platform: rules/seed, then the engine-agnostic definitions
	# (items, units, intel, factions) that game_core systems read.
	CoreContext.configure(cfg)
	CoreRegistry.load_package(package_path(id))
	CoreIntel.load_rules(data_path("intel_rules"))

	AssetRegistry.load_manifest(data_path("assets"))
	ItemRegistry.load_definitions(data_path("items"))
	IntelRegistry.load_definitions(data_path("intel"), data_path("intel_rules"))
	FactionRegistry.load_definitions(data_path("factions"))
	EntityRegistry.load_definitions(data_path("units"), data_path("ai_profiles"))
	WorldManager.configure(cfg.get("grid", {}), int(cfg.get("max_map_depth", WorldManager.DEFAULT_MAX_DEPTH)))
	WorldManager.load_definitions(data_path("terrains"), data_path("maps"), data_path("sites"))
	GameClock.configure(cfg.get("calendar", {}), cfg.get("turns", {}))
	TurnManager.configure(cfg.get("turns", {}))
	return true


## Start a fresh run of the loaded package.
func start_new_game(seed_override: int = -1) -> void:
	flags.clear()
	CoreContext.reset()
	CoreIntel.reset()
	IntelRegistry.reset_journals()
	FactionRegistry.reset()
	EntityRegistry.reset()
	GameClock.reset()
	var seed_val := seed_override if seed_override >= 0 else int(game_config.get("seed", randi() % 1_000_000))
	WorldManager.enter_root_map(game_config.get("start_map", ""), seed_val)
	FactionRegistry.instantiate_all()
	WorldManager.place_starting_entities()
	set_state(State.PLAYING)
	EventBus.game_started.emit(game_id)
	TurnManager.start()


## Rule lookup with dotted path, e.g. rule("combat.randomness", 0.2).
func rule(path: String, default = null):
	var node = game_config.get("rules", {})
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return default
	return node


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	_previous_state = state
	state = new_state
	get_tree().paused = state in [State.PAUSED, State.JOURNAL, State.DIALOGUE]
	EventBus.game_state_changed.emit(_previous_state, state)


func toggle_pause() -> void:
	if state == State.PLAYING:
		set_state(State.PAUSED)
	elif state == State.PAUSED:
		set_state(State.PLAYING)


func toggle_journal() -> void:
	if state == State.PLAYING:
		set_state(State.JOURNAL)
	elif state == State.JOURNAL:
		set_state(State.PLAYING)


func end_game(winner_faction: String, condition_id: String) -> void:
	set_state(State.GAME_OVER)
	EventBus.victory.emit(winner_faction, condition_id)


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	EventBus.flag_set.emit(flag, value)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
	elif event.is_action_pressed("toggle_journal"):
		toggle_journal()
	elif event.is_action_pressed("end_turn") and state == State.PLAYING:
		TurnManager.commit_faction(player_faction_id)
	elif event.is_action_pressed("toggle_pause_clock") and state == State.PLAYING:
		GameClock.toggle_paused()
