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
		# SmokeTest exercises the hex world, units and terrain, none of which a
		# narrative package has. Such a package gets a boot check instead:
		# did the data load, and did the shared core come up with it?
		if GameManager.is_narrative_package():
			_narrative_boot_check(game_id)
		else:
			var smoke := SmokeTest.new()
			add_child(smoke)
			smoke.run()


## Minimal headless check for a text-led package: the package loaded, its
## intel graph reached CoreRegistry, and the boot script installed itself.
func _narrative_boot_check(game_id: String) -> void:
	var failures := 0
	var checks := 0

	checks += 1
	if GameManager.game_id != game_id:
		push_error("boot: package id is '%s', expected '%s'"
			% [GameManager.game_id, game_id])
		failures += 1

	checks += 1
	var tokens := CoreRegistry.ids("intel")
	if tokens.is_empty():
		push_error("boot: no intel tokens registered")
		failures += 1

	checks += 1
	if CoreContext.adapter == null:
		push_error("boot: no engine adapter installed")
		failures += 1

	checks += 1
	if GameManager.state != GameManager.State.PLAYING:
		push_error("boot: expected PLAYING state")
		failures += 1

	print("NARRATIVE BOOT (%s): %d/%d passed, %d tokens"
		% [game_id, checks - failures, checks, tokens.size()])
	get_tree().quit(1 if failures > 0 else 0)


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
