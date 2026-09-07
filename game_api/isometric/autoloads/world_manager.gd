## Owns the world: terrain/feature definitions, map definitions, the live
## WorldMap model, sites on it, the site-descent stack (depth-limited), and
## the renderer that draws whatever map is current.
##
## Hierarchy model (same idea as the first-person engine, on tiles):
##   overworld (depth 0)
##     ├── city interior   (depth 1)  entered via a "portal" interaction on the city site
##     └── dungeon level 1 (depth 1)
##           └── dungeon level 2 (depth 2) ... up to max_depth
extends Node

const DEFAULT_MAX_DEPTH := 3

var max_depth: int = DEFAULT_MAX_DEPTH
var grid_config: Dictionary = {}
var terrain_defs: Dictionary = {}     ## id -> TileDefinition
var feature_defs: Dictionary = {}     ## id -> TileDefinition
var map_defs: Dictionary = {}         ## map_id -> MapDefinition
var site_defs: Dictionary = {}        ## site_id -> SiteDefinition

var world: WorldMap = null            ## Current map model.
var current_id: String = ""
var sites: Dictionary = {}            ## site_id -> Site (runtime, current map only)
var map_states: Dictionary = {}       ## map_id -> persisted dict (discovered sites, per-site state, saved WorldMap)
var seed_value: int = 0

var renderer: WorldRenderer = null
var _stack: Array[String] = []        ## Ancestor chain, root first (excludes current).
var _world_root: Node2D = null
var _cached_worlds: Dictionary = {}   ## map_id -> WorldMap (kept alive while descended)


func _ready() -> void:
	EventBus.turn_phase_changed.connect(_on_turn_phase)
	EventBus.unit_moved.connect(_on_unit_moved)
	EventBus.unit_spawned.connect(func(_u, f, _c): refresh_visibility(f))
	EventBus.unit_removed.connect(func(_u): refresh_all_visibility())


func set_world_root(root: Node2D) -> void:
	_world_root = root


func configure(grid: Dictionary, p_max_depth: int) -> void:
	grid_config = grid
	max_depth = p_max_depth


# --- Definitions ---------------------------------------------------------------------

func load_definitions(terrains_path: String, maps_path: String, sites_path: String) -> void:
	terrain_defs.clear()
	feature_defs.clear()
	map_defs.clear()
	site_defs.clear()
	var tdoc := DataLoader.load_json(terrains_path)
	for entry in tdoc.get("terrains", []):
		var t := TileDefinition.from_dict(entry, false)
		terrain_defs[t.id] = t
	for entry in tdoc.get("features", []):
		var f := TileDefinition.from_dict(entry, true)
		feature_defs[f.id] = f
	for entry in DataLoader.load_json_array(maps_path, "maps"):
		var m := MapDefinition.from_dict(entry)
		map_defs[m.id] = m
	for entry in DataLoader.load_json_array(sites_path, "sites"):
		var s := SiteDefinition.from_dict(entry)
		site_defs[s.id] = s
		if map_defs.has(s.map_id):
			map_defs[s.map_id].site_ids.append(s.id)
		else:
			push_error("WorldManager: site '%s' references unknown map '%s'" % [s.id, s.map_id])
	_validate_hierarchy()


func get_map_definition(map_id: String) -> MapDefinition:
	return map_defs.get(map_id)


func get_site_definition(site_id: String) -> SiteDefinition:
	return site_defs.get(site_id)


func get_site(site_id: String) -> Site:
	return sites.get(site_id)


func sites_on_map(map_id: String) -> Array:
	return sites.values() if map_id == current_id else []


func site_at(coord: Vector2i) -> Site:
	var t := world.get_tile(coord) if world else null
	return sites.get(t.site_id) if t and t.site_id != "" else null


func depth_of(map_id: String) -> int:
	var depth := 0
	var def: MapDefinition = map_defs.get(map_id)
	while def and def.parent_id != "":
		depth += 1
		def = map_defs.get(def.parent_id)
		if depth > 64:
			push_error("WorldManager: cycle in map hierarchy near '%s'" % map_id)
			break
	return depth


func current_depth() -> int:
	return _stack.size()


func _validate_hierarchy() -> void:
	for id in map_defs:
		var def: MapDefinition = map_defs[id]
		if def.parent_id != "" and not map_defs.has(def.parent_id):
			push_error("WorldManager: map '%s' references unknown parent '%s'" % [id, def.parent_id])
		if depth_of(id) > max_depth:
			push_error("WorldManager: map '%s' exceeds max_depth %d" % [id, max_depth])



# --- Entering maps ---------------------------------------------------------------

func enter_root_map(map_id: String, seed_val: int) -> void:
	seed_value = seed_val
	_stack.clear()
	map_states.clear()
	_cached_worlds.clear()
	world = null
	_load_map(map_id, "")


func descend(child_id: String, portal_id: String = "") -> void:
	if _stack.size() + 1 > max_depth:
		EventBus.notification.emit("You cannot go any deeper.", "warning")
		return
	var from := current_id
	_stack.append(current_id)
	EventBus.map_transition.emit(from, child_id, portal_id)
	_load_map(child_id, portal_id)


func ascend(portal_id: String = "") -> void:
	if _stack.is_empty():
		return
	var from := current_id
	var parent: String = _stack.pop_back()
	EventBus.map_transition.emit(from, parent, portal_id)
	_load_map(parent, portal_id)


func _load_map(map_id: String, _portal_id: String) -> void:
	var def: MapDefinition = map_defs.get(map_id)
	if def == null:
		push_error("WorldManager: unknown map '%s'" % map_id)
		return
	if world:
		EventBus.world_unloading.emit(current_id)
		_cached_worlds[current_id] = world
	current_id = map_id
	sites.clear()
	if _cached_worlds.has(map_id):
		world = _cached_worlds[map_id]
	else:
		EventBus.world_generating.emit(map_id)
		var topo := GridTopology.create(grid_config)
		world = WorldMap.new(map_id, topo, terrain_defs, feature_defs)
		var saved: Dictionary = get_map_state(map_id).get("world", {})
		if saved.is_empty():
			MapGenerator.generate(world, def, seed_value + hash(map_id) % 100000)
		else:
			world.from_save_data(saved)
	_build_sites(def)
	get_map_state(map_id)["visits"] = int(get_map_state(map_id).get("visits", 0)) + 1
	_ensure_renderer()
	renderer.bind(world)
	EntityRegistry.on_map_entered(map_id)
	refresh_all_visibility()
	EventBus.world_loaded.emit(map_id, current_depth())


func _build_sites(def: MapDefinition) -> void:
	for sid in def.site_ids:
		var sdef: SiteDefinition = site_defs[sid]
		var site := Site.new()
		site.definition = sdef
		var coord := sdef.coord
		if sdef.placement == "random_land":
			coord = MapGenerator.find_land_near(world, Vector2i(world.rng.randi_range(0, world.width() - 1), world.rng.randi_range(0, world.height() - 1)))
		elif not world.tiles.has(coord):
			coord = MapGenerator.find_land_near(world, coord)
		site.coord = coord
		var tile := world.get_tile(coord)
		if tile:
			tile.site_id = sid
		site.build()
		sites[sid] = site


func _ensure_renderer() -> void:
	if renderer:
		return
	if _world_root == null:
		push_error("WorldManager: world root not set; call set_world_root() from main scene")
		_world_root = Node2D.new()
		add_child(_world_root)
	renderer = WorldRenderer.new()
	renderer.name = "WorldRenderer"
	_world_root.add_child(renderer)


## Spawn factions' starting units/territory as declared in factions.json + map starts,
## then site-defined spawns (monsters, guards, NPCs).
func place_starting_entities() -> void:
	for f in FactionRegistry.factions.values():
		var start := _start_coord_for(f)
		f.home_coord = start
		for entry in f.definition.starting_units:
			var uid: String = entry if entry is String else entry.get("unit", "")
			var count: int = 1 if entry is String else int(entry.get("count", 1))
			for i in count:
				var c := MapGenerator.find_land_near(world, start)
				EntityRegistry.spawn(uid, f.id, c, current_id)
		if f.definition.claims_start_territory:
			for coord in world.topology.ring(start, int(f.definition.metadata.get("start_territory_radius", 1))):
				if world.get_tile(coord):
					world.set_owner(coord, f.id)
	for site in sites.values():
		site.spawn_initial_entities()
	refresh_all_visibility()


func _start_coord_for(f: Faction) -> Vector2i:
	var def: MapDefinition = map_defs[current_id]
	var preferred: Vector2i
	if f.definition.start_coord != Vector2i(-1, -1):
		preferred = f.definition.start_coord
	elif def.starts.has(f.id):
		var s: Array = def.starts[f.id]
		preferred = Vector2i(int(s[0]), int(s[1]))
	else:
		preferred = Vector2i(world.rng.randi_range(2, world.width() - 3), world.rng.randi_range(2, world.height() - 3))
	return MapGenerator.find_start_near(world, preferred, int(GameManager.rule("world.start_min_land_neighbors", 6)))



# --- Visibility / intel reveals ----------------------------------------------------------

func refresh_visibility(faction_id: String) -> void:
	if world:
		FogOfWar.recompute(world, faction_id)


func refresh_all_visibility() -> void:
	for fid in FactionRegistry.faction_ids():
		refresh_visibility(fid)


## Apply an IntelToken.reveals spec for a holder (explored knowledge, not live vision).
func apply_reveal_spec(holder: String, spec: Dictionary) -> void:
	if world == null:
		return
	var coords: Array = []
	for pair in spec.get("tiles", []):
		coords.append(Vector2i(int(pair[0]), int(pair[1])))
	var radius := int(spec.get("radius", 0))
	if spec.has("around"):
		var centre := _resolve_anchor(spec["around"])
		if centre != Vector2i(-1, -1):
			coords.append_array(world.topology.ring(centre, radius))
	for sid in spec.get("sites", []):
		var s: Site = sites.get(sid)
		if s:
			coords.append_array(world.topology.ring(s.coord, radius))
			s.discover(holder)
	for uid in spec.get("units", []):
		var u := EntityRegistry.get_unit(uid)
		if u and u.map_id == current_id:
			coords.append_array(world.topology.ring(u.coord, radius))
	var changed := world.reveal(holder, coords, WorldMap.Vis.EXPLORED)
	if not changed.is_empty():
		EventBus.visibility_changed.emit(holder, changed)


func _resolve_anchor(anchor) -> Vector2i:
	if anchor is Array and anchor.size() == 2:
		return Vector2i(int(anchor[0]), int(anchor[1]))
	if anchor is String:
		if sites.has(anchor):
			return sites[anchor].coord
		var u := EntityRegistry.get_unit(anchor)
		if u:
			return u.coord
	return Vector2i(-1, -1)


# --- Per-map persisted state ----------------------------------------------------------

func get_map_state(map_id: String) -> Dictionary:
	if not map_states.has(map_id):
		map_states[map_id] = {"discovered_sites": {}, "sites": {}, "flags": {}, "visits": 0}
	return map_states[map_id]


func _on_turn_phase(_turn: int, phase: int) -> void:
	if phase == TurnManager.Phase.UPKEEP:
		for site in sites.values():
			site.on_upkeep()


func _on_unit_moved(unit_id: String, _from: Vector2i, to: Vector2i) -> void:
	var unit := EntityRegistry.get_unit(unit_id)
	if unit == null:
		return
	refresh_visibility(unit.faction_id)
	var site := site_at(to)
	if site:
		site.on_unit_entered(unit)


# --- Serialisation -----------------------------------------------------------------------

func to_save_data() -> Dictionary:
	if world:
		get_map_state(current_id)["world"] = world.to_save_data()
	for mid in _cached_worlds:
		get_map_state(mid)["world"] = _cached_worlds[mid].to_save_data()
	for site in sites.values():
		site.persist()
	return {"current": current_id, "stack": _stack.duplicate(), "seed": seed_value, "states": map_states.duplicate(true)}


func from_save_data(data: Dictionary) -> void:
	map_states = data.get("states", {})
	seed_value = int(data.get("seed", 0))
	_stack.assign(data.get("stack", []))
	_cached_worlds.clear()
	world = null
	var target: String = data.get("current", "")
	if target != "":
		_load_map(target, "")
