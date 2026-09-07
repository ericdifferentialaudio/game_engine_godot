## Base class for interaction/effect strategies — the framework's universal
## "do something" primitive. Used by places, intel token effects, item use,
## abilities and dialogue nodes, in either graphics engine.
##
## Built from a JSON spec:
##   {"kind": "intel", "tokens": ["rumor_bandit_camp"], "once": true,
##    "requires": {"has": "met_innkeeper"}, "message": "The elder whispers..."}
##
## Gating keys handled here (every kind gets them for free):
##   requires        – CoreIntelQuery that must pass for the acting holder
##   flags           – global flags that must all be true
##   holder_flags    – acting holder's own flags that must all be true
##   once            – run only once ever (per owning place)
##   once_per_holder – run once per acting holder
##   consumes        – stop evaluating later interactions once this runs
##   message         – notification shown when it runs
##   chance          – 0..1 probability, rolled on the shared seeded RNG
##
## Subclasses implement [method _execute]. Register new kinds with
## CoreInteractionFactory.register("ritual", MyRitualInteraction) — games are
## never limited to the built-in set.
class_name CoreInteraction
extends RefCounted

var kind: String = "base"
var spec: Dictionary = {}
var owner_id: String = ""              ## Place/item/ability id that owns this.
var consumes: bool = true

## Persisted "already ran" bookkeeping, supplied by the owner so it survives
## save/load. Shape: {"done": bool, "done_by": {holder: true}}
var state: Dictionary = {}


func setup(p_spec: Dictionary, p_owner_id: String = "", p_state: Dictionary = {}) -> void:
	spec = p_spec
	owner_id = p_owner_id
	state = p_state
	kind = str(spec.get("kind", kind))
	consumes = bool(spec.get("consumes", true))
	_on_setup()


func _on_setup() -> void:
	pass


## Can this run right now for [param holder]?
func can_run(holder: String) -> bool:
	if spec.get("once", false) and state.get("done", false):
		return false
	if spec.get("once_per_holder", spec.get("once_per_faction", false)):
		if state.get("done_by", {}).get(holder, false):
			return false
	var req: Dictionary = spec.get("requires", {})
	if not req.is_empty() and not CoreIntel.evaluate(req, holder):
		return false
	for flag in spec.get("flags", []):
		if not CoreContext.has_flag(str(flag)):
			return false
	for flag in spec.get("holder_flags", spec.get("faction_flags", [])):
		if not CoreContext.adapter.holder_flag(holder, str(flag)):
			return false
	return true


## Run for [param holder]. [param actor] and [param target] are opaque to the
## core — each engine passes its own unit/actor object. Returns true if it ran.
func run(holder: String, actor = null, target = null) -> bool:
	if not can_run(holder):
		return false
	var chance := float(spec.get("chance", 1.0))
	if chance < 1.0 and CoreContext.rng().randf() > chance:
		return false
	_execute(holder, actor, target)
	_mark_done(holder)
	_notify(holder)
	return true


## Subclasses implement the actual effect.
func _execute(_holder: String, _actor, _target) -> void:
	pass


func _mark_done(holder: String) -> void:
	if spec.get("once", false):
		state["done"] = true
	if spec.get("once_per_holder", spec.get("once_per_faction", false)):
		if not state.has("done_by"):
			state["done_by"] = {}
		state["done_by"][holder] = true


func _notify(_holder: String) -> void:
	var msg := str(spec.get("message", ""))
	if msg != "":
		CoreContext.adapter.notify(msg, str(spec.get("message_category", "info")))
