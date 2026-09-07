## Presents a Shop for the player's hero. Registered in group "shop_ui".
extends PanelContainer

@onready var _title: Label = %ShopTitle
@onready var _stock: VBoxContainer = %StockList
@onready var _close_btn: Button = %CloseShop

var _shop: Shop = null
var _buyer: Unit = null


func _ready() -> void:
	add_to_group("shop_ui")
	visible = false
	_close_btn.pressed.connect(close)


func open(shop: Shop, buyer: Unit) -> void:
	_shop = shop
	_buyer = buyer
	visible = true
	GameManager.set_state(GameManager.State.DIALOGUE)
	_render()


func _render() -> void:
	for c in _stock.get_children():
		c.queue_free()
	if _shop == null or _buyer == null:
		return
	var f := FactionRegistry.get_faction(_buyer.faction_id)
	_title.text = "%s — %s: %d" % [_shop.shop_id, _shop.currency_id, int(f.get_resource(_shop.currency_id)) if f else 0]
	for e in _shop.available_entries(_buyer.faction_id):
		var def := ItemRegistry.get_definition(e["item"])
		var b := Button.new()
		b.text = "%s — %d %s%s" % [def.display_name if def else e["item"], int(e["price"]), _shop.currency_id, "" if e["stock"] < 0 else " (%d left)" % e["stock"]]
		b.pressed.connect(func():
			_shop.buy(e["item"], _buyer)
			_render())
		_stock.add_child(b)
	if _shop.buys_intel:
		var j := IntelRegistry.journal_for(_buyer.faction_id)
		for tok in j.tokens.values():
			if tok.tradeable and tok.value > 0:
				var b := Button.new()
				b.text = "Sell intel: %s (+%d)" % [tok.title, IntelRegistry.trade_value(_buyer.faction_id, tok.id)]
				b.pressed.connect(func():
					_shop.sell_intel(tok.id, _buyer.faction_id)
					_render())
				_stock.add_child(b)


func close() -> void:
	visible = false
	_shop = null
	_buyer = null
	if GameManager.state == GameManager.State.DIALOGUE:
		GameManager.set_state(GameManager.State.PLAYING)
