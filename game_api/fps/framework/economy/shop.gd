## Shop model (no UI). Stock entries may be intel-gated so knowledge unlocks
## trade; intel tokens themselves can be sold if they have a value.
class_name Shop
extends RefCounted

var shop_id: String = ""
var currency_id: String = "gold"
var stock: Array[Dictionary] = []   ## {item, price, stock(-1 = infinite), requires}


func load_stock(entries: Array) -> void:
	stock.clear()
	for e in entries:
		var d: Dictionary = e.duplicate()
		d["stock"] = int(d.get("stock", -1))
		stock.append(d)
	_restore()


func available_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in stock:
		if e["stock"] == 0:
			continue
		var req: Dictionary = e.get("requires", {})
		if req.is_empty() or IntelRegistry.evaluate(req):
			out.append(e)
	return out


static func inventory_of(node: Node) -> Inventory:
	if node is Actor:
		return (node as Actor).inventory
	return node.get_node_or_null("Inventory") as Inventory if node else null


func buy(item_id: String, buyer: Node) -> bool:
	var inv := inventory_of(buyer)
	if inv == null:
		EventBus.purchase_failed.emit(shop_id, item_id, "no_inventory")
		return false
	for e in available_entries():
		if e["item"] != item_id:
			continue
		var price := int(e["price"])
		if not inv.spend_currency(currency_id, price):
			EventBus.purchase_failed.emit(shop_id, item_id, "insufficient_funds")
			return false
		inv.add_item(item_id, 1)
		if e["stock"] > 0:
			e["stock"] -= 1
		_persist()
		EventBus.purchase_completed.emit(shop_id, item_id, price)
		return true
	EventBus.purchase_failed.emit(shop_id, item_id, "not_available")
	return false


## Sell intel to an informant/broker shop.
func sell_intel(token_id: String, seller: Node) -> bool:
	var tok := IntelRegistry.get_token(token_id)
	var inv := inventory_of(seller)
	if tok == null or inv == null or tok.value <= 0:
		return false
	inv.add_currency(currency_id, int(tok.value * tok.reliability))
	return true


# Stock counts persist in GameManager flags-adjacent state via MapManager states
# keyed by shop id, so limited stock stays sold-out across visits.
func _persist() -> void:
	var st := MapManager.get_map_state("__shops__")
	var counts := {}
	for e in stock:
		counts[e["item"]] = e["stock"]
	st[shop_id] = counts


func _restore() -> void:
	var st := MapManager.get_map_state("__shops__")
	var counts: Dictionary = st.get(shop_id, {})
	for e in stock:
		if counts.has(e["item"]):
			e["stock"] = int(counts[e["item"]])
