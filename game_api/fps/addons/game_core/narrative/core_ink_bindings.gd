## Binds the shared game systems into an Ink story as EXTERNAL functions.
##
## This is the seam where narrative meets simulation. `CoreInkEngine` knows
## nothing about knowledge or assets; the stores know nothing about Ink. This
## class introduces them, and is the single place to look up what vocabulary a
## writer may use.
##
## Declare the ones you use at the top of your .ink file:
##
##   EXTERNAL knows(id)
##   EXTERNAL has_asset(id, amount)
##   EXTERNAL spend_asset(id, amount)
##   ...
##
## Query functions are bound lookahead-safe (Ink may evaluate them
## speculatively while working out which choices to show — that is harmless for
## a read). Mutating functions are **not**, so paying for something cannot fire
## twice. This distinction is the whole reason this class exists.
class_name CoreInkBindings
extends RefCounted

## The holder these bindings act for — normally the player.
var holder: String = "player"
## The NPC/subject this conversation is with, used by the no-argument standing
## helpers so writers do not repeat the npc id in every condition.
var subject: String = ""
## Optional place qualifier for standing (see `CoreStandingStore`).
var place: String = ""

## Names of every function this class can bind, for the static validator.
const FUNCTION_NAMES := [
	"knows", "believes", "heard_of", "disbelieves", "learn", "forget",
	"has_asset", "asset_count", "give_asset", "spend_asset", "lose_asset",
	"standing", "standing_at_least", "adjust_standing",
	"stat", "stat_at_least", "flag", "set_flag",
]

## Query functions: safe to evaluate speculatively during choice lookahead.
const READ_ONLY := [
	"knows", "believes", "heard_of", "disbelieves",
	"has_asset", "asset_count",
	"standing", "standing_at_least",
	"stat", "stat_at_least", "flag",
]


## The stores this instance talks to, resolved once at construction.
##
## Resolved from the scene tree rather than referenced as bare autoload names,
## because a script launched with `godot -s` (the validators) is compiled
## before the autoloads register, and a compile-time reference would make this
## class unusable from any command-line tool.
var _knowledge: Node
var _assets: Node
var _standing: Node
var _context: Node


func _init(p_holder: String = "player", p_subject: String = "", p_place: String = "") -> void:
	holder = p_holder
	subject = p_subject
	place = p_place

	var loop := Engine.get_main_loop()
	var root: Node = loop.root if loop is SceneTree else null
	if root != null:
		_knowledge = root.get_node_or_null("CoreKnowledge")
		_assets = root.get_node_or_null("CoreAssets")
		_standing = root.get_node_or_null("CoreStanding")
		_context = root.get_node_or_null("CoreContext")


## Bind every function into the engine. Call after `load_story()` and before
## `start()`.
##
## Binding a function a story never declares is harmless, so the same bindings
## object serves every story in a game.
func bind_all(engine: Node) -> void:
	for fn_name in FUNCTION_NAMES:
		engine.bind_function(fn_name, self, "_ink_" + fn_name, fn_name in READ_ONLY)


# --- Knowledge ----------------------------------------------------------------

## `knows(id)` — believed firmly enough to act on. A flimsy rumour is false.
func _ink_knows(id: String) -> bool:
	return _knowledge.knows(id, holder)


## `believes(id, min)` — believed at least this much (0..1). Lets a writer
## treat "half-suspects" differently from "is certain".
func _ink_believes(id: String, min_belief: float) -> bool:
	return _knowledge.believes(id, min_belief, holder)


## `heard_of(id)` — encountered at all, however dubious. For flavour only.
func _ink_heard_of(id: String) -> bool:
	return _knowledge.heard_of(id, holder)


## `disbelieves(id)` — has positively established this is a lie.
func _ink_disbelieves(id: String) -> bool:
	return _knowledge.disbelieves(id, holder)


## `learn(id, trust)` — teach the player something. [param trust] is how
## credible the teller is (0..1); a shifty informant should not produce
## certainty. Returns true if this is newly known.
func _ink_learn(id: String, trust = 1.0) -> bool:
	return _knowledge.learn(id, subject, holder, float(trust))


## `forget(id)` — take knowledge away. Rare by design.
func _ink_forget(id: String) -> bool:
	return _knowledge.forget(id, holder)


# --- Assets -------------------------------------------------------------------

## `has_asset(id, amount)` — does the player have at least this many?
func _ink_has_asset(id: String, amount = 1) -> bool:
	return _assets.has(id, int(amount), holder)


## `asset_count(id)` — how many, for display or arithmetic.
func _ink_asset_count(id: String) -> int:
	return _assets.amount(id, holder)


## `give_asset(id, amount)` — hand something over.
func _ink_give_asset(id: String, amount = 1) -> bool:
	return _assets.give(id, int(amount), holder)


## `spend_asset(id, amount)` — pay for something. False (and nothing changes)
## when the player cannot afford it, so it is safe as a transaction guard:
##   { spend_asset("zorkmid", 3): ... -> paid | ... -> too_poor }
func _ink_spend_asset(id: String, amount = 1) -> bool:
	return _assets.spend(id, int(amount), holder)


## `lose_asset(id, amount)` — taken, broken or dropped, with nothing in return.
func _ink_lose_asset(id: String, amount = 1) -> bool:
	return _assets.lose(id, int(amount), holder)


# --- Standing -----------------------------------------------------------------

## `standing(npc)` — raw score. Pass "" to mean the current conversation's NPC.
func _ink_standing(npc = "") -> float:
	return _standing.score(_subject(npc), holder, place)


## `standing_at_least(npc, tier)` — the form gates should use, so retuning the
## numbers does not invalidate the writing. Pass "" for the current NPC.
func _ink_standing_at_least(npc, tier_id: String) -> bool:
	return _standing.at_least(_subject(npc), tier_id, holder, place)


## `adjust_standing(npc, delta)` — the conversation changed how they feel.
func _ink_adjust_standing(npc, delta: float) -> float:
	return _standing.adjust(_subject(npc), float(delta), holder, place)


# --- Stats & flags ------------------------------------------------------------

## `stat(name)` — a player stat, via the engine adapter (0 if unknown).
func _ink_stat(stat_name: String) -> float:
	if _context == null or _context.adapter == null:
		return 0.0
	var stats: CoreStats = _context.adapter.stats_of(holder)
	return stats.get_value(stat_name) if stats != null else 0.0


## `stat_at_least(name, value)` — the common stat check, spelled out.
func _ink_stat_at_least(stat_name: String, value: float) -> bool:
	return _ink_stat(stat_name) >= value


## `flag(name)` — a global progression flag, including prior-conversation
## markers and `quest.<id>.<stage>`.
func _ink_flag(flag_name: String) -> bool:
	return _context.has_flag(flag_name)


## `set_flag(name)` — record that something happened, readable by every later
## conversation in any story file.
func _ink_set_flag(flag_name: String) -> bool:
	_context.set_flag(flag_name, true)
	return true


func _subject(npc) -> String:
	var id := str(npc)
	return id if id != "" else subject
