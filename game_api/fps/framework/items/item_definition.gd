## Static item data (items.json).
##
## Items are behavioural, not just stat sticks: they can carry passive
## [member effects], grant [member abilities] while equipped, and fire
## [member procs] on triggers (on_hit, on_kill, on_cast, on_damaged...).
## Magic items may start unidentified; their true properties are revealed via
## intel (sage, scroll, use) — see [member identified_by_default] / [member identify_intel].
class_name ItemDefinition
extends Definition

enum Category { WEAPON, ARMOR, ACCESSORY, CONSUMABLE, AMMO, KEY, TOME, MATERIAL, QUEST, CURRENCY, MISC }

const CATEGORY_NAMES := {
	"weapon": Category.WEAPON, "armor": Category.ARMOR, "accessory": Category.ACCESSORY,
	"consumable": Category.CONSUMABLE, "ammo": Category.AMMO, "key": Category.KEY,
	"tome": Category.TOME, "material": Category.MATERIAL, "quest": Category.QUEST,
	"currency": Category.CURRENCY, "misc": Category.MISC,
}
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "unique"]

@export var category: Category = Category.MISC
@export var rarity: String = "common"
@export var weight: float = 0.0
@export var stackable: bool = false
@export var max_stack: int = 1
@export var equip_slot: String = ""           ## "" = not equippable; must be in game.json equip_slots
@export var two_handed: bool = false
@export var value: int = 0
@export var stats: Dictionary = {}            ## {"attack": 6, "armor": 2, "crit_chance": 0.05} flat mods
@export var stats_percent: Dictionary = {}    ## {"move_speed": 0.1} = +10%
@export var damage: Dictionary = {}           ## weapons: {"physical": [4, 7], "fire": [2, 3]}
@export var resistances: Dictionary = {}      ## armour: {"fire": 0.25}
@export var effects: Array[String] = []       ## EffectDefinition ids applied while equipped
@export var abilities: Array[String] = []     ## AbilityDefinition ids granted while equipped
@export var procs: Array[Dictionary] = []     ## {"trigger": "on_hit", "chance": 0.2, "ability": "...", "effect": "..."}
@export var use_ability: String = ""          ## consumables/tomes: ability cast on use
@export var teaches_ability: String = ""      ## tomes: permanently learn this ability
@export var consumed_on_use: bool = true
@export var requires: Dictionary = {}         ## IntelQuery to equip/use (learn how to wield it)
@export var requires_stats: Dictionary = {}   ## {"strength": 12}
@export var identified_by_default: bool = true
@export var identify_intel: String = ""       ## Intel token that identifies this item when known
@export var lore_intel: String = ""           ## Intel token granted when the item is inspected
@export var durability: float = 0.0           ## 0 = indestructible
@export var visual_key: String = ""           ## world/prop scene (AssetRegistry)
@export var view_model_key: String = ""       ## first-person held model
@export var icon_key: String = ""
@export var affix_pool: String = ""           ## M4: affix table for generated variants


func _apply(d: Dictionary) -> void:
	category = CATEGORY_NAMES.get(str(d.get("category", "misc")).to_lower(), Category.MISC)
	rarity = str(d.get("rarity", "common"))
	weight = float(d.get("weight", 0.0))
	stackable = bool(d.get("stackable", category in [Category.CONSUMABLE, Category.AMMO, Category.MATERIAL, Category.CURRENCY]))
	max_stack = int(d.get("max_stack", 99 if stackable else 1))
	equip_slot = str(d.get("equip_slot", ""))
	two_handed = bool(d.get("two_handed", false))
	value = int(d.get("value", 0))
	stats = d.get("stats", {})
	stats_percent = d.get("stats_percent", {})
	damage = d.get("damage", {})
	resistances = d.get("resistances", {})
	effects = Definition._str_array(d.get("effects", []))
	abilities = Definition._str_array(d.get("abilities", []))
	procs = Definition._dict_array(d.get("procs", []))
	use_ability = str(d.get("use_ability", ""))
	teaches_ability = str(d.get("teaches_ability", ""))
	consumed_on_use = bool(d.get("consumed_on_use", true))
	requires = d.get("requires", {})
	requires_stats = d.get("requires_stats", {})
	identified_by_default = bool(d.get("identified", true))
	identify_intel = str(d.get("identify_intel", ""))
	lore_intel = str(d.get("lore_intel", ""))
	durability = float(d.get("durability", 0.0))
	visual_key = str(d.get("visual", "item.%s" % category_name()))
	view_model_key = str(d.get("view_model", ""))
	icon_key = str(d.get("icon", ""))
	affix_pool = str(d.get("affix_pool", ""))


func category_name() -> String:
	return Category.keys()[category].to_lower()


func is_equippable() -> bool:
	return equip_slot != ""


func is_usable() -> bool:
	return use_ability != "" or teaches_ability != ""


func is_weapon() -> bool:
	return category == Category.WEAPON


## Average damage across all types (for UI / AI weighting).
func average_damage() -> float:
	var total := 0.0
	for t in damage:
		var r = damage[t]
		if r is Array and r.size() == 2:
			total += (float(r[0]) + float(r[1])) * 0.5
		else:
			total += float(r)
	return total
