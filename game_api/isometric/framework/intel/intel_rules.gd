## Data-driven rules that make intel *live* between turns (intel_rules.json).
##
## {
##   "derivations": [
##     {"id": "locate_crypt", "when": {"all": [{"has": "rumor_crypt_west"}, {"has": "rumor_crypt_reeds", "min_reliability": 0.5}]},
##      "grant": "crypt_location", "reliability": 0.8, "once": true}
##   ],
##   "spread": [
##     {"id": "trade_gossip", "channel": "spread", "between": "trade_partners"|"neighbors"|"allies"|"all",
##      "chance": 0.15, "max_secrecy": 0.4, "reliability_loss": 0.2, "categories": ["rumor", "economic"]}
##   ],
##   "contradiction": {"dispute_amount": 0.15, "flag_source_trust_loss": 0.2},
##   "observation": {"unit_sight_reveals_tokens": true}
## }
##
## Derivations run for every holder after each acquisition and at RESOLVE.
## Spread runs at RESOLVE for every pair of factions that match the rule's
## relationship filter. Chance is rolled with the world RNG so games are
## reproducible per seed.
class_name IntelRules
extends RefCounted

var derivations: Array[Dictionary] = []
var spread: Array[Dictionary] = []
var contradiction: Dictionary = {"dispute_amount": 0.15, "flag_source_trust_loss": 0.2}
var observation: Dictionary = {}
var _derived_once: Dictionary = {}   ## "holder|rule_id" -> true


func load_from(d: Dictionary) -> void:
	derivations.assign(d.get("derivations", []))
	spread.assign(d.get("spread", []))
	contradiction.merge(d.get("contradiction", {}), true)
	observation = d.get("observation", {})
	_derived_once.clear()


## Evaluate derivation rules for one holder. Returns ids of tokens granted.
func run_derivations(holder: String, registry: Node) -> Array[String]:
	var granted: Array[String] = []
	for rule in derivations:
		var key := "%s|%s" % [holder, rule.get("id", "")]
		if rule.get("once", true) and _derived_once.has(key):
			continue
		var target: String = rule.get("grant", "")
		if target == "" or registry.has(holder, target):
			continue
		if IntelQuery.evaluate(rule.get("when", {}), holder):
			_derived_once[key] = true
			var tok: IntelToken = registry.acquire(holder, target, rule.get("id", "derivation"), "derived", float(rule.get("reliability", -1.0)))
			if tok:
				granted.append(target)
				EventBus.intel_derived.emit(holder, target, rule.get("id", ""))
	return granted


## Spread step between two holders for one rule; returns tokens spread.
func run_spread_pair(rule: Dictionary, from_holder: String, to_holder: String, registry: Node, rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	var src: IntelJournal = registry.journal_for(from_holder)
	if src == null:
		return out
	var chance := float(rule.get("chance", 0.1))
	var max_secrecy := float(rule.get("max_secrecy", 0.5))
	var loss := float(rule.get("reliability_loss", 0.2))
	var cats: Array = rule.get("categories", [])
	var now := GameClock.now()
	for tok in src.valid_tokens(now):
		if not tok.spreadable or tok.secrecy > max_secrecy:
			continue
		if not cats.is_empty() and tok.category not in cats:
			continue
		if registry.has(to_holder, tok.id):
			continue
		if rng.randf() > chance * (1.0 - tok.secrecy):
			continue
		var rel := maxf(0.05, tok.reliability - loss)
		var got: IntelToken = registry.acquire(to_holder, tok.id, from_holder, rule.get("channel", "spread"), rel, from_holder)
		if got:
			out.append(tok.id)
			EventBus.intel_spread.emit(from_holder, to_holder, tok.id)
	return out


func to_save_data() -> Dictionary:
	return {"derived_once": _derived_once.duplicate()}


func from_save_data(d: Dictionary) -> void:
	_derived_once = d.get("derived_once", {})
