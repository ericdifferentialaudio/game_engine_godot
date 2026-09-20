## THE INTEGRATION DEMO.
##
## Proves every phase works together, with nothing wired by direct reference:
##
##   Ink story (pattern library)  ->  CoreInkEngine
##       ->  renders into the registered "dialogue" text window
##       ->  choice comes back as a CoreWindowRegistry signal
##       ->  gate checks currency AND knowledge AND standing
##       ->  success grants an asset AND knowledge
##       ->  the registered "status" window visibly updates
##
## The presenter below never holds a scene reference to any window: every push
## is a registry look-up by role. Swap the layout and it still works; remove a
## window from the layout and it degrades quietly instead of crashing.
extends GutTest

const STORY := "res://ink/round_room_fence.ink.json"
const LAYOUT_FILE := "res://ink/sample_layout.json"
const HOLDER := "player"
const FENCE := "fence"

const INTEL := [
	{"id": "know_trapdoor", "title": "A trap door beneath the rug", "reliability": 1.0,
	 "secrecy": 0.0},
	{"id": "rumor_rug_worthless", "title": "The rug is just a rug", "reliability": 0.3,
	 "secrecy": 0.0},
	{"id": "know_grue", "title": "What a grue is", "reliability": 1.0, "secrecy": 0.0},
]
const ITEMS := [
	{"id": "zorkmid", "display_name": "Zorkmid", "category": "currency", "value": 1},
	{"id": "brass_lantern", "display_name": "Brass Lantern", "category": "misc", "value": 5},
]

var _root: Control
var _builder: CoreLayoutBuilder
var _presenter: Presenter


## Glue a game would write once: drive a story into whatever windows exist.
## Deliberately registry-only — this class has no window references at all.
class Presenter extends RefCounted:
	var bindings: CoreInkBindings
	var context: CoreContextBuilder
	var dialogue_role := "dialogue"
	var status_role := "status"

	func start(story_path: String, npc: String, location: String) -> bool:
		if not CoreInkEngine.load_story(story_path):
			return false
		bindings = CoreInkBindings.new("player", npc)
		bindings.bind_all(CoreInkEngine)

		context = CoreContextBuilder.new()
		context.npc_id = npc
		context.location = location
		context.push(CoreInkEngine)
		context.watch()

		CoreWindowRegistry.choice_selected.connect(_on_choice)
		CoreAssets.asset_gained.connect(_on_assets_changed)
		CoreAssets.asset_lost.connect(_on_assets_changed)
		CoreKnowledge.learned.connect(_on_learned)

		_advance()
		refresh_status()
		return true

	func _advance() -> void:
		for line in CoreInkEngine.continue_all():
			CoreWindowRegistry.append_line(dialogue_role, line)
		var window := CoreWindowRegistry.get_text_window(dialogue_role)
		if window != null:
			window.set_choices(CoreInkEngine.choices())

	func _on_choice(role: String, index: int, _text: String) -> void:
		if role != dialogue_role:
			return
		CoreInkEngine.choose(index)
		_advance()

	func _on_assets_changed(_h, _id, _amount, _total) -> void:
		refresh_status()

	func _on_learned(_h, knowledge_id: String, _source: String) -> void:
		var window := CoreWindowRegistry.get_icon_text_window(status_role)
		if window != null:
			window.set_entry("knew_" + knowledge_id, "?", "Learned: " + knowledge_id)

	## Mirror the asset stores into the status window, purely by role lookup.
	func refresh_status() -> void:
		var window := CoreWindowRegistry.get_icon_text_window(status_role)
		if window == null:
			return
		for asset_id in CoreAssets.all_assets("player"):
			window.set_entry(str(asset_id), "*",
					"%s: %d" % [asset_id, CoreAssets.amount(str(asset_id), "player")])


func before_each() -> void:
	CoreWindowRegistry.clear()
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
		{"id": "stranger", "at": -100.0}, {"id": "neutral", "at": 0.0},
		{"id": "friendly", "at": 25.0}]}}
	CoreContext.install(CoreEngineAdapter.new())
	CoreContext.configure({"seed": 7})

	_root = Control.new()
	add_child_autofree(_root)
	_builder = CoreLayoutBuilder.new(CoreLayoutDefinition.load_file(LAYOUT_FILE))
	_builder.build(_root, Vector2(1920, 1080))
	_presenter = Presenter.new()


func after_each() -> void:
	CoreInkEngine.unload()
	if is_instance_valid(_root):
		_builder.teardown(_root)


## Press a choice button by its visible text, then let the deferred report
## reach the presenter (see CoreTextWindow._on_choice_pressed).
func _press(fragment: String) -> bool:
	var window := CoreWindowRegistry.get_text_window("dialogue")
	var choices := CoreInkEngine.choices()
	for i in choices.size():
		if str(choices[i]["text"]).contains(fragment):
			if not window.press_choice(i):
				return false
			await get_tree().process_frame
			return true
	return false


# --- The demo ------------------------------------------------------------------

func test_conversation_renders_into_the_registered_text_window() -> void:
	assert_true(_presenter.start(STORY, FENCE, "round_room"))

	var window := CoreWindowRegistry.get_text_window("dialogue")
	assert_gt(window.lines().size(), 0, "narration should have reached the window")
	assert_gt(window.choice_count(), 0, "choices should have reached the window")


func test_status_window_shows_starting_assets() -> void:
	CoreAssets.give("zorkmid", 5, HOLDER)
	_presenter.start(STORY, FENCE, "round_room")

	var status := CoreWindowRegistry.get_icon_text_window("status")
	assert_eq(status.entry_text("zorkmid"), "zorkmid: 5")


## The headline: three gates, two grants, all through the windows.
func test_full_exchange_updates_both_windows() -> void:
	CoreAssets.give("zorkmid", 5, HOLDER)
	CoreKnowledge.learn("know_trapdoor", "saw it", HOLDER)
	CoreStanding.set_score(FENCE, 40.0, HOLDER)
	_presenter.start(STORY, FENCE, "round_room")

	var dialogue := CoreWindowRegistry.get_text_window("dialogue")
	var status := CoreWindowRegistry.get_icon_text_window("status")

	assert_true(await _press("for sale"), "wares unlocked by standing")
	assert_true(await _press("Buy the lantern"), "purchase unlocked by currency")

	# Simulation state changed...
	assert_true(CoreAssets.has("brass_lantern", 1, HOLDER))
	assert_eq(CoreAssets.amount("zorkmid", HOLDER), 2)
	assert_true(CoreKnowledge.knows("know_grue", HOLDER))

	# ...and the windows reflect it, updated only via registry look-ups.
	assert_eq(status.entry_text("zorkmid"), "zorkmid: 2",
			"the status window should show the spend")
	assert_eq(status.entry_text("brass_lantern"), "brass_lantern: 1",
			"the status window should show the new item")
	assert_true(status.has_entry("knew_know_grue"),
			"the status window should show the new knowledge")

	var prose := "\n".join(dialogue.lines())
	assert_true(prose.contains("Coins change hands"),
			"the purchase narration should have rendered")


func test_layout_without_a_status_window_degrades_quietly() -> void:
	CoreWindowRegistry.unregister_window("status")
	CoreAssets.give("zorkmid", 5, HOLDER)
	CoreStanding.set_score(FENCE, 40.0, HOLDER)

	assert_true(_presenter.start(STORY, FENCE, "round_room"),
			"a missing window must not stop the conversation")
	assert_true(await _press("for sale"))
	assert_true(await _press("Buy the lantern"))
	assert_true(CoreAssets.has("brass_lantern", 1, HOLDER),
			"the simulation still ran correctly with no status window present")


func test_context_variables_reach_the_story() -> void:
	CoreStanding.set_score(FENCE, 40.0, HOLDER)
	_presenter.start(STORY, FENCE, "round_room")

	assert_eq(str(CoreInkEngine.var_get("location")), "round_room")
	assert_eq(str(CoreInkEngine.var_get("npc_standing")), "friendly",
			"the standing tier should have been pushed as an Ink variable")
