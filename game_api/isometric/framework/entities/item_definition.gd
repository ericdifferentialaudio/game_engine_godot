## Static description of an item (items.json).
##
## {"items": [
##   {"id": "iron_sword", "display_name": "Iron Sword", "kind": "equipment", "slot": "weapon",
##    "icon": "icon.item.iron_sword", "rarity": "common", "value": 40, "stackable": false,
##    "modifiers": {"strength": 2}, "tags": ["weapon", "melee"]},
##   {"id": "healing_herb", "kind": "consumable", "stackable": true, "max_stack": 10,
##    "use_effects": [{"kind": "reward", "stat_delta": {"health": 5}}], "value": 8},
##   {"id": "smugglers_map", "kind": "intel", "grants_intel": ["crypt_location"],
##    "consume_on_use": true, "value": 60,
##    "use_requires": {"has": "can_read_charts"}},
##   {"id": "ancient_relic", "kind": "artifact", "unique": true, "value": 500,
##    "modifiers": {"sight": 1}, "tags": ["quest"]}
## ]}
##
## kinds: equipment | consumable | intel | artifact | resource | key | misc
class_name ItemDefinition
extends Resource

const KINDS := ["equipment", "consumable", "intel", "artifact", "resource", "key", "misc"]
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "unique"]

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: String = "misc"
@export var slot: String = ""
@export var icon_key: String = ""
@export var rarity: String = "common"
@export var value: int = 0
@export var stackable: bool = true
@export var max_stack: int = 99
@export var unique: bool = false
@export var modifiers: Dictionary = {}       ## stat -> delta while equipped/held (artifact)
@export var use_effects: Array[Dictionary] = []
@export var use_requires: Dictionary = {}    ## IntelQuery evaluated for the owner's faction
@export var grants_intel: PackedStringArray = []
@export var consume_on_use: bool = true
@export var tags: PackedStringArray = []
@export var metadata: Dictionary = {}


static func from_dict(d: Dictionary) -> ItemDefinition:
	var it := ItemDefinition.new()
	it.id = d.get("id", "")
	it.display_name = d.get("display_name", it.id.capitalize())
	it.description = d.get("description", "")
	it.kind = d.get("kind", "misc")
	it.slot = d.get("slot", "")
	it.icon_key = d.get("icon", "icon.item.%s" % it.id)
	it.rarity = d.get("rarity", "common")
	it.value = int(d.get("value", 0))
	it.stackable = bool(d.get("stackable", it.kind not in ["equipment", "artifact"]))
	it.max_stack = int(d.get("max_stack", 99))
	it.unique = bool(d.get("unique", false))
	it.modifiers = d.get("modifiers", {})
	it.use_effects.assign(d.get("use_effects", []))
	it.use_requires = d.get("use_requires", {})
	it.grants_intel = PackedStringArray(d.get("grants_intel", []))
	it.consume_on_use = bool(d.get("consume_on_use", it.kind in ["consumable", "intel"]))
	it.tags = PackedStringArray(d.get("tags", []))
	it.metadata = d.get("metadata", {})
	return it


func is_usable() -> bool:
	return not use_effects.is_empty() or not grants_intel.is_empty()


func is_equippable() -> bool:
	return kind == "equipment" and slot != ""
