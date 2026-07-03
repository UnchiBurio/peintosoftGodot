# CanvasChunk.gd
class_name CanvasChunk
extends RefCounted

enum StorageMode {
	EMPTY,
	SOLID,
	BITMAP,
}

static var _shared_solid_texture: ImageTexture

var image: Image
var texture: Texture2D
var position: Vector2i
var dirty: bool = false
var last_used_time: float = 0.0
var texture_dirty: bool = true
var texture_rect: Sprite2D
var storage_mode: StorageMode = StorageMode.EMPTY
var solid_color: Color = Color.TRANSPARENT
var chunk_size: int
var solid_display_size: Vector2i
var layer_visible: bool = true
var layer_opacity: float = 1.0

func _init(pos: Vector2i, chunk_size_value: int):
	position = pos
	chunk_size = chunk_size_value
	solid_display_size = Vector2i(chunk_size, chunk_size)
	image = null
	texture = null
	
	texture_rect = Sprite2D.new()
	texture_rect.z_index = -1
	texture_rect.centered = false
	texture_rect.position = Vector2(pos * chunk_size)
	texture_rect.scale = Vector2.ONE * chunk_size
	
	clear_to_empty()
	sync_texture()

static func _get_shared_solid_texture() -> ImageTexture:
	if _shared_solid_texture == null:
		var white_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		white_image.fill(Color.WHITE)
		_shared_solid_texture = ImageTexture.create_from_image(white_image)
	return _shared_solid_texture

func update_position(pos: Vector2i) -> void:
	position = pos
	texture_rect.position = Vector2(pos * chunk_size)

func update_solid_display_size(size: Vector2i) -> void:
	solid_display_size = Vector2i(max(1, size.x), max(1, size.y))
	if storage_mode == StorageMode.SOLID:
		_refresh_visual_state()

func apply_layer_visuals(is_visible: bool, opacity: float) -> void:
	layer_visible = is_visible
	layer_opacity = opacity
	_refresh_visual_state()

func _refresh_visual_state() -> void:
	match storage_mode:
		StorageMode.EMPTY:
			texture_rect.region_enabled = false
			texture_rect.visible = false
			texture_rect.modulate = Color(1.0, 1.0, 1.0, layer_opacity)
			texture_rect.scale = Vector2(solid_display_size)
		StorageMode.SOLID:
			texture_rect.region_enabled = false
			texture_rect.visible = layer_visible and solid_color.a > 0.0
			var modulate_color = solid_color
			modulate_color.a *= layer_opacity
			texture_rect.modulate = modulate_color
			texture_rect.scale = Vector2(solid_display_size)
		StorageMode.BITMAP:
			texture_rect.region_enabled = true
			texture_rect.region_rect = Rect2(Vector2.ZERO, Vector2(solid_display_size))
			texture_rect.visible = layer_visible
			texture_rect.modulate = Color(1.0, 1.0, 1.0, layer_opacity)
			texture_rect.scale = Vector2.ONE

func materialize() -> void:
	if storage_mode == StorageMode.BITMAP:
		return
	if image == null:
		image = Image.create(chunk_size, chunk_size, false, Image.FORMAT_RGBA8)
	match storage_mode:
		StorageMode.EMPTY:
			image.fill(Color.TRANSPARENT)
		StorageMode.SOLID:
			image.fill(solid_color)
	storage_mode = StorageMode.BITMAP
	texture = null
	texture_rect.texture = null
	texture_dirty = true

func set_bitmap_from_image(new_image: Image) -> void:
	image = new_image
	storage_mode = StorageMode.BITMAP
	texture = null
	texture_rect.texture = null
	texture_dirty = true

func clear_to_empty() -> void:
	storage_mode = StorageMode.EMPTY
	solid_color = Color.TRANSPARENT
	image = null
	texture = null
	texture_rect.texture = null
	texture_dirty = true

func set_solid(color: Color) -> void:
	storage_mode = StorageMode.SOLID
	solid_color = color
	image = null
	texture = null
	texture_dirty = true

func is_uniform_target(color: Color) -> bool:
	match storage_mode:
		StorageMode.EMPTY:
			return color.is_equal_approx(Color.TRANSPARENT)
		StorageMode.SOLID:
			return solid_color.is_equal_approx(color)
		_:
			return false

func get_pixel(x: int, y: int) -> Color:
	match storage_mode:
		StorageMode.EMPTY:
			return Color.TRANSPARENT
		StorageMode.SOLID:
			return solid_color
		_:
			return image.get_pixel(x, y)

func set_pixel(x: int, y: int, color: Color) -> void:
	materialize()
	image.set_pixel(x, y, color)

func fill_span(y: int, x0: int, x1: int, color: Color) -> void:
	if x1 < x0:
		return
	materialize()
	image.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), color)

func fill_local_rect(rect: Rect2i, color: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	materialize()
	image.fill_rect(rect, color)

func sync_texture() -> void:
	match storage_mode:
		StorageMode.EMPTY:
			texture = null
			texture_rect.texture = null
		StorageMode.SOLID:
			texture = _get_shared_solid_texture()
			texture_rect.texture = texture
		StorageMode.BITMAP:
			if image == null:
				image = Image.create(chunk_size, chunk_size, false, Image.FORMAT_RGBA8)
				image.fill(Color.TRANSPARENT)
			if texture == null or not (texture is ImageTexture):
				texture = ImageTexture.create_from_image(image)
			else:
				(texture as ImageTexture).update(image)
			texture_rect.texture = texture
	texture_dirty = false
	_refresh_visual_state()

func get_navigator_modulate(opacity: float) -> Color:
	match storage_mode:
		StorageMode.SOLID:
			var modulate_color = solid_color
			modulate_color.a *= opacity
			return modulate_color
		StorageMode.BITMAP:
			return Color(1.0, 1.0, 1.0, opacity)
		_:
			return Color.TRANSPARENT

func mark_dirty():
	if not dirty:
		dirty = true
		last_used_time = Time.get_ticks_msec()
	texture_dirty = true
