## Runtime site on the current map. Handles per-faction discovery/visibility
## gating, unit entry, ordered Interaction dispatch, spawns and persisted state.
## Its visual is a Node2D placed by WorldRenderer (see build()).
class_name Site
extends RefCounted

var definition: SiteDefinition
var coord: Vector2i = Vector2i.ZERO
var owner_id: String = ""
var discovered_by: Dictionary = {}    ## faction_id -> true
var visual: Node2D = null
var _interactions: Array = []         ## Array[Interaction]
var _spawned: Dictionary = {}         ## spawn index -> Array[unit_id]
var _respawn_at: Dictionary = {}      ## spawn index -> turn


func id() -> String:
	return definition.id


func build() -> void:
	owner_id = definition.owner_id
	var st := _state()
	owner_id = st.get("owner", owner_id)
	discovered_by = st.get("discovered_by", {})
	_interactions.clear()
	for i in definition.interactions.size():
		var spec: Dictionary = definition.interactions[i].duplicate()
		spec["index"] = i
		var inter := InteractionFactory.create(spec, self)
		if inter:
			_interactions.append(inter)
	if owner_id != "" and WorldManager.world:
		WorldManager.world.set_owner(coord, owner_id)
	if WorldManager.renderer:
		visual = WorldManager.renderer.add_site_visual(self)


## Whether a faction may perceive this site at all (hidden_until intel gate).
func is_revealed_to(faction_id: String) -> bool:
	return definition.hidden_until.is_empty() or IntelRegistry.evaluate(definition.hidden_until, faction_id)


func is_discovered_by(faction_id: String) -> bool:
	return discovered_by.get(faction_id, false)


func discover(faction_id: String) -> void:
	if faction_id == "" or is_discovered_by(faction_id) or not is_revealed_to(faction_id):
		return
	discovered_by[faction_id] = true
	_state()["discovered_by"] = discovered_by
	for tok in definition.discover_intel:
		IntelRegistry.acquire(faction_id, tok, definition.id, "observed")
	EventBus.site_discovered.emit(definition.id, faction_id)
	if faction_id == GameManager.player_faction_id:
		EventBus.notification.emit("Discovered: %s" % definition.display_name, "discovery")


func on_unit_entered(unit: Unit) -> void:
	discover(unit.faction_id)
	EventBus.site_entered.emit(definition.id, unit.unit_id)
	if not definition.enter_requires.is_empty() and not IntelRegistry.evaluate(definition.enter_requires, unit.faction_id):
		if unit.faction_id == GameManager.player_faction_id:
			EventBus.notification.emit("You lack the knowledge to make use of %s." % definition.display_name, "warning")
		return
	if definition.capturable and owner_id != unit.faction_id and FactionRegistry.are_hostile(owner_id, unit.faction_id) and GameManager.rule("sites.capture_on_enter", true):
		capture(unit.faction_id)
	interact(unit)


## Run interactions in order for the acting unit's faction.
func interact(by: Unit) -> void:
	for inter in _interactions:
		if inter.can_run(by):
			inter.run(by)
			EventBus.site_interacted.emit(definition.id, inter.kind)
			if inter.consumes_interaction:
				break


func capture(faction_id: String) -> void:
	if owner_id == faction_id:
		return
	owner_id = faction_id
	_state()["owner"] = owner_id
	if WorldManager.world:
		WorldManager.world.set_owner(coord, faction_id)
	if faction_id == GameManager.player_faction_id:
		EventBus.notification.emit("Captured %s" % definition.display_name, "success")


func spawn_initial_entities() -> void:
	for i in definition.spawns.size():
		_do_spawn(i)


func _do_spawn(i: int) -> void:
	var spec: Dictionary = definition.spawns[i]
	var world := WorldManager.world
	var ids: Array = []
	for k in int(spec.get("count", 1)):
		var ring := world.topology.ring(coord, int(spec.get("radius", 0)))
		var target := coord
		for c in ring:
			var t := world.get_tile(c)
			if t and t.terrain.passable and world.unit_at(c) == null:
				target = c
				if world.rng.randf() < 0.5:
					break
		var u := EntityRegistry.spawn(spec.get("unit", ""), spec.get("faction", owner_id), target, WorldManager.current_id)
		if u:
			u.home_coord = coord
			ids.append(u.unit_id)
	_spawned[i] = ids


## Respawn logic each UPKEEP; site yields to owner.
func on_upkeep() -> void:
	for i in definition.spawns.size():
		var spec: Dictionary = definition.spawns[i]
		var respawn := int(spec.get("respawn_turns", 0))
		if respawn <= 0:
			continue
		var alive := 0
		for uid in _spawned.get(i, []):
			var u := EntityRegistry.get_unit(uid)
			if u and u.alive:
				alive += 1
		if alive == 0:
			if not _respawn_at.has(i):
				_respawn_at[i] = GameClock.turn + respawn
			elif GameClock.turn >= int(_respawn_at[i]):
				_respawn_at.erase(i)
				_do_spawn(i)
	if owner_id != "":
		var f := FactionRegistry.get_faction(owner_id)
		if f:
			for k in definition.yields:
				f.add_resource(k, float(definition.yields[k]))


## Per-site persisted state lives inside the map state.
func _state() -> Dictionary:
	var ms := WorldManager.get_map_state(definition.map_id)
	if not ms["sites"].has(definition.id):
		ms["sites"][definition.id] = {}
	return ms["sites"][definition.id]


func get_state() -> Dictionary:
	return _state()


func persist() -> void:
	var st := _state()
	st["owner"] = owner_id
	st["discovered_by"] = discovered_by
	st["coord"] = [coord.x, coord.y]
