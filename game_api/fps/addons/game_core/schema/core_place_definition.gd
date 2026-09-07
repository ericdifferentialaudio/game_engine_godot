## A place in the world: town, village, castle, shrine, dragon lair, dungeon,
## portal, island resource node — anything worth putting on a map and visiting.
##
## This is the single shared vocabulary replacing the isometric engine's
## SiteDefinition and the FPS engine's PoiDefinition. Only *presentation*
## differs between engines; ownership, garrisons, gating, yields, interactions
## and containment are simulation and live here.
##
## ---------------------------------------------------------------------------
## EXTENSIBILITY (the point of this class)
## ---------------------------------------------------------------------------
## Nothing here is a closed set. A game can:
##
## 1. Inherit an archetype and override only the deltas:
##      {"id": "hollowmere", "extends": "village", "owner": "greywood"}
##
## 2. Invent categories the framework has never heard of. Categories are plain
##    strings; CATEGORY_TRAITS only supplies *defaults*. A game registers its
##    own traits at boot:
##      CorePlaceDefinition.register_category("dragon_lair",
##          {"dangerous": true, "capturable": true, "defense_bonus": 60.0})
##
## 3. Carry arbitrary fields. Anything unmapped stays in `raw`, readable via
##    extra("key"), so a game's "hoard_size" or "tide_locked" survives a load
##    without any framework change.
##
## 4. Add behaviour through interactions (see CoreInteraction) and traits,
##    rather than by subclassing.
##
##   {"id": "mount_cinder", "extends": "lair", "category": "dragon_lair",
##    "display_name": "Cinderpeak", "boss": "ancient_red_dragon",
##    "garrison": [{"unit": "drake", "count": 3, "respawn_after": 20}],
##    "yields": {"treasure": 5}, "traits": {"flying_only": true},
##    "hidden_until": {"has": "rumor_the_burning_peak"}}
##
##   {"id": "pearl_shoal", "extends": "resource", "category": "island_resource",
##    "yields": {"pearls": 3}, "requires_access": "boat",
##    "traits": {"island": true, "storm_risk": 0.2}}
class_name CorePlaceDefinition
extends CoreDefinition

## Built-in category traits. These are DEFAULTS ONLY — every one can be
## overridden per-place in JSON, and games may register entirely new
## categories via register_category(). Never treat this as exhaustive.
const CATEGORY_TRAITS := {
	# --- Settlements ---
	"city":       {"settlement": true, "capturable": true, "defense_bonus": 40.0, "sight": 3},
	"town":       {"settlement": true, "capturable": true, "defense_bonus": 25.0, "sight": 2},
	"village":    {"settlement": true, "capturable": true, "defense_bonus": 10.0, "sight": 2},
	"hamlet":     {"settlement": true, "capturable": true, "sight": 1},
	"camp":       {"settlement": true, "capturable": true, "sight": 2},
	# --- Fortifications ---
	"castle":     {"fortification": true, "capturable": true, "defense_bonus": 75.0, "sight": 4},
	"keep":       {"fortification": true, "capturable": true, "defense_bonus": 50.0, "sight": 3},
	"fort":       {"fortification": true, "capturable": true, "defense_bonus": 45.0, "sight": 3},
	"tower":      {"fortification": true, "capturable": true, "defense_bonus": 30.0, "sight": 5},
	"outpost":    {"fortification": true, "capturable": true, "defense_bonus": 15.0, "sight": 3},
	# --- Sacred ---
	"shrine":     {"sacred": true, "sight": 1},
	"temple":     {"sacred": true, "capturable": true, "defense_bonus": 15.0, "sight": 2},
	"monastery":  {"sacred": true, "capturable": true, "defense_bonus": 20.0, "sight": 2},
	# --- Lairs & dungeons ---
	"lair":       {"dangerous": true, "capturable": true, "defense_bonus": 25.0},
	"dungeon":    {"dangerous": true, "enterable": true, "defense_bonus": 30.0},
	"crypt":      {"dangerous": true, "enterable": true, "defense_bonus": 30.0},
	"cave":       {"dangerous": true, "enterable": true},
	"ruins":      {"dangerous": true, "enterable": true, "defense_bonus": 10.0},
	"battlefield":{"dangerous": true},
	# --- Transit ---
	"portal":     {"transit": true, "enterable": true},
	"gate":       {"transit": true, "enterable": true},
	"bridge":     {"transit": true},
	"stairs":     {"transit": true, "enterable": true},
	# --- Economic ---
	"mine":       {"economic": true, "capturable": true},
	"farm":       {"economic": true, "capturable": true},
	"mill":       {"economic": true, "capturable": true},
	"market":     {"economic": true, "enterable": true},
	"shop":       {"economic": true, "enterable": true},
	"inn":        {"economic": true, "enterable": true},
	"resource":   {"economic": true, "capturable": true},
	# --- Informational / misc ---
	"landmark":   {},
	"cache":      {},
	"informant":  {},
	"npc":        {},
	"generic":    {},
}

## Trait keys the framework itself understands. Games may add any others;
## unknown traits are preserved and queryable via has_trait()/trait_value().
const KNOWN_TRAITS := ["settlement", "fortification", "sacred", "dangerous",
	"transit", "economic", "capturable", "enterable"]

## Game-registered categories, merged over CATEGORY_TRAITS. Static so a game
## can register before any package is loaded.
static var _custom_categories: Dictionary = {}


## Teach the framework a new place category (or override a built-in one).
##
##   CorePlaceDefinition.register_category("dragon_lair",
##       {"dangerous": true, "capturable": true, "defense_bonus": 60.0, "sight": 3})
##
## Categories work without registering — this only supplies defaults so every
## place of that category need not repeat them.
static func register_category(category: String, traits: Dictionary) -> void:
	_custom_categories[category] = traits


static func category_traits(category: String) -> Dictionary:
	if _custom_categories.has(category):
		return _custom_categories[category]
	return CATEGORY_TRAITS.get(category, {})


static func known_categories() -> Array:
	var out := CATEGORY_TRAITS.keys()
	for k in _custom_categories:
		if k not in out:
			out.append(k)
	return out


# --- Identity ------------------------------------------------------------------
@export var category: String = "generic"
@export var map_id: String = ""              ## Map this place sits on.
@export var parent_place_id: String = ""     ## Containing place (keep inside a castle).

# --- Placement (resolved per engine by CoreEngineAdapter) ----------------------
## Abstract anchor. The isometric engine reads `coord`; the FPS engine reads
## `position`/`yaw`. Games author whichever their target engine needs, or use
## `placement` to let the engine choose a spot.
@export var coord: Vector2i = Vector2i(-1, -1)
@export var position: Array = []             ## [x, y, z] for 3D engines
@export var yaw: float = 0.0
@export var placement: String = "fixed"      ## fixed | random_land | random_coast | ...
@export var placement_rules: Dictionary = {} ## free-form hints for a generator

# --- Ownership & control --------------------------------------------------------
@export var owner_id: String = ""
@export var capturable: bool = false
@export var defense_bonus: float = 0.0
@export var sight: int = 1
@export var yields: Dictionary = {}          ## resource_id -> per-turn amount

# --- Population ------------------------------------------------------------------
@export var garrison: Array[Dictionary] = [] ## [{unit, count, faction?, respawn_after?, radius?}]
@export var boss: String = ""                ## optional unique unit id (dragon, lich...)
@export var population: int = 0

# --- Access & discovery -----------------------------------------------------------
@export var hidden_until: Dictionary = {}    ## CoreIntelQuery; invisible until satisfied
@export var enter_requires: Dictionary = {}  ## CoreIntelQuery gate to interact/enter
@export var requires_access: String = ""     ## e.g. "boat", "flight", "key_item"
@export var discover_intel: PackedStringArray = []
@export var discover_radius: float = 0.0     ## 3D auto-discovery (0 = on entry only)
@export var interact_radius: float = 0.0

# --- Behaviour ---------------------------------------------------------------------
@export var interactions: Array[Dictionary] = []
@export var contains: PackedStringArray = [] ## child place ids (castle -> courtyard, keep)
@export var leads_to: String = ""            ## map id this place descends into

# --- Open-ended extension ------------------------------------------------------------
## Merged from the category defaults, then the place's own "traits" block.
## Games put anything here: {"flying_only": true, "tide_locked": true}.
@export var traits: Dictionary = {}

# --- Presentation (logical keys; each engine resolves its own asset) ----------------
@export var visual_key: String = ""
@export var icon_key: String = ""
@export var music_key: String = ""
@export var environment_key: String = ""


func _apply(d: Dictionary) -> void:
	category = str(d.get("category", d.get("kind", "generic")))
	map_id = str(d.get("map", d.get("map_id", "")))
	parent_place_id = str(d.get("parent", d.get("parent_place", "")))

	# Traits: category defaults first, then per-place overrides.
	traits = category_traits(category).duplicate(true)
	for k in d.get("traits", {}):
		traits[k] = d["traits"][k]

	# Placement: tile coord (2D), world position (3D), or generator-chosen.
	var c = d.get("coord", null)
	if c is Array and c.size() == 2:
		coord = Vector2i(int(c[0]), int(c[1]))
	position = d.get("position", [])
	yaw = float(d.get("yaw", 0.0))
	var has_anchor := coord.x >= 0 or not position.is_empty()
	placement = str(d.get("placement", "fixed" if has_anchor else "random_land"))
	placement_rules = d.get("placement_rules", {})

	# Ownership: explicit value wins, else the category default.
	owner_id = str(d.get("owner", d.get("owner_id", "")))
	capturable = bool(d.get("capturable", traits.get("capturable", false)))
	defense_bonus = float(d.get("defense_bonus", traits.get("defense_bonus", 0.0)))
	sight = int(d.get("sight", traits.get("sight", 1)))
	yields = d.get("yields", {})

	garrison = CoreDataLoader.dict_array(d.get("garrison", d.get("spawns", [])))
	boss = str(d.get("boss", ""))
	population = int(d.get("population", 0))

	hidden_until = d.get("hidden_until", {})
	enter_requires = d.get("enter_requires", d.get("requires", {}))
	requires_access = str(d.get("requires_access", ""))
	discover_intel = CoreDataLoader.packed_str_array(d.get("discover_intel", []))
	discover_radius = float(d.get("discover_radius", 0.0))
	interact_radius = float(d.get("interact_radius", 0.0))

	interactions = CoreDataLoader.dict_array(d.get("interactions", []))
	contains = CoreDataLoader.packed_str_array(d.get("contains", []))
	leads_to = str(d.get("leads_to", ""))

	visual_key = str(d.get("visual", "place.%s" % category))
	icon_key = str(d.get("icon", "icon.place.%s" % category))
	music_key = str(d.get("music", ""))
	environment_key = str(d.get("environment", ""))


# --- Trait queries ------------------------------------------------------------
## Prefer these over comparing `category` strings: a game's "dragon_lair" or
## "island_resource" answers correctly without the framework knowing it exists.

func has_trait(trait_name: String) -> bool:
	return bool(traits.get(trait_name, false))


## Read any trait value (including game-defined, non-boolean ones).
func trait_value(trait_name: String, default = null):
	return traits.get(trait_name, default)


func is_settlement() -> bool:
	return has_trait("settlement")


func is_fortification() -> bool:
	return has_trait("fortification")


func is_sacred() -> bool:
	return has_trait("sacred")


func is_dangerous() -> bool:
	return has_trait("dangerous")


func is_economic() -> bool:
	return has_trait("economic")


func is_transit() -> bool:
	return has_trait("transit")


## Can the player descend into this place as its own map?
func is_enterable() -> bool:
	return leads_to != "" or has_trait("enterable")


func is_capturable() -> bool:
	return capturable


func has_garrison() -> bool:
	return not garrison.is_empty() or boss != ""


## Every unit this place spawns, flattened. Honours per-entry faction overrides,
## falling back to the place's owner.
func garrison_units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if boss != "":
		out.append({"unit": boss, "count": 1, "faction": owner_id, "boss": true})
	for g in garrison:
		var entry := g.duplicate()
		entry["count"] = int(g.get("count", 1))
		entry["faction"] = str(g.get("faction", owner_id))
		out.append(entry)
	return out


## Total per-turn yield of one resource.
func yield_of(resource_id: String) -> float:
	return float(yields.get(resource_id, 0.0))
