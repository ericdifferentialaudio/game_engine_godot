## Global lookup from a role id to the live window filling that role.
##
## Registered as the `CoreWindowRegistry` autoload.
##
## This is what lets narrative, inventory and map code push content to the
## screen without holding scene references:
##
##   var w := CoreWindowRegistry.get_text_window("dialogue")
##   if w: w.append_line("The fence looks up.")
##
## Lookups **fail gracefully**. A game whose layout has no map window is not
## broken — map code simply finds nothing and does nothing. That is deliberate:
## shared systems must not assume a particular screen.
##
## Direction of travel is a deliberate hybrid:
##   * pushing content down    -> direct registry calls (simple, immediate)
##   * reporting player action -> signals (the window does not know who cares)
extends Node

## A window became available in this role.
signal window_registered(role: String, window: Control)
## A window went away (scene change, layout rebuild).
signal window_unregistered(role: String)

## The player picked a choice in a text window.
signal choice_selected(role: String, index: int, text: String)
## The player clicked something in a map window.
signal marker_activated(role: String, marker_id: String)
## The player picked an entry in a unit/icon list window.
signal entry_activated(role: String, entry_id: String)

var _windows: Dictionary = {}       ## role -> Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- Registration -------------------------------------------------------------

## Called by a window at scene-ready time. Re-registering a role replaces it,
## which is what a layout rebuild wants.
func register_window(role: String, window: Control) -> void:
	if role == "":
		push_warning("CoreWindowRegistry: refusing to register a window with no role")
		return
	_windows[role] = window
	window_registered.emit(role, window)


func unregister_window(role: String) -> void:
	if _windows.erase(role):
		window_unregistered.emit(role)


func clear() -> void:
	for role in _windows.keys():
		unregister_window(str(role))


# --- Lookup -------------------------------------------------------------------

## The window in this role, or null. Callers are expected to null-check; that
## is the graceful-degradation contract.
##
## Named `window_for`, not `get_window`, because `Node.get_window()` is a Godot
## built-in returning the OS window — overriding it with a different signature
## is a parse error.
func window_for(role: String) -> Control:
	var window = _windows.get(role)
	if window == null:
		return null
	if not is_instance_valid(window):
		# The scene went away without telling us.
		_windows.erase(role)
		return null
	return window


func has_window(role: String) -> bool:
	return window_for(role) != null


## Every role currently filled, sorted for stable output.
func roles() -> Array[String]:
	var out: Array[String] = []
	for role in _windows:
		if is_instance_valid(_windows[role]):
			out.append(str(role))
	out.sort()
	return out


# --- Typed lookups ------------------------------------------------------------
## Sugar that also guards against a layout putting the wrong window type in a
## role — better a null than a "method not found" three frames later.

func get_text_window(role: String) -> CoreTextWindow:
	return window_for(role) as CoreTextWindow


func get_unit_window(role: String) -> CoreUnitDisplayWindow:
	return window_for(role) as CoreUnitDisplayWindow


func get_icon_text_window(role: String) -> CoreIconTextWindow:
	return window_for(role) as CoreIconTextWindow


## Returns the base type, so an engine subclass (the isometric `IsoMapWindow`,
## say) is found here exactly like the plain core window — callers look up a
## *role*, never a concrete class.
func get_map_window(role: String) -> CoreMapWindow:
	return window_for(role) as CoreMapWindow


func get_graphics_window(role: String) -> CoreGraphicsWindow:
	return window_for(role) as CoreGraphicsWindow


# --- Convenience --------------------------------------------------------------

## Push a line to a text window if that role exists. Returns false when the
## game's layout has no such window — not an error, just nothing to do.
func append_line(role: String, text: String) -> bool:
	var window := get_text_window(role)
	if window == null:
		return false
	window.append_line(text)
	return true


## Clear every registered window (scene transitions, new game).
func clear_all() -> void:
	for role in roles():
		var window := window_for(role)
		if window != null and window.has_method("clear"):
			window.clear()


# --- Signal relays ------------------------------------------------------------
## Windows call these rather than emitting their own bespoke signals, so any
## listener can subscribe in one place regardless of which window spoke.

func report_choice(role: String, index: int, text: String) -> void:
	choice_selected.emit(role, index, text)


func report_marker(role: String, marker_id: String) -> void:
	marker_activated.emit(role, marker_id)


func report_entry(role: String, entry_id: String) -> void:
	entry_activated.emit(role, entry_id)
