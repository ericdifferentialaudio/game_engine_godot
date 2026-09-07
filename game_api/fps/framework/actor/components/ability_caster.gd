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
signal hit_landed(victim: Actor, info: DamageInfo, dealt: float)

var known: Dictionary = {}          ## ability_id -> {"permanent": bool, "sources": [..]}
var _rng := RandomNumberGenerator.new()
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


## Resolve targeting and apply the ability.
##  * SELF / AOE_SELF      -> heal + self effects
##  * MELEE_ARC / TOUCH    -> every hostile Actor inside range & arc takes damage
##  * PROJECTILE / BEAM    -> resolved as an instant hit on the aimed actor (if
##                            one is within range) — no projectile bodies yet.
func _execute(def: AbilityDefinition, target) -> void:
	match def.targeting:
		AbilityDefinition.Targeting.SELF, AbilityDefinition.Targeting.AOE_SELF:
			_execute_self(def)
		_:
			_execute_melee(def, target)


func _execute_self(def: AbilityDefinition) -> void:
	if def.heal > 0.0:
		actor.heal(def.heal, actor)
	if actor.status_effects:
		for e in def.apply_effects:
			if e.get("target", "self") == "self" and _rng.randf() <= float(e.get("chance", 1.0)):
				actor.status_effects.apply(str(e.get("effect", "")), "ability:%s" % def.id)


func _execute_melee(def: AbilityDefinition, target) -> void:
	var victims := targets_in_arc(def, target)
	if victims.is_empty():
		if actor.is_player():
			EventBus.notification.emit("Your swing finds only air.", "combat")
		return
	for victim in victims:
		var info := build_damage(def)
		info.direction = (victim.global_position - actor.global_position).normalized()
		info.hit_position = victim.global_position
		var dealt := victim.take_damage(info)
		hit_landed.emit(victim, info, dealt)
		if victim.is_dead:
			continue
		if victim.status_effects:
			for e in def.apply_effects:
				if e.get("target", "enemy") == "enemy" and _rng.randf() <= float(e.get("chance", 1.0)):
					victim.status_effects.apply(str(e.get("effect", "")), "ability:%s" % def.id)
	if actor.status_effects:
		for e in def.apply_effects:
			if e.get("target", "enemy") == "self" and _rng.randf() <= float(e.get("chance", 1.0)):
				actor.status_effects.apply(str(e.get("effect", "")), "ability:%s" % def.id)


## Actors this ability can hit right now. The player may strike anyone (Zork
## lets you attack whatever you like); AI only strikes actors it is hostile to.
## A single-target ability with an explicit Actor [param target] hits only it.
func targets_in_arc(def: AbilityDefinition, target = null) -> Array[Actor]:
	var out: Array[Actor] = []
	var origin := actor.global_position
	var forward := -actor.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var reach := def.range + 0.6   # body radius allowance
	var candidates: Array = []
	if target is Actor:
		candidates = [target]
	else:
		candidates = get_tree().get_nodes_in_group("actors")
	for other in candidates:
		if other == actor or not (other is Actor) or other.is_dead:
			continue
		var to: Vector3 = other.global_position - origin
		to.y = 0.0
		var dist := to.length()
		if dist > reach:
			continue
		if dist > 0.3 and def.arc_degrees < 360.0 and rad_to_deg(forward.angle_to(to.normalized())) > def.arc_degrees * 0.5:
			continue
		if not actor.is_player() and not actor.is_hostile_to(other):
			continue
		if actor.is_player() and other.is_player():
			continue
		out.append(other)
		if def.targeting == AbilityDefinition.Targeting.TOUCH or def.targeting == AbilityDefinition.Targeting.PROJECTILE \
				or def.targeting == AbilityDefinition.Targeting.BEAM:
			break
	return out


## Roll the damage for one hit: ability ranges + main weapon ranges (when
## scale_with_weapon), stat scaling, flat "attack" stat, crit.
func build_damage(def: AbilityDefinition) -> DamageInfo:
	var ranges: Dictionary = def.damage.duplicate()
	if def.scale_with_weapon and actor.equipment:
		var weapon := actor.equipment.main_weapon()
		if weapon:
			for t in weapon.def.damage:
				var r = weapon.def.damage[t]
				if ranges.has(t) and ranges[t] is Array and r is Array:
					ranges[t] = [float(ranges[t][0]) + float(r[0]), float(ranges[t][1]) + float(r[1])]
				else:
					ranges[t] = r
	if ranges.is_empty():
		ranges = {"blunt": [1, 2]}
	var info := DamageInfo.from_ranges(ranges, _rng, actor)
	info.ability_id = def.id
	info.tags.append("melee" if def.school == "physical" else "spell")
	if actor.stats:
		DamageCalculator.apply_scaling(info, def.scaling, actor.stats.all_final())
	var attack := actor.stat("attack", 0.0)
	if attack > 0.0:
		info.add(info.primary_type(), attack)
	info.is_crit = DamageCalculator.roll_crit(actor.stat("crit_chance", 0.0), _rng)
	return info


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
