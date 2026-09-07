## POI that acts as a map transition (e.g. a trapdoor discovered via intel).
##   {"kind": "portal", "portal_id": "cellar_trapdoor", "requires": {"has": "rumor_cellar"}}
## The portal_id must exist in the current MapDefinition.portals list.
class_name PortalInteraction
extends Interaction


func _on_setup() -> void:
	kind = "portal"


func _execute(_by: Node) -> void:
	MapManager.traverse_portal(spec.get("portal_id", ""))
