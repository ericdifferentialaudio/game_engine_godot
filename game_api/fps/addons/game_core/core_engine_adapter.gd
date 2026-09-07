## Base class a graphics engine extends to plug itself into the shared platform.
##
## The default implementation below is fully functional and headless: it keeps
## its own clock and answers "no" to every spatial question. That means core
## systems and unit tests run with no graphics engine present at all.
##
## The isometric engine overrides the spatial/ownership methods with hex/square
## grid answers; the FPS engine overrides them with 3D world answers.
##
##   class MyAdapter extends CoreEngineAdapter:
##       func now() -> float: return float(TurnManager.turn)
##       func distance(a, b) -> float: return world.topology.distance(a, b)
##       func are_hostile(a, b) -> bool: return FactionRegistry.are_hostile(a, b)
class_name CoreEngineAdapter
extends RefCounted

## Identifier of the host graphics engine: "headless" | "isometric" | "fps".
var engine_id: String = "headless"

var _clock: float = 0.0


# --- Time --------------------------------------------------------------------

## Current time in this engine's own unit (turns or game seconds).
func now() -> float:
	return _clock


## Headless helper: advance the built-in clock (used by tests).
func advance(delta: float) -> void:
	_clock += delta


# --- Space -------------------------------------------------------------------

## Distance between two positions in this engine's own units.
## [param a] and [param b] are Vector2i tile coords (iso) or Vector3 (fps).
func distance(_a, _b) -> float:
	return 0.0


## Does [param observer_id] currently have line of sight to [param target_id]?
func can_see(_observer_id: String, _target_id: String) -> bool:
	return false


## World/grid position of an entity, or null if it has none.
func position_of(_entity_id: String):
	return null


# --- Entities / factions ------------------------------------------------------

## True when the two holders (factions, or "player"/"npc" in the FPS engine)
## are hostile toward each other.
func are_hostile(_a: String, _b: String) -> bool:
	return false


## Stat block of a live entity, or null if unknown to this engine.
func stats_of(_entity_id: String) -> CoreStats:
	return null


## Number of live units of [param def_id] owned by [param holder] ("" = any def).
func unit_count(_holder: String, _def_id: String = "") -> int:
	return 0


## A holder-scoped flag (per-faction in iso; usually global in fps).
func holder_flag(_holder: String, _flag: String) -> bool:
	return false


## A holder's stockpile of a resource/currency.
func holder_resource(_holder: String, _resource_id: String) -> float:
	return 0.0


## Diplomacy/attitude stance of [param holder] toward [param other].
func stance(_holder: String, _other: String) -> String:
	return "neutral"


## Does [param holder] control the site/POI [param site_id]?
func owns_site(_holder: String, _site_id: String) -> bool:
	return false


# --- Presentation -------------------------------------------------------------

## Show a transient message. The engine layer routes this to its own HUD.
func notify(_text: String, _category: String = "info") -> void:
	pass


## Reveal map knowledge granted by an intel token's `reveals` block.
func reveal(_holder: String, _reveals: Dictionary) -> void:
	pass
