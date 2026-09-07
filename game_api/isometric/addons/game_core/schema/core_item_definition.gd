## Unified static item data (items.json), merged from the FPS and isometric engines.
##
## The FPS engine used `category` + damage/effects/procs/identification; the
## isometric engine used `kind` + modifiers/use_effects/grants_intel. Both are
## supported here so one items.json works in either graphics engine; a field
## irrelevant to a given engine is simply ignored by it.
##
## JSON:
##   {"id": "iron_sword", "display_name": "Iron Sword", "category": "weapon",
##    "equip_slot": "weapon", "value": 40, "stats": {"attack": 6},
##    "damage": {"physical": [4, 7]}, "tags": ["melee"]}
##   {"id": "smugglers_map", "category": "tome", "grants_intel": ["crypt_location"],
##    "consumed_on_use": true, "requires": {"has": "can_read_charts"}}
class_name CoreItemDefinition
extends CoreDefinition

enum Category { WEAPON, ARMOR, ACCESSORY, CONSUMABLE, AMMO, KEY, TOME, MATERIAL, QUEST, CURRENCY, ARTIFACT, RESOURCE, MISC }

const CATEGORY_NAMES := {
	"weapon": Category.WEAPON, "armor": Category.ARMOR, "accessory": Category.ACCESSORY,
	"consumable": Category.CONSUMABLE, "ammo": Category.AMMO, "key": Category.KEY,
	"tome": Category.TOME, "material": Category.MATERIAL, "quest": Category.QUEST,
	"currency": Category.CURRENCY, "artifact": Category.ARTIFACT,
	"resource": Category.RESOURCE, "misc": Category.MISC,
	# isometric "kind" aliases
	"equipment": Category.WEAPON, "intel": Category.TOME,
}
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "unique"]
const STACKABLE_BY_DEFAULT := [Category.CONSUMABLE, Category.AMMO, Category.MATERIAL,
	Category.CURRENCY, Category.RESOURCE]

@export var category: Category = Category.MISC
@export var rarity: String = "common"
@export var weight: float = 0.0
@export var value: int = 0
@export var stackable: bool = false
@export var max_stack: int = 1
@export var unique: bool = false

# --- Equipment -----------------------------------------------------------------
@export var equip_slot: String = ""            ## "" = not equippable
@export var two_handed: bool = false
@export var stats: Dictionary = {}             ## flat modifiers while equipped
@export var stats_percent: Dictionary = {}     ## {"move_speed": 0.1} = +10%
@export var damage: Dictionary = {}            ## {"physical": [4, 7], "fire": [2, 3]}
@export var resistances: Dictionary = {}       ## {"fire": 0.25}
@export var durability: float = 0.0            ## 0 = indestructible

# --- Behaviour -----------------------------------------------------------------
@export var effects: Array[String] = []        ## effect ids applied while equipped
@export var abilities: Array[String] = []      ## ability ids granted while equipped
@export var procs: Array[Dictionary] = []      ## {"trigger": "on_hit", "chance": 0.2}
@export var use_effects: Array[Dictionary] = []## interaction specs run on use
@export var use_ability: String = ""
@export var teaches_ability: String = ""
@export var consumed_on_use: bool = true
@export var grants_intel: PackedStringArray = []

# --- Gating / identification ---------------------------------------------------
@export var requires: Dictionary = {}          ## CoreIntelQuery to equip/use
@export var requires_stats: Dictionary = {}    ## {"strength": 12}
@export var identified_by_default: bool = true
@export var identify_intel: String = ""
@export var lore_intel: String = ""

# --- Presentation (resolved per graphics engine via CoreAssetRegistry) ----------
@export var icon_key: String = ""
@export var visual_key: String = ""            ## iso sprite / 3D world prop
@export var view_model_key: String = ""        ## FPS first-person held model
@export var affix_pool: String = ""


func _apply(d: Dictionary) -> void:
	var raw_cat := str(d.get("category", d.get("kind", "misc"))).to_lower()
	category = CATEGORY_NAMES.get(raw_cat, Category.MISC)
	rarity = str(d.get("rarity", "common"))
	weight = float(d.get("weight", 0.0))
	value = int(d.get("value", 0))
	stackable = bool(d.get("stackable", category in STACKABLE_BY_DEFAULT))
	max_stack = int(d.get("max_stack", 99 if stackable else 1))
	unique = bool(d.get("unique", false))

	equip_slot = str(d.get("equip_slot", d.get("slot", "")))
	two_handed = bool(d.get("two_handed", false))
	stats = d.get("stats", d.get("modifiers", {}))
	stats_percent = d.get("stats_percent", {})
	damage = d.get("damage", {})
	resistances = d.get("resistances", {})
	durability = float(d.get("durability", 0.0))

	effects = CoreDataLoader.str_array(d.get("effects", []))
	abilities = CoreDataLoader.str_array(d.get("abilities", []))
	procs = CoreDataLoader.dict_array(d.get("procs", []))
	use_effects = CoreDataLoader.dict_array(d.get("use_effects", []))
	use_ability = str(d.get("use_ability", ""))
	teaches_ability = str(d.get("teaches_ability", ""))
	grants_intel = CoreDataLoader.packed_str_array(d.get("grants_intel", []))
	consumed_on_use = bool(d.get("consumed_on_use", d.get("consume_on_use",
		category in [Category.CONSUMABLE, Category.TOME])))

	requires = d.get("requires", d.get("use_requires", {}))
	requires_stats = d.get("requires_stats", {})
	identified_by_default = bool(d.get("identified", true))
	identify_intel = str(d.get("identify_intel", ""))
	lore_intel = str(d.get("lore_intel", ""))

	icon_key = str(d.get("icon", "icon.item.%s" % id))
	visual_key = str(d.get("visual", "item.%s" % category_name()))
	view_model_key = str(d.get("view_model", ""))
	affix_pool = str(d.get("affix_pool", ""))


func category_name() -> String:
	return Category.keys()[category].to_lower()


func is_equippable() -> bool:
	return equip_slot != ""


func is_usable() -> bool:
	return use_ability != "" or teaches_ability != "" \
		or not use_effects.is_empty() or not grants_intel.is_empty()


func is_weapon() -> bool:
	return category == Category.WEAPON


## Average damage across all damage types (for UI / AI weighting).
func average_damage() -> float:
	var total := 0.0
	for t in damage:
		var r = damage[t]
		if r is Array and r.size() == 2:
			total += (float(r[0]) + float(r[1])) * 0.5
		else:
			total += float(r)
	return total
