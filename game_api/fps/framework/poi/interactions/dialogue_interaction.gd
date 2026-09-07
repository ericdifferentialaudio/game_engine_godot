## Branching dialogue tied to the intel system.
##
## Nodes:
##   "greet": {"speaker": "Troll", "text": "...", "choices": [...],
##             "grant_intel": ["tok"] | [{"token": "tok", "reliability": 0.9}],
##             "debunk": ["false_tok"], "set_flags": [...], "clear_flags": [...],
##             "score": 5, "reputation": {"trolls": -10}, "hostile": true,
##             "give_items": {"axe": 1}, "take_items": {"lunch": 1},
##             "next": "other_node" | null}
## Choices:
##   {"text": "Say 'Odysseus'.", "next": "flee",
##    "requires": <IntelQuery>,          # only offered if the query passes
##    "requires_item": {"lunch": 1},     # only offered if carried
##    "consume_item": true,              # ...and removed when chosen
##    "check": <IntelQuery>,             # THE ANSWER MECHANIC: on pick, verify what
##    "next_pass": "n1", "next_fail": "n2",   # the player actually knows and route
##    "correct": true|false}             # optional: marks the truthful answer
##
## A choice with a "check" is how the game asks "do you really know this?": the
## text is always offered, but whether it *works* depends on the journal — a
## bluff with no token (or a stale/low-reliability one) fails.
##
## Presentation is delegated to a node in group "dialogue_ui" implementing
## open(dialogue: DialogueInteraction); logic stays here so it is testable.
class_name DialogueInteraction
extends Interaction

signal node_entered(node_id: String)
signal finished

var nodes: Dictionary = {}
var current: String = ""
var last_result: String = ""      ## "", "pass" or "fail" after the last choice with a check
var _by: Node = null


func _on_setup() -> void:
	kind = "dialogue"
	nodes = spec.get("nodes", {})


func _execute(by: Node) -> void:
	_by = by
	last_result = ""
	current = spec.get("start", "")
	_enter(current)
	var ui := by.get_tree().get_first_node_in_group("dialogue_ui") if by and by.is_inside_tree() else null
	if ui and ui.has_method("open"):
		ui.open(self)
	else:
		# Headless: auto-walk the first available choice so effects still apply.
		var guard := 0
		while current != "" and guard < 64:
			guard += 1
			if available_choices().is_empty():
				if nodes.get(current, {}).get("next", null) == null:
					break
				advance()
				continue
			choose(0)
		finish()


func speaker() -> String:
	var n: Dictionary = nodes.get(current, {})
	if n.has("speaker"):
		return str(n["speaker"])
	if spec.has("speaker"):
		return str(spec["speaker"])
	if poi and "definition" in poi and poi.definition:
		return str(poi.definition.display_name)
	return ""


func current_text() -> String:
	return str(nodes.get(current, {}).get("text", ""))


func is_finished() -> bool:
	return current == ""


## Choices the player may pick right now (knowledge- and item-gated).
func available_choices() -> Array:
	var out := []
	var inv := Shop.inventory_of(_by) if _by else null
	for c in nodes.get(current, {}).get("choices", []):
		var req: Dictionary = c.get("requires", {})
		if not req.is_empty() and not IntelRegistry.evaluate(req):
			continue
		var need: Dictionary = c.get("requires_item", {})
		var have := true
		for item_id in need:
			if inv == null or not inv.has_item(str(item_id), int(need[item_id])):
				have = false
		if have:
			out.append(c)
	return out


## Pick a choice by index into available_choices().
func choose(index: int) -> void:
	var choices := available_choices()
	if index < 0 or index >= choices.size():
		current = ""
		return
	var c: Dictionary = choices[index]
	last_result = ""
	var inv := Shop.inventory_of(_by) if _by else null
	if c.get("consume_item", false) and inv:
		var need: Dictionary = c.get("requires_item", {})
		for item_id in need:
			inv.remove_item(str(item_id), int(need[item_id]))
	for flag in c.get("set_flags", []):
		GameManager.set_flag(str(flag), true)
	var nxt = c.get("next", null)
	if c.has("check"):
		var passed := IntelRegistry.evaluate(c["check"])
		last_result = "pass" if passed else "fail"
		nxt = c.get("next_pass", nxt) if passed else c.get("next_fail", nxt)
	current = str(nxt) if nxt != null else ""
	if current != "":
		_enter(current)


## Advance past a node that has no choices (Continue button).
func advance() -> void:
	var nxt = nodes.get(current, {}).get("next", null)
	current = str(nxt) if nxt != null else ""
	if current != "":
		_enter(current)


func finish() -> void:
	current = ""
	finished.emit()


func _enter(node_id: String) -> void:
	var node: Dictionary = nodes.get(node_id, {})
	if node.is_empty():
		push_warning("DialogueInteraction: unknown node '%s'" % node_id)
		current = ""
		return
	var poi_id: String = poi.definition.id if poi and "definition" in poi and poi.definition else ""
	for tok in node.get("grant_intel", []):
		if tok is Dictionary:
			IntelRegistry.acquire(str(tok.get("token", "")), poi_id, float(tok.get("reliability", -1.0)))
		else:
			IntelRegistry.acquire(str(tok), poi_id)
	for tok in node.get("debunk", []):
		IntelRegistry.debunk(str(tok), poi_id)
	for flag in node.get("set_flags", []):
		GameManager.set_flag(str(flag), true)
	for flag in node.get("clear_flags", []):
		GameManager.set_flag(str(flag), false)
	if node.has("score"):
		GameManager.add_score(int(node["score"]), "dialogue:%s:%s" % [poi_id, node_id])
	for faction_id in node.get("reputation", {}):
		GameManager.change_reputation(str(faction_id), int(node["reputation"][faction_id]))
	var inv := Shop.inventory_of(_by) if _by else null
	if inv:
		for item_id in node.get("give_items", {}):
			inv.add_item(str(item_id), int(node["give_items"][item_id]))
		for item_id in node.get("take_items", {}):
			inv.remove_item(str(item_id), int(node["take_items"][item_id]))
	if node.get("hostile", false):
		_make_hostile()
	if node.get("despawn", false):
		_despawn_speaker()
	node_entered.emit(node_id)


## The speaker attacks: works when the dialogue is attached to an Actor.
func _make_hostile() -> void:
	var owner_actor := _owner_actor()
	if owner_actor and _by is Actor:
		if owner_actor.faction:
			owner_actor.faction.make_personal_enemy(_by)
		if owner_actor.brain is AIBrain:
			var b := owner_actor.brain as AIBrain
			b.target = _by
			b.set_state(AIBrain.State.CHASE)
	EventBus.notification.emit("%s attacks!" % speaker(), "combat")


## The speaker leaves (flees, vanishes). Recorded like a kill so it stays gone.
func _despawn_speaker() -> void:
	var owner_actor := _owner_actor()
	if owner_actor:
		owner_actor.corpse_seconds = 0.5
		owner_actor.is_dead = true
		if owner_actor.spawned_by_map != "":
			var st := MapManager.get_map_state(owner_actor.spawned_by_map)
			if not st.has("killed"):
				st["killed"] = []
			if not st["killed"].has(owner_actor.spawn_key):
				st["killed"].append(owner_actor.spawn_key)
		owner_actor.collision_layer = 0
		owner_actor.get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(owner_actor): owner_actor.queue_free())


func _owner_actor() -> Actor:
	if poi is ActorTalk:
		return (poi as ActorTalk).actor
	return null
