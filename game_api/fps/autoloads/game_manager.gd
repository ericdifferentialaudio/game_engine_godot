## Top-level game state machine and entry point for a "game package".
##
## A game package lives in res://games/<game_id>/ and is described by game.json.
## GameManager loads the package, hands the data to the registries, and drives
## the high-level state (menu / playing / paused / in-dialogue / journal).
extends Node

enum State { BOOT, MAIN_MENU, LOADING, PLAYING, PAUSED, DIALOGUE, JOURNAL, GAME_OVER }

const GAMES_ROOT := "res://games/"

var state: State = State.BOOT
var game_id: String = ""
var game_config: Dictionary = {}
var flags: Dictionary = {}                 ## Arbitrary bool progression flags.
var reputation: Dictionary = {}            ## faction_id -> int (player standing)
var player: Node3D = null

var _previous_state: State = State.BOOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_spawned.connect(_on_player_spawned)


func _on_player_spawned(p: Node3D) -> void:
	var first_spawn := player == null
	player = p
	if first_spawn:
		_apply_starting_inventory()


func _apply_starting_inventory() -> void:
	var inv = player.get("inventory") if player is Actor else player.get_node_or_null("Inventory")
	if inv == null:
		return
	var currencies: Array = game_config.get("currencies", ["gold"])
	for key in game_config.get("starting_inventory", {}):
		var amount := int(game_config["starting_inventory"][key])
		if key in currencies:
			inv.add_currency(key, amount)
		else:
			inv.add_item(key, amount)
	var equipment = player.get("equipment") if player is Actor else null
	if equipment:
		for item_id in game_config.get("starting_equipment", []):
			var inst = inv.find_first(item_id)
			if inst == null:
				inv.add_item(item_id, 1)
				inst = inv.find_first(item_id)
			if inst:
				equipment.equip(inst)


## Load a game package by id (folder name under res://games/).
func load_game(id: String) -> bool:
	var path := GAMES_ROOT.path_join(id).path_join("game.json")
	var cfg := DataLoader.load_json(path)
	if cfg.is_empty():
		push_error("GameManager: could not load game package '%s' (%s)" % [id, path])
		return false
	game_id = id
	game_config = cfg
	set_state(State.LOADING)

	var base := GAMES_ROOT.path_join(id)

	# Shared platform: rules/seed, then the engine-agnostic definitions that
	# game_core systems read. This engine names its unit file actors.json, so
	# the shared "units" type is re-pointed at it.
	CoreContext.configure(cfg)
	CoreRegistry.register_type("units", CoreUnitDefinition, "actors.json", "actors", true)
	CoreRegistry.load_package(base)

	AssetRegistry.load_manifest(base.path_join("assets.json"))
	DefinitionRegistry.load_package(base)
	IntelRegistry.load_definitions()
	MapManager.load_definitions()
	MapManager.max_depth = int(cfg.get("max_map_depth", MapManager.DEFAULT_MAX_DEPTH))
	GameClock.configure(cfg)
	DamageCalculator.configure(cfg.get("combat", {}))
	return true


## Start a fresh run of the loaded package.
func start_new_game() -> void:
	flags.clear()
	CoreContext.reset()
	CoreIntel.reset()
	reputation.clear()
	for f in DefinitionRegistry.all("factions"):
		reputation[f.id] = f.starting_reputation
	IntelRegistry.reset_journal()
	GameClock.configure(game_config)
	var start_map: String = game_config.get("start_map", "")
	var start_spawn: String = game_config.get("start_spawn", "default")
	MapManager.enter_root_map(start_map, start_spawn)
	set_state(State.PLAYING)


## Reset run state without loading a map (tests / tooling).
func start_new_game_headless() -> void:
	flags.clear()
	reputation.clear()
	for f in DefinitionRegistry.all("factions"):
		reputation[f.id] = f.starting_reputation
	IntelRegistry.reset_journal()
	GameClock.configure(game_config)
	GameClock.running = false
	state = State.PLAYING


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


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	EventBus.flag_set.emit(flag, value)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func get_reputation(faction_id: String) -> int:
	return int(reputation.get(faction_id, 0))


func change_reputation(faction_id: String, delta: int) -> void:
	reputation[faction_id] = get_reputation(faction_id) + delta
	EventBus.faction_reputation_changed.emit(faction_id, reputation[faction_id])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
	elif event.is_action_pressed("toggle_journal"):
		toggle_journal()
