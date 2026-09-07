## HUD with a text-adventure narration log: every notification is appended as
## a line, room descriptions print on arrival (long text on first visit, short
## on revisits), combat is narrated, and the status line shows Score / Moves.
## The *signals* it listens to are the contract; games may re-skin the scene.
class_name Hud
extends CanvasLayer

const MAX_LOG_LINES := 60
const CATEGORY_COLORS := {
	"room": "#e6ffe6", "examine": "#bfffbf", "dialogue": "#bfffbf", "travel": "#9fdf9f",
	"pickup": "#ffe9a0", "reward": "#ffe9a0", "intel": "#a0d8ff", "discovery": "#a0d8ff",
	"combat": "#ff9f9f", "death": "#ff5f5f", "locked": "#d0b070", "warning": "#d0b070",
	"score": "#ffe9a0",
}

@onready var prompt_label: Label = $Prompt
@onready var notif_box: VBoxContainer = $Notifications
@onready var journal_panel: PanelContainer = $Journal
@onready var journal_text: RichTextLabel = $Journal/Scroll/Text
@onready var breadcrumb: Label = $Breadcrumb
@onready var vitals: Label = $Vitals

var _log_lines: Array[String] = []
var _game_over_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	journal_panel.visible = false
	prompt_label.visible = false
	EventBus.interaction_prompt.connect(_on_prompt)
	EventBus.notification.connect(_on_notification)
	EventBus.game_state_changed.connect(_on_state)
	EventBus.map_loaded.connect(_on_map_loaded)
	EventBus.intel_acquired.connect(func(_id, _src): _refresh_journal())
	EventBus.intel_updated.connect(func(_id): _refresh_journal())
	EventBus.intel_acquired.connect(_on_intel_acquired)
	EventBus.actor_damaged.connect(_on_actor_damaged)
	EventBus.actor_died.connect(_on_actor_died)
	EventBus.score_changed.connect(_on_score)


func _on_prompt(text: String, visible_: bool) -> void:
	prompt_label.text = "[E] " + text
	prompt_label.visible = visible_


func _on_notification(text: String, category: String) -> void:
	_append_log(text, category)


## Append to the scrolling narration; falls back to the label feed when a
## HUD scene has no NarrationLog node.
func _append_log(text: String, category: String = "") -> void:
	var color: String = CATEGORY_COLORS.get(category, "#d0d0d0")
	_log_lines.append("[color=%s]%s[/color]" % [color, text])
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	var log := get_node_or_null("NarrationLog") as RichTextLabel
	if log:
		log.text = "\n".join(_log_lines)
		log.scroll_to_line(log.get_line_count())
	else:
		var l := Label.new()
		l.text = text
		notif_box.add_child(l)
		get_tree().create_timer(6.0).timeout.connect(l.queue_free)


func _on_state(_prev: int, cur: int) -> void:
	journal_panel.visible = cur == GameManager.State.JOURNAL
	if journal_panel.visible:
		_refresh_journal()
	if cur == GameManager.State.GAME_OVER:
		_show_game_over()
	elif _game_over_label:
		_game_over_label.queue_free()
		_game_over_label = null


func _show_game_over() -> void:
	_game_over_label = Label.new()
	_game_over_label.text = "    ****  You have died  ****\n\nScore: %d in %d moves.\n\n[E] to begin again" % [GameManager.score, GameManager.moves]
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_game_over_label.offset_left = -240
	_game_over_label.offset_right = 240
	_game_over_label.offset_top = -80
	_game_over_label.offset_bottom = 80
	_game_over_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	add_child(_game_over_label)


func _on_map_loaded(_map_id: String, _depth: int) -> void:
	describe_room(true)
	_refresh_status()


## Print the current room: long text on the first visit (or when forced by
## LOOK), the short text on revisits. Dark rooms print the grue warning.
func describe_room(auto: bool = false) -> void:
	var def := MapManager.get_definition(MapManager.current_id)
	if def == null:
		return
	_append_log("[b]%s[/b]" % def.display_name, "room")
	var map := MapManager.current_map
	if map and map.has_method("is_lit") and not map.is_lit():
		_append_log(def.dark_description, "room")
		return
	var visits := int(MapManager.get_map_state(def.id).get("visits", 1))
	if auto and visits > 1 and def.short_description != "":
		_append_log(def.short_description, "room")
	elif def.description != "":
		_append_log(def.description, "room")



func _on_intel_acquired(token_id: String, _src: String) -> void:
	var tok := IntelRegistry.get_token(token_id)
	if tok and not tok.has_tag("debunked"):
		_append_log("[i]You make a note: %s.[/i]" % tok.title, "intel")


func _on_actor_damaged(actor: Node3D, amount: float, _type: String, source: Node3D) -> void:
	if amount <= 0.0:
		return
	if actor is Actor and (actor as Actor).is_player():
		_append_log("%s hits you for %d." % [_name_of(source).capitalize(), int(round(amount))], "combat")
	else:
		var hp := ""
		if actor is Actor and (actor as Actor).health:
			var h := (actor as Actor).health
			hp = " (%d/%d)" % [int(h.current), int(h.maximum)]
		_append_log("You strike %s for %d%s." % [_name_of(actor), int(round(amount)), hp], "combat")


func _on_actor_died(actor: Node3D, killer: Node3D) -> void:
	if actor is Actor and (actor as Actor).is_player():
		return
	var who := _name_of(actor).capitalize()
	if killer is Actor and (killer as Actor).is_player():
		_append_log("%s falls. It does not get up." % who, "combat")
	else:
		_append_log("%s is dead." % who, "combat")


func _on_score(_total: int, delta: int) -> void:
	if delta != 0:
		_append_log("[Your score has just gone %s by %d points.]" % ["up" if delta > 0 else "down", absi(delta)], "score")
	_refresh_status()


func _name_of(n: Node3D) -> String:
	if n is Actor:
		var a := n as Actor
		if a.is_player():
			return "you"
		return a.actor_def.display_name.to_lower() if a.actor_def else a.name
	return "something" if n == null else n.name


func _refresh_status() -> void:
	var def := MapManager.get_definition(MapManager.current_id)
	var room := def.display_name if def else MapManager.current_id
	breadcrumb.text = "%s     Score: %d     Moves: %d" % [room, GameManager.score, GameManager.moves]


func _process(_delta: float) -> void:
	var p := GameManager.player
	if p is Actor and p.health:
		var parts: Array[String] = ["HP %d/%d" % [p.health.current, p.health.maximum]]
		if p.resources:
			for name in p.resources.pools:
				parts.append("%s %d/%d" % [name.capitalize(), p.resources.get_current(name), p.resources.get_max(name)])
		if p.equipment and p.equipment.main_weapon():
			parts.append("Wielding: %s" % p.equipment.main_weapon().display_name())
		vitals.text = "   ".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if event.is_action_pressed("look"):
		describe_room(false)
	elif event.is_action_pressed("toggle_inventory"):
		_print_inventory()


func _print_inventory() -> void:
	var p := GameManager.player
	if not (p is Actor) or p.inventory == null:
		return
	var wielded: Dictionary = p.equipment.equipped_items if p.equipment else {}
	if p.inventory.items.is_empty() and wielded.is_empty():
		_append_log("You are empty-handed.", "examine")
		return
	_append_log("You are carrying:", "examine")
	for slot in wielded:
		_append_log("  A %s (wielded)" % wielded[slot].display_name().to_lower(), "examine")
	for inst in p.inventory.items:
		var line: String = ("A " + inst.display_name().to_lower()) if inst.count == 1 else ("%d x %s" % [inst.count, inst.display_name().to_lower()])
		_append_log("  " + line, "examine")


func _refresh_journal() -> void:
	var lines: Array[String] = ["[b]What you know[/b]\n"]
	var by_subject := {}
	for tok in IntelRegistry.journal.values():
		if not by_subject.has(tok.subject):
			by_subject[tok.subject] = []
		by_subject[tok.subject].append(tok)
	for subject in by_subject:
		lines.append("[u]%s[/u]" % (subject.capitalize() if subject != "" else "General"))
		for tok in by_subject[subject]:
			var pct := int(tok.reliability * 100)
			var mark := " [color=red](FALSE)[/color]" if tok.has_tag("debunked") else ""
			var stale := " [color=gray](stale)[/color]" if tok.is_expired() else ""
			lines.append("  • %s — %d%% reliable, %d source(s)%s%s\n    %s" % [tok.title, pct, tok.sources.size(), mark, stale, tok.summary])
	journal_text.text = "\n".join(lines)
