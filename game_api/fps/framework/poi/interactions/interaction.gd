## Base class for POI interaction strategies.
##
## Each strategy is constructed from a JSON spec:
##   {"kind": "intel", "tokens": ["rumor_bandit_camp"], "once": true,
##    "requires": {"has": "met_innkeeper"}}
##
## Common keys handled here:
##   requires  – IntelQuery that must pass for the interaction to run
##   flags     – GameManager flags that must be true
##   once      – only run a single time (persisted in POI state)
##   consumes  – stop evaluating later interactions once this one runs (default true)
class_name Interaction
extends RefCounted

var kind: String = "base"
var spec: Dictionary = {}
var poi: Node = null
var consumes_interaction: bool = true


func setup(p_spec: Dictionary, p_poi: Node) -> void:
	spec = p_spec
	poi = p_poi
	kind = spec.get("kind", kind)
	consumes_interaction = spec.get("consumes", true)
	_on_setup()


func _on_setup() -> void:
	pass


func can_run(_by: Node) -> bool:
	if spec.get("once", false) and _state().get("done", false):
		return false
	var req: Dictionary = spec.get("requires", {})
	if not req.is_empty() and not IntelRegistry.evaluate(req):
		return false
	for flag in spec.get("flags", []):
		if not GameManager.has_flag(flag):
			return false
	return true


func run(by: Node) -> void:
	_execute(by)
	if spec.get("once", false):
		_state()["done"] = true


## Subclasses implement the actual effect.
func _execute(_by: Node) -> void:
	pass


func _state() -> Dictionary:
	if poi and poi.has_method("get_state"):
		var st: Dictionary = poi.get_state()
		var key := "%s_%d" % [kind, spec.get("index", 0)]
		if not st.has(key):
			st[key] = {}
		return st[key]
	return {}
