## Strategy HUD: turn/era/clock, faction resources, active faction, End Turn,
## selected unit panel, hovered tile tooltip, notification feed. Driven only by
## EventBus so games can replace the scene without touching gameplay code.
extends CanvasLayer

@onready var _turn_label: Label = %TurnLabel
@onready var _resources_label: Label = %ResourcesLabel
@onready var _end_turn: Button = %EndTurnButton
@onready var _unit_panel: Label = %UnitPanel
@onready var _tile_tooltip: Label = %TileTooltip
@onready var _feed: VBoxContainer = %Feed
@onready var _journal: Control = %JournalPanel
@onready var _dialogue: Control = %DialoguePanel


func _ready() -> void:
	EventBus.turn_started.connect(func(_t): _refresh_turn())
	EventBus.turn_phase_changed.connect(func(_t, _p): _refresh_turn())
	EventBus.active_faction_changed.connect(func(_f): _refresh_turn())
	EventBus.clock_tick.connect(func(_t, _d): _refresh_turn())
	EventBus.clock_paused.connect(func(_p): _refresh_turn())
	EventBus.faction_resource_changed.connect(func(_f, _r, _a): _refresh_resources())
	EventBus.game_started.connect(func(_g): _refresh_all())
	EventBus.load_completed.connect(func(_s): _refresh_all())
	EventBus.unit_selected.connect(func(_u): _refresh_unit())
	EventBus.unit_deselected.connect(func(_u): _refresh_unit())
	EventBus.unit_action_points_changed.connect(func(_u, _r): _refresh_unit())
	EventBus.unit_stat_changed.connect(func(_u, _s, _v, _m): _refresh_unit())
	EventBus.tile_hovered.connect(_on_tile_hovered)
	EventBus.notification.connect(_on_notification)
	EventBus.game_state_changed.connect(_on_state_changed)
	EventBus.intel_acquired.connect(_on_intel_acquired)
	_end_turn.pressed.connect(func(): TurnManager.commit_faction(GameManager.player_faction_id))
	_journal.visible = false
	_dialogue.visible = false


func _refresh_all() -> void:
	_refresh_turn()
	_refresh_resources()
	_refresh_unit()


func _refresh_turn() -> void:
	var text := "Turn %d  ·  %s  ·  %s" % [GameClock.turn, GameClock.year_label(), GameClock.era_label()]
	text += "\n%s / %s" % [TurnManager.mode_name(), TurnManager.phase_name()]
	if TurnManager.mode == TurnManager.Mode.SEQUENTIAL and TurnManager.active_faction_id != "":
		var f := FactionRegistry.get_faction(TurnManager.active_faction_id)
		text += "  ·  %s" % (f.definition.display_name if f else TurnManager.active_faction_id)
	if TurnManager.mode == TurnManager.Mode.REALTIME_PAUSE:
		text += "  ·  tick %d/%d %s" % [GameClock.tick, GameClock.ticks_per_turn, "(paused)" if GameClock.paused else ""]
	if TurnManager.time_left() >= 0.0:
		text += "  ·  %.0fs" % TurnManager.time_left()
	_turn_label.text = text
	_end_turn.disabled = not TurnManager.is_faction_active(GameManager.player_faction_id)


func _refresh_resources() -> void:
	var f := FactionRegistry.player()
	if f == null:
		_resources_label.text = ""
		return
	var parts := PackedStringArray()
	for k in f.resources:
		parts.append("%s %d" % [k.capitalize(), int(f.resources[k])])
	_resources_label.text = "%s   |   %s" % [f.definition.display_name, "   ".join(parts)]


func _refresh_unit() -> void:
	var u := EntityRegistry.selected()
	if u == null:
		_unit_panel.text = ""
		return
	var lines := PackedStringArray(["%s  (Lv %d %s)" % [u.display_name(), u.level, u.definition.kind]])
	for s in u.stats.base:
		lines.append("%s: %d/%d" % [s, int(u.stats.get_value(s)), int(u.stats.max_value(s))])
	lines.append("AP: %.1f" % u.action_points)
	if not u.inventory.items.is_empty():
		lines.append("Items: %s" % ", ".join(u.inventory.items.keys()))
	_unit_panel.text = "\n".join(lines)


func _on_tile_hovered(c: Vector2i) -> void:
	var world := WorldManager.world
	var t := world.get_tile(c) if world else null
	if t == null:
		_tile_tooltip.text = ""
		return
	if not world.is_explored(GameManager.player_faction_id, c):
		_tile_tooltip.text = "(%d,%d) Unexplored" % [c.x, c.y]
		return
	var lines := PackedStringArray(["(%d,%d) %s" % [c.x, c.y, t.terrain.display_name]])
	if not t.features.is_empty():
		lines.append("Features: %s" % ", ".join(t.features))
	if t.owner_id != "":
		lines.append("Owner: %s" % t.owner_id)
	var site := WorldManager.site_at(c)
	if site and site.is_revealed_to(GameManager.player_faction_id):
		lines.append("Site: %s" % site.definition.display_name)
	for u in world.units_at(c):
		if u.visible:
			lines.append("Unit: %s [%s]" % [u.display_name(), u.faction_id])
	_tile_tooltip.text = "\n".join(lines)


func _on_notification(text: String, category: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = {"warning": Color(1, 0.7, 0.3), "discovery": Color(0.6, 0.9, 1), "success": Color(0.6, 1, 0.6), "intel": Color(1, 0.9, 0.5)}.get(category, Color.WHITE)
	_feed.add_child(l)
	if _feed.get_child_count() > 8:
		_feed.get_child(0).queue_free()
	get_tree().create_timer(6.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())


func _on_intel_acquired(holder: String, token_id: String, _source: String) -> void:
	if holder != GameManager.player_faction_id:
		return
	var tok := IntelRegistry.get_token(holder, token_id)
	if tok:
		_on_notification("Intel: %s (%.0f%%)" % [tok.title, tok.reliability * 100.0], "intel")


func _on_state_changed(_prev: int, cur: int) -> void:
	_journal.visible = cur == GameManager.State.JOURNAL
	if _journal.visible and _journal.has_method("refresh"):
		_journal.refresh()
	if cur != GameManager.State.DIALOGUE:
		_dialogue.visible = false
