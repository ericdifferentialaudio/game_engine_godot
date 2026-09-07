## Draws a WorldMap: terrain TileMapLayer, feature sprites, ownership borders,
## site visuals, fog overlay. Units render themselves (EntityRegistry container
## is reparented under this node so Y-sort works across layers).
##
## Tile art comes through AssetRegistry "tile.<terrain_id>" / "feature.<id>" keys.
## If a terrain has no tileset entry, a placeholder hex/diamond is generated
## from TileDefinition.color so blockout maps are playable with zero art.
class_name WorldRenderer
extends Node2D

var world: WorldMap
var viewer_faction: String = ""

var _terrain_layer: TileMapLayer
var _features: Node2D
var _sites: Node2D
var _borders: Node2D
var _fog: Node2D
var _tileset: TileSet
var _source_ids: Dictionary = {}   ## terrain_id -> {source, atlas}
var _fog_cells: Dictionary = {}    ## Vector2i -> Polygon2D
var _outline: PackedVector2Array


func _ready() -> void:
	_terrain_layer = TileMapLayer.new()
	_terrain_layer.name = "Terrain"
	_terrain_layer.z_index = 0
	add_child(_terrain_layer)
	_features = _layer("Features", 1)
	_borders = _layer("Borders", 2)
	_sites = _layer("Sites", 3)
	_fog = _layer("Fog", 5)
	EventBus.tile_changed.connect(func(c, _f): redraw_tile(c))
	EventBus.visibility_changed.connect(_on_visibility_changed)
	EventBus.tile_owner_changed.connect(func(c, _o, _n): _draw_border(c))


func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	add_child(l)
	return l


func bind(p_world: WorldMap) -> void:
	world = p_world
	viewer_faction = GameManager.player_faction_id
	_outline = world.topology.outline()
	_build_tileset()
	redraw_all()


# --- Tileset --------------------------------------------------------------------------

func _build_tileset() -> void:
	_source_ids.clear()
	var topo := world.topology
	# Prefer a game-provided TileSet if every terrain resolves to a "tile" asset.
	var shared: TileSet = null
	var all_resolved := true
	for tid in world.terrain_defs:
		var entry := AssetRegistry.resolve_tile("tile.%s" % tid)
		if entry.is_empty() or entry["tileset"] == null:
			all_resolved = false
			break
		shared = entry["tileset"]
		_source_ids[tid] = {"source": entry["source"], "atlas": entry["atlas"]}
	if all_resolved and shared:
		_tileset = shared
	else:
		_source_ids.clear()
		_tileset = TileSet.new()
		_tileset.tile_shape = topo.tileset_shape()
		_tileset.tile_layout = topo.tileset_layout()
		_tileset.tile_offset_axis = topo.tileset_offset_axis()
		_tileset.tile_size = Vector2i(topo.tile_size)
		var idx := 0
		for tid in world.terrain_defs:
			var def: TileDefinition = world.terrain_defs[tid]
			var src := TileSetAtlasSource.new()
			src.texture = _placeholder_tile_texture(def)
			src.texture_region_size = Vector2i(topo.tile_size)
			src.create_tile(Vector2i.ZERO)
			var sid := _tileset.add_source(src, idx)
			_source_ids[tid] = {"source": sid, "atlas": Vector2i.ZERO}
			idx += 1
	_terrain_layer.tile_set = _tileset


func _placeholder_tile_texture(def: TileDefinition) -> Texture2D:
	var key := "tile.%s" % def.id
	if AssetRegistry.has_asset(key) and AssetRegistry.get_asset_meta(key).get("type", "") == "texture":
		var tex := AssetRegistry.load_asset(key)
		if tex is Texture2D and ResourceLoader.exists(AssetRegistry.get_asset_path(key)):
			return tex
	var size := Vector2i(world.topology.tile_size)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var centre := Vector2(size) * 0.5
	var poly := PackedVector2Array()
	for p in _outline:
		poly.append(p * 0.96 + centre)
	for y in size.y:
		for x in size.x:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				var shade := 1.0 - 0.06 * float((x + y) % 3)
				img.set_pixel(x, y, Color(def.color.r * shade, def.color.g * shade, def.color.b * shade, 1.0))
	return ImageTexture.create_from_image(img)


# --- Drawing --------------------------------------------------------------------------------

func redraw_all() -> void:
	_terrain_layer.clear()
	for c in _features.get_children():
		c.queue_free()
	for c in _borders.get_children():
		c.queue_free()
	_fog_cells.clear()
	for c in _fog.get_children():
		c.queue_free()
	for coord in world.tiles:
		redraw_tile(coord)
	refresh_fog()


func redraw_tile(coord: Vector2i) -> void:
	var tile := world.get_tile(coord)
	if tile == null or tile.terrain == null:
		return
	var src: Dictionary = _source_ids.get(tile.terrain.id, {})
	if not src.is_empty():
		_terrain_layer.set_cell(_tilemap_coord(coord), src["source"], src["atlas"])
	var fname := "F_%d_%d" % [coord.x, coord.y]
	var old := _features.get_node_or_null(fname)
	if old:
		old.queue_free()
	if not tile.features.is_empty():
		var holder := Node2D.new()
		holder.name = fname
		holder.position = world.topology.to_world(coord)
		for i in tile.features.size():
			var fdef := world.feature_definition(tile.features[i])
			if fdef == null:
				continue
			var s := Sprite2D.new()
			s.texture = AssetRegistry.load_texture(fdef.visual_key)
			s.scale = Vector2.ONE * 0.5
			s.position = Vector2(0, -6 - 4 * i)
			holder.add_child(s)
		_features.add_child(holder)
	_draw_border(coord)


## Convert storage coord to TileMapLayer coordinates (identical for our layouts).
func _tilemap_coord(c: Vector2i) -> Vector2i:
	return c


func _draw_border(coord: Vector2i) -> void:
	var bname := "B_%d_%d" % [coord.x, coord.y]
	var old := _borders.get_node_or_null(bname)
	if old:
		old.queue_free()
	var owner := world.owner_of(coord)
	if owner == "":
		return
	var f := FactionRegistry.get_faction(owner)
	var line := Line2D.new()
	line.name = bname
	line.width = 2.0
	line.default_color = f.color if f else Color.WHITE
	line.closed = true
	line.points = _scaled_outline(0.9)
	line.position = world.topology.to_world(coord)
	_borders.add_child(line)


# --- Sites ---------------------------------------------------------------------------------

func add_site_visual(site: Site) -> Node2D:
	var node := AssetRegistry.instance_scene(site.definition.visual_key)
	node.name = "Site_" + site.definition.id
	node.position = world.topology.to_world(site.coord)
	if node.has_method("configure"):
		node.configure(site.definition.display_name, AssetRegistry.key_color(site.definition.category))
	_sites.add_child(node)
	return node


# --- Fog -------------------------------------------------------------------------------------

func refresh_fog() -> void:
	if world.fog_mode == "none" or viewer_faction == "":
		_fog.visible = false
		return
	_fog.visible = true
	for coord in world.tiles:
		_update_fog_cell(coord)
	_apply_entity_visibility()


func _apply_entity_visibility() -> void:
	for u in EntityRegistry.units_on_map(world.map_id):
		u.set_fog_visible(world.fog_mode == "none" or world.is_visible(viewer_faction, u.coord) or u.faction_id == viewer_faction)
	for site in WorldManager.sites.values():
		if site.visual:
			site.visual.visible = (world.fog_mode == "none" or world.is_explored(viewer_faction, site.coord)) and site.is_revealed_to(viewer_faction)


func _update_fog_cell(coord: Vector2i) -> void:
	var vis := world.visibility(viewer_faction, coord)
	var poly: Polygon2D = _fog_cells.get(coord)
	if vis == WorldMap.Vis.VISIBLE:
		if poly:
			poly.visible = false
		return
	if poly == null:
		poly = Polygon2D.new()
		poly.polygon = _scaled_outline(1.02)
		poly.position = world.topology.to_world(coord)
		_fog.add_child(poly)
		_fog_cells[coord] = poly
	poly.visible = true
	poly.color = Color(0, 0, 0, 0.92) if vis == WorldMap.Vis.UNEXPLORED else Color(0, 0, 0, 0.45)


func _on_visibility_changed(faction_id: String, revealed: Array) -> void:
	if faction_id != viewer_faction or world == null:
		return
	for c in revealed:
		_update_fog_cell(c)
	_apply_entity_visibility()


func _scaled_outline(scale_factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _outline:
		out.append(p * scale_factor)
	return out


## World-space bounding rect of the map (camera limits).
func map_rect() -> Rect2:
	if world == null or world.tiles.is_empty():
		return Rect2()
	var topo := world.topology
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for c in [Vector2i(0, 0), Vector2i(topo.width - 1, 0), Vector2i(0, topo.height - 1), Vector2i(topo.width - 1, topo.height - 1)]:
		var p := topo.to_world(c)
		minp = minp.min(p)
		maxp = maxp.max(p)
	return Rect2(minp - topo.tile_size, maxp - minp + topo.tile_size * 2.0)
