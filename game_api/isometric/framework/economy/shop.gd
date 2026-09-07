## Shop model (no UI). Stock entries may be intel-gated so knowledge unlocks
## trade; intel tokens themselves can be sold to broker shops. Purchases are
## paid from the buying faction's resources; goods go to the buying hero's
## inventory (or the faction stockpile for non-heroes).
class_name Shop
extends RefCounted

var shop_id: String = ""
var currency_id: String = "gold"
var stock: Array[Dictionary] = []   ## {item, price, stock(-1 = infinite), requires}
var buys_intel: bool = false
var intel_price_multiplier: float = 1.0


func load_stock(entries: Array) -> void:
	stock.clear()
	for e in entries:
		var d: Dictionary = e.duplicate()
		d["stock"] = int(d.get("stock", -1))
		stock.append(d)
	_restore()


func available_entries(holder: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in stock:
		if e["stock"] == 0:
			continue
		var req: Dictionary = e.get("requires", {})
		if req.is_empty() or IntelRegistry.evaluate(req, holder):
			out.append(e)
	return out


func buy(item_id: String, buyer: Unit) -> bool:
	var faction := FactionRegistry.get_faction(buyer.faction_id) if buyer else null
	if faction == null:
		EventBus.purchase_failed.emit(shop_id, item_id, "no_faction")
		return false
	for e in available_entries(faction.id):
		if e["item"] != item_id:
			continue
		var price := int(e["price"])
		if not faction.spend_resource(currency_id, price):
			EventBus.purchase_failed.emit(shop_id, item_id, "insufficient_funds")
			return false
		var inv: Inventory = buyer.inventory if buyer.is_hero() else faction.stockpile
		if not inv.add_item(item_id, 1):
			faction.add_resource(currency_id, price)
			EventBus.purchase_failed.emit(shop_id, item_id, "inventory_full")
			return false
		if e["stock"] > 0:
			e["stock"] -= 1
		_persist()
		EventBus.purchase_completed.emit(shop_id, item_id, price)
		return true
	EventBus.purchase_failed.emit(shop_id, item_id, "not_available")
	return false


## Sell an item back at a fraction of its value.
func sell(item_id: String, seller: Unit) -> bool:
	var faction := FactionRegistry.get_faction(seller.faction_id)
	var def := ItemRegistry.get_definition(item_id)
	if faction == null or def == null:
		return false
	var inv: Inventory = seller.inventory if seller.inventory.has_item(item_id) else faction.stockpile
	if not inv.remove_item(item_id, 1):
		return false
	faction.add_resource(currency_id, int(def.value * float(GameManager.rule("economy.sell_ratio", 0.5))))
	return true


## Sell intel to an informant/broker shop. Returns the price paid (0 = refused).
func sell_intel(token_id: String, seller_faction: String, exclusive: bool = false) -> int:
	if not buys_intel:
		return 0
	var tok := IntelRegistry.get_token(seller_faction, token_id)
	var faction := FactionRegistry.get_faction(seller_faction)
	if tok == null or faction == null or not tok.tradeable or tok.value <= 0:
		return 0
	var price := int(round(IntelRegistry.trade_value(seller_faction, token_id) * intel_price_multiplier))
	if price <= 0:
		return 0
	faction.add_resource(currency_id, price)
	var st := _shop_state()
	if not st.has("bought_intel"):
		st["bought_intel"] = []
	if token_id in st["bought_intel"]:
		return 0
	st["bought_intel"].append(token_id)
	if exclusive:
		IntelRegistry.forget(seller_faction, token_id)
	EventBus.intel_traded.emit(seller_faction, shop_id, token_id, price)
	return price


func _shop_state() -> Dictionary:
	var st := WorldManager.get_map_state("__shops__")
	if not st.has(shop_id):
		st[shop_id] = {}
	return st[shop_id]


func _persist() -> void:
	var counts := {}
	for e in stock:
		counts[e["item"]] = e["stock"]
	_shop_state()["counts"] = counts


func _restore() -> void:
	var counts: Dictionary = _shop_state().get("counts", {})
	for e in stock:
		if counts.has(e["item"]):
			e["stock"] = int(counts[e["item"]])
