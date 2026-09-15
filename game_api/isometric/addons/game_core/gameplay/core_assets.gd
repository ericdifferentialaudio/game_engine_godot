## Physical assets: things that exist in quantity and can be gained, spent,
## traded or lost.
##
## Registered as the `CoreAssets` autoload.
##
## The counterpart to `CoreKnowledge`. Knowledge is boolean and (by default)
## permanent; assets are counted and volatile. The two are deliberately separate
## systems because they behave differently — you cannot spend half a secret, and
## you cannot "already know" a third coin.
##
## This is a **holder-scoped facade over `CoreInventory`**, not a second store,
## so items granted in a conversation are the same items the rest of the game
## already understands (weight, stacking, equipment, `requires` gates).
##
## One vocabulary for two underlying kinds: `CoreItemDefinition.category`
## decides whether an id is currency or an object, so narrative authors write
## `spend_asset("zorkmid", 3)` and `give_asset("brass_lantern", 1)` without
## caring which is which.
class_name CoreAssetStore
extends Node

## A holder gained assets.
signal asset_gained(holder: String, asset_id: String, amount: int, total: int)
## A holder lost assets (spent, traded, stolen, destroyed).
signal asset_lost(holder: String, asset_id: String, amount: int, total: int)
## A spend/lose was refused because the holder did not have enough.
signal asset_refused(holder: String, asset_id: String, amount: int, held: int)

var default_holder: String = "player"

## holder -> CoreInventory
var _inventories: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
	_inventories.clear()


## Get (creating if needed) a holder's inventory. Games that already build their
## own inventory for an actor should hand it over with [method bind_inventory]
## so both views stay in sync.
func inventory_for(holder: String = "") -> CoreInventory:
	var who := _holder(holder)
	if not _inventories.has(who):
		_inventories[who] = CoreInventory.new(who, who)
	return _inventories[who]


## Adopt an existing inventory (e.g. the player actor's) as this holder's
## asset store, so narrative grants land in the real inventory.
func bind_inventory(holder: String, inventory: CoreInventory) -> void:
	if inventory != null:
		_inventories[_holder(holder)] = inventory


## Is this id a currency rather than a carried object?
func is_currency(asset_id: String) -> bool:
	var def := CoreRegistry.get_def("items", asset_id) as CoreItemDefinition
	if def == null:
		# Unknown ids are treated as currency: games commonly declare abstract
		# counters ("favours", "reputation points") in game.json without an
		# items.json entry, and that should not hard-fail a conversation.
		return true
	return def.category == CoreItemDefinition.Category.CURRENCY


# --- Queries ------------------------------------------------------------------

## How many of this asset the holder has.
func amount(asset_id: String, holder: String = "") -> int:
	var inv := inventory_for(holder)
	return inv.currency(asset_id) if is_currency(asset_id) else inv.count(asset_id)


## Does the holder have at least [param required] of this asset?
func has(asset_id: String, required: int = 1, holder: String = "") -> bool:
	return amount(asset_id, holder) >= required


# --- Mutations ----------------------------------------------------------------

## Grant assets. Returns true if anything was actually added (an inventory can
## refuse on weight/slots/uniqueness).
func give(asset_id: String, count: int = 1, holder: String = "") -> bool:
	if count <= 0:
		return false
	var who := _holder(holder)
	var inv := inventory_for(who)
	var ok := true
	if is_currency(asset_id):
		inv.add_currency(asset_id, count)
	else:
		ok = inv.add_item(asset_id, count)
	if ok:
		asset_gained.emit(who, asset_id, count, amount(asset_id, who))
	return ok


## Pay assets away in exchange for something. Fails (changing nothing) when the
## holder cannot afford it, so it is safe to call as a transaction guard.
func spend(asset_id: String, count: int = 1, holder: String = "") -> bool:
	return _take(asset_id, count, holder)


## Remove assets with nothing given back — theft, decay, a failed gamble.
## Identical mechanics to [method spend]; the separate name is for intent, so
## narrative reads honestly and UI can react differently.
func lose(asset_id: String, count: int = 1, holder: String = "") -> bool:
	return _take(asset_id, count, holder)


## Move assets between holders. All-or-nothing: if the giver cannot afford it,
## or the receiver cannot accept it, nothing moves.
func transfer(asset_id: String, count: int, from_holder: String, to_holder: String) -> bool:
	if not has(asset_id, count, from_holder):
		asset_refused.emit(_holder(from_holder), asset_id, count, amount(asset_id, from_holder))
		return false
	if not give(asset_id, count, to_holder):
		return false
	if not _take(asset_id, count, from_holder):
		# Roll back so assets are never duplicated.
		_take(asset_id, count, to_holder)
		return false
	return true


## Every asset id the holder holds, with counts.
func all_assets(holder: String = "") -> Dictionary:
	var inv := inventory_for(holder)
	var out := {}
	for id in inv.items:
		out[id] = inv.items[id]
	for id in inv.currencies:
		out[id] = inv.currencies[id]
	return out


# --- Persistence --------------------------------------------------------------

func to_save_data() -> Dictionary:
	var out := {}
	for holder in _inventories:
		out[holder] = _inventories[holder].to_save_data()
	return out


func from_save_data(d: Dictionary) -> void:
	for holder in d:
		inventory_for(str(holder)).from_save_data(d[holder])


# --- Internals ----------------------------------------------------------------

func _take(asset_id: String, count: int, holder: String) -> bool:
	if count <= 0:
		return false
	var who := _holder(holder)
	var held := amount(asset_id, who)
	if held < count:
		asset_refused.emit(who, asset_id, count, held)
		return false
	var inv := inventory_for(who)
	var ok := inv.spend_currency(asset_id, count) if is_currency(asset_id) \
			else inv.remove_item(asset_id, count)
	if ok:
		asset_lost.emit(who, asset_id, count, amount(asset_id, who))
	return ok


func _holder(holder: String) -> String:
	return holder if holder != "" else default_holder
