## One damage event. Built by an ability/weapon, resolved by DamageCalculator,
## delivered to a Damageable.
class_name DamageInfo
extends RefCounted

const TYPES := ["physical", "slash", "pierce", "blunt", "fire", "frost", "lightning",
	"poison", "arcane", "holy", "shadow", "true"]
const PHYSICAL_TYPES := ["physical", "slash", "pierce", "blunt"]

var amounts: Dictionary = {}          ## type -> float (pre-mitigation)
var source: Node3D = null             ## attacking actor (may be null: traps, environment)
var ability_id: String = ""
var item_id: String = ""
var is_crit: bool = false
var crit_multiplier: float = 1.5
var knockback: float = 0.0
var direction: Vector3 = Vector3.ZERO
var hit_position: Vector3 = Vector3.ZERO
var ignore_armor: bool = false
var can_be_dodged: bool = true
var tags: Array[String] = []          ## "melee", "ranged", "spell", "dot", "sneak_attack"

# Filled by DamageCalculator
var final_amounts: Dictionary = {}
var total: float = 0.0
var mitigated: float = 0.0
var dodged: bool = false
var blocked: bool = false


static func single(type: String, amount: float, p_source: Node3D = null) -> DamageInfo:
	var d := DamageInfo.new()
	d.amounts[type] = amount
	d.source = p_source
	return d


## Roll damage ranges from a definition dictionary {"fire": [2, 5], "physical": 4}.
static func from_ranges(ranges: Dictionary, rng: RandomNumberGenerator = null, p_source: Node3D = null) -> DamageInfo:
	var d := DamageInfo.new()
	d.source = p_source
	for t in ranges:
		var r = ranges[t]
		if r is Array and r.size() == 2:
			var lo := float(r[0])
			var hi := float(r[1])
			d.amounts[t] = rng.randf_range(lo, hi) if rng else (lo + hi) * 0.5
		else:
			d.amounts[t] = float(r)
	return d


func add(type: String, amount: float) -> void:
	amounts[type] = amounts.get(type, 0.0) + amount


func raw_total() -> float:
	var t := 0.0
	for k in amounts:
		t += amounts[k]
	return t


func primary_type() -> String:
	var best := ""
	var best_v := -INF
	for k in amounts:
		if amounts[k] > best_v:
			best_v = amounts[k]
			best = k
	return best


static func is_physical(type: String) -> bool:
	return type in PHYSICAL_TYPES
