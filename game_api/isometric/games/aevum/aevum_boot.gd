## Aevum-specific rules, loaded by GameManager via game.json "boot_script".
## The shared platform (hex grid, simultaneous turns, factions, fog, intel,
## combat, sites) is generic; this file supplies the handful of rules that are
## Aevum-only and have no engine equivalent. See docs/PORT_MAP.md.
##
##  * Clan select  – seed picks rules.aevum.active_clans of the 12 clan
##    factions before the run starts (StartupEngine.select_active_clans).
##  * Shrines      – meditating is timed by mantra knowledge (1 / 3 / 12 turns),
##    grants a permanent clan-wide +1 / meditator +2 stat bonus, and Avatar
##    status once a clan has meditated every active shrine.
##  * Sacred ground – no combat within radius of any shrine (CombatResolver
##    swap, see aevum_combat_resolver.gd).
##  * The Dragon    – wakes when a Seeker enters radius of the Veil; the egg
##    can only be picked up post-Avatar and makes its carrier unable to attack.
##  * Victory       – carrying the egg back to your own enclave wins the game.
extends Node

const SHRINE_CATEGORY := "shrine"
const VEIL_ID := "the_veil"
const EGG_ID := "dragon_egg"

var _meditating: Dictionary = {}   ## unit_id -> {"clan": String, "shrine": String, "turns_left": int}
var _dragon_awake: bool = false


func boot(_gm: Node) -> void:
	add_to_group("aevum_boot")
	_select_active_clans()
	CombatResolver.active = load("res://games/aevum/aevum_combat_resolver.gd").new()
	EventBus.ability_used.connect(_on_ability_used)
	EventBus.turn_phase_changed.connect(_on_turn_phase)
	EventBus.unit_moved.connect(_on_unit_moved)
	EventBus.item_acquired.connect(_on_item_acquired)
	EventBus.unit_spawned.connect(_on_unit_spawned)


# --- Clan select: seed picks N of 12 clan factions ------------------------------------

## Deterministically keep only rules.aevum.active_clans clan factions (plus
## the always-on Wilds/Dragon), before FactionRegistry.instantiate_all() runs.
## Mirrors the Python StartupEngine.select_active_clans(seed, n) contract.
func _select_active_clans() -> void:
	var n := int(GameManager.rule("aevum.active_clans", 8))
	var clan_ids: Array[String] = []
	for id in FactionRegistry.definitions:
		var def: Faction.FactionDefinition = FactionRegistry.definitions[id]
		if "clan" in def.tags:
			clan_ids.append(id)
	if clan_ids.size() <= n:
		return
	clan_ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameManager.game_config.get("seed", 0))
	_seeded_shuffle(clan_ids, rng)
	var keep: Dictionary = {}
	var player_id: String = GameManager.player_faction_id
	keep[player_id] = true   # the human's clan always plays, matching the Python contract
	for id in clan_ids:
		if keep.size() >= n:
			break
		keep[id] = true
	for id in clan_ids:
		if not keep.has(id):
			FactionRegistry.definitions.erase(id)


## Deterministic Fisher-Yates so the same seed always picks the same clans.
func _seeded_shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --- Shrines: timed meditation, clan-wide bonus, Avatar status -----------------------

## The "meditate" ability (units.json) just flags intent; the actual multi-turn
## process is tracked here so it can be interrupted by leaving the hex.
func _on_ability_used(unit_id: String, ability_id: String, _target) -> void:
	if ability_id != "meditate":
		return
	var unit := EntityRegistry.get_unit(unit_id)
	if unit == null:
		return
	var site := WorldManager.site_at(unit.coord)
	if site == null or site.definition.category != SHRINE_CATEGORY:
		return
	if _meditating.has(unit_id):
		return
	var faction := FactionRegistry.get_faction(unit.faction_id)
	if faction and faction.has_flag("meditated_%s" % site.id()):
		return   # already done; nothing to repeat
	_meditating[unit_id] = {
		"clan": unit.faction_id, "shrine": site.id(),
		"turns_left": _meditation_turns(unit.faction_id, site.id()),
	}
	if unit.faction_id == GameManager.player_faction_id:
		EventBus.notification.emit("You begin to meditate at the %s." % site.definition.display_name, "info")


## Direct knowledge of the mantra: 1 turn. Reasonable secondhand belief (a
## corroborated but imperfect token): 3 turns. No knowledge at all: 12 turns.
## Mirrors shrines.json's meditation_methods / engine_mantras.get_meditation_turns.
func _meditation_turns(faction_id: String, shrine_id: String) -> int:
	var clan := str(WorldManager.get_site_definition(shrine_id).metadata.get("clan", ""))
	var mantra_id := "mantra_%s" % clan
	var turns_cfg: Dictionary = GameManager.rule("aevum.meditation_turns", {})
	var tok := IntelRegistry.get_token(faction_id, mantra_id)
	if tok and tok.reliability >= 0.7:
		return int(turns_cfg.get("direct", 1))
	if tok and tok.reliability >= 0.3:
		return int(turns_cfg.get("secondhand", 3))
	return int(turns_cfg.get("unknown", 12))


func _tick_meditation() -> void:
	for unit_id in _meditating.keys():
		var unit := EntityRegistry.get_unit(unit_id)
		var st: Dictionary = _meditating[unit_id]
		if unit == null or not unit.alive:
			_meditating.erase(unit_id)
			continue
		var site := WorldManager.site_at(unit.coord)
		if site == null or site.id() != st["shrine"]:
			_meditating.erase(unit_id)   # left the hex: meditation lost, must restart
			continue
		st["turns_left"] -= 1
		if st["turns_left"] <= 0:
			_complete_meditation(unit, site)
			_meditating.erase(unit_id)


func _complete_meditation(unit: Unit, site: Site) -> void:
	var faction := FactionRegistry.get_faction(unit.faction_id)
	if faction == null:
		return
	faction.set_flag("meditated_%s" % site.id(), true)
	var stat := str(site.definition.metadata.get("bonus_stat", "strength"))
	_apply_shrine_bonus(faction, stat, 1.0, "shrine:%s" % site.id())
	unit.stats.add_modifier("shrine_self:%s" % site.id(), {stat: 2.0})
	if unit.faction_id == GameManager.player_faction_id:
		EventBus.notification.emit("Meditation complete: %s gains +%s." %
			[faction.definition.display_name, site.definition.metadata.get("bonus_label", stat)], "success")
	_check_avatar(faction)


## +[param delta] to [param stat] for every current unit of the faction, and
## recorded so units spawned *after* this shrine is claimed inherit it too.
func _apply_shrine_bonus(faction: Faction, stat: String, delta: float, source: String) -> void:
	faction.flags["bonus_%s" % source] = {"stat": stat, "delta": delta}
	for u in EntityRegistry.units_of(faction.id):
		u.stats.add_modifier(source, {stat: delta})


func _check_avatar(faction: Faction) -> bool:
	if faction.has_flag("is_avatar"):
		return true
	if not bool(GameManager.rule("aevum.avatar_requires_all_shrines", true)):
		return false
	for site in WorldManager.sites.values():
		if site.definition.category == SHRINE_CATEGORY and not faction.has_flag("meditated_%s" % site.id()):
			return false
	faction.set_flag("is_avatar", true)
	if faction.id == GameManager.player_faction_id:
		EventBus.notification.emit("%s has become Avatar!" % faction.definition.display_name, "success")
	return true


## New units of a clan that already claimed shrine bonuses inherit them.
func _on_unit_spawned(unit_id: String, faction_id: String, _coord: Vector2i) -> void:
	var faction := FactionRegistry.get_faction(faction_id)
	var unit := EntityRegistry.get_unit(unit_id)
	if faction == null or unit == null:
		return
	for key in faction.flags:
		if str(key).begins_with("bonus_shrine:"):
			var b: Dictionary = faction.flags[key]
			unit.stats.add_modifier(str(key).trim_prefix("bonus_"), {b["stat"]: b["delta"]})


# --- The Dragon: wake on approach, guard the egg ---------------------------------------

func _on_turn_phase(_turn: int, phase: int) -> void:
	if phase != TurnManager.Phase.RESOLVE:
		return
	_tick_meditation()
	_tick_dragon()


func _veil_site() -> Site:
	return WorldManager.sites.get(VEIL_ID)


func _dragon_unit() -> Unit:
	for u in EntityRegistry.units_of("dragon"):
		return u
	return null


func _tick_dragon() -> void:
	if _dragon_awake:
		return
	var veil := _veil_site()
	var dragon := _dragon_unit()
	if veil == null or dragon == null:
		return
	var radius := int(GameManager.rule("aevum.dragon_wake_radius", 8))
	for u in EntityRegistry.units_on_map(veil.definition.map_id):
		if "seeker" in u.definition.tags and WorldManager.world.topology.distance(u.coord, veil.coord) <= radius:
			_wake_dragon(dragon)
			return


func _wake_dragon(dragon: Unit) -> void:
	_dragon_awake = true
	dragon.flags["state"] = "awake"
	EventBus.notification.emit("Something vast stirs beneath the Veil.", "warning")


## Ancient armour: the first N damage per turn is negated entirely (a
## threshold applied before defence, per monsters.json's dragon passive).
## Tracked per-turn on the dragon's own flags so it resets every RESOLVE.
func dragon_negate_damage(dragon: Unit, amount: int) -> int:
	var cap := int(GameManager.rule("aevum.dragon_damage_negated_per_turn", 5))
	var used := int(dragon.flags.get("armour_used_turn", -1))
	var used_amount := int(dragon.flags.get("armour_used_amount", 0)) if used == GameClock.turn else 0
	var negate := mini(amount, maxi(0, cap - used_amount))
	dragon.flags["armour_used_turn"] = GameClock.turn
	dragon.flags["armour_used_amount"] = used_amount + negate
	return maxi(0, amount - negate)


# --- The egg: pickup gate, move penalty, cannot attack while carried ------------------

func _on_item_acquired(owner_id: String, item_id: String, _count: int) -> void:
	if item_id != EGG_ID:
		return
	var unit := EntityRegistry.get_unit(owner_id)
	if unit == null:
		return
	unit.flags["carrying_egg"] = true
	unit.flags["cannot_attack"] = true
	unit.stats.add_modifier("egg_burden", {"moves": -float(GameManager.rule("aevum.egg_carrier_move_penalty", 1))})


## Meditation is interrupted by movement (Interaction/ability flow only spends
## AP; walking away is what actually breaks the multi-turn hold), and the win
## condition is checked every time a unit carrying the egg steps onto a tile.
func _on_unit_moved(unit_id: String, _from: Vector2i, to: Vector2i) -> void:
	if _meditating.has(unit_id):
		var st: Dictionary = _meditating[unit_id]
		var site := WorldManager.site_at(to)
		if site == null or site.id() != st["shrine"]:
			_meditating.erase(unit_id)
	var unit := EntityRegistry.get_unit(unit_id)
	if unit == null or not unit.flags.get("carrying_egg", false):
		return
	var site := WorldManager.site_at(to)
	if site == null or site.definition.category != "enclave":
		return
	if str(site.definition.metadata.get("clan", "")) != unit.faction_id:
		return
	if _contested(unit.faction_id, to):
		return   # "uncontested": an enemy unit adjacent to the enclave blocks the win
	GameManager.end_game(unit.faction_id, "dragon_egg_delivered")


## The egg must be carried home *uncontested* — no hostile unit adjacent to
## the delivering enclave hex.
func _contested(faction_id: String, coord: Vector2i) -> bool:
	var world := WorldManager.world
	if world == null:
		return false
	for n in world.topology.ring(coord, 1):
		var occ := world.unit_at(n)
		if occ and occ.alive and FactionRegistry.are_hostile(faction_id, occ.faction_id):
			return true
	return false


# --- Tech / building gate --------------------------------------------------------------

## Aevum has a 5-tier building chain and a 3-tier tech tree gating unit
## production (buildings.json / technologies.json). There is no production-
## queue UI in the shared platform yet, so this is exposed as a pure query any
## future AI/build-menu code calls before spawning a unit — not itself a
## spawner. Buildings/techs are tracked as faction flags "building_<id>" /
## "tech_<id>", set by whatever UI or AI logic completes them.
func can_produce(faction_id: String, unit_def_id: String) -> bool:
	var def := EntityRegistry.get_definition(unit_def_id)
	var faction := FactionRegistry.get_faction(faction_id)
	if def == null or faction == null:
		return false
	var meta := def.metadata
	if meta.has("requires_building") and meta["requires_building"] != null:
		if not faction.has_flag("building_%s" % meta["requires_building"]):
			return false
	if meta.has("requires_tech") and meta["requires_tech"] != null:
		if not faction.has_flag("tech_%s" % meta["requires_tech"]):
			return false
	if bool(meta.get("requires_avatar", false)) and not faction.has_flag("is_avatar"):
		return false
	if meta.has("max_per_clan") and meta["max_per_clan"] != null:
		if EntityRegistry.count_units(faction_id, unit_def_id) >= int(meta["max_per_clan"]):
			return false
	return faction.can_afford(def.cost)
