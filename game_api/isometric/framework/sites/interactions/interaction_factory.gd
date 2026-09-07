## Maps JSON "kind" -> Interaction subclass. Games can register custom kinds
## at startup via register().
class_name InteractionFactory
extends RefCounted

static var _registry: Dictionary = {
	"intel": preload("res://framework/sites/interactions/intel_interaction.gd"),
	"reward": preload("res://framework/sites/interactions/reward_interaction.gd"),
	"shop": preload("res://framework/sites/interactions/shop_interaction.gd"),
	"dialogue": preload("res://framework/sites/interactions/dialogue_interaction.gd"),
	"portal": preload("res://framework/sites/interactions/portal_interaction.gd"),
	"spawn": preload("res://framework/sites/interactions/spawn_interaction.gd"),
	"combat": preload("res://framework/sites/interactions/combat_interaction.gd"),
	"flag": preload("res://framework/sites/interactions/flag_interaction.gd"),
}


static func known_kinds() -> Array:
	return _registry.keys()


static func register(kind: String, script: GDScript) -> void:
	_registry[kind] = script


static func create(spec: Dictionary, owner) -> Interaction:
	var kind: String = spec.get("kind", "")
	var script: GDScript = _registry.get(kind)
	if script == null:
		push_error("InteractionFactory: unknown interaction kind '%s'" % kind)
		return null
	var inter: Interaction = script.new()
	inter.setup(spec.duplicate(), owner)
	return inter
