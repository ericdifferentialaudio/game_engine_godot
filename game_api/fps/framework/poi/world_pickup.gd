## A pile of items lying in the world (dropped loot, thrown-away gear).
## Look at it and press interact to take everything into your inventory.
class_name WorldPickup
extends Area3D

var items: Dictionary = {}          ## item_id -> count
var label: String = "some items"
var visual_key: String = "poi.loot"

var _interactable: Interactable


func _ready() -> void:
	collision_layer = 1 << 2  # Interactable
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	shape.position.y = 0.5
	add_child(shape)
	add_child(AssetRegistry.instance_scene(visual_key))
	_interactable = Interactable.new()
	_interactable.prompt = "Take %s" % label
	_interactable.interacted.connect(_on_interact)
	add_child(_interactable)


func _on_interact(by: Node) -> void:
	var inv := Shop.inventory_of(by)
	if inv == null:
		return
	var taken: Array[String] = []
	for item_id in items.keys():
		var def := DefinitionRegistry.get_def("items", item_id) as ItemDefinition
		var count := int(items[item_id])
		var added := inv.add_item(item_id, count)
		if added >= count:
			items.erase(item_id)
			taken.append(def.display_name if def else item_id)
		elif added > 0:
			items[item_id] = count - added
	if not taken.is_empty():
		EventBus.notification.emit("Taken: %s." % ", ".join(taken), "pickup")
	if items.is_empty():
		if MapManager.current_map and MapManager.current_map.has_method("unregister_loot"):
			MapManager.current_map.unregister_loot(self)
		queue_free()
