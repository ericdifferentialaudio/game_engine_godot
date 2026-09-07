## Minimal HUD: interaction prompt, notification feed, and a text journal panel.
## Intended to be replaced by a proper themed UI per game; the *signals* it
## listens to are the contract.
class_name Hud
extends CanvasLayer

@onready var prompt_label: Label = $Prompt
@onready var notif_box: VBoxContainer = $Notifications
@onready var journal_panel: PanelContainer = $Journal
@onready var journal_text: RichTextLabel = $Journal/Scroll/Text
@onready var breadcrumb: Label = $Breadcrumb
@onready var vitals: Label = $Vitals


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


func _on_prompt(text: String, visible_: bool) -> void:
	prompt_label.text = "[E] " + text
	prompt_label.visible = visible_


func _on_notification(text: String, category: String) -> void:
	var l := Label.new()
	l.text = "[%s] %s" % [category, text]
	notif_box.add_child(l)
	get_tree().create_timer(4.0).timeout.connect(l.queue_free)


func _on_state(_prev: int, cur: int) -> void:
	journal_panel.visible = cur == GameManager.State.JOURNAL
	if journal_panel.visible:
		_refresh_journal()


func _on_map_loaded(map_id: String, depth: int) -> void:
	var def := MapManager.get_definition(map_id)
	breadcrumb.text = "%s  (depth %d/%d)  •  %s" % [def.display_name if def else map_id, depth, MapManager.max_depth, GameClock.format_time()]


func _process(_delta: float) -> void:
	# Cheap debug vitals line; replaced by a real HUD in M2.
	var p := GameManager.player
	if p is Actor and p.health:
		var parts: Array[String] = ["HP %d/%d" % [p.health.current, p.health.maximum]]
		if p.resources:
			for name in p.resources.pools:
				parts.append("%s %d/%d" % [name.capitalize(), p.resources.get_current(name), p.resources.get_max(name)])
		parts.append(GameClock.format_time())
		vitals.text = "   ".join(parts)


func _refresh_journal() -> void:
	var lines: Array[String] = ["[b]Intel Journal[/b]\n"]
	var by_subject := {}
	for tok in IntelRegistry.journal.values():
		if not by_subject.has(tok.subject):
			by_subject[tok.subject] = []
		by_subject[tok.subject].append(tok)
	for subject in by_subject:
		lines.append("[u]%s[/u]" % (subject if subject != "" else "General"))
		for tok in by_subject[subject]:
			var pct := int(tok.reliability * 100)
			var stale := " [color=gray](stale)[/color]" if tok.is_expired() else ""
			lines.append("  • %s — %d%% reliable, %d source(s)%s\n    %s" % [tok.title, pct, tok.sources.size(), stale, tok.summary])
	journal_text.text = "\n".join(lines)
