## Slack Tide's session driver: the actual game loop.
##
## Everything else in this package is data or presentation. This is the part
## that plays: where you are, who is standing there, what a slot costs, what
## asking someone a question does to your journal, and which ending you get.
##
##   maps.json          -> where you can go, and when (`requires_slot`)
##   topics.json        -> what each person will discuss, and how (`mode`)
##   intel.json         -> what a token is worth and whether it is true
##   slack_tide_boot.gd -> the tide clock, economy, decay, culprit
##   slack_tide_ui.gd   -> the five windows
##
## Deliberately headless-capable: nothing here needs a viewport, so the
## `--sim` harness can play thousands of runs with no renderer. That is what
## lets the engine be cross-checked against `tools/model.py`.
extends Node

signal location_changed(map_id: String)
signal token_learned(token_id: String, method: String, source: String)
signal run_ended(outcome: String, won: bool)

const HOLDER := "player"

## Reliability a method delivers, mirroring the spec. The engine stores 0..1.
const METHOD_RELIABILITY := {
	"overheard": 0.30, "told": 0.55, "slip": 0.55, "sold": 0.60,
	"document": 0.70, "found": 0.70, "witnessed": 0.90,
}

## A rumour mill carries every answer, but never above this.
const RUMOR_CAP := 0.25

var maps: Dictionary = {}          ## map_id -> map definition
var topics: Dictionary = {}        ## topic_id -> topic definition
var actors_at: Dictionary = {}     ## map_id -> Array[actor_id]

var current_map: String = ""
var visited: Dictionary = {}
## "npc:topic" -> true. A source is independent ONCE; corroboration has to be
## earned from a *different* mouth, which is the core loop.
var asked: Dictionary = {}
var ended: bool = false
var outcome: String = ""

var _boot: Node
var _ui: Node


func setup(boot: Node, ui: Node = null) -> void:
	_boot = boot
	_ui = ui
	_load_data()
	var start := str(GameManager.game_config.get("start_map", "sorrel_landing"))
	go_to(start, true)


# --- Data ---------------------------------------------------------------------

func _load_data() -> void:
	var base := GameManager.package_path(GameManager.game_id)
	var map_doc: Dictionary = CoreDataLoader.load_json(base.path_join("maps.json"))
	for m in map_doc.get("maps", []):
		maps[str(m.get("id", ""))] = m
	var topic_doc: Dictionary = CoreDataLoader.load_json(base.path_join("topics.json"))
	topics = topic_doc.get("topics", {})

	# Index actors by where they stand, so a location knows who is in it
	# without every caller re-scanning the cast.
	var actor_doc: Dictionary = CoreDataLoader.load_json(base.path_join("actors.json"))
	for a in actor_doc.get("actors", []):
		var loc := str(a.get("location", ""))
		if loc == "" or str(a.get("role", "")) == "player":
			continue
		if not actors_at.has(loc):
			actors_at[loc] = []
		actors_at[loc].append(str(a.get("id", "")))


# --- Movement -----------------------------------------------------------------

## Links usable *right now*. `requires_slot` is why the world feels tidal: the
## ferry only runs on a crossing, the Low Lantern only opens at night. Time is
## a key, not just a budget.
func available_exits() -> Array:
	var out: Array = []
	var here: Dictionary = maps.get(current_map, {})
	for link in here.get("links", []):
		var need := str(link.get("requires_slot", ""))
		if need != "" and not _slot_allows(need):
			continue
		out.append(link)
	return out


func _slot_allows(requirement: String) -> bool:
	if _boot == null:
		return true
	if requirement == "crossing":
		return _boot.is_crossing()
	return _boot.current_slot() == requirement


func go_to(map_id: String, force: bool = false) -> bool:
	if not maps.has(map_id):
		push_warning("slack_tide: no such location '%s'" % map_id)
		return false
	if not force:
		var ok := false
		for link in available_exits():
			if str(link.get("to", "")) == map_id:
				ok = true
				break
		if not ok:
			return false
	current_map = map_id
	visited[map_id] = true
	location_changed.emit(map_id)
	_present()
	return true


## Who is standing here to be talked to.
func actors_here() -> Array:
	return actors_at.get(current_map, [])


## Advance one slot (dawn/morning/midday/afternoon/dusk/night). Six calls make
## a day: wages land, board is spent, hearsay decays, the Slack Index moves.
##
## Nothing else drives this for a narrative package -- `TurnManager` only
## turns the crank when there are factions to activate, and Slack Tide has
## none. Without this call the tide clock never moves at all: wages never
## land and priced tokens (Ottoline, Wimble) never become affordable. The
## player presses "end the slot" (a UI button, or the ferry departing on a
## crossing); this is the one function that stands behind it.
func advance_slot() -> void:
	GameClock.advance_turn()
	EventBus.turn_started.emit(GameClock.turn)


## Topics this person will discuss at all.
func topics_for(npc: String) -> Array:
	var out: Array = []
	for tid in topics:
		if topics[tid].get("stances", {}).has(npc):
			out.append(tid)
	return out


# --- Knowledge ----------------------------------------------------------------

## Ask someone about a topic. This is the whole game in one function.
##
## What you get depends on their stance:
##   explain -- they tell you the seed-true answer at their method's weight
##   rumor   -- they give you EVERY answer, capped low. Not lying: hedging.
##   price   -- they will sell, not tell (see `buy`)
##   flinch  -- they deny it; a held token at reliability makes them slip
##
## Asking the same person twice teaches nothing new. Corroboration must come
## from a second, independent mouth.
func ask(npc: String, topic_id: String) -> Array:
	var learned: Array = []
	var topic: Dictionary = topics.get(topic_id, {})
	var stance: Dictionary = topic.get("stances", {}).get(npc, {})
	if stance.is_empty():
		return learned

	var key := npc + ":" + topic_id
	if asked.has(key):
		return learned
	asked[key] = true

	match str(stance.get("mode", "explain")):
		"explain":
			var method := str(stance.get("method", "told"))
			for tid in stance.get("grants", []):
				if _is_true(str(tid)) and _learn(str(tid), method, npc):
					learned.append(tid)
		"rumor":
			# Every version, at gossip weight. This is where false belief is
			# born, and why the player learns to want a second source.
			for tid in stance.get("grants", []):
				if _learn(str(tid), "overheard", npc, RUMOR_CAP):
					learned.append(tid)
		"flinch":
			for tid in stance.get("grants", []):
				if _is_true(str(tid)) and _learn(str(tid), "slip", npc):
					learned.append(tid)
	return learned


## Buy a token from a broker. Costs money, arrives at `sold` weight.
func buy(npc: String, topic_id: String) -> Array:
	var learned: Array = []
	var stance: Dictionary = topics.get(topic_id, {}).get("stances", {}).get(npc, {})
	if not str(stance.get("mode", "")) in ["price", "sell"]:
		return learned
	var price := int(stance.get("price", 8))
	if _boot != null:
		price = _boot.adjusted_price(price)
	if CoreAssets.amount("tally", HOLDER) < price:
		return learned
	CoreAssets.spend("tally", price, HOLDER)
	for tid in stance.get("buys", stance.get("grants", [])):
		if _is_true(str(tid)) and _learn(str(tid), "sold", npc):
			learned.append(tid)
	return learned


## The player SELLING a token to someone (the information market side, e.g.
## Ottoline buying from the player rather than the reverse). Distinct from
## `buy`, which is the player paying to learn -- this is the player paid to
## tell, which is what puts a token into the Ledger.
func sell_to_market(token_id: String, base_value: int) -> int:
	if _boot == null or not knows(str(token_id), 0.0):
		return 0
	var price: int = _boot.intel_price(token_id, base_value)
	if price <= 0:
		return 0
	CoreAssets.give("tally", price, HOLDER)
	sell(token_id)
	return price


# --- The Ledger of What You Said -----------------------------------------------
##
## `_sales`/`record_sale` already exist in slack_tide_boot.gd and are purely
## economic (price decay per sale). This is the narrative half: what you sell
## enters the world's mouth. From SPREAD_DELAY days after a sale, the token
## surfaces as common knowledge -- FALSE ones included -- so the market is a
## moral system, not a shop. Selling a lie for coin on day 4 can mean an NPC
## repeats it to you as established fact on day 12, with your name on it.
const SPREAD_DELAY := 3

var _sale_log: Array = []    ## [{token, day, culprit_true}]


## Record a sale for both the economic model (slack_tide_boot.gd) and this
## ledger. Call this whenever a token changes hands for coin.
func sell(token_id: String) -> void:
	if _boot == null:
		return
	_boot.record_sale(token_id)
	_sale_log.append({
		"token": token_id,
		"day": _boot.day,
		"true": _is_true(token_id),
	})


## Tokens that have "gone to weather": sold long enough ago that the town
## now repeats them regardless of what the player still believes.
func spread_tokens() -> Array:
	if _boot == null:
		return []
	var out: Array = []
	for entry in _sale_log:
		if _boot.day - int(entry["day"]) >= SPREAD_DELAY:
			out.append(entry["token"])
	return out


## Does the town now say this, whether or not it is true? This is what an
## NPC (or the Assize) checks before repeating a rumour that started as a
## deliberate sale rather than organic gossip.
func is_common_knowledge(token_id: String) -> bool:
	return token_id in spread_tokens()


## A line for the journal/status window: how many of the player's OWN sales
## are currently false claims loose in the world. Zero is a clean conscience;
## a positive number is a debt that can surface at the worst possible time.
func loose_falsehoods() -> int:
	var n := 0
	for entry in _sale_log:
		if _boot != null and _boot.day - int(entry["day"]) >= SPREAD_DELAY \
				and not bool(entry["true"]):
			n += 1
	return n


## Does this token agree with the seed's hidden truth?
func _is_true(token_id: String) -> bool:
	if _boot == null or not _boot.has_method("is_token_true"):
		return true
	var def := CoreRegistry.get_def("intel", token_id)
	if def == null:
		return true
	return _boot.is_token_true({"truth": _fact(def, "truth", "always")})


## `truth` isn't a field CoreIntelToken's schema names, so it rides in `raw`
## (the untouched source JSON) and is read back via CoreDefinition.extra().
func _fact(def, key: String, fallback: String = "") -> String:
	if def == null:
		return fallback
	return str(def.extra(key, fallback))


func _learn(token_id: String, method: String, source: String,
		cap: float = 1.0) -> bool:
	if CoreRegistry.get_def("intel", token_id) == null:
		return false
	var before := reliability_of(token_id)
	CoreIntel.acquire(HOLDER, token_id, source, method)
	# This game's 0-100 model sits on top of core acquisition: a rumour mill
	# can never push a token past the gossip cap however often it repeats,
	# and a genuine second source is worth +20 to a ceiling of 95.
	var journal := CoreIntel.journal_for(HOLDER)
	if journal != null:
		var token := journal.get_token(token_id)
		if token != null:
			var target: float = minf(METHOD_RELIABILITY.get(method, 0.3), cap)
			if token.provenance.size() > 1:
				target = minf(0.95, maxf(before + 0.20, target))
			token.reliability = maxf(before, target)
	var after := reliability_of(token_id)
	if after > before:
		token_learned.emit(token_id, method, source)
		return true
	return false


func reliability_of(token_id: String) -> float:
	var journal := CoreIntel.journal_for(HOLDER)
	if journal == null:
		return 0.0
	var token := journal.get_token(token_id)
	return token.reliability if token != null else 0.0


func knows(token_id: String, floor_value: float = 0.75) -> bool:
	return reliability_of(token_id) >= floor_value


# --- Presentation -------------------------------------------------------------

func _present() -> void:
	if _ui == null:
		return
	var here: Dictionary = maps.get(current_map, {})
	_ui.set_scene("scene." + current_map, str(here.get("display_name", "")))
	_ui.say(str(here.get("description", "")))
	_ui.refresh()


# --- Endings ------------------------------------------------------------------

## Two axes: did the tide turn, and did you know why.
##
## Turning the tide while acting on a falsehood is a mechanical WIN and a
## narrative indictment -- that is the range this game is for. Understanding
## the cause and failing anyway is a loss that reads as grace.
const ENDINGS := {
	# [turned, understood] -> id and the line it is remembered by
	"long_way_home": "You were right, and it cost what being right costs.",
	"cold_answer": "The tide turned. You never learned whose hand it was, "
		+ "and the town thanked you for it.",
	"standing_water": "You understood it entirely, and the water stayed "
		+ "where it was.",
	"full_slack": "The tide does not turn. Nobody learns why.",
}


## Did the player hold the seed-true case at a reliability they could act on?
func understood(culprit: String) -> bool:
	var true_case: Array = []
	var held := 0
	for tid in CoreRegistry.ids("intel"):
		var def := CoreRegistry.get_def("intel", str(tid))
		if def == null or def.category != "case":
			continue
		if _fact(def, "truth", "always") != "culprit=" + culprit:
			continue
		true_case.append(tid)
		if knows(str(tid)):
			held += 1
	if true_case.is_empty():
		return false
	return held >= maxi(1, true_case.size() / 2)


func finish(turned: bool) -> String:
	if ended:
		return outcome
	ended = true
	var culprit := str(_boot.culprit) if _boot != null else "A"
	var knew := understood(culprit)
	if turned:
		outcome = "long_way_home" if knew else "cold_answer"
	else:
		outcome = "standing_water" if knew else "full_slack"
	if _ui != null:
		_ui.say(str(ENDINGS.get(outcome, "")))
		_ui.say(str(reckoning_text(str(_boot.culprit) if _boot else "A")))
	run_ended.emit(outcome, turned)
	return outcome


# --- The Reckoning --------------------------------------------------------
##
## Four axes that cannot all be maxed in one run -- selling secrets earns
## Purse and costs Truth. That tension is the replay hook. Mirrors
## tools/model.py's `reckoning()` so a Godot run and a Python sweep produce
## comparable numbers.
func reckoning(culprit: String) -> Dictionary:
	var true_case: Array = []
	for tid in CoreRegistry.ids("intel"):
		var def := CoreRegistry.get_def("intel", str(tid))
		if def != null and def.category == "case" \
				and _fact(def, "truth", "always") == "culprit=" + culprit:
			true_case.append(tid)
	var truth := 0.0
	if not true_case.is_empty():
		var total := 0.0
		for tid in true_case:
			total += reliability_of(str(tid))
		truth = 100.0 * total / float(true_case.size())

	var conduct := 0.0
	var mercy := 0.0
	if _boot != null:
		var values := ["candor", "mercy", "fairness", "nerve", "patience",
					   "fidelity", "curiosity", "restraint"]
		var sum_v := 0
		for v in values:
			sum_v += _boot.value_of(v)
		conduct = 100.0 * float(sum_v) / float(10 * values.size())
		mercy = 100.0 * float(_boot.value_of("mercy")) / 10.0

	var purse := minf(100.0, float(CoreAssets.amount("tally", HOLDER)) / 3.0)

	return {"truth": roundi(truth), "conduct": roundi(conduct),
			"purse": roundi(purse), "mercy": roundi(mercy),
			"loose_falsehoods": loose_falsehoods()}


## The human-readable version, printed at the end of a run.
func reckoning_text(culprit: String) -> String:
	var r := reckoning(culprit)
	var lines := ["", "THE RECKONING",
		"  Truth        %3d/100" % r["truth"],
		"  Conduct      %3d/100" % r["conduct"],
		"  Purse        %3d/100" % r["purse"],
		"  Mercy        %3d/100" % r["mercy"]]
	if int(r["loose_falsehoods"]) > 0:
		lines.append("  Loose lies   %d -- sold, false, and still out there"
			% r["loose_falsehoods"])
	return "\n".join(lines)


## Can any road be walked THIS turn, and which is cheapest? Reads the same
## `roads`/`entry_methods` shape as `tools/model.py`'s `_road_ok`, so the two
## can be cross-checked seed for seed (see test_slack_tide_sim.gd).
func road_available(spec: Dictionary, culprit: String) -> String:
	var roads: Dictionary = spec.get("roads", {})
	for road_name in ["word", "bargain", "hand"]:
		var r: Dictionary = roads.get(road_name, {}).get(culprit, {})
		if r.is_empty():
			continue
		if _road_ok(r):
			return road_name
	return ""


func _road_ok(r: Dictionary) -> bool:
	var floor_value := float(r.get("min_reliability", 75)) / 100.0
	for tid in r.get("tokens", []):
		if reliability_of(str(tid)) < floor_value:
			return false
	for vname in r.get("values", {}):
		if _boot == null or _boot.value_of(str(vname)) < int(r["values"][vname]):
			return false
	return true    # affordability is checked by the caller against tallies


func entry_available(spec: Dictionary, culprit: String) -> bool:
	for name in spec.get("entry_methods", {}):
		var e: Dictionary = spec["entry_methods"][name]
		if not str(culprit) in str(e.get("seeds", "")):
			continue
		var ok := true
		for tid in e.get("tokens", []):
			if reliability_of(str(tid)) < 0.55:
				ok = false
				break
		if ok:
			return true
	return false
