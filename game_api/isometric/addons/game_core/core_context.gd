## The single seam between the engine-agnostic platform and a graphics engine.
##
## Core systems (intel, inventory, queries, combat) never reference the
## isometric or FPS autoloads directly. Instead each graphics engine installs an
## adapter here at boot, and core code asks `CoreContext` for the few
## engine-dependent facts it needs.
##
## Registered as the `CoreContext` autoload.
##
## Install from a graphics engine:
##   CoreContext.install(MyEngineAdapter.new())     # extends CoreEngineAdapter
##
## API used by core systems:
##   CoreContext.now()                       -> float  (turns for iso, seconds for fps)
##   CoreContext.has_flag(flag)              -> bool
##   CoreContext.set_flag(flag, value)
##   CoreContext.rule("combat.randomness", 0.2)
##   CoreContext.rng()                       -> RandomNumberGenerator (deterministic)
##   CoreContext.adapter                     -> CoreEngineAdapter (engine extras)
extends Node

signal adapter_installed(adapter: CoreEngineAdapter)
signal flag_set(flag: String, value: bool)

## The active graphics-engine adapter. Never null: a headless default is used
## until a real engine installs its own, so core logic and tests always work.
var adapter: CoreEngineAdapter = null

## Free-form global progression flags (shared by both engines).
var flags: Dictionary = {}

## Game rules dictionary, normally game.json["rules"].
var rules: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if adapter == null:
		adapter = CoreEngineAdapter.new()


## Install a graphics-engine adapter. Called once at boot by the engine layer.
func install(new_adapter: CoreEngineAdapter) -> void:
	adapter = new_adapter if new_adapter != null else CoreEngineAdapter.new()
	adapter_installed.emit(adapter)


## Configure rules + deterministic seed, normally from game.json.
func configure(config: Dictionary) -> void:
	rules = config.get("rules", {})
	var game_seed := int(config.get("seed", 0))
	if game_seed != 0:
		_rng.seed = game_seed
	else:
		_rng.randomize()


## Reset per-run state without dropping the installed adapter.
func reset() -> void:
	flags.clear()


# --- Time --------------------------------------------------------------------

## Current time in the host engine's own unit: turn number (isometric) or game
## seconds (FPS). Core systems only ever compare/subtract these values, so the
## unit is irrelevant as long as one engine is consistent with itself.
func now() -> float:
	return adapter.now() if adapter else 0.0


# --- Flags -------------------------------------------------------------------

func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_set.emit(flag, value)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


# --- Rules -------------------------------------------------------------------

## Dotted-path rule lookup, e.g. rule("combat.randomness", 0.2).
func rule(path: String, default = null):
	var node = rules
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return default
	return node


# --- Randomness --------------------------------------------------------------

## Shared deterministic RNG so a seeded game replays identically in both engines.
func rng() -> RandomNumberGenerator:
	return _rng


func to_save_data() -> Dictionary:
	return {"flags": flags.duplicate(), "rng_state": _rng.state, "rng_seed": _rng.seed}


func from_save_data(d: Dictionary) -> void:
	flags = d.get("flags", {})
	if d.has("rng_seed"):
		_rng.seed = int(d["rng_seed"])
	if d.has("rng_state"):
		_rng.state = int(d["rng_state"])
