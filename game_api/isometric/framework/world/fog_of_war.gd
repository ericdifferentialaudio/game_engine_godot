## Recomputes per-faction visibility from unit sight, owned tiles and sites,
## and emits EventBus.visibility_changed. Intel "reveals" add EXPLORED tiles
## independently through WorldManager.apply_reveal_spec.
##
## rules.fog (game.json):
##   {"shared_vision_allies": true, "owned_tile_sight": 1, "site_sight": 2}
class_name FogOfWar
extends RefCounted


static func recompute(world: WorldMap, faction_id: String) -> void:
	if world == null or world.fog_mode == "none":
		return
	var before: Dictionary = world.fog.get(faction_id, {}).duplicate()
	world.clear_visible(faction_id)
	var visible: Array = []
	for unit in EntityRegistry.units_of(faction_id):
		if unit.map_id != world.map_id:
			continue
		visible.append_array(world.compute_sight(unit.coord, unit.sight_range()))
	var owned_sight := int(GameManager.rule("fog.owned_tile_sight", 1))
	for tile in world.tiles.values():
		if tile.owner_id == faction_id:
			visible.append_array(world.topology.ring(tile.coord, owned_sight))
	var site_sight := int(GameManager.rule("fog.site_sight", 2))
	for site in WorldManager.sites_on_map(world.map_id):
		if site.owner_id == faction_id:
			visible.append_array(world.topology.ring(site.coord, site_sight))
	if GameManager.rule("fog.shared_vision_allies", true):
		for other in FactionRegistry.faction_ids():
			if other != faction_id and FactionRegistry.relationship_matches(faction_id, other, "allies"):
				for unit in EntityRegistry.units_of(other):
					if unit.map_id == world.map_id:
						visible.append_array(world.compute_sight(unit.coord, unit.sight_range()))
	world.reveal(faction_id, visible, WorldMap.Vis.VISIBLE)
	var changed: Array = []
	var after: Dictionary = world.fog.get(faction_id, {})
	for c in after:
		if before.get(c, -1) != after[c]:
			changed.append(c)
	if not changed.is_empty():
		EventBus.visibility_changed.emit(faction_id, changed)
		if GameManager.rule("intel.observe_sites", true):
			_observe_sites(world, faction_id, changed)


## Seeing a site for the first time discovers it and grants its "observed" intel.
static func _observe_sites(world: WorldMap, faction_id: String, coords: Array) -> void:
	for c in coords:
		if not world.is_visible(faction_id, c):
			continue
		var tile := world.get_tile(c)
		if tile and tile.site_id != "":
			var site := WorldManager.get_site(tile.site_id)
			if site:
				site.discover(faction_id)
