## Grants, debunks or forgets intel tokens for the acting holder.
##
##   {"kind": "intel", "tokens": ["rumor_crypt_west"], "channel": "told",
##    "reliability": 0.6, "once_per_holder": true,
##    "message": "The elder whispers of a crypt to the west."}
##
## Optional:
##   debunk: ["token_id"]   mark as proven false (also penalises its sources)
##   forget: ["token_id"]   remove outright
##   share:  {"to": "greywood", "tokens": [...]}   scripted leak to another holder
class_name CoreIntelInteraction
extends CoreInteraction


func _on_setup() -> void:
	kind = "intel"


func _execute(holder: String, actor, _target) -> void:
	var trust := float(spec.get("reliability", spec.get("trust", 1.0)))
	var channel := str(spec.get("channel", "told"))

	# Perceptive characters judge told/read intel a little better. The stat is
	# read through the adapter so this works in either engine (or headless).
	var bonus := 0.0
	var stats := _stats_of(actor)
	if stats != null and stats.has_stat("perception"):
		var per_point := float(CoreContext.rule("intel.perception_reliability_per_point", 0.02))
		bonus = per_point * stats.get_value("perception")

	for tok in spec.get("tokens", []):
		var token_id := str(tok)
		if CoreIntel.acquire(holder, token_id, owner_id, channel, trust) and bonus > 0.0:
			var t := CoreIntel.journal_for(holder).get_token(token_id)
			if t:
				t.reliability = clampf(t.reliability + bonus, 0.0, 1.0)

	for tok in spec.get("debunk", []):
		CoreIntel.debunk(holder, str(tok))
	for tok in spec.get("forget", []):
		CoreIntel.forget(holder, str(tok))

	if spec.has("share"):
		var s: Dictionary = spec["share"]
		var to := str(s.get("to", ""))
		for tok in s.get("tokens", []):
			CoreIntel.give(holder, to, str(tok))


func _stats_of(actor) -> CoreStats:
	if actor != null and actor is Object and "stats" in actor and actor.stats is CoreStats:
		return actor.stats
	return null
