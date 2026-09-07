## Tests for the shared intel platform: acquisition, corroboration, decay,
## provenance, contradiction, debunking, spread/trade, and the query language.
## Runs headless with the default CoreEngineAdapter (no graphics engine).
extends GutTest

const INTEL := [
	{"id": "crypt_location", "title": "The Sunken Crypt", "subject": "crypt",
	 "scope": "site", "category": "location", "reliability": 0.4,
	 "corroboration_step": 0.3, "decay_turns": 10, "value": 100, "secrecy": 0.0,
	 "conflicts": ["crypt_is_myth"], "facts": {"map": "crypt"}, "tags": ["location"]},
	{"id": "crypt_is_myth", "subject": "crypt", "reliability": 0.9, "secrecy": 0.0,
	 "conflicts": ["crypt_location"]},
	{"id": "state_secret", "subject": "crown", "category": "secret",
	 "reliability": 1.0, "secrecy": 1.0, "spreadable": true, "tradeable": false},
]

var _adapter: CoreEngineAdapter


func before_each() -> void:
	CoreRegistry.clear()
	for d in INTEL:
		CoreRegistry.add("intel", CoreDefinition.build(CoreIntelToken, d))
	CoreIntel.reset()
	CoreContext.reset()
	_adapter = CoreEngineAdapter.new()
	CoreContext.install(_adapter)
	CoreContext.configure({"seed": 12345})


# --- Acquisition & corroboration ------------------------------------------------

func test_acquire_creates_independent_journal_instances() -> void:
	assert_true(CoreIntel.acquire("blue", "crypt_location", "scout", "observed"))
	assert_true(CoreIntel.acquire("red", "crypt_location", "spy", "stolen"))

	var blue := CoreIntel.journal_for("blue").get_token("crypt_location")
	var red := CoreIntel.journal_for("red").get_token("crypt_location")
	blue.dispute(0.4)
	assert_ne(blue.reliability, red.reliability,
		"each holder's belief must be independent")


func test_acquire_unknown_token_fails() -> void:
	assert_false(CoreIntel.acquire("blue", "does_not_exist"))
	assert_false(CoreIntel.knows("blue", "does_not_exist"))


func test_corroboration_raises_reliability_once_per_source() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	var tok := CoreIntel.journal_for("blue").get_token("crypt_location")
	var before := tok.reliability

	# Same source again -> no change.
	assert_false(CoreIntel.acquire("blue", "crypt_location", "scout", "told"))
	assert_eq(tok.reliability, before)

	# A genuinely independent source -> belief rises.
	assert_true(CoreIntel.acquire("blue", "crypt_location", "innkeeper", "told"))
	assert_gt(tok.reliability, before)
	assert_eq(tok.sources().size(), 2)


func test_reliability_never_exceeds_one() -> void:
	for source in ["a", "b", "c", "d", "e", "f"]:
		CoreIntel.acquire("blue", "crypt_location", source, "told")
	assert_lte(CoreIntel.journal_for("blue").get_token("crypt_location").reliability, 1.0)


# --- Provenance -----------------------------------------------------------------

func test_provenance_records_channel_and_time() -> void:
	_adapter.advance(7.0)
	CoreIntel.acquire("blue", "crypt_location", "spy", "stolen", 0.8)
	var tok := CoreIntel.journal_for("blue").get_token("crypt_location")
	assert_eq(tok.provenance.size(), 1)
	assert_eq(tok.provenance[0].channel, "stolen")
	assert_eq(tok.provenance[0].at, 7.0)
	assert_eq(tok.acquired_at, 7.0)


# --- Decay ----------------------------------------------------------------------

func test_token_goes_stale_after_decay_window() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	var tok := CoreIntel.journal_for("blue").get_token("crypt_location")
	assert_false(tok.is_stale(_adapter.now()))

	_adapter.advance(11.0)
	assert_true(tok.is_stale(_adapter.now()))
	assert_eq(CoreIntel.prune_stale("blue").size(), 1)
	# Only reported once.
	assert_eq(CoreIntel.prune_stale("blue").size(), 0)


func test_corroboration_refreshes_a_stale_token() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	_adapter.advance(11.0)
	var tok := CoreIntel.journal_for("blue").get_token("crypt_location")
	assert_true(tok.is_stale(_adapter.now()))

	CoreIntel.acquire("blue", "crypt_location", "innkeeper", "told")
	assert_false(tok.is_stale(_adapter.now()), "a fresh source revives the token")


# --- Contradiction & debunking ----------------------------------------------------

func test_conflicting_tokens_raise_contradiction() -> void:
	watch_signals(CoreIntel)
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	CoreIntel.acquire("blue", "crypt_is_myth", "priest", "told")
	assert_signal_emitted(CoreIntel, "contradiction_found")
	assert_eq(CoreIntel.journal_for("blue").contradictions().size(), 1)


func test_debunk_penalises_other_tokens_from_the_same_liar() -> void:
	CoreIntel.acquire("blue", "crypt_location", "liar", "told")
	CoreIntel.acquire("blue", "crypt_is_myth", "liar", "told")
	var other := CoreIntel.journal_for("blue").get_token("crypt_is_myth")
	var before := other.reliability

	CoreIntel.debunk("blue", "crypt_location")
	assert_true(CoreIntel.journal_for("blue").get_token("crypt_location").known_false)
	assert_false(CoreIntel.knows("blue", "crypt_location"))
	assert_almost_eq(other.reliability, before - CoreIntel.LIAR_PENALTY, 0.001)


# --- Spread & trade ----------------------------------------------------------------

func test_spread_transfers_with_degraded_trust() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	assert_true(CoreIntel.spread("blue", "red", "crypt_location"))
	assert_true(CoreIntel.knows("red", "crypt_location"))
	var red := CoreIntel.journal_for("red").get_token("crypt_location")
	assert_eq(red.provenance[0].channel, "spread")


func test_maximum_secrecy_blocks_spread() -> void:
	CoreIntel.acquire("blue", "state_secret", "insider", "observed")
	assert_false(CoreIntel.spread("blue", "red", "state_secret"))
	assert_false(CoreIntel.knows("red", "state_secret"))


func test_untradeable_token_is_refused() -> void:
	CoreIntel.acquire("blue", "state_secret", "insider", "observed")
	assert_eq(CoreIntel.trade("blue", "red", "state_secret"), -1)


func test_trade_price_scales_with_belief() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	var tok := CoreIntel.journal_for("blue").get_token("crypt_location")
	tok.reliability = 0.5
	assert_eq(CoreIntel.trade("blue", "red", "crypt_location"), 50)  # 100 * 0.5


# --- Query language -----------------------------------------------------------------

func test_query_has_with_reliability_and_staleness() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed", 1.0)
	assert_true(CoreIntel.evaluate({"has": "crypt_location"}, "blue"))
	assert_false(CoreIntel.evaluate({"has": "crypt_location", "min_reliability": 0.9}, "blue"))
	assert_false(CoreIntel.evaluate({"has": "crypt_location"}, "red"))

	_adapter.advance(11.0)
	assert_false(CoreIntel.evaluate({"has": "crypt_location"}, "blue"))
	assert_true(CoreIntel.evaluate({"has": "crypt_location", "allow_stale": true}, "blue"))


func test_query_grouping_operators() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	assert_true(CoreIntel.evaluate({"any": [{"has": "nope"}, {"has": "crypt_location"}]}, "blue"))
	assert_false(CoreIntel.evaluate({"all": [{"has": "nope"}, {"has": "crypt_location"}]}, "blue"))
	assert_true(CoreIntel.evaluate({"not": {"has": "nope"}}, "blue"))
	assert_true(CoreIntel.evaluate({}, "blue"), "an empty query is always true")


func test_query_by_subject_tag_scope_and_category() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	CoreIntel.acquire("blue", "crypt_is_myth", "priest", "told")
	assert_true(CoreIntel.evaluate({"subject": "crypt", "count": 2}, "blue"))
	assert_false(CoreIntel.evaluate({"subject": "crypt", "count": 3}, "blue"))
	assert_true(CoreIntel.evaluate({"tag": "location"}, "blue"))
	assert_true(CoreIntel.evaluate({"scope": "site"}, "blue"))
	assert_true(CoreIntel.evaluate({"category": "location"}, "blue"))


func test_query_fact_provenance_source_and_contradiction() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	assert_true(CoreIntel.evaluate({"fact": ["crypt_location", "map", "crypt"]}, "blue"))
	assert_false(CoreIntel.evaluate({"fact": ["crypt_location", "map", "other"]}, "blue"))
	assert_true(CoreIntel.evaluate({"provenance": ["crypt_location", "observed"]}, "blue"))
	assert_false(CoreIntel.evaluate({"provenance": ["crypt_location", "stolen"]}, "blue"))
	assert_true(CoreIntel.evaluate({"source": ["crypt_location", "scout"]}, "blue"))

	assert_false(CoreIntel.evaluate({"contradicted": "crypt_location"}, "blue"))
	CoreIntel.acquire("blue", "crypt_is_myth", "priest", "told")
	assert_true(CoreIntel.evaluate({"contradicted": "crypt_location"}, "blue"))


func test_query_flag_and_time() -> void:
	assert_false(CoreIntel.evaluate({"flag": "gate_open"}, "blue"))
	CoreContext.set_flag("gate_open", true)
	assert_true(CoreIntel.evaluate({"flag": "gate_open"}, "blue"))

	_adapter.advance(10.0)
	assert_true(CoreIntel.evaluate({"time": [">=", 10]}, "blue"))
	assert_false(CoreIntel.evaluate({"time": [">", 10]}, "blue"))


func test_query_shape_validation_for_offline_tools() -> void:
	assert_true(CoreIntelQuery.is_valid_shape({"has": "x"}))
	assert_true(CoreIntelQuery.is_valid_shape({"all": [{"has": "x"}]}))
	assert_false(CoreIntelQuery.is_valid_shape({"nonsense": 1}))
	assert_false(CoreIntelQuery.is_valid_shape({"all": "not_an_array"}))


# --- Persistence ---------------------------------------------------------------------

func test_intel_save_and_load_roundtrip() -> void:
	CoreIntel.acquire("blue", "crypt_location", "scout", "observed")
	CoreIntel.acquire("blue", "crypt_location", "innkeeper", "told")
	var expected := CoreIntel.journal_for("blue").get_token("crypt_location").reliability

	var saved := CoreIntel.to_save_data()
	CoreIntel.reset()
	assert_false(CoreIntel.knows("blue", "crypt_location"))

	CoreIntel.from_save_data(saved)
	var tok := CoreIntel.journal_for("blue").get_token("crypt_location")
	assert_almost_eq(tok.reliability, expected, 0.001)
	assert_eq(tok.sources().size(), 2)
