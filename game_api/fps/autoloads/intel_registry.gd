## The information/intel core of the engine.
##
## Two layers:
##  * Definitions  – every IntelToken the game *could* grant (from intel.json).
##  * Journal      – tokens the player has actually acquired, with runtime
##                   reliability, corroboration count and acquisition source.
##
## Intel is the primary progression currency in these games: POIs emit tokens,
## and shops/rewards/portals may be *gated* by IntelQuery expressions.
extends Node

var definitions: Dictionary = {}   ## token_id -> IntelToken (template)
var journal: Dictionary = {}       ## token_id -> IntelToken (acquired instance)

var _unlock_watchers: Array[Dictionary] = []  ## {id, query} evaluated on change


## Pull intel definitions from DefinitionRegistry (call after load_package).
func load_definitions() -> void:
	definitions.clear()
	for tok in DefinitionRegistry.all("intel"):
		definitions[tok.id] = tok


func reset_journal() -> void:
	journal.clear()
	_unlock_watchers.clear()


# --- Acquisition -------------------------------------------------------------

## Grant a token to the player. Re-acquiring corroborates it (raises reliability).
func acquire(token_id: String, source_poi: String = "", reliability_override: float = -1.0) -> IntelToken:
	var template: IntelToken = definitions.get(token_id)
	if template == null:
		push_error("IntelRegistry: unknown intel token '%s'" % token_id)
		return null
	var tok: IntelToken
	if journal.has(token_id):
		tok = journal[token_id]
		tok.corroborate(source_poi)
		EventBus.intel_updated.emit(token_id)
	else:
		tok = template.duplicate_instance()
		tok.acquired_at = GameClock.now()
		tok.sources.append(source_poi)
		if reliability_override >= 0.0:
			tok.reliability = reliability_override
		journal[token_id] = tok
		EventBus.intel_acquired.emit(token_id, source_poi)
	_evaluate_watchers()
	return tok


func has(token_id: String) -> bool:
	return journal.has(token_id)


func get_token(token_id: String) -> IntelToken:
	return journal.get(token_id)


## Tokens whose runtime reliability is at least [param min_reliability].
func reliable_tokens(min_reliability: float = 0.5) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in journal.values():
		if tok.reliability >= min_reliability and not tok.is_expired():
			out.append(tok)
	return out


func tokens_about(subject: String) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in journal.values():
		if tok.subject == subject:
			out.append(tok)
	return out


func tokens_with_tag(tag: String) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in journal.values():
		if tag in tok.tags:
			out.append(tok)
	return out


# --- Gating ------------------------------------------------------------------

## Evaluate a query dictionary (see IntelQuery) against the journal.
func evaluate(query: Dictionary) -> bool:
	return IntelQuery.evaluate(query, self)


## Register a query; EventBus.intel_query_unlocked fires once when it becomes true.
func watch_unlock(unlock_id: String, query: Dictionary) -> void:
	for w in _unlock_watchers:
		if w["id"] == unlock_id:
			return
	_unlock_watchers.append({"id": unlock_id, "query": query, "fired": false})
	_evaluate_watchers()


func _evaluate_watchers() -> void:
	for w in _unlock_watchers:
		if not w["fired"] and evaluate(w["query"]):
			w["fired"] = true
			EventBus.intel_query_unlocked.emit(w["id"])


# --- Expiry ------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Cheap periodic sweep; tokens with expires_after <= 0 never expire.
	if Engine.get_process_frames() % 120 != 0:
		return
	for id in journal.keys():
		var tok: IntelToken = journal[id]
		if tok.is_expired() and not tok.expiry_notified:
			tok.expiry_notified = true
			EventBus.intel_expired.emit(id)


# --- Serialisation -----------------------------------------------------------

func to_save_data() -> Dictionary:
	var out := {}
	for id in journal:
		out[id] = journal[id].to_dict()
	return out


func from_save_data(data: Dictionary) -> void:
	journal.clear()
	for id in data:
		if definitions.has(id):
			var tok: IntelToken = definitions[id].duplicate_instance()
			tok.apply_runtime(data[id])
			journal[id] = tok
