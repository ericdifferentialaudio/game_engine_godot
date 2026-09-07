## Tiny declarative query language for gating content on knowledge.
##
## A query is a JSON object. Supported forms:
##   {"has": "token_id"}                         player holds the token
##   {"has": "token_id", "min_reliability": 0.7} ...with at least this reliability
##   {"subject": "baron_veyle", "count": 2}      knows >= count tokens about subject
##   {"tag": "location", "count": 1}             knows >= count tokens with tag
##   {"fact": ["token_id", "key", "value"]}      token's facts[key] == value
##   {"flag": "asked_rumour"}                    GameManager flag is true
##   {"all": [q1, q2]}   {"any": [q1, q2]}   {"not": q}
##
## Kept deliberately simple and side-effect free so it can also be validated
## offline by tools/validate_data.py.
class_name IntelQuery
extends RefCounted


static func evaluate(q: Dictionary, registry: Node) -> bool:
	if q.is_empty():
		return true
	if q.has("all"):
		for sub in q["all"]:
			if not evaluate(sub, registry):
				return false
		return true
	if q.has("any"):
		for sub in q["any"]:
			if evaluate(sub, registry):
				return true
		return false
	if q.has("not"):
		return not evaluate(q["not"], registry)
	if q.has("has"):
		var tok = registry.get_token(q["has"])
		if tok == null or tok.is_expired():
			return false
		return tok.reliability >= float(q.get("min_reliability", 0.0))
	if q.has("subject"):
		return registry.tokens_about(q["subject"]).size() >= int(q.get("count", 1))
	if q.has("tag"):
		return registry.tokens_with_tag(q["tag"]).size() >= int(q.get("count", 1))
	if q.has("fact"):
		var spec: Array = q["fact"]
		if spec.size() != 3:
			return false
		var tok = registry.get_token(spec[0])
		return tok != null and tok.facts.get(spec[1]) == spec[2]
	if q.has("flag"):
		return GameManager.has_flag(q["flag"])
	push_warning("IntelQuery: unrecognised query %s" % JSON.stringify(q))
	return false
