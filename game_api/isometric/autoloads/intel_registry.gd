## The information/intel core of the engine.
##
## Layers:
##  * Definitions – every IntelToken the game *could* grant (intel.json).
##  * Journals    – one IntelJournal per faction holding acquired instances with
##                  runtime reliability, provenance chain and staleness.
##  * Rules       – derivation / spread / contradiction behaviour (intel_rules.json).
##
## Intel is a first-class resource: sites and NPCs emit tokens, tokens reveal
## map knowledge, gate shops/dialogue/sites/abilities via IntelQuery, decay
## over turns, spread between factions, and can be traded, stolen or faked.
extends Node

var definitions: Dictionary = {}   ## token_id -> IntelToken (template)
var journals: Dictionary = {}      ## holder(faction id) -> IntelJournal
var rules := IntelRules.new()

var _spread_rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.turn_phase_changed.connect(_on_turn_phase)


func load_definitions(intel_path: String, rules_path: String = "") -> void:
	definitions.clear()
	for entry in DataLoader.load_json_array(intel_path, "intel"):
		var tok := IntelToken.from_dict(entry)
		if tok.id == "":
			push_error("IntelRegistry: token without id in %s" % intel_path)
			continue
		definitions[tok.id] = tok
	rules = IntelRules.new()
	if rules_path != "" and FileAccess.file_exists(rules_path):
		rules.load_from(DataLoader.load_json(rules_path))


func reset_journals(seed_val: int = 0) -> void:
	journals.clear()
	_spread_rng.seed = seed_val
	rules.from_save_data({})


func get_definition(token_id: String) -> IntelToken:
	return definitions.get(token_id)


## Journal for a holder, created on demand (so unknown factions never crash).
func journal_for(holder: String) -> IntelJournal:
	if holder == "":
		return null
	if not journals.has(holder):
		journals[holder] = IntelJournal.new(holder)
	return journals[holder]


# --- Acquisition ---------------------------------------------------------------

## Grant a token to a holder. Re-acquiring from a new source corroborates it.
## [param channel] is a Provenance channel; [param reliability_override] < 0 keeps the template value.
func acquire(holder: String, token_id: String, source: String = "", channel: String = "told",
		reliability_override: float = -1.0, via_holder: String = "") -> IntelToken:
	var template: IntelToken = definitions.get(token_id)
	if template == null:
		push_error("IntelRegistry: unknown intel token '%s'" % token_id)
		return null
	var journal := journal_for(holder)
	if journal == null:
		return null
	var now := GameClock.now()
	var prov := Provenance.make(source, channel, now, journal.trust_of(source), via_holder)
	var tok: IntelToken
	if journal.has(token_id):
		tok = journal.tokens[token_id]
		if tok.corroborate(prov):
			EventBus.intel_updated.emit(holder, token_id)
	else:
		tok = template.duplicate_instance()
		tok.acquired_turn = now
		tok.confirmed_turn = now
		tok.provenance.append(prov)
		if reliability_override >= 0.0:
			tok.reliability = clampf(reliability_override, 0.0, 1.0)
		else:
			tok.reliability = clampf(tok.base_reliability * lerpf(0.5, 1.0, prov.trust), 0.0, 1.0)
		journal.tokens[token_id] = tok
		EventBus.intel_acquired.emit(holder, token_id, source)
		_apply_reveals(holder, tok)
		_apply_effects(holder, tok, source)
		_check_contradictions(holder, tok)
	rules.run_derivations(holder, self)
	_evaluate_watchers(holder)
	return tok


## Remove a token from a holder's journal (e.g. sold exclusive intel, memory wipe).
func forget(holder: String, token_id: String) -> void:
	var j := journal_for(holder)
	if j and j.tokens.erase(token_id):
		EventBus.intel_updated.emit(holder, token_id)


## Mark a held token as proven false; sources that provided it lose trust.
func debunk(holder: String, token_id: String) -> void:
	var j := journal_for(holder)
	var tok: IntelToken = j.get_token(token_id) if j else null
	if tok == null or tok.known_false:
		return
	tok.known_false = true
	for s in tok.sources():
		j.adjust_trust(s, -float(rules.contradiction.get("flag_source_trust_loss", 0.2)))
	EventBus.intel_updated.emit(holder, token_id)
	_evaluate_watchers(holder)


## Copy a token from one holder to another (diplomacy trade, theft, sharing).
func transfer(from_holder: String, to_holder: String, token_id: String, channel: String = "traded", price: int = 0) -> IntelToken:
	var src := journal_for(from_holder)
	var tok: IntelToken = src.get_token(token_id) if src else null
	if tok == null:
		return null
	if channel == "traded" and not tok.tradeable:
		return null
	var got := acquire(to_holder, token_id, from_holder, channel, tok.reliability, from_holder)
	if got:
		EventBus.intel_traded.emit(from_holder, to_holder, token_id, price)
	return got


func has(holder: String, token_id: String) -> bool:
	var j: IntelJournal = journals.get(holder)
	return j != null and j.has(token_id)


func get_token(holder: String, token_id: String) -> IntelToken:
	var j: IntelJournal = journals.get(holder)
	return j.get_token(token_id) if j else null


## Evaluate a query for a holder (see IntelQuery).
func evaluate(query: Dictionary, holder: String) -> bool:
	return IntelQuery.evaluate(query, holder)


## Trade value of a token for a holder = base value scaled by its belief in it.
func trade_value(holder: String, token_id: String) -> int:
	var tok := get_token(holder, token_id)
	return int(round(tok.value * tok.reliability)) if tok else 0



# --- Gating watchers --------------------------------------------------------------

## Register a query; EventBus.intel_query_unlocked fires once when it becomes true.
func watch_unlock(holder: String, unlock_id: String, query: Dictionary) -> void:
	var j := journal_for(holder)
	for w in j.unlock_watchers:
		if w["id"] == unlock_id:
			return
	j.unlock_watchers.append({"id": unlock_id, "query": query, "fired": false})
	_evaluate_watchers(holder)


func _evaluate_watchers(holder: String) -> void:
	var j := journal_for(holder)
	for w in j.unlock_watchers:
		if not w["fired"] and evaluate(w["query"], holder):
			w["fired"] = true
			EventBus.intel_query_unlocked.emit(holder, w["id"])


# --- Effects of acquisition -----------------------------------------------------------

func _apply_reveals(holder: String, tok: IntelToken) -> void:
	if tok.reveals.is_empty() or tok.revealed_applied or WorldManager.world == null:
		return
	tok.revealed_applied = true
	WorldManager.apply_reveal_spec(holder, tok.reveals)


func _apply_effects(holder: String, tok: IntelToken, source: String) -> void:
	for spec in tok.effects:
		var inter := InteractionFactory.create(spec, null)
		if inter:
			inter.run_for_holder(holder, source)


func _check_contradictions(holder: String, tok: IntelToken) -> void:
	var j := journal_for(holder)
	var amount := float(rules.contradiction.get("dispute_amount", 0.15))
	for other_id in tok.conflicts:
		var other: IntelToken = j.get_token(other_id)
		if other == null:
			continue
		# The better-supported token wins some ground; the weaker loses.
		if other.reliability >= tok.reliability:
			tok.dispute(amount)
		else:
			other.dispute(amount)
		EventBus.intel_contradiction.emit(holder, tok.id, other_id)


# --- Per-turn behaviour ---------------------------------------------------------------

func _on_turn_phase(_turn: int, phase: int) -> void:
	if phase == TurnManager.Phase.UPKEEP:
		_sweep_stale()
	elif phase == TurnManager.Phase.RESOLVE:
		_run_spread()
		for holder in journals.keys():
			rules.run_derivations(holder, self)
			_evaluate_watchers(holder)


func _sweep_stale() -> void:
	var now := GameClock.now()
	for holder in journals:
		for tok in journals[holder].tokens.values():
			if tok.is_stale(now) and not tok.stale_notified:
				tok.stale_notified = true
				EventBus.intel_expired.emit(holder, tok.id)


func _run_spread() -> void:
	if rules.spread.is_empty():
		return
	var ids := FactionRegistry.faction_ids()
	for rule in rules.spread:
		var between: String = rule.get("between", "all")
		for a in ids:
			for b in ids:
				if a == b or not FactionRegistry.relationship_matches(a, b, between):
					continue
				rules.run_spread_pair(rule, a, b, self, _spread_rng)


# --- Serialisation --------------------------------------------------------------------

func to_save_data() -> Dictionary:
	var out := {"journals": {}, "rules": rules.to_save_data(), "rng": _spread_rng.state}
	for holder in journals:
		out["journals"][holder] = journals[holder].to_save_data()
	return out


func from_save_data(data: Dictionary) -> void:
	journals.clear()
	rules.from_save_data(data.get("rules", {}))
	_spread_rng.state = int(data.get("rng", 0))
	for holder in data.get("journals", {}):
		var jd: Dictionary = data["journals"][holder]
		var j := journal_for(holder)
		j.source_trust = jd.get("trust", {})
		j.unlock_watchers.assign(jd.get("watchers", []))
		for id in jd.get("tokens", {}):
			if definitions.has(id):
				var tok: IntelToken = definitions[id].duplicate_instance()
				tok.apply_runtime(jd["tokens"][id])
				j.tokens[id] = tok
