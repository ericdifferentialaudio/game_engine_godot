## Pure damage math. The single place where mitigation rules live so they can
## be unit-tested and tuned per game via game.json "combat" block:
##
##   "combat": {"armor_constant": 50, "max_resistance": 0.75, "min_resistance": -1.0,
##              "crit_base": 0.05, "dodge_base": 0.0}
##
## Physical mitigation:  armor / (armor + armor_constant)   (diminishing returns)
## Elemental mitigation: resistance (fraction, may be negative = vulnerable)
## "true" damage ignores everything.
class_name DamageCalculator
extends RefCounted

static var armor_constant: float = 50.0
static var max_resistance: float = 0.75
static var min_resistance: float = -1.0


static func configure(cfg: Dictionary) -> void:
	armor_constant = float(cfg.get("armor_constant", 50.0))
	max_resistance = float(cfg.get("max_resistance", 0.75))
	min_resistance = float(cfg.get("min_resistance", -1.0))


static func armor_mitigation(armor: float) -> float:
	if armor <= 0.0:
		return 0.0
	return armor / (armor + armor_constant)


static func clamp_resistance(r: float) -> float:
	return clampf(r, min_resistance, max_resistance)


## Resolve [param info] against a defender described by
## [param armor], [param resistances] (type -> fraction) and [param immunities].
## Fills info.final_amounts / total / mitigated and returns the total.
static func resolve(info: DamageInfo, armor: float, resistances: Dictionary, immunities: Array = [],
		dodge_chance: float = 0.0, rng: RandomNumberGenerator = null) -> float:
	info.final_amounts.clear()
	info.total = 0.0
	info.mitigated = 0.0
	info.dodged = false

	if info.can_be_dodged and dodge_chance > 0.0:
		var roll := rng.randf() if rng else 0.5
		if roll < dodge_chance:
			info.dodged = true
			info.mitigated = info.raw_total()
			return 0.0

	var crit_mult := info.crit_multiplier if info.is_crit else 1.0
	for type in info.amounts:
		var raw: float = info.amounts[type] * crit_mult
		var final := raw
		if type in immunities:
			final = 0.0
		elif type == "true":
			final = raw
		elif DamageInfo.is_physical(type):
			if not info.ignore_armor:
				final = raw * (1.0 - armor_mitigation(armor))
			var r := clamp_resistance(float(resistances.get(type, resistances.get("physical", 0.0))))
			final *= (1.0 - r)
		else:
			var r := clamp_resistance(float(resistances.get(type, 0.0)))
			final = raw * (1.0 - r)
		final = maxf(0.0, final)
		info.final_amounts[type] = final
		info.total += final
		info.mitigated += raw - final
	return info.total


## Roll a crit using attacker crit chance (0..1).
static func roll_crit(crit_chance: float, rng: RandomNumberGenerator = null) -> bool:
	if crit_chance <= 0.0:
		return false
	var roll := rng.randf() if rng else 0.5
	return roll < crit_chance


## Add stat scaling ({"strength": 0.5}) using the attacker's final stats.
static func apply_scaling(info: DamageInfo, scaling: Dictionary, stats: Dictionary) -> void:
	if scaling.is_empty() or info.amounts.is_empty():
		return
	var bonus := 0.0
	for stat in scaling:
		bonus += float(stats.get(stat, 0.0)) * float(scaling[stat])
	if bonus == 0.0:
		return
	var primary := info.primary_type()
	info.amounts[primary] = info.amounts.get(primary, 0.0) + bonus
