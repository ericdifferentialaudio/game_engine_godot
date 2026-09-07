## Data-driven rules that make intel *live* between turns (intel_rules.json).
##
## This is the exchange engine: how knowledge is inferred, propagates between
## holders, and loses trust when contradicted. Pure simulation — it works
## identically in both graphics engines.
##
## {
##   "derivations": [
##     {"id": "triangulate_crypt",
##      "when": {"all": [{"has": "rumor_crypt_west", "min_reliability": 0.5},
##                       {"has": "rumor_crypt_reeds", "min_reliability": 0.5},
##                       {"has": "ruin_inscription"}]},
##      "grant": "crypt_location", "reliability": 0.65, "once": true}
##   ],
##   "spread": [
##     {"id": "trade_gossip", "channel": "spread", "between": "trade_partners",
##      "chance": 0.15, "max_secrecy": 0.35, "reliability_loss": 0.2,
##      "categories": ["rumor", "economic", "location"]}
##   ],
##   "contradiction": {"dispute_amount": 0.15, "flag_source_trust_loss": 0.25},
##   "observation": {"unit_sight_reveals_tokens": true}
## }
##
## Derivations run for a holder after each acquisition and once per turn.
## Spread runs per turn for every holder pair matching the rule's relationship
## filter, resolved through CoreEngineAdapter.related_holders(). All chances
## roll on CoreContext.rng() so a seeded game replays identically.
class_name CoreIntelRules
extends RefCounted

signal derived(holder: String, token_id: String, rule_id: String)
signal spread_occurred(from_holder: String, to_holder: String, token_id: String, rule_id: String)

const DEFAULT_CONTRADICTION := {"dispute_amount": 0.15, "flag_source_trust_loss": 0.2}

var derivations: Array[Dictionary] = []
var spread: Array[Dictionary] = []
var contradiction: Dictionary = DEFAULT_CONTRADICTION.duplicate()
var observation: Dictionary = {}

var _derived_once: Dictionary = {}   ## "holder|rule_id" -> true


func load_from(d: Dictionary) -> void:
	derivations = CoreDataLoader.dict_array(d.get("derivations", []))
	spread = CoreDataLoader.dict_array(d.get("spread", []))
	contradiction = DEFAULT_CONTRADICTION.duplicate()
	contradiction.merge(d.get("contradiction", {}), true)
	observation = d.get("observation", {})
	_derived_once.clear()


func load_file(path: String) -> void:
	load_from(CoreDataLoader.load_json(path))


func reset() -> void:
	_derived_once.clear()


# --- Derivation: inferring new knowledge ---------------------------------------

## Evaluate every derivation rule for one holder. Returns the tokens granted.
## Two rumours plus an inscription can pin a location no single source gave.
func run_derivations(holder: String) -> Array[String]:
	var granted: Array[String] = []
	for rule in derivations:
		var rule_id := str(rule.get("id", ""))
		var key := "%s|%s" % [holder, rule_id]
		if rule.get("once", true) and _derived_once.has(key):
			continue
		var target := str(rule.get("grant", ""))
		if target == "" or CoreIntel.knows(holder, target):
			continue
		if not CoreIntel.evaluate(rule.get("when", {}), holder):
			continue

		_derived_once[key] = true
		# A derivation asserts its own confidence rather than inheriting it.
		var override := float(rule.get("reliability", -1.0))
		if CoreIntel.acquire(holder, target, rule_id, "derived", 1.0, override):
			granted.append(target)
			derived.emit(holder, target, rule_id)
	return granted


## Run derivations for every holder the engine knows about.
func run_all_derivations() -> int:
	var n := 0
	for holder in CoreContext.adapter.all_holders():
		n += run_derivations(holder).size()
	return n


# --- Spread: knowledge leaking between holders -----------------------------------

## Apply one spread rule from one holder to another. Returns tokens transferred.
func run_spread_pair(rule: Dictionary, from_holder: String, to_holder: String) -> Array[String]:
	var out: Array[String] = []
	if from_holder == to_holder or to_holder == "":
		return out
	var journal := CoreIntel.journal_for(from_holder)
	var chance := float(rule.get("chance", 0.1))
	var max_secrecy := float(rule.get("max_secrecy", 0.5))
	var loss := float(rule.get("reliability_loss", 0.2))
	var categories: Array = rule.get("categories", [])
	var channel := str(rule.get("channel", "spread"))
	var rng := CoreContext.rng()

	for tok in journal.known(CoreContext.now()):
		if not tok.spreadable or tok.secrecy > max_secrecy:
			continue
		if not categories.is_empty() and tok.category not in categories:
			continue
		if CoreIntel.knows(to_holder, tok.id):
			continue
		# Secretive information leaks less often, even when it qualifies.
		if rng.randf() > chance * (1.0 - tok.secrecy):
			continue

		# Second-hand knowledge arrives degraded by the rule's loss.
		var degraded := maxf(0.05, tok.reliability - loss)
		if CoreIntel.acquire(to_holder, tok.id, from_holder, channel, 1.0, degraded):
			var got := CoreIntel.journal_for(to_holder).get_token(tok.id)
			if got and not got.provenance.is_empty():
				got.provenance[-1].via_holder = from_holder
			out.append(tok.id)
			spread_occurred.emit(from_holder, to_holder, tok.id, str(rule.get("id", "")))
	return out


## Run every spread rule across every matching holder pair. Call once per turn.
func run_spread() -> int:
	var total := 0
	var holders := CoreContext.adapter.all_holders()
	for rule in spread:
		var relation := str(rule.get("between", "all"))
		for from_holder in holders:
			for to_holder in CoreContext.adapter.related_holders(from_holder, relation):
				total += run_spread_pair(rule, from_holder, to_holder).size()
	return total


# --- Contradiction ------------------------------------------------------------------

## Lower belief in both sides of a contradiction the holder now sees.
func apply_contradiction(holder: String, token_a: String, token_b: String) -> void:
	var amount := float(contradiction.get("dispute_amount", 0.15))
	var journal := CoreIntel.journal_for(holder)
	for id in [token_a, token_b]:
		var tok := journal.get_token(id)
		if tok:
			tok.dispute(amount)


## Full per-turn step: derive, spread, then age out stale tokens.
func tick() -> Dictionary:
	var result := {"derived": run_all_derivations(), "spread": run_spread(), "expired": 0}
	for holder in CoreContext.adapter.all_holders():
		result["expired"] += CoreIntel.prune_stale(holder).size()
	return result


func to_save_data() -> Dictionary:
	return {"derived_once": _derived_once.duplicate()}


func from_save_data(d: Dictionary) -> void:
	_derived_once = d.get("derived_once", {})
