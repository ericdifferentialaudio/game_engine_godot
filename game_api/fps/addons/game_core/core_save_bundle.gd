## One aggregate of every core system's persistent state.
##
## Each engine layer already has its own `SaveManager` with its own
## `SAVE_VERSION` and migrations. Rather than make each of them enumerate core
## systems — and have to be edited every time a new core system appears — they
## embed this one nested dictionary:
##
##   # saving
##   save["core"] = CoreSaveBundle.collect()
##   # loading
##   CoreSaveBundle.apply(save.get("core", {}))
##
## Adding a core system therefore touches this file only, and both engines
## inherit the change on the next `sync_core.ps1`.
##
## Deliberately **not** included: window split ratios. Those are a property of
## the player's screen, not of the game world, and live in user preferences
## (`CoreLayoutBuilder.PREFS_PATH`) so they survive across saves and machines.
class_name CoreSaveBundle
extends RefCounted

## Bumped when the shape of this bundle changes incompatibly. Engine
## SaveManagers can read it to decide whether they need to migrate.
const VERSION := 1

## Autoload name -> key in the bundle. Order matters on load: definitions and
## context first, then the systems that reference them.
const SYSTEMS := [
	["CoreContext", "context"],
	["CoreIntel", "intel"],
	["CoreAssets", "assets"],
	["CoreStanding", "standing"],
	["CoreInkEngine", "ink"],
]


## Gather every core system's state into one dictionary.
static func collect() -> Dictionary:
	var out := {"version": VERSION}
	for entry in SYSTEMS:
		var node := _system(entry[0])
		if node != null and node.has_method("to_save_data"):
			out[entry[1]] = node.to_save_data()
	return out


## Restore every core system from a bundle produced by [method collect].
## Unknown or missing sections are skipped, so an older save still loads.
static func apply(bundle: Dictionary) -> void:
	for entry in SYSTEMS:
		if not bundle.has(entry[1]):
			continue
		var node := _system(entry[0])
		if node != null and node.has_method("from_save_data"):
			node.from_save_data(bundle[entry[1]])


## Version of a bundle, 0 when absent (a pre-bundle save).
static func version_of(bundle: Dictionary) -> int:
	return int(bundle.get("version", 0))


## Resolved from the scene tree rather than by bare autoload name so that this
## works from command-line tools too (see `CoreInkBindings`).
static func _system(singleton: String) -> Node:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null(singleton)
