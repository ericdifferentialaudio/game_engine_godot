## The validation tools, run for real against the compiled demo story.
##
## This is both the test of the validator and the working demonstration asked
## for: the static pass and the context simulation both execute here, and the
## simulation genuinely discovers that the purchase branch is reachable only
## when currency AND standing are both sufficient.
extends GutTest

const STORY := "res://ink/round_room_fence.ink.json"
const SOURCES := ["res://ink/round_room_fence.ink", "res://ink/patterns/patterns.ink"]
const HOLDER := "player"
const FENCE := "fence"

const INTEL := [
	{"id": "know_trapdoor", "title": "td", "reliability": 1.0, "secrecy": 0.0},
	{"id": "rumor_rug_worthless", "title": "rr", "reliability": 0.3, "secrecy": 0.0},
	{"id": "know_grue", "title": "grue", "reliability": 1.0, "secrecy": 0.0},
]
const ITEMS := [
	{"id": "zorkmid", "display_name": "Zorkmid", "category": "currency", "value": 1},
	{"id": "brass_lantern", "display_name": "Brass Lantern", "category": "misc", "value": 5},
]


func _seed_world() -> void:
	CoreRegistry.clear()
	for d in INTEL:
		CoreRegistry.add("intel", CoreDefinition.build(CoreIntelToken, d))
	for d in ITEMS:
		CoreRegistry.add("items", CoreDefinition.build(CoreItemDefinition, d))
	CoreIntel.reset()
	CoreAssets.reset()
	CoreStanding.reset()
	CoreContext.reset()
	CoreContext.rules = {"standing": {"tiers": [
		{"id": "stranger", "at": -100.0},
		{"id": "neutral", "at": 0.0},
		{"id": "friendly", "at": 25.0},
	]}}
	CoreContext.install(CoreEngineAdapter.new())
	CoreContext.configure({"seed": 99})


func before_each() -> void:
	_seed_world()


func after_each() -> void:
	CoreInkEngine.unload()


# --- Static pass ---------------------------------------------------------------

func test_static_check_passes_on_the_demo_story() -> void:
	var result := CoreInkValidator.static_check(
			STORY, SOURCES, CoreInkBindings.FUNCTION_NAMES)
	var findings: Array = result["findings"]

	gut.p(CoreInkValidator.format_report(
			"STATIC PASS — round_room_fence", findings, result["summary"]))

	assert_false(CoreInkValidator.has_errors(findings),
			"the shipped demo story must have no structural errors")


func test_static_check_catches_an_unbound_external() -> void:
	# Bind everything except one function the story genuinely declares.
	var incomplete := CoreInkBindings.FUNCTION_NAMES.duplicate()
	incomplete.erase("spend_asset")

	var result := CoreInkValidator.static_check(STORY, SOURCES, incomplete)
	assert_true(CoreInkValidator.has_errors(result["findings"]),
			"an unbound EXTERNAL must be reported as an error")


func test_static_check_reports_a_missing_story_file() -> void:
	var result := CoreInkValidator.static_check(
			"res://ink/does_not_exist.ink.json", [], [])
	assert_true(CoreInkValidator.has_errors(result["findings"]))


# --- Context simulation --------------------------------------------------------

func test_build_cases_produces_the_cross_product() -> void:
	var cases := CoreInkValidator.build_cases({
		"assets": {"zorkmid": [0, 3]},
		"standing": {"fence": [0.0, 40.0]},
	})
	assert_eq(cases.size(), 4, "2 x 2 axes should give 4 context states")


func test_build_cases_respects_the_cap() -> void:
	var cases := CoreInkValidator.build_cases({
		"assets": {"a": [0, 1], "b": [0, 1], "c": [0, 1], "d": [0, 1]},
	}, 4)
	assert_lte(cases.size(), 4, "the case cap must be honoured")


## The headline test: play the story across a grid of world states and prove
## the simulation discovers context-dependent reachability.
func test_simulation_finds_context_gated_content() -> void:
	var cases := CoreInkValidator.build_cases({
		"assets": {"zorkmid": [0, 5]},
		"knowledge": {"know_trapdoor": [false, true]},
		"standing": {"fence": [0.0, 40.0]},
	})
	assert_eq(cases.size(), 8, "three binary axes")

	var sim := CoreInkValidator.simulate(cases, _play_case)
	var reached: Dictionary = sim["reached"]
	gut.p("Reached %d distinct labels across %d context states"
			% [reached.size(), int(sim["case_count"])])

	# Content that should appear in every world state.
	assert_true(reached.has("Ask about the house on the hill."),
			"the opening question should be available unconditionally")

	# Content gated on standing alone.
	var wares := "Ask what he has for sale."
	assert_true(reached.has(wares), "the wares should be reachable somehow")
	for ctx in CoreInkValidator.conditions_for(wares, sim):
		assert_eq(float(ctx["standing"]["fence"]), 40.0,
				"the wares must only ever appear at sufficient standing")

	# Content gated on TWO systems at once — the case a static walk misses.
	var buy := "Buy the lantern (3 zorkmids)."
	assert_true(reached.has(buy), "the purchase must be reachable in some state")
	for ctx in CoreInkValidator.conditions_for(buy, sim):
		assert_eq(float(ctx["standing"]["fence"]), 40.0, "purchase needs standing")
		assert_eq(int(ctx["assets"]["zorkmid"]), 5, "purchase needs currency")

	# Content gated on knowledge.
	var confide := "Mention what is under the rug."
	assert_true(reached.has(confide))
	for ctx in CoreInkValidator.conditions_for(confide, sim):
		assert_true(bool(ctx["knowledge"]["know_trapdoor"]),
				"cannot volunteer a secret the player does not hold")


func test_unreachable_report_names_content_never_seen() -> void:
	var cases := CoreInkValidator.build_cases({"assets": {"zorkmid": [0]}})
	var sim := CoreInkValidator.simulate(cases, _play_case)

	var findings := CoreInkValidator.unreachable_report(
			["Ask about the house on the hill.", "Buy the lantern (3 zorkmids)."], sim)

	gut.p(CoreInkValidator.format_report(
			"CONTEXT SIMULATION — poor, unknown, unfriendly", findings,
			{"cases": sim["case_count"]}))

	assert_eq(findings.size(), 1,
			"only the purchase should be flagged unreachable in this context")
	assert_eq(str(findings[0]["subject"]), "Buy the lantern (3 zorkmids).")


# --- Simulation driver ---------------------------------------------------------

## Seed the world from one context case, walk every choice one level deep, and
## return the labels encountered.
func _play_case(context: Dictionary) -> Array:
	_seed_world()

	for asset_id in context.get("assets", {}):
		var count := int(context["assets"][asset_id])
		if count > 0:
			CoreAssets.give(str(asset_id), count, HOLDER)
	for knowledge_id in context.get("knowledge", {}):
		if bool(context["knowledge"][knowledge_id]):
			CoreKnowledge.learn(str(knowledge_id), "setup", HOLDER)
	for npc in context.get("standing", {}):
		CoreStanding.set_score(str(npc), float(context["standing"][npc]), HOLDER)

	CoreInkEngine.unload()
	if not CoreInkEngine.load_story(STORY):
		return []
	CoreInkBindings.new(HOLDER, FENCE).bind_all(CoreInkEngine)

	var labels: Array = []
	CoreInkEngine.continue_all()
	for choice in CoreInkEngine.choices():
		labels.append(str(choice["text"]))

	# Descend one level so nested gates (the wares menu) are exercised too.
	for choice in CoreInkEngine.choices():
		if str(choice["text"]).contains("for sale"):
			CoreInkEngine.choose(int(choice["index"]))
			CoreInkEngine.continue_all()
			for nested in CoreInkEngine.choices():
				labels.append(str(nested["text"]))
			break

	return labels
