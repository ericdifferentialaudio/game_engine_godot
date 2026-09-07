## Senses: sight (range, FOV, line-of-sight) and hearing (noise events).
## Maintains an awareness level per observed actor. Used by AIBrain (M3) and by
## stealth mechanics (is the player seen?). Player perception stat feeds
## discovery radius and intel reliability in intel-focused games.
##
## Configured from ActorDefinition.senses:
##   {"sight_range": 20, "fov": 110, "hearing": 15, "memory": 10}
class_name Perception
extends ActorComponent

enum Awareness { UNAWARE, SUSPICIOUS, ALERT, COMBAT }

signal awareness_changed(target: Actor, level: Awareness)
signal noise_heard(position: Vector3, loudness: float, source: Node3D)

@export var sight_range: float = 20.0
@export var fov_degrees: float = 110.0
@export var hearing_range: float = 15.0
@export var memory_seconds: float = 10.0     ## real seconds before losing an unseen target
@export var eye_height: float = 1.6
@export var check_interval: float = 0.25     ## real seconds between sight sweeps
@export var enabled: bool = true

var tracked: Dictionary = {}                 ## Actor -> {"level", "last_seen_pos", "last_seen_time", "visible"}
var last_noise: Dictionary = {}              ## {"position", "loudness", "time"}

var _timer := 0.0


func _actor_ready() -> void:
	EventBus.noise_emitted.connect(_on_noise)


func _definition_applied(def: ActorDefinition) -> void:
	sight_range = float(def.senses.get("sight_range", sight_range))
	fov_degrees = float(def.senses.get("fov", fov_degrees))
	hearing_range = float(def.senses.get("hearing", hearing_range))
	memory_seconds = float(def.senses.get("memory", memory_seconds))
	enabled = def.brain == "ai"   # players don't need AI perception sweeps


func _process(delta: float) -> void:
	if not enabled or actor.is_dead:
		return
	_timer += delta
	if _timer < check_interval:
		return
	_timer = 0.0
	_sweep()


## Can this actor currently see [param target]? (distance, FOV, LOS, invisibility)
func can_see(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target is Actor and target.status_effects and target.status_effects.has_flag("invisible"):
		return false
	var eye := actor.global_position + Vector3.UP * eye_height
	var to := target.global_position + Vector3.UP * (eye_height * 0.6) - eye
	var dist := to.length()
	if dist > sight_range:
		return false
	var forward := -actor.global_transform.basis.z
	if dist > 0.5 and rad_to_deg(forward.angle_to(to.normalized())) > fov_degrees * 0.5:
		return false
	var space := actor.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, eye + to, 1)  # World layer only blocks sight
	q.exclude = [actor.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _sweep() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for other in get_tree().get_nodes_in_group("actors"):
		if other == actor or not (other is Actor) or other.is_dead:
			continue
		if not actor.is_hostile_to(other):
			continue
		var seen := can_see(other)
		var t: Dictionary = tracked.get(other, {"level": Awareness.UNAWARE, "last_seen_time": -INF})
		if seen:
			t["visible"] = true
			t["last_seen_pos"] = other.global_position
			t["last_seen_time"] = now
			_set_level(other, t, Awareness.COMBAT if t["level"] >= Awareness.ALERT else Awareness.ALERT)
		else:
			t["visible"] = false
			if now - t["last_seen_time"] > memory_seconds and t["level"] > Awareness.UNAWARE:
				_set_level(other, t, Awareness.UNAWARE)
		tracked[other] = t
	# Drop dead / freed targets
	for k in tracked.keys():
		if not is_instance_valid(k) or k.is_dead:
			tracked.erase(k)


func _set_level(target: Actor, t: Dictionary, level: Awareness) -> void:
	if t.get("level", Awareness.UNAWARE) == level:
		return
	t["level"] = level
	awareness_changed.emit(target, level)
	EventBus.awareness_changed.emit(actor, target, level)


func _on_noise(position: Vector3, loudness: float, source: Node3D) -> void:
	if not enabled or actor.is_dead or source == actor:
		return
	var dist := actor.global_position.distance_to(position)
	if dist > hearing_range * loudness:
		return
	last_noise = {"position": position, "loudness": loudness, "time": Time.get_ticks_msec() / 1000.0}
	noise_heard.emit(position, loudness, source)
	if source is Actor and actor.is_hostile_to(source):
		var t: Dictionary = tracked.get(source, {"level": Awareness.UNAWARE, "last_seen_time": -INF})
		t["last_seen_pos"] = position
		if t["level"] < Awareness.SUSPICIOUS:
			_set_level(source, t, Awareness.SUSPICIOUS)
		tracked[source] = t


func awareness_of(target: Actor) -> Awareness:
	return tracked.get(target, {}).get("level", Awareness.UNAWARE)


func highest_threat() -> Actor:
	var best: Actor = null
	var best_level := -1
	for a in tracked:
		if is_instance_valid(a) and tracked[a]["level"] > best_level:
			best_level = tracked[a]["level"]
			best = a
	return best


func visible_hostiles() -> Array[Actor]:
	var out: Array[Actor] = []
	for a in tracked:
		if is_instance_valid(a) and tracked[a].get("visible", false):
			out.append(a)
	return out
