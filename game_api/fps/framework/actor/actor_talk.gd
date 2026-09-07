## Makes an NPC/monster Actor a conversation partner.
##
## Attach (or let MapRoot attach) to an Actor whose ActorDefinition carries an
## "interactions" array in the same format as a POI. The player looks at the
## actor and presses interact; interactions run in order exactly like a POI's.
## Hostile actors that are already fighting will not talk.
class_name ActorTalk
extends Node

var actor: Actor
var interactions: Array = []
var _interactable: Interactable
var _talk_layer_added := false


func setup(p_actor: Actor, specs: Array) -> void:
	actor = p_actor
	_interactable = Interactable.new()
	_interactable.prompt = "Talk to %s" % (actor.actor_def.display_name if actor.actor_def else actor.name)
	_interactable.interacted.connect(_on_interact)
	actor.add_child(_interactable)
	# Actors sit on the NPC layer (5); the interaction ray also scans Interactable (3).
	actor.collision_layer |= (1 << 2)
	_talk_layer_added = true
	for i in specs.size():
		var spec: Dictionary = specs[i].duplicate()
		spec["index"] = i
		var inter = InteractionFactory.create(spec, self)
		if inter:
			interactions.append(inter)
	actor.died.connect(func(_k): if _interactable: _interactable.enabled = false)


## Interaction base class asks its poi for get_state(); persist per actor def.
func get_state() -> Dictionary:
	var ms := MapManager.get_map_state(actor.spawned_by_map if actor.spawned_by_map != "" else "__actors__")
	if not ms.has("actors"):
		ms["actors"] = {}
	var key: String = actor.actor_def.id if actor.actor_def else String(actor.name)
	if not ms["actors"].has(key):
		ms["actors"][key] = {}
	return ms["actors"][key]


## DialogueInteraction reads poi.definition.id for provenance; give it one.
var definition:
	get:
		return actor.actor_def


func _on_interact(by: Node) -> void:
	if actor.is_dead:
		return
	if actor.brain is AIBrain and (actor.brain as AIBrain).state in [AIBrain.State.CHASE, AIBrain.State.ATTACK]:
		EventBus.notification.emit("%s is in no mood to talk." % (actor.actor_def.display_name if actor.actor_def else "It"), "dialogue")
		return
	for inter in interactions:
		if inter.can_run(by):
			inter.run(by)
			EventBus.poi_interacted.emit(definition.id if definition else actor.name, inter.kind)
			if inter.consumes_interaction:
				break
