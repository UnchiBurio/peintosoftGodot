# DraggablePanel.gd
extends PanelContainer

var dragging := false
var drag_start_position := Vector2.ZERO

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start_position = get_global_mouse_position() - position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		position = get_global_mouse_position() - drag_start_position
		_clamp_to_viewport()

func _clamp_to_viewport():
	var viewport_size = get_viewport_rect().size
	var clamped_x = clamp(position.x, 0, viewport_size.x - size.x)
	var clamped_y = clamp(position.y, 0, viewport_size.y - size.y)
	position = Vector2(clamped_x, clamped_y)
