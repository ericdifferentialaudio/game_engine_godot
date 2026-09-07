## Status effect / passive modifier data (effects.json).
##
## An effect is a bundle of stat modifiers plus optional periodic behaviour,
## applied to an actor for a duration (game seconds) or permanently (0) while
## its source (equipment, aura) persists.
class_name EffectDefinition
extends Definition

enum Stacking { REFRESH, STACK, INDEPENDENT, IGNORE }
const STACKING_NAMES := {"refresh": Stacking.REFRESH, "stack": Stacking.STACK,
	"independent": Stacking.INDEPENDENT, "ignore": Stacking.IGNORE}

@export var duration: float = 0.0                 ## game seconds; 0 = until removed
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1
@export var stat_mods: Dictionary = {}            ## {"armor": -5}
@export var stat_mods_percent: Dictionary = {}    ## {"move_speed": -0.3}
@export var resistances: Dictionary = {}          ## {"fire": -0.25}
@export var tick_interval: float = 0.0            ## game seconds between ticks; 0 = no ticks
@export var tick_damage: Dictionary = {}          ## {"fire": 3}
@export var tick_heal: float = 0.0
@export var tick_resources: Dictionary = {}       ## {"mana": 2}
@export var flags: Array[String] = []             ## "stunned", "invisible", "silenced", "rooted", "revealed"
@export var immunities: Array[String] = []        ## effect ids or damage types this grants immunity to
@export var is_debuff: bool = false
@export var dispellable: bool = true
@export var vfx_key: String = ""
@export var icon_key: String = ""


func _apply(d: Dictionary) -> void:
	duration = float(d.get("duration", 0.0))
	stacking = STACKING_NAMES.get(str(d.get("stacking", "refresh")), Stacking.REFRESH)
	max_stacks = int(d.get("max_stacks", 1))
	stat_mods = d.get("stat_mods", {})
	stat_mods_percent = d.get("stat_mods_percent", {})
	resistances = d.get("resistances", {})
	tick_interval = float(d.get("tick_interval", 0.0))
	tick_damage = d.get("tick_damage", {})
	tick_heal = float(d.get("tick_heal", 0.0))
	tick_resources = d.get("tick_resources", {})
	flags = Definition._str_array(d.get("flags", []))
	immunities = Definition._str_array(d.get("immunities", []))
	is_debuff = bool(d.get("debuff", false))
	dispellable = bool(d.get("dispellable", true))
	vfx_key = str(d.get("vfx", ""))
	icon_key = str(d.get("icon", ""))
