class_name IntersectionRatioEditorUI
extends VBoxContainer

var ratio_manager: IntersectionRatioManager
var canvas: Node2D
var base_line_option: OptionButton
var target_lines_container: VBoxContainer
var segment_ratios_container: VBoxContainer

func _ready():
	ratio_manager = IntersectionRatioManager.new()
	setup_base_line_selection()
	setup_target_lines_container()
	setup_segment_ratios_container()
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
	# 「Add Target Line」ボタンを押したときの処理を修正
	add_button.pressed.connect(func():
		# 利用可能な接続線の数を計算
		# 基準線として1本使用するので、全体から1を引く
		var available_connections = canvas.preview_connections.size() - 1
		# 現在のターゲットライン数を取得
		var current_target_lines = target_lines_container.get_child_count()
		
		if current_target_lines >= available_connections:
			# これ以上追加できない場合は警告ダイアログを表示
			_show_warning_dialog("Cannot add more target lines. No more connections available.")
			return
			
		# 追加可能な場合は通常通り追加処理を実行
		add_target_line_entry()
	)
	add_child(add_button)

# 警告ダイアログを表示する関数を追加
func _show_warning_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Warning"
	dialog.dialog_text = message
	dialog.size = Vector2i(300, 100)  # ダイアログのサイズを設定
	
	# ダイアログを画面に追加して表示
	add_child(dialog)
	dialog.popup_centered()
	
	# ダイアログが閉じられたら削除
	dialog.confirmed.connect(func(): dialog.queue_free())
func setup_segment_ratios_container():
	var title = Label.new()
	title.text = "Segment Ratios"
	add_child(title)
	
	segment_ratios_container = VBoxContainer.new()
	add_child(segment_ratios_container)

func setup_actions():
	var update_button = Button.new()
	update_button.text = "Update Positions"
	update_button.pressed.connect(_update_positions)
	add_child(update_button)

# IntersectionRatioEditorUIクラス内
func setup(canvas_ref: Node2D):
	canvas = canvas_ref
	ratio_manager.set_canvas(canvas)
	_update_line_options()
	
	# 接続線が存在する場合、選択されている接続線を基準線として設定
	if canvas.preview_connections.size() > 0:
		# まず、選択されている接続線を探す
		var selected_line = null
		for connection in canvas.preview_connections:
			if connection.state == CanvasPreview.ConnectionLine.LineState.SELECTED:
				selected_line = connection
				break
		
		# 選択されている接続線があれば、それを基準線として設定
		if selected_line != null:
			# 接続線のインデックスを見つける
			var selected_index = canvas.preview_connections.find(selected_line)
			if selected_index != -1:
				# ドロップダウンの選択を更新
				base_line_option.select(selected_index)
				# 基準線として設定
				ratio_manager.set_base_line(selected_line)
				# 対象線の選択肢を更新
				for entry in target_lines_container.get_children():
					_update_target_line_options(entry.get_child(0))
				_update_segment_ratios_ui()
		# 選択されている接続線がない場合は、最初の接続線を選択
		elif canvas.preview_connections.size() > 0:
			base_line_option.select(0)
			ratio_manager.set_base_line(canvas.preview_connections[0])
			_update_segment_ratios_ui()

func _update_line_options():
	base_line_option.clear()
	if !canvas:
		return
		
	for i in range(canvas.preview_connections.size()):
		var connection = canvas.preview_connections[i]
		var display_name = connection.name if connection.name else "Connection " + str(i)
		base_line_option.add_item(display_name)

func remove_target_line_entry(entry: HBoxContainer, line_option: OptionButton):
	if !entry or !line_option:
		push_error("Invalid entry or line option")
		return
		
	if line_option.selected >= 0:
		var selected_line = canvas.preview_connections[line_option.selected]
		if selected_line:
			ratio_manager.remove_target_line(selected_line)
			entry.queue_free()
			_update_segment_ratios_ui()
			print("Target line removed. Current count: ", ratio_manager.target_lines.size())
		else:
			push_error("Selected line not found in preview connections")
	else:
		push_warning("No line selected for removal")
		entry.queue_free()  # UIは削除してよい

func add_target_line_entry():
	# 利用可能な接続線の数を計算
	# 基準線として1本使用するので、全体から1を引く
	var available_connections = canvas.preview_connections.size() - 1
	# 現在のターゲットライン数を取得
	var current_target_lines = target_lines_container.get_child_count()
	
	# これ以上追加できない場合は警告を表示して終了
	if current_target_lines >= available_connections:
		_show_warning_dialog("Cannot add more target lines. No more connections available.")
		return
	
	# ターゲットライン用のコンテナを作成
	var entry = HBoxContainer.new()
	target_lines_container.add_child(entry)
	
	# 現在の選択を追跡するための変数
	var current_selected_line: CanvasPreview.ConnectionLine = null
	
	# 対象線の選択用ドロップダウンを作成
	var line_option = OptionButton.new()
	_update_target_line_options(line_option)
	entry.add_child(line_option)
	
	# 比率ラベルを追加
	var ratio_label = Label.new()
	ratio_label.text = "Ratio  "
	entry.add_child(ratio_label)
	
	# 上部の比率入力
	var upper_ratio_spin = SpinBox.new()
	upper_ratio_spin.min_value = 0.1
	upper_ratio_spin.max_value = 10.0
	upper_ratio_spin.step = 0.1
	upper_ratio_spin.value = 1.0
	entry.add_child(upper_ratio_spin)
	
	# 比率の区切り文字
	var ratio_separator = Label.new()
	ratio_separator.text = " : "
	entry.add_child(ratio_separator)
	
	# 下部の比率入力
	var lower_ratio_spin = SpinBox.new()
	lower_ratio_spin.min_value = 0.1
	lower_ratio_spin.max_value = 10.0
	lower_ratio_spin.step = 0.1
	lower_ratio_spin.value = 1.0
	entry.add_child(lower_ratio_spin)
	
	# 削除ボタン
	var remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(func(): 
		remove_target_line_entry(entry, line_option)
	)
	entry.add_child(remove_button)
	
	# 現在の選択を追跡するための変数をエントリーのメタデータとして保存
	entry.set_meta("current_line", null)
	
	# 選択変更時のハンドラを改善
	line_option.item_selected.connect(func(idx):
		var new_line = canvas.preview_connections[idx]
		
		# 現在の選択を取得
		var current_line = entry.get_meta("current_line")
		
		# もし現在の選択が存在し、それが新しい選択と異なる場合は削除
		if current_line != null and current_line != new_line:
			ratio_manager.remove_target_line(current_line)
			print("Removed target line: ", current_line)
		
		# 新しい選択を設定
		entry.set_meta("current_line", new_line)
		
		# 新しい線を追加（まだターゲットラインに含まれていない場合のみ）
		if not ratio_manager.target_lines.has(new_line):
			ratio_manager.add_target_line(
				new_line,
				Vector2(upper_ratio_spin.value, lower_ratio_spin.value)
			)
			print("Added new target line: ", new_line)
		
		_update_segment_ratios_ui()
	)
	
	# 上部比率が変更されたときのハンドラ
	upper_ratio_spin.value_changed.connect(func(value):
		var current_line = entry.get_meta("current_line")
		if current_line != null:
			ratio_manager.set_target_ratio(
				current_line,
				Vector2(value, lower_ratio_spin.value)
			)
	)

	# 下部比率が変更されたときのハンドラ
	lower_ratio_spin.value_changed.connect(func(value):
		var current_line = entry.get_meta("current_line")
		if current_line != null:
			ratio_manager.set_target_ratio(
				current_line,
				Vector2(upper_ratio_spin.value, value)
			)
	)
	
	# 初期選択の処理
	if line_option.item_count > 0:
		line_option.select(0)
		current_selected_line = canvas.preview_connections[0]
		ratio_manager.add_target_line(current_selected_line, Vector2(1.0, 1.0))
		_update_segment_ratios_ui()

func _update_target_line_options(option_button: OptionButton):
	option_button.clear()
	if !canvas:
		return
		
	# キャンバスの各接続線をオプションとして追加
	for i in range(canvas.preview_connections.size()):
		var connection = canvas.preview_connections[i]
		var display_name = connection.name if connection.name else "Connection " + str(i)
		option_button.add_item(display_name, i)

func _update_segment_ratios_ui():
	print("updating UI with segments:", ratio_manager.segment_ratios.size())  # デバッグ出力を追加
	print("Target lines count: ", ratio_manager.target_lines.size())
	print("UI entries count: ", target_lines_container.get_child_count())
	print("Segment ratios count: ", ratio_manager.segment_ratios.size())
	for child in segment_ratios_container.get_children():
		child.queue_free()
	
	for i in range(ratio_manager.segment_ratios.size()):
		var entry = HBoxContainer.new()
		segment_ratios_container.add_child(entry)
		
		var label = Label.new()
		label.text = "Segment " + str(i) + ":"
		entry.add_child(label)
		
		var ratio_spin = SpinBox.new()
		ratio_spin.min_value = 0.1
		ratio_spin.max_value = 10.0
		ratio_spin.step = 0.1
		ratio_spin.value = ratio_manager.segment_ratios[i]
		ratio_spin.value_changed.connect(func(value): 
			ratio_manager.set_segment_ratio(i, value)
		)
		entry.add_child(ratio_spin)

func _on_base_line_changed(index: int):
	if index >= 0 and index < canvas.preview_connections.size():
		ratio_manager.set_base_line(canvas.preview_connections[index])
		# 対象線のオプションを更新
		for entry in target_lines_container.get_children():
			_update_target_line_options(entry.get_child(0))
		_update_segment_ratios_ui()

func _update_positions():
	ratio_manager.update_positions()
