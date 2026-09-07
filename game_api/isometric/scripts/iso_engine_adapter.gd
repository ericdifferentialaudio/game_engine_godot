## Binds the isometric graphics engine to the shared game_core platform.
##
## Install once at boot (see scripts/iso_bootstrap.gd):
##   CoreContext.install(IsoEngineAdapter.new())
##
## Time unit for this engine is the **turn number**, so every core decay value
## (`decay_turns`) and every {"time": [...]} query is expressed in turns.
class_name IsoEngineAdapter
extends CoreEngineAdapter


func _init() -> void:
	engine_id = "isometric"


# --- Time --------------------------------------------------------------------

## Absolute time in turns; fractional within a turn in time-based modes.
func now() -> float:
	return GameClock.now()


# --- Space -------------------------------------------------------------------

## Grid distance in tiles between two Vector2i coords.
func distance(a, b) -> float:
	if not (a is Vector2i and b is Vector2i):
		return 0.0
	var world = WorldManager.world
	if world == null or world.topology == null:
		return 0.0
	return float(world.topology.distance(a, b))


func position_of(entity_id: String):
	var u = EntityRegistry.get_unit(entity_id)
	return u.coord if u else null


func can_see(observer_id: String, target_id: String) -> bool:
	var o = EntityRegistry.get_unit(observer_id)
	var t = EntityRegistry.get_unit(target_id)
	if o == null or t == null:
		return false
	var sight: float = o.stats.get_value("sight") if o.stats.has_stat("sight") else 1.0
	return distance(o.coord, t.coord) <= sight


# --- Entities / factions ------------------------------------------------------

func are_hostile(a: String, b: String) -> bool:
	return FactionRegistry.are_hostile(a, b)


func unit_count(holder: String, def_id: String = "") -> int:
	return EntityRegistry.count_units(holder, def_id)


func holder_flag(holder: String, flag: String) -> bool:
	var f = FactionRegistry.get_faction(holder)
	return f != null and f.has_flag(flag)


func holder_resource(holder: String, resource_id: String) -> float:
	var f = FactionRegistry.get_faction(holder)
	return f.get_resource(resource_id) if f else 0.0


func stance(holder: String, other: String) -> String:
	var f = FactionRegistry.get_faction(holder)
	return f.stance_toward(other) if f else "neutral"


func owns_site(holder: String, site_id: String) -> bool:
	var site = WorldManager.get_site_definition(site_id)
	if site == null or WorldManager.world == null:
		return false
	return WorldManager.world.owner_of(site.coord) == holder


# --- Presentation -------------------------------------------------------------

func notify(text: String, category: String = "info") -> void:
	EventBus.notification.emit(text, category)


## Reveal tiles/sites/units to a faction's fog of war.
func reveal(holder: String, reveals: Dictionary) -> void:
	var world = WorldManager.world
	if world == null:
		return
	var coords: Array = []
	for c in reveals.get("tiles", []):
		if c is Array and c.size() == 2:
			coords.append(Vector2i(int(c[0]), int(c[1])))
	var radius := int(reveals.get("radius", 0))
	var around = reveals.get("around", null)
	if around != null and radius > 0:
		var centre = around
		if around is String:
			centre = position_of(around)
			if centre == null:
				var site = WorldManager.get_site_definition(around)
				centre = site.coord if site else null
		elif around is Array and around.size() == 2:
			centre = Vector2i(int(around[0]), int(around[1]))
		if centre is Vector2i:
			coords.append_array(world.topology.in_radius(centre, radius))
	if not coords.is_empty():
		world.reveal_tiles(holder, coords)
		EventBus.visibility_changed.emit(holder, coords)
