## Inventory panel (I). Lists carried + wielded items; each row offers
## Wield / Unwield, Use (consumables / items with use_ability), Examine and
## Drop (creates a WorldPickup at the player's feet). Pauses the game via
## GameManager.State.JOURNAL-style pause (uses State.PAUSED semantics locally).
class_name InventoryUi
extends CanvasLayer

const FONT_COLOR := Color(0.75, 1.0, 0.75)
const DIM_COLOR := Color(0.45, 0.65, 0.45)

var _panel: PanelContainer
var _rows: VBoxContainer
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build()
	_panel.visible = false
	EventBus.game_state_changed.connect(func(_p, cur): if cur != GameManager.State.PAUSED and _open: _close())


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -260
	_panel.offset_bottom = 260
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.03, 0.0, 0.94)
	style.border_color = DIM_COLOR
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "YOU ARE CARRYING"
	title.add_theme_color_override("font_color", DIM_COLOR)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var hint := Label.new()
	hint.text = "[I / Esc] close"
	hint.add_theme_color_override("font_color", DIM_COLOR)
	box.add_child(hint)


func toggle() -> void:
	if _open:
		_close()
	elif GameManager.state == GameManager.State.PLAYING:
		_open = true
		GameManager.set_state(GameManager.State.PAUSED)
		_panel.visible = true
		_refresh()


func _close() -> void:
	_open = false
	_panel.visible = false
	if GameManager.state == GameManager.State.PAUSED:
		GameManager.set_state(GameManager.State.PLAYING)


func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var p := GameManager.player as Actor
	if p == null:
		return
	if p.equipment:
		for slot in p.equipment.equipped_items:
			_add_row(p.equipment.equipped_items[slot], true, slot)
	for inst in p.inventory.items:
		_add_row(inst, false, "")
	if _rows.get_child_count() == 0:
		var l := Label.new()
		l.text = "You are empty-handed."
		l.add_theme_color_override("font_color", FONT_COLOR)
		_rows.add_child(l)


func _add_row(inst: ItemInstance, wielded: bool, slot: String) -> void:
	var row := HBoxContainer.new()
	var name := Label.new()
	name.text = ("%s (wielded)" % inst.display_name()) if wielded else (inst.display_name() if inst.count == 1 else "%s x%d" % [inst.display_name(), inst.count])
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", FONT_COLOR)
	row.add_child(name)
	row.add_child(_button("Examine", func(): _examine(inst)))
	if inst.def.is_equippable():
		row.add_child(_button("Unwield" if wielded else "Wield", func(): _toggle_wield(inst, wielded, slot)))
	if inst.def.is_usable() and not wielded:
		row.add_child(_button("Use", func(): _use(inst)))
	if not wielded:
		row.add_child(_button("Drop", func(): _drop(inst)))
	_rows.add_child(row)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_color_override("font_color", FONT_COLOR)
	b.pressed.connect(cb)
	return b


func _examine(inst: ItemInstance) -> void:
	var text := inst.def.description if inst.def.description != "" else "There is nothing special about the %s." % inst.display_name().to_lower()
	EventBus.notification.emit(text, "examine")
	if inst.def.lore_intel != "":
		IntelRegistry.acquire(inst.def.lore_intel, "item:%s" % inst.def.id)


func _toggle_wield(inst: ItemInstance, wielded: bool, slot: String) -> void:
	var p := GameManager.player as Actor
	if wielded:
		p.equipment.unequip(slot)
		EventBus.notification.emit("You put away the %s." % inst.display_name().to_lower(), "examine")
	elif p.equipment.equip(inst):
		EventBus.notification.emit("You are now wielding the %s." % inst.display_name().to_lower(), "examine")
	_refresh()


func _use(inst: ItemInstance) -> void:
	var p := GameManager.player as Actor
	if inst.def.use_ability != "" and p.ability_caster:
		p.ability_caster.learn(inst.def.use_ability)
		if p.ability_caster.cast(inst.def.use_ability):
			if inst.def.consumed_on_use:
				p.inventory.remove_item(inst.def.id, 1)
			EventBus.notification.emit("You use the %s." % inst.display_name().to_lower(), "examine")
	_refresh()


func _drop(inst: ItemInstance) -> void:
	var p := GameManager.player as Actor
	var pickup := WorldPickup.new()
	pickup.items = {inst.def.id: inst.count}
	pickup.label = inst.display_name().to_lower()
	pickup.name = "Dropped_%s_%d" % [inst.def.id, Time.get_ticks_msec()]
	p.inventory.remove_instance(inst)
	var map := MapManager.current_map
	var parent: Node = map.get_node_or_null("Actors") if map else null
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(pickup)
	pickup.global_position = p.global_position - p.global_transform.basis.z * 1.2
	if map and map.has_method("register_loot"):
		map.register_loot(pickup, "", pickup.items)
	EventBus.notification.emit("Dropped.", "examine")
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") and GameManager.state in [GameManager.State.PLAYING, GameManager.State.PAUSED]:
		if _open or GameManager.state == GameManager.State.PLAYING:
			toggle()
			get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
