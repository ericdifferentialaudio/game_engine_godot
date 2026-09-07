## Declarative query language for gating content on knowledge and world state.
##
## A query is a plain JSON object evaluated against a *holder* (a faction id in
## the isometric engine, "player" in the FPS engine). Every engine-dependent
## question is delegated to the installed CoreEngineAdapter, so the exact same
## query JSON works unchanged in both graphics engines.
##
## Supported forms:
##   {"has": "token_id"}                          holder holds the token
##   {"has": "id", "min_reliability": 0.7}        ...with at least this belief
##   {"has": "id", "allow_stale": true}           ...even if decayed
##   {"has": "id", "max_age": 5}                  ...acquired within N time units
##   {"subject": "baron", "count": 2}             knows >= count about a subject
##   {"tag": "location", "count": 1}              knows >= count with a tag
##   {"scope": "site", "count": 3}                knows >= count of that scope
##   {"category": "military", "min_reliability": 0.5}
##   {"fact": ["token_id", "key", "value"]}       token's facts[key] == value
##   {"provenance": ["token_id", "observed"]}     came via that channel
##   {"source": ["token_id", "source_id"]}        was provided by that source
##   {"contradicted": "token_id"}                 holder also holds a conflict
##   {"flag": "asked_rumour"}                     global flag
##   {"holder_flag": "met_elders"}                holder-scoped flag
##   {"resource": ["gold", ">=", 50]}             holder resource comparison
##   {"time": [">=", 10]}                         engine clock comparison
##   {"owns_site": "site_id"}                     holder controls the site
##   {"unit_count": ["scout", ">=", 1]}           holder owns >= N of a unit def
##   {"stance": ["other_faction", "war"]}         diplomacy stance
##   {"all": [q1, q2]}   {"any": [q1, q2]}   {"not": q}
##
## Side-effect free, so offline validators can check the same shapes.
class_name CoreIntelQuery
extends RefCounted

const KEYS := ["has", "subject", "tag", "scope", "category", "fact", "provenance",
	"source", "contradicted", "flag", "holder_flag", "resource", "time",
	"owns_site", "unit_count", "stance", "all", "any", "not"]


## Evaluate [param q] for [param holder] against [param journal].
static func evaluate(q: Dictionary, holder: String, journal: CoreIntelJournal) -> bool:
	if q.is_empty():
		return true
	if q.has("all"):
		for sub in q["all"]:
			if not evaluate(sub, holder, journal):
				return false
		return true
	if q.has("any"):
		for sub in q["any"]:
			if evaluate(sub, holder, journal):
				return true
		return false
	if q.has("not"):
		return not evaluate(q["not"], holder, journal)
	if journal == null:
		journal = CoreIntelJournal.new(holder)
	return _leaf(q, holder, journal, CoreContext.now())


static func _leaf(q: Dictionary, holder: String, journal: CoreIntelJournal, now: float) -> bool:
	var adapter := CoreContext.adapter

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
		return _count(journal.tokens_about(q["subject"], now), q) >= int(q.get("count", 1))
	if q.has("tag"):
		return _count(journal.tokens_with_tag(q["tag"], now), q) >= int(q.get("count", 1))
	if q.has("scope"):
		return _count(journal.tokens_in_scope(q["scope"], now), q) >= int(q.get("count", 1))
	if q.has("category"):
		return _count(journal.tokens_in_category(q["category"], now), q) >= int(q.get("count", 1))

	if q.has("fact"):
		var fspec: Array = q["fact"]
		if fspec.size() != 3:
			return false
		var ftok := journal.get_token(fspec[0])
		return ftok != null and not ftok.known_false and ftok.facts.get(fspec[1]) == fspec[2]

	if q.has("provenance"):
		var pspec: Array = q["provenance"]
		var ptok := journal.get_token(pspec[0]) if pspec.size() == 2 else null
		if ptok == null:
			return false
		for p in ptok.provenance:
			if p.channel == pspec[1]:
				return true
		return false

	if q.has("source"):
		var sspec: Array = q["source"]
		var stok := journal.get_token(sspec[0]) if sspec.size() == 2 else null
		return stok != null and sspec[1] in stok.sources()

	if q.has("contradicted"):
		var ctok := journal.get_token(q["contradicted"])
		if ctok == null:
			return false
		for c in ctok.conflicts:
			if journal.has(c):
				return true
		return false

	if q.has("flag"):
		return CoreContext.has_flag(q["flag"])
	if q.has("holder_flag"):
		return adapter.holder_flag(holder, q["holder_flag"])

	if q.has("resource"):
		var rspec: Array = q["resource"]
		return rspec.size() == 3 and CoreDataLoader.compare(
			adapter.holder_resource(holder, rspec[0]), rspec[1], float(rspec[2]))

	if q.has("time"):
		var tspec: Array = q["time"]
		return tspec.size() == 2 and CoreDataLoader.compare(now, tspec[0], float(tspec[1]))

	if q.has("owns_site"):
		return adapter.owns_site(holder, q["owns_site"])

	if q.has("unit_count"):
		var uspec: Array = q["unit_count"]
		return uspec.size() == 3 and CoreDataLoader.compare(
			float(adapter.unit_count(holder, uspec[0])), uspec[1], float(uspec[2]))

	if q.has("stance"):
		var dspec: Array = q["stance"]
		return dspec.size() == 2 and adapter.stance(holder, dspec[0]) == dspec[1]

	push_warning("CoreIntelQuery: unrecognised query %s" % JSON.stringify(q))
	return false


static func _count(toks: Array[CoreIntelToken], q: Dictionary) -> int:
	var min_rel := float(q.get("min_reliability", 0.0))
	var n := 0
	for t in toks:
		if t.reliability >= min_rel:
			n += 1
	return n


## Static shape check usable by offline validators (no game state required).
static func is_valid_shape(q: Dictionary) -> bool:
	if q.is_empty():
		return true
	for k in ["all", "any"]:
		if q.has(k):
			if not (q[k] is Array):
				return false
			for sub in q[k]:
				if not (sub is Dictionary) or not is_valid_shape(sub):
					return false
			return true
	if q.has("not"):
		return q["not"] is Dictionary and is_valid_shape(q["not"])
	for k in q.keys():
		if String(k) in KEYS:
			return true
	return false
