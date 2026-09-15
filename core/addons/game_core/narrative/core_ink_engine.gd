## The shared Ink narrative engine: load a compiled story, advance it, present
## choices, and persist mid-conversation state.
##
## Registered as the `CoreInkEngine` autoload.
##
## This is the **only** file in the repo that references the vendored `inkgd`
## runtime (`core/addons/inkgd/`). Everything else — games, engine layers,
## windows, validators — talks to this facade, so replacing the runtime is a
## single-file change.
##
## API:
##   CoreInkEngine.load_story("res://games/zork/ink/pub_gathering.ink.json")
##   CoreInkEngine.start("pub_gathering")     # optional knot
##   while CoreInkEngine.can_continue():
##       print(CoreInkEngine.continue_text(), CoreInkEngine.current_tags())
##   CoreInkEngine.choices()                  -> [{"index", "text", "tags"}]
##   CoreInkEngine.choose(0)
##   CoreInkEngine.to_save_data() / from_save_data(d)
##
## External functions (`knows`, `has_asset`, ...) are not bound here: that is
## `CoreInkBindings`' job, so this stays pure plumbing with no opinion about
## what a game's knowledge or assets are.
extends Node

## A line of narrative became available. [param tags] are the `#tag`s on it.
signal line_shown(text: String, tags: Array)
## The story is waiting on the player. [param choices] is an Array[Dictionary].
signal choices_presented(choices: Array)
## A choice was taken (emitted before the story advances).
signal choice_made(index: int, text: String)
## The story ran out of content.
signal story_ended()
## A story finished loading. [param ok] is false if it could not be created.
signal story_loaded(path: String, ok: bool)
## The runtime reported a problem. Surfaced as a signal so a game can show it.
signal story_error(message: String)

## Path of the story currently loaded, "" when none.
var story_path: String = ""

var _player: Node = null
var _bindings: Array[String] = []     ## External fn names currently bound.
## Strong references to every object holding a bound method. Ink keeps only a
## weak binding, so without this a RefCounted bindings object created inline
## (`CoreInkBindings.new(...).bind_all(engine)`) is freed while the story is
## still running, and every external call fails at the worst possible moment.
var _binding_owners: Array = []
var _ended: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Deferred because the scene root is still busy adding autoloads here.
	_ensure_runtime.call_deferred()


## inkgd expects a `__InkRuntime` singleton under the scene root and probes for
## it with a plain `get_node()`, which logs a "Node not found" error the first
## time. Creating it up front keeps that noise out of every story load — and out
## of validator output, which writers are meant to read.
## Added as a child of this autoload rather than deferred onto the scene root:
## a deferred add would not have landed by the time a story is loaded in the
## same frame (which both the tests and the CLI validators do), leaving inkgd
## to build its own runtime mid-load.
func _ensure_runtime() -> void:
	var tree := get_tree()
	if tree == null or tree.root.has_node("__InkRuntime"):
		return
	var runtime = load("res://addons/inkgd/ink_runtime.gd").new()
	runtime.name = "__InkRuntime"
	tree.root.add_child(runtime)


# --- Loading ------------------------------------------------------------------

## Load a compiled Ink story (`.ink.json`). Synchronous: by the time this
## returns the story is ready to [method start].
##
## Returns true on success. Safe to call repeatedly; the previous story is
## discarded along with its external-function bindings.
func load_story(path: String) -> bool:
	unload()

	# A story can legitimately be loaded in the very first frame, before the
	# deferred setup above has run, so make sure the runtime exists now.
	_ensure_runtime()

	var json := _read_json(path)
	if json == "":
		story_error.emit("CoreInkEngine: could not read story at %s" % path)
		story_loaded.emit(path, false)
		return false

	_player = InkPlayerFactory.create()
	# Synchronous creation keeps the API simple and the headless validators
	# deterministic; stories are small enough that this is cheap.
	_player.loads_in_background = false
	_player.ink_file = _make_resource(json)
	add_child(_player)

	_player.loaded.connect(_on_loaded)
	_player.error_encountered.connect(_on_error)
	_player.exception_raised.connect(_on_exception)

	# inkgd's own create_story() always defers the final build (even with
	# loads_in_background off), which would leave the story unusable until the
	# next frame. Drive the runtime attach + build directly so that this call
	# is genuinely synchronous, as the API above promises — the headless
	# validators and tests depend on it.
	_player._add_runtime()
	_player._create_and_finalize_story(_player.ink_file.json, _player._ink_runtime.get_ref())

	if _player._story == null:
		story_error.emit("CoreInkEngine: story could not be built from %s" % path)
		story_loaded.emit(path, false)
		return false

	story_path = path
	_ended = false
	story_loaded.emit(path, true)
	return true


## Discard the current story and every external-function binding.
func unload() -> void:
	if _player != null:
		if _player.get_parent() == self:
			remove_child(_player)
		# free(), not queue_free(): a validator run loads and unloads hundreds
		# of stories synchronously within a single frame, and deferred frees
		# would pile up as orphans until that frame ended.
		_player.free()
		_player = null
	_bindings.clear()
	_binding_owners.clear()
	story_path = ""
	_ended = false


func is_loaded() -> bool:
	return _player != null


# --- Flow ---------------------------------------------------------------------

## Jump to a knot/stitch path, e.g. "pub_gathering" or "barter.refused".
## Pass "" to simply begin at the top of the story.
func start(knot_path: String = "") -> void:
	if not _require_story():
		return
	_ended = false
	if knot_path != "":
		_player.choose_path(knot_path)


func can_continue() -> bool:
	return _player != null and _player.can_continue


## Advance one line. Emits [signal line_shown], and [signal choices_presented]
## or [signal story_ended] once the story stops producing text.
func continue_text() -> String:
	if not _require_story():
		return ""
	if not _player.can_continue:
		_settle()
		return ""
	var text: String = _player.continue_story()
	line_shown.emit(text, current_tags())
	if not _player.can_continue:
		_settle()
	return text


## Advance until the story needs the player (a choice or the end), returning
## every line produced. Convenience for text windows that show a whole beat.
func continue_all() -> Array[String]:
	var lines: Array[String] = []
	while can_continue():
		var line := continue_text()
		if line.strip_edges() != "":
			lines.append(line)
	return lines


func current_text() -> String:
	return _player.current_text if _player != null else ""


## Tags attached to the current line (`# portrait: barkeep` -> "portrait: barkeep").
func current_tags() -> Array:
	return _player.current_tags if _player != null else []


## Tags at the top of the story file, before any content.
func global_tags() -> Array:
	return _player.global_tags if _player != null else []


func has_choices() -> bool:
	return _player != null and _player.has_choices


## The choices the player may take now, as plain Dictionaries so that UI code
## never touches an inkgd type:
##   [{"index": 0, "text": "Pay the fence.", "tags": ["cost: 3"]}]
func choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _player == null:
		return out
	var index := 0
	for choice in _player.current_choices:
		out.append({
			"index": index,
			"text": str(choice.text),
			"tags": choice.tags if choice.tags != null else [],
		})
		index += 1
	return out


## Take a choice by its index in [method choices]. Returns false if out of range.
func choose(index: int) -> bool:
	if not _require_story():
		return false
	var available := choices()
	if index < 0 or index >= available.size():
		story_error.emit("CoreInkEngine: choice index %d out of range (%d available)"
				% [index, available.size()])
		return false
	choice_made.emit(index, str(available[index]["text"]))
	_player.choose_choice_index(index)
	return true


## True once the story has no more content and no choices.
func has_ended() -> bool:
	return _ended


## How many times the story has visited a knot/stitch. Used by the validators
## to prove a branch was actually reachable.
func visit_count(path: String) -> int:
	return _player.visit_count_at_path(path) if _player != null else 0


func current_path() -> String:
	return _player.current_path if _player != null else ""


# --- Variables ----------------------------------------------------------------

## Read an Ink global variable (`VAR location = "round_room"`).
func var_get(name: String, default_value = null):
	if _player == null:
		return default_value
	var value = _player.get_variable(name)
	return default_value if value == null else value


## Write an Ink global variable. Silently ignores names the story does not
## declare, so a shared ContextBuilder can push a superset of variables into a
## story that only cares about some of them.
func var_set(name: String, value) -> void:
	if _player == null:
		return
	if _player.get_variable(name) == null:
		return
	_player.set_variable(name, value)


## True when the story declares this global variable.
func has_var(name: String) -> bool:
	return _player != null and _player.get_variable(name) != null


# --- External functions -------------------------------------------------------

## Bind an Ink `EXTERNAL fn(...)` to a Godot method.
##
## [param lookahead_safe] must stay false for anything with side effects
## (`learn`, `give_asset`): Ink evaluates choice conditions speculatively, and a
## lookahead-safe binding can fire twice.
func bind_function(func_name: String, object: Object, method_name: String,
		lookahead_safe: bool = false) -> void:
	if not _require_story():
		return
	_player.bind_external_function(func_name, object, method_name, lookahead_safe)
	if func_name not in _bindings:
		_bindings.append(func_name)
	if object != null and object not in _binding_owners:
		_binding_owners.append(object)


func unbind_function(func_name: String) -> void:
	if _player == null:
		return
	_player.unbind_external_function(func_name)
	_bindings.erase(func_name)


## Names of every external function currently bound. The static validator uses
## this to check a story's `EXTERNAL` declarations are all satisfied.
func bound_functions() -> Array[String]:
	return _bindings.duplicate()


# --- Persistence --------------------------------------------------------------
## The Ink runtime's own JSON state travels inside the host's save data, so a
## save taken mid-conversation restores mid-conversation.

func to_save_data() -> Dictionary:
	if _player == null:
		return {}
	return {
		"story_path": story_path,
		"state": _player.get_state(),
		"ended": _ended,
	}


func from_save_data(d: Dictionary) -> void:
	var path := str(d.get("story_path", ""))
	if path == "":
		unload()
		return
	# Reload the story itself before restoring state: Ink state is meaningless
	# without the container it was recorded against.
	if path != story_path or _player == null:
		if not load_story(path):
			return
	var state := str(d.get("state", ""))
	if state != "":
		_player.set_state(state)
	_ended = bool(d.get("ended", false))


# --- Internals ----------------------------------------------------------------

func _settle() -> void:
	if _player == null:
		return
	if _player.has_choices:
		choices_presented.emit(choices())
	elif not _ended:
		_ended = true
		story_ended.emit()


func _require_story() -> bool:
	if _player == null:
		story_error.emit("CoreInkEngine: no story loaded")
		return false
	return true


func _read_json(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _make_resource(json: String) -> Resource:
	var res = load("res://addons/inkgd/editor/import_plugins/ink_resource.gd").new()
	res.json = json
	return res


func _on_loaded(ok: bool) -> void:
	if not ok:
		story_error.emit("CoreInkEngine: story failed to load (%s)" % story_path)


func _on_error(message, _type) -> void:
	story_error.emit("CoreInkEngine: %s" % str(message))


func _on_exception(message, _stack_trace) -> void:
	story_error.emit("CoreInkEngine: %s" % str(message))
