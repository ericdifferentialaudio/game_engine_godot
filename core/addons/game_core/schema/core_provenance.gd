## One link in an intel token's chain of custody: who told whom, how, when,
## and how much the receiver trusted that channel.
##
## Enables lie detection (a source later proven false lowers trust in every
## token it provided), espionage attribution, and "where did I hear this?" UI.
## [member at] is a timestamp in the host engine's own time unit (turn number
## for the isometric engine, game seconds for the FPS engine).
class_name CoreProvenance
extends RefCounted

## How the holder came by the token.
const CHANNELS := ["observed", "told", "read", "traded", "stolen", "spread", "derived", "scripted"]

var source_id: String = ""     ## Unit/site/faction/item id that provided it ("" = unknown).
var channel: String = "told"
var at: float = 0.0
var trust: float = 1.0         ## 0..1 multiplier applied to corroboration.
var via_holder: String = ""    ## Holder the info passed through (spread/trade).
var note: String = ""


static func make(p_source: String, p_channel: String, p_at: float, p_trust: float = 1.0, p_via: String = "") -> CoreProvenance:
	var p := CoreProvenance.new()
	p.source_id = p_source
	p.channel = p_channel if p_channel in CHANNELS else "told"
	p.at = p_at
	p.trust = clampf(p_trust, 0.0, 1.0)
	p.via_holder = p_via
	return p


func to_dict() -> Dictionary:
	return {"source": source_id, "channel": channel, "at": at,
		"trust": trust, "via": via_holder, "note": note}


static func from_dict(d: Dictionary) -> CoreProvenance:
	var p := make(d.get("source", ""), d.get("channel", "told"),
		float(d.get("at", d.get("turn", 0.0))), float(d.get("trust", 1.0)), d.get("via", ""))
	p.note = d.get("note", "")
	return p
