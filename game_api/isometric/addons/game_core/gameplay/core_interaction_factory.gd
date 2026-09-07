## Maps a JSON "kind" to a CoreInteraction subclass, and runs ordered lists.
##
## The built-in kinds cover both engines' original sets:
##   intel · reward · flag · portal · spawn · shop · dialogue · combat
##
## Games are never limited to these — register a new kind at boot:
##   CoreInteractionFactory.register("ritual", preload("res://ritual.gd"))
## and any place, item, ability or intel token can then use
##   {"kind": "ritual", ...}
class_name CoreInteractionFactory
extends RefCounted

static var _registry: Dictionary = {}
static var _defaults_installed: bool = false


static func _install_defaults() -> void:
	if _defaults_installed:
		return
	_defaults_installed = true
	_registry.merge({
		"intel": CoreIntelInteraction,
		"reward": CoreRewardInteraction,
		"flag": CoreFlagInteraction,
		"portal": CorePortalInteraction,
		"spawn": CoreSpawnInteraction,
		"shop": CoreShopInteraction,
		"dialogue": CoreDialogueInteraction,
		"combat": CoreCombatInteraction,
	}, false)   # never clobber a game's override


## Register (or replace) an interaction kind.
static func register(kind: String, script: GDScript) -> void:
	_install_defaults()
	_registry[kind] = script


static func known_kinds() -> Array:
	_install_defaults()
	return _registry.keys()


static func has_kind(kind: String) -> bool:
	_install_defaults()
	return _registry.has(kind)


## Build one interaction from a spec. [param state] is the owner's persisted
## bookkeeping for once/once_per_holder, so it survives save/load.
static func create(spec: Dictionary, owner_id: String = "", state: Dictionary = {}) -> CoreInteraction:
	_install_defaults()
	var kind := str(spec.get("kind", ""))
	var script: GDScript = _registry.get(kind)
	if script == null:
		push_warning("CoreInteractionFactory: unknown interaction kind '%s'" % kind)
		return null
	var inter: CoreInteraction = script.new()
	inter.setup(spec.duplicate(true), owner_id, state)
	return inter


## Build every interaction in an ordered list, giving each its own state slot.
## [param state_store] is a dictionary the owner persists.
static func create_all(specs: Array, owner_id: String = "", state_store: Dictionary = {}) -> Array[CoreInteraction]:
	var out: Array[CoreInteraction] = []
	for i in specs.size():
		if not (specs[i] is Dictionary):
			continue
		var key := "%s_%d" % [str(specs[i].get("kind", "?")), i]
		if not state_store.has(key):
			state_store[key] = {}
		var inter := create(specs[i], owner_id, state_store[key])
		if inter:
			out.append(inter)
	return out


## Run an ordered list for a holder, honouring `consumes`. Returns how many ran.
##
## This is the standard dispatch used by places, item use and abilities: walk
## the list in order, run whatever passes its gates, and stop at the first
## interaction that declares it consumes the encounter.
static func run_all(interactions: Array, holder: String, actor = null, target = null) -> int:
	var ran := 0
	for inter in interactions:
		if inter == null:
			continue
		if inter.run(holder, actor, target):
			ran += 1
			if inter.consumes:
				break
	return ran
