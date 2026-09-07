## Zork-specific rules, loaded by GameManager via game.json "boot_script".
##
##  * F toggles the brass lantern (swaps brass_lantern <-> brass_lantern_lit,
##    which is what MapRoot.is_lit() checks via game.json "light_sources").
##  * Wandering a dark room without light for too long gets you eaten by a grue.
##  * The elvish sword narrates its glow when an enemy is in the room.
##  * Auto-wield: picking up a weapon while unarmed equips it.
##  * Consumables: G eats garlic (sets the reeks_of_garlic flag the troll checks).
extends Node

const GRUE_GRACE_SECONDS := 9.0
const GRUE_WARNING_AT := 4.0

var _dark_timer := 0.0
var _warned := false
var _sword_glow_state := ""


func boot(_gm: Node) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.map_loaded.connect(_on_map_loaded)
	EventBus.item_acquired.connect(_on_item_acquired)
	EventBus.actor_died.connect(_on_actor_died)
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.status_removed.connect(_on_status_removed)


func _on_map_loaded(map_id: String, _depth: int) -> void:
	_dark_timer = 0.0
	_warned = false
	_sword_glow_state = ""
	if map_id == GameManager.game_config.get("start_map", "") and GameManager.moves == 0:
		EventBus.notification.emit("ZORK I: The Great Underground Empire — re-imagined in three dimensions. The grue remains unrendered on purpose.", "room")
		EventBus.notification.emit("Controls: WASD move · mouse look · E interact/talk · LMB attack · F lantern · G eat garlic · H eat lunch · L look · I inventory · J journal · 1-9 dialogue.", "examine")


func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	var map := MapManager.current_map
	if map == null or not map.has_method("is_lit"):
		return
	_update_sword_glow()
	if map.is_lit():
		if _dark_timer > 0.0:
			_dark_timer = 0.0
			_warned = false
		return
	_dark_timer += delta
	if not _warned and _dark_timer >= GRUE_WARNING_AT:
		_warned = true
		EventBus.notification.emit("You hear a soft, wet shuffling somewhere close. It is very dark. Something is deciding.", "warning")
	if _dark_timer >= GRUE_GRACE_SECONDS:
		_eaten_by_grue()


func _eaten_by_grue() -> void:
	_dark_timer = -INF
	var player := GameManager.player
	if player is Actor and not (player as Actor).is_dead:
		EventBus.notification.emit("Oh, no! You have walked into the slavering fangs of a lurking grue!", "death")
		var info := DamageInfo.single("true", 9999.0, null)
		info.can_be_dodged = false
		(player as Actor).take_damage(info)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_F:
			_toggle_lantern()
			get_viewport().set_input_as_handled()
		KEY_G:
			_consume("garlic", "eat_garlic")
			get_viewport().set_input_as_handled()
		KEY_H:
			_consume("lunch", "eat_lunch")
			get_viewport().set_input_as_handled()


func _consume(item_id: String, ability_id: String) -> void:
	var player := GameManager.player
	var inv := Shop.inventory_of(player)
	if inv == null or not inv.has_item(item_id):
		EventBus.notification.emit("You have no %s." % item_id, "examine")
		return
	if player is Actor and (player as Actor).ability_caster:
		var caster := (player as Actor).ability_caster
		caster.learn(ability_id)
		if caster.cast(ability_id):
			inv.remove_item(item_id, 1)
			if item_id == "lunch":
				EventBus.notification.emit("Thank you very much. It really hit the spot.", "examine")


func _toggle_lantern() -> void:
	var inv := Shop.inventory_of(GameManager.player)
	if inv == null:
		return
	if inv.has_item("brass_lantern"):
		inv.remove_item("brass_lantern", 1)
		inv.add_item("brass_lantern_lit", 1)
		EventBus.notification.emit("The brass lantern is now on.", "examine")
		var map := MapManager.current_map
		if map and map.get("definition") != null and map.definition.dark:
			var hud := get_tree().current_scene.get_node_or_null("HUD")
			if hud and hud.has_method("describe_room"):
				hud.describe_room(false)
	elif inv.has_item("brass_lantern_lit"):
		inv.remove_item("brass_lantern_lit", 1)
		inv.add_item("brass_lantern", 1)
		EventBus.notification.emit("The brass lantern is now off.", "examine")
		var map := MapManager.current_map
		if map and map.has_method("is_lit") and not map.is_lit():
			EventBus.notification.emit("It is now pitch black. You are likely to be eaten by a grue.", "warning")
	else:
		EventBus.notification.emit("You have no lantern to light. You do have a lot of confidence, though.", "examine")


## Picking up a weapon while unarmed wields it.
func _on_item_acquired(item_id: String, _count: int) -> void:
	var player := GameManager.player
	if not (player is Actor):
		return
	var a := player as Actor
	if a.equipment == null or a.inventory == null:
		return
	var def := DefinitionRegistry.get_def("items", item_id) as ItemDefinition
	if def and def.is_weapon() and a.equipment.main_weapon() == null:
		var inst := a.inventory.find_first(item_id)
		if inst and a.equipment.equip(inst):
			EventBus.notification.emit("You are now wielding the %s." % def.display_name.to_lower(), "examine")


func _update_sword_glow() -> void:
	var player := GameManager.player
	if not (player is Actor):
		return
	var a := player as Actor
	var weapon := a.equipment.main_weapon() if a.equipment else null
	if weapon == null or weapon.def.id != "elvish_sword":
		return
	var nearest := INF
	for other in get_tree().get_nodes_in_group("actors"):
		if other == a or not (other is Actor) or other.is_dead:
			continue
		if other.faction and other.faction.faction_id in ["trolls", "thieves"]:
			nearest = minf(nearest, a.global_position.distance_to(other.global_position))
	var state := "off"
	if nearest < 4.0:
		state = "bright"
	elif nearest < 12.0:
		state = "faint"
	if state != _sword_glow_state:
		var first := _sword_glow_state == ""
		_sword_glow_state = state
		match state:
			"bright": EventBus.notification.emit("Your sword has begun to glow very brightly.", "warning")
			"faint": EventBus.notification.emit("Your sword is glowing with a faint blue glow.", "warning")
			"off":
				if not first:
					EventBus.notification.emit("Your sword is no longer glowing.", "examine")


func _on_actor_died(actor: Node3D, killer: Node3D) -> void:
	if not (actor is Actor) or (actor as Actor).is_player():
		return
	var id: String = (actor as Actor).actor_def.id if (actor as Actor).actor_def else ""
	if id == "troll" and killer is Actor and (killer as Actor).is_player():
		EventBus.notification.emit("Almost as soon as the troll breathes his last breath, a cloud of sinister black fog envelops him, and when the fog lifts, the carcass has disappeared. His axe remains.", "combat")
		GameManager.add_score(10, "kill:troll")
	elif id == "thief":
		EventBus.notification.emit("The thief, badly wounded, sinks to the floor. 'Do... mind... the grue.' His bag falls open; a platinum bar rolls out.", "combat")
		GameManager.add_score(10, "kill:thief")


func _on_status_applied(actor: Node3D, effect_id: String) -> void:
	if effect_id == "reeks_of_garlic" and actor is Actor and (actor as Actor).is_player():
		GameManager.set_flag("reeks_of_garlic", true)
		EventBus.notification.emit("You eat the garlic. It is unpleasant. You now reek magnificently, and will for some time.", "examine")


func _on_status_removed(actor: Node3D, effect_id: String) -> void:
	if effect_id == "reeks_of_garlic" and actor is Actor and (actor as Actor).is_player():
		GameManager.set_flag("reeks_of_garlic", false)

