## Starts a dialogue tree, optionally granting intel up front.
##
##   {"kind": "dialogue", "dialogue": "elder_maren", "tokens": ["met_elder_maren"],
##    "once_per_holder": true}
##
## Dialogue presentation is engine-specific; the knowledge side effects are not.
class_name CoreDialogueInteraction
extends CoreInteraction

signal started(holder: String, dialogue_id: String)


func _on_setup() -> void:
	kind = "dialogue"


func _execute(holder: String, actor, _target) -> void:
	# Meeting someone is itself information.
	for tok in spec.get("tokens", []):
		CoreIntel.acquire(holder, str(tok), owner_id, str(spec.get("channel", "told")))

	var dialogue_id := str(spec.get("dialogue", spec.get("tree", "")))
	if dialogue_id != "" and CoreContext.adapter.start_dialogue(holder, dialogue_id, actor):
		started.emit(holder, dialogue_id)
