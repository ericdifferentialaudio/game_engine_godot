## Command-line narrative validator.
##
## Runs the static pass, and optionally the context simulation, over a game's
## compiled stories and prints a writer-readable report.
##
##   godot --headless --path core -s tools/validate_ink.gd -- \
##       --story=res://ink/round_room_fence.ink.json \
##       --source=res://ink/round_room_fence.ink \
##       --source=res://ink/patterns/patterns.ink \
##       --axes=res://ink/round_room_fence.axes.json
##
## Exits non-zero when any ERROR-severity finding is present, so it can be
## wired into tools/run_tests.ps1 or CI as a gate.
##
## `--axes` points at a JSON file describing the context dimensions to vary:
##   {"assets": {"zorkmid": [0, 5]}, "knowledge": {"know_trapdoor": [false, true]},
##    "standing": {"fence": [0, 40]}, "npc": "fence"}
extends SceneTree

var _story := ""
var _sources: Array[String] = []
var _axes_path := ""
var _npc := ""
var _package := ""

# `class_name` globals are not registered for a script run with `-s`, so the
# shared classes are loaded by path instead.
const Bindings := preload("res://addons/game_core/narrative/core_ink_bindings.gd")
const Validator := preload("res://addons/game_core/narrative/core_ink_validator.gd")


func _init() -> void:
	_parse_args()
	if _story == "":
		print(_usage())
		quit(2)
		return
	# Autoloads are not available to `-s` scripts, so defer until the tree is up.
	_run.call_deferred()


func _run() -> void:
	var failed := false

	# CoreInkEngine creates the inkgd runtime with call_deferred on _ready;
	# let that land before any story is loaded.
	await process_frame

	# Load the game's definitions so asset/knowledge ids in the story resolve
	# to real items and intel tokens rather than warning as unknown.
	if _package != "":
		_a("CoreRegistry").load_package(_package)

	var static_result := Validator.static_check(
			_story, _sources, Bindings.FUNCTION_NAMES)
	print(Validator.format_report(
			"STATIC PASS — %s" % _story.get_file(),
			static_result["findings"], static_result["summary"]))
	if Validator.has_errors(static_result["findings"]):
		failed = true

	if _axes_path != "":
		var axes := _load_axes()
		if axes.is_empty():
			print("Could not read axes file: %s" % _axes_path)
			failed = true
		else:
			failed = _run_simulation(axes) or failed

	print("RESULT: %s" % ("FAILED" if failed else "OK"))
	quit(1 if failed else 0)


func _run_simulation(axes: Dictionary) -> bool:
	var cases := Validator.build_cases(axes)
	var sim := Validator.simulate(cases, _play_case)

	var reached: Dictionary = sim["reached"]
	var labels: Array = reached.keys()
	labels.sort()

	print(Validator.format_report(
			"CONTEXT SIMULATION — %s" % _story.get_file(), [],
			{"contexts": sim["case_count"], "reachable choices": labels.size()}))

	print("REACHABLE CONTENT")
	print("-".repeat(72))
	for label in labels:
		var conditions: Array = reached[label]
		var note := "always" if conditions.size() == cases.size() \
				else "%d/%d contexts" % [conditions.size(), cases.size()]
		print("  %-46s %s" % [str(label).left(46), note])
	print("")
	return false


## One playthrough under a given world state, returning the labels reached.
func _play_case(context: Dictionary) -> Array:
	_a("CoreIntel").reset()
	_a("CoreAssets").reset()
	_a("CoreStanding").reset()
	_a("CoreContext").reset()

	for asset_id in context.get("assets", {}):
		var count := int(context["assets"][asset_id])
		if count > 0:
			_a("CoreAssets").give(str(asset_id), count)
	for knowledge_id in context.get("knowledge", {}):
		if bool(context["knowledge"][knowledge_id]):
			_a("CoreKnowledge").learn(str(knowledge_id), "validator")
	for npc in context.get("standing", {}):
		_a("CoreStanding").set_score(str(npc), float(context["standing"][npc]))

	_a("CoreInkEngine").unload()
	if not _a("CoreInkEngine").load_story(_story):
		return []
	Bindings.new("player", _npc).bind_all(_a("CoreInkEngine"))

	var labels: Array = []
	_a("CoreInkEngine").continue_all()
	for choice in _a("CoreInkEngine").choices():
		labels.append(str(choice["text"]))
	return labels


## Autoload lookup by name.
##
## A script run with `-s` is compiled before the autoload singletons exist, so
## referencing `CoreIntel` directly is a compile error. Resolving them from the
## scene tree at runtime is the supported way to use autoloads from a CLI tool.
func _a(singleton: String) -> Node:
	return root.get_node_or_null(singleton)


func _load_axes() -> Dictionary:
	if not FileAccess.file_exists(_axes_path):
		return {}
	var file := FileAccess.open(_axes_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {}
	var axes: Dictionary = parsed
	if axes.has("npc"):
		_npc = str(axes["npc"])
		axes.erase("npc")
	return axes


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--story="):
			_story = arg.trim_prefix("--story=")
		elif arg.begins_with("--source="):
			_sources.append(arg.trim_prefix("--source="))
		elif arg.begins_with("--axes="):
			_axes_path = arg.trim_prefix("--axes=")
		elif arg.begins_with("--npc="):
			_npc = arg.trim_prefix("--npc=")
		elif arg.begins_with("--package="):
			_package = arg.trim_prefix("--package=")


func _usage() -> String:
	return """
Narrative validator

  godot --headless --path core -s tools/validate_ink.gd -- \\
      --story=res://ink/my_scene.ink.json \\
      --source=res://ink/my_scene.ink \\
      --source=res://ink/patterns/patterns.ink \\
      [--axes=res://ink/my_scene.axes.json] [--npc=fence]

  --story   compiled .ink.json to check          (required)
  --source  .ink source; repeat for each file    (recommended)
  --axes    JSON of context axes to simulate     (optional)
  --npc     NPC id the conversation is with      (optional)

Exits non-zero if any ERROR-severity finding is reported.
"""
