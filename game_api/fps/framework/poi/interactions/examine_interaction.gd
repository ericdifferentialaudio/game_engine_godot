## "LOOK AT" something. Narrates text and may teach intel / set flags.
##   {"kind": "examine", "text": "A small leaflet.", "grant_intel": ["lore_leaflet"],
##    "set_flags": ["read_leaflet"], "reliability": 1.0, "once": false, "consumes": false}
## Alternate text may be keyed on a flag: "text_if": [{"flag": "rug_moved", "text": "..."}]
class_name ExamineInteraction
extends Interaction


func _on_setup() -> void:
	kind = "examine"
	consumes_interaction = spec.get("consumes", false)


func _execute(_by: Node) -> void:
	var text: String = spec.get("text", "")
	for alt in spec.get("text_if", []):
		var q: Dictionary = alt.get("requires", {})
		if alt.has("flag"):
			q = {"flag": alt["flag"]}
		if not q.is_empty() and IntelRegistry.evaluate(q):
			text = str(alt.get("text", text))
	if text != "":
		EventBus.notification.emit(text, "examine")
	var poi_id: String = poi.definition.id if poi and "definition" in poi and poi.definition else ""
	var reliability := float(spec.get("reliability", -1.0))
	for tok in spec.get("grant_intel", []):
		IntelRegistry.acquire(str(tok), poi_id, reliability)
	for flag in spec.get("set_flags", []):
		GameManager.set_flag(str(flag), true)
	if spec.has("score"):
		GameManager.add_score(int(spec["score"]), "examine:%s:%d" % [poi_id, spec.get("index", 0)])
