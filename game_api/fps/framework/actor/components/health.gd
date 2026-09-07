## Hit points. Max is driven by the "max_health" stat if present (so gear and
## buffs can raise it), otherwise by the definition's resources.health.
class_name Health
extends ActorComponent

signal changed(current: float, maximum: float)
signal damaged(amount: float, info: DamageInfo)
signal healed(amount: float, source: Node3D)
signal died(killer: Node3D)

var current: float = 100.0
var maximum: float = 100.0
var regen_per_game_hour: float = 0.0
var invulnerable: bool = false

var _regen_timer: int = -1


func _actor_ready() -> void:
	if actor.stats:
		actor.stats.stat_changed.connect(_on_stat_changed)


func _definition_applied(def: ActorDefinition) -> void:
	maximum = float(def.resources.get("health", def.stats.get("max_health", maximum)))
	if actor.stats and not actor.stats.base.has("max_health"):
		actor.stats.set_base("max_health", maximum)
	current = maximum
	regen_per_game_hour = float(def.resources.get("health_regen", 0.0))
	_setup_regen()
	changed.emit(current, maximum)


func _on_stat_changed(stat: String, value: float) -> void:
	if stat == "max_health":
		var ratio := current / maximum if maximum > 0.0 else 1.0
		maximum = maxf(1.0, value)
		current = clampf(maximum * ratio, 0.0, maximum)
		changed.emit(current, maximum)


func _setup_regen() -> void:
	if _regen_timer >= 0:
		GameClock.cancel(_regen_timer)
		_regen_timer = -1
	if regen_per_game_hour > 0.0:
		_regen_timer = GameClock.schedule_in(60.0, _regen_tick, true)  # every game minute


func _regen_tick() -> void:
	if not actor.is_dead and current < maximum:
		heal(regen_per_game_hour / 60.0)


## Apply already-mitigated damage. Returns the amount actually removed.
func apply_damage(info: DamageInfo) -> float:
	if actor.is_dead or invulnerable or info.total <= 0.0:
		return 0.0
	var before := current
	current = maxf(0.0, current - info.total)
	var dealt := before - current
	damaged.emit(dealt, info)
	changed.emit(current, maximum)
	EventBus.actor_damaged.emit(actor, dealt, info.primary_type(), info.source)
	if current <= 0.0:
		died.emit(info.source)
		actor.die(info.source)
	return dealt


func heal(amount: float, source: Node3D = null) -> float:
	if actor.is_dead or amount <= 0.0:
		return 0.0
	var before := current
	current = minf(maximum, current + amount)
	var healed_by := current - before
	if healed_by > 0.0:
		healed.emit(healed_by, source)
		changed.emit(current, maximum)
		EventBus.actor_healed.emit(actor, healed_by)
	return healed_by


func set_full() -> void:
	current = maximum
	changed.emit(current, maximum)


func ratio() -> float:
	return current / maximum if maximum > 0.0 else 0.0


func is_below(fraction: float) -> bool:
	return ratio() < fraction


func to_save_data() -> Dictionary:
	return {"current": current, "maximum": maximum}


func from_save_data(d: Dictionary) -> void:
	maximum = float(d.get("maximum", maximum))
	current = float(d.get("current", current))
	changed.emit(current, maximum)
