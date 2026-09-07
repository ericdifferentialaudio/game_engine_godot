## Active status effects on an actor. Applies EffectDefinition stat modifiers
## into Stats (source "effect:<id>"), tracks duration on the GameClock, and
## runs periodic ticks (damage/heal/resource). Flags ("stunned", "invisible")
## are queryable by Brains and Perception.
class_name StatusEffects
extends ActorComponent

signal applied(effect_id: String, stacks: int)
signal removed(effect_id: String)
signal ticked(effect_id: String)

class ActiveEffect:
	var def: EffectDefinition
	var stacks: int = 1
	var applied_at: float
	var expires_at: float       ## INF when permanent
	var source_id: String = ""  ## "equip:<slot>" for gear-granted effects
	var next_tick: float

var active: Dictionary = {}     ## effect_id -> ActiveEffect


func _process(_delta: float) -> void:
	if active.is_empty():
		return
	var now := GameClock.now()
	for id in active.keys():
		var e: ActiveEffect = active[id]
		if e.def.tick_interval > 0.0 and now >= e.next_tick:
			_tick(e)
			e.next_tick += e.def.tick_interval
		if now >= e.expires_at:
			remove(id)


## Apply an effect by id. Returns false if immune or ignored by stacking rules.
func apply(effect_id: String, source_id: String = "", duration_override: float = -1.0) -> bool:
	var def := DefinitionRegistry.get_def("effects", effect_id) as EffectDefinition
	if def == null or is_immune_to(effect_id):
		return false
	var now := GameClock.now()
	var duration := def.duration if duration_override < 0.0 else duration_override
	var expires := INF if duration <= 0.0 else now + duration

	if active.has(effect_id):
		var e: ActiveEffect = active[effect_id]
		match def.stacking:
			EffectDefinition.Stacking.IGNORE:
				return false
			EffectDefinition.Stacking.REFRESH:
				e.expires_at = expires
			EffectDefinition.Stacking.STACK, EffectDefinition.Stacking.INDEPENDENT:
				e.stacks = mini(e.stacks + 1, def.max_stacks)
				e.expires_at = expires
		_push_modifiers(e)
		applied.emit(effect_id, e.stacks)
		return true

	var e := ActiveEffect.new()
	e.def = def
	e.applied_at = now
	e.expires_at = expires
	e.source_id = source_id
	e.next_tick = now + def.tick_interval if def.tick_interval > 0.0 else INF
	active[effect_id] = e
	_push_modifiers(e)
	applied.emit(effect_id, 1)
	EventBus.status_applied.emit(actor, effect_id)
	return true


func remove(effect_id: String) -> void:
	if not active.has(effect_id):
		return
	active.erase(effect_id)
	if actor.stats:
		actor.stats.remove_modifiers("effect:%s" % effect_id)
	removed.emit(effect_id)
	EventBus.status_removed.emit(actor, effect_id)


func remove_from_source(source_id: String) -> void:
	for id in active.keys():
		if active[id].source_id == source_id:
			remove(id)


func dispel(debuffs_only: bool = true) -> int:
	var n := 0
	for id in active.keys():
		var e: ActiveEffect = active[id]
		if e.def.dispellable and (not debuffs_only or e.def.is_debuff):
			remove(id)
			n += 1
	return n


func has(effect_id: String) -> bool:
	return active.has(effect_id)


func stacks(effect_id: String) -> int:
	return active[effect_id].stacks if active.has(effect_id) else 0


func has_flag(flag: String) -> bool:
	for e in active.values():
		if flag in e.def.flags:
			return true
	return false


func is_immune_to(id_or_type: String) -> bool:
	for e in active.values():
		if id_or_type in e.def.immunities:
			return true
	return false


## Aggregate resistance modifiers from all active effects.
func resistance_mods() -> Dictionary:
	var out := {}
	for e in active.values():
		for t in e.def.resistances:
			out[t] = out.get(t, 0.0) + float(e.def.resistances[t]) * e.stacks
	return out


func _push_modifiers(e: ActiveEffect) -> void:
	if actor.stats == null:
		return
	var flat := {}
	var pct := {}
	for k in e.def.stat_mods: flat[k] = float(e.def.stat_mods[k]) * e.stacks
	for k in e.def.stat_mods_percent: pct[k] = float(e.def.stat_mods_percent[k]) * e.stacks
	actor.stats.set_modifiers("effect:%s" % e.def.id, flat, pct)


func _tick(e: ActiveEffect) -> void:
	if not e.def.tick_damage.is_empty():
		var info := DamageInfo.from_ranges(e.def.tick_damage)
		for t in info.amounts: info.amounts[t] *= e.stacks
		info.tags.append("dot")
		info.can_be_dodged = false
		actor.take_damage(info)
	if e.def.tick_heal > 0.0:
		actor.heal(e.def.tick_heal * e.stacks)
	if actor.resources:
		for r in e.def.tick_resources:
			actor.resources.modify(r, float(e.def.tick_resources[r]) * e.stacks)
	ticked.emit(e.def.id)


func to_save_data() -> Dictionary:
	var out := {}
	for id in active:
		var e: ActiveEffect = active[id]
		out[id] = {"stacks": e.stacks, "expires_at": e.expires_at if e.expires_at != INF else -1.0, "source": e.source_id}
	return {"active": out}


func from_save_data(d: Dictionary) -> void:
	for id in d.get("active", {}):
		var s: Dictionary = d["active"][id]
		var exp_at := float(s.get("expires_at", -1.0))
		var remaining := -1.0 if exp_at < 0.0 else maxf(0.0, exp_at - GameClock.now())
		if apply(id, str(s.get("source", "")), remaining if exp_at >= 0.0 else 0.0):
			active[id].stacks = int(s.get("stacks", 1))
			_push_modifiers(active[id])
