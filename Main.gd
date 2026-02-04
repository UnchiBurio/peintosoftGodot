extends Control
class_name Main

@onready var tab_container=$VBoxContainer/TabContainer
@onready var file_menu=$VBoxContainer/MenuBar/File
@onready var edit_menu=$VBoxContainer/MenuBar/Edit
@onready var color_picker=$ColorPickerButton
@onready var navigator_viewport: SubViewport = $NavigatorViewport
@onready var navigator_texture_rect: TextureRect = $NavigatorTextureRect
@onready var layer_manager = $VBoxContainer/LayerManagerScene
@onready var brush_button: Button = $ToolWindow/MarginContainer/VBoxContainer/BrushButton
@onready var eraser_button: Button = $ToolWindow/MarginContainer/VBoxContainer/EraserButton
@onready var fill_button: Button = $ToolWindow/MarginContainer/VBoxContainer/FillButton
@onready var tip_visibility_checkbox: CheckBox = $ToolWindow/MarginContainer/VBoxContainer/TipVisibilityCheckBox
@onready var crosshair_enabled_checkbox: CheckBox = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairEnabledCheckBox
@onready var crosshair_primary_color_picker: ColorPickerButton = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairPrimaryColorRow/CrosshairPrimaryColorPicker
@onready var crosshair_secondary_color_picker: ColorPickerButton = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairSecondaryColorRow/CrosshairSecondaryColorPicker
@onready var crosshair_alpha_slider: HSlider = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairAlphaRow/CrosshairAlphaSlider
@onready var crosshair_length_slider: HSlider = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairLengthRow/CrosshairLengthSlider
@onready var crosshair_thickness_slider: HSlider = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairThicknessRow/CrosshairThicknessSlider
@onready var crosshair_min_movement_slider: HSlider = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairMinMovementRow/CrosshairMinMovementSlider
@onready var crosshair_smoothing_slider: HSlider = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairSmoothingRow/CrosshairSmoothingSlider
@onready var crosshair_trail_interval_slider: HSlider = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairTrailIntervalRow/CrosshairTrailIntervalSlider
@onready var crosshair_trail_persist_checkbox: CheckBox = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairTrailPersistCheckBox
@onready var crosshair_trail_clear_button: Button = $CrosshairWindow/MarginContainer/VBoxContainer/CrosshairTrailClearButton

var active_paint_canvas: Node2D = null

# 無限キャンバスの参照
var infinite_canvas: Node2D

# タブ管理用の変数を追加
var canvas_counter := 0  # 新規キャンバスの連番用

# ツールの状態
enum Tool {BRUSH, ERASER, FILL}
var current_tool = Tool.BRUSH
var tool_button_group: ButtonGroup
var show_tool_tip_indicator: bool = true

# ツールパラメータ
static var stroke_color = Color.BLACK
static var stroke_width = 1.0

# 回転クロスヘア設定
var directional_crosshair_enabled: bool = false
var directional_crosshair_primary_color: Color = Color.BLACK
var directional_crosshair_secondary_color: Color = Color.BLACK
var directional_crosshair_alpha: float = 0.6
var directional_crosshair_length: float = 18.0
var directional_crosshair_thickness: float = 1.0
var directional_crosshair_min_movement: float = 2.0
var directional_crosshair_smoothing: float = 0.2
var directional_crosshair_trail_interval: float = 20.0
var directional_crosshair_trail_persist: bool = false

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
	crosshair_primary_color_picker.color = directional_crosshair_primary_color
	crosshair_secondary_color_picker.color = directional_crosshair_secondary_color
	crosshair_enabled_checkbox.button_pressed = directional_crosshair_enabled
	crosshair_alpha_slider.value = directional_crosshair_alpha
	crosshair_length_slider.value = directional_crosshair_length
	crosshair_thickness_slider.value = directional_crosshair_thickness
	crosshair_min_movement_slider.value = directional_crosshair_min_movement
	crosshair_smoothing_slider.value = directional_crosshair_smoothing
	crosshair_trail_interval_slider.value = directional_crosshair_trail_interval
	crosshair_trail_persist_checkbox.button_pressed = directional_crosshair_trail_persist
	
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
	
	_setup_tool_buttons()
	_setup_tip_visibility_checkbox()


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
		if not layer.visible:
			continue
		for chunk in layer.chunks.values():
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
			_apply_directional_crosshair_settings(active_paint_canvas)
			# 入力シグナルを接続
			child.gui_input.connect(_on_canvas_input.bind(child))
			
			if layer_manager:
				layer_manager.set_target_canvas(active_paint_canvas)
	
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
			if active_paint_canvas and active_paint_canvas.has_method("undo"):
				active_paint_canvas.undo()
		1:  # Redo
			if active_paint_canvas and active_paint_canvas.has_method("redo"):
				active_paint_canvas.redo()

func _on_color_picker_color_changed(color):
	stroke_color = color

func _on_h_slider_value_changed(value):
	stroke_width = value

func _on_brush_button_pressed():
	_set_tool(Tool.BRUSH)

func _on_eraser_button_pressed():
	_set_tool(Tool.ERASER)

func _on_fill_button_pressed():
	_set_tool(Tool.FILL)

func _set_tool(tool: Tool):
	current_tool = tool
	_update_tool_buttons()

func _setup_tool_buttons():
	if !brush_button or !eraser_button or !fill_button:
		return
	
	if brush_button.button_group:
		tool_button_group = brush_button.button_group
	elif eraser_button.button_group:
		tool_button_group = eraser_button.button_group
	elif fill_button.button_group:
		tool_button_group = fill_button.button_group
	else:
		tool_button_group = ButtonGroup.new()
	
	brush_button.toggle_mode = true
	eraser_button.toggle_mode = true
	fill_button.toggle_mode = true
	brush_button.button_group = tool_button_group
	eraser_button.button_group = tool_button_group
	fill_button.button_group = tool_button_group
	_update_tool_buttons()

func _setup_tip_visibility_checkbox():
	if !tip_visibility_checkbox:
		return
	tip_visibility_checkbox.button_pressed = show_tool_tip_indicator

func _update_tool_buttons():
	if !brush_button or !eraser_button or !fill_button:
		return
	
	brush_button.button_pressed = current_tool == Tool.BRUSH
	eraser_button.button_pressed = current_tool == Tool.ERASER
	fill_button.button_pressed = current_tool == Tool.FILL

func _on_tip_visibility_toggled(pressed: bool) -> void:
	show_tool_tip_indicator = pressed
	if active_paint_canvas:
		active_paint_canvas.queue_redraw()

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
			_apply_directional_crosshair_settings(active_paint_canvas)
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
		_apply_directional_crosshair_settings(active_paint_canvas)
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

func _apply_directional_crosshair_settings(canvas: Node2D) -> void:
	if not canvas:
		return
	canvas.show_directional_crosshair = directional_crosshair_enabled
	canvas.directional_crosshair_primary_color = directional_crosshair_primary_color
	canvas.directional_crosshair_secondary_color = directional_crosshair_secondary_color
	canvas.directional_crosshair_alpha = directional_crosshair_alpha
	canvas.directional_crosshair_length = directional_crosshair_length
	canvas.directional_crosshair_thickness = directional_crosshair_thickness
	canvas.directional_crosshair_min_movement = directional_crosshair_min_movement
	canvas.directional_crosshair_smoothing = directional_crosshair_smoothing
	canvas.directional_crosshair_trail_interval = directional_crosshair_trail_interval
	canvas.directional_crosshair_trail_persist = directional_crosshair_trail_persist
	canvas.queue_redraw()

func _on_crosshair_enabled_toggled(pressed: bool) -> void:
	directional_crosshair_enabled = pressed
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_primary_color_changed(color: Color) -> void:
	directional_crosshair_primary_color = color
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_secondary_color_changed(color: Color) -> void:
	directional_crosshair_secondary_color = color
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_alpha_changed(value: float) -> void:
	directional_crosshair_alpha = value
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_length_changed(value: float) -> void:
	directional_crosshair_length = value
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_thickness_changed(value: float) -> void:
	directional_crosshair_thickness = value
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_min_movement_changed(value: float) -> void:
	directional_crosshair_min_movement = value
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_smoothing_changed(value: float) -> void:
	directional_crosshair_smoothing = value
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_trail_interval_changed(value: float) -> void:
	directional_crosshair_trail_interval = value
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_trail_persist_toggled(pressed: bool) -> void:
	directional_crosshair_trail_persist = pressed
	_apply_directional_crosshair_settings(active_paint_canvas)

func _on_crosshair_trail_clear_pressed() -> void:
	if active_paint_canvas and active_paint_canvas.has_method("clear_crosshair_trail"):
		active_paint_canvas.clear_crosshair_trail()
