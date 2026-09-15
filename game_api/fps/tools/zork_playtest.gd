## Automated play-through of the zork package's critical path, run inside the
## real game (windowed or headless):
##   godot --path . -- --game=zork --playtest
## Exercises portals, containers, examine/pickup, the dialogue UI + answer
## mechanic, and live melee combat. Prints narration and quits 0/1.
class_name ZorkPlaytest
extends Node

var _fails: Array[String] = []
var _passes := 0
var _log: Array[String] = []


func run() -> void:
	EventBus.notification.connect(func(t, c): _log.append(t); print("   > [%s] %s" % [c, t]))
	call_deferred("_go")


func _go() -> void:
	await _frames(5)
	_check(MapManager.current_id == "west_of_house", "start in West of House")
	_interact_poi("mailbox")
	_check(_inv().has_item("leaflet"), "leaflet taken from mailbox")
	_check(IntelRegistry.has("know_trophy_case"), "leaflet taught the trophy case rule")

	await _portal("to_north")
	await _portal("to_east")
	_check(MapManager.current_id == "behind_house", "reached Behind House")
	_interact_poi("window_outside")
	_check(GameManager.has_flag("window_open"), "window opened via examine")
	await _portal("window")
	_check(MapManager.current_id == "kitchen", "climbed through the window")
	_interact_poi("kitchen_sack")
	_check(_inv().has_item("garlic") and _inv().has_item("lunch"), "sack gave lunch + garlic")

	await _portal("to_living")
	_interact_poi("living_sword")
	var w := _player().equipment.main_weapon()
	_check(w != null and w.def.id == "elvish_sword", "sword auto-wielded")
	_interact_poi("living_lantern")
	_interact_poi("living_bestiary")
	_check(IntelRegistry.has("know_troll_hates_garlic"), "bestiary taught garlic weakness")
	_interact_poi("living_rug")
	_check(GameManager.has_flag("rug_moved") and IntelRegistry.has("know_trapdoor"), "rug moved -> trapdoor known")
	_interact_poi("living_rug")
	_check(GameManager.has_flag("trapdoor_open"), "trap door opened")
	GameManager._boot._toggle_lantern()
	_check(_inv().has_item("brass_lantern_lit"), "lantern lit with F")
	await _portal("trapdoor")
	_check(MapManager.current_id == "cellar", "descended to the cellar")
	_check(MapManager.current_map.is_lit(), "cellar is lit by the lantern")
	_interact_poi("cellar_carving")
	var tok := IntelRegistry.get_token("know_troll_name")
	_check(tok != null and tok.reliability >= 0.5, "learned the troll's true name")

	await _portal("to_troll")
	await _troll_room()

	# Onward: passage -> round room -> gallery (thief) -> cyclops room.
	await _portal("to_passage")
	_interact_poi("dead_adventurer")
	_check(_inv().has_item("adventurer_notebook") and IntelRegistry.has("know_thief_true_name"), "notebook names the thief")
	await _portal("to_round")
	await _portal("to_gallery")
	await _gallery()
	await _portal("to_cyclops")
	await _cyclops_room()

	print("")
	for f in _fails:
		print("FAIL  %s" % f)
	print("PLAYTEST: %d checks, %d failed, %d narration lines" % [_passes + _fails.size(), _fails.size(), _log.size()])
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _troll_room() -> void:
	_check(MapManager.current_id == "troll_room", "entered the Troll Room")
	var troll: Actor = MapManager.current_map.actors.get("troll")
	_check(troll != null and not troll.is_dead, "troll spawned")
	if troll == null:
		return
	var east: MapPortal = MapManager.current_map.portals["to_passage"]
	_check(east.is_blocked(), "east passage blocked by the living troll")

	# Talk: "I know your name" -> "Greldok." (correct: we hold the token at 0.85)
	var talk: ActorTalk = troll.get_node("ActorTalk")
	talk._on_interact(_player())
	await _frames(2)
	var ui: DialogueUi = get_tree().get_first_node_in_group("dialogue_ui")
	_check(ui != null and ui.dialogue != null, "dialogue UI opened")
	_check(GameManager.state == GameManager.State.DIALOGUE, "game paused in DIALOGUE state")
	_pick(ui, "'I know your name")
	_pick(ui, "'Greldok.'")
	_check(ui.dialogue != null and ui.dialogue.last_result == "pass", "correct answer accepted")
	_check(GameManager.has_flag("troll_pacified"), "troll pacified by name")
	_check(IntelRegistry.is_debunked("rumor_troll_name_false"), "false name rumour marked FALSE")
	_pick(ui, "Walk past him")
	await _frames(2)
	_check(GameManager.state == GameManager.State.PLAYING, "dialogue closed, back to PLAYING")
	_check(east.is_unlocked() and not east.is_blocked(), "east passage now open (pacified)")

	# Then fight him anyway: face the troll and swing until he drops.
	var p := _player()
	p.global_position = troll.global_position + Vector3(0, 0, 1.6)
	p.look_at(Vector3(troll.global_position.x, p.global_position.y, troll.global_position.z), Vector3.UP)
	var swings := 0
	while not troll.is_dead and swings < 60:
		p.ability_caster.cooldowns.clear()
		p.resources.restore_all()
		p.ability_caster.cast("sword_slash")
		swings += 1
		await _frames(1)
	_check(troll.is_dead, "troll slain in %d swings" % swings)
	_check(GameManager.has_flag("troll_dead"), "troll_dead flag set")
	await _frames(2)
	var looted := false
	for n in MapManager.current_map.get_node("Actors").get_children():
		if n is WorldPickup and n.items.has("bloody_axe"):
			n._on_interact(p)
			looted = _inv().has_item("bloody_axe")
	_check(looted, "bloody axe looted from the remains")
	_check(GameManager.score >= 10, "score recorded (%d)" % GameManager.score)


func _gallery() -> void:
	_check(MapManager.current_id == "gallery", "entered the Gallery")
	var thief: Actor = MapManager.current_map.actors.get("thief")
	_check(thief != null, "thief spawned")
	if thief == null:
		return
	_check(thief.brain is AIBrain and (thief.brain as AIBrain).behaviour.get("wander", false), "thief wanders")
	# Stealing: give ourselves a treasure, stand next to him, let him think.
	_inv().add_item("painting", 1)
	var p := _player()
	p.global_position = thief.global_position + Vector3(1.0, 0, 0)
	var b := thief.brain as AIBrain
	b._steal_ready_at = 0.0
	b._try_steal(Time.get_ticks_msec() / 1000.0)
	_check(not _inv().has_item("painting") and thief.inventory.has_item("painting"), "thief stole the painting")
	# Parley: name him (we hold the notebook token) and get the bar + free egg opening.
	_inv().add_item("jewelled_egg", 1)
	var talk: ActorTalk = thief.get_node("ActorTalk")
	talk._on_interact(p)
	await _frames(2)
	var ui: DialogueUi = get_tree().get_first_node_in_group("dialogue_ui")
	_pick(ui, "Address him by name")
	_pick(ui, "'Tarbel Flathead.'")
	_check(ui.dialogue != null and ui.dialogue.last_result == "pass", "thief's true name accepted")
	_pick(ui, "'Open the egg")
	await _frames(2)
	_check(_inv().has_item("golden_canary"), "thief opened the egg for free")
	_check(IntelRegistry.is_debunked("rumor_thief_name_false"), "Sir Reginald debunked")
	# Once named he no longer steals.
	_inv().add_item("painting", 1)
	b._steal_ready_at = 0.0
	b._try_steal(Time.get_ticks_msec() / 1000.0)
	_check(_inv().has_item("painting"), "named thief no longer steals")
	# Wound him: he stops fighting and parleys instead.
	# He has dodge 0.25, so a single blow can legitimately miss. We are testing
	# the wound *reaction*, not the dodge roll: keep hitting until he is under
	# his 0.35 flee threshold (same retry shape as the troll fight above).
	var blows := 0
	while not thief.is_dead and not thief.health.is_below(0.35) and blows < 40:
		thief.take_damage(DamageInfo.single("true", thief.health.maximum * 0.1, p))
		blows += 1
	await _frames(2)
	_check(GameManager.has_flag("thief_wounded"), "wounded thief flag set")


func _cyclops_room() -> void:
	_check(MapManager.current_id == "cyclops_room", "entered the Cyclops Room")
	var cy: Actor = MapManager.current_map.actors.get("cyclops")
	_check(cy != null, "cyclops spawned")
	if cy == null:
		return
	await _frames(10)
	_check((cy.brain as AIBrain).state != AIBrain.State.CHASE, "cyclops is passive until provoked")
	var stairs: MapPortal = MapManager.current_map.portals["stairs_up"]
	_check(stairs.is_blocked(), "stairs blocked by the cyclops")
	# Feed him lunch + water -> he sleeps.  (We ate none yet: kitchen sack gave lunch, bottle not taken.)
	_inv().add_item("water_bottle", 1)
	var talk: ActorTalk = cy.get_node("ActorTalk")
	talk._on_interact(_player())
	await _frames(2)
	var ui: DialogueUi = get_tree().get_first_node_in_group("dialogue_ui")
	_pick(ui, "Offer him the lunch")
	_check(GameManager.has_flag("cyclops_ate"), "cyclops ate the lunch")
	_pick(ui, "Offer him the bottle of water")
	await _frames(2)
	_check(GameManager.has_flag("cyclops_asleep") and GameManager.has_flag("trapdoor_unbarred"), "cyclops asleep, way up open")
	_check(not stairs.is_blocked() and stairs.is_unlocked(), "stairs passable")
	await _portal("stairs_up")
	_check(MapManager.current_id == "living_room", "climbed back to the Living Room")
	_interact_poi("trophy_case")
	_check(GameManager.score >= 40, "treasures deposited, score %d" % GameManager.score)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("ok    %s" % label)
	else:
		_fails.append(label)
		print("FAIL  %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _player() -> Actor:
	return GameManager.player as Actor


func _inv() -> Inventory:
	return _player().inventory


func _interact_poi(id: String) -> void:
	var poi: PointOfInterest = MapManager.current_map.pois.get(id)
	if poi == null:
		_fails.append("poi '%s' missing on %s" % [id, MapManager.current_id])
		return
	poi._on_interact(_player())


func _portal(id: String) -> void:
	var portal: MapPortal = MapManager.current_map.portals.get(id)
	if portal == null:
		_fails.append("portal '%s' missing on %s" % [id, MapManager.current_id])
		return
	portal._on_interact(_player())
	await _frames(3)


func _pick(ui: DialogueUi, prefix: String) -> void:
	if ui == null or ui.dialogue == null:
		_fails.append("no dialogue open when picking '%s'" % prefix)
		return
	var choices := ui.dialogue.available_choices()
	for i in choices.size():
		if str(choices[i]["text"]).begins_with(prefix):
			ui._pick(i)
			return
	var texts := []
	for c in choices:
		texts.append(c["text"])
	_fails.append("choice '%s' not offered; had %s" % [prefix, str(texts)])

