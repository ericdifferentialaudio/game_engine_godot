## Static description of any actor archetype: player, NPC, monster, boss (actors.json).
class_name ActorDefinition
extends Definition

enum Role { PLAYER, NPC, MONSTER, BOSS, SUMMON, CREATURE }
const ROLE_NAMES := {"player": Role.PLAYER, "npc": Role.NPC, "monster": Role.MONSTER,
	"boss": Role.BOSS, "summon": Role.SUMMON, "creature": Role.CREATURE}

@export var role: Role = Role.MONSTER
@export var level: int = 1
@export var faction_id: String = "neutral"
@export var stats: Dictionary = {}              ## base stat values {"strength": 10, "armor": 4, ...}
@export var resources: Dictionary = {}          ## {"health": 40, "mana": 0, "stamina": 50}
@export var resistances: Dictionary = {}        ## {"fire": 0.2, "holy": -0.5}
@export var immunities: Array[String] = []
@export var abilities: Array[String] = []
@export var equipment: Dictionary = {}          ## slot -> item id
@export var inventory: Dictionary = {}          ## item id -> count
@export var loot_table: String = ""
@export var xp_value: int = 0
@export var brain: String = "ai"                ## "player" | "ai" | "none"
@export var behaviour: Dictionary = {}          ## AI profile {"style": "melee|caster|skirmisher|support", "flee_below": 0.2, ...}
@export var senses: Dictionary = {}             ## {"sight_range": 20, "fov": 110, "hearing": 15}
@export var move_speed: float = 4.0
@export var size: Dictionary = {}               ## {"radius": 0.35, "height": 1.8}
@export var schedule: Array[Dictionary] = []    ## NPCs: [{"from": 6, "to": 22, "map": "hollowmere", "spot": "inn_counter"}]
@export var dialogue_id: String = ""
@export var visual_key: String = ""
@export var phases: Array[Dictionary] = []      ## bosses: [{"below_health": 0.5, "abilities": [...], "effects": [...]}]
@export var weakness_intel: String = ""         ## intel token that reveals resistances/immunities in UI


func _apply(d: Dictionary) -> void:
	role = ROLE_NAMES.get(str(d.get("role", "monster")), Role.MONSTER)
	level = int(d.get("level", 1))
	faction_id = str(d.get("faction", "neutral"))
	stats = d.get("stats", {})
	resources = d.get("resources", {})
	resistances = d.get("resistances", {})
	immunities = Definition._str_array(d.get("immunities", []))
	abilities = Definition._str_array(d.get("abilities", []))
	equipment = d.get("equipment", {})
	inventory = d.get("inventory", {})
	loot_table = str(d.get("loot_table", ""))
	xp_value = int(d.get("xp", 0))
	brain = str(d.get("brain", "player" if role == Role.PLAYER else "ai"))
	behaviour = d.get("behaviour", {})
	senses = d.get("senses", {})
	move_speed = float(d.get("move_speed", 4.0))
	size = d.get("size", {})
	schedule = Definition._dict_array(d.get("schedule", []))
	dialogue_id = str(d.get("dialogue", ""))
	visual_key = str(d.get("visual", "actor.%s" % id))
	phases = Definition._dict_array(d.get("phases", []))
	weakness_intel = str(d.get("weakness_intel", ""))


func role_name() -> String:
	return Role.keys()[role].to_lower()
