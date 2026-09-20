## Slack Tide rules, loaded by the game manager via game.json "boot_script".
##
## This is the game-specific layer the shared core deliberately does not own:
## the tide clock, the six-slot day, the wage/board economy, Slack inflation,
## hearsay decay, and the seed's hidden culprit.
##
## Everything here is DETERMINISTIC under CoreContext.rng() - the same seed
## must always produce the same culprit, the same manifests and the same tide
## table, because the seed-testing harness depends on it.
extends Node

const SLOTS := ["dawn_crossing", "morning", "midday_crossing",
				"afternoon", "dusk_crossing", "night"]
const CROSSING_SLOTS := ["dawn_crossing", "midday_crossing", "dusk_crossing"]

const WAGE_PER_DAY := 6
const BOARD_PER_DAY := 2

## Slack inflation: prices climb from day 6, 4% a day, capped at +60%.
const INFLATION_FROM_DAY := 6
const INFLATION_PER_DAY := 0.04
const INFLATION_CAP := 0.60

## Hearsay is perishable. Anything under DECAY_BELOW loses DECAY_PER_DAY
## reliability each day, down to DECAY_FLOOR, unless it is corroborated.
## This is what makes selling early tempting and hoarding expensive.
const DECAY_BELOW := 0.50
const DECAY_PER_DAY := 0.05
const DECAY_FLOOR := 0.10

## One of three culprits is real per seed. Every triad answer naming a
## different culprit is false THIS run and true in another, which is what
## makes the same rumour worth believing on Tuesday and worth debunking on
## Wednesday.
const CULPRITS := ["A", "B", "C"]

## Whose journal and purse this game tracks. The isometric engine addresses
## holders by faction id; Slack Tide has a single protagonist, so there is one.
const HOLDER := "player"

var day: int = 1
var slot_index: int = 0
var culprit: String = "A"
var full_slack_day: int = 14
var _values: Dictionary = {}
var _sales: Dictionary = {}     ## token_id -> times sold (drives spread)


## The isometric engine drives time in turns, and one Slack Tide slot is one
## turn: six slots make a day. Everything below therefore hangs off
## EventBus.turn_started rather than any bespoke clock.
func boot(_gm: Node) -> void:
	_roll_seed()
	_reset_values()
	EventBus.turn_started.connect(_on_turn_started)


# --- Seed ---------------------------------------------------------------------

## Pick this run's hidden truth from the SHARED generator, never a local one.
func _roll_seed() -> void:
	var rng := CoreContext.rng()
	culprit = CULPRITS[rng.randi() % CULPRITS.size()]
	# Full Slack lands between day 12 and 14, so the deadline is not memorised.
	full_slack_day = 12 + (rng.randi() % 3)
	# Published as a flag so dialogue and validators can read the seed's truth
	# through the ordinary query grammar, with no bespoke API.
	CoreContext.set_flag("culprit_" + culprit.to_lower())


## True when a token's `truth` field agrees with this seed.
func is_token_true(token: Dictionary) -> bool:
	var truth := str(token.get("truth", "always"))
	if truth == "always":
		return true
	if truth.begins_with("culprit="):
		return truth.substr(8) == culprit
	if truth.begins_with("culprit!="):
		return truth.substr(9) != culprit
	return true


# --- The clock ----------------------------------------------------------------

func current_slot() -> String:
	return SLOTS[slot_index]


func is_crossing() -> bool:
	return current_slot() in CROSSING_SLOTS


## Slack lengthens by roughly an hour a day until it swallows the day entirely.
func slack_hours() -> float:
	return minf(6.0 + float(day) * 0.45, 24.0)


func is_full_slack() -> bool:
	return day >= full_slack_day


## One turn is one slot. Derives day and slot from the engine's turn counter
## rather than keeping a parallel clock that could drift out of step with saves.
func _on_turn_started(turn: int) -> void:
	slot_index = turn % SLOTS.size()
	var new_day := (turn / SLOTS.size()) + 1
	if new_day != day:
		day = new_day
		_on_day_advanced(day)
	if current_slot() == "night" and not GameManager.has_flag("barred_tonight"):
		EventBus.notification.emit(
			"The shift ends. The Low Lantern will be open.", "room")


# --- Economy ------------------------------------------------------------------

## Wages land at dusk, board is taken at night. Quitting the ferry ends both,
## which is the point: Act II has to be paid for out of Act I.
func _on_day_advanced(new_day: int) -> void:
	if not GameManager.has_flag("quit_ferry"):
		CoreAssets.give("tally", WAGE_PER_DAY, HOLDER)
		EventBus.notification.emit(
			"Hesper counts out six tallies without looking up.", "economy")
	CoreAssets.spend("tally", BOARD_PER_DAY, HOLDER)
	_decay_hearsay()

	if new_day == full_slack_day - 2:
		EventBus.notification.emit(
			"The tide-post has not moved since yesterday morning. "
			+ "Hesper looks at it for a long time and says nothing.", "warning")
	if is_full_slack():
		_begin_full_slack()


## Prices rise the longer the Slack lasts. Buy early or pay more.
func price_multiplier() -> float:
	if day < INFLATION_FROM_DAY:
		return 1.0
	var days_over := day - INFLATION_FROM_DAY + 1
	return 1.0 + minf(float(days_over) * INFLATION_PER_DAY, INFLATION_CAP)


func adjusted_price(base_price: int) -> int:
	return int(ceil(float(base_price) * price_multiplier()))


# --- Information --------------------------------------------------------------

## What a buyer pays: category base x reliability x scarcity x inflation.
## Hearsay under half-certain sells for half, and every previous sale of the
## same token drops the price - information is worth less once it is weather.
func intel_price(token_id: String, base_value: int) -> int:
	var journal := CoreIntel.journal_for(HOLDER)
	if journal == null:
		return 0
	var token := journal.get_token(token_id)
	if token == null or token.known_false:
		return 0
	var price := float(base_value) * token.reliability
	if token.reliability < 0.5:
		price *= 0.5
	price *= maxf(0.1, 1.0 - float(_sales.get(token_id, 0)) * 0.18)
	price *= price_multiplier()
	return int(round(price))


## Record a sale, so the next buyer of the same token pays less.
func record_sale(token_id: String) -> void:
	_sales[token_id] = int(_sales.get(token_id, 0)) + 1


## Perishable hearsay. Corroborated tokens are exempt - that is the reward for
## finding a second independent source instead of trusting the tavern.
func _decay_hearsay() -> void:
	var journal := CoreIntel.journal_for(HOLDER)
	if journal == null:
		return
	for token in journal.tokens.values():
		# More than one provenance entry means an independent second source
		# corroborated it, which is exactly what decay is meant to reward.
		if token.provenance.size() > 1:
			continue
		if token.reliability < DECAY_BELOW and token.reliability > DECAY_FLOOR:
			token.reliability = maxf(
				DECAY_FLOOR, token.reliability - DECAY_PER_DAY)


# --- Values -------------------------------------------------------------------

## Eight values, 0-10, starting at 3. Old NPCs give their gift only to people
## whose conduct already matches them, so gifts cannot be farmed: by the time
## you know a gift exists, the conduct that earns it is mostly behind you.
func _reset_values() -> void:
	for v in ["candor", "mercy", "fairness", "nerve",
			  "patience", "fidelity", "curiosity", "restraint"]:
		_values[v] = 3


func value_of(id: String) -> int:
	return int(_values.get(id, 0))


func adjust_value(id: String, delta: int) -> void:
	if not _values.has(id):
		return
	var before: int = _values[id]
	_values[id] = clampi(before + delta, 0, 10)
	if _values[id] != before:
		# No bespoke signal: values ride the engine's own notification channel,
		# so the status window picks them up with no extra wiring.
		EventBus.notification.emit(
			"%s %s (%d)" % [id.capitalize(),
				"rises" if delta > 0 else "falls", _values[id]], "value")


# --- Act III ------------------------------------------------------------------

func _begin_full_slack() -> void:
	if GameManager.has_flag("full_slack_begun"):
		return
	GameManager.set_flag("full_slack_begun", true)
	EventBus.notification.emit(
		"The tide does not turn. Not at dawn, not at midday. The Patience "
		+ "stays at her berth with her engine cold, and for the first time "
		+ "in forty years Hesper has nothing to do.", "act")
