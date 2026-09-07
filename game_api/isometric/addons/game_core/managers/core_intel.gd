## Owns every holder's intel journal and all knowledge transactions.
##
## Registered as the `CoreIntel` autoload. Holders are faction ids (isometric)
## or just "player" (FPS) — the manager is agnostic.
##
## API:
##   CoreIntel.journal_for(holder)                     -> CoreIntelJournal
##   CoreIntel.acquire(holder, token_id, source, channel, trust) -> bool
##   CoreIntel.knows(holder, token_id, min_reliability) -> bool
##   CoreIntel.evaluate(query, holder)                  -> bool
##   CoreIntel.spread(from, to, token_id)               -> bool
##   CoreIntel.trade(from, to, token_id)                -> int (price paid)
##   CoreIntel.debunk(holder, token_id)
##   CoreIntel.prune_stale(holder)
extends Node

signal acquired(holder: String, token_id: String, source: String)
signal updated(holder: String, token_id: String)
signal expired(holder: String, token_id: String)
signal spread_completed(from_holder: String, to_holder: String, token_id: String)
signal traded(from_holder: String, to_holder: String, token_id: String, price: int)
signal contradiction_found(holder: String, token_a: String, token_b: String)
signal debunked(holder: String, token_id: String)

## Reliability lost by every other token from a source proven to lie.
const LIAR_PENALTY := 0.25

var journals: Dictionary = {}    ## holder -> CoreIntelJournal


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
	journals.clear()


## Get (creating if needed) a holder's journal.
func journal_for(holder: String) -> CoreIntelJournal:
	if not journals.has(holder):
		journals[holder] = CoreIntelJournal.new(holder)
	return journals[holder]


func knows(holder: String, token_id: String, min_reliability: float = 0.0) -> bool:
	var tok := journal_for(holder).get_token(token_id)
	return tok != null and not tok.known_false and tok.reliability >= min_reliability


func evaluate(query: Dictionary, holder: String) -> bool:
	return CoreIntelQuery.evaluate(query, holder, journal_for(holder))


## Grant a token to a holder. If already held, this counts as corroboration from
## an independent source. Returns true if anything changed.
func acquire(holder: String, token_id: String, source: String = "", channel: String = "told", trust: float = 1.0) -> bool:
	var def := CoreRegistry.get_def("intel", token_id) as CoreIntelToken
	if def == null:
		# Not an engine error: callers legitimately probe for optional tokens.
		push_warning("CoreIntel: unknown intel token '%s'" % token_id)
		return false
	var journal := journal_for(holder)
	var now := CoreContext.now()
	var entry := CoreProvenance.make(source, channel, now, trust)

	var existing := journal.get_token(token_id)
	if existing != null:
		if not existing.corroborate(entry):
			return false
		updated.emit(holder, token_id)
		_check_contradictions(holder, existing)
		return true

	var tok := def.duplicate_instance()
	tok.acquired_at = now
	tok.confirmed_at = now
	tok.provenance.append(entry)
	tok.reliability = clampf(tok.base_reliability * trust, 0.0, 1.0)
	journal.add(tok)

	if not tok.reveals.is_empty() and not tok.revealed_applied:
		CoreContext.adapter.reveal(holder, tok.reveals)
		tok.revealed_applied = true

	acquired.emit(holder, token_id, source)
	_check_contradictions(holder, tok)
	return true


func forget(holder: String, token_id: String) -> void:
	if journal_for(holder).forget(token_id):
		updated.emit(holder, token_id)


## Mark a token as a proven lie and penalise everything else from its sources.
func debunk(holder: String, token_id: String) -> void:
	var journal := journal_for(holder)
	var tok := journal.get_token(token_id)
	if tok == null or tok.known_false:
		return
	tok.known_false = true
	tok.reliability = 0.0
	var liars := tok.sources()
	for other in journal.tokens.values():
		if other.id == token_id:
			continue
		for s in other.sources():
			if s in liars:
				other.dispute(LIAR_PENALTY)
				updated.emit(holder, other.id)
				break
	debunked.emit(holder, token_id)


## Propagate a token between holders, gated by its secrecy.
func spread(from_holder: String, to_holder: String, token_id: String) -> bool:
	var tok := journal_for(from_holder).get_token(token_id)
	if tok == null or not tok.spreadable or tok.known_false:
		return false
	if CoreContext.rng().randf() < tok.secrecy:
		return false
	var trust := tok.reliability * (1.0 - tok.secrecy)
	if not acquire(to_holder, token_id, from_holder, "spread", trust):
		return false
	spread_completed.emit(from_holder, to_holder, token_id)
	return true


## Sell/exchange a token. Returns the price, or -1 if the trade was refused.
func trade(from_holder: String, to_holder: String, token_id: String) -> int:
	var tok := journal_for(from_holder).get_token(token_id)
	if tok == null or not tok.tradeable or tok.known_false:
		return -1
	if not acquire(to_holder, token_id, from_holder, "traded", tok.reliability):
		return -1
	var price := tok.trade_value()
	traded.emit(from_holder, to_holder, token_id, price)
	return price


## Emit expiry signals for tokens that just went stale. Call once per turn/tick.
func prune_stale(holder: String) -> Array[String]:
	var now := CoreContext.now()
	var gone: Array[String] = []
	for tok in journal_for(holder).tokens.values():
		if tok.is_stale(now) and not tok.stale_notified:
			tok.stale_notified = true
			gone.append(tok.id)
			expired.emit(holder, tok.id)
	return gone


# --- Persistence --------------------------------------------------------------

func to_save_data() -> Dictionary:
	var out := {}
	for holder in journals:
		out[holder] = journals[holder].to_save_data()
	return out


func from_save_data(d: Dictionary) -> void:
	reset()
	for holder in d:
		var journal := journal_for(holder)
		for token_id in d[holder]:
			var def := CoreRegistry.get_def("intel", token_id) as CoreIntelToken
			if def == null:
				continue
			var tok := def.duplicate_instance()
			tok.apply_runtime(d[holder][token_id])
			journal.add(tok)


func _check_contradictions(holder: String, tok: CoreIntelToken) -> void:
	var journal := journal_for(holder)
	for c in tok.conflicts:
		if journal.has(c):
			contradiction_found.emit(holder, tok.id, c)
