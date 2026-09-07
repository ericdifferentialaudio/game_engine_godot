## Grants intel tokens to the acting faction.
##   {"kind": "intel", "tokens": ["rumor_crypt_location"], "channel": "told", "reliability": 0.6,
##    "once_per_faction": true, "message": "The elder whispers of a crypt to the west."}
## Optional: "debunk": ["token_id"] marks tokens as proven false; "forget": [...] removes them.
class_name IntelInteraction
extends Interaction


func _on_setup() -> void:
	kind = "intel"


func _execute(holder: String, actor: Unit, _target) -> void:
	var rel := float(spec.get("reliability", -1.0))
	# Perception bonus: perceptive heroes judge told/read intel a little better.
	var bonus := 0.0
	if actor and actor.stats.has_stat("perception"):
		bonus = float(GameManager.rule("intel.perception_reliability_per_point", 0.02)) * actor.stats.get_value("perception")
	for tok in spec.get("tokens", []):
		var t := IntelRegistry.acquire(holder, tok, source_id(), spec.get("channel", "told"), rel)
		if t and bonus > 0.0:
			t.reliability = clampf(t.reliability + bonus, 0.0, 1.0)
	for tok in spec.get("debunk", []):
		IntelRegistry.debunk(holder, tok)
	for tok in spec.get("forget", []):
		IntelRegistry.forget(holder, tok)
