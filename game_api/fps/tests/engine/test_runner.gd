## Minimal in-engine test runner (no addon dependency). Discovers every
## `test_*.gd` under res://tests/godot/, instantiates it, and runs every
## method starting with `test_`. Assertion helpers live in GdTest.
##
##   godot --headless --path . -s res://tests/godot/test_runner.gd
##   .\tools\godot.ps1 test
extends SceneTree

const TEST_DIR := "res://tests/godot/"
const GAME_ID := "example_realm"

var _passed := 0
var _failed := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# `-s` scripts compile before autoloads exist, so resolve singletons via the tree.
	var game_manager := root.get_node("GameManager")
	if not game_manager.load_game(GAME_ID):
		printerr("test_runner: could not load game package '%s'" % GAME_ID)
		quit(1)
		return
	game_manager.start_new_game_headless()

	var scripts := _discover()
	scripts.sort()
	for path in scripts:
		# NOTE: no static type references to GdTest/Actor here — this script is
		# compiled before autoload singletons exist, so test classes must only be
		# loaded at runtime (after the deferred call).
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			_fail("%s: failed to load/compile" % path)
			continue
		var suite = script.new()
		suite.tree = self
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			suite._reset()
			suite.before_each()
			var callable := Callable(suite, mname)
			callable.call()
			await process_frame  # let deferred / signals settle
			suite.after_each()
			if suite.errors.is_empty():
				_passed += 1
				print("  ok   %s.%s" % [path.get_file().get_basename(), mname])
			else:
				_failed += 1
				for e in suite.errors:
					_failures.append("%s.%s: %s" % [path.get_file().get_basename(), mname, e])
				printerr("  FAIL %s.%s" % [path.get_file().get_basename(), mname])
				for e in suite.errors:
					printerr("       %s" % e)
		suite.free_all()

	print("\n%d passed, %d failed." % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _fail(msg: String) -> void:
	_failed += 1
	_failures.append(msg)
	printerr("  FAIL " + msg)


func _discover() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd":
			out.append(TEST_DIR + f)
		f = dir.get_next()
	dir.list_dir_end()
	return out
