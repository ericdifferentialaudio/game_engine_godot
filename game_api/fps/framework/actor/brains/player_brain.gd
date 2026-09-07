## First-person player control: mouse-look, movement, sprint/jump, head-bob,
## ability hotkeys. Expects the actor scene to contain Head/Camera3D and an
## optional ViewModel node under the camera.
##
## Movement speed = actor stat "move_speed" (base from ActorDefinition/game.json),
## so gear and status effects (slow, haste) affect the player automatically.
class_name PlayerBrain
extends Brain

@export var sprint_multiplier: float = 1.65
@export var jump_velocity: float = 4.5
@export var acceleration: float = 12.0
@export var mouse_sensitivity: float = 0.0025
@export var pitch_limit_deg: float = 88.0
@export var head_bob_enabled: bool = true
@export var sprint_stamina_per_second: float = 8.0
@export var footstep_noise: float = 0.6
@export var sprint_noise: float = 1.2

var head: Node3D
var camera: Camera3D
var view_model: Node3D

var _bob_time := 0.0
var _camera_base_y := 0.0
var _step_timer := 0.0


func _brain_ready() -> void:
	actor.add_to_group("player")
	head = actor.get_node_or_null("Head")
	camera = head.get_node_or_null("Camera3D") if head else null
	view_model = camera.get_node_or_null("ViewModel") if camera else null
	if camera:
		_camera_base_y = camera.position.y
	if actor.stats and not actor.stats.base.has("move_speed"):
		actor.stats.set_base("move_speed", 4.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.game_state_changed.connect(_on_state_changed)


func _on_state_changed(_prev: int, cur: int) -> void:
	var playing := cur == GameManager.State.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	set_physics_process(playing)
	set_process_unhandled_input(playing)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and head:
		actor.rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	elif event.is_action_pressed("attack"):
		_use_slot(0)
	elif event.is_action_pressed("cast_1"):
		_use_slot(1)
	elif event.is_action_pressed("cast_2"):
		_use_slot(2)
	elif event.is_action_pressed("cast_3"):
		_use_slot(3)


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if is_disabled():
		actor.velocity.x = move_toward(actor.velocity.x, 0.0, acceleration * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0.0, acceleration * delta)
		actor.move_and_slide()
		return

	if actor.is_on_floor() and Input.is_action_just_pressed("jump"):
		actor.velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (actor.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := actor.stat("move_speed", 4.5)
	var sprinting := Input.is_action_pressed("sprint") and direction.length() > 0.1 and _can_sprint(delta)
	if sprinting:
		speed *= sprint_multiplier
	var target := direction * speed
	actor.velocity.x = move_toward(actor.velocity.x, target.x, acceleration * delta * speed)
	actor.velocity.z = move_toward(actor.velocity.z, target.z, acceleration * delta * speed)
	actor.move_and_slide()

	var moving := direction.length() > 0.1 and actor.is_on_floor()
	_apply_head_bob(delta, moving, sprinting)
	_emit_footsteps(delta, moving, sprinting)


func _can_sprint(delta: float) -> bool:
	if actor.resources == null or not actor.resources.has_pool("stamina"):
		return true
	if actor.resources.get_current("stamina") <= 0.0:
		return false
	actor.resources.modify("stamina", -sprint_stamina_per_second * delta)
	return true


func _apply_head_bob(delta: float, moving: bool, sprinting: bool) -> void:
	if not head_bob_enabled or camera == null:
		return
	if moving:
		_bob_time += delta * (14.0 if sprinting else 10.0)
		camera.position.y = _camera_base_y + sin(_bob_time) * 0.04
	else:
		_bob_time = 0.0
		camera.position.y = lerpf(camera.position.y, _camera_base_y, delta * 8.0)


func _emit_footsteps(delta: float, moving: bool, sprinting: bool) -> void:
	if not moving:
		_step_timer = 0.0
		return
	_step_timer += delta
	var interval := 0.35 if sprinting else 0.55
	if _step_timer >= interval:
		_step_timer = 0.0
		var loud := sprint_noise if sprinting else footstep_noise
		if actor.status_effects and actor.status_effects.has_flag("silent_steps"):
			loud *= 0.25
		EventBus.noise_emitted.emit(actor.global_position, loud, actor)


## Hotbar slot -> ability. Slot 0 = main-hand weapon's first ability (basic attack).
func _use_slot(slot: int) -> void:
	if actor.ability_caster == null:
		return
	var ability_id := ""
	if slot == 0:
		var weapon := actor.equipment.main_weapon() if actor.equipment else null
		if weapon and not weapon.total_abilities().is_empty():
			ability_id = weapon.total_abilities()[0]
		else:
			ability_id = GameManager.game_config.get("unarmed_ability", "")
	else:
		var hotbar: Array = GameManager.game_config.get("default_hotbar", [])
		if slot - 1 < hotbar.size():
			ability_id = str(hotbar[slot - 1])
	if ability_id != "":
		actor.ability_caster.cast(ability_id, _aim_target())


func _aim_target() -> Vector3:
	if camera == null:
		return actor.global_position - actor.global_transform.basis.z * 10.0
	return camera.global_position - camera.global_transform.basis.z * 30.0


func reset_motion() -> void:
	actor.velocity = Vector3.ZERO
