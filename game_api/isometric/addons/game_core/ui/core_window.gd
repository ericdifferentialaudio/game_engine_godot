## Base contract every screen window implements.
##
## A window is one fixed region of the main screen, specialised for one job.
## Its *position* never changes at runtime — that is what makes a layout
## learnable. Its *size* is the player's business, adjusted by dragging the
## dividers between regions (see `CoreLayoutBuilder`).
##
## Subclasses add their own specialised methods (`append_line`, `set_units`,
## `set_marker`, ...). Everything shared lives here, so any system can do
## `CoreWindowRegistry.get_window("dialogue").clear()` without knowing or
## caring which kind of window is installed in that role.
##
## Windows register themselves on `_ready` and deregister on exit, so lookups
## are always against what is genuinely on screen.
class_name CoreWindow
extends PanelContainer

## Emitted after the window registers itself, for systems that want to push
## initial content without polling.
signal window_ready(role: String)

## The stable id other systems look this window up by ("dialogue", "status",
## "map", "portrait"). Set from the layout config, not hard-coded per game.
@export var role: String = ""

## Human-readable label, optionally shown in a title bar.
@export var title: String = ""

## Smallest sensible size for this window type. The layout builder enforces it
## so a player cannot drag a divider far enough to make content unreadable.
@export var minimum_window_size: Vector2i = Vector2i(120, 80)


func _ready() -> void:
	custom_minimum_size = Vector2(minimum_window_size)
	_build()
	if role != "":
		CoreWindowRegistry.register_window(role, self)
	window_ready.emit(role)


func _exit_tree() -> void:
	if role != "":
		CoreWindowRegistry.unregister_window(role)


## Subclasses build their own contents here. Called once, before registration,
## so a window is fully usable the instant it appears in the registry.
func _build() -> void:
	pass


# --- Shared contract ----------------------------------------------------------

## Show this window. Kept as plain methods (not just `visible`) so that a
## subclass can do extra work — resume a feed, start an animation — and so that
## calling code reads the same for every window type.
func show_window() -> void:
	visible = true


func hide_window() -> void:
	visible = false


func is_shown() -> bool:
	return visible


## Remove everything this window is currently displaying, leaving it usable.
## Subclasses must override; the base does nothing rather than guess.
func clear() -> void:
	pass


## A one-line description of what this window currently holds. Used by the
## layout debugger and by tests to assert on content without reaching into
## the node tree.
func describe() -> String:
	return "%s (%s)" % [role, get_class()]
