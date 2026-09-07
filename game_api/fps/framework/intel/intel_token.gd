## A unit of information the player can learn.
##
## Design notes
## ------------
## * subject      – what the intel is about (an NPC, place, faction, item...).
##                  Lets the journal group tokens and lets queries ask
##                  "do I know anything about X?".
## * facts        – key/value payload consumed by game logic (e.g. {"location": "ruins_north"}).
## * reliability  – 0..1; rumours start low, corroboration from independent
##                  sources raises it. Queries can require a minimum.
## * expires_after– seconds of game time until stale (0 = never). Time-sensitive
##                  intel ("the caravan leaves at dusk") drives urgency.
## * conflicts    – ids of tokens that contradict this one; UI can surface
##                  contradictions and the player must decide whom to trust.
class_name IntelToken
extends Definition

@export var title: String = ""
@export var summary: String = ""
@export var subject: String = ""
@export var category: String = "rumor"    ## rumor | fact | secret | location | password | schedule ...
@export var facts: Dictionary = {}
@export var base_reliability: float = 0.5
@export var corroboration_step: float = 0.2
@export var expires_after: float = 0.0    ## GAME seconds (GameClock), 0 = never.
@export var conflicts: PackedStringArray = []
@export var value: int = 0                ## Trade value if intel can be sold.

# Runtime (journal instance only)
var reliability: float = 0.5
var sources: Array[String] = []
var acquired_at: float = -1.0             ## GameClock.now() at acquisition; -1 = not acquired.
var expiry_notified: bool = false


static func from_dict(d: Dictionary) -> IntelToken:
	return Definition.build(IntelToken, d) as IntelToken


func _apply(d: Dictionary) -> void:
	title = d.get("title", id)
	display_name = title
	summary = d.get("summary", "")
	subject = d.get("subject", "")
	category = d.get("category", "rumor")
	facts = d.get("facts", {})
	base_reliability = float(d.get("reliability", 0.5))
	corroboration_step = float(d.get("corroboration_step", 0.2))
	expires_after = float(d.get("expires_after", 0.0))
	conflicts = PackedStringArray(d.get("conflicts", []))
	value = int(d.get("value", 0))
	reliability = base_reliability


func duplicate_instance() -> IntelToken:
	var t := duplicate(true) as IntelToken
	t.reliability = base_reliability
	t.sources = []
	t.acquired_at = -1.0
	t.expiry_notified = false
	return t


## Another independent source confirmed this intel.
func corroborate(source: String) -> void:
	if source != "" and source in sources:
		return
	sources.append(source)
	reliability = clampf(reliability + corroboration_step, 0.0, 1.0)


func is_expired() -> bool:
	if expires_after <= 0.0 or acquired_at < 0.0:
		return false
	return GameClock.now() - acquired_at > expires_after


## Game seconds remaining before this intel goes stale (INF if it never does).
func time_remaining() -> float:
	if expires_after <= 0.0 or acquired_at < 0.0:
		return INF
	return maxf(0.0, expires_after - (GameClock.now() - acquired_at))


func to_dict() -> Dictionary:
	return {
		"reliability": reliability,
		"sources": sources,
		"acquired_at": acquired_at,
	}


func apply_runtime(d: Dictionary) -> void:
	reliability = float(d.get("reliability", base_reliability))
	sources.assign(d.get("sources", []))
	acquired_at = float(d.get("acquired_at", -1.0))
