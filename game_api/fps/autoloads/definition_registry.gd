## Single loader/store for every data-driven definition type in a game package.
##
## A "type" is registered once with its Definition subclass, file name and JSON
## array key. Loading a game package then reads every registered file from
## games/<id>/. Systems query definitions by (type, id).
##
##   DefinitionRegistry.get_def("items", "rusty_sword")   -> ItemDefinition
##   DefinitionRegistry.all("actors")                     -> Array[Definition]
##
## Adding a new data type = one Definition subclass + one register_type() line
## + one JSON schema + validator coverage in tools/validate_data.py.
extends Node

class TypeInfo:
	var def_script: GDScript
	var file: String
	var key: String
	var optional: bool

var _types: Dictionary = {}   ## type_name -> TypeInfo
var _defs: Dictionary = {}    ## type_name -> {id -> Definition}
var _base_path: String = ""


func _ready() -> void:
	_register_builtin_types()


func _register_builtin_types() -> void:
	register_type("maps", preload("res://framework/map/map_definition.gd"), "maps.json", "maps")
	register_type("pois", preload("res://framework/poi/poi_definition.gd"), "pois.json", "pois")
	register_type("intel", preload("res://framework/intel/intel_token.gd"), "intel.json", "intel")
	register_type("items", preload("res://framework/items/item_definition.gd"), "items.json", "items", true)
	register_type("actors", preload("res://framework/actor/actor_definition.gd"), "actors.json", "actors", true)
	register_type("factions", preload("res://framework/actor/faction_definition.gd"), "factions.json", "factions", true)
	register_type("effects", preload("res://framework/combat/effect_definition.gd"), "effects.json", "effects", true)
	register_type("abilities", preload("res://framework/combat/ability_definition.gd"), "abilities.json", "abilities", true)


func register_type(type_name: String, script: GDScript, file: String, key: String, optional: bool = false) -> void:
	var info := TypeInfo.new()
	info.def_script = script
	info.file = file
	info.key = key
	info.optional = optional
	_types[type_name] = info
	if not _defs.has(type_name):
		_defs[type_name] = {}


## Load every registered type from a game package folder (res://games/<id>).
func load_package(base_path: String) -> void:
	_base_path = base_path
	for type_name in _types:
		load_type(type_name)


func load_type(type_name: String) -> void:
	var info: TypeInfo = _types[type_name]
	var path := _base_path.path_join(info.file)
	var store := {}
	if FileAccess.file_exists(path):
		for entry in DataLoader.load_json_array(path, info.key):
			if not (entry is Dictionary):
				continue
			var def := Definition.build(info.def_script, entry)
			if def.id == "":
				push_error("DefinitionRegistry: %s entry without id in %s" % [type_name, path])
				continue
			if store.has(def.id):
				push_error("DefinitionRegistry: duplicate %s id '%s'" % [type_name, def.id])
			store[def.id] = def
	elif not info.optional:
		push_error("DefinitionRegistry: required data file missing: %s" % path)
	_defs[type_name] = store


## Register a definition created at runtime (procedural maps, generated items...).
func add(type_name: String, def: Definition) -> void:
	if not _defs.has(type_name):
		_defs[type_name] = {}
	_defs[type_name][def.id] = def


func has(type_name: String, id: String) -> bool:
	return _defs.get(type_name, {}).has(id)


func get_def(type_name: String, id: String) -> Definition:
	var d = _defs.get(type_name, {}).get(id)
	if d == null and id != "":
		push_warning("DefinitionRegistry: unknown %s '%s'" % [type_name, id])
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


func clear() -> void:
	for t in _defs:
		_defs[t] = {}
