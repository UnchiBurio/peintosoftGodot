# ConnectionEditorUI.gd
class_name ConnectionEditorUI
extends VBoxContainer

var connection: CanvasPreview.ConnectionLine
var canvas: Node2D
var index: int
var length_label: Label

func setup(connection_data: CanvasPreview.ConnectionLine, idx: int, canvas_ref: Node2D):
	connection = connection_data
	index = idx
	canvas = canvas_ref
	
	setup_header()
	setup_endpoints()
	setup_dimensions()
	setup_style()
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
	name_edit.text = connection.name
	name_edit.custom_minimum_size.x = 100
	name_edit.text_changed.connect(func(new_name): 
		connection.name = new_name
		canvas.queue_redraw()
	)
	name_container.add_child(name_edit)
	header.add_child(name_container)
	
	# 既存のインデックス表示
	var index_label = Label.new()
	index_label.text = "Connection " + str(index)
	header.add_child(index_label)

func setup_endpoints():
	var endpoints = HBoxContainer.new()
	add_child(endpoints)
	
	# 開始点選択
	var start_label = Label.new()
	start_label.text = "Start:"
	endpoints.add_child(start_label)
	
	var start_option = OptionButton.new()
	_update_point_options(start_option, connection.start_point)
	start_option.item_selected.connect(func(idx):
		connection.start_point = canvas.preview_points[idx]
		_update_length_display()
		canvas.queue_redraw()
	)
	endpoints.add_child(start_option)
	
	# 終点選択
	var end_label = Label.new()
	end_label.text = "End:"
	endpoints.add_child(end_label)
	
	var end_option = OptionButton.new()
	_update_point_options(end_option, connection.end_point)
	end_option.item_selected.connect(func(idx):
		connection.end_point = canvas.preview_points[idx]
		_update_length_display()
		canvas.queue_redraw()
	)
	endpoints.add_child(end_option)

func setup_dimensions():
	print("setup_dimensions")
	# 長さ設定
	var length_container = HBoxContainer.new()
	add_child(length_container)
	
	var length_text = Label.new()
	length_text.text = "Length:"
	length_container.add_child(length_text)
	
	var length_spin = SpinBox.new()
	length_spin.min_value = 1
	length_spin.max_value = 10000
	length_spin.step = 0.1
	length_spin.value = connection.get_length()
	length_spin.value_changed.connect(func(new_length): 
		_update_connection_length(new_length)
		canvas.queue_redraw()
	)
	length_container.add_child(length_spin)
	
	length_label = Label.new()
	_update_length_display()
	length_container.add_child(length_label)
	
	# 角度設定
	var angle_container = HBoxContainer.new()
	add_child(angle_container)
	
	var angle_label = Label.new()
	angle_label.text = "Angle:"
	angle_container.add_child(angle_label)
	
	# 絶対角度/相対角度切り替え
	var angle_mode = OptionButton.new()
	angle_mode.add_item("Absolute", 0)
	angle_mode.add_item("Relative", 1)
	angle_container.add_child(angle_mode)
	
	# 基準線選択（初期状態では非表示）
	var reference_container = HBoxContainer.new()
	reference_container.visible = false
	add_child(reference_container)
	
	var ref_label = Label.new()
	ref_label.text = "Reference Line:"
	reference_container.add_child(ref_label)
	
	var ref_option = OptionButton.new()
	_update_reference_options(ref_option)
	reference_container.add_child(ref_option)
	
	var angle_spin = SpinBox.new()
	angle_spin.min_value = -360
	angle_spin.max_value = 360
	angle_spin.step = 1
	
	var current_angle = rad_to_deg((connection.end_point.position - connection.start_point.position).angle())
	angle_spin.value = current_angle
	angle_container.add_child(angle_spin)
	
	# モード切り替え時の処理
	angle_mode.item_selected.connect(func(index):
		reference_container.visible = (index == 1)  # 相対モードの時のみ表示
		if index == 0:  # 絶対角度モード
			var absolute_angle = rad_to_deg((connection.end_point.position - connection.start_point.position).angle())
			angle_spin.value = absolute_angle
		else:  # 相対角度モード
			if ref_option.selected >= 0:
				_update_relative_angle(ref_option, angle_spin)
	)
	
	# 基準線変更時の処理
	ref_option.item_selected.connect(func(index):
		if angle_mode.selected == 1:  # 相対モードの時のみ
			_update_relative_angle(ref_option, angle_spin)
	)
	
	# 角度変更時の処理
	angle_spin.value_changed.connect(func(new_angle): 
		if angle_mode.selected == 0:  # 絶対角度モード
			_update_connection_angle(deg_to_rad(new_angle), connection.get_length())
		else:  # 相対角度モード
			_update_relative_connection_angle(ref_option, new_angle, connection.get_length())
		canvas.queue_redraw()
	)
	
	 # 位置設定用のコンテナ
	var position_container = HBoxContainer.new()
	add_child(position_container)

	var position_label = Label.new()
	position_label.text = "Position:"
	position_container.add_child(position_label)

	# X座標
	var x_label = Label.new()
	x_label.text = "X:"
	position_container.add_child(x_label)

	var x_spin = SpinBox.new()
	x_spin.min_value = 0
	x_spin.max_value = 10000
	x_spin.step = 1
	x_spin.value = connection.get_display_position().x
	position_container.add_child(x_spin)

	# Y座標
	var y_label = Label.new()
	y_label.text = "Y:"
	position_container.add_child(y_label)

	var y_spin = SpinBox.new()
	y_spin.min_value = 0
	y_spin.max_value = 10000
	y_spin.step = 1
	y_spin.value = connection.get_display_position().y
	position_container.add_child(y_spin)

	# 位置変更時の処理
	x_spin.value_changed.connect(func(new_x):
		var current_pos = connection.get_display_position()
		connection.update_position(Vector2(new_x, current_pos.y))
		canvas.queue_redraw()
	)

	y_spin.value_changed.connect(func(new_y):
		var current_pos = connection.get_display_position()
		connection.update_position(Vector2(current_pos.x, new_y))
		canvas.queue_redraw()
	)

func normalize_angle(angle: float) -> float:
	var normalized = fmod(angle + 180.0, 360.0) - 180.0
	if normalized < -180.0:
		normalized += 360.0
	return normalized

# 基準線選択肢の更新
func _update_reference_options(option_button: OptionButton):
	option_button.clear()
	for i in range(canvas.preview_connections.size()):
		if canvas.preview_connections[i] != connection:  # 自分自身は除外
			option_button.add_item("Connection " + str(i), i)

# 相対角度の更新
func _update_relative_angle(ref_option: OptionButton, angle_spin: SpinBox):
	if ref_option.selected < 0:
		return
		
	var ref_line = canvas.preview_connections[ref_option.selected]
	var ref_angle = rad_to_deg((ref_line.end_point.position - ref_line.start_point.position).angle())
	var current_angle = rad_to_deg((connection.end_point.position - connection.start_point.position).angle())
	var relative_angle = normalize_angle(current_angle - ref_angle)
	
	print("Reference angle: ", ref_angle)
	print("Current angle: ", current_angle)
	print("Relative angle (raw): ", current_angle - ref_angle)
	print("Relative angle (normalized): ", relative_angle)
	
	angle_spin.value = relative_angle
	
# 相対角度に基づく接続線の更新
func _update_relative_connection_angle(ref_option: OptionButton, relative_angle: float, length: float):
	if ref_option.selected < 0:
		return
		
	var ref_line = canvas.preview_connections[ref_option.selected]
	var ref_angle = rad_to_deg((ref_line.end_point.position - ref_line.start_point.position).angle())
	
	# 絶対角度を計算し、-180から180の範囲に正規化
	var absolute_angle = normalize_angle(ref_angle + relative_angle)
	_update_connection_angle(deg_to_rad(absolute_angle), length)

func setup_style():
	# タイプ選択
	var type_container = HBoxContainer.new()
	add_child(type_container)
	
	var type_label = Label.new()
	type_label.text = "Type:"
	type_container.add_child(type_label)
	
	var type_option = OptionButton.new()
	type_option.add_item("Normal", CanvasPreview.ConnectionLine.LineType.NORMAL)
	type_option.add_item("Guide", CanvasPreview.ConnectionLine.LineType.GUIDE)
	type_option.add_item("Dimension", CanvasPreview.ConnectionLine.LineType.DIMENSION)
	type_option.add_item("Extension", CanvasPreview.ConnectionLine.LineType.EXTENSION)
	type_option.selected = connection.type
	type_option.item_selected.connect(func(index): 
		connection.type = index
		canvas.queue_redraw()
	)
	type_container.add_child(type_option)
	
	# スタイル設定
	var style_container = HBoxContainer.new()
	add_child(style_container)
	
	# 色選択
	var color_label = Label.new()
	color_label.text = "Color:"
	style_container.add_child(color_label)
	
	var color_picker = ColorPickerButton.new()
	color_picker.color = connection.style["color"]
	color_picker.custom_minimum_size = Vector2(50, 20)
	color_picker.color_changed.connect(func(color): 
		connection.style["color"] = color
		canvas.queue_redraw()
	)
	style_container.add_child(color_picker)
	
	# 線の太さ
	var width_label = Label.new()
	width_label.text = "Width:"
	style_container.add_child(width_label)
	
	var width_spin = SpinBox.new()
	width_spin.min_value = 1
	width_spin.max_value = 10
	width_spin.value = connection.style["width"]
	width_spin.value_changed.connect(func(value): 
		connection.style["width"] = value
		canvas.queue_redraw()
	)
	style_container.add_child(width_spin)

func setup_actions():
	var buttons = HBoxContainer.new()
	add_child(buttons)
	
	var delete_button = Button.new()
	delete_button.text = "削除"
	delete_button.pressed.connect(func():
		canvas.preview_connections.remove_at(index)
		canvas._update_editor()
		canvas.queue_redraw()
	)
	buttons.add_child(delete_button)

func _update_point_options(option_button: OptionButton, selected_point: CanvasPreview.PreviewPoint):
	option_button.clear()
	for i in range(canvas.preview_points.size()):
		var point = canvas.preview_points[i]
		option_button.add_item("Point " + str(i) + " (" + str(point.position) + ")")
		if point == selected_point:
			option_button.selected = i

func _update_connection_length(new_length: float):
	var direction = (connection.end_point.position - connection.start_point.position).normalized()
	connection.end_point.position = connection.start_point.position + direction * new_length
	_update_length_display()

func _update_connection_angle(angle: float, length: float):
	var direction = Vector2(cos(angle), sin(angle))
	connection.end_point.position = connection.start_point.position + direction * length

func _update_length_display():
	if length_label:
		var length = connection.get_length()
		length_label.text = "Current Length: %.1f" % length
