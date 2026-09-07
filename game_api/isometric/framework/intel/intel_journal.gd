## One faction's knowledge: the tokens it holds plus per-source trust.
##
## Every faction (human or AI) has its own journal, so espionage, rumours and
## disinformation are first-class: two factions can hold contradictory beliefs
## about the same subject. IntelRegistry owns the journals and applies rules.
class_name IntelJournal
extends RefCounted

var holder_id: String = ""
var tokens: Dictionary = {}          ## token_id -> IntelToken (instance)
var source_trust: Dictionary = {}    ## source_id -> 0..1 (default 1.0); lowered when a source lies
var unlock_watchers: Array[Dictionary] = []


func _init(p_holder: String = "") -> void:
	holder_id = p_holder


func has(token_id: String) -> bool:
	return tokens.has(token_id)


func get_token(token_id: String) -> IntelToken:
	return tokens.get(token_id)


func trust_of(source_id: String) -> float:
	return float(source_trust.get(source_id, 1.0))


func adjust_trust(source_id: String, delta: float) -> void:
	source_trust[source_id] = clampf(trust_of(source_id) + delta, 0.0, 1.0)


## Tokens usable for queries: not stale (unless allowed) and not known false.
func valid_tokens(now_turn: float, allow_stale: bool = false) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in tokens.values():
		if tok.known_false:
			continue
		if not allow_stale and tok.is_stale(now_turn):
			continue
		out.append(tok)
	return out


func tokens_about(subject: String, now_turn: float) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in valid_tokens(now_turn):
		if tok.subject == subject:
			out.append(tok)
	return out


func tokens_with_tag(tag: String, now_turn: float) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in valid_tokens(now_turn):
		if tag in tok.tags:
			out.append(tok)
	return out


func tokens_in_scope(scope: String, now_turn: float) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in valid_tokens(now_turn):
		if tok.scope == scope:
			out.append(tok)
	return out


func tokens_in_category(category: String, now_turn: float) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in valid_tokens(now_turn):
		if tok.category == category:
			out.append(tok)
	return out


func reliable_tokens(min_reliability: float, now_turn: float) -> Array[IntelToken]:
	var out: Array[IntelToken] = []
	for tok in valid_tokens(now_turn):
		if tok.reliability >= min_reliability:
			out.append(tok)
	return out


## Pairs of held tokens that contradict each other (for UI and derivation).
func contradictions() -> Array[Array]:
	var out: Array[Array] = []
	var seen := {}
	for tok in tokens.values():
		for other_id in tok.conflicts:
			if tokens.has(other_id):
				var key := [tok.id, other_id]
				key.sort()
				var k := "%s|%s" % key
				if not seen.has(k):
					seen[k] = true
					out.append(key)
	return out


func to_save_data() -> Dictionary:
	var toks := {}
	for id in tokens:
		toks[id] = tokens[id].to_dict()
	return {"tokens": toks, "trust": source_trust.duplicate(), "watchers": unlock_watchers.duplicate(true)}
