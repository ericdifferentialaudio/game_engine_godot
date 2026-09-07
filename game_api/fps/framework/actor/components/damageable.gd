## Receives DamageInfo, gathers the defender's armour/resistances/immunities
## from Stats, Equipment, StatusEffects and the ActorDefinition, runs
## DamageCalculator, then forwards to Health. Also owns hurtbox metadata
## (M2: Area3D hurtboxes with multipliers, e.g. head = 2.0).
class_name Damageable
extends ActorComponent

signal hit(info: DamageInfo)
signal dodged(info: DamageInfo)

var base_resistances: Dictionary = {}
var base_immunities: Array[String] = []
var hurtbox_multipliers: Dictionary = {"body": 1.0, "head": 2.0, "limb": 0.75}
var rng := RandomNumberGenerator.new()


func _definition_applied(def: ActorDefinition) -> void:
	base_resistances = def.resistances.duplicate()
	base_immunities = def.immunities.duplicate()


## Combined resistance table: definition + equipment + status effects.
func resistances() -> Dictionary:
	var out := base_resistances.duplicate()
	if actor.equipment:
		for t in actor.equipment.total_resistances():
			out[t] = out.get(t, 0.0) + actor.equipment.total_resistances()[t]
	if actor.status_effects:
		var mods := actor.status_effects.resistance_mods()
		for t in mods:
			out[t] = out.get(t, 0.0) + mods[t]
	# Stats may expose "resist_<type>" for generic scaling
	if actor.stats:
		for k in actor.stats.all_final():
			var key: String = k
			if key.begins_with("resist_"):
				var t: String = key.trim_prefix("resist_")
				out[t] = out.get(t, 0.0) + actor.stats.get_final(key)
	return out


func immunities() -> Array:
	var out := base_immunities.duplicate()
	if actor.status_effects:
		for e in actor.status_effects.active.values():
			for i in e.def.immunities:
				if i not in out:
					out.append(i)
	return out


func armor() -> float:
	return actor.stat("armor", 0.0)


func dodge_chance() -> float:
	return clampf(actor.stat("dodge", 0.0), 0.0, 0.75)


## Mitigate and apply. Returns damage dealt to health.
func receive(info: DamageInfo, hurtbox: String = "body") -> float:
	if actor.is_dead:
		return 0.0
	var mult := float(hurtbox_multipliers.get(hurtbox, 1.0))
	if mult != 1.0:
		for t in info.amounts:
			info.amounts[t] *= mult
	DamageCalculator.resolve(info, armor(), resistances(), immunities(), dodge_chance(), rng)
	if info.dodged:
		dodged.emit(info)
		return 0.0
	hit.emit(info)
	var dealt := actor.health.apply_damage(info) if actor.health else 0.0
	# Being attacked makes the attacker a personal enemy (NPCs turn hostile).
	if info.source is Actor and actor.faction and not actor.is_player():
		actor.faction.make_personal_enemy(info.source)
	return dealt
