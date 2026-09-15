## Aevum's two combat carve-outs the shared CombatResolver cannot express as data:
##   * Sacred ground: no combat at all within a shrine's sacred_ground_radius,
##     attacker or defender (shrines.json "sacred_ground_radius": 2).
##   * The Dragon's ancient armour: the first N damage per turn is negated
##     outright, before the normal defence math (monsters.json "ancient_armour").
## Everything else (terrain defence, randomness, monster weakness/resistance)
## is the shared resolver unchanged, so this simply wraps it.
extends "res://framework/combat/combat_resolver.gd"


func resolve(attacker: Unit, defender: Unit) -> Dictionary:
	if _on_sacred_ground(attacker.coord) or _on_sacred_ground(defender.coord):
		return {}
	var result := super.resolve(attacker, defender)
	if result.is_empty():
		return result
	if defender.faction_id == "dragon":
		_reapply_dragon_armour(defender, result)
	return result


func _on_sacred_ground(coord: Vector2i) -> bool:
	var world := WorldManager.world
	if world == null:
		return false
	for site in WorldManager.sites.values():
		if site.definition.category != "shrine":
			continue
		var radius := int(site.definition.metadata.get("sacred_ground_radius",
			GameManager.rule("aevum.sacred_ground_radius", 2)))
		if world.topology.distance(coord, site.coord) <= radius:
			return true
	return false


## The base resolver already applied full damage before we can intervene, so
## the dragon's armour is modelled as a partial heal-back of the negated
## amount rather than pre-empting take_damage(); this keeps the shared
## resolver simple and dependency-free while still being correct per-turn.
func _reapply_dragon_armour(dragon: Unit, result: Dictionary) -> void:
	var dealt := int(result.get("damage_to_defender", 0))
	if dealt <= 0 or not dragon.alive:
		return
	var tree := dragon.get_tree()
	if tree == null:
		return
	var nodes := tree.get_nodes_in_group("aevum_boot")
	var boot: Node = nodes[0] if not nodes.is_empty() else null
	if boot == null or not boot.has_method("dragon_negate_damage"):
		return
	var should_take: int = boot.call("dragon_negate_damage", dragon, dealt)
	var refund: int = dealt - should_take
	if refund > 0:
		dragon.heal(refund)
