@tool
extends EditorPlugin
## Registers the shared game_core managers as autoload singletons in any
## Godot project that installs this addon (core harness, isometric, fps).
##
## Adding a new shared manager: add one line here AND document it in
## docs/RESOURCE_SCHEMA.md / docs/ARCHITECTURE.md.

## `DialogueManager` was removed 2026-09-19: it was an unimplemented placeholder
## superseded by `CoreInkEngine` (a real Ink runtime with save state, external
## functions and validators). Nothing referenced it.
const AUTOLOADS := {
	"VirtueSystem": "res://addons/game_core/managers/virtue_system.gd",
	"WorldStateManager": "res://addons/game_core/managers/world_state_manager.gd",
	"AIHeuristicManager": "res://addons/game_core/managers/ai_heuristic_manager.gd",
}


func _enter_tree() -> void:
	for autoload_name in AUTOLOADS.keys():
		add_autoload_singleton(autoload_name, AUTOLOADS[autoload_name])


func _exit_tree() -> void:
	for autoload_name in AUTOLOADS.keys():
		remove_autoload_singleton(autoload_name)
