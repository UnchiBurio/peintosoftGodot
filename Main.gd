extends Control
class_name Main

@onready var tab_container=$VBoxContainer/TabContainer
@onready var file_menu=$VBoxContainer/MenuBar/File
@onready var edit_menu=$VBoxContainer/MenuBar/Edit
@onready var view_menu=$VBoxContainer/MenuBar/View
@onready var color_picker=$ColorPickerButton
@onready var navigator_viewport: SubViewport = $NavigatorViewport
@onready var navigator_texture_rect: TextureRect = $NavigatorTextureRect
@onready var layer_manager = $VBoxContainer/LayerManagerScene
@onready var position_label: Label = find_child("PositionLabel", true, false) as Label
@onready var tool_window: Control = $ToolWindow
@onready var crosshair_window: Control = $CrosshairWindow
@onready var brush_button: Button = $ToolWindow/MarginContainer/VBoxContainer/BrushButton
@onready var eraser_button: Button = $ToolWindow/MarginContainer/VBoxContainer/EraserButton
@onready var fill_button: Button = $ToolWindow/MarginContainer/VBoxContainer/FillButton
@onready var point_attraction_strength_slider: HSlider = $ToolWindow/MarginContainer/VBoxContainer/PointAttractionStrengthRow/PointAttractionStrengthSlider
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

# ツールパラメータ
static var stroke_color = Color.BLACK
static var stroke_width = 1.0
var point_attraction_strength: float = 0.18

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
const NAVIGATOR_UPDATE_INTERVAL_MS := 120
const VIEW_PANEL_TOOLS := 0
const VIEW_PANEL_CROSSHAIR := 1
const VIEW_PANEL_LAYERS := 2
const VIEW_PANEL_NAVIGATOR := 3
var last_navigator_update_ms := 0

func _ready():
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# 初期タブの作成
	_create_new_canvas()
	
	# メニューバーの設定
	file_menu.get_popup().id_pressed.connect(_on_file_menu_pressed)
	edit_menu.get_popup().id_pressed.connect(_on_edit_menu_pressed)
	_setup_view_menu()
	_setup_panel_close_signals()
	
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
	point_attraction_strength_slider.value = point_attraction_strength
	
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
		layer_btn.pressed.connect(func(): _set_layer_manager_visible(true))
	
	_setup_tool_buttons()
	_refresh_viewport_update_modes()
	_sync_active_canvas_with_current_tab()

func _setup_view_menu() -> void:
	var popup = view_menu.get_popup()
	popup.clear()
	popup.add_check_item("ツール", VIEW_PANEL_TOOLS)
	popup.add_check_item("クロスヘア", VIEW_PANEL_CROSSHAIR)
	popup.add_check_item("レイヤー", VIEW_PANEL_LAYERS)
	popup.add_check_item("ナビゲーター", VIEW_PANEL_NAVIGATOR)
	if not popup.id_pressed.is_connected(_on_view_menu_pressed):
		popup.id_pressed.connect(_on_view_menu_pressed)
	_sync_view_menu_checks()

func _setup_panel_close_signals() -> void:
	if tool_window.has_signal("close_requested"):
		tool_window.close_requested.connect(_sync_view_menu_checks)
	if crosshair_window.has_signal("close_requested"):
		crosshair_window.close_requested.connect(_sync_view_menu_checks)
	if navigator_texture_rect.has_signal("close_requested"):
		navigator_texture_rect.close_requested.connect(func(): _set_navigator_visible(false))
	if layer_manager.has_signal("close_requested"):
		layer_manager.close_requested.connect(func(): call_deferred("_sync_view_menu_checks"))

func _on_view_menu_pressed(id: int) -> void:
	match id:
		VIEW_PANEL_TOOLS:
			_toggle_panel(tool_window)
		VIEW_PANEL_CROSSHAIR:
			_toggle_panel(crosshair_window)
		VIEW_PANEL_LAYERS:
			_set_layer_manager_visible(not layer_manager.visible)
		VIEW_PANEL_NAVIGATOR:
			_set_navigator_visible(not show_navigator)

func _toggle_panel(panel: Control) -> void:
	panel.visible = not panel.visible
	if panel.visible and panel.has_method("_clamp_to_viewport"):
		panel._clamp_to_viewport()
	_sync_view_menu_checks()

func _set_layer_manager_visible(is_visible: bool) -> void:
	if is_visible:
		layer_manager.show()
	else:
		layer_manager.hide()
	_sync_view_menu_checks()

func _sync_view_menu_checks() -> void:
	if not is_node_ready() or not view_menu:
		return
	var popup = view_menu.get_popup()
	_set_popup_item_checked(popup, VIEW_PANEL_TOOLS, tool_window.visible)
	_set_popup_item_checked(popup, VIEW_PANEL_CROSSHAIR, crosshair_window.visible)
	_set_popup_item_checked(popup, VIEW_PANEL_LAYERS, layer_manager.visible)
	_set_popup_item_checked(popup, VIEW_PANEL_NAVIGATOR, show_navigator)

func _set_popup_item_checked(popup: PopupMenu, id: int, checked: bool) -> void:
	var index = popup.get_item_index(id)
	if index != -1:
		popup.set_item_checked(index, checked)


func _on_navigator_draw():
	var draw_node = navigator_viewport.get_child(0)
	if !show_navigator:
		return
	
	# ナビゲーターの背景を描画
	draw_node.draw_rect(Rect2(Vector2.ZERO, Vector2(navigator_viewport.size)), 
					   Color(0.2, 0.2, 0.2, 0.8), true)
	draw_node.draw_rect(Rect2(Vector2.ZERO, Vector2(navigator_viewport.size)), 
					   Color.WHITE, false)

	# 現在アクティブなキャンバスを取得
	var active_canvas = _get_active_paint_canvas()
	if not active_canvas:
		return
	
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
			var chunk_canvas_rect = active_canvas._get_chunk_canvas_rect(chunk.position)
			var chunk_size = Vector2(chunk_canvas_rect.size) * navigator_scale
			match chunk.storage_mode:
				CanvasChunk.StorageMode.SOLID:
					var draw_color = chunk.get_navigator_modulate(layer.opacity)
					if draw_color.a > 0.0:
						draw_node.draw_rect(Rect2(chunk_preview_pos, chunk_size), draw_color, true)
				CanvasChunk.StorageMode.BITMAP:
					if chunk.texture != null:
						draw_node.draw_texture_rect(
							chunk.texture,
							Rect2(chunk_preview_pos, chunk_size),
							false,
							chunk.get_navigator_modulate(layer.opacity)
						)

func _process(_delta):
	# マウス位置の更新
	if infinite_canvas and position_label:
		var mouse_pos = infinite_canvas.get_local_mouse_position()
		position_label.text = "Position: %d, %d" % [mouse_pos.x, mouse_pos.y]

func _get_viewport_container(tab_index: int) -> Node:
	if tab_index < 0 or tab_index >= tab_container.get_tab_count():
		return null
	return tab_container.get_child(tab_index)

func _get_tab_viewport(tab_index: int) -> SubViewport:
	var viewport_container = _get_viewport_container(tab_index)
	if viewport_container and viewport_container.get_child_count() > 0:
		return viewport_container.get_child(0) as SubViewport
	return null

func _get_tab_root_canvas(tab_index: int) -> Node:
	var viewport = _get_tab_viewport(tab_index)
	if viewport and viewport.get_child_count() > 0:
		return viewport.get_child(0)
	return null

func _find_first_paint_canvas(root: Node) -> Node2D:
	if root == null:
		return null
	for child in root.get_children():
		if child is Node2D and child.has_method("commit_line"):
			return child
	return null

func _refresh_viewport_update_modes() -> void:
	var current_tab = tab_container.get_current_tab()
	for i in range(tab_container.get_tab_count()):
		var viewport = _get_tab_viewport(i)
		if viewport == null:
			continue
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if i == current_tab else SubViewport.UPDATE_DISABLED

func _sync_active_canvas_with_current_tab() -> void:
	infinite_canvas = _get_tab_root_canvas(tab_container.get_current_tab()) as Node2D
	var next_canvas = _find_first_paint_canvas(infinite_canvas)
	_set_active_canvas(next_canvas)

func _set_active_canvas(canvas: Node2D) -> void:
	if active_paint_canvas == canvas:
		if active_paint_canvas and active_paint_canvas.has_method("queue_active_state_redraw"):
			active_paint_canvas.queue_active_state_redraw()
		if layer_manager and active_paint_canvas:
			layer_manager.set_target_canvas(active_paint_canvas)
		return

	var previous_canvas = active_paint_canvas
	active_paint_canvas = canvas

	if previous_canvas != null and is_instance_valid(previous_canvas) and previous_canvas.has_method("queue_active_state_redraw"):
		previous_canvas.queue_active_state_redraw()

	if active_paint_canvas != null and active_paint_canvas.has_method("queue_active_state_redraw"):
		active_paint_canvas.queue_active_state_redraw()
		_apply_directional_crosshair_settings(active_paint_canvas)
		_apply_point_attraction_settings(active_paint_canvas)

	if layer_manager:
		layer_manager.set_target_canvas(active_paint_canvas)

	_request_navigator_update(true)

func _request_navigator_update(force: bool = false) -> void:
	if not show_navigator:
		return
	if not active_paint_canvas:
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		navigator_viewport.get_child(0).queue_redraw()
		return
	var now = Time.get_ticks_msec()
	var is_busy = bool(active_paint_canvas.get("is_drawing")) or bool(active_paint_canvas.get("is_fill_in_progress"))
	if not force and is_busy and now - last_navigator_update_ms < NAVIGATOR_UPDATE_INTERVAL_MS:
		return
	last_navigator_update_ms = now
	navigator_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	navigator_viewport.get_child(0).queue_redraw()

# 現在アクティブなキャンバスを取得
func _get_active_paint_canvas() -> Node2D:
	return active_paint_canvas

# アクティブキャンバス上にカーソルがあるかどうかでカーソル形状を切り替える
func set_cursor_over_active_canvas(is_over_canvas: bool) -> void:
	if is_over_canvas:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# ナビゲーターの表示切り替え
func toggle_navigator():
	_set_navigator_visible(not show_navigator)

func _set_navigator_visible(is_visible: bool) -> void:
	show_navigator = is_visible
	navigator_texture_rect.visible = show_navigator
	if show_navigator:
		_request_navigator_update(true)
	else:
		# 非表示時は更新を無効化
		navigator_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sync_view_menu_checks()

func toggle_navigator_flip_vertical():
	# 関数名は同じでも内部で水平反転を扱う
	navigator_flip_horizontal = !navigator_flip_horizontal
	navigator_texture_rect.flip_h = navigator_flip_horizontal  # flip_vからflip_hに変更
	if show_navigator:
		_request_navigator_update(true)

# キー入力の処理を追加
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			match event.keycode:
				KEY_Z:
					if active_paint_canvas and active_paint_canvas.has_method("undo"):
						active_paint_canvas.undo()
				KEY_Y:
					if active_paint_canvas and active_paint_canvas.has_method("redo"):
						active_paint_canvas.redo()
			return
		match event.keycode:
			KEY_N:
				toggle_navigator()
			KEY_V:
				toggle_navigator_flip_vertical()
			KEY_DELETE:
				_request_delete_active_canvas()
				get_viewport().set_input_as_handled()

func _request_delete_active_canvas() -> void:
	if not active_paint_canvas or not is_instance_valid(active_paint_canvas):
		return
	if bool(active_paint_canvas.get("is_drawing")) or bool(active_paint_canvas.get("is_fill_in_progress")):
		return
	
	var canvas_to_delete = active_paint_canvas
	var dialog = ConfirmationDialog.new()
	dialog.title = "キャンバスの削除"
	dialog.dialog_text = "選択中のキャンバスを削除しますか？"
	dialog.size = Vector2(300, 100)
	dialog.get_ok_button().text = "削除"
	dialog.get_cancel_button().text = "キャンセル"
	dialog.confirmed.connect(
		func():
			if not is_instance_valid(canvas_to_delete):
				return
			var next_canvas = _find_next_paint_canvas_excluding(infinite_canvas, canvas_to_delete)
			canvas_to_delete.queue_free()
			_set_active_canvas(next_canvas)
			_request_navigator_update(true)
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): dialog.queue_free())
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _find_next_paint_canvas_excluding(root: Node, excluded_canvas: Node) -> Node2D:
	if root == null:
		return null
	for child in root.get_children():
		if child == excluded_canvas:
			continue
		if child is Node2D and child.has_method("commit_line"):
			return child
	return null

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
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = get_viewport().get_visible_rect().size
	viewport_container.add_child(viewport)
	
	# 無限キャンバスの作成
	var new_infinite_canvas = preload("res://src/InfiniteCanvas.tscn").instantiate()
	viewport.add_child(new_infinite_canvas)
	
	# キャンバスの入力シグナルを接続
	for child in new_infinite_canvas.get_children():
		if child is Node2D and child.has_method("_draw") and child.has_method("commit_line"):
			# 入力シグナルを接続
			child.gui_input.connect(_on_canvas_input.bind(child))
	
	# タブに追加
	canvas_counter += 1
	tab_container.add_child(viewport_container)
	var new_tab_index = tab_container.get_tab_count() - 1
	tab_container.set_tab_title(new_tab_index, "Canvas " + str(canvas_counter))
	tab_container.current_tab = new_tab_index
	_refresh_viewport_update_modes()
	_sync_active_canvas_with_current_tab()

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

func _on_point_attraction_strength_changed(value: float) -> void:
	point_attraction_strength = value
	_apply_point_attraction_settings(active_paint_canvas)

func _on_brush_button_pressed():
	_set_tool(Tool.BRUSH)

func _on_eraser_button_pressed():
	_set_tool(Tool.ERASER)

func _on_fill_button_pressed():
	_set_tool(Tool.FILL)

func _on_clear_canvas_button_pressed() -> void:
	if active_paint_canvas and active_paint_canvas.has_method("clear_canvas_contents"):
		active_paint_canvas.clear_canvas_contents()

func _set_tool(tool: Tool):
	current_tool = tool
	_update_tool_buttons()
	if active_paint_canvas and active_paint_canvas.has_method("queue_crosshair_overlay_redraw"):
		active_paint_canvas.queue_crosshair_overlay_redraw()

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

func _update_tool_buttons():
	if !brush_button or !eraser_button or !fill_button:
		return
	
	brush_button.button_pressed = current_tool == Tool.BRUSH
	eraser_button.button_pressed = current_tool == Tool.ERASER
	fill_button.button_pressed = current_tool == Tool.FILL

func _on_canvas_updated():
	var is_busy = active_paint_canvas != null and (bool(active_paint_canvas.get("is_drawing")) or bool(active_paint_canvas.get("is_fill_in_progress")))
	_request_navigator_update(not is_busy)

func _on_navigator_texture_rect_resized():
	if navigator_viewport:
		navigator_viewport.size = $NavigatorTextureRect.size
		_request_navigator_update(true)


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
				viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
				viewport.size = get_viewport().get_visible_rect().size
				viewport_container.add_child(viewport)
				
				# 読み込んだInfiniteCanvasをインスタンス化
				var infinite_canvas = packed_scene.instantiate()
				viewport.add_child(infinite_canvas)
				
				# タブに追加
				canvas_counter += 1
				tab_container.add_child(viewport_container)
				var new_tab_index = tab_container.get_tab_count() - 1
				tab_container.set_tab_title(new_tab_index, "Canvas " + str(canvas_counter))
				tab_container.current_tab = new_tab_index
				_refresh_viewport_update_modes()
				_sync_active_canvas_with_current_tab()
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
			_set_active_canvas(canvas)

# ナビゲーター更新用のメソッドを追加
func _update_navigator_view():
	_request_navigator_update(true)

func _on_canvas_input_received(canvas: Node2D):
	# 既にアクティブなら何もしない
	if active_paint_canvas == canvas:
		return
	_set_active_canvas(canvas)

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
	if canvas.has_method("queue_crosshair_overlay_redraw"):
		canvas.queue_crosshair_overlay_redraw()

func _apply_point_attraction_settings(canvas: Node2D) -> void:
	if not canvas:
		return
	canvas.point_attraction_strength = point_attraction_strength
	if canvas.has_method("update_point_attraction_feedback"):
		canvas.update_point_attraction_feedback(canvas.last_input_position)
	if canvas.has_method("queue_preview_overlay_redraw"):
		canvas.queue_preview_overlay_redraw()
	if canvas.has_method("queue_crosshair_overlay_redraw"):
		canvas.queue_crosshair_overlay_redraw()

func _on_tab_changed(_tab: int) -> void:
	_refresh_viewport_update_modes()
	_sync_active_canvas_with_current_tab()

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
