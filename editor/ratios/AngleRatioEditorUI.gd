class_name AngleRatioEditorUI
extends VBoxContainer

var ratio_manager: AngleRatioManager
var canvas: Node2D
var base_line_option: OptionButton
var target_lines_container: VBoxContainer

func _ready():
	ratio_manager = AngleRatioManager.new()
	setup_base_line_selection()
	setup_target_lines_container()
	setup_actions()

func setup_base_line_selection():
	var base_container = HBoxContainer.new()
	add_child(base_container)
	
	var base_label = Label.new()
	base_label.text = "Base Line:"
	base_container.add_child(base_label)
	
	base_line_option = OptionButton.new()
	base_container.add_child(base_line_option)
	base_line_option.item_selected.connect(_on_base_line_changed)

func setup_target_lines_container():
	var title = Label.new()
	title.text = "Target Lines"
	add_child(title)
	
	target_lines_container = VBoxContainer.new()
	add_child(target_lines_container)
	
	var add_button = Button.new()
	add_button.text = "Add Target Line"
	add_button.pressed.connect(add_target_line_entry)
	add_child(add_button)

func setup_actions():
	var update_button = Button.new()
	update_button.text = "Update Angles"
	update_button.pressed.connect(_update_angles)
	add_child(update_button)

func setup(canvas_ref: Node2D):
	canvas = canvas_ref
	ratio_manager.set_canvas(canvas)
	_update_line_options()

func _update_line_options():
	base_line_option.clear()
	if !canvas:
		return
		
	for i in range(canvas.preview_connections.size()):
		var connection = canvas.preview_connections[i]
		var display_name = connection.name if connection.name else "Connection " + str(i)
		base_line_option.add_item(display_name)


func _update_target_line_options(line_option: OptionButton):
	line_option.clear()
	if !canvas:
		return
		
	var count = -1
	for i in range(canvas.preview_connections.size()):
		if i != base_line_option.selected:
			count += 1
			var connection = canvas.preview_connections[i]
			var display_name = connection.name if connection.name else "Connection " + str(i)
			line_option.add_item(display_name)

func add_target_line_entry():
	var entry = HBoxContainer.new()
	target_lines_container.add_child(entry)
	
	var line_option = OptionButton.new()
	_update_target_line_options(line_option)
	entry.add_child(line_option)
	
	# リファレンスチェックボックスを追加
	var ref_check = CheckBox.new()
	ref_check.text = "Reference"
	entry.add_child(ref_check)
	ref_check.toggled.connect(func(pressed):
		if pressed:
			# 他のチェックボックスをオフにする
			for other_entry in target_lines_container.get_children():
				var other_check = other_entry.get_node_or_null("RefCheck")
				if other_check and other_check != ref_check:
					other_check.button_pressed = false
			# この線をリファレンス線として設定
			var line = canvas.preview_connections[line_option.selected]
			ratio_manager.set_reference_line(line)
		else:
			ratio_manager.set_reference_line(null)
	)
	ref_check.name = "RefCheck"  # 後で参照できるように名前を設定
	
	var ratio_label = Label.new()
	ratio_label.text = "Ratio:"
	entry.add_child(ratio_label)
	
	var ratio_spin = SpinBox.new()
	ratio_spin.min_value = -10.0
	ratio_spin.max_value = 10.0
	ratio_spin.step = 0.1
	ratio_spin.value = 1.0
	entry.add_child(ratio_spin)
	
	var remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(func(): 
		var line = canvas.preview_connections[line_option.selected]
		ratio_manager.remove_target_line(line)
		entry.queue_free()
	)
	entry.add_child(remove_button)
	
	line_option.item_selected.connect(func(idx):
		var selected_connection_idx = -1
		# 表示されているインデックスから実際の接続線のインデックスを計算
		var count = -1
		for i in range(canvas.preview_connections.size()):
			if i != base_line_option.selected:
				count += 1
				if count == idx:
					selected_connection_idx = i
					break
		
		if selected_connection_idx != -1:
			var line = canvas.preview_connections[selected_connection_idx]
			ratio_manager.add_target_line(line, ratio_spin.value)
			if ref_check.button_pressed:
				ratio_manager.set_reference_line(line)
	)
	
	ratio_spin.value_changed.connect(func(value):
		var selected_connection_idx = -1
		var count = -1
		for i in range(canvas.preview_connections.size()):
			if i != base_line_option.selected:
				count += 1
				if count == line_option.selected:
					selected_connection_idx = i
					break
		
		if selected_connection_idx != -1:
			var line = canvas.preview_connections[selected_connection_idx]
			ratio_manager.set_angle_ratio(line, value)
	)
	
	# 初期選択の処理
	if line_option.item_count > 0:
		line_option.select(0)
		var selected_connection_idx = 0
		for i in range(canvas.preview_connections.size()):
			if i != base_line_option.selected:
				selected_connection_idx = i
				break
		if selected_connection_idx >= 0:
			var line = canvas.preview_connections[selected_connection_idx]
			ratio_manager.add_target_line(line, ratio_spin.value)

func _on_base_line_changed(index: int):
	if index >= 0 and index < canvas.preview_connections.size():
		# 以前の対象線をクリア
		for entry in target_lines_container.get_children():
			entry.queue_free()
		
		# 新しい基準線を設定
		ratio_manager.set_base_line(canvas.preview_connections[index])
		
		# すべての対象線のオプションを更新
		for entry in target_lines_container.get_children():
			var line_option = entry.get_child(0) as OptionButton
			if line_option:
				_update_target_line_options(line_option)

func _update_angles():
	if ratio_manager.base_line == null:
		print("Base line is not set")
		return
	
	if ratio_manager.reference_line == null:
		print("Reference line is not set")
		return
	
	if ratio_manager.target_lines.is_empty():
		print("No target lines")
		return
	
	ratio_manager.update_angles()
	print("Angles updated")
