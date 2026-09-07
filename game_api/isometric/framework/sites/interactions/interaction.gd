## Base class for interaction/effect strategies — the engine's universal "do
## something" primitive. Used by sites, intel token effects, item use, abilities
## and dialogue nodes. Constructed from a JSON spec:
##
##   {"kind": "intel", "tokens": ["rumor_bandit_camp"], "once": true,
##    "requires": {"has": "met_innkeeper"}, "faction_flags": ["met_elders"], "consumes": true}
##
## Common keys handled here:
##   requires      – IntelQuery that must pass (evaluated for the acting faction)
##   flags         – global GameManager flags that must be true
##   faction_flags – acting faction flags that must be true
##   once          – run only once per site (persisted in site state)
##   once_per_faction – run once per acting faction
##   consumes      – stop evaluating later interactions once this runs (default true)
##   message       – notification shown to the player faction when it runs
class_name Interaction
extends RefCounted

var kind: String = "base"
var spec: Dictionary = {}
var site: Site = null            ## Owning site (may be null for item/ability/token effects).
var context: Node = null         ## Optional node context (target unit etc.).
var consumes_interaction: bool = true


func setup(p_spec: Dictionary, p_owner) -> void:
	spec = p_spec
	if p_owner is Site:
		site = p_owner
	elif p_owner is Node:
		context = p_owner
	kind = spec.get("kind", kind)
	consumes_interaction = spec.get("consumes", true)
	_on_setup()


func _on_setup() -> void:
	pass


func acting_faction(by) -> String:
	if by is Unit:
		return by.faction_id
	if by is String:
		return by
	return GameManager.player_faction_id


func can_run(by) -> bool:
	var holder := acting_faction(by)
	if spec.get("once", false) and _state().get("done", false):
		return false
	if spec.get("once_per_faction", false) and _state().get("done_by", {}).get(holder, false):
		return false
	var req: Dictionary = spec.get("requires", {})
	if not req.is_empty() and not IntelRegistry.evaluate(req, holder):
		return false
	for flag in spec.get("flags", []):
		if not GameManager.has_flag(flag):
			return false
	var f := FactionRegistry.get_faction(holder)
	for flag in spec.get("faction_flags", []):
		if f == null or not f.has_flag(flag):
			return false
	return true


## Run for a unit standing on the site.
func run(by: Unit) -> void:
	_execute(by.faction_id, by, by)
	_mark_done(by.faction_id)
	_notify(by.faction_id)


## Run for a faction with no unit (token effects, item use, abilities).
func run_for_holder(holder: String, source: String = "", actor: Unit = null, target = null) -> void:
	spec["_source"] = source
	_execute(holder, actor, target)
	_mark_done(holder)
	_notify(holder)


## Subclasses implement the actual effect.
func _execute(_holder: String, _actor: Unit, _target) -> void:
	pass


func source_id() -> String:
	if site:
		return site.definition.id
	return spec.get("_source", "")


func _mark_done(holder: String) -> void:
	if spec.get("once", false):
		_state()["done"] = true
	if spec.get("once_per_faction", false):
		var st := _state()
		if not st.has("done_by"):
			st["done_by"] = {}
		st["done_by"][holder] = true


func _notify(holder: String) -> void:
	var msg: String = spec.get("message", "")
	if msg != "" and holder == GameManager.player_faction_id:
		EventBus.notification.emit(msg, "info")


func _state() -> Dictionary:
	if site:
		var st: Dictionary = site.get_state()
		var key := "%s_%d" % [kind, spec.get("index", 0)]
		if not st.has(key):
			st[key] = {}
		return st[key]
	return {}
