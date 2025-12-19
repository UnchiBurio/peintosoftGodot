# DraggableNavigator.gd
extends TextureRect

var dragging := false
var drag_start_position := Vector2.ZERO
var border_color := Color.WHITE
var border_width := 2.0

func _ready():
	# マウス入力を受け付けるように設定
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)

func _draw():
	# 枠線を描画
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, border_color, false, border_width)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# ドラッグ開始
				dragging = true
				drag_start_position = get_global_mouse_position() - position
			else:
				# ドラッグ終了
				dragging = false
	
	elif event is InputEventMouseMotion:
		if dragging:
			# ドラッグ中の位置更新
			position = get_global_mouse_position() - drag_start_position
			
			# 画面外に出ないように制限
			var viewport_size = get_viewport_rect().size
			position.x = clamp(position.x, 0, viewport_size.x - size.x)
			position.y = clamp(position.y, 0, viewport_size.y - size.y)
