## Opens a shop. Stock can be gated per-item by intel (the merchant only shows
## the smuggled goods once you know the code word).
##   {"kind": "shop", "shop_id": "hollowmere_general", "currency": "gold",
##    "stock": [{"item": "potion_minor", "price": 25, "stock": 5},
##              {"item": "map_fragment_north", "price": 120, "requires": {"has": "rumor_north_ruins"}}]}
class_name ShopInteraction
extends Interaction

var shop: Shop


func _on_setup() -> void:
	kind = "shop"
	shop = Shop.new()
	shop.shop_id = spec.get("shop_id", poi.definition.id if poi and "definition" in poi else "shop")
	shop.currency_id = spec.get("currency", "gold")
	shop.load_stock(spec.get("stock", []))


func _execute(by: Node) -> void:
	var ui := by.get_tree().get_first_node_in_group("shop_ui") if by else null
	if ui and ui.has_method("open"):
		ui.open(shop, by)
	else:
		# Headless / no UI: list what is available so the flow is testable.
		for entry in shop.available_entries():
			EventBus.notification.emit("%s – %d %s" % [entry["item"], entry["price"], shop.currency_id], "shop")
