## Opens a Shop model for the acting faction (UI in group "shop_ui" presents it).
##   {"kind": "shop", "shop_id": "marrow_curios", "currency": "gold",
##    "stock": [{"item": "healing_herb", "price": 10, "stock": 5},
##              {"item": "smugglers_map", "price": 60, "stock": 1, "requires": {"has": "rumor_marrow_smuggles"}}],
##    "buys_intel": true, "intel_price_multiplier": 1.0}
## Headless/AI: nothing is bought automatically.
class_name ShopInteraction
extends Interaction

var shop: Shop


func _on_setup() -> void:
	kind = "shop"
	shop = Shop.new()
	shop.shop_id = spec.get("shop_id", "%s_shop" % (site.definition.id if site else "anon"))
	shop.currency_id = spec.get("currency", GameManager.game_config.get("currencies", ["gold"])[0])
	shop.buys_intel = bool(spec.get("buys_intel", false))
	shop.intel_price_multiplier = float(spec.get("intel_price_multiplier", 1.0))
	shop.load_stock(spec.get("stock", []))


func _execute(holder: String, actor: Unit, _target) -> void:
	var tree := actor.get_tree() if actor and actor.is_inside_tree() else null
	var ui := tree.get_first_node_in_group("shop_ui") if tree else null
	if holder == GameManager.player_faction_id and ui and ui.has_method("open"):
		ui.open(shop, actor)
