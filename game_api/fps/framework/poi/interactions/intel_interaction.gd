## Grants one or more intel tokens.
##   {"kind": "intel", "tokens": ["rumor_bandit_camp"], "reliability": 0.6,
##    "message": "The innkeeper leans in...", "once": true}
class_name IntelInteraction
extends Interaction


func _on_setup() -> void:
	kind = "intel"


func _execute(_by: Node) -> void:
	var reliability := float(spec.get("reliability", -1.0))
	var poi_id: String = poi.definition.id if poi and "definition" in poi else ""
	for token_id in spec.get("tokens", []):
		IntelRegistry.acquire(token_id, poi_id, reliability)
	var msg: String = spec.get("message", "")
	if msg != "":
		EventBus.notification.emit(msg, "intel")
