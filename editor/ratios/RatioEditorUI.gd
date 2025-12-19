# RatioEditorUI.gd
class_name RatioEditorUI
extends VBoxContainer

var ratio_manager: RatioManager
var canvas: Node2D
var entries_container: VBoxContainer
var param_option: OptionButton

var current_ratio_label:Label
var current_ratio:String=""

func _ready():
	# 基本的なUIコンポーネントの初期化
	ratio_manager = RatioManager.new()
	setup_parameter_selection()
	setup_entries_container()
	setup_actions()
	
func setup(canvas_ref: Node2D):
	# 既存のエントリーをクリア
	if entries_container:
		_clear_all_entries()
	
	# 新しいキャンバスの設定
	canvas = canvas_ref
	ratio_manager.set_canvas(canvas)

# パラメータ選択UIの設定
func setup_parameter_selection():
	var param_container = HBoxContainer.new()
	add_child(param_container)
	
	current_ratio_label = Label.new()
	current_ratio_label.text = "Target Parameter:"
	param_container.add_child(current_ratio_label)
	
	var param_label = Label.new()
	param_label.text = "Target Parameter:"
	param_container.add_child(param_label)
	
	param_option = OptionButton.new()
	param_option.add_item("Length", RatioManager.TargetParameter.LENGTH)
	param_option.add_item("Angle", RatioManager.TargetParameter.ANGLE)
	param_option.selected = 0
	param_option.item_selected.connect(_on_parameter_changed)
	param_container.add_child(param_option)

# エントリーコンテナの設定
func setup_entries_container():
	entries_container = VBoxContainer.new()
	add_child(entries_container)
	
	var add_button = Button.new()
	add_button.text = "Add Ratio Entry"
	add_button.pressed.connect(add_ratio_entry)
	add_child(add_button)

# アクションボタンの設定
func setup_actions():
	var actions_container = HBoxContainer.new()
	add_child(actions_container)
	
	var update_button = Button.new()
	update_button.text = "Update Ratios"
	update_button.pressed.connect(_update_ratio_entries)
	actions_container.add_child(update_button)
	
	var clear_button = Button.new()
	clear_button.text = "Clear All"
	clear_button.pressed.connect(_clear_all_entries)
	actions_container.add_child(clear_button)

# 新しい比率エントリーの追加
func add_ratio_entry():
	if canvas.preview_connections.is_empty():
		_show_error_dialog("No connections available")
		return
	
	var entry_container = _create_ratio_entry_container()
	entries_container.add_child(entry_container)
	_update_ratio_entries()
	print("追加",ratio_manager.entries)
	
	print("追加2",ratio_manager.entries)
	
	print("追加3",ratio_manager.entries)

# 比率エントリーコンテナの作成
func _create_ratio_entry_container() -> HBoxContainer:
	var entry_container = HBoxContainer.new()
	
	# Ratio input
	var ratio_label = Label.new()
	ratio_label.text = "Ratio:"
	entry_container.add_child(ratio_label)
	
	var ratio_spin = SpinBox.new()
	ratio_spin.min_value = 0.1
	ratio_spin.max_value = 10.0
	ratio_spin.step = 0.1
	ratio_spin.value = 1.0
	entry_container.add_child(ratio_spin)
	
	# Connection selection
	var connection_label = Label.new()
	connection_label.text = "Connection:"
	entry_container.add_child(connection_label)
	
	var connection_option = OptionButton.new()
	_update_connection_options(connection_option)
	entry_container.add_child(connection_option)
	
	# Reference checkbox
	var ref_check = CheckBox.new()
	ref_check.text = "Reference"
	ref_check.toggled.connect(_on_reference_toggled.bind(ref_check))
	entry_container.add_child(ref_check)
	
	# Delete button
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(func():
		entry_container.queue_free()
		_update_ratio_entries()
	)
	entry_container.add_child(delete_button)
	
	return entry_container

# 接続オプションの更新
func _update_connection_options(option_button: OptionButton):
	option_button.clear()
	for i in range(canvas.preview_connections.size()):
		var connection = canvas.preview_connections[i]
		# 名前がない場合はデフォルトの表示を使用
		var display_name = connection.name if connection.name else "Connection " + str(i)
		option_button.add_item(display_name)
		if i == 0:
			option_button.selected = 0

# 比率エントリーの更新
func _update_ratio_entries():
	ratio_manager.entries.clear()
	var has_reference = false
	
	for entry_container in entries_container.get_children():
		if not (entry_container is HBoxContainer):
			continue
		
		var ratio_spin = entry_container.get_child(1) as SpinBox
		var connection_option = entry_container.get_child(3) as OptionButton
		var ref_check = entry_container.get_child(4) as CheckBox
		
		if not (ratio_spin and connection_option and ref_check):
			continue
		
		if connection_option.selected >= 0 and connection_option.selected < canvas.preview_connections.size():
			var connection = canvas.preview_connections[connection_option.selected]
			ratio_manager.add_entry(ratio_spin.value, connection, ref_check.button_pressed)
			if ref_check.button_pressed:
				has_reference = true
	
	if not has_reference and entries_container.get_child_count() > 0:
		var first_entry = entries_container.get_child(0)
		if first_entry is HBoxContainer:
			var ref_check = first_entry.get_child(4) as CheckBox
			if ref_check:
				ref_check.button_pressed = true
				_update_ratio_entries()
				return
	
	ratio_manager.target_parameter = param_option.selected
	ratio_manager.update_connections()
	calculate_connections()

# リファレンスチェックボックスの切り替え処理
func _on_reference_toggled(toggled: bool, current_check: CheckBox):
	if toggled:
		for entry_container in entries_container.get_children():
			if not (entry_container is HBoxContainer):
				continue
			
			var ref_check = entry_container.get_child(4) as CheckBox
			if ref_check and ref_check != current_check:
				ref_check.button_pressed = false
	

# パラメータ変更時の処理
func _on_parameter_changed(_index: int):
	pass

# 全エントリーのクリア
func _clear_all_entries():
	for entry in entries_container.get_children():
		entry.queue_free()
	ratio_manager.entries.clear()
	_update_ratio_entries()

# エラーダイアログの表示
func _show_error_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	
func calculate_connections():
	var c=[]
	for e in ratio_manager.entries:
		c.append(e.connection.get_length())
	var ratio=calculate_ratio(c)
	current_ratio_label.text=ratio
	
func calculate_ratio(numbers: Array) -> String:
	"""
	複数の数値の比を計算して文字列として返します。

	引数:
		numbers: 数値の配列 (例: [12, 18, 30])

	戻り値:
		比を表す文字列 (例: "2:3:5")。
		数値が2つ以上ない場合や、数値以外が含まれる場合は "Error" を返します。
	"""
	if numbers.size() < 2:
		printerr("Error: 比率を計算するには2つ以上の数値が必要です。")
		return "Error"

	for num in numbers:
		if typeof(num) != TYPE_INT and typeof(num) != TYPE_FLOAT:
			printerr("Error: 数値以外の値が配列に含まれています。")
			return "Error"

	var common_divisor = numbers[0]
	for i in range(1, numbers.size()):
		common_divisor = _gcd(common_divisor, numbers[i])

	if common_divisor == 0:
		printerr("Error: 共通の約数が0です。") # 念のため
		return "Error"

	var ratios = []
	for num in numbers:
		ratios.append(num / common_divisor)

	var ratio_str_array = []
	for ratio in ratios:
		ratio_str_array.append(str(ratio)) # 整数で表示したい場合は int(ratio) にキャスト

	return ":".join(ratio_str_array)


func _gcd(a: int, b: int) -> int:
	"""
	ユークリッドの互除法で最大公約数を計算するヘルパー関数
	"""
	while b != 0:
		var temp = b
		b = a % b
		a = temp
	return abs(a) # 負の数の場合も考慮して絶対値を返す
	
