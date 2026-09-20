## Slack Tide's screen: builds the five windows and keeps them fed.
##
## Layout (wide variant, see layout.json):
##
##     +----------------+------------+------------+
##     | scene  (NW)    | map        | status     |   top band
##     +----------------+------------+------------+
##     | narration  (full-width south)| journal    |   south band
##     +------------------------------+------------+
##
## The south band is where the player reads and clicks, so it gets the width.
## The journal sits beside it because reliability and conflicts have to be
## readable WHILE reading the prose that argues about them.
##
## This script owns no widgets of its own. Everything is a `Core*Window` built
## from data by `CoreLayoutBuilder`, looked up **by role** through
## `CoreWindowRegistry`. A role the layout omits returns null and the
## corresponding update simply does nothing -- that is the contract that lets
## the tall variant drop the map without a single conditional here.
extends Node

const LAYOUT_PATH := "res://games/slack_tide/layout.json"

## Reliability bands, shown as a glyph so the journal is skimmable. The exact
## number is in the text; the glyph is for pattern-matching at a glance.
const BANDS := [
	{"floor": 0.75, "icon": "\u25cf", "word": "firm"},
	{"floor": 0.50, "icon": "\u25d1", "word": "likely"},
	{"floor": 0.25, "icon": "\u25cb", "word": "hearsay"},
	{"floor": 0.00, "icon": "\u00b7", "word": "whisper"},
]

var builder: CoreLayoutBuilder
var _boot: Node


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var def := CoreLayoutDefinition.load_file(LAYOUT_PATH)
	if def == null:
		push_error("slack_tide_ui: cannot load " + LAYOUT_PATH)
		return

	builder = CoreLayoutBuilder.new(def)
	# The variant is chosen from the REAL viewport, so the same build serves an
	# ultrawide monitor and a tall window with no runtime repositioning.
	builder.build(root, Vector2(get_viewport().get_visible_rect().size))
	builder.load_ratios()

	# Player input arrives as signals, never as direct calls back into a story:
	# the window does not know what a story is.
	CoreWindowRegistry.choice_selected.connect(_on_choice)
	CoreWindowRegistry.marker_activated.connect(_on_marker)
	CoreWindowRegistry.entry_activated.connect(_on_entry)

	if EventBus.has_signal("turn_started"):
		EventBus.turn_started.connect(func(_t): refresh())
	if EventBus.has_signal("notification"):
		EventBus.notification.connect(_on_notification)

	_boot = get_tree().root.find_child("SlackTideBoot", true, false)
	refresh()


func _exit_tree() -> void:
	if builder != null:
		builder.save_ratios()


# --- Pushing content ----------------------------------------------------------

## Narration. Everything the player reads arrives here.
func say(line: String) -> void:
	CoreWindowRegistry.append_line("narration", line)


## Offer choices. Accepts `CoreInkEngine.choices()` dictionaries or strings.
func offer(choices: Array) -> void:
	var w := CoreWindowRegistry.get_text_window("narration")
	if w != null:
		w.set_choices(choices)


## Swap the scene card and its caption.
func set_scene(image_key: String, caption: String) -> void:
	var w := CoreWindowRegistry.get_graphics_window("scene")
	if w == null:
		return
	if w.has_method("set_image"):
		w.set_image(image_key)
	if w.has_method("set_caption"):
		w.set_caption(caption)


## Place a clickable hotspot. Rides the map window until CR-005 lands a marker
## overlay on the graphics window itself.
func set_hotspot(id: String, pos: Vector2, icon: String = "\u25c6") -> void:
	var w := CoreWindowRegistry.get_map_window("map")
	if w != null and w.has_method("set_marker"):
		w.set_marker(id, pos, icon)


# --- Refresh ------------------------------------------------------------------

func refresh() -> void:
	_refresh_status()
	_refresh_journal()


func _refresh_status() -> void:
	var w := CoreWindowRegistry.get_icon_text_window("status")
	if w == null:
		return
	if _boot != null:
		w.set_entry("day", "\u25d4", "Day %d, %s"
			% [_boot.day, str(_boot.current_slot()).capitalize().replace("_", " ")])
		w.set_entry("tide", "\u2248", "Slack: %.1f hours" % _boot.slack_hours())
	w.set_entry("purse", "\u25ce", "Tallies: %d" % CoreAssets.amount("tally"))
	if _boot != null:
		# Only values that have MOVED are worth screen space; eight static
		# rows of "3" teach the player nothing.
		for v in ["candor", "mercy", "fairness", "nerve",
				  "patience", "fidelity", "curiosity", "restraint"]:
			var n: int = _boot.value_of(v)
			if n != 3:
				w.set_entry("v_" + v, "\u2726", "%s %d" % [v.capitalize(), n])
			else:
				w.remove_entry("v_" + v)


func _refresh_journal() -> void:
	var w := CoreWindowRegistry.get_icon_text_window("journal")
	if w == null:
		return
	var journal := CoreIntel.journal_for("player")
	if journal == null:
		return
	for token in journal.tokens.values():
		var rel: float = token.reliability
		var band := _band(rel)
		var label: String = token.title if token.title != "" else str(token.id)
		var text := "%s  (%d, %s)" % [label, int(round(rel * 100.0)), band["word"]]
		var icon := str(band["icon"])
		if token.known_false:
			# A debunked token is kept, not hidden: knowing a thing is a lie is
			# itself intel, and in this game exposing one corroborates its twin.
			text = "%s  (disproved)" % label
			icon = "\u2715"
		elif not token.conflicts.is_empty():
			# Something in the journal contradicts this. The player should be
			# able to see the argument, not just the conclusion.
			icon = "\u2260"
		w.set_entry(str(token.id), icon, text)


func _band(reliability: float) -> Dictionary:
	for b in BANDS:
		if reliability >= float(b["floor"]):
			return b
	return BANDS[-1]


# --- Player input -------------------------------------------------------------

signal choice_taken(index: int, text: String)
signal hotspot_taken(id: String)
signal journal_opened(token_id: String)


func _on_choice(role: String, index: int, text: String) -> void:
	if role == "narration":
		choice_taken.emit(index, text)


func _on_marker(role: String, marker_id: String) -> void:
	if role == "map":
		hotspot_taken.emit(marker_id)


func _on_entry(role: String, entry_id: String) -> void:
	if role == "journal":
		journal_opened.emit(entry_id)


func _on_notification(text: String, _kind: String) -> void:
	say(text)
	refresh()
