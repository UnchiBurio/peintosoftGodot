# DraggableNavigator.gd
extends TextureRect

signal close_requested

var dragging := false
var resizing := false
var drag_start_position := Vector2.ZERO
var resize_start_position := Vector2.ZERO
var resize_start_size := Vector2.ZERO
var border_color := Color.WHITE
var border_width := 2.0
var resize_handle_size := 12.0
var min_size := Vector2(20, 20)
var close_button: Button

func _ready():
	# マウス入力を受け付けるように設定
	mouse_filter = Control.MOUSE_FILTER_PASS
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	gui_input.connect(_on_gui_input)
	_setup_close_button()

func _setup_close_button() -> void:
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "x"
	close_button.tooltip_text = "閉じる"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(22, 22)
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -26.0
	close_button.offset_top = 4.0
	close_button.offset_right = -4.0
	close_button.offset_bottom = 26.0
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_on_close_button_pressed)
	add_child(close_button)

func _on_close_button_pressed() -> void:
	close_requested.emit()

func _draw():
	# 枠線を描画
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, border_color, false, border_width)
	# リサイズハンドル
	var handle_rect = Rect2(size - Vector2(resize_handle_size, resize_handle_size), Vector2(resize_handle_size, resize_handle_size))
	draw_rect(handle_rect, border_color, true)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# ドラッグ/リサイズ開始
				if _is_on_resize_handle(event.position):
					resizing = true
					resize_start_position = get_global_mouse_position()
					resize_start_size = size
				else:
					dragging = true
					drag_start_position = get_global_mouse_position() - position
			else:
				# ドラッグ/リサイズ終了
				dragging = false
				resizing = false
	
	elif event is InputEventMouseMotion:
		if resizing:
			var mouse_delta = get_global_mouse_position() - resize_start_position
			var new_size = resize_start_size + mouse_delta
			var viewport_size = get_viewport_rect().size
			var max_size = viewport_size - position
			new_size.x = clamp(new_size.x, min_size.x, max_size.x)
			new_size.y = clamp(new_size.y, min_size.y, max_size.y)
			size = new_size
			queue_redraw()
		elif dragging:
			# ドラッグ中の位置更新
			position = get_global_mouse_position() - drag_start_position
			
			# 画面外に出ないように制限
			var viewport_size = get_viewport_rect().size
			position.x = clamp(position.x, 0, viewport_size.x - size.x)
			position.y = clamp(position.y, 0, viewport_size.y - size.y)

func _is_on_resize_handle(local_pos: Vector2) -> bool:
	return local_pos.x >= size.x - resize_handle_size and local_pos.y >= size.y - resize_handle_size
