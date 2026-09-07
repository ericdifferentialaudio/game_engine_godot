## A live place in the world: the runtime counterpart of CorePlaceDefinition.
##
## Owns per-holder discovery, the intel gate, ordered interaction dispatch,
## ownership/capture and garrison bookkeeping — all simulation, all shared.
## Each graphics engine attaches its own visual and feeds entry events in.
##
##   var place := CorePlace.new(definition)
##   place.discover("blue")            # grants discover_intel, emits discovered
##   place.interact("blue", unit)      # runs interactions in order
class_name CorePlace
extends RefCounted

signal discovered(holder: String)
signal interacted(holder: String, ran: int)
signal owner_changed(old_owner: String, new_owner: String)

var definition: CorePlaceDefinition
var owner_id: String = ""
var discovered_by: Dictionary = {}      ## holder -> true
var interaction_state: Dictionary = {}  ## persisted once/once_per_holder marks
var garrison_ids: Array[String] = []    ## live unit ids spawned by this place
var respawn_at: Dictionary = {}         ## garrison index -> time

var _interactions: Array[CoreInteraction] = []
var _built: bool = false


func _init(p_definition: CorePlaceDefinition = null) -> void:
	if p_definition:
		definition = p_definition
		owner_id = p_definition.owner_id


func id() -> String:
	return definition.id if definition else ""


## Instantiate the interaction list. Safe to call again after a load.
func build() -> void:
	_interactions = CoreInteractionFactory.create_all(
		definition.interactions, id(), interaction_state)
	_built = true


func interactions() -> Array[CoreInteraction]:
	if not _built:
		build()
	return _interactions


# --- Visibility & discovery -----------------------------------------------------

## Can this holder perceive the place at all? (hidden_until intel gate)
func is_revealed_to(holder: String) -> bool:
	if definition == null or definition.hidden_until.is_empty():
		return true
	return CoreIntel.evaluate(definition.hidden_until, holder)


func is_discovered_by(holder: String) -> bool:
	return discovered_by.get(holder, false)


## First sight. Grants the place's discover_intel to the finder.
func discover(holder: String) -> bool:
	if holder == "" or is_discovered_by(holder) or not is_revealed_to(holder):
		return false
	discovered_by[holder] = true
	for tok in definition.discover_intel:
		CoreIntel.acquire(holder, str(tok), id(), "observed")
	discovered.emit(holder)
	return true


# --- Access & interaction ---------------------------------------------------------

## May this holder act here? Checks the enter gate and any access requirement.
func can_enter(holder: String) -> bool:
	if definition == null or not is_revealed_to(holder):
		return false
	if not definition.enter_requires.is_empty() \
			and not CoreIntel.evaluate(definition.enter_requires, holder):
		return false
	if definition.requires_access != "" \
			and not CoreContext.adapter.has_access(holder, definition.requires_access):
		return false
	return true


## Run the interaction list in order. Returns how many ran (0 if gated out).
func interact(holder: String, actor = null, target = null) -> int:
	if not can_enter(holder):
		return 0
	discover(holder)
	var ran := CoreInteractionFactory.run_all(interactions(), holder, actor, target)
	if ran > 0:
		interacted.emit(holder, ran)
	return ran


# --- Ownership --------------------------------------------------------------------

func set_owner(new_owner: String) -> void:
	if new_owner == owner_id:
		return
	var old := owner_id
	owner_id = new_owner
	owner_changed.emit(old, new_owner)


## Take the place for a holder, if it can be captured at all.
func capture(holder: String) -> bool:
	if definition == null or not definition.is_capturable() or holder == owner_id:
		return false
	set_owner(holder)
	return true


# --- Garrison ----------------------------------------------------------------------

## Spawn the defined garrison through the engine. Returns spawned unit ids.
func spawn_garrison() -> Array[String]:
	garrison_ids.clear()
	if definition == null:
		return garrison_ids
	for entry in definition.garrison_units():
		var spec := entry.duplicate()
		spec["near"] = definition.coord if definition.coord.x >= 0 else definition.position
		for uid in CoreContext.adapter.spawn_units(spec, owner_id, self):
			garrison_ids.append(uid)
	return garrison_ids


# --- Persistence --------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return {
		"owner": owner_id,
		"discovered_by": discovered_by.duplicate(),
		"interactions": interaction_state.duplicate(true),
		"garrison": garrison_ids.duplicate(),
		"respawn_at": respawn_at.duplicate(),
	}


func from_save_data(d: Dictionary) -> void:
	owner_id = str(d.get("owner", owner_id))
	discovered_by = d.get("discovered_by", {})
	interaction_state = d.get("interactions", {})
	garrison_ids.assign(d.get("garrison", []))
	respawn_at = d.get("respawn_at", {})
	build()   # rebind interactions to the restored state
