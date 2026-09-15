## Art window: portraits, scene illustration, sprites.
##
## Images are addressed by **logical key** ("portrait.fence", "scene.round_room"),
## never a `res://` path — resolution is the host engine's job via
## `CoreContext.adapter`. That keeps narrative able to say "show this character"
## without knowing where a particular game keeps its art, and lets a game ship
## no art at all without breaking the story.
##
## Specialised API:
##   set_image(texture_id) / set_texture(tex) / current_image() / clear()
class_name CoreGraphicsWindow
extends CoreWindow

## How the image fits the region.
@export var keep_aspect: bool = true

var _rect: TextureRect
var _caption: Label
var _image_id: String = ""


func _build() -> void:
	if minimum_window_size == Vector2i(120, 80):
		minimum_window_size = Vector2i(160, 120)
		custom_minimum_size = Vector2(minimum_window_size)

	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	_rect = TextureRect.new()
	_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect \
			else TextureRect.STRETCH_SCALE
	root.add_child(_rect)

	_caption = Label.new()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.visible = false
	root.add_child(_caption)


## Show art by logical key. Returns false when the host engine cannot resolve
## it — a missing portrait must never stop a conversation.
func set_image(texture_id: String) -> bool:
	_image_id = texture_id
	if texture_id == "":
		set_texture(null)
		return true
	var resolved = _resolve(texture_id)
	set_texture(resolved)
	return resolved != null


## Set an already-loaded texture directly, for engines that resolve art
## themselves.
func set_texture(tex: Texture2D) -> void:
	if _rect != null:
		_rect.texture = tex


## Optional caption beneath the image ("" hides it).
func set_caption(text: String) -> void:
	if _caption == null:
		return
	_caption.text = text
	_caption.visible = text != ""


func current_image() -> String:
	return _image_id


func has_image() -> bool:
	return _rect != null and _rect.texture != null


# --- Contract -----------------------------------------------------------------

func clear() -> void:
	_image_id = ""
	set_texture(null)
	set_caption("")


func describe() -> String:
	return "%s: %s" % [role, _image_id if _image_id != "" else "(empty)"]


## Ask the host engine to turn a logical key into a texture. The headless
## adapter has no art, so this returns null and the window simply stays blank.
func _resolve(texture_id: String) -> Texture2D:
	var adapter := CoreContext.adapter
	if adapter != null and adapter.has_method("resolve_texture"):
		return adapter.resolve_texture(texture_id) as Texture2D
	return null
