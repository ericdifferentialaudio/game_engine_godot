## Spawns units near the site/actor (ambushes, summoned guards, rescued allies).
##   {"kind": "spawn", "unit": "wolf", "faction": "monsters", "count": 2, "radius": 1,
##    "once": true, "message": "Wolves burst from the undergrowth!"}
## "faction": "actor" spawns for the acting faction.
class_name SpawnInteraction
extends Interaction


func _on_setup() -> void:
	kind = "spawn"


func _execute(holder: String, actor: Unit, _target) -> void:
	var world := WorldManager.world
	if world == null:
		return
	var centre: Vector2i = site.coord if site else (actor.coord if actor else Vector2i.ZERO)
	var faction: String = spec.get("faction", "actor")
	if faction == "actor":
		faction = holder
	var count := int(spec.get("count", 1))
	var ring := world.topology.ring(centre, int(spec.get("radius", 1)))
	for c in ring:
		if count <= 0:
			break
		var t := world.get_tile(c)
		if t and t.terrain.passable and world.unit_at(c) == null:
			var u := EntityRegistry.spawn(spec.get("unit", ""), faction, c, WorldManager.current_id)
			if u:
				u.home_coord = centre
				count -= 1
