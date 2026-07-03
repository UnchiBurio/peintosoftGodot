# InfiniteCanvas.gd
@tool
extends Node2D

# カメラ/変形関連の変数
var is_panning := false
var pan_start_position := Vector2.ZERO
var zoom_min := 0.1
var zoom_max := 5.0
var current_zoom := 1.0

# キャンバス配置関連の変数
var is_placing_canvas := false
var canvas_preview_start := Vector2.ZERO
var canvas_preview_end := Vector2.ZERO
var minimum_canvas_size := Vector2(100, 100)  # キャンバスの最小サイズ

# シーンの参照
const PaintCanvasScene = preload("res://src/PaintCanvas.tscn")

# 画像ドロップ関連の変数
var drag_data: Dictionary = {}

func _ready():
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# ドロップ処理を有効化
	get_viewport().gui_embed_subwindows = false
	get_tree().get_root().files_dropped.connect(_on_files_dropped)

func _draw():
	# キャンバスプレビューの描画
	if is_placing_canvas:
		var rect = _get_preview_rect()
		draw_rect(rect, Color(0.5, 0.5, 1.0, 0.3), true)  # 半透明の塗りつぶし
		draw_rect(rect, Color(0.5, 0.5, 1.0, 0.8), false)  # 実線の枠
		
		# サイズ表示のための設定
		var size_text = "%dx%d" % [int(rect.size.x), int(rect.size.y)]
		var zoom_scale = 1.0 / current_zoom
		var font_size = max(1, int(round(16.0 * zoom_scale)))
		var padding = 5.0 * zoom_scale
		
		# テキストのサイズを取得
		var text_size = ThemeDB.fallback_font.get_string_size(
			size_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		)
		
		# テキストの位置を計算（矩形の中央上部）
		var text_pos = Vector2(
			rect.position.x + (rect.size.x - text_size.x) / 2,
			rect.position.y - text_size.y - padding
		)
		
		# 背景付きのサイズ表示を描画
		var background_rect = Rect2(
			text_pos - Vector2(padding, padding),
			text_size + Vector2(padding * 2, padding * 2)
		)
		draw_rect(background_rect, Color(0, 0, 0, 0.5))
		
		# サイズテキストを描画
		draw_string(
			ThemeDB.fallback_font,
			text_pos,
			size_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		var transformed_position = _transform_input_position(event.position)
		
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_handle_zoom(1.2, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_handle_zoom(0.8, event.position)
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_start_pan(event.position)
				else:
					_end_pan()
			MOUSE_BUTTON_LEFT:
				if Input.is_key_pressed(KEY_SHIFT):  # Shiftキーが押されている場合
					if event.pressed:
						_start_canvas_placement(transformed_position)
					else:
						_finish_canvas_placement()
	
	elif event is InputEventMouseMotion:
		if is_placing_canvas:
			_update_canvas_preview(_transform_input_position(event.position))
		elif is_panning:
			_update_pan(event.position)

# キャンバス配置関連の関数
func _start_canvas_placement(position: Vector2):
	is_placing_canvas = true
	canvas_preview_start = position
	canvas_preview_end = position

func _update_canvas_preview(position: Vector2):
	canvas_preview_end = position
	queue_redraw()

func _finish_canvas_placement():
	if is_placing_canvas:
		var rect = _get_preview_rect()
		if rect.size.x >= minimum_canvas_size.x and rect.size.y >= minimum_canvas_size.y:
			var new_canvas = PaintCanvasScene.instantiate()
			new_canvas.position = rect.position
			new_canvas.canvas_size = rect.size
			add_child(new_canvas)
		
		is_placing_canvas = false
		queue_redraw()

func _get_preview_rect() -> Rect2:
	var top_left = Vector2(
		min(canvas_preview_start.x, canvas_preview_end.x),
		min(canvas_preview_start.y, canvas_preview_end.y)
	)
	var size = (canvas_preview_end - canvas_preview_start).abs()
	return Rect2(top_left, size)

# カメラ操作関連の関数
func _transform_input_position(position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * position

func _handle_zoom(zoom_factor: float, center: Vector2):
	var new_zoom = clamp(current_zoom * zoom_factor, zoom_min, zoom_max)
	if new_zoom == current_zoom:
		return
	
	var old_mouse_pos = get_global_transform().affine_inverse() * center
	current_zoom = new_zoom
	scale = Vector2.ONE * current_zoom
	var new_mouse_pos = get_global_transform().affine_inverse() * center
	position += (new_mouse_pos - old_mouse_pos) * current_zoom
	_update_zoom_independent_canvas_ui()
	queue_redraw()

func get_current_zoom() -> float:
	return current_zoom

func _update_zoom_independent_canvas_ui() -> void:
	for child in get_children():
		if child.has_method("update_zoom_independent_ui"):
			child.update_zoom_independent_ui()

func _start_pan(position: Vector2):
	is_panning = true
	pan_start_position = position

func _update_pan(pos: Vector2):
	if is_panning:
		var delta = pos - pan_start_position
		position += delta
		pan_start_position = pos

func _end_pan():
	is_panning = false

# キャンバス管理関連の関数
func _find_canvas_at_position(position: Vector2) -> Node2D:
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if child is Node2D:
			var local_pos = child.get_local_mouse_position()
			var canvas_rect = Rect2(Vector2.ZERO, child.canvas_size)
			if canvas_rect.has_point(local_pos):
				return child
	return null
	
func _on_files_dropped(files: PackedStringArray) -> void:
	for file_path in files:
		# 画像ファイルかどうかをチェック
		if _is_valid_image_file(file_path):
			# 画像を読み込んでテクスチャを作成
			var image = Image.new()
			var error = image.load(file_path)
			
			if error == OK:
				# 画像サイズでキャンバスを作成
				var new_canvas = PaintCanvasScene.instantiate()
				new_canvas.position = _transform_input_position(get_viewport().get_mouse_position())
				new_canvas.canvas_size = Vector2(image.get_width(), image.get_height())
				
				# キャンバスをシーンに追加して_ready()を実行させる
				add_child(new_canvas)
				
				# ここで画像を適用
				_apply_image_to_canvas(new_canvas, image)

func _is_valid_image_file(file_path: String) -> bool:
	# 対応する画像形式の拡張子をチェック
	var valid_extensions = ["png", "jpg", "jpeg", "bmp", "webp"]
	var extension = file_path.get_extension().to_lower()
	return valid_extensions.has(extension)

func _apply_image_to_canvas(canvas: Node2D, source_image: Image) -> void:
	# レイヤーがまだ初期化されていない場合は初期化
	if canvas.layers.is_empty():
		canvas._add_layer("layer0")
	
	var chunk_size = canvas.CHUNK_SIZE
	var chunks_x = ceili(canvas.canvas_size.x / float(chunk_size))
	var chunks_y = ceili(canvas.canvas_size.y / float(chunk_size))
	
	# ソース画像のフォーマットをRGBA8に統一
	if source_image.get_format() != Image.FORMAT_RGBA8:
		source_image.convert(Image.FORMAT_RGBA8)
	
	# 各チャンクに画像データを転送
	for x in range(chunks_x):
		for y in range(chunks_y):
			var chunk_pos = Vector2i(x, y)
			var chunk = canvas._get_chunk(chunk_pos)
			
			# チャンクの領域を計算
			var src_x = x * chunk_size
			var src_y = y * chunk_size
			var src_width = mini(chunk_size, int(canvas.canvas_size.x) - src_x)
			var src_height = mini(chunk_size, int(canvas.canvas_size.y) - src_y)
			
			# インポート時は通常のビットマップチャンクとして扱う
			chunk.materialize()
			chunk.image.fill(Color.TRANSPARENT)
			
			# 画像の該当部分をコピー
			var region = source_image.get_region(Rect2i(src_x, src_y, src_width, src_height))
			chunk.image.blit_rect(region, 
								Rect2i(0, 0, src_width, src_height), 
								Vector2i.ZERO)
			
			# テクスチャを更新
			chunk.sync_texture()
			chunk.mark_dirty()
	
	# キャンバスを更新
	canvas.queue_all_overlay_redraws()
	canvas.emit_signal("canvas_updated")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# シーンが削除される際にシグナル接続を解除
		if get_tree() and get_tree().get_root():
			get_tree().get_root().files_dropped.disconnect(_on_files_dropped)
