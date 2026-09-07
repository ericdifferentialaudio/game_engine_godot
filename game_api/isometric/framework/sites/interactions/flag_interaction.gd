## Sets/clears progression flags and quest stages; can also change diplomacy or
## transfer intel between factions (scripted leaks).
##   {"kind": "flag", "set_flags": ["bridge_repaired"], "clear_flags": [], "set_faction_flags": ["met_elders"],
##    "quest": {"id": "find_crypt", "stage": "located"},
##    "stance": {"with": "greywood", "stance": "friendly"},
##    "share_intel": {"to": "greywood", "tokens": ["crypt_location"]}}
class_name FlagInteraction
extends Interaction


func _on_setup() -> void:
	kind = "flag"


func _execute(holder: String, _actor: Unit, _target) -> void:
	for f in spec.get("set_flags", []):
		GameManager.set_flag(f, true)
	for f in spec.get("clear_flags", []):
		GameManager.set_flag(f, false)
	var faction := FactionRegistry.get_faction(holder)
	if faction:
		for f in spec.get("set_faction_flags", []):
			faction.set_flag(f, true)
		if spec.has("stance"):
			var s: Dictionary = spec["stance"]
			faction.set_stance(s.get("with", ""), s.get("stance", "peace"))
	if spec.has("quest"):
		var q: Dictionary = spec["quest"]
		GameManager.set_flag("quest.%s.%s" % [q.get("id", ""), q.get("stage", "")], true)
		EventBus.quest_flag_changed.emit(q.get("id", ""), q.get("stage", ""))
	if spec.has("share_intel"):
		var s: Dictionary = spec["share_intel"]
		for tok in s.get("tokens", []):
			IntelRegistry.transfer(holder, s.get("to", ""), tok, "traded", 0)
