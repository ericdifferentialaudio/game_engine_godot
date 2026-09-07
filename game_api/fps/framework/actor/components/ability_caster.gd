## Known abilities, cooldowns, resource costs and cast gating.
##
## M1: bookkeeping + `can_cast()` + `cast()` that validates, spends costs,
## starts cooldown and emits signals. The actual effect execution pipeline
## (targeting, projectiles, damage application) is M2 and plugs into
## [signal cast_started] / [method _execute].
class_name AbilityCaster
extends ActorComponent

signal learned(ability_id: String)
signal forgotten(ability_id: String)
signal cast_started(ability: AbilityDefinition, target)
signal cast_finished(ability: AbilityDefinition)
signal cast_failed(ability_id: String, reason: String)
signal cooldown_started(ability_id: String, seconds: float)

var known: Dictionary = {}          ## ability_id -> {"permanent": bool, "sources": [..]}
var cooldowns: Dictionary = {}      ## ability_id -> real time (msec) when ready
var global_cooldown_until: int = 0
var is_casting: bool = false
var current_cast: AbilityDefinition = null


func _definition_applied(def: ActorDefinition) -> void:
	for a in def.abilities:
		learn(a)


# --- Knowledge ---------------------------------------------------------------

func learn(ability_id: String) -> bool:
	if DefinitionRegistry.get_def("abilities", ability_id) == null:
		return false
	if not known.has(ability_id):
		known[ability_id] = {"permanent": true, "sources": []}
		learned.emit(ability_id)
	else:
		known[ability_id]["permanent"] = true
	return true


## Temporarily grant (from equipment); removed when the source goes away.
func grant(ability_id: String, source: String) -> void:
	if DefinitionRegistry.get_def("abilities", ability_id) == null:
		return
	if not known.has(ability_id):
		known[ability_id] = {"permanent": false, "sources": [source]}
		learned.emit(ability_id)
	elif source not in known[ability_id]["sources"]:
		known[ability_id]["sources"].append(source)


func remove_granted(source: String) -> void:
	for id in known.keys():
		var k: Dictionary = known[id]
		k["sources"].erase(source)
		if not k["permanent"] and k["sources"].is_empty():
			known.erase(id)
			forgotten.emit(id)


func forget(ability_id: String) -> void:
	if known.erase(ability_id):
		forgotten.emit(ability_id)


func knows(ability_id: String) -> bool:
	return known.has(ability_id)


func known_abilities() -> Array[AbilityDefinition]:
	var out: Array[AbilityDefinition] = []
	for id in known:
		var d := DefinitionRegistry.get_def("abilities", id) as AbilityDefinition
		if d:
			out.append(d)
	return out


# --- Casting -----------------------------------------------------------------

func can_cast(ability_id: String) -> Dictionary:
	var def := DefinitionRegistry.get_def("abilities", ability_id) as AbilityDefinition
	if def == null or not knows(ability_id):
		return {"ok": false, "reason": "unknown"}
	if actor.is_dead:
		return {"ok": false, "reason": "dead"}
	if is_casting:
		return {"ok": false, "reason": "casting"}
	if actor.status_effects and (actor.status_effects.has_flag("stunned") or
			(def.school != "physical" and actor.status_effects.has_flag("silenced"))):
		return {"ok": false, "reason": "disabled"}
	if is_on_cooldown(ability_id):
		return {"ok": false, "reason": "cooldown"}
	if actor.resources and not actor.resources.can_afford(def.costs):
		return {"ok": false, "reason": "resources"}
	if not def.requires.is_empty() and not IntelRegistry.evaluate(def.requires):
		return {"ok": false, "reason": "unknown_use"}
	for stat in def.requires_stats:
		if actor.stat(stat) < float(def.requires_stats[stat]):
			return {"ok": false, "reason": "stat:%s" % stat}
	return {"ok": true, "reason": ""}


## Attempt to cast. [param target] is ability-dependent (Node3D, Vector3 or null).
func cast(ability_id: String, target = null) -> bool:
	var check := can_cast(ability_id)
	if not check["ok"]:
		cast_failed.emit(ability_id, check["reason"])
		return false
	var def := DefinitionRegistry.get_def("abilities", ability_id) as AbilityDefinition
	if actor.resources:
		actor.resources.spend(def.costs)
	start_cooldown(ability_id, def.cooldown)
	is_casting = def.cast_time > 0.0
	current_cast = def
	cast_started.emit(def, target)
	EventBus.ability_cast.emit(actor, ability_id)
	if def.noise > 0.0:
		EventBus.noise_emitted.emit(actor.global_position, def.noise, actor)
	if is_casting:
		get_tree().create_timer(def.cast_time).timeout.connect(_finish_cast.bind(def, target))
	else:
		_finish_cast(def, target)
	return true


func interrupt() -> void:
	if is_casting and current_cast and current_cast.interruptible:
		is_casting = false
		cast_failed.emit(current_cast.id, "interrupted")
		current_cast = null


func _finish_cast(def: AbilityDefinition, target) -> void:
	if current_cast != def:
		return  # interrupted
	is_casting = false
	current_cast = null
	_execute(def, target)
	cast_finished.emit(def)


## M2 hook: resolve targeting and apply def.effects. Stub logs only.
func _execute(def: AbilityDefinition, _target) -> void:
	if OS.is_debug_build():
		print_verbose("%s casts %s (execution pipeline pending M2)" % [actor.name, def.id])


# --- Cooldowns ---------------------------------------------------------------

func start_cooldown(ability_id: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	cooldowns[ability_id] = Time.get_ticks_msec() + int(seconds * 1000.0)
	cooldown_started.emit(ability_id, seconds)


func is_on_cooldown(ability_id: String) -> bool:
	return cooldowns.get(ability_id, 0) > Time.get_ticks_msec()


func cooldown_remaining(ability_id: String) -> float:
	return maxf(0.0, (cooldowns.get(ability_id, 0) - Time.get_ticks_msec()) / 1000.0)


func to_save_data() -> Dictionary:
	var perm := []
	for id in known:
		if known[id]["permanent"]:
			perm.append(id)
	return {"known": perm}


func from_save_data(d: Dictionary) -> void:
	for id in d.get("known", []):
		learn(id)
