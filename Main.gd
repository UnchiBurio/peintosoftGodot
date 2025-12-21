extends Control
class_name Main

@onready var tab_container=$VBoxContainer/TabContainer
@onready var file_menu=$VBoxContainer/MenuBar/File
@onready var edit_menu=$VBoxContainer/MenuBar/Edit
@onready var color_picker=$ColorPickerButton
@onready var navigator_viewport: SubViewport = $NavigatorViewport
@onready var navigator_texture_rect: TextureRect = $NavigatorTextureRect
@onready var layer_manager = $VBoxContainer/LayerManagerScene

var active_paint_canvas: Node2D = null

# 無限キャンバスの参照
var infinite_canvas: Node2D

# タブ管理用の変数を追加
var canvas_counter := 0  # 新規キャンバスの連番用

# ツールの状態
enum Tool {BRUSH, ERASER}
var current_tool = Tool.BRUSH

# ツールパラメータ
static var stroke_color = Color.BLACK
static var stroke_width = 1.0

# ナビゲーター関連の変数
var show_navigator: bool = true
var navigator_scale: float = 1.0
var navigator_flip_vertical: bool = false
var navigator_flip_horizontal: bool = false

func _ready():
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 初期タブの作成
	_create_new_canvas()
	
	# メニューバーの設定
	file_menu.get_popup().id_pressed.connect(_on_file_menu_pressed)
	edit_menu.get_popup().id_pressed.connect(_on_edit_menu_pressed)
	
	# 初期カラーを設定
	color_picker.color = stroke_color
	
	# ナビゲーター用のViewportTextureを設定
	navigator_texture_rect.texture = navigator_viewport.get_texture()
	
	# ナビゲーターの描画ノードを追加
	var navigator_draw = Node2D.new()
	navigator_draw.draw.connect(_on_navigator_draw)
	navigator_viewport.add_child(navigator_draw)
	
	# 初期状態での更新モード設定
	navigator_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	# ナビゲーターのリサイズシグナルを接続
	navigator_texture_rect.resized.connect(_on_navigator_texture_rect_resized)
	
	# "Layers"ボタンが押されたらウィンドウを表示する接続
	# （ボタンのパスは実際の配置に合わせてください）
	var layer_btn = find_child("LayerButton", true, false)
	if layer_btn:
		layer_btn.pressed.connect(func(): layer_manager.show())


func _on_navigator_draw():
	var draw_node = navigator_viewport.get_child(0)
	if !show_navigator:
		return
	
	# 現在アクティブなキャンバスを取得
	var active_canvas = _get_active_paint_canvas()
	if not active_canvas:
		return
	
	# ナビゲーターの背景を描画
	draw_node.draw_rect(Rect2(Vector2.ZERO, Vector2(navigator_viewport.size)), 
					   Color(0.2, 0.2, 0.2, 0.8), true)
	draw_node.draw_rect(Rect2(Vector2.ZERO, Vector2(navigator_viewport.size)), 
					   Color.WHITE, false)
	
	# スケールの計算
	var scale_x = (float(navigator_viewport.size.x) - 20.0) / active_canvas.canvas_size.x
	var scale_y = (float(navigator_viewport.size.y) - 20.0) / active_canvas.canvas_size.y
	navigator_scale = min(scale_x, scale_y)
	
	# キャンバスプレビューの描画用サイズを計算
	var scaled_size = active_canvas.canvas_size * navigator_scale
	var preview_pos = (Vector2(navigator_viewport.size) - scaled_size) / 2
	
	# キャンバスの内容を描画
	for layer in active_canvas.layers:
		for chunk in layer.values():
			var chunk_pos = Vector2(chunk.position * active_canvas.CHUNK_SIZE) * navigator_scale
			var chunk_preview_pos = preview_pos + chunk_pos
			var chunk_size = Vector2.ONE * active_canvas.CHUNK_SIZE * navigator_scale
			
			draw_node.draw_texture_rect(chunk.texture, 
									  Rect2(chunk_preview_pos, chunk_size), 
									  false)

func _process(_delta):
	# マウス位置の更新
	if infinite_canvas:
		var mouse_pos = infinite_canvas.get_local_mouse_position()
		$VBoxContainer/StatusBar/HBoxContainer/PositionLabel.text = "Position: %d, %d" % [mouse_pos.x, mouse_pos.y]

# 現在アクティブなキャンバスを取得
func _get_active_paint_canvas() -> Node2D:
	return active_paint_canvas

# ナビゲーターの表示切り替え
func toggle_navigator():
	show_navigator = !show_navigator
	navigator_texture_rect.visible = show_navigator
	if show_navigator:
		# ナビゲーター表示時に一度更新
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		navigator_viewport.get_child(0).queue_redraw()
	else:
		# 非表示時は更新を無効化
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func toggle_navigator_flip_vertical():
	# 関数名は同じでも内部で水平反転を扱う
	navigator_flip_horizontal = !navigator_flip_horizontal
	navigator_texture_rect.flip_h = navigator_flip_horizontal  # flip_vからflip_hに変更
	if show_navigator:
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		navigator_viewport.get_child(0).queue_redraw()

# キー入力の処理を追加
func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_N:
				toggle_navigator()
			KEY_V:
				toggle_navigator_flip_vertical()

func _on_file_menu_pressed(id: int):
	match id:
		0:  # New Canvas
			_create_new_canvas()
		1:  # Save
			var current_tab = tab_container.get_current_tab()
			if current_tab >= 0:
				var viewport_container = tab_container.get_child(current_tab)
				if viewport_container and viewport_container.get_child_count() > 0:
					var viewport = viewport_container.get_child(0)
					if viewport and viewport.get_child_count() > 0:
						var infinite_canvas = viewport.get_child(0)
						_save_infinite_canvas(infinite_canvas)
		2:  # Load
			_load_infinite_canvas()

func _create_new_canvas():
	# SubViewportContainerの作成
	var viewport_container = SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# SubViewportの設定
	var viewport = SubViewport.new()
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = get_viewport().get_visible_rect().size
	viewport_container.add_child(viewport)
	
	# 無限キャンバスの作成
	var infinite_canvas = preload("res://InfiniteCanvas.tscn").instantiate()
	viewport.add_child(infinite_canvas)
	
	# キャンバスの入力シグナルを接続
	for child in infinite_canvas.get_children():
		if child is Node2D and child.has_method("_draw") and child.has_method("commit_line"):
			# 新しく作成されたキャンバスを自動的にアクティブにする
			active_paint_canvas = child
			# 入力シグナルを接続
			child.gui_input.connect(_on_canvas_input.bind(child))
	
	# タブに追加
	canvas_counter += 1
	tab_container.add_child(viewport_container)
	tab_container.set_tab_title(
		tab_container.get_tab_count() - 1, 
		"Canvas " + str(canvas_counter)
	)

func _on_edit_menu_pressed(id: int):
	match id:
		0:  # Undo
			print("Undo")
		1:  # Redo
			print("Redo")

func _on_color_picker_color_changed(color):
	stroke_color = color

func _on_h_slider_value_changed(value):
	stroke_width = value

func _on_brush_button_pressed():
	current_tool = Tool.BRUSH

func _on_eraser_button_pressed():
	current_tool = Tool.ERASER

func _on_canvas_updated():
	if show_navigator:
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		navigator_viewport.get_child(0).queue_redraw()

func _on_navigator_texture_rect_resized():
	if navigator_viewport:
		navigator_viewport.size = $NavigatorTextureRect.size
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		navigator_viewport.get_child(0).queue_redraw()


# 無限キャンバスの保存
# 無限キャンバスの保存
func _save_infinite_canvas(infinite_canvas: Node):
	# ファイル選択ダイアログを作成
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.infinitecanvas ; Infinite Canvas Files"]
	
	file_dialog.size = Vector2(500, 400)
	get_tree().root.add_child(file_dialog)
	
	# ファイル選択時の処理
	file_dialog.file_selected.connect(
		func(path: String):
			# シーン全体をパックしてセーブ
			var packed_scene = PackedScene.new()
			var result = packed_scene.pack(infinite_canvas)
			if result == OK:
				var error = ResourceSaver.save(packed_scene, path)
				if error != OK:
					print("Failed to save scene: ", error)
			file_dialog.queue_free()
	)
	
	# キャンセル時の処理
	file_dialog.canceled.connect(
		func():
			file_dialog.queue_free()
	)
	
	file_dialog.popup_centered()

# 無限キャンバスの読み込み
func _load_infinite_canvas():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.infinitecanvas ; Infinite Canvas Files"]
	
	file_dialog.size = Vector2(500, 400)
	get_tree().root.add_child(file_dialog)
	
	# ファイル選択時の処理
	file_dialog.file_selected.connect(
		func(path: String):
			var packed_scene = load(path) as PackedScene
			if packed_scene:
				# 新しいタブを作成
				var viewport_container = SubViewportContainer.new()
				viewport_container.stretch = true
				viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
				
				var viewport = SubViewport.new()
				viewport.handle_input_locally = false
				viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				viewport.size = get_viewport().get_visible_rect().size
				viewport_container.add_child(viewport)
				
				# 読み込んだInfiniteCanvasをインスタンス化
				var infinite_canvas = packed_scene.instantiate()
				viewport.add_child(infinite_canvas)
				
				# タブに追加
				canvas_counter += 1
				tab_container.add_child(viewport_container)
				tab_container.set_tab_title(
					tab_container.get_tab_count() - 1,
					"Canvas " + str(canvas_counter)
				)
			file_dialog.queue_free()
	)
	
	# キャンセル時の処理
	file_dialog.canceled.connect(
		func():
			file_dialog.queue_free()
	)
	
	file_dialog.popup_centered()

# キャンバスが選択された時の処理を追加
func _on_canvas_input(canvas: Node2D, event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if canvas != active_paint_canvas:
			active_paint_canvas = canvas
			# ナビゲーターの更新をトリガー
			_update_navigator_view()

# ナビゲーター更新用のメソッドを追加
func _update_navigator_view():
	if show_navigator and active_paint_canvas:
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		navigator_viewport.get_child(0).queue_redraw()

func _on_canvas_input_received(canvas: Node2D):
	print("アクティブ",active_paint_canvas)
	# 既にアクティブなら何もしない
	if active_paint_canvas == canvas:
		print("アクティブおんなじ")
		return
		
	if active_paint_canvas != null and is_instance_valid(active_paint_canvas):
		active_paint_canvas.queue_redraw()
		
	if canvas != active_paint_canvas:
		active_paint_canvas = canvas
		# ナビゲーターの更新をトリガー
		if show_navigator:
			navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			navigator_viewport.get_child(0).queue_redraw()
		print("なのは～",active_paint_canvas)
	
		if layer_manager:
			print("レイヤーまね")
			layer_manager.set_target_canvas(active_paint_canvas)
		else:
			print("Error: layer_window is null!")
