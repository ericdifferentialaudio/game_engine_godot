## JSON save/load. Each system exposes to_save_data()/from_save_data() and is
## aggregated here; the schema is versioned so migrations can be added later.
##
## Load order matters: world (tiles/fog) before factions (territory), factions
## before units (faction colour), units before intel (reveal anchors).
extends Node

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	EventBus.save_requested.connect(save_game)


func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join("%s.json" % slot)


func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"game_id": GameManager.game_id,
		"timestamp": Time.get_datetime_string_from_system(),
		"flags": GameManager.flags,
		"clock": GameClock.to_save_data(),
		"turns": TurnManager.to_save_data(),
		"world": WorldManager.to_save_data(),
		"factions": FactionRegistry.to_save_data(),
		"units": EntityRegistry.to_save_data(),
		"intel": IntelRegistry.to_save_data(),
	}


func save_game(slot: String = "auto") -> bool:
	var data := build_save_data()
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write slot '%s'" % slot)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.save_completed.emit(slot)
	return true


func load_game(slot: String = "auto") -> bool:
	var data := DataLoader.load_json(_slot_path(slot))
	if data.is_empty():
		return false
	return apply_save_data(data, slot)


func apply_save_data(data: Dictionary, slot: String = "memory") -> bool:
	if int(data.get("version", 0)) != SAVE_VERSION:
		data = _migrate(data)
	if data.get("game_id", "") != GameManager.game_id:
		if not GameManager.load_game(data.get("game_id", "")):
			return false
	TurnManager.stop()
	GameManager.flags = data.get("flags", {})
	GameClock.from_save_data(data.get("clock", {}))
	EntityRegistry.reset()
	IntelRegistry.reset_journals()
	WorldManager.from_save_data(data.get("world", {}))
	FactionRegistry.from_save_data(data.get("factions", {}))
	EntityRegistry.from_save_data(data.get("units", {}))
	IntelRegistry.from_save_data(data.get("intel", {}))
	TurnManager.from_save_data(data.get("turns", {}))
	WorldManager.refresh_all_visibility()
	GameManager.set_state(GameManager.State.PLAYING)
	EventBus.load_completed.emit(slot)
	return true


func list_slots() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(SAVE_DIR):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out


func _migrate(data: Dictionary) -> Dictionary:
	# Add per-version migration steps here as SAVE_VERSION increments.
	push_warning("SaveManager: migrating save from version %s" % str(data.get("version")))
	data["version"] = SAVE_VERSION
	return data
