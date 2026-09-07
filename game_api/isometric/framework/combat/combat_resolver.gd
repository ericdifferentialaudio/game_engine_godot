## Pluggable combat strategy. Games swap the resolver at startup:
##   CombatResolver.active = MyResolver.new()
## The default is a Civ-like strength comparison with terrain defence and a
## small seeded random swing (rules.combat in game.json):
##   {"randomness": 0.2, "base_damage": 3, "defender_terrain_bonus": true, "attack_ends_turn": true,
##    "require_line_of_sight": true, "monster_weakness_bonus": 3.0, "monster_resistance_penalty": 1.0}
##
## Line-of-sight gating and the monster-weakness/damage-type bonus are ported
## from Aevum: Age of Shrines' combat_engine.py (has_line_of_sight(),
## _classify_attack()/_apply_monster_weakness()), generalised from Aevum's
## hardcoded clan/monster-lair model to data-driven EntityDefinition metadata:
##   attacker units.json: {"metadata": {"damage_type": "fire"}}   (default "physical")
##   monster  units.json: {"metadata": {"weak_to": "fire", "resists": "physical"}}
## A faction only gets the weakness bonus once it knows the monster's
## weakness, via the same intel-token mechanism attackers already use
## elsewhere (metadata key "weakness_intel": token id; granted/known through
## CoreIntel/IntelRegistry like any other fact).
class_name CombatResolver
extends RefCounted

static var active: CombatResolver = CombatResolver.new()


func resolve(attacker: Unit, defender: Unit) -> Dictionary:
	if GameManager.rule("combat.require_line_of_sight", true) and WorldManager.world:
		if not WorldManager.world.topology.has_line_of_sight(WorldManager.world, attacker.coord, defender.coord):
			return {}

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

	dmg_to_defender = _apply_monster_weakness(attacker, defender, dmg_to_defender)

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


## +bonus damage if [param attacker]'s faction knows [param defender]'s
## elemental weakness; -penalty (never below 1) if it hits a known
## resistance instead. No effect if the defender declares no weakness/
## resistance metadata, or the weakness is not yet known to the attacker.
func _apply_monster_weakness(attacker: Unit, defender: Unit, damage: int) -> int:
	var weak_to: String = str(defender.definition.metadata.get("weak_to", ""))
	var resists: String = str(defender.definition.metadata.get("resists", ""))
	if weak_to == "" and resists == "":
		return damage

	var weakness_token: String = str(defender.definition.metadata.get("weakness_intel", ""))
	if weakness_token != "" and not IntelRegistry.has(attacker.faction_id, weakness_token):
		return damage   # weakness unknown to this faction -> no effect either way

	var damage_type: String = str(attacker.definition.metadata.get("damage_type", "physical"))
	if weak_to != "" and damage_type == weak_to:
		return damage + int(GameManager.rule("combat.monster_weakness_bonus", 3.0))
	if resists != "" and damage_type == resists:
		return maxi(1, damage - int(GameManager.rule("combat.monster_resistance_penalty", 1.0)))
	return damage


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
