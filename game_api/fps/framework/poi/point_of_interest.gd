## Runtime node for a POI. Built by MapRoot from a PoiDefinition.
##
## Handles discovery (proximity), visibility gating (hidden_until intel query),
## focus/interaction, and dispatches to Interaction strategies in order.
class_name PointOfInterest
extends Area3D

var definition: PoiDefinition
var discovered: bool = false
var _interactions: Array = []       ## Array[Interaction]
var _interactable: Interactable
var _visual: Node3D
var _discover_area: Area3D


func build() -> void:
	collision_layer = 1 << 2  # "Interactable"
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(definition.interact_radius * 0.5, 0.75)
	shape.shape = sphere
	shape.position.y = 1.0
	add_child(shape)

	_visual = AssetRegistry.instance_scene(definition.visual_key)
	add_child(_visual)

	_interactable = Interactable.new()
	_interactable.prompt = definition.display_name
	_interactable.interacted.connect(_on_interact)
	add_child(_interactable)

	_discover_area = Area3D.new()
	_discover_area.collision_layer = 0
	_discover_area.collision_mask = 1 << 1  # Player
	var ds := CollisionShape3D.new()
	var dsphere := SphereShape3D.new()
	dsphere.radius = definition.discover_radius
	ds.shape = dsphere
	_discover_area.add_child(ds)
	_discover_area.body_entered.connect(_on_body_entered)
	add_child(_discover_area)

	for i in definition.interactions.size():
		var spec: Dictionary = definition.interactions[i].duplicate()
		spec["index"] = i
		var inter = InteractionFactory.create(spec, self)
		if inter:
			_interactions.append(inter)

	var st := MapManager.get_map_state(definition.map_id)
	discovered = st["discovered_pois"].has(definition.id)
	_refresh_visibility()
	EventBus.intel_acquired.connect(func(_t, _s): _refresh_visibility())
	EventBus.intel_updated.connect(func(_t): _refresh_visibility())
	EventBus.flag_set.connect(func(_f, _v): _refresh_visibility())


func is_revealed() -> bool:
	return definition.hidden_until.is_empty() or IntelRegistry.evaluate(definition.hidden_until)


## Was this object picked up (PickupInteraction)? Persisted in map state.
func is_taken() -> bool:
	return get_state().get("taken", false)


func set_taken() -> void:
	get_state()["taken"] = true
	_refresh_visibility()


func _refresh_visibility() -> void:
	var show := is_revealed() and not is_taken()
	visible = show
	_interactable.enabled = show
	collision_layer = (1 << 2) if show else 0


func _on_body_entered(body: Node3D) -> void:
	if discovered or not is_revealed() or not body.is_in_group("player"):
		return
	discovered = true
	EventBus.poi_discovered.emit(definition.id, definition.map_id)
	EventBus.notification.emit("Discovered: %s" % definition.display_name, "discovery")


func _on_interact(by: Node) -> void:
	if not discovered:
		discovered = true
		EventBus.poi_discovered.emit(definition.id, definition.map_id)
	var ran := false
	for inter in _interactions:
		if inter.can_run(by):
			ran = true
			inter.run(by)
			EventBus.poi_interacted.emit(definition.id, inter.kind)
			if inter.consumes_interaction:
				break
	if not ran:
		for inter in _interactions:
			var msg: String = inter.missing_item_text(by)
			if msg != "":
				EventBus.notification.emit(msg, "locked")
				return
		if definition.description != "":
			EventBus.notification.emit(definition.description, "examine")


## Per-POI persisted state lives inside the map state so it unloads/reloads cleanly.
func get_state() -> Dictionary:
	var ms := MapManager.get_map_state(definition.map_id)
	if not ms.has("pois"):
		ms["pois"] = {}
	if not ms["pois"].has(definition.id):
		ms["pois"][definition.id] = {}
	return ms["pois"][definition.id]
