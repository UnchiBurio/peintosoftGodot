# CanvasChunk.gd
class_name CanvasChunk
extends RefCounted

var image: Image
var texture: ImageTexture
var position: Vector2i
var dirty: bool = false
var last_used_time: float = 0.0
var texture_dirty: bool = true # テクスチャが変更されたかどうかのフラグ
var texture_rect: TextureRect # TextureRectを追加

func _init(pos: Vector2i, chunk_size: int):
	position = pos
	image = Image.create(chunk_size, chunk_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	texture = ImageTexture.create_from_image(image)
	
	# TextureRectの初期化
	texture_rect = TextureRect.new()
	texture_rect.z_index=-1
	texture_rect.texture = texture
	texture_rect.position = Vector2(pos * chunk_size)
	texture_rect.size = Vector2(chunk_size, chunk_size)
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE

func mark_dirty():
	if not dirty:
		dirty = true
		last_used_time = Time.get_ticks_msec()
		texture_dirty = true # チャンクが変更されたらテクスチャも変更されたとマーク
