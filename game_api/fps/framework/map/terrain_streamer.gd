## Chunked streaming for large exterior maps (overworld/regions).
##
## Add as a child of a MapRoot and point [member chunk_dir] at a folder of
## chunk scenes named `chunk_<x>_<z>.tscn`. Chunks within [member view_distance]
## of the player are loaded (threaded) and others freed. Terrain itself is
## expected to be authored as heightmap-derived meshes (see docs/05_rendering.md)
## or via the Terrain3D GDExtension; this class only handles lifecycle.
##
## Performance note: if chunk counts grow large or we need runtime heightmap
## editing, this is the first candidate to move into the C++ GDExtension.
class_name TerrainStreamer
extends Node3D

@export var chunk_dir: String = ""
@export var chunk_size: float = 256.0
@export var view_distance: int = 2          ## In chunks (radius).
@export var update_interval: float = 0.5

var _loaded: Dictionary = {}                ## Vector2i -> Node3D
var _pending: Dictionary = {}               ## Vector2i -> path
var _timer := 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer < update_interval:
		_poll_pending()
		return
	_timer = 0.0
	var player := GameManager.player
	if player == null or chunk_dir == "":
		return
	var center := _to_chunk(player.global_position)
	var wanted := {}
	for dx in range(-view_distance, view_distance + 1):
		for dz in range(-view_distance, view_distance + 1):
			wanted[center + Vector2i(dx, dz)] = true
	for c in wanted:
		if not _loaded.has(c) and not _pending.has(c):
			_request(c)
	for c in _loaded.keys():
		if not wanted.has(c):
			_loaded[c].queue_free()
			_loaded.erase(c)
	_poll_pending()


func _to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))


func _request(c: Vector2i) -> void:
	var path := chunk_dir.path_join("chunk_%d_%d.tscn" % [c.x, c.y])
	if not ResourceLoader.exists(path):
		return
	ResourceLoader.load_threaded_request(path)
	_pending[c] = path


func _poll_pending() -> void:
	for c in _pending.keys():
		var path: String = _pending[c]
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(path)
			var node := scene.instantiate() as Node3D
			node.position = Vector3(c.x * chunk_size, 0, c.y * chunk_size)
			add_child(node)
			_loaded[c] = node
			_pending.erase(c)
