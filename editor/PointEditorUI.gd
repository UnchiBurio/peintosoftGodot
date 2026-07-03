# PointEditorUI.gd
class_name PointEditorUI
extends VBoxContainer

var point: CanvasPreview.PreviewPoint
var canvas: Node2D
var index: int

func setup(point_data: CanvasPreview.PreviewPoint, idx: int, canvas_ref: Node2D):
	print("PointEditorUI-setup")
	point = point_data
	index = idx
	canvas = canvas_ref
	
	setup_header()
	setup_coordinates()
	setup_properties()
	setup_actions()
	add_child(HSeparator.new())

func setup_header():
	var header = HBoxContainer.new()
	add_child(header)
	
	# 名前入力フィールド
	var name_container = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Name: "
	name_container.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.text = point.name
	name_edit.custom_minimum_size.x = 100
	name_edit.text_changed.connect(func(new_name): 
		point.name = new_name
		canvas.queue_redraw()
	)
	name_container.add_child(name_edit)
	header.add_child(name_container)
	
	# 既存のインデックス表示
	var index_label = Label.new()
	index_label.text = "Point " + str(index)
	header.add_child(index_label)

func setup_coordinates():
	print("PointEditorUI-setup_coordinates")
	var coords = HBoxContainer.new()
	add_child(coords)
	
	# X座標
	var x_label = Label.new()
	x_label.text = "X:"
	coords.add_child(x_label)
	
	var x_spinbox = SpinBox.new()
	x_spinbox.min_value = 0
	x_spinbox.max_value = 10000
	x_spinbox.value = point.position.x
	x_spinbox.value_changed.connect(func(new_value): 
		point.position.x = new_value
		canvas.queue_redraw()
	)
	coords.add_child(x_spinbox)
	
	# Y座標
	var y_label = Label.new()
	y_label.text = "Y:"
	coords.add_child(y_label)
	
	var y_spinbox = SpinBox.new()
	y_spinbox.min_value = 0
	y_spinbox.max_value = 10000
	y_spinbox.value = point.position.y
	y_spinbox.value_changed.connect(func(new_value): 
		point.position.y = new_value
		canvas.queue_redraw()
	)
	coords.add_child(y_spinbox)

func setup_properties():
	print("PointEditorUI-setup_header")
	var properties = HBoxContainer.new()
	add_child(properties)
	
	# 無限線プロパティ
	var infinite_check = CheckBox.new()
	infinite_check.text = "無限線"
	infinite_check.button_pressed = point.has_property(canvas.PointProperty.INFINITE_LINE)
	infinite_check.toggled.connect(func(pressed):
		if pressed:
			point.add_property(canvas.PointProperty.INFINITE_LINE)
		else:
			point.remove_property(canvas.PointProperty.INFINITE_LINE)
		canvas.queue_redraw()
	)
	properties.add_child(infinite_check)
	
	# 直角線プロパティ
	var perpendicular_check = CheckBox.new()
	perpendicular_check.text = "直角線"
	perpendicular_check.button_pressed = point.has_property(canvas.PointProperty.PERPENDICULAR_LINE)
	perpendicular_check.toggled.connect(func(pressed):
		if pressed:
			point.add_property(canvas.PointProperty.PERPENDICULAR_LINE)
		else:
			point.remove_property(canvas.PointProperty.PERPENDICULAR_LINE)
		canvas.queue_redraw()
	)
	properties.add_child(perpendicular_check)

	var cursor_radius_circle_check = CheckBox.new()
	cursor_radius_circle_check.text = "カーソル半径円"
	cursor_radius_circle_check.button_pressed = point.has_property(canvas.PointProperty.CURSOR_RADIUS_CIRCLE)
	cursor_radius_circle_check.toggled.connect(func(pressed):
		if pressed:
			point.add_property(canvas.PointProperty.CURSOR_RADIUS_CIRCLE)
		else:
			point.remove_property(canvas.PointProperty.CURSOR_RADIUS_CIRCLE)
		canvas.queue_redraw()
	)
	properties.add_child(cursor_radius_circle_check)

func setup_actions():
	print("PointEditorUI-setup_actions")
	var buttons = HBoxContainer.new()
	add_child(buttons)
	
	var delete_button = Button.new()
	delete_button.text = "削除"
	delete_button.pressed.connect(func():
		canvas.preview_points.remove_at(index)
		canvas._update_editor()
		canvas.queue_redraw()
	)
	buttons.add_child(delete_button)
