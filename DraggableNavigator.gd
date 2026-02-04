# DraggableNavigator.gd
extends TextureRect

var dragging := false
var resizing := false
var drag_start_position := Vector2.ZERO
var resize_start_size := Vector2.ZERO
var resize_start_mouse := Vector2.ZERO
var border_color := Color.WHITE
var border_width := 2.0
var resize_handle_size := 14.0
var min_size := Vector2(40, 40)

func _ready():
	# マウス入力を受け付けるように設定
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)

func _draw():
	# 枠線を描画
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, border_color, false, border_width)
	# リサイズハンドルを描画
	var handle_rect = Rect2(size - Vector2.ONE * resize_handle_size, Vector2.ONE * resize_handle_size)
	draw_rect(handle_rect, border_color, true)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = event.position
				var handle_area = Rect2(size - Vector2.ONE * resize_handle_size, Vector2.ONE * resize_handle_size)
				if handle_area.has_point(local_pos):
					# リサイズ開始
					resizing = true
					resize_start_size = size
					resize_start_mouse = get_global_mouse_position()
				else:
					# ドラッグ開始
					dragging = true
					drag_start_position = get_global_mouse_position() - position
			else:
				# ドラッグ終了
				dragging = false
				resizing = false
	
	elif event is InputEventMouseMotion:
		if resizing:
			var delta = get_global_mouse_position() - resize_start_mouse
			var new_size = resize_start_size + delta
			var viewport_size = get_viewport_rect().size
			var max_size_x = max(min_size.x, viewport_size.x - position.x)
			var max_size_y = max(min_size.y, viewport_size.y - position.y)
			new_size.x = clamp(new_size.x, min_size.x, max_size_x)
			new_size.y = clamp(new_size.y, min_size.y, max_size_y)
			size = new_size
			queue_redraw()
		elif dragging:
			# ドラッグ中の位置更新
			position = get_global_mouse_position() - drag_start_position
			
			# 画面外に出ないように制限
			var viewport_size = get_viewport_rect().size
			position.x = clamp(position.x, 0, viewport_size.x - size.x)
			position.y = clamp(position.y, 0, viewport_size.y - size.y)
