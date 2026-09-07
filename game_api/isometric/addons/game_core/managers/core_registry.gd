## Single loader/store for every data-driven definition type in a game package.
##
## A "type" is registered once with its CoreDefinition subclass, file name and
## JSON array key. Loading a package then reads every registered file from the
## package folder. Systems query definitions by (type, id).
##
## Registered as the `CoreRegistry` autoload.
##
## API:
##   CoreRegistry.register_type("items", CoreItemDefinition, "items.json", "items")
##   CoreRegistry.load_package("res://games/my_game")
##   CoreRegistry.get_def("items", "rusty_sword")  -> CoreItemDefinition
##   CoreRegistry.all("units")                     -> Array[CoreDefinition]
##   CoreRegistry.with_tag("items", "melee")       -> Array[CoreDefinition]
##
## Adding a new data type = one CoreDefinition subclass + one register_type()
## call. Both graphics engines register extra, engine-specific types (maps,
## terrains, sites, POIs) against this same registry.
extends Node

signal package_loaded(base_path: String)
signal type_loaded(type_name: String, count: int)

class TypeInfo:
	var def_script: GDScript
	var file: String
	var key: String
	var optional: bool

var _types: Dictionary = {}      ## type_name -> TypeInfo
var _defs: Dictionary = {}       ## type_name -> {id -> CoreDefinition}
var _archetypes: Dictionary = {} ## type_name -> {id -> raw Dictionary}
var _base_path: String = ""


const ARCHETYPE_ROOT := "res://addons/game_core/data"


func _ready() -> void:
	_register_builtin_types()
	load_archetypes("places", ARCHETYPE_ROOT.path_join("places.json"), "places")


## The universal types both graphics engines share.
func _register_builtin_types() -> void:
	register_type("items", CoreItemDefinition, "items.json", "items", true)
	register_type("units", CoreUnitDefinition, "units.json", "units", true)
	register_type("intel", CoreIntelToken, "intel.json", "intel", true)
	register_type("factions", CoreFactionDefinition, "factions.json", "factions", true)
	register_type("places", CorePlaceDefinition, "places.json", "places", true)


# --- Archetypes ----------------------------------------------------------------
## Archetypes are reusable base entries a game's data can "extends". They are
## raw dictionaries (not built definitions), so a game may override any field.
##
##   CoreRegistry.load_archetypes("places", "res://addons/game_core/data/places.json", "places")
##   -> games can then write {"id": "hollowmere", "extends": "village"}
##
## A game can also ship its own library and extend the built-ins from it,
## e.g. {"id": "dragon_lair", "extends": "lair", "traits": {"flying_only": true}}.
func load_archetypes(type_name: String, path: String, key: String) -> int:
	var store: Dictionary = _archetypes.get(type_name, {})
	for entry in CoreDataLoader.load_json_array(path, key):
		if entry is Dictionary and str(entry.get("id", "")) != "":
			store[str(entry["id"])] = entry
	_archetypes[type_name] = store
	return store.size()


## Register a single archetype at runtime (no file needed).
func add_archetype(type_name: String, entry: Dictionary) -> void:
	var id := str(entry.get("id", ""))
	if id == "":
		push_error("CoreRegistry: archetype without id")
		return
	if not _archetypes.has(type_name):
		_archetypes[type_name] = {}
	_archetypes[type_name][id] = entry


func archetype_ids(type_name: String) -> Array:
	return _archetypes.get(type_name, {}).keys()


## Build a definition straight from an archetype, optionally overridden.
## Useful for procedural generation: spawn a "village" with no authored entry.
func instantiate(type_name: String, archetype_id: String, overrides: Dictionary = {}) -> CoreDefinition:
	if not _types.has(type_name):
		push_error("CoreRegistry: unregistered type '%s'" % type_name)
		return null
	if not _archetypes.get(type_name, {}).has(archetype_id):
		push_warning("CoreRegistry: unknown %s archetype '%s'" % [type_name, archetype_id])
	# Resolve the archetype's own "extends" chain first, so an archetype built
	# on another archetype (city -> town -> village) inherits the whole line.
	var base := _resolve_inheritance(type_name, archetype_id, {}, [])
	var merged := deep_merge(base, overrides)
	merged.erase("extends")
	if not merged.has("id"):
		merged["id"] = archetype_id
	return CoreDefinition.build(_types[type_name].def_script, merged)


func register_type(type_name: String, script: GDScript, file: String, key: String, optional: bool = false) -> void:
	var info := TypeInfo.new()
	info.def_script = script
	info.file = file
	info.key = key
	info.optional = optional
	_types[type_name] = info
	if not _defs.has(type_name):
		_defs[type_name] = {}


func registered_types() -> Array:
	return _types.keys()


## Load every registered type from a game package folder.
func load_package(base_path: String) -> void:
	_base_path = base_path
	for type_name in _types:
		load_type(type_name)
	package_loaded.emit(base_path)


func load_type(type_name: String) -> void:
	if not _types.has(type_name):
		push_error("CoreRegistry: unregistered type '%s'" % type_name)
		return
	var info: TypeInfo = _types[type_name]
	var path := _base_path.path_join(info.file)
	var store := {}

	if FileAccess.file_exists(path):
		# Two passes: collect the raw JSON so "extends" can reference an
		# archetype declared later in the file (or in a library loaded before).
		var raw_by_id := {}
		var order: Array[String] = []
		for entry in CoreDataLoader.load_json_array(path, info.key):
			if not (entry is Dictionary):
				continue
			var entry_id := str(entry.get("id", ""))
			if entry_id == "":
				push_error("CoreRegistry: %s entry without id in %s" % [type_name, path])
				continue
			if raw_by_id.has(entry_id):
				push_error("CoreRegistry: duplicate %s id '%s'" % [type_name, entry_id])
			raw_by_id[entry_id] = entry
			order.append(entry_id)

		for entry_id in order:
			var merged := _resolve_inheritance(type_name, entry_id, raw_by_id, [])
			store[entry_id] = CoreDefinition.build(info.def_script, merged)
	elif not info.optional:
		push_error("CoreRegistry: required data file missing: %s" % path)

	# Keep archetypes loaded earlier (e.g. the core library) available.
	var existing: Dictionary = _defs.get(type_name, {})
	for id in existing:
		if not store.has(id) and _archetypes.get(type_name, {}).has(id):
			store[id] = existing[id]
	_defs[type_name] = store
	type_loaded.emit(type_name, store.size())


## Resolve an entry's "extends" chain into one merged dictionary.
##
##   {"id": "hollowmere", "extends": "village", "owner": "greywood"}
##
## The parent may be another entry in the same file or a previously registered
## archetype. Dictionaries deep-merge (so a child can override one trait
## without restating the rest); all other values are replaced outright.
func _resolve_inheritance(type_name: String, entry_id: String, raw_by_id: Dictionary, seen: Array) -> Dictionary:
	var entry: Dictionary = raw_by_id.get(entry_id, _archetypes.get(type_name, {}).get(entry_id, {}))
	var parent_id := str(entry.get("extends", ""))
	if parent_id == "":
		return entry

	if entry_id in seen:
		push_error("CoreRegistry: circular 'extends' on %s '%s'" % [type_name, entry_id])
		return entry
	if not raw_by_id.has(parent_id) and not _archetypes.get(type_name, {}).has(parent_id):
		push_warning("CoreRegistry: %s '%s' extends unknown '%s'" % [type_name, entry_id, parent_id])
		return entry

	var base := _resolve_inheritance(type_name, parent_id, raw_by_id, seen + [entry_id])
	var merged := deep_merge(base, entry)
	merged["id"] = entry_id       # never inherit the parent's id
	merged.erase("extends")
	return merged


## Recursively merge [param over] onto [param base]. Nested dictionaries merge;
## arrays and scalars replace.
static func deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = deep_merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


## Register a definition created at runtime (procedural maps, generated items).
func add(type_name: String, def: CoreDefinition) -> void:
	if not _defs.has(type_name):
		_defs[type_name] = {}
	_defs[type_name][def.id] = def


func has(type_name: String, id: String) -> bool:
	return _defs.get(type_name, {}).has(id)


func get_def(type_name: String, id: String) -> CoreDefinition:
	var d = _defs.get(type_name, {}).get(id)
	if d == null and id != "":
		push_warning("CoreRegistry: unknown %s '%s'" % [type_name, id])
	return d


func all(type_name: String) -> Array:
	return _defs.get(type_name, {}).values()


func ids(type_name: String) -> Array:
	return _defs.get(type_name, {}).keys()


func with_tag(type_name: String, tag: String) -> Array:
	var out := []
	for d in all(type_name):
		if d.has_tag(tag):
			out.append(d)
	return out


## Filter any type by an arbitrary property value, e.g. filter("units", "role", "monster").
func filter(type_name: String, property: String, value) -> Array:
	var out := []
	for d in all(type_name):
		if property in d and d.get(property) == value:
			out.append(d)
	return out


func clear() -> void:
	for t in _defs:
		_defs[t] = {}
