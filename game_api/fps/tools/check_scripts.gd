## Headless compile check for every GDScript in the project.
##
## Runs inside a full SceneTree (so autoload singletons such as EventBus and
## GameManager resolve), loads each script, and reports any that fail to
## compile. Also instantiates every .tscn to catch broken scene references.
##
##   godot --headless --path . -s res://tools/check_scripts.gd
## Exit code 0 = all good, 1 = failures.
extends SceneTree

const SKIP_DIRS := [".godot", "gdextension", "addons", "assets_src"]

var _failed := 0
var _checked := 0


func _init() -> void:
	# Defer so autoloads have been added to the tree.
	call_deferred("_run")


func _run() -> void:
	var scripts: Array[String] = []
	var scenes: Array[String] = []
	_collect("res://", scripts, scenes)

	for path in scripts:
		_checked += 1
		var script = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		if script == null or not (script as GDScript).can_instantiate() and not _is_abstract_ok(script):
			_fail(path, "failed to load/compile")
		else:
			print("ok   ", path)

	for path in scenes:
		_checked += 1
		var packed = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
		if packed == null:
			_fail(path, "failed to load scene")
			continue
		var state := (packed as PackedScene).get_state()
		if state == null or state.get_node_count() == 0:
			_fail(path, "scene has no nodes / broken references")
		else:
			print("ok   ", path)

	print("\n%d files checked, %d failed." % [_checked, _failed])
	quit(1 if _failed > 0 else 0)


## A script that compiles but has a bare `class_name ... extends RefCounted` can still instantiate;
## can_instantiate() is false only when compilation failed or the base is abstract.
func _is_abstract_ok(script: GDScript) -> bool:
	return script.get_instance_base_type() != &""


func _fail(path: String, why: String) -> void:
	_failed += 1
	printerr("FAIL ", path, "  (", why, ")")


func _collect(dir_path: String, scripts: Array[String], scenes: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with(".") and name not in SKIP_DIRS:
				_collect(full, scripts, scenes)
		elif name.ends_with(".gd") and full != "res://tools/check_scripts.gd":
			scripts.append(full)
		elif name.ends_with(".tscn"):
			scenes.append(full)
		name = dir.get_next()
	dir.list_dir_end()
