## Spendable pools other than health: mana, stamina, focus, rage... Defined per
## game in game.json "resources" (defaults) and per actor in resources{}.
## A "max_<name>" stat, if present, drives the maximum so gear can raise it.
class_name Resources
extends ActorComponent

signal changed(resource: String, current: float, maximum: float)

var pools: Dictionary = {}      ## name -> {"current", "max", "regen"}  (regen = per real second)


func _actor_ready() -> void:
	for name in GameManager.game_config.get("resources", {}):
		var cfg = GameManager.game_config["resources"][name]
		var mx := float(cfg if not (cfg is Dictionary) else cfg.get("max", 0.0))
		var regen := 0.0 if not (cfg is Dictionary) else float(cfg.get("regen", 0.0))
		define(name, mx, regen)
	if actor.stats:
		actor.stats.stat_changed.connect(_on_stat_changed)


func _definition_applied(def: ActorDefinition) -> void:
	for name in def.resources:
		if name == "health" or name == "health_regen":
			continue
		if name.ends_with("_regen"):
			var base_name: String = name.trim_suffix("_regen")
			if pools.has(base_name):
				pools[base_name]["regen"] = float(def.resources[name])
			continue
		define(name, float(def.resources[name]), pools.get(name, {}).get("regen", 0.0))


func _process(delta: float) -> void:
	for name in pools:
		var p: Dictionary = pools[name]
		if p["regen"] != 0.0 and p["current"] < p["max"]:
			p["current"] = clampf(p["current"] + p["regen"] * delta, 0.0, p["max"])
			changed.emit(name, p["current"], p["max"])


func define(name: String, maximum: float, regen: float = 0.0) -> void:
	pools[name] = {"current": maximum, "max": maximum, "regen": regen}
	changed.emit(name, maximum, maximum)


func has_pool(name: String) -> bool:
	return pools.has(name)


func get_current(name: String) -> float:
	return pools.get(name, {}).get("current", 0.0)


func get_max(name: String) -> float:
	return pools.get(name, {}).get("max", 0.0)


func can_afford(costs: Dictionary) -> bool:
	for name in costs:
		if get_current(name) < float(costs[name]):
			return false
	return true


func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for name in costs:
		modify(name, -float(costs[name]))
	return true


func modify(name: String, delta: float) -> void:
	if not pools.has(name):
		return
	var p: Dictionary = pools[name]
	p["current"] = clampf(p["current"] + delta, 0.0, p["max"])
	changed.emit(name, p["current"], p["max"])


func restore_all() -> void:
	for name in pools:
		pools[name]["current"] = pools[name]["max"]
		changed.emit(name, pools[name]["current"], pools[name]["max"])


func _on_stat_changed(stat: String, value: float) -> void:
	if stat.begins_with("max_"):
		var name := stat.trim_prefix("max_")
		if pools.has(name):
			var p: Dictionary = pools[name]
			var ratio: float = p["current"] / p["max"] if p["max"] > 0.0 else 1.0
			p["max"] = maxf(0.0, value)
			p["current"] = p["max"] * ratio
			changed.emit(name, p["current"], p["max"])


func to_save_data() -> Dictionary:
	return {"pools": pools.duplicate(true)}


func from_save_data(d: Dictionary) -> void:
	pools = d.get("pools", pools)
	for name in pools:
		changed.emit(name, pools[name]["current"], pools[name]["max"])
