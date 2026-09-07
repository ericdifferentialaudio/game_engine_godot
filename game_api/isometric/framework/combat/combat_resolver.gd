## Pluggable combat strategy. Games swap the resolver at startup:
##   CombatResolver.active = MyResolver.new()
## The default is a Civ-like strength comparison with terrain defence and a
## small seeded random swing (rules.combat in game.json):
##   {"randomness": 0.2, "base_damage": 3, "defender_terrain_bonus": true, "attack_ends_turn": true}
class_name CombatResolver
extends RefCounted

static var active: CombatResolver = CombatResolver.new()


func resolve(attacker: Unit, defender: Unit) -> Dictionary:
	EventBus.combat_started.emit(attacker.unit_id, defender.unit_id)
	var rng := WorldManager.world.rng if WorldManager.world else RandomNumberGenerator.new()
	var randomness := float(GameManager.rule("combat.randomness", 0.2))
	var base := float(GameManager.rule("combat.base_damage", 3.0))

	var atk := _stat(attacker, "strength", 1.0)
	var def := _stat(defender, "defense", _stat(defender, "strength", 1.0))
	if GameManager.rule("combat.defender_terrain_bonus", true):
		def *= 1.0 + _terrain_bonus(defender.coord) / 100.0
	var ratio := atk / maxf(def, 0.1)
	var swing := 1.0 + rng.randf_range(-randomness, randomness)
	var dmg_to_defender := int(round(base * ratio * swing))
	var dmg_to_attacker := int(round(base / maxf(ratio, 0.1) * (2.0 - swing) * float(GameManager.rule("combat.retaliation_scale", 0.6))))
	dmg_to_defender = maxi(dmg_to_defender, 1)
	dmg_to_attacker = maxi(dmg_to_attacker, 0)

	defender.take_damage(dmg_to_defender, attacker.unit_id)
	if defender.alive and dmg_to_attacker > 0:
		attacker.take_damage(dmg_to_attacker, defender.unit_id)
	var result := {
		"attacker": attacker.unit_id, "defender": defender.unit_id,
		"damage_to_defender": dmg_to_defender, "damage_to_attacker": dmg_to_attacker,
		"defender_died": not defender.alive, "attacker_died": not attacker.alive,
	}
	# Combat is loud: observers learn about the winner's strength.
	for tok in attacker.definition.intel_profile.get("on_combat", []):
		IntelRegistry.acquire(defender.faction_id, tok, attacker.unit_id, "observed")
	EventBus.combat_resolved.emit(attacker.unit_id, defender.unit_id, result)
	return result


func _stat(u: Unit, stat: String, fallback: float) -> float:
	return u.stats.get_value(stat) if u.stats.has_stat(stat) else fallback


func _terrain_bonus(coord: Vector2i) -> float:
	var world := WorldManager.world
	var t := world.get_tile(coord) if world else null
	if t == null:
		return 0.0
	var bonus := t.terrain.defense_bonus if t.terrain else 0.0
	for f in t.features:
		var fd := world.feature_definition(f)
		if fd:
			bonus += fd.defense_bonus
	var site := WorldManager.site_at(coord)
	if site:
		bonus += site.definition.defense_bonus
	return bonus
