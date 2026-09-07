## Boot scene. Picks the game package (from command line `--game=<id>` or the
## default in bootstrap.json), loads it, and starts a new game.
##
## `--smoke` runs a headless self-test (see SmokeTest) and quits with an exit code.
## `--seed=N` fixes the world seed.
extends Node

const BOOTSTRAP := "res://bootstrap.json"

@onready var world_root: Node2D = $World


func _ready() -> void:
	# Bind the shared game_core platform to this graphics engine. Must happen
	# before any package load, since core systems read time/space through it.
	CoreContext.install(IsoEngineAdapter.new())

	WorldManager.set_world_root(world_root)
	var args := _parse_args()
	GameManager.smoke_mode = args.has("smoke")
	var game_id: String = args.get("game", _default_game())
	if not GameManager.load_game(game_id):
		push_error("Main: failed to load game '%s'" % game_id)
		if GameManager.smoke_mode:
			get_tree().quit(2)
		return
	GameManager.start_new_game(int(args.get("seed", -1)))
	if GameManager.smoke_mode:
		var smoke := SmokeTest.new()
		add_child(smoke)
		smoke.run()


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var body := arg.trim_prefix("--")
			var eq := body.find("=")
			if eq >= 0:
				out[body.substr(0, eq)] = body.substr(eq + 1)
			else:
				out[body] = true
	return out


func _default_game() -> String:
	var boot := DataLoader.load_json(BOOTSTRAP)
	return boot.get("default_game", "example_realm_iso")
