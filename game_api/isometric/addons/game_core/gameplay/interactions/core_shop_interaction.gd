## Opens a shop / trading session.
##
##   {"kind": "shop", "shop": "general_goods", "stock": ["healing_herb", "rope"],
##    "buys": ["pelt"], "markup": 1.2, "requires": {"has": "met_innkeeper"}}
##
## Stock may itself be intel-gated, which is how "the smuggler only sells you
## the chart once you know the password" works. The UI is engine-specific.
class_name CoreShopInteraction
extends CoreInteraction

signal opened(holder: String, shop_id: String)


func _on_setup() -> void:
	kind = "shop"


func _execute(holder: String, actor, _target) -> void:
	var shop_spec := spec.duplicate()
	shop_spec["stock"] = visible_stock(holder)
	if CoreContext.adapter.open_shop(holder, shop_spec, actor):
		opened.emit(holder, str(spec.get("shop", owner_id)))


## Stock filtered by any per-entry intel gate. Entries may be a plain item id
## or {"item": "id", "price": 50, "requires": {...}}.
func visible_stock(holder: String) -> Array:
	var out := []
	for entry in spec.get("stock", []):
		if entry is Dictionary:
			var req: Dictionary = entry.get("requires", {})
			if req.is_empty() or CoreIntel.evaluate(req, holder):
				out.append(entry)
		else:
			out.append(entry)
	return out
