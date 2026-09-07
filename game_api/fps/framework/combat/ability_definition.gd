## Ability data (abilities.json). Melee swings, spells, item uses and monster
## attacks all share this format; the execution pipeline (M2) interprets
## [member targeting] and applies [member effects] in order.
class_name AbilityDefinition
extends Definition

enum Targeting { SELF, MELEE_ARC, PROJECTILE, BEAM, AOE_SELF, AOE_TARGET, GROUND, SUMMON, TOUCH }
const TARGETING_NAMES := {"self": Targeting.SELF, "melee_arc": Targeting.MELEE_ARC,
	"projectile": Targeting.PROJECTILE, "beam": Targeting.BEAM, "aoe_self": Targeting.AOE_SELF,
	"aoe_target": Targeting.AOE_TARGET, "ground": Targeting.GROUND, "summon": Targeting.SUMMON,
	"touch": Targeting.TOUCH}

@export var school: String = "physical"         ## physical | evocation | illusion | necromancy | divine ...
@export var targeting: Targeting = Targeting.MELEE_ARC
@export var range: float = 2.0
@export var radius: float = 0.0                 ## AoE / arc width
@export var arc_degrees: float = 90.0
@export var costs: Dictionary = {}              ## {"mana": 12, "stamina": 5}
@export var cast_time: float = 0.0              ## real seconds (gameplay feel, not game clock)
@export var cooldown: float = 0.0               ## real seconds
@export var channel: bool = false
@export var interruptible: bool = true
@export var damage: Dictionary = {}             ## {"fire": [10, 14]}; weapons add their own
@export var scale_with_weapon: bool = false     ## MELEE_ARC abilities typically true
@export var scaling: Dictionary = {}            ## {"intellect": 0.5} adds stat * factor to damage
@export var heal: float = 0.0
@export var apply_effects: Array[Dictionary] = []  ## {"effect": "burning", "chance": 1.0, "target": "enemy|self"}
@export var effects: Array[Dictionary] = []     ## ordered execution steps: {"type": "damage|heal|status|knockback|teleport|spawn|reveal_intel|noise", ...}
@export var projectile: Dictionary = {}         ## {"speed": 30, "gravity": 0, "pierce": false, "visual": "fx.firebolt"}
@export var summon_actor: String = ""
@export var noise: float = 0.0                  ## loudness emitted (stealth)
@export var requires: Dictionary = {}           ## IntelQuery to learn/cast
@export var requires_stats: Dictionary = {}
@export var animation: String = ""
@export var vfx_key: String = ""
@export var sfx_key: String = ""
@export var icon_key: String = ""
@export var ai_weight: float = 1.0              ## AI utility base weight
@export var ai_tags: Array[String] = []         ## "heal", "ranged", "escape", "buff", "opener"


func _apply(d: Dictionary) -> void:
	school = str(d.get("school", "physical"))
	targeting = TARGETING_NAMES.get(str(d.get("targeting", "melee_arc")), Targeting.MELEE_ARC)
	range = float(d.get("range", 2.0))
	radius = float(d.get("radius", 0.0))
	arc_degrees = float(d.get("arc_degrees", 90.0))
	costs = d.get("costs", {})
	cast_time = float(d.get("cast_time", 0.0))
	cooldown = float(d.get("cooldown", 0.0))
	channel = bool(d.get("channel", false))
	interruptible = bool(d.get("interruptible", true))
	damage = d.get("damage", {})
	scale_with_weapon = bool(d.get("scale_with_weapon", targeting == Targeting.MELEE_ARC))
	scaling = d.get("scaling", {})
	heal = float(d.get("heal", 0.0))
	apply_effects = Definition._dict_array(d.get("apply_effects", []))
	effects = Definition._dict_array(d.get("effects", []))
	projectile = d.get("projectile", {})
	summon_actor = str(d.get("summon_actor", ""))
	noise = float(d.get("noise", 0.0))
	requires = d.get("requires", {})
	requires_stats = d.get("requires_stats", {})
	animation = str(d.get("animation", ""))
	vfx_key = str(d.get("vfx", ""))
	sfx_key = str(d.get("sfx", ""))
	icon_key = str(d.get("icon", ""))
	ai_weight = float(d.get("ai_weight", 1.0))
	ai_tags = Definition._str_array(d.get("ai_tags", []))


func targeting_name() -> String:
	return Targeting.keys()[targeting].to_lower()


func is_offensive() -> bool:
	return not damage.is_empty() or apply_effects.any(func(e): return e.get("target", "enemy") == "enemy")
