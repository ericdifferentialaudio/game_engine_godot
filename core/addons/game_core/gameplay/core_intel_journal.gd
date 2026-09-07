## Everything one holder knows. A "holder" is a faction id in the isometric
## engine, or simply "player" in the FPS engine — the core does not care.
##
## Tokens in a journal are *instances*: the same definition held by two holders
## has independent reliability, provenance and acquisition time.
##
## API:
##   journal.add(token_instance) / has(id) / get_token(id) / forget(id)
##   journal.tokens_about(subject, now) / tokens_with_tag(tag, now)
##   journal.tokens_in_scope(scope, now) / tokens_in_category(cat, now)
##   journal.contradictions() -> Array[Array]  # pairs of conflicting token ids
class_name CoreIntelJournal
extends RefCounted

var holder: String = ""
var tokens: Dictionary = {}    ## token_id -> CoreIntelToken (instance)


func _init(p_holder: String = "") -> void:
	holder = p_holder


func add(token: CoreIntelToken) -> void:
	tokens[token.id] = token


func has(token_id: String) -> bool:
	return tokens.has(token_id)


func get_token(token_id: String) -> CoreIntelToken:
	return tokens.get(token_id)


func forget(token_id: String) -> bool:
	return tokens.erase(token_id)


func clear() -> void:
	tokens.clear()


func size() -> int:
	return tokens.size()


## Every token the holder believes (excludes proven lies, and stale ones unless asked).
func known(now: float, allow_stale: bool = false) -> Array[CoreIntelToken]:
	var out: Array[CoreIntelToken] = []
	for t in tokens.values():
		if t.known_false:
			continue
		if not allow_stale and t.is_stale(now):
			continue
		out.append(t)
	return out


func tokens_about(subject: String, now: float, allow_stale: bool = false) -> Array[CoreIntelToken]:
	var out: Array[CoreIntelToken] = []
	for t in known(now, allow_stale):
		if t.subject == subject:
			out.append(t)
	return out


func tokens_with_tag(tag: String, now: float, allow_stale: bool = false) -> Array[CoreIntelToken]:
	var out: Array[CoreIntelToken] = []
	for t in known(now, allow_stale):
		if t.has_tag(tag):
			out.append(t)
	return out


func tokens_in_scope(scope: String, now: float, allow_stale: bool = false) -> Array[CoreIntelToken]:
	var out: Array[CoreIntelToken] = []
	for t in known(now, allow_stale):
		if t.scope == scope:
			out.append(t)
	return out


func tokens_in_category(category: String, now: float, allow_stale: bool = false) -> Array[CoreIntelToken]:
	var out: Array[CoreIntelToken] = []
	for t in known(now, allow_stale):
		if t.category == category:
			out.append(t)
	return out


## Tokens that may be sold/spread, most valuable first.
func tradeable(now: float) -> Array[CoreIntelToken]:
	var out := known(now)
	out = out.filter(func(t): return t.tradeable)
	out.sort_custom(func(a, b): return a.trade_value() > b.trade_value())
	return out


## Pairs of held token ids that contradict one another.
func contradictions() -> Array:
	var out := []
	var seen := {}
	for t in tokens.values():
		for c in t.conflicts:
			if not tokens.has(c):
				continue
			var key := "|".join(PackedStringArray([t.id, c]) if t.id < c else PackedStringArray([c, t.id]))
			if not seen.has(key):
				seen[key] = true
				out.append([t.id, c])
	return out


func to_save_data() -> Dictionary:
	var out := {}
	for id in tokens:
		out[id] = tokens[id].to_dict()
	return out
