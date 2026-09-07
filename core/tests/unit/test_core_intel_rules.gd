## Tests for intel exchange: derivation, spread between holders, trade, and
## contradiction. The rule set below is the real one from
## example_realm_iso/intel_rules.json — if these pass, the port is faithful.
extends GutTest

class SpyAdapter extends CoreEngineAdapter:
	var holders: Array[String] = []
	var relations: Dictionary = {}

	func _init() -> void:
		engine_id = "spy"

	func all_holders() -> Array[String]:
		return holders

	func related_holders(holder: String, relation: String) -> Array[String]:
		var out: Array[String] = []
		for h in relations.get("%s|%s" % [holder, relation], []):
			out.append(str(h))
		return out


## Verbatim from example_realm_iso/intel_rules.json.
const RULES := {
	"derivations": [
		{"id": "triangulate_crypt",
		 "when": {"all": [
			{"has": "rumor_crypt_west", "min_reliability": 0.5},
			{"has": "rumor_crypt_reeds", "min_reliability": 0.5},
			{"has": "ruin_inscription"}]},
		 "grant": "crypt_location", "reliability": 0.65, "once": true},
		{"id": "rival_interest",
		 "when": {"all": [{"has": "seen_scouts_abroad"}, {"has": "rumor_crypt_west"}]},
		 "grant": "greywood_knows_crypt_west", "reliability": 0.5, "once": true},
	],
	# chance is raised to 2.0 here (the shipped values are 0.15/0.25) purely so
	# the probabilistic gate always passes and the *routing* logic is what these
	# tests measure. The effective roll is chance * (1 - secrecy), matching the
	# reference implementation.
	"spread": [
		{"id": "trade_gossip", "channel": "spread", "between": "trade_partners",
		 "chance": 2.0, "max_secrecy": 0.35, "reliability_loss": 0.2,
		 "categories": ["rumor", "economic", "location"]},
		{"id": "border_chatter", "channel": "spread", "between": "neighbors",
		 "chance": 2.0, "max_secrecy": 0.3, "reliability_loss": 0.1,
		 "categories": ["military"]},
	],
	"contradiction": {"dispute_amount": 0.15, "flag_source_trust_loss": 0.25},
	"observation": {"unit_sight_reveals_tokens": true},
}

const INTEL := [
	{"id": "rumor_crypt_west", "subject": "crypt", "category": "rumor",
	 "reliability": 0.35, "corroboration_step": 0.3, "secrecy": 0.1, "value": 15},
	{"id": "rumor_crypt_reeds", "subject": "crypt", "category": "rumor",
	 "reliability": 0.5, "secrecy": 0.3, "value": 20},
	{"id": "ruin_inscription", "subject": "ruins", "category": "lore",
	 "reliability": 0.7, "secrecy": 0.2, "value": 12},
	{"id": "crypt_location", "subject": "crypt", "category": "location",
	 "reliability": 0.8, "secrecy": 0.6, "value": 60},
	{"id": "seen_scouts_abroad", "subject": "world", "category": "military",
	 "reliability": 0.8, "secrecy": 0.1, "decay_turns": 6, "value": 5},
	{"id": "greywood_knows_crypt_west", "subject": "crypt", "category": "military",
	 "reliability": 0.5, "secrecy": 0.5, "value": 10},
	{"id": "schedule_ossuary_guard", "subject": "warden", "category": "schedule",
	 "reliability": 0.5, "secrecy": 0.7, "decay_turns": 12, "value": 30,
	 "conflicts": ["schedule_ossuary_guard_false"]},
	{"id": "schedule_ossuary_guard_false", "subject": "warden", "category": "rumor",
	 "reliability": 0.2, "secrecy": 0.1, "value": 5,
	 "conflicts": ["schedule_ossuary_guard"]},
	{"id": "warden_true_schedule", "subject": "warden", "category": "fact",
	 "reliability": 1.0, "secrecy": 0.8, "value": 40, "spreadable": false},
]

var spy: SpyAdapter


func before_each() -> void:
	CoreRegistry.clear()
	for d in INTEL:
		CoreRegistry.add("intel", CoreDefinition.build(CoreIntelToken, d))
	CoreIntel.reset()
	CoreContext.reset()
	spy = SpyAdapter.new()
	spy.holders = ["blue", "greywood", "wilds"]
	CoreContext.install(spy)
	CoreContext.configure({"seed": 99})
	CoreIntel.rules.load_from(RULES)


# --- Derivation: inferring what nobody told you --------------------------------------

func test_triangulation_derives_a_location_from_three_weaker_sources() -> void:
	watch_signals(CoreIntel.rules)
	# A rumour heard once (0.35) is below the rule's 0.5 threshold; hearing it
	# from a second, independent source is what makes it credible.
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	CoreIntel.acquire("blue", "rumor_crypt_west", "innkeeper", "told", 1.0)
	assert_false(CoreIntel.knows("blue", "crypt_location"))
	CoreIntel.acquire("blue", "rumor_crypt_reeds", "smuggler", "told", 1.0)
	assert_false(CoreIntel.knows("blue", "crypt_location"))

	# The inscription completes the set -> derivation fires automatically.
	CoreIntel.acquire("blue", "ruin_inscription", "standing_stones", "read", 1.0)
	assert_true(CoreIntel.knows("blue", "crypt_location"),
		"three independent clues locate the crypt without buying the chart")

	var tok := CoreIntel.journal_for("blue").get_token("crypt_location")
	assert_almost_eq(tok.reliability, 0.65, 0.001, "derivation asserts its own confidence")
	assert_eq(tok.provenance[0].channel, "derived")
	assert_signal_emitted(CoreIntel.rules, "derived")


func test_derivation_respects_min_reliability_in_its_condition() -> void:
	# rumor_crypt_west is authored at 0.35 and the rule needs >= 0.5, so a
	# single telling is never enough however much the source is trusted.
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	CoreIntel.acquire("blue", "rumor_crypt_reeds", "smuggler", "told", 1.0)
	CoreIntel.acquire("blue", "ruin_inscription", "stones", "read", 1.0)
	assert_lt(CoreIntel.journal_for("blue").get_token("rumor_crypt_west").reliability, 0.5)
	assert_false(CoreIntel.knows("blue", "crypt_location"),
		"a weakly-believed rumour does not complete the triangulation")

	# A second, independent source corroborates it over the threshold.
	CoreIntel.acquire("blue", "rumor_crypt_west", "innkeeper", "told", 1.0)
	assert_gte(CoreIntel.journal_for("blue").get_token("rumor_crypt_west").reliability, 0.5)
	assert_true(CoreIntel.knows("blue", "crypt_location"),
		"corroboration completes the triangulation")


func test_derivation_is_once_per_holder_and_independent_between_holders() -> void:
	for h in ["blue", "greywood"]:
		CoreIntel.acquire(h, "rumor_crypt_west", "drunk", "told", 1.0)
		CoreIntel.acquire(h, "rumor_crypt_west", "innkeeper", "told", 1.0)
		CoreIntel.acquire(h, "rumor_crypt_reeds", "smuggler", "told", 1.0)
		CoreIntel.acquire(h, "ruin_inscription", "stones", "read", 1.0)
	assert_true(CoreIntel.knows("blue", "crypt_location"))
	assert_true(CoreIntel.knows("greywood", "crypt_location"))

	# Re-running finds nothing new.
	assert_eq(CoreIntel.rules.run_derivations("blue").size(), 0)


func test_second_derivation_rule_infers_rival_intent() -> void:
	CoreIntel.acquire("blue", "seen_scouts_abroad", "watchtower", "observed", 1.0)
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	assert_true(CoreIntel.knows("blue", "greywood_knows_crypt_west"),
		"scouts near the mill + the rumour implies a rival is hunting the crypt")


# --- Spread: knowledge leaking between holders ------------------------------------------

func test_spread_moves_low_secrecy_intel_to_trade_partners() -> void:
	spy.relations["blue|trade_partners"] = ["greywood"]
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	watch_signals(CoreIntel.rules)

	assert_gt(CoreIntel.rules.run_spread(), 0)
	assert_true(CoreIntel.knows("greywood", "rumor_crypt_west"))
	assert_signal_emitted(CoreIntel.rules, "spread_occurred")


func test_spread_degrades_reliability_and_records_the_middleman() -> void:
	spy.relations["blue|trade_partners"] = ["greywood"]
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	var source_rel := CoreIntel.journal_for("blue").get_token("rumor_crypt_west").reliability
	CoreIntel.rules.run_spread()

	var got := CoreIntel.journal_for("greywood").get_token("rumor_crypt_west")
	assert_almost_eq(got.reliability, source_rel - 0.2, 0.001, "second-hand info is trusted less")
	assert_eq(got.provenance[0].channel, "spread")
	assert_eq(got.provenance[0].via_holder, "blue", "chain of custody is recorded")


func test_spread_respects_max_secrecy() -> void:
	spy.relations["blue|trade_partners"] = ["greywood"]
	# crypt_location has secrecy 0.6, above trade_gossip's 0.35 ceiling.
	CoreIntel.acquire("blue", "crypt_location", "sage", "told", 1.0)
	CoreIntel.rules.run_spread()
	assert_false(CoreIntel.knows("greywood", "crypt_location"),
		"closely-held secrets do not leak through idle gossip")


func test_spread_respects_category_filters() -> void:
	spy.relations["blue|neighbors"] = ["greywood"]
	# border_chatter carries "military" only; ruin_inscription is "lore".
	CoreIntel.acquire("blue", "ruin_inscription", "stones", "read", 1.0)
	CoreIntel.acquire("blue", "seen_scouts_abroad", "tower", "observed", 1.0)
	CoreIntel.rules.run_spread()
	assert_true(CoreIntel.knows("greywood", "seen_scouts_abroad"), "military spreads")
	assert_false(CoreIntel.knows("greywood", "ruin_inscription"), "lore does not")


func test_unspreadable_intel_never_leaks() -> void:
	spy.relations["blue|trade_partners"] = ["greywood"]
	CoreIntel.acquire("blue", "warden_true_schedule", "insider", "observed", 1.0)
	CoreIntel.rules.run_spread()
	assert_false(CoreIntel.knows("greywood", "warden_true_schedule"))


func test_spread_is_deterministic_for_a_given_seed() -> void:
	spy.relations["blue|trade_partners"] = ["greywood"]
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	var first := CoreIntel.rules.run_spread()

	CoreIntel.reset()
	CoreIntel.rules.load_from(RULES)
	CoreContext.configure({"seed": 99})
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	assert_eq(CoreIntel.rules.run_spread(), first, "same seed, same outcome")


# --- Contradiction & lies ----------------------------------------------------------------

func test_conflicting_schedules_dispute_each_other() -> void:
	CoreIntel.acquire("blue", "schedule_ossuary_guard", "insider", "told", 1.0)
	var truth := CoreIntel.journal_for("blue").get_token("schedule_ossuary_guard")
	var before := truth.reliability

	watch_signals(CoreIntel)
	CoreIntel.acquire("blue", "schedule_ossuary_guard_false", "liar", "told", 1.0)
	assert_signal_emitted(CoreIntel, "contradiction_found")
	# dispute_amount 0.15 is applied to both sides.
	assert_almost_eq(truth.reliability, before - 0.15, 0.001,
		"holding both accounts weakens confidence in each")
	assert_eq(CoreIntel.journal_for("blue").contradictions().size(), 1)


func test_debunking_a_lie_discredits_its_source() -> void:
	CoreIntel.acquire("blue", "schedule_ossuary_guard_false", "tavern_drunk", "told", 1.0)
	CoreIntel.acquire("blue", "rumor_crypt_west", "tavern_drunk", "told", 1.0)
	var other := CoreIntel.journal_for("blue").get_token("rumor_crypt_west")
	var before := other.reliability

	CoreIntel.debunk("blue", "schedule_ossuary_guard_false")
	assert_false(CoreIntel.knows("blue", "schedule_ossuary_guard_false"))
	assert_almost_eq(other.reliability, before - CoreIntel.LIAR_PENALTY, 0.001,
		"everything else that liar said is now doubted")


# --- Deliberate exchange -------------------------------------------------------------------

func test_trade_prices_intel_by_belief() -> void:
	CoreIntel.acquire("blue", "crypt_location", "sage", "told", 1.0)
	CoreIntel.journal_for("blue").get_token("crypt_location").reliability = 0.5
	assert_eq(CoreIntel.trade("blue", "greywood", "crypt_location"), 30, "60 * 0.5")
	assert_true(CoreIntel.knows("greywood", "crypt_location"))


func test_give_bypasses_secrecy_because_the_holder_chose_to_tell() -> void:
	# crypt_location is too secret to leak via spread, but can be handed over.
	CoreIntel.acquire("blue", "crypt_location", "sage", "told", 1.0)
	assert_true(CoreIntel.give("blue", "greywood", "crypt_location"))
	assert_true(CoreIntel.knows("greywood", "crypt_location"))


func test_a_known_lie_cannot_be_traded_or_given() -> void:
	CoreIntel.acquire("blue", "schedule_ossuary_guard_false", "liar", "told", 1.0)
	CoreIntel.debunk("blue", "schedule_ossuary_guard_false")
	assert_eq(CoreIntel.trade("blue", "greywood", "schedule_ossuary_guard_false"), -1)
	assert_false(CoreIntel.give("blue", "greywood", "schedule_ossuary_guard_false"))


# --- The per-turn step ------------------------------------------------------------------------

func test_tick_derives_spreads_and_expires_in_one_call() -> void:
	spy.relations["blue|trade_partners"] = ["greywood"]
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	CoreIntel.acquire("blue", "rumor_crypt_reeds", "smuggler", "told", 1.0)

	var result := CoreIntel.tick()
	assert_true(result.has("derived") and result.has("spread") and result.has("expired"))
	assert_gt(result["spread"], 0, "rumours reached the trade partner")


func test_rules_state_survives_save_and_load() -> void:
	CoreIntel.acquire("blue", "seen_scouts_abroad", "tower", "observed", 1.0)
	CoreIntel.acquire("blue", "rumor_crypt_west", "drunk", "told", 1.0)
	assert_true(CoreIntel.knows("blue", "greywood_knows_crypt_west"))

	var saved := CoreIntel.rules.to_save_data()
	var fresh := CoreIntelRules.new()
	fresh.load_from(RULES)
	fresh.from_save_data(saved)
	assert_eq(fresh.run_derivations("blue").size(), 0,
		"a once-only derivation does not fire twice after loading")
