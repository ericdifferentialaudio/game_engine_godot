## Spawns units near the place or actor (ambushes, guards, rescued allies).
##
##   {"kind": "spawn", "unit": "wolf", "faction": "monsters", "count": 2,
##    "radius": 1, "once": true, "message": "Wolves burst from the undergrowth!"}
##
## "faction": "actor" spawns for the acting holder. Placement is engine-specific
## (free tile in a ring vs. navmesh point), so it is delegated to the adapter.
class_name CoreSpawnInteraction
extends CoreInteraction

signal spawned(holder: String, unit_ids: Array)


func _on_setup() -> void:
	kind = "spawn"


func _execute(holder: String, actor, _target) -> void:
	var faction := str(spec.get("faction", "actor"))
	if faction == "actor":
		faction = holder
	var resolved := spec.duplicate()
	resolved["faction"] = faction
	var ids := CoreContext.adapter.spawn_units(resolved, holder, actor)
	if not ids.is_empty():
		spawned.emit(holder, ids)
