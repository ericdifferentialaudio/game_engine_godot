## AI decision-maker. M1 provides the state skeleton, navigation agent slot,
## and threat selection from Perception; M3 fills in behaviour trees / utility
## scoring, patrol routes, schedules and group tactics.
class_name AIBrain
extends Brain

enum State { IDLE, PATROL, SCHEDULE, INVESTIGATE, CHASE, ATTACK, FLEE, RETURN, DEAD }

signal state_changed(previous: State, current: State)

@export var think_interval: float = 0.2

var state: State = State.IDLE
var target: Actor = null
var home_position: Vector3
var behaviour: Dictionary = {}          ## from ActorDefinition.behaviour
var nav_agent: NavigationAgent3D = null

var _think_timer := 0.0


func _brain_ready() -> void:
	home_position = actor.global_position
	nav_agent = actor.get_node_or_null("NavigationAgent3D")
	if nav_agent == null:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		actor.add_child(nav_agent)
	if actor.perception:
		actor.perception.awareness_changed.connect(_on_awareness_changed)
	actor.died.connect(func(_k): set_state(State.DEAD))
	if actor.health:
		actor.health.damaged.connect(func(_a, _i): provoked = true)


func _definition_applied(def: ActorDefinition) -> void:
	behaviour = def.behaviour
	if actor.stats and not actor.stats.base.has("move_speed"):
		actor.stats.set_base("move_speed", def.move_speed)


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if state == State.DEAD or is_disabled():
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		actor.move_and_slide()
		return
	_think_timer += delta
	if _think_timer >= think_interval:
		_think_timer = 0.0
		think()
	_move(delta)


## High-level decision step (M3 replaces with BT/utility). Minimal M1 logic:
## engage visible hostiles, otherwise idle at home.
func think() -> void:
	if actor.perception:
		var threat := actor.perception.highest_threat()
		# Passive actors ignore faction hostility until personally provoked
		# (attacked, or a dialogue node marked "hostile").
		if threat and behaviour.get("passive_until_provoked", false) and not provoked \
				and not (actor.faction and threat.actor_uid in actor.faction.personal_hostiles):
			threat = null
		if threat and not threat.is_dead and actor.perception.awareness_of(threat) >= Perception.Awareness.ALERT:
			target = threat
			var flee_below := float(behaviour.get("flee_below", 0.0))
			if actor.health and actor.health.is_below(flee_below):
				set_state(State.FLEE)
			else:
				set_state(State.CHASE)
			return
		if threat and actor.perception.awareness_of(threat) == Perception.Awareness.SUSPICIOUS:
			set_state(State.INVESTIGATE)
			return
	target = null
	if behaviour.get("wander", false):
		_think_wander()
		return
	set_state(State.IDLE if actor.global_position.distance_to(home_position) < 1.0 else State.RETURN)


# --- Wandering / stealing ------------------------------------------------------
## behaviour: {"wander": true, "wander_radius": 5.0, "steal": true, "steal_range": 2.2,
##             "steal_cooldown": 25.0, "steal_tags": ["treasure"], "no_steal_flag": "thief_named"}

var provoked: bool = false
var _wander_target: Vector3
var _wander_wait := 0.0
var _steal_ready_at := 0.0


func _think_wander() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if behaviour.get("steal", false):
		_try_steal(now)
	if state != State.PATROL:
		set_state(State.PATROL)
		_pick_wander_point()
	elif actor.global_position.distance_to(_wander_target) < 0.8:
		if _wander_wait <= 0.0:
			_wander_wait = CoreContext.rng().randf_range(1.0, 3.0)
		_wander_wait -= think_interval
		if _wander_wait <= 0.0:
			_pick_wander_point()


func _pick_wander_point() -> void:
	var r := float(behaviour.get("wander_radius", 5.0))
	var rng := CoreContext.rng()
	var off := Vector3(rng.randf_range(-r, r), 0.0, rng.randf_range(-r, r))
	_wander_target = home_position + off


## Lift one item from a nearby player. Narrated in Zork's voice.
func _try_steal(now: float) -> void:
	if now < _steal_ready_at:
		return
	var no_flag := str(behaviour.get("no_steal_flag", ""))
	if no_flag != "" and GameManager.has_flag(no_flag):
		return
	var player := GameManager.player as Actor
	if player == null or player.is_dead or player.inventory == null:
		return
	if actor.global_position.distance_to(player.global_position) > float(behaviour.get("steal_range", 2.2)):
		return
	var tags: Array = behaviour.get("steal_tags", [])
	var victim_item: ItemInstance = null
	for inst in player.inventory.items:
		var ok := tags.is_empty()
		for t in inst.def.tags:
			if t in tags:
				ok = true
		if ok:
			victim_item = inst
			break
	_steal_ready_at = now + float(behaviour.get("steal_cooldown", 25.0))
	if victim_item == null:
		return
	player.inventory.remove_item(victim_item.def.id, 1)
	if actor.inventory:
		actor.inventory.add_item(victim_item.def.id, 1)
	stole.emit(victim_item.def.id)
	var who := actor.actor_def.display_name.to_lower() if actor.actor_def else "someone"
	EventBus.notification.emit("The %s brushes past you. A moment later you realise the %s is gone from your pack. 'Terribly sorry,' he murmurs. 'Occupational habit.'" % [who, victim_item.def.display_name.to_lower()], "warning")
	GameManager.set_flag("was_robbed", true)


signal stole(item_id: String)


func _move(delta: float) -> void:
	var speed := actor.stat("move_speed", 3.5)
	var desired := Vector3.ZERO
	match state:
		State.CHASE, State.ATTACK:
			if target and is_instance_valid(target):
				desired = _direction_to(target.global_position)
				var reach := float(behaviour.get("preferred_range", 1.8))
				if actor.global_position.distance_to(target.global_position) <= reach:
					desired = Vector3.ZERO
					set_state(State.ATTACK)
					_try_attack()
		State.FLEE:
			if target and is_instance_valid(target):
				desired = -_direction_to(target.global_position)
		State.RETURN:
			desired = _direction_to(home_position)
		State.PATROL:
			if actor.global_position.distance_to(_wander_target) > 0.8:
				desired = _direction_to(_wander_target)
		State.INVESTIGATE:
			var noise: Dictionary = actor.perception.last_noise if actor.perception else {}
			if noise.has("position") and actor.global_position.distance_to(noise["position"]) > 1.5:
				desired = _direction_to(noise["position"])
	actor.velocity.x = move_toward(actor.velocity.x, desired.x * speed, 10.0 * delta * speed)
	actor.velocity.z = move_toward(actor.velocity.z, desired.z * speed, 10.0 * delta * speed)
	if desired.length() > 0.1:
		var look := actor.global_position + desired
		actor.look_at(Vector3(look.x, actor.global_position.y, look.z), Vector3.UP)
	actor.move_and_slide()


func _direction_to(pos: Vector3) -> Vector3:
	var d := pos - actor.global_position
	d.y = 0.0
	return d.normalized()


## Pick the first castable ability (M3: utility scoring by ai_tags/weights).
func _try_attack() -> void:
	if actor.ability_caster == null or target == null:
		return
	for ab in actor.ability_caster.known_abilities():
		if ab.is_offensive() and actor.ability_caster.can_cast(ab.id)["ok"]:
			actor.ability_caster.cast(ab.id, target)
			return


func set_state(s: State) -> void:
	if s == state:
		return
	var prev := state
	state = s
	state_changed.emit(prev, s)


func _on_awareness_changed(_target: Actor, _level: int) -> void:
	_think_timer = think_interval  # react next frame


func to_save_data() -> Dictionary:
	return {"home": [home_position.x, home_position.y, home_position.z]}


func from_save_data(d: Dictionary) -> void:
	var h: Array = d.get("home", [])
	if h.size() == 3:
		home_position = Vector3(h[0], h[1], h[2])
