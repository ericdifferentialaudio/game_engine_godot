## Declarative query language for gating content on knowledge and world state.
##
## A query is a JSON object evaluated against a *holder* (faction id). Forms:
##   {"has": "token_id"}                              holder has the token
##   {"has": "token_id", "min_reliability": 0.7}      ...with at least this reliability
##   {"has": "token_id", "allow_stale": true}         ...even if decayed
##   {"has": "token_id", "max_age": 5}                ...acquired within the last N turns
##   {"subject": "baron_veyle", "count": 2}           knows >= count tokens about subject
##   {"tag": "location", "count": 1}                  knows >= count tokens with tag
##   {"scope": "site", "count": 3}                    knows >= count tokens of that scope
##   {"category": "military", "min_reliability": 0.5, "count": 1}
##   {"fact": ["token_id", "key", "value"]}           token's facts[key] == value
##   {"provenance": ["token_id", "channel"]}          token came via channel (observed/told/stolen...)
##   {"source": ["token_id", "source_id"]}            token was provided by that source
##   {"contradicted": "token_id"}                     holder also holds a conflicting token
##   {"flag": "asked_rumour"}                         GameManager global flag is true
##   {"faction_flag": "met_elders"}                   holder's own flag
##   {"resource": ["gold", ">=", 50]}                 holder resource comparison
##   {"turn": [">=", 10]}                             game turn comparison
##   {"era": "classical"}                             current era
##   {"owns_site": "site_id"}                         holder controls the site's tile
##   {"unit_count": ["scout", ">=", 1]}               holder owns >= N units of definition
##   {"stance": ["other_faction", "war"]}             diplomacy stance toward another faction
##   {"all": [q1, q2]}   {"any": [q1, q2]}   {"not": q}
##
## Side-effect free so tools/validate_data.py can validate the same shapes offline.
class_name IntelQuery
extends RefCounted

const KEYS := ["has", "subject", "tag", "scope", "category", "fact", "provenance", "source",
	"contradicted", "flag", "faction_flag", "resource", "turn", "era", "owns_site",
	"unit_count", "stance", "all", "any", "not"]


static func evaluate(q: Dictionary, holder: String) -> bool:
	if q.is_empty():
		return true
	if q.has("all"):
		for sub in q["all"]:
			if not evaluate(sub, holder):
				return false
		return true
	if q.has("any"):
		for sub in q["any"]:
			if evaluate(sub, holder):
				return true
		return false
	if q.has("not"):
		return not evaluate(q["not"], holder)
	var journal: IntelJournal = IntelRegistry.journal_for(holder)
	if journal == null:
		return false
	return _evaluate_leaf(q, holder, journal, GameClock.now())



static func _evaluate_leaf(q: Dictionary, holder: String, journal: IntelJournal, now: float) -> bool:
	if q.has("has"):
		var tok := journal.get_token(q["has"])
		if tok == null or tok.known_false:
			return false
		if not q.get("allow_stale", false) and tok.is_stale(now):
			return false
		if q.has("max_age") and tok.age(now) > float(q["max_age"]):
			return false
		return tok.reliability >= float(q.get("min_reliability", 0.0))
	if q.has("subject"):
		return _count_reliable(journal.tokens_about(q["subject"], now), q) >= int(q.get("count", 1))
	if q.has("tag"):
		return _count_reliable(journal.tokens_with_tag(q["tag"], now), q) >= int(q.get("count", 1))
	if q.has("scope"):
		return _count_reliable(journal.tokens_in_scope(q["scope"], now), q) >= int(q.get("count", 1))
	if q.has("category"):
		return _count_reliable(journal.tokens_in_category(q["category"], now), q) >= int(q.get("count", 1))
	if q.has("fact"):
		var spec: Array = q["fact"]
		if spec.size() != 3:
			return false
		var tok := journal.get_token(spec[0])
		return tok != null and not tok.known_false and tok.facts.get(spec[1]) == spec[2]
	if q.has("provenance"):
		var spec: Array = q["provenance"]
		var tok := journal.get_token(spec[0]) if spec.size() == 2 else null
		if tok == null:
			return false
		for p in tok.provenance:
			if p.channel == spec[1]:
				return true
		return false
	if q.has("source"):
		var spec: Array = q["source"]
		var tok := journal.get_token(spec[0]) if spec.size() == 2 else null
		return tok != null and spec[1] in tok.sources()
	if q.has("contradicted"):
		var tok := journal.get_token(q["contradicted"])
		if tok == null:
			return false
		for c in tok.conflicts:
			if journal.has(c):
				return true
		return false
	if q.has("flag"):
		return GameManager.has_flag(q["flag"])
	if q.has("faction_flag"):
		var f := FactionRegistry.get_faction(holder)
		return f != null and f.has_flag(q["faction_flag"])
	if q.has("resource"):
		var spec: Array = q["resource"]
		var f := FactionRegistry.get_faction(holder)
		return f != null and spec.size() == 3 and _compare(f.get_resource(spec[0]), spec[1], float(spec[2]))
	if q.has("turn"):
		var spec: Array = q["turn"]
		return spec.size() == 2 and _compare(float(GameClock.turn), spec[0], float(spec[1]))
	if q.has("era"):
		return GameClock.current_era == q["era"]
	if q.has("owns_site"):
		var site := WorldManager.get_site_definition(q["owns_site"])
		return site != null and WorldManager.world != null and WorldManager.world.owner_of(site.coord) == holder
	if q.has("unit_count"):
		var spec: Array = q["unit_count"]
		if spec.size() != 3:
			return false
		return _compare(float(EntityRegistry.count_units(holder, spec[0])), spec[1], float(spec[2]))
	if q.has("stance"):
		var spec: Array = q["stance"]
		var f := FactionRegistry.get_faction(holder)
		return f != null and spec.size() == 2 and f.stance_toward(spec[0]) == spec[1]
	push_warning("IntelQuery: unrecognised query %s" % JSON.stringify(q))
	return false


static func _count_reliable(toks: Array[IntelToken], q: Dictionary) -> int:
	var min_rel := float(q.get("min_reliability", 0.0))
	var n := 0
	for t in toks:
		if t.reliability >= min_rel:
			n += 1
	return n


static func _compare(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		">": return a > b
		"<=": return a <= b
		"<": return a < b
		"==", "=": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
	return false
