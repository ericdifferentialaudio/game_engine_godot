## Maps JSON "kind" -> Interaction subclass. Games can register custom kinds
## at startup via register().
class_name InteractionFactory
extends RefCounted

static var _registry: Dictionary = {
	"intel": preload("res://framework/poi/interactions/intel_interaction.gd"),
	"reward": preload("res://framework/poi/interactions/reward_interaction.gd"),
	"shop": preload("res://framework/poi/interactions/shop_interaction.gd"),
	"dialogue": preload("res://framework/poi/interactions/dialogue_interaction.gd"),
	"portal": preload("res://framework/poi/interactions/portal_interaction.gd"),
}


static func register(kind: String, script: GDScript) -> void:
	_registry[kind] = script


static func create(spec: Dictionary, poi: Node) -> Interaction:
	var kind: String = spec.get("kind", "")
	var script: GDScript = _registry.get(kind)
	if script == null:
		push_error("InteractionFactory: unknown interaction kind '%s'" % kind)
		return null
	var inter: Interaction = script.new()
	inter.setup(spec, poi)
	return inter
