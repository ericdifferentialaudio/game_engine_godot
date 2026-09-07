## Branching dialogue. Nodes can grant intel, run effects, set flags, gate choices.
##   {"kind": "dialogue", "start": "greet", "speaker": "Elder Maren", "portrait": "portrait.maren", "nodes": {
##      "greet": {"text": "Welcome, traveller.", "choices": [
##          {"text": "Heard any rumours?", "next": "rumour", "requires": {"has": "met_innkeeper"}},
##          {"text": "Farewell.", "next": null}]},
##      "rumour": {"text": "Bandits camp north of the old bridge.",
##                 "grant_intel": ["rumor_bandit_camp"], "set_flags": ["asked_rumour"],
##                 "effects": [{"kind": "reward", "resources": {"gold": -5}}], "next": null}
##   }}
## Presentation is delegated to a node in group "dialogue_ui" implementing
## open(dialogue); logic (grants/flags) stays here so it is testable headless.
class_name DialogueInteraction
extends Interaction

var nodes: Dictionary = {}
var current: String = ""
var holder: String = ""
var actor: Unit = null


func _on_setup() -> void:
	kind = "dialogue"
	nodes = spec.get("nodes", {})


func speaker() -> String:
	return spec.get("speaker", site.definition.display_name if site else "")


func _execute(p_holder: String, p_actor: Unit, _target) -> void:
	holder = p_holder
	actor = p_actor
	current = spec.get("start", "")
	EventBus.dialogue_started.emit(source_id())
	_enter(current)
	var tree := actor.get_tree() if actor and actor.is_inside_tree() else null
	var ui := tree.get_first_node_in_group("dialogue_ui") if tree else null
	if holder == GameManager.player_faction_id and ui and ui.has_method("open"):
		ui.open(self)
	else:
		# Headless / AI: auto-walk the first available choice so effects still apply.
		var guard := 0
		while current != "" and guard < 64:
			guard += 1
			var choices := available_choices()
			if choices.is_empty():
				break
			choose(0)
		end()


func current_text() -> String:
	return nodes.get(current, {}).get("text", "")


func available_choices() -> Array:
	var out := []
	for c in nodes.get(current, {}).get("choices", []):
		var req: Dictionary = c.get("requires", {})
		if req.is_empty() or IntelRegistry.evaluate(req, holder):
			out.append(c)
	return out


func choose(index: int) -> void:
	var choices := available_choices()
	if index < 0 or index >= choices.size():
		current = ""
		return
	var nxt = choices[index].get("next", null)
	current = str(nxt) if nxt != null else ""
	if current != "":
		_enter(current)


func is_finished() -> bool:
	return current == "" or (available_choices().is_empty() and nodes.get(current, {}).get("next", null) == null)


func end() -> void:
	current = ""
	EventBus.dialogue_ended.emit(source_id())


func _enter(node_id: String) -> void:
	var node: Dictionary = nodes.get(node_id, {})
	for tok in node.get("grant_intel", []):
		IntelRegistry.acquire(holder, tok, source_id(), "told")
	for flag in node.get("set_flags", []):
		GameManager.set_flag(flag, true)
	var f := FactionRegistry.get_faction(holder)
	if f:
		for flag in node.get("set_faction_flags", []):
			f.set_flag(flag, true)
	for eff in node.get("effects", []):
		var inter := InteractionFactory.create(eff, site if site else actor)
		if inter:
			inter.run_for_holder(holder, source_id(), actor)
	# Linear "next" without choices: advance automatically.
	if node.get("choices", []).is_empty() and node.get("next", null) != null:
		current = str(node["next"])
		_enter(current)
