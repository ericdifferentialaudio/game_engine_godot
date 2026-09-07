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

var _types: Dictionary = {}   ## type_name -> TypeInfo
var _defs: Dictionary = {}    ## type_name -> {id -> CoreDefinition}
var _base_path: String = ""


func _ready() -> void:
	_register_builtin_types()


## The universal types both graphics engines share.
func _register_builtin_types() -> void:
	register_type("items", CoreItemDefinition, "items.json", "items", true)
	register_type("units", CoreUnitDefinition, "units.json", "units", true)
	register_type("intel", CoreIntelToken, "intel.json", "intel", true)
	register_type("factions", CoreFactionDefinition, "factions.json", "factions", true)


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
		for entry in CoreDataLoader.load_json_array(path, info.key):
			if not (entry is Dictionary):
				continue
			var def := CoreDefinition.build(info.def_script, entry)
			if def.id == "":
				push_error("CoreRegistry: %s entry without id in %s" % [type_name, path])
				continue
			if store.has(def.id):
				push_error("CoreRegistry: duplicate %s id '%s'" % [type_name, def.id])
			store[def.id] = def
	elif not info.optional:
		push_error("CoreRegistry: required data file missing: %s" % path)
	_defs[type_name] = store
	type_loaded.emit(type_name, store.size())


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
