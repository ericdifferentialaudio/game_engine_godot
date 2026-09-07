## Runtime instance of an EntityDefinition on a tile (hero, unit, npc, monster, structure).
##
## Owns stats, inventory/equipment, statuses, abilities and turn action points.
## Rendering is a child AnimatedSprite2D driven from the definition's visual key;
## faction colour is applied via modulate so blockout art stays readable.
class_name Unit
extends Node2D

var unit_id: String = ""
var definition: EntityDefinition
var faction_id: String = ""
var map_id: String = ""
var coord: Vector2i = Vector2i.ZERO
var home_coord: Vector2i = Vector2i.ZERO
var facing: int = 0
var level: int = 1
var xp: int = 0
var action_points: float = 0.0
var alive: bool = true
var custom_name: String = ""
var flags: Dictionary = {}

var stats := CharacterStats.new()
var inventory := Inventory.new()
var statuses: StatusEffects
var abilities: AbilitySet

var _sprite: AnimatedSprite2D
var _label: Label
var _health_bar: ColorRect


func setup(p_id: String, def: EntityDefinition, p_faction: String, p_map: String, p_coord: Vector2i) -> void:
	unit_id = p_id
	definition = def
	faction_id = p_faction
	map_id = p_map
	coord = p_coord
	home_coord = p_coord
	name = "Unit_" + unit_id
	stats.define_from(GameManager.game_config.get("stats", {}), def.stats)
	stats.stat_changed.connect(func(s, v, m): EventBus.unit_stat_changed.emit(unit_id, s, v, m))
	inventory.owner_id = unit_id
	inventory.faction_id = faction_id
	inventory.stats = stats
	inventory.allowed_slots = def.equipment_slots
	statuses = StatusEffects.new(self)
	abilities = AbilitySet.new(self, def.abilities)
	for entry in def.starting_items:
		if entry is String:
			inventory.add_item(entry, 1)
		elif entry is Dictionary:
			inventory.add_item(entry.get("item", ""), int(entry.get("count", 1)))
			if entry.get("equip", false):
				inventory.equip(entry.get("item", ""))
	refresh_action_points()
	_build_visual()


func display_name() -> String:
	return custom_name if custom_name != "" else definition.display_name


func is_hero() -> bool:
	return definition.kind == "hero"


func sight_range() -> int:
	return maxi(1, int(stats.get_value("sight") if stats.has_stat("sight") else 2))


func max_moves() -> float:
	return stats.max_value("moves") if stats.has_stat("moves") else 0.0


func refresh_action_points() -> void:
	action_points = max_moves()
	EventBus.unit_action_points_changed.emit(unit_id, action_points)


func spend_action_points(amount: float) -> void:
	action_points = maxf(0.0, action_points - amount)
	EventBus.unit_action_points_changed.emit(unit_id, action_points)


## Start-of-turn maintenance for the owning faction.
func on_turn_begin() -> void:
	statuses.tick()
	abilities.tick()
	if alive:
		refresh_action_points()
		var regen := float(GameManager.rule("units.heal_per_turn", 0.0))
		if regen > 0.0 and stats.has_stat("health"):
			heal(int(regen))


# --- Movement ------------------------------------------------------------------------

## Move along a path as far as action points allow. Returns tiles actually moved.
func move_to(goal: Vector2i) -> int:
	var world := WorldManager.world
	if world == null or not alive or not definition.is_mobile():
		return 0
	var path := Pathfinder.find_path(world, self, coord, goal)
	return move_along(path)


func move_toward_target(goal: Vector2i) -> int:
	var world := WorldManager.world
	if world == null:
		return 0
	var best := goal
	if world.unit_at(goal) != null:
		var best_d := 1 << 30
		for n in world.topology.neighbors(goal):
			if world.unit_at(n) == null and Pathfinder.move_cost(world, self, n) < Pathfinder.INF_COST:
				var d := world.topology.distance(coord, n)
				if d < best_d:
					best_d = d
					best = n
	return move_to(best)


func move_along(path: Array[Vector2i]) -> int:
	var world := WorldManager.world
	var moved := 0
	for step in path:
		var cost := Pathfinder.move_cost(world, self, step)
		if cost >= Pathfinder.INF_COST:
			break
		# Civ rule: you may always enter a tile if you have any points left.
		if action_points <= 0.0:
			break
		var occupant := world.unit_at(step)
		if occupant and occupant.definition.blocks_tile and step == path[path.size() - 1]:
			break
		var from := coord
		facing = world.topology.facing(from, step)
		world.place_unit(self, step)
		spend_action_points(cost)
		moved += 1
		_update_position()
		EventBus.unit_moved.emit(unit_id, from, step)
		_observe_surroundings()
	return moved


func teleport(p_coord: Vector2i, p_map: String = "") -> void:
	if p_map != "":
		map_id = p_map
	var world := WorldManager.world
	if world and map_id == WorldManager.current_id:
		world.place_unit(self, p_coord)
	coord = p_coord
	_update_position()



## Units are intel sensors: seeing another entity grants its "on_sight" tokens.
func _observe_surroundings() -> void:
	if not GameManager.rule("intel.observe_units", true):
		return
	var world := WorldManager.world
	for other in EntityRegistry.units_on_map(map_id):
		if other == self or other.faction_id == faction_id:
			continue
		if world.topology.distance(coord, other.coord) <= sight_range():
			for tok in other.definition.intel_profile.get("on_sight", []):
				IntelRegistry.acquire(faction_id, tok, other.unit_id, "observed")


# --- Combat / health ------------------------------------------------------------------------

func attack(target: Unit) -> Dictionary:
	if not alive or action_points <= 0.0 or target == null or not target.alive:
		return {}
	if not FactionRegistry.are_hostile(faction_id, target.faction_id):
		return {}
	var result := CombatResolver.active.resolve(self, target)
	spend_action_points(action_points if GameManager.rule("combat.attack_ends_turn", true) else 1.0)
	return result


func take_damage(amount: int, source_id: String = "") -> void:
	if not alive or amount <= 0:
		return
	stats.modify("health", -amount)
	EventBus.unit_damaged.emit(unit_id, amount, source_id)
	_update_health_bar()
	if stats.get_value("health") <= 0.0:
		die(source_id)


func heal(amount: int) -> void:
	if not alive or amount <= 0:
		return
	stats.modify("health", amount)
	EventBus.unit_healed.emit(unit_id, amount)
	_update_health_bar()


func die(killer_id: String = "") -> void:
	if not alive:
		return
	alive = false
	var killer := EntityRegistry.get_unit(killer_id)
	if killer:
		killer.gain_xp(definition.xp_value)
		for tok in definition.intel_profile.get("on_defeat", []):
			IntelRegistry.acquire(killer.faction_id, tok, unit_id, "observed")
		for tok in definition.intel_profile.get("carries", []):
			IntelRegistry.acquire(killer.faction_id, tok, unit_id, "read")
		_drop_loot(killer)
	EventBus.unit_died.emit(unit_id, killer_id)
	EntityRegistry.remove_unit(unit_id)


func _drop_loot(killer: Unit) -> void:
	var rng := WorldManager.world.rng if WorldManager.world else RandomNumberGenerator.new()
	var faction := FactionRegistry.get_faction(killer.faction_id)
	var target_inv: Inventory = killer.inventory if killer.is_hero() else (faction.stockpile if faction else killer.inventory)
	for entry in definition.loot:
		if rng.randf() <= float(entry.get("chance", 1.0)):
			target_inv.add_item(entry.get("item", ""), int(entry.get("count", 1)))
	for id in inventory.items.keys():
		target_inv.add_item(id, inventory.items[id])


func gain_xp(amount: int) -> void:
	if amount <= 0 or definition.level_curve.is_empty():
		return
	xp += amount
	var curve := definition.level_curve
	var need := int(float(curve.get("base_xp", 20)) * pow(float(curve.get("growth", 1.5)), level - 1))
	while xp >= need:
		xp -= need
		level += 1
		for stat in curve.get("per_level", {}):
			stats.raise_base(stat, float(curve["per_level"][stat]))
		EventBus.unit_leveled.emit(unit_id, level)
		need = int(float(curve.get("base_xp", 20)) * pow(float(curve.get("growth", 1.5)), level - 1))


# --- Visual ------------------------------------------------------------------------------------

func _build_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = AssetRegistry.load_sprite_frames(definition.visual_key)
	var names := _sprite.sprite_frames.get_animation_names()
	_sprite.animation = "idle" if _sprite.sprite_frames.has_animation("idle") else names[0]
	_sprite.play()
	var f := FactionRegistry.get_faction(faction_id)
	if f:
		_sprite.modulate = f.color.lerp(Color.WHITE, 0.35)
	add_child(_sprite)
	_label = Label.new()
	_label.text = display_name()
	_label.position = Vector2(-40, -44)
	_label.size = Vector2(80, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	add_child(_label)
	_health_bar = ColorRect.new()
	_health_bar.color = Color(0.2, 0.9, 0.3)
	_health_bar.position = Vector2(-16, 22)
	_health_bar.size = Vector2(32, 3)
	add_child(_health_bar)
	z_index = 4
	_update_position()


func _update_position() -> void:
	if WorldManager.world:
		position = WorldManager.world.topology.to_world(coord)
	visible = map_id == WorldManager.current_id


func _update_health_bar() -> void:
	if _health_bar and stats.has_stat("health"):
		var frac := stats.get_value("health") / maxf(1.0, stats.max_value("health"))
		_health_bar.size.x = 32.0 * frac
		_health_bar.color = Color(0.9, 0.2, 0.2).lerp(Color(0.2, 0.9, 0.3), frac)


func set_fog_visible(v: bool) -> void:
	visible = v and map_id == WorldManager.current_id


# --- Serialisation --------------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return {
		"def": definition.id, "faction": faction_id, "map": map_id, "coord": [coord.x, coord.y],
		"home": [home_coord.x, home_coord.y], "level": level, "xp": xp, "ap": action_points,
		"name": custom_name, "flags": flags, "stats": stats.to_save_data(),
		"inventory": inventory.to_save_data(), "statuses": statuses.to_save_data(),
		"abilities": abilities.to_save_data(),
	}


func from_save_data(d: Dictionary) -> void:
	var h: Array = d.get("home", [coord.x, coord.y])
	home_coord = Vector2i(int(h[0]), int(h[1]))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	action_points = float(d.get("ap", action_points))
	custom_name = d.get("name", "")
	flags = d.get("flags", {})
	stats.from_save_data(d.get("stats", {}))
	inventory.from_save_data(d.get("inventory", {}))
	statuses.from_save_data(d.get("statuses", {}))
	abilities.from_save_data(d.get("abilities", {}))
	if _label:
		_label.text = display_name()
	_update_health_bar()
