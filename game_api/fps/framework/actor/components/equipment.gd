## Equipment slots. Equipping pushes the item's stats into Stats (source
## "equip:<slot>"), its passive effects into StatusEffects, and its granted
## abilities into AbilityCaster. Equip can be gated by intel (`requires`) and
## stats (`requires_stats`) — learning how to wield a relic is part of the game.
##
## Slots come from game.json "equip_slots" (default list below).
class_name Equipment
extends ActorComponent

signal equipped(slot: String, inst: ItemInstance)
signal unequipped(slot: String, inst: ItemInstance)

const DEFAULT_SLOTS := ["main_hand", "off_hand", "head", "body", "hands", "feet", "ring_1", "ring_2", "amulet", "ammo"]
const RING_SLOTS := ["ring_1", "ring_2"]

var slots: Array[String] = []
var equipped_items: Dictionary = {}   ## slot -> ItemInstance


func _actor_ready() -> void:
	slots.assign(GameManager.game_config.get("equip_slots", DEFAULT_SLOTS))


func _definition_applied(def: ActorDefinition) -> void:
	for slot in def.equipment:
		var item_def := DefinitionRegistry.get_def("items", str(def.equipment[slot])) as ItemDefinition
		if item_def:
			var inst := ItemInstance.create(item_def)
			_apply_slot(slot, inst)


# --- Rules -------------------------------------------------------------------

## Resolve the concrete slot an item goes into ("ring" -> first free ring slot).
func resolve_slot(inst: ItemInstance) -> String:
	var s := inst.def.equip_slot
	if s == "ring":
		for r in RING_SLOTS:
			if r in slots and not equipped_items.has(r):
				return r
		return RING_SLOTS[0]
	return s if s in slots else ""


func can_equip(inst: ItemInstance) -> Dictionary:
	if not inst.def.is_equippable():
		return {"ok": false, "reason": "not_equippable"}
	if resolve_slot(inst) == "":
		return {"ok": false, "reason": "no_slot"}
	if not inst.def.requires.is_empty() and not IntelRegistry.evaluate(inst.def.requires):
		return {"ok": false, "reason": "unknown_use"}   # you don't yet know how to wield it
	for stat in inst.def.requires_stats:
		if actor.stat(stat) < float(inst.def.requires_stats[stat]):
			return {"ok": false, "reason": "stat:%s" % stat}
	return {"ok": true, "reason": ""}


## Equip from the actor's inventory (item is removed from inventory).
func equip(inst: ItemInstance) -> bool:
	var check := can_equip(inst)
	if not check["ok"]:
		EventBus.notification.emit(_reason_text(check["reason"]), "locked")
		return false
	var slot := resolve_slot(inst)
	if actor.inventory:
		actor.inventory.remove_instance(inst)
	# Two-handed weapons clear the off hand; off-hand items clear a 2H main hand.
	if inst.def.two_handed and slot == "main_hand":
		unequip("off_hand")
	if slot == "off_hand" and equipped_items.has("main_hand") and equipped_items["main_hand"].def.two_handed:
		unequip("main_hand")
	unequip(slot)
	_apply_slot(slot, inst)
	return true


func unequip(slot: String) -> ItemInstance:
	if not equipped_items.has(slot):
		return null
	var inst: ItemInstance = equipped_items[slot]
	equipped_items.erase(slot)
	var source := "equip:%s" % slot
	if actor.stats:
		actor.stats.remove_modifiers(source)
	if actor.status_effects:
		actor.status_effects.remove_from_source(source)
	if actor.ability_caster:
		actor.ability_caster.remove_granted(source)
	if actor.inventory:
		actor.inventory.add_instance(inst)
	unequipped.emit(slot, inst)
	EventBus.equipment_changed.emit(actor, slot, "")
	return inst


func _apply_slot(slot: String, inst: ItemInstance) -> void:
	equipped_items[slot] = inst
	var source := "equip:%s" % slot
	if actor.stats:
		actor.stats.set_modifiers(source, inst.total_stats(), inst.total_stats_percent())
	if actor.status_effects:
		for e in inst.total_effects():
			actor.status_effects.apply(e, source)
	if actor.ability_caster:
		for a in inst.total_abilities():
			actor.ability_caster.grant(a, source)
	equipped.emit(slot, inst)
	EventBus.equipment_changed.emit(actor, slot, inst.def.id)


# --- Queries -----------------------------------------------------------------

func get_item(slot: String) -> ItemInstance:
	return equipped_items.get(slot)


func main_weapon() -> ItemInstance:
	return equipped_items.get("main_hand")


## Sum of resistances across equipped items (+ affixes if identified).
func total_resistances() -> Dictionary:
	var out := {}
	for inst in equipped_items.values():
		for t in inst.def.resistances:
			out[t] = out.get(t, 0.0) + float(inst.def.resistances[t])
	return out


func all_procs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for inst in equipped_items.values():
		out.append_array(inst.total_procs())
	return out


func _reason_text(reason: String) -> String:
	match reason:
		"unknown_use": return "You don't yet understand how to use this."
		"no_slot": return "You can't equip that."
		"not_equippable": return "That isn't equipment."
		_:
			if reason.begins_with("stat:"):
				return "You lack the %s to use this." % reason.trim_prefix("stat:")
			return "Cannot equip."


# --- Persistence -------------------------------------------------------------

func to_save_data() -> Dictionary:
	var out := {}
	for slot in equipped_items:
		out[slot] = equipped_items[slot].to_dict()
	return {"slots": out}


func from_save_data(d: Dictionary) -> void:
	for slot in equipped_items.keys():
		var inst: ItemInstance = equipped_items[slot]
		equipped_items.erase(slot)
		var source := "equip:%s" % slot
		if actor.stats: actor.stats.remove_modifiers(source)
		if actor.status_effects: actor.status_effects.remove_from_source(source)
		if actor.ability_caster: actor.ability_caster.remove_granted(source)
	for slot in d.get("slots", {}):
		var inst := ItemInstance.from_dict(d["slots"][slot])
		if inst:
			_apply_slot(slot, inst)
