## A unit of information a holder (player or faction) can know.
##
## Merged from both engines: the isometric version (turn-based decay, provenance
## chains, secrecy/spread/trade) is the superset, and the FPS version's
## real-time `expires_after` is preserved as an alternative decay clock.
## Whichever clock the host engine drives, [method is_stale] takes a single
## "now" value in that engine's own time unit (turns for iso, game seconds
## for FPS) — the core never assumes which.
##
## JSON (intel.json):
##   {"id": "crypt_location", "title": "The Sunken Crypt", "subject": "crypt",
##    "scope": "site", "category": "location", "reliability": 0.4,
##    "decay_turns": 20, "conflicts": ["crypt_is_myth"], "facts": {"map": "crypt"}}
class_name CoreIntelToken
extends CoreDefinition

const SCOPES := ["global", "region", "tile", "site", "unit", "faction", "item"]
const CATEGORIES := ["rumor", "fact", "secret", "location", "password", "schedule",
	"military", "economic", "diplomatic", "geographic", "lore", "map", "tech"]

@export var title: String = ""
@export var summary: String = ""
@export var subject: String = ""            ## what the intel is about
@export var scope: String = "global"
@export var category: String = "rumor"
@export var facts: Dictionary = {}          ## key/value payload for game logic
@export var base_reliability: float = 0.5
@export var corroboration_step: float = 0.2
@export var decay_turns: float = 0.0        ## 0 = never goes stale
@export var conflicts: PackedStringArray = []
@export var secrecy: float = 0.3
@export var spreadable: bool = true
@export var tradeable: bool = true
@export var value: int = 0
@export var reveals: Dictionary = {}        ## map knowledge granted on acquisition
@export var effects: Array[Dictionary] = [] ## interaction specs run when acquired

# --- Runtime (journal instance only) -------------------------------------------
var reliability: float = 0.5
var provenance: Array[CoreProvenance] = []  ## Oldest first.
var acquired_at: float = -1.0
var confirmed_at: float = -1.0
var stale_notified: bool = false
var known_false: bool = false               ## Holder has proof this is a lie.
var revealed_applied: bool = false


static func from_dict(d: Dictionary) -> CoreIntelToken:
	return CoreDefinition.build(CoreIntelToken, d) as CoreIntelToken


func _apply(d: Dictionary) -> void:
	title = str(d.get("title", display_name))
	display_name = title
	summary = str(d.get("summary", description))
	subject = str(d.get("subject", "world"))
	scope = str(d.get("scope", "global"))
	category = str(d.get("category", "rumor"))
	facts = d.get("facts", {})
	base_reliability = clampf(float(d.get("reliability", 0.5)), 0.0, 1.0)
	corroboration_step = float(d.get("corroboration_step", 0.2))
	# decay_turns (iso) or expires_after (fps) — same field, engine-defined unit.
	decay_turns = float(d.get("decay_turns", d.get("expires_after", 0.0)))
	conflicts = CoreDataLoader.packed_str_array(d.get("conflicts", []))
	secrecy = clampf(float(d.get("secrecy", 0.3)), 0.0, 1.0)
	spreadable = bool(d.get("spreadable", true))
	tradeable = bool(d.get("tradeable", true))
	value = int(d.get("value", 0))
	reveals = d.get("reveals", {})
	effects = CoreDataLoader.dict_array(d.get("effects", []))
	reliability = base_reliability


## A fresh, unacquired copy for a holder's journal.
func duplicate_instance() -> CoreIntelToken:
	var t := duplicate(true) as CoreIntelToken
	t.raw = raw
	t.reliability = base_reliability
	t.provenance = []
	t.acquired_at = -1.0
	t.confirmed_at = -1.0
	t.stale_notified = false
	t.known_false = false
	t.revealed_applied = false
	return t


## Distinct sources that independently vouch for this token.
func sources() -> PackedStringArray:
	var out := PackedStringArray()
	for p in provenance:
		if p.source_id != "" and p.source_id not in out:
			out.append(p.source_id)
	return out


## Another independent source confirmed this intel. Returns true if it counted.
func corroborate(entry: CoreProvenance) -> bool:
	if entry.source_id != "" and entry.source_id in sources():
		return false
	provenance.append(entry)
	reliability = clampf(reliability + corroboration_step * entry.trust, 0.0, 1.0)
	confirmed_at = entry.at
	stale_notified = false
	return true


## Evidence against this token lowers belief.
func dispute(amount: float) -> void:
	reliability = clampf(reliability - amount, 0.0, 1.0)


func is_stale(now: float) -> bool:
	if decay_turns <= 0.0 or acquired_at < 0.0:
		return false
	var ref := confirmed_at if confirmed_at >= 0.0 else acquired_at
	return now - ref > decay_turns


func age(now: float) -> float:
	return maxf(0.0, now - acquired_at) if acquired_at >= 0.0 else 0.0


## Time left before going stale, in the host engine's time unit (INF if never).
func time_remaining(now: float) -> float:
	if decay_turns <= 0.0 or acquired_at < 0.0:
		return INF
	var ref := confirmed_at if confirmed_at >= 0.0 else acquired_at
	return maxf(0.0, decay_turns - (now - ref))


## Trade price at current belief.
func trade_value() -> int:
	return int(round(float(value) * reliability))


func to_dict() -> Dictionary:
	var prov := []
	for p in provenance:
		prov.append(p.to_dict())
	return {
		"reliability": reliability,
		"provenance": prov,
		"acquired_at": acquired_at,
		"confirmed_at": confirmed_at,
		"known_false": known_false,
		"revealed_applied": revealed_applied,
	}


func apply_runtime(d: Dictionary) -> void:
	reliability = float(d.get("reliability", base_reliability))
	provenance.clear()
	for pd in d.get("provenance", []):
		provenance.append(CoreProvenance.from_dict(pd))
	acquired_at = float(d.get("acquired_at", -1.0))
	confirmed_at = float(d.get("confirmed_at", -1.0))
	known_false = bool(d.get("known_false", false))
	revealed_applied = bool(d.get("revealed_applied", false))
