## Simple branching dialogue. Nodes can grant intel, set flags, or gate choices.
##   {"kind": "dialogue", "start": "greet", "nodes": {
##      "greet": {"text": "Welcome, traveller.", "choices": [
##          {"text": "Heard any rumours?", "next": "rumour", "requires": {"has": "met_innkeeper"}},
##          {"text": "Farewell.", "next": null}]},
##      "rumour": {"text": "Bandits camp north of the old bridge.",
##                 "grant_intel": ["rumor_bandit_camp"], "set_flags": ["asked_rumour"], "next": null}
##   }}
## Presentation is delegated to a node in group "dialogue_ui" implementing
## open(dialogue: DialogueInteraction); logic (grants/flags) stays here so it is
## testable without UI.
class_name DialogueInteraction
extends Interaction

var nodes: Dictionary = {}
var current: String = ""


func _on_setup() -> void:
	kind = "dialogue"
	nodes = spec.get("nodes", {})


func _execute(by: Node) -> void:
	current = spec.get("start", "")
	_enter(current)
	var ui := by.get_tree().get_first_node_in_group("dialogue_ui") if by else null
	if ui and ui.has_method("open"):
		ui.open(self)
	else:
		# Headless: auto-walk the first available choice so effects still apply.
		while current != "":
			var choices := available_choices()
			if choices.is_empty():
				break
			choose(0)


func current_text() -> String:
	return nodes.get(current, {}).get("text", "")


func available_choices() -> Array:
	var out := []
	for c in nodes.get(current, {}).get("choices", []):
		var req: Dictionary = c.get("requires", {})
		if req.is_empty() or IntelRegistry.evaluate(req):
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


func _enter(node_id: String) -> void:
	var node: Dictionary = nodes.get(node_id, {})
	var poi_id: String = poi.definition.id if poi and "definition" in poi else ""
	for tok in node.get("grant_intel", []):
		IntelRegistry.acquire(tok, poi_id)
	for flag in node.get("set_flags", []):
		GameManager.set_flag(flag, true)
	if node.get("choices", []).is_empty() and node.get("next", null) == null:
		# Leaf without choices: dialogue ends after display.
		pass
