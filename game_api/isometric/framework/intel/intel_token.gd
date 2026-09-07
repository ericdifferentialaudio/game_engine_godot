## A unit of information a faction can hold.
##
## Definition fields (intel.json) — the template every journal instance copies:
##   id, title, summary
##   subject       – what it is about (unit id, site id, faction id, tile "q,r", item id, "world")
##   scope         – global | region | tile | site | unit | faction | item   (what kind of subject)
##   category      – rumor | fact | secret | location | password | schedule | military | economic |
##                   diplomatic | geographic | lore | map | tech
##   tags          – free-form filters
##   facts         – key/value payload consumed by game logic
##   reliability   – 0..1 starting belief; corroboration raises it, contradictions can lower it
##   corroboration_step – how much each independent confirming source adds
##   decay_turns   – turns until the token goes stale (0 = never). Stale tokens stay in the
##                   journal but fail queries unless the query says allow_stale.
##   conflicts     – ids of tokens that contradict this one
##   secrecy       – 0..1; higher is harder to spread/steal/trade (see IntelRules)
##   spreadable    – may propagate to other factions via spread rules
##   tradeable     – may be sold/exchanged in diplomacy or intel shops
##   value         – base trade value (scaled by reliability at sale time)
##   reveals       – {"tiles": [[q,r],...], "radius": 2, "around": "site_id"|"unit_id"|[q,r],
##                    "sites": ["site_id"], "units": ["unit_id"]} – map knowledge granted on acquisition
##   effects       – interaction specs run when acquired (reward/flag/etc.) — hooks for game logic
##   metadata      – free-form
##
## Runtime (journal instance only): reliability, provenance chain, acquisition turn,
## last confirmed turn, stale flag, lie flag.
class_name IntelToken
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var summary: String = ""
@export var subject: String = ""
@export var scope: String = "global"
@export var category: String = "rumor"
@export var tags: PackedStringArray = []
@export var facts: Dictionary = {}
@export var base_reliability: float = 0.5
@export var corroboration_step: float = 0.2
@export var decay_turns: int = 0
@export var conflicts: PackedStringArray = []
@export var secrecy: float = 0.3
@export var spreadable: bool = true
@export var tradeable: bool = true
@export var value: int = 0
@export var reveals: Dictionary = {}
@export var effects: Array[Dictionary] = []
@export var metadata: Dictionary = {}

# Runtime (journal instance only)
var reliability: float = 0.5
var provenance: Array[Provenance] = []  ## Oldest first.
var acquired_turn: float = -1.0
var confirmed_turn: float = -1.0
var stale_notified: bool = false
var known_false: bool = false           ## Holder has proof this token is a lie.
var revealed_applied: bool = false


static func from_dict(d: Dictionary) -> IntelToken:
	var t := IntelToken.new()
	t.id = d.get("id", "")
	t.title = d.get("title", t.id)
	t.summary = d.get("summary", "")
	t.subject = d.get("subject", "world")
	t.scope = d.get("scope", "global")
	t.category = d.get("category", "rumor")
	t.tags = PackedStringArray(d.get("tags", []))
	t.facts = d.get("facts", {})
	t.base_reliability = clampf(float(d.get("reliability", 0.5)), 0.0, 1.0)
	t.corroboration_step = float(d.get("corroboration_step", 0.2))
	t.decay_turns = int(d.get("decay_turns", 0))
	t.conflicts = PackedStringArray(d.get("conflicts", []))
	t.secrecy = clampf(float(d.get("secrecy", 0.3)), 0.0, 1.0)
	t.spreadable = bool(d.get("spreadable", true))
	t.tradeable = bool(d.get("tradeable", true))
	t.value = int(d.get("value", 0))
	t.reveals = d.get("reveals", {})
	t.effects.assign(d.get("effects", []))
	t.metadata = d.get("metadata", {})
	t.reliability = t.base_reliability
	return t


func duplicate_instance() -> IntelToken:
	var t := duplicate(true) as IntelToken
	t.reliability = base_reliability
	t.provenance = []
	t.acquired_turn = -1.0
	t.confirmed_turn = -1.0
	t.stale_notified = false
	t.known_false = false
	t.revealed_applied = false
	return t


## Sources that independently vouch for this token.
func sources() -> PackedStringArray:
	var out := PackedStringArray()
	for p in provenance:
		if p.source_id != "" and p.source_id not in out:
			out.append(p.source_id)
	return out


## Another independent source confirmed this intel. Returns true if it counted.
func corroborate(entry: Provenance) -> bool:
	if entry.source_id != "" and entry.source_id in sources():
		return false
	provenance.append(entry)
	reliability = clampf(reliability + corroboration_step * entry.trust, 0.0, 1.0)
	confirmed_turn = entry.turn
	stale_notified = false
	return true


## Evidence against this token lowers belief.
func dispute(amount: float) -> void:
	reliability = clampf(reliability - amount, 0.0, 1.0)


func is_stale(now_turn: float) -> bool:
	if decay_turns <= 0 or acquired_turn < 0.0:
		return false
	var ref := confirmed_turn if confirmed_turn >= 0.0 else acquired_turn
	return now_turn - ref > float(decay_turns)


func age(now_turn: float) -> float:
	return maxf(0.0, now_turn - acquired_turn) if acquired_turn >= 0.0 else 0.0


func to_dict() -> Dictionary:
	var prov := []
	for p in provenance:
		prov.append(p.to_dict())
	return {
		"reliability": reliability,
		"provenance": prov,
		"acquired_turn": acquired_turn,
		"confirmed_turn": confirmed_turn,
		"known_false": known_false,
		"revealed_applied": revealed_applied,
	}


func apply_runtime(d: Dictionary) -> void:
	reliability = float(d.get("reliability", base_reliability))
	provenance.clear()
	for pd in d.get("provenance", []):
		provenance.append(Provenance.from_dict(pd))
	acquired_turn = float(d.get("acquired_turn", -1.0))
	confirmed_turn = float(d.get("confirmed_turn", -1.0))
	known_false = bool(d.get("known_false", false))
	revealed_applied = bool(d.get("revealed_applied", false))
