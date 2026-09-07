## One link in an intel token's chain of custody: who told whom, how, when,
## and how much the receiver trusted that channel.
##
## Enables: lie detection (a source later proven false lowers trust in every
## token it provided), espionage attribution, and "where did I hear this?" UI.
class_name Provenance
extends RefCounted

## How the holder came by the token.
const CHANNELS := ["observed", "told", "read", "traded", "stolen", "spread", "derived", "scripted"]

var source_id: String = ""     ## Unit/site/faction/item id that provided it ("" = unknown).
var channel: String = "told"
var turn: float = 0.0
var trust: float = 1.0         ## 0..1 multiplier applied to corroboration.
var via_holder: String = ""    ## Faction the info passed through (spread/trade).
var note: String = ""


static func make(p_source: String, p_channel: String, p_turn: float, p_trust: float = 1.0, p_via: String = "") -> Provenance:
	var p := Provenance.new()
	p.source_id = p_source
	p.channel = p_channel if p_channel in CHANNELS else "told"
	p.turn = p_turn
	p.trust = clampf(p_trust, 0.0, 1.0)
	p.via_holder = p_via
	return p


func to_dict() -> Dictionary:
	return {"source": source_id, "channel": channel, "turn": turn, "trust": trust, "via": via_holder, "note": note}


static func from_dict(d: Dictionary) -> Provenance:
	var p := make(d.get("source", ""), d.get("channel", "told"), float(d.get("turn", 0.0)), float(d.get("trust", 1.0)), d.get("via", ""))
	p.note = d.get("note", "")
	return p
