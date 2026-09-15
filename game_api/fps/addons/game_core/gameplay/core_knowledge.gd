## Boolean knowledge: does the holder know a thing, yes or no?
##
## Registered as the `CoreKnowledge` autoload.
##
## This is deliberately a **facade over `CoreIntel`**, not a second store. The
## platform already models information richly (reliability, corroboration,
## provenance, decay, secrecy, `conflicts`, `debunk`). Narrative authors mostly
## do not want that: they want `{ knows(know_trapdoor): ... }`.
##
## So: one store, two reading levels.
##
##   knows(id)            -> believed at or above the belief threshold
##   believes(id, min)    -> believed at or above an explicit threshold
##   heard_of(id)         -> in the journal at all, however dubious
##
## Hearing a rumour is therefore *not* knowing it. A token authored at
## `reliability: 0.3` (a tavern rumour) reads false from `knows()`; the same
## fact learned from a reliable source, or corroborated by a second independent
## source, crosses the threshold and reads true. A token the holder has proven
## false (`known_false`) always reads false.
##
## The threshold is per-game:
##   game.json -> {"rules": {"knowledge": {"belief_threshold": 0.5}}}
class_name CoreKnowledgeStore
extends Node

## A fact crossed from "not known" to "known" for this holder.
signal learned(holder: String, knowledge_id: String, source: String)
## A fact stopped being known (debunked, decayed below threshold, or forgotten).
signal forgotten(holder: String, knowledge_id: String)

## Belief required before [method knows] returns true, when a game sets no rule.
const DEFAULT_BELIEF_THRESHOLD := 0.5

## Holder used when a caller does not name one. Games with factions pass their
## own; single-protagonist games can leave this alone.
var default_holder: String = "player"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Keep the boolean view honest: a debunked token must stop being "known".
	if not CoreIntel.debunked.is_connected(_on_debunked):
		CoreIntel.debunked.connect(_on_debunked)


## The belief level a fact must reach to count as known.
func belief_threshold() -> float:
	return float(CoreContext.rule("knowledge.belief_threshold", DEFAULT_BELIEF_THRESHOLD))


# --- Queries ------------------------------------------------------------------

## Does the holder know this, firmly enough to act on it?
func knows(knowledge_id: String, holder: String = "") -> bool:
	return believes(knowledge_id, belief_threshold(), holder)


## Does the holder believe this at least [param min_belief] much (0..1)?
## Pass 0.0 to mean "has encountered it and has not disproved it".
func believes(knowledge_id: String, min_belief: float, holder: String = "") -> bool:
	return CoreIntel.knows(_holder(holder), knowledge_id, min_belief)


## Has the holder encountered this at all — even as an unreliable rumour, and
## even if they have since proved it false? Use for "you have heard this before"
## dialogue, never for gating a real outcome.
func heard_of(knowledge_id: String, holder: String = "") -> bool:
	return CoreIntel.journal_for(_holder(holder)).has(knowledge_id)


## How strongly the holder believes this, 0..1. 0.0 when never encountered or
## proven false. Lets a writer shade a line by confidence.
func belief(knowledge_id: String, holder: String = "") -> float:
	var tok := CoreIntel.journal_for(_holder(holder)).get_token(knowledge_id)
	if tok == null or tok.known_false:
		return 0.0
	return tok.reliability


## Has the holder positively established this is a lie?
func disbelieves(knowledge_id: String, holder: String = "") -> bool:
	var tok := CoreIntel.journal_for(_holder(holder)).get_token(knowledge_id)
	return tok != null and tok.known_false


## Every knowledge id the holder currently knows (above the threshold).
func known_ids(holder: String = "") -> Array[String]:
	var out: Array[String] = []
	var threshold := belief_threshold()
	for tok in CoreIntel.journal_for(_holder(holder)).tokens.values():
		if not tok.known_false and tok.reliability >= threshold:
			out.append(tok.id)
	out.sort()
	return out


# --- Mutations ----------------------------------------------------------------

## Teach the holder something.
##
## [param trust] is how much the holder credits this source, 0..1 — the lever
## that makes "a drunk told me" differ from "I read it in the ledger". A fact
## learned from a fully trusted source arrives at its authored reliability.
##
## Returns true if this crossed them over into knowing it (so a caller can
## show a "you have learned..." notification only when it means something).
func learn(knowledge_id: String, source: String = "", holder: String = "",
		trust: float = 1.0, channel: String = "told") -> bool:
	var who := _holder(holder)
	var knew_before := knows(knowledge_id, who)
	CoreIntel.acquire(who, knowledge_id, source, channel, clampf(trust, 0.0, 1.0))
	var knows_now := knows(knowledge_id, who)
	if knows_now and not knew_before:
		learned.emit(who, knowledge_id, source)
		return true
	return false


## Teach something outright, bypassing trust — the holder saw it themselves.
func learn_firsthand(knowledge_id: String, source: String = "", holder: String = "") -> bool:
	return learn(knowledge_id, source, holder, 1.0, "witnessed")


## Remove a fact entirely. Knowledge is permanent by default; this exists for
## games that explicitly take it away (amnesia, a burned document, a spell).
func forget(knowledge_id: String, holder: String = "") -> bool:
	var who := _holder(holder)
	var journal := CoreIntel.journal_for(who)
	if not journal.forget(knowledge_id):
		return false
	forgotten.emit(who, knowledge_id)
	return true


func _holder(holder: String) -> String:
	return holder if holder != "" else default_holder


func _on_debunked(holder: String, token_id: String) -> void:
	forgotten.emit(holder, token_id)
