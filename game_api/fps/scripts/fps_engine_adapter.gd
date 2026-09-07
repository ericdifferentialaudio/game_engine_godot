## Binds the first-person 3D graphics engine to the shared game_core platform.
##
## Install once at boot (see scripts/fps_bootstrap.gd):
##   CoreContext.install(FpsEngineAdapter.new())
##
## Time unit for this engine is **game seconds** from GameClock, so a core
## `decay_turns` value on an intel token is read as "seconds of game time" and
## every {"time": [...]} query compares against the same clock.
##
## The FPS engine is single-holder: there is one player journal. `holder` is
## normally the constant [constant PLAYER_HOLDER].
class_name FpsEngineAdapter
extends CoreEngineAdapter

const PLAYER_HOLDER := "player"


func _init() -> void:
	engine_id = "fps"


# --- Time --------------------------------------------------------------------

func now() -> float:
	return GameClock.now() if GameClock else 0.0


# --- Space -------------------------------------------------------------------

## Straight-line distance in metres between two Vector3 positions.
func distance(a, b) -> float:
	if a is Vector3 and b is Vector3:
		return a.distance_to(b)
	return 0.0


func position_of(entity_id: String):
	var actor := _find_actor(entity_id)
	return actor.global_position if actor else null


func can_see(observer_id: String, target_id: String) -> bool:
	var observer := _find_actor(observer_id)
	var target := _find_actor(target_id)
	if observer == null or target == null:
		return false
	var perception = observer.get_node_or_null("Perception")
	if perception and perception.has_method("can_see"):
		return perception.can_see(target)
	return false


func _find_actor(entity_id: String) -> Node3D:
	if entity_id == PLAYER_HOLDER:
		return GameManager.player
	for node in Engine.get_main_loop().root.get_tree().get_nodes_in_group("actors"):
		if node.name == entity_id or node.get("actor_id") == entity_id:
			return node
	return null


# --- Entities / factions ------------------------------------------------------

## In the FPS engine hostility is reputation-driven rather than diplomatic.
func are_hostile(a: String, b: String) -> bool:
	if a == b:
		return false
	var def := CoreRegistry.get_def("factions", a) as CoreFactionDefinition
	if def and def.is_hostile_to(b):
		return true
	return GameManager.get_reputation(b) < 0 if a == PLAYER_HOLDER else false


func unit_count(_holder: String, def_id: String = "") -> int:
	var n := 0
	for node in Engine.get_main_loop().root.get_tree().get_nodes_in_group("actors"):
		if def_id == "" or node.get("definition_id") == def_id:
			n += 1
	return n


## The FPS engine has one player, so holder flags are the global flags.
func holder_flag(_holder: String, flag: String) -> bool:
	return GameManager.has_flag(flag)


## Currency carried by the player's inventory.
func holder_resource(_holder: String, resource_id: String) -> float:
	var player := GameManager.player
	if player == null:
		return 0.0
	var inv = player.get("inventory")
	if inv and inv.has_method("get_currency"):
		return float(inv.get_currency(resource_id))
	return 0.0


## Reputation mapped onto the shared stance vocabulary.
func stance(_holder: String, other: String) -> String:
	var rep := GameManager.get_reputation(other)
	if rep <= -50:
		return "war"
	if rep < 0:
		return "hostile"
	if rep >= 50:
		return "allied"
	if rep > 0:
		return "friendly"
	return "neutral"


## "Owning" a POI in the FPS engine means having discovered/cleared it.
func owns_site(_holder: String, site_id: String) -> bool:
	return GameManager.has_flag("poi_cleared:%s" % site_id)


# --- Presentation -------------------------------------------------------------

func notify(text: String, category: String = "info") -> void:
	EventBus.notification.emit(text, category)


## Map knowledge in the FPS engine = marking maps/POIs as discovered.
func reveal(_holder: String, reveals: Dictionary) -> void:
	for map_id in reveals.get("maps", []):
		GameManager.set_flag("map_known:%s" % str(map_id), true)
	for poi_id in reveals.get("sites", []):
		GameManager.set_flag("poi_known:%s" % str(poi_id), true)
		EventBus.poi_discovered.emit(str(poi_id), "")
