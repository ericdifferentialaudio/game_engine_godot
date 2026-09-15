## CoreKnowledge — the boolean view over the intel journal.
##
## The point under test: hearing a rumour is not knowing a fact.
extends GutTest

const HOLDER := "player"

const INTEL := [
	{"id": "fact_reliable", "title": "A solid fact", "reliability": 1.0, "secrecy": 0.0},
	{"id": "rumor_flimsy", "title": "A tavern rumour", "reliability": 0.3, "secrecy": 0.0},
	{"id": "fact_midling", "title": "A half-fact", "reliability": 0.6,
	 "corroboration_step": 0.2, "secrecy": 0.0},
]

var _adapter: CoreEngineAdapter


func before_each() -> void:
	CoreRegistry.clear()
	for d in INTEL:
		CoreRegistry.add("intel", CoreDefinition.build(CoreIntelToken, d))
	CoreIntel.reset()
	CoreContext.reset()
	CoreContext.rules = {}
	_adapter = CoreEngineAdapter.new()
	CoreContext.install(_adapter)
	CoreContext.configure({"seed": 12345})


func test_unknown_is_not_known() -> void:
	assert_false(CoreKnowledge.knows("fact_reliable", HOLDER))
	assert_false(CoreKnowledge.heard_of("fact_reliable", HOLDER))


func test_reliable_fact_becomes_known() -> void:
	CoreKnowledge.learn("fact_reliable", "ledger", HOLDER)
	assert_true(CoreKnowledge.knows("fact_reliable", HOLDER))


func test_flimsy_rumor_is_heard_but_not_known() -> void:
	CoreKnowledge.learn("rumor_flimsy", "a drunk", HOLDER)
	assert_true(CoreKnowledge.heard_of("rumor_flimsy", HOLDER),
			"the rumour should be in the journal")
	assert_false(CoreKnowledge.knows("rumor_flimsy", HOLDER),
			"a 0.3-reliability rumour must not satisfy a hard gate")


func test_belief_threshold_is_game_configurable() -> void:
	CoreKnowledge.learn("rumor_flimsy", "a drunk", HOLDER)
	CoreContext.rules = {"knowledge": {"belief_threshold": 0.2}}
	assert_true(CoreKnowledge.knows("rumor_flimsy", HOLDER),
			"a credulous game can lower the bar")


func test_distrusted_source_yields_weaker_belief() -> void:
	CoreKnowledge.learn("fact_reliable", "a stranger", HOLDER, 0.2)
	var doubted := CoreKnowledge.belief("fact_reliable", HOLDER)
	CoreIntel.reset()
	CoreKnowledge.learn("fact_reliable", "the ledger", HOLDER, 1.0)
	assert_gt(CoreKnowledge.belief("fact_reliable", HOLDER), doubted,
			"a trusted source should produce firmer belief than a doubtful one")


func test_learn_reports_only_the_crossing() -> void:
	assert_true(CoreKnowledge.learn("fact_reliable", "ledger", HOLDER),
			"first time across the threshold returns true")
	assert_false(CoreKnowledge.learn("fact_reliable", "ledger2", HOLDER),
			"already known: nothing new to announce")


func test_corroboration_can_promote_a_rumor() -> void:
	CoreKnowledge.learn("fact_midling", "one source", HOLDER)
	var first := CoreKnowledge.belief("fact_midling", HOLDER)
	CoreKnowledge.learn("fact_midling", "another source", HOLDER)
	assert_gt(CoreKnowledge.belief("fact_midling", HOLDER), first,
			"an independent second source should raise belief")


func test_debunked_fact_stops_being_known() -> void:
	CoreKnowledge.learn("fact_reliable", "ledger", HOLDER)
	CoreIntel.debunk(HOLDER, "fact_reliable")
	assert_false(CoreKnowledge.knows("fact_reliable", HOLDER))
	assert_true(CoreKnowledge.disbelieves("fact_reliable", HOLDER))
	assert_eq(CoreKnowledge.belief("fact_reliable", HOLDER), 0.0)


func test_forget_removes_knowledge() -> void:
	CoreKnowledge.learn("fact_reliable", "ledger", HOLDER)
	assert_true(CoreKnowledge.forget("fact_reliable", HOLDER))
	assert_false(CoreKnowledge.heard_of("fact_reliable", HOLDER))
	assert_false(CoreKnowledge.forget("fact_reliable", HOLDER), "already gone")


func test_known_ids_lists_only_believed_facts() -> void:
	CoreKnowledge.learn("fact_reliable", "ledger", HOLDER)
	CoreKnowledge.learn("rumor_flimsy", "a drunk", HOLDER)
	var known := CoreKnowledge.known_ids(HOLDER)
	assert_has(known, "fact_reliable")
	assert_does_not_have(known, "rumor_flimsy")
