# PaintCanvas.gd
extends Node2D

# 描画領域のプロパティ
@export var canvas_size: Vector2 = Vector2(800, 600)
@export var background_color: Color = Color.WHITE
@export var border_color: Color = Color.BLACK

# チャンクの定数
@export var CHUNK_SIZE: int = 512  # ピクセル単位
var CHUNK_MASK: int
var CHUNK_BITS: int

# チャンク管理用の変数
class LayerData:
	extends RefCounted
	var name: String
	var visible: bool
	var chunks: Dictionary

	func _init(layer_name: String):
		name = layer_name
		visible = true
		chunks = {}
	
	func values():
		return chunks.values()
	
	func keys():
		return chunks.keys()
	
	func has(key):
		return chunks.has(key)
	
	func erase(key):
		return chunks.erase(key)

var layers: Array = [] # 各要素がLayerDataを格納
var active_chunks: Array[CanvasChunk] = []  # 更新が必要なチャンク
var canvas_rect: Rect2i  # キャンバス全体の範囲
# チャンクプール
var chunk_pool := []
const MAX_POOL_SIZE = 10

# 描画状態の管理
var is_drawing: bool = false
var last_point: Vector2
var current_point: Vector2
var stroke_points: PackedVector2Array

# プレビュー線の表示設定
var show_preview_line: bool = false
var preview_points: Array[CanvasPreview.PreviewPoint] = []
var preview_connections: Array[CanvasPreview.ConnectionLine] = []

# クラス変数に十字カーソル関連の変数を追加
var show_cursor_cross: bool = false
var cursor_color: Color = Color.BLACK  # 十字の色
var cursor_alpha: float = 0.3  # 十字線の透明度

# 描画関連の変数
var stroke_history: Array = []
var current_stroke: Array = []
var undo_stack: Array = []
var redo_stack: Array = []
var is_recording_stroke: bool = false
var stroke_snapshots: Dictionary = {}

# メニュー関連の変数
var popup_menu: PopupMenu
var selected_point: CanvasPreview.PreviewPoint = null
# 分割したクラスのインスタンス
var canvas_input: CanvasInput
var canvas_draw: CanvasDraw
var canvas_resize: CanvasResize
var canvas_move: CanvasMove
var canvas_layer: PaintCanvasLayer
var canvas_preview: CanvasPreview

# 点の性質を表す列挙型
enum PointProperty {
	NONE = 0,
	INFINITE_LINE = 1,
	PERPENDICULAR_LINE = 2
	# 今後追加する性質をここに定義
}

var last_draw_position: Vector2
var last_input_position: Vector2 = Vector2.ZERO
var deback_mode:bool=true

var show_grid: bool = false  # グリッド表示フラグ
var grid_size: int = 32     # グリッドのサイズ（ピクセル単位）
var grid_color: Color = Color(0.8, 0.8, 0.8, 0.3)  # グリッド線の色
var show_grid_highlight: bool = false  # グリッドハイライト表示フラグ
var grid_highlight_color: Color = Color(0.8, 0.8, 1.0, 0.2)  # ハイライトの色
var grid_history_length: int = 5  # 履歴として保持するマスの数
var grid_history: Array[Vector2i] = []  # カーソルが通過したマスの履歴
var grid_history_colors: Array[Color] = [  # 履歴用の色（新しい順）
	Color(0.4, 0.4, 1.0, 0.8),  # 現在のマス
	Color(0.5, 0.5, 1.0, 0.6),
	Color(0.6, 0.6, 1.0, 0.4),
	Color(0.7, 0.7, 1.0, 0.2),
	Color(0.8, 0.8, 1.0, 0.1)
]
var grid_intersection_size: float = 4.0  # 交点強調の大きさ
var grid_intersection_color: Color = Color(0.3, 0.3, 1.0, 0.8)  # 交点の色
var last_grid_intersection: Vector2 = Vector2.ZERO  # 最後に横切ったグリッド線の位置
var grid_intersections: Array[Vector2] = []  # 通過した交点の履歴
var grid_intersection_history_length: int = 10  # 交点履歴の保持数

signal canvas_updated
signal layer_structure_changed # レイヤーの追加・削除時に発火
signal active_layer_changed(index) # アクティブレイヤー変更時に発火
signal preview_lines_requested(lines)

@export var highlight_color: Color = Color(0.0, 0.8, 1.0, 1.0) # シアン色
@export var highlight_width: float = 4.0 # 通常より太くする

func _ready():
	# チャンク関連の定数を初期化
	_update_chunk_constants()
	
	_setup_popup_menu()
	
	# 入力処理を有効化
	set_process_input(true)
	set_process_unhandled_input(true)
	_update_canvas_rect()
	
	add_to_group("paint_canvas")
	
	# 各クラスのインスタンス化
	canvas_input = CanvasInput.new(self)
	canvas_draw = CanvasDraw.new(self)
	canvas_resize = CanvasResize.new(self)
	canvas_move = CanvasMove.new(self)
	canvas_preview = CanvasPreview.new(self)
	
	# タブUIの追加
	canvas_layer = PaintCanvasLayer.new(self)
	
	# レイヤーの初期化
	_add_layer("layer0")
	
	# TextureRectをシーンに追加
	for layer in layers:
		for chunk in layer.chunks.values():
			add_child(chunk.texture_rect)
			
	# シグナルの接続
	if !solo:
		canvas_updated.connect(func(): get_tree().root.get_node("Main")._on_canvas_updated())

func _setup_popup_menu():
	popup_menu = PopupMenu.new()
	add_child(popup_menu)
	
	# セパレータで区切って性質の設定と削除を分ける
	popup_menu.add_check_item("無限線を引く", PointProperty.INFINITE_LINE)
	popup_menu.add_check_item("直角線を引く", PointProperty.PERPENDICULAR_LINE)
	
	popup_menu.add_separator()  # 区切り線を追加
	popup_menu.add_item("削除", 9999)  # 削除用に特別なID
	
	popup_menu.id_pressed.connect(_on_popup_menu_item_selected)

func _update_chunk_constants():
	CHUNK_MASK = CHUNK_SIZE - 1
	CHUNK_BITS = int(log(float(CHUNK_SIZE)) / log(2.0))

func _draw():
	canvas_draw.draw()

func _draw_resize_handles():
	var handle_color = Color(0.2, 0.6, 1.0, 0.8)
	var handle_points = _get_resize_handle_points()
	
	for point in handle_points:
		draw_rect(
			Rect2(point - Vector2.ONE * canvas_resize.resize_handle_size/2, Vector2.ONE * canvas_resize.resize_handle_size),
			handle_color,
			true
		)

func _get_resize_handle_points() -> Array:
	return [
		Vector2.ZERO,  # 左上
		Vector2(canvas_size.x/2, 0),  # 上中央
		Vector2(canvas_size.x, 0),  # 右上
		Vector2(canvas_size.x, canvas_size.y/2),  # 右中央
		Vector2(canvas_size.x, canvas_size.y),  # 右下
		Vector2(canvas_size.x/2, canvas_size.y),  # 下中央
		Vector2(0, canvas_size.y),  # 左下
		Vector2(0, canvas_size.y/2)  # 左中央
	]

var solo:bool=false
func _unhandled_input(event):
	if event is InputEventMouseButton:
		var local_pos = to_local(event.position)
		if _is_position_in_canvas(local_pos):
			# キャンバス内でクリックされた場合、選択状態を更新
			if !solo:
				get_tree().root.get_node("Main")._on_canvas_input_received(self)
	
	# 既存の入力処理を継続
	canvas_input.handle_input(event)

# シグナル定義
func _emit_preview_lines_requested():
	if show_preview_line:
		var lines_data = []
		for point in preview_points:
			lines_data.append({
				"position": point.position,
				"properties": point.properties
			})
		for connection in preview_connections:
			lines_data.append({
				"start": connection.start_point.position,  # start_pointを使用
				"end": connection.end_point.position      # end_pointを使用
			})
		preview_lines_requested.emit(lines_data)

# 最も近いプレビューポイントを見つける
func _find_nearest_preview_point(position: Vector2) -> Vector2:
	return canvas_preview.find_nearest_preview_point(position)

# 指定位置にある点を探す
func _find_point_at_position(position: Vector2, threshold: float = 5.0) -> CanvasPreview.PreviewPoint:
	return canvas_preview.find_point_at_position(position, threshold)

# 最も近い接続線を見つける
func _find_nearest_connection(position: Vector2, threshold: float = 10.0) :
	return canvas_preview.find_nearest_connection(position, threshold)

func create_connection(start_point: CanvasPreview.PreviewPoint, end_point: CanvasPreview.PreviewPoint) -> void:
	var new_connection = CanvasPreview.ConnectionLine.new(start_point, end_point)
	preview_connections.append(new_connection)
	queue_redraw()
	emit_signal("canvas_updated")

func _on_popup_menu_item_selected(id: int):
	if selected_point == null:
		return
	
	if id == 9999:  # 削除操作
		# 点に関連する接続線を削除
		preview_connections = preview_connections.filter(
			func(connection: Dictionary) -> bool:
				return not (
					connection.start.is_equal_approx(selected_point.position) or 
					connection.end.is_equal_approx(selected_point.position)
				)
		)
		# 点を削除
		preview_points.erase(selected_point)
		selected_point = null  # 選択中の点をクリア
	else:
		# 性質の切り替え
		if selected_point.has_property(id):
			selected_point.remove_property(id)
		else:
			selected_point.add_property(id)
	
	_emit_preview_lines_requested()
	queue_redraw()
	emit_signal("canvas_updated")

# ユーティリティ関数
func _is_position_in_canvas(position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, canvas_size).has_point(position)

# 移動関連の関数
func _start_move(global_pos: Vector2):
	canvas_move.start_move(global_pos)

func _update_move(global_pos: Vector2):
	canvas_move.update_move(global_pos)

func _end_move():
	canvas_move.end_move()

# キャンバスのリサイズ処理
func _update_canvas_rect():
	canvas_rect = Rect2i(Vector2i.ZERO, Vector2i(canvas_size))
	_ensure_chunks_exist(canvas_rect)

# キャンバスの範囲内に必要なチャンクを作成
func _ensure_chunks_exist(rect: Rect2i):
	var start_chunk = _get_chunk_pos(rect.position)
	var end_chunk = _get_chunk_pos(rect.end)
	
	for x in range(start_chunk.x, end_chunk.x + 1):
		for y in range(start_chunk.y, end_chunk.y + 1):
			var chunk_pos = Vector2i(x, y)
			for i in range(layers.size()):
				var layer = layers[i]
				if not layer.chunks.has(chunk_pos):
					layer.chunks[chunk_pos] = _get_or_create_chunk(chunk_pos, i)

func _get_chunk_pos(pos: Vector2) -> Vector2i:
	# 浮動小数点数を整数に変換してからビット演算を行う
	return Vector2i(
		int(pos.x) >> CHUNK_BITS,
		int(pos.y) >> CHUNK_BITS
	)

# チャンクの取得と管理
func _get_chunk(pos: Vector2i) -> CanvasChunk:
	# チャンク座標でのルックアップを確実に
	if not layers[canvas_layer.current_layer_index].chunks.has(pos):
		layers[canvas_layer.current_layer_index].chunks[pos] = _get_or_create_chunk(pos, canvas_layer.current_layer_index)
	return layers[canvas_layer.current_layer_index].chunks[pos]

func _start_resize(edge: Vector2, global_pos: Vector2):
	canvas_resize.start_resize(edge, global_pos)

func _update_resize(global_pos: Vector2):
	canvas_resize.update_resize(global_pos)

func _end_resize():
	canvas_resize.end_resize()

# キャンバスの描画機能を提供するメソッド群
func draw_canvas_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	# プレビュー用の一時的な線描画
	draw_line(from, to, color, width)

func draw_canvas_rect(rect: Rect2, color: Color, filled: bool = false, width: float = 1.0) -> void:
	# プレビュー用の四角形描画
	draw_rect(rect, color, filled, width)

func commit_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	# キャンバスの有効な範囲を定義
	var canvas_bounds = Rect2(Vector2.ZERO, canvas_size)
	
	# 描画範囲を計算
	var draw_rect = Rect2(from, Vector2.ZERO).expand(to).grow(width)
	
	# キャンバスの範囲内に制限
	draw_rect = draw_rect.intersection(canvas_bounds)
	
	# 制限された範囲に対してチャンクを取得
	var affected_chunks = _get_affected_chunks(draw_rect)
	
	# 以下の処理は変更なし
	for chunk in affected_chunks:
		_record_chunk_state(chunk, canvas_layer.current_layer_index)
		var chunk_from = _local_to_chunk_space(from, chunk)
		var chunk_to = _local_to_chunk_space(to, chunk)
		canvas_draw.draw_line_in_chunk_optimized(chunk, chunk_from, chunk_to, color, width)
		chunk.mark_dirty()
		canvas_draw._pending_updates[chunk.position] = chunk
		canvas_draw.chunk_update_times[chunk.position] = Time.get_ticks_msec()
		if not chunk in active_chunks:
			active_chunks.append(chunk)
	
	canvas_draw.process_pending_updates()
	queue_redraw()
	
# プレビュー描画
func draw_preview_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(from, to, color, width)

# 描画が有効な範囲かチェック
func is_valid_draw_position(position: Vector2) -> bool:
	# ローカル座標でのキャンバス範囲チェック
	var local_rect = Rect2(Vector2.ZERO, canvas_size)
	return local_rect.has_point(position)

func commit_rect(rect: Rect2, color: Color, filled: bool = false, width: float = 1.0) -> void:
	# まず影響を受けるチャンクを特定します
	var affected_chunks = _get_affected_chunks(rect)
	
	for chunk in affected_chunks:
		_record_chunk_state(chunk, canvas_layer.current_layer_index)
		# グローバル座標をチャンク内の相対座標に変換します
		var local_rect = Rect2(
			_local_to_chunk_space(rect.position, chunk),
			rect.size
		)
		
		if filled:
			# 塗りつぶしの場合
			_draw_filled_rect_in_chunk(chunk, local_rect, color)
		else:
			# 枠線の場合は4つの辺を個別に描画します
			_draw_rect_outline_in_chunk(chunk, local_rect, color, width)
		
		chunk.mark_dirty()
		if not chunk in active_chunks:
			active_chunks.append(chunk)
	
	queue_redraw()

# チャンク内に塗りつぶし四角形を描画
func _draw_filled_rect_in_chunk(chunk: CanvasChunk, rect: Rect2, color: Color) -> void:
	# チャンクの有効範囲を定義
	var chunk_rect = Rect2(Vector2.ZERO, Vector2.ONE * CHUNK_SIZE)
	
	# 描画範囲をチャンクの範囲内に制限
	var draw_rect = rect.intersection(chunk_rect)
	
	# 範囲内の各ピクセルを描画
	for x in range(int(draw_rect.position.x), int(draw_rect.end.x)):
		for y in range(int(draw_rect.position.y), int(draw_rect.end.y)):
			if chunk_rect.has_point(Vector2(x, y)):
				chunk.image.set_pixel(x, y, color)

# チャンク内に四角形の枠線を描画
func _draw_rect_outline_in_chunk(chunk: CanvasChunk, rect: Rect2, color: Color, width: float) -> void:
	# 4つの辺をそれぞれ描画
	# 上辺
	canvas_draw.draw_line_in_chunk_optimized(chunk, rect.position, 
		Vector2(rect.end.x, rect.position.y), color, width)
	# 右辺
	canvas_draw.draw_line_in_chunk_optimized(chunk, Vector2(rect.end.x, rect.position.y),
		rect.end, color, width)
	# 下辺
	canvas_draw.draw_line_in_chunk_optimized(chunk, Vector2(rect.position.x, rect.end.y),
		rect.end, color, width)
	# 左辺
	canvas_draw.draw_line_in_chunk_optimized(chunk, rect.position,
		Vector2(rect.position.x, rect.end.y), color, width)

# プレビュー描画用のメソッド
func draw_preview_rect(rect: Rect2, color: Color, filled: bool = false, width: float = 1.0) -> void:
	if filled:
		draw_rect(rect, color, true)
	else:
		draw_rect(rect, color, false, width)

# 描画用の補助関数
func _local_to_chunk_space(point: Vector2, chunk: CanvasChunk) -> Vector2:
	var chunk_origin = Vector2(chunk.position * CHUNK_SIZE)
	var local_point = point - chunk_origin
	return local_point
	
func _get_affected_chunks(rect: Rect2) -> Array:
	var affected: Array[CanvasChunk] = []
	
	# キャンバスの範囲内のチャンクのみを対象とする
	var canvas_chunks = Rect2i(
		Vector2i.ZERO,
		Vector2i(ceil(canvas_size.x / float(CHUNK_SIZE)),
				ceil(canvas_size.y / float(CHUNK_SIZE)))
	)
	
	var start_chunk = _get_chunk_pos(rect.position)
	var end_chunk = _get_chunk_pos(rect.end)
	
	# チャンク座標をキャンバスの範囲内に制限
	start_chunk = start_chunk.clamp(Vector2i.ZERO, canvas_chunks.end)
	end_chunk = end_chunk.clamp(Vector2i.ZERO, canvas_chunks.end)
	
	# 既存のチャンクのみを収集
	for x in range(start_chunk.x, end_chunk.x + 1):
		for y in range(start_chunk.y, end_chunk.y + 1):
			var chunk_pos = Vector2i(x, y)
			# すでに存在するチャンクのみを使用
			if layers[canvas_layer.current_layer_index].chunks.has(chunk_pos):
				affected.append(layers[canvas_layer.current_layer_index].chunks[chunk_pos])
			# 必要な場合のみ新しいチャンクを作成
			elif _is_chunk_needed(chunk_pos, rect):
				var new_chunk = _get_or_create_chunk(chunk_pos, canvas_layer.current_layer_index)
				affected.append(new_chunk)
	
	return affected
	
# 新しいヘルパーメソッド
func _is_chunk_needed(chunk_pos: Vector2i, draw_rect: Rect2) -> bool:
	# チャンクの範囲を計算
	var chunk_rect = Rect2(
		Vector2(chunk_pos * CHUNK_SIZE),
		Vector2.ONE * CHUNK_SIZE
	)
	
	# 描画範囲とチャンクの範囲が重なっているかチェック
	return chunk_rect.intersects(draw_rect) and chunk_rect.intersects(Rect2(Vector2.ZERO, canvas_size))

# チャンクのクリーンアップ
func cleanup_unused_chunks()->void:
	var used_chunks := {}
	for chunk in active_chunks:
		used_chunks[chunk.position] = chunk
	
	# アクティブでないチャンクを解放
	var keys_to_remove := []
	for layer in layers:
		for pos in layer.chunks.keys():
			if not used_chunks.has(pos):
				keys_to_remove.append(pos)
	
	for pos in keys_to_remove:
		for layer in layers:
			if layer.chunks.has(pos):
				var chunk = layer.chunks[pos]
				layer.chunks.erase(pos)
				if chunk_pool.size() < MAX_POOL_SIZE:
					chunk.image.fill(Color.TRANSPARENT)
					chunk_pool.append(chunk)
					chunk.texture_rect.visible = false # TextureRectを非表示にする
				else:
					chunk.image.free()
					chunk.texture.free()
					chunk.texture_rect.queue_free() # TextureRectを解放
					chunk.free()

# 定期的なクリーンアップ
func _on_cleanup_timer_timeout()->void:
	cleanup_unused_chunks()
	
func _global_to_local(global_pos: Vector2) -> Vector2:
	return to_local(global_pos)

# チャンク内座標の高速な計算
func _get_local_pos(pos: Vector2) -> Vector2i:
	# 浮動小数点数を整数に変換してからビット演算を行う
	return Vector2i(
		int(pos.x) & CHUNK_MASK,
		int(pos.y) & CHUNK_MASK
	)

# プールからチャンクを取得または新規作成
func _get_or_create_chunk(pos: Vector2i, layer_index: int) -> CanvasChunk:
	var chunk: CanvasChunk
	if chunk_pool.size() > 0:
		chunk = chunk_pool.pop_back()
		chunk.position = pos
		chunk.image.fill(Color.TRANSPARENT)
		# offsetの代わりにpositionを使用
		chunk.texture_rect.position = Vector2(pos * CHUNK_SIZE)
		chunk.texture_rect.visible = layers[layer_index].visible
	else:
		chunk = CanvasChunk.new(pos, CHUNK_SIZE)
	chunk.texture_rect.z_index = layer_index
	return chunk

# 削除ボタンが押されたときの処理
func _on_delete_button_pressed() -> void:
	# 確認ダイアログの表示
	var dialog = ConfirmationDialog.new()
	dialog.title = "キャンバスの削除"
	dialog.dialog_text = "このキャンバスを削除しますか？"
	dialog.size = Vector2(300, 100)
	
	# ダイアログのボタンテキストを設定
	dialog.get_ok_button().text = "削除"
	dialog.get_cancel_button().text = "キャンセル"
	
	# シグナルの接続
	dialog.confirmed.connect(
		func():
			# キャンバスの削除処理
			queue_free()  # ノードを削除
	)
	
	# ダイアログを画面に追加して表示
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

# レイヤーの追加
func _add_layer(layer_name: String) -> void:
	var new_layer := LayerData.new(layer_name)
	layers.append(new_layer)
	canvas_layer.current_layer_index = layers.size() - 1
	canvas_layer.current_layer_name = layer_name
	_update_canvas_rect()
	_refresh_layer_z_indices()
	
	# 新しいレイヤーのチャンクのTextureRectをシーンに追加
	for chunk_pos in new_layer.chunks.keys():
		var chunk = new_layer.chunks[chunk_pos]
		add_child(chunk.texture_rect)

	emit_signal("layer_structure_changed")
	emit_signal("active_layer_changed", canvas_layer.current_layer_index)

# 現在のアクティブなレイヤーを削除する関数
func delete_current_layer() -> void:
	# 最低1つはレイヤーを残す
	if layers.size() <= 1:
		return 
	
	var current_index = canvas_layer.current_layer_index
	var layer_to_remove = layers[current_index]
	
	# 削除されたレイヤーのチャンクを解放（メモリ管理）
	for chunk_pos in layer_to_remove.chunks.keys():
		var chunk = layer_to_remove.chunks[chunk_pos]
		
		# プールに戻すか、完全に削除するか
		if chunk_pool.size() < MAX_POOL_SIZE:
			chunk.image.fill(Color.TRANSPARENT)
			chunk_pool.append(chunk)
			chunk.texture_rect.visible = false # TextureRectを非表示にする
		else:
			chunk.image.free()
			chunk.texture.free()
			chunk.texture_rect.queue_free() # TextureRectを解放
			chunk.free()
	
	# 配列からレイヤーデータを削除
	layers.remove_at(current_index)
	
	# 現在のレイヤーインデックスを調整（範囲外にならないように）
	if canvas_layer.current_layer_index >= layers.size():
		canvas_layer.current_layer_index = layers.size() - 1
	canvas_layer.current_layer_name = layers[canvas_layer.current_layer_index].name
	
	_refresh_layer_z_indices()
	
	# キャンバスの状態を更新
	_update_canvas_rect()
	queue_redraw()
	
	# 外部UI（LayerManager）に通知
	emit_signal("layer_structure_changed")
	emit_signal("active_layer_changed", canvas_layer.current_layer_index)

# アクティブレイヤー変更用
func change_active_layer(index: int):
	if index < 0 or index >= layers.size():
		return
	canvas_layer.set_active_layer(index)
	emit_signal("active_layer_changed", index)

func rename_layer(index: int, new_name: String) -> void:
	if index < 0 or index >= layers.size():
		return
	layers[index].name = new_name
	if canvas_layer.current_layer_index == index:
		canvas_layer.current_layer_name = new_name
	emit_signal("layer_structure_changed")

func set_layer_visibility(index: int, visible: bool) -> void:
	if index < 0 or index >= layers.size():
		return
	layers[index].visible = visible
	for chunk in layers[index].chunks.values():
		chunk.texture_rect.visible = visible
	queue_redraw()
	emit_signal("canvas_updated")
	emit_signal("layer_structure_changed")

func move_layer(from_index: int, to_index: int) -> void:
	if from_index == to_index or from_index < 0 or to_index < 0:
		return
	if from_index >= layers.size() or to_index >= layers.size():
		return
	var layer = layers[from_index]
	layers.remove_at(from_index)
	if from_index < to_index:
		to_index -= 1
	layers.insert(to_index, layer)
	
	var active_index = canvas_layer.current_layer_index
	if active_index == from_index:
		active_index = to_index
	elif active_index > from_index and active_index <= to_index:
		active_index -= 1
	elif active_index < from_index and active_index >= to_index:
		active_index += 1
	canvas_layer.current_layer_index = active_index
	canvas_layer.current_layer_name = layers[active_index].name
	
	_refresh_layer_z_indices()
	queue_redraw()
	emit_signal("layer_structure_changed")
	emit_signal("canvas_updated")
	emit_signal("active_layer_changed", active_index)

func _refresh_layer_z_indices() -> void:
	for i in range(layers.size()):
		var layer = layers[i]
		for chunk in layer.chunks.values():
			chunk.texture_rect.z_index = i
			chunk.texture_rect.visible = layer.visible

# 新しい保存機能の実装
func _on_save_button_pressed() -> void:
	var image = _create_canvas_image()
	_save_image_to_file(image)

func _create_canvas_image() -> Image:
	# キャンバス全体のサイズの画像を作成
	var image = Image.create(int(canvas_size.x), int(canvas_size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# レイヤーごとにブレンド処理
	for layer in layers:
		if not layer.visible:
			continue
		for chunk_pos in layer.chunks.keys():
			var chunk = layer.chunks[chunk_pos]
			
			# チャンクの位置を計算
			var dst_pos = Vector2i(chunk_pos * CHUNK_SIZE)
			
			# ソース矩形（チャンク全体）を定義
			var src_rect = Rect2i(0, 0, CHUNK_SIZE, CHUNK_SIZE)
			
			# チャンクの内容をメイン画像にブレンド
			image.blend_rect(chunk.image, src_rect, dst_pos)
	
	return image

func _save_image_to_file(image: Image) -> void:
	# ファイル選択ダイアログを作成
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png ; PNG Images"]
	
	# ダイアログのサイズと位置を設定
	file_dialog.size = Vector2(500, 400)
	file_dialog.position = Vector2(100, 100)
	
	# ダイアログを画面に追加
	get_tree().root.add_child(file_dialog)
	
	# ファイル選択時の処理
	file_dialog.file_selected.connect(
		func(path: String):
			# PNG形式で保存
			var error = image.save_png(path)
			if error != OK:
				print("Failed to save image: ", error)
			file_dialog.queue_free()
	)
	
	# キャンセル時の処理
	file_dialog.canceled.connect(
		func():
			file_dialog.queue_free()
	)

	# ダイアログを表示
	file_dialog.popup_centered()

# Undo/Redo support
func start_stroke_recording() -> void:
	if is_recording_stroke:
		return
	is_recording_stroke = true
	stroke_snapshots.clear()

func finish_stroke_recording() -> void:
	if not is_recording_stroke:
		return
	if stroke_snapshots.size() > 0:
		var snapshot_array: Array = []
		for value in stroke_snapshots.values():
			snapshot_array.append(value)
		undo_stack.append(snapshot_array)
		redo_stack.clear()
	stroke_snapshots.clear()
	is_recording_stroke = false

func undo() -> void:
	if undo_stack.is_empty():
		return
	var last_action: Array = undo_stack.pop_back()
	var redo_action: Array = []
	for entry in last_action:
		var layer_index: int = entry["layer_index"]
		var chunk_pos: Vector2i = entry["position"]
		var chunk = _get_or_create_layer_chunk(layer_index, chunk_pos)
		if chunk == null:
			continue
		var redo_image = chunk.image.duplicate()
		redo_action.append({
			"layer_index": layer_index,
			"position": chunk_pos,
			"image": redo_image,
		})
		chunk.image = entry["image"].duplicate()
		chunk.texture = ImageTexture.create_from_image(chunk.image)
		chunk.texture_rect.texture = chunk.texture
		chunk.mark_dirty()
	redo_stack.append(redo_action)
	canvas_draw.process_pending_updates(true)
	queue_redraw()
	emit_signal("canvas_updated")

func redo() -> void:
	if redo_stack.is_empty():
		return
	var action: Array = redo_stack.pop_back()
	var undo_action: Array = []
	for entry in action:
		var layer_index: int = entry["layer_index"]
		var chunk_pos: Vector2i = entry["position"]
		var chunk = _get_or_create_layer_chunk(layer_index, chunk_pos)
		if chunk == null:
			continue
		var undo_image = chunk.image.duplicate()
		undo_action.append({
			"layer_index": layer_index,
			"position": chunk_pos,
			"image": undo_image,
		})
		chunk.image = entry["image"].duplicate()
		chunk.texture = ImageTexture.create_from_image(chunk.image)
		chunk.texture_rect.texture = chunk.texture
		chunk.mark_dirty()
	undo_stack.append(undo_action)
	canvas_draw.process_pending_updates(true)
	queue_redraw()
	emit_signal("canvas_updated")

func _record_chunk_state(chunk: CanvasChunk, layer_index: int) -> void:
	if not is_recording_stroke:
		return
	var key = "%d_%d_%d" % [layer_index, chunk.position.x, chunk.position.y]
	if stroke_snapshots.has(key):
		return
	stroke_snapshots[key] = {
		"layer_index": layer_index,
		"position": chunk.position,
		"image": chunk.image.duplicate()
	}

func _get_or_create_layer_chunk(layer_index: int, chunk_pos: Vector2i) -> CanvasChunk:
	if layer_index < 0 or layer_index >= layers.size():
		return null
	var layer = layers[layer_index]
	if not layer.chunks.has(chunk_pos):
		layer.chunks[chunk_pos] = _get_or_create_chunk(chunk_pos, layer_index)
	return layer.chunks[chunk_pos]
