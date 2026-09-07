## Boot scene. Picks the game package (from command line `--game=<id>` or the
## default in bootstrap.json), loads it, and starts a new game.
extends Node

const BOOTSTRAP := "res://bootstrap.json"

@onready var world_root: Node3D = $World


func _ready() -> void:
	# Bind the shared game_core platform to this graphics engine. Must happen
	# before any package load, since core systems read time/space through it.
	CoreContext.install(FpsEngineAdapter.new())

	MapManager.set_world_root(world_root)
	var game_id := _resolve_game_id()
	if not GameManager.load_game(game_id):
		push_error("Main: failed to load game '%s'" % game_id)
		return
	GameManager.start_new_game()

	if "--boot-check" in OS.get_cmdline_user_args():
		var check := BootCheck.new()
		add_child(check)
		check.run()


func _resolve_game_id() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="):
			return arg.trim_prefix("--game=")
	var boot := DataLoader.load_json(BOOTSTRAP)
	return boot.get("default_game", "example_realm")
