# DraggablePanel.gd
extends PanelContainer

signal close_requested

var dragging := false
var drag_start_position := Vector2.ZERO
var close_button: Button

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_setup_close_button()

func _setup_close_button() -> void:
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "x"
	close_button.tooltip_text = "閉じる"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(22, 22)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_on_close_button_pressed)
	var title_label = _find_first_label(self)
	if title_label and title_label.get_parent() is VBoxContainer:
		var title_parent = title_label.get_parent()
		var title_index = title_label.get_index()
		var header = HBoxContainer.new()
		header.name = "PanelHeader"
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_parent.remove_child(title_label)
		title_parent.add_child(header)
		title_parent.move_child(header, title_index)
		header.add_child(title_label)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(close_button)
	else:
		close_button.queue_free()
		close_button = null

func _find_first_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
		var nested_label = _find_first_label(child)
		if nested_label:
			return nested_label
	return null

func _on_close_button_pressed() -> void:
	hide()
	close_requested.emit()

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
