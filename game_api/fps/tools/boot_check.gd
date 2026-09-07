## Headless boot self-test: `godot --headless --path . -- --boot-check`.
##
## The FPS engine has no full smoke suite yet, so this verifies the parts the
## shared platform depends on: the engine adapter is installed, the core clock
## tracks GameClock, and CoreRegistry was fed the same game package rather than
## being left silently empty. Prints a report and quits 0/1.
class_name BootCheck
extends Node

var _fails: Array[String] = []
var _passes: int = 0


func run() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await get_tree().process_frame

	var adapter := CoreContext.adapter
	_check(adapter != null and adapter.engine_id == "fps",
		"core adapter installed (%s)" % (adapter.engine_id if adapter else "none"))
	_check(is_equal_approx(CoreContext.now(), GameClock.now()),
		"core clock tracks engine clock (%.1f)" % CoreContext.now())
	_check(CoreRegistry.ids("items").size() > 0,
		"core items loaded (%d)" % CoreRegistry.ids("items").size())
	_check(CoreRegistry.ids("units").size() > 0,
		"core units loaded from actors.json (%d)" % CoreRegistry.ids("units").size())
	_check(CoreRegistry.ids("intel").size() > 0,
		"core intel loaded (%d)" % CoreRegistry.ids("intel").size())
	_check(CoreRegistry.ids("factions").size() > 0,
		"core factions loaded (%d)" % CoreRegistry.ids("factions").size())

	# The core intel pipeline must work against this engine's real data.
	var token_ids := CoreRegistry.ids("intel")
	if not token_ids.is_empty():
		var tid: String = token_ids[0]
		_check(CoreIntel.acquire("player", tid, "boot_a", "told"),
			"core intel acquired '%s'" % tid)
		_check(CoreIntel.evaluate({"has": tid}, "player"),
			"core intel query resolves")

	print("")
	for f in _fails:
		print("FAIL  %s" % f)
	print("BOOT CHECK: %d passed, %d failed" % [_passes, _fails.size()])
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("ok    %s" % label)
	else:
		_fails.append(label)
		print("FAIL  %s" % label)
