## Base for every living thing: player, NPCs, monsters, summons.
##
## An Actor is a CharacterBody3D plus composable child components. Missing
## components are created automatically so a bare Actor node is still valid.
## The player is simply an Actor whose Brain is a PlayerBrain.
##
## Scene layout (minimum):
##   Actor (CharacterBody3D, this script)
##     CollisionShape3D
##     [components...]  Health, Stats, Resources, StatusEffects, Inventory,
##                      Equipment, AbilityCaster, Perception, Faction,
##                      Damageable, Brain (PlayerBrain | AIBrain)
class_name Actor
extends CharacterBody3D

signal definition_applied(def: ActorDefinition)
signal died(killer: Node3D)

const COMPONENT_SCRIPTS := {
	"health": preload("res://framework/actor/components/health.gd"),
	"stats": preload("res://framework/actor/components/stats.gd"),
	"resources": preload("res://framework/actor/components/resources.gd"),
	"status_effects": preload("res://framework/actor/components/status_effects.gd"),
	"inventory": preload("res://framework/actor/components/inventory.gd"),
	"equipment": preload("res://framework/actor/components/equipment.gd"),
	"ability_caster": preload("res://framework/actor/components/ability_caster.gd"),
	"perception": preload("res://framework/actor/components/perception.gd"),
	"faction": preload("res://framework/actor/components/faction.gd"),
	"damageable": preload("res://framework/actor/components/damageable.gd"),
}

@export var actor_def_id: String = ""      ## ActorDefinition id; applied on ready if set.
@export var auto_create_components: bool = true

var actor_def: ActorDefinition = null
var actor_uid: String = ""                  ## Stable per-instance id for persistence.
var is_dead: bool = false
var spawned_by_map: String = ""             ## Map id when spawned from a spawn table.
var spawn_key: String = ""                  ## Spawn-table key; recorded in map state on death.
var corpse_seconds: float = 6.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Typed component accessors (filled in _ready)
var health: Health
var stats: Stats
var resources: Resources
var status_effects: StatusEffects
var inventory: Inventory
var equipment: Equipment
var ability_caster: AbilityCaster
var perception: Perception
var faction: Faction
var damageable: Damageable
var brain: Brain

var _components: Array[ActorComponent] = []


func _ready() -> void:
	add_to_group("actors")
	if actor_uid == "":
		actor_uid = "%s_%d" % [actor_def_id if actor_def_id != "" else name, get_instance_id()]
	_discover_components()
	for c in _components:
		c.setup(self)
	if brain:
		brain.setup(self)
	if actor_def_id != "":
		apply_definition(DefinitionRegistry.get_def("actors", actor_def_id) as ActorDefinition)
	EventBus.actor_spawned.emit(self)


func _discover_components() -> void:
	for child in get_children():
		if child is Brain:
			brain = child
		elif child is ActorComponent:
			_components.append(child)
			_assign(child)
	if auto_create_components:
		for key in COMPONENT_SCRIPTS:
			if get(key) == null:
				var c: ActorComponent = COMPONENT_SCRIPTS[key].new()
				c.name = key.to_pascal_case()
				add_child(c)
				_components.append(c)
				_assign(c)


func _assign(c: ActorComponent) -> void:
	if c is Health: health = c
	elif c is Stats: stats = c
	elif c is Resources: resources = c
	elif c is StatusEffects: status_effects = c
	elif c is Inventory: inventory = c
	elif c is Equipment: equipment = c
	elif c is AbilityCaster: ability_caster = c
	elif c is Perception: perception = c
	elif c is Faction: faction = c
	elif c is Damageable: damageable = c


## Apply an ActorDefinition: base stats, resources, faction, abilities, gear.
func apply_definition(def: ActorDefinition) -> void:
	if def == null:
		return
	actor_def = def
	var role_group := def.role_name()
	add_to_group(role_group if role_group != "boss" else "monster")
	if def.role == ActorDefinition.Role.BOSS:
		add_to_group("boss")
	for c in _components:
		c._definition_applied(def)
	if brain:
		brain._definition_applied(def)
	definition_applied.emit(def)


# --- Combat entry points -----------------------------------------------------

## Route damage through Damageable (mitigation) -> Health.
func take_damage(info: DamageInfo) -> float:
	if is_dead or damageable == null:
		return 0.0
	return damageable.receive(info)


func heal(amount: float, source: Node3D = null) -> float:
	if is_dead or health == null:
		return 0.0
	return health.heal(amount, source)


func die(killer: Node3D = null) -> void:
	if is_dead:
		return
	is_dead = true
	if brain:
		brain.set_process(false)
		brain.set_physics_process(false)
	died.emit(killer)
	EventBus.actor_died.emit(self, killer)
	if is_player():
		GameManager.on_player_died(killer)
		return
	_drop_loot()
	if actor_def and actor_def.raw.get("death_flag", "") != "":
		GameManager.set_flag(str(actor_def.raw["death_flag"]), true)
	if actor_def and actor_def.raw.get("death_intel", "") != "":
		IntelRegistry.acquire(str(actor_def.raw["death_intel"]), actor_uid)
	if spawned_by_map != "":
		var st := MapManager.get_map_state(spawned_by_map)
		if not st.has("killed"):
			st["killed"] = []
		if spawn_key != "" and not st["killed"].has(spawn_key):
			st["killed"].append(spawn_key)
	# Leave the body briefly, then remove it.
	collision_layer = 0
	collision_mask = 0
	get_tree().create_timer(corpse_seconds).timeout.connect(func(): if is_instance_valid(self): queue_free())


## Everything carried (inventory + equipped) becomes a WorldPickup at the feet.
func _drop_loot() -> void:
	var drops: Dictionary = {}
	if inventory:
		for inst in inventory.items:
			drops[inst.def.id] = drops.get(inst.def.id, 0) + inst.count
	if equipment:
		for slot in equipment.equipped_items:
			var inst: ItemInstance = equipment.equipped_items[slot]
			if not inst.def.raw.get("no_drop", false):
				drops[inst.def.id] = drops.get(inst.def.id, 0) + inst.count
	if actor_def:
		for item_id in actor_def.raw.get("drops", {}):
			drops[item_id] = drops.get(item_id, 0) + int(actor_def.raw["drops"][item_id])
	if drops.is_empty() or get_parent() == null:
		return
	var pickup := WorldPickup.new()
	pickup.items = drops
	pickup.label = "the remains of %s" % (actor_def.display_name if actor_def else name)
	pickup.name = "Loot_%s" % actor_uid
	get_parent().add_child(pickup)
	pickup.global_position = global_position
	if MapManager.current_map:
		MapManager.current_map.register_loot(pickup, spawn_key, drops)


func is_hostile_to(other: Actor) -> bool:
	return faction != null and other != null and faction.is_hostile_to(other)


func is_player() -> bool:
	return brain is PlayerBrain


## Final value of a stat (base + equipment + status effects).
func stat(stat_name: String, default: float = 0.0) -> float:
	return stats.get_final(stat_name, default) if stats else default


# --- Persistence -------------------------------------------------------------

func to_save_data() -> Dictionary:
	var data := {
		"def": actor_def_id,
		"uid": actor_uid,
		"dead": is_dead,
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"components": {},
	}
	for c in _components:
		var d := c.to_save_data()
		if not d.is_empty():
			data["components"][c.name] = d
	if brain:
		var bd := brain.to_save_data()
		if not bd.is_empty():
			data["brain"] = bd
	return data


func from_save_data(data: Dictionary) -> void:
	actor_uid = str(data.get("uid", actor_uid))
	is_dead = bool(data.get("dead", false))
	var p: Array = data.get("position", [global_position.x, global_position.y, global_position.z])
	global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(data.get("yaw", rotation.y))
	var comps: Dictionary = data.get("components", {})
	for c in _components:
		if comps.has(c.name):
			c.from_save_data(comps[c.name])
	if brain and data.has("brain"):
		brain.from_save_data(data["brain"])
