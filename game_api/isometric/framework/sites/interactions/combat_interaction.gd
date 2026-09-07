## Forces a combat resolution between the actor and a target unit or a
## site-defined guardian (spawned then fought immediately).
##   {"kind": "combat", "target": "nearest_enemy" | "guardian", "guardian": {"unit": "bone_warden", "faction": "monsters"},
##    "on_victory": [{"kind": "reward", ...}], "once": true}
class_name CombatInteraction
extends Interaction


func _on_setup() -> void:
	kind = "combat"


func _execute(holder: String, actor: Unit, target) -> void:
	if actor == null:
		return
	var defender: Unit = target if target is Unit else null
	var mode: String = spec.get("target", "nearest_enemy")
	if defender == null and mode == "guardian" and spec.has("guardian"):
		var g: Dictionary = spec["guardian"]
		var world := WorldManager.world
		for c in world.topology.neighbors(actor.coord):
			if world.unit_at(c) == null and world.get_tile(c) and world.get_tile(c).terrain.passable:
				defender = EntityRegistry.spawn(g.get("unit", ""), g.get("faction", "monsters"), c, WorldManager.current_id)
				break
	if defender == null:
		var best_d := 1 << 30
		for u in EntityRegistry.units_on_map(actor.map_id):
			if FactionRegistry.are_hostile(holder, u.faction_id):
				var d := WorldManager.world.topology.distance(actor.coord, u.coord)
				if d < best_d:
					best_d = d
					defender = u
	if defender == null:
		return
	var result := CombatResolver.active.resolve(actor, defender)
	if result.get("defender_died", false):
		for eff in spec.get("on_victory", []):
			var inter := InteractionFactory.create(eff, site if site else actor)
			if inter:
				inter.run_for_holder(holder, source_id(), actor)
