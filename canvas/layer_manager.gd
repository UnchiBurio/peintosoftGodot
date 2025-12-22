extends Window

@onready var layer_list: ItemList = $Panel/VBoxContainer/LayerList
@onready var add_button: Button = $Panel/VBoxContainer/HBoxContainer/AddButton
@onready var delete_button: Button = $Panel/VBoxContainer/HBoxContainer/DeleteButton
@onready var name_edit: LineEdit = $Panel/VBoxContainer/NameEdit
@onready var visibility_toggle: CheckBox = $Panel/VBoxContainer/VisibilityToggle

var current_canvas: Node2D = null
var drag_start_index := -1
var is_dragging := false
var _is_updating_ui := false

func _ready():
	# ウィンドウの「閉じる（X）」ボタンが押された時の挙動
	# close_requestedシグナルを接続して、消去(queue_free)せずに非表示(hide)にする
	close_requested.connect(func(): hide())
	
	# UIシグナル接続
	add_button.pressed.connect(_on_add_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	layer_list.item_selected.connect(_on_layer_selected)
	layer_list.gui_input.connect(_on_layer_list_gui_input)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.focus_exited.connect(func(): _on_name_submitted(name_edit.text))
	visibility_toggle.toggled.connect(_on_visibility_toggled)
	
	# 初期状態
	_clear_ui()

# Mainから呼ばれる：操作対象のキャンバスを切り替える
func set_target_canvas(canvas: Node2D):
	print("LayerManager: set_target_canvas called. Canvas: ", canvas) # デバッグ用
	
	# 同じキャンバスなら何もしない（ただしnullの場合は更新）
	if current_canvas == canvas and canvas != null:
		return

	# 古いキャンバスのシグナルを切断
	if current_canvas and is_instance_valid(current_canvas):
		if current_canvas.is_connected("layer_structure_changed", _refresh_list):
			current_canvas.disconnect("layer_structure_changed", _refresh_list)
		if current_canvas.is_connected("active_layer_changed", _update_selection):
			current_canvas.disconnect("active_layer_changed", _update_selection)
	
	current_canvas = canvas
	
	if current_canvas:
		# 新しいキャンバスのシグナルを接続
		if not current_canvas.is_connected("layer_structure_changed", _refresh_list):
			current_canvas.layer_structure_changed.connect(_refresh_list)
		if not current_canvas.is_connected("active_layer_changed", _update_selection):
			current_canvas.active_layer_changed.connect(_update_selection)
		
		# UI有効化
		add_button.disabled = false
		delete_button.disabled = false
		_refresh_list()
		
		# キャンバスが選択されたらウィンドウを表示する（お好みで）
		if not visible:
			show()
	else:
		_clear_ui()

func _clear_ui():
	layer_list.clear()
	add_button.disabled = true
	delete_button.disabled = true
	name_edit.editable = false
	name_edit.text = ""
	visibility_toggle.disabled = true
	visibility_toggle.button_pressed = false

func _refresh_list():
	print("LayerManager: Refreshing list...") # デバッグ用
	
	if not current_canvas: 
		print("LayerManager: No canvas to refresh.")
		return
	
	layer_list.clear()
	print("LayerManager: Layer count = ", current_canvas.layers.size()) # デバッグ用
	
	# レイヤーリストを構築
	# 配列のインデックスと表示順を合わせるため、そのまま追加
	for i in range(current_canvas.layers.size()):
		var layer_name = current_canvas.layers[i].name
		var prefix = "👁 " if current_canvas.layers[i].visible else "🚫 "
		layer_list.add_item(prefix + layer_name)
		print("LayerManager: Added item ", layer_name) # デバッグ用
	
	# 現在の選択状態を反映
	_update_selection(current_canvas.canvas_layer.current_layer_index)

func _update_selection(index: int):
	# 一旦選択解除
	layer_list.deselect_all()
	if layer_list.item_count > index:
		layer_list.select(index)
		_is_updating_ui = true
		name_edit.editable = true
		name_edit.text = current_canvas.layers[index].name
		visibility_toggle.disabled = false
		visibility_toggle.set_pressed_no_signal(current_canvas.layers[index].visible)
		_is_updating_ui = false
	else:
		name_edit.editable = false
		name_edit.text = ""
		visibility_toggle.disabled = true

# --- ボタン操作 ---

func _on_add_button_pressed():
	if current_canvas:
		current_canvas._add_layer("New Layer")

func _on_delete_button_pressed():
	if current_canvas:
		# 前回の回答で追加したメソッドを呼び出す
		current_canvas.delete_current_layer()

func _on_layer_selected(index: int):
	if current_canvas:
		current_canvas.change_active_layer(index)
		name_edit.text = current_canvas.layers[index].name
		visibility_toggle.set_pressed_no_signal(current_canvas.layers[index].visible)

func _on_name_submitted(new_text: String):
	if not current_canvas:
		return
	var index = _get_selected_index()
	if index == -1:
		return
	current_canvas.rename_layer(index, new_text)
	_refresh_list()
	_update_selection(index)

func _on_name_changed(new_text: String):
	if _is_updating_ui:
		return
	_on_name_submitted(new_text)

func _on_visibility_toggled(toggled_on: bool):
	if not current_canvas:
		return
	var index = _get_selected_index()
	if index == -1:
		return
	current_canvas.set_layer_visibility(index, toggled_on)
	_refresh_list()
	_update_selection(index)

func _on_layer_list_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start_index = layer_list.get_item_at_position(event.position, true)
			if drag_start_index != -1 and event.position.x <= 24:
				current_canvas.set_layer_visibility(drag_start_index, !current_canvas.layers[drag_start_index].visible)
				_refresh_list()
				_update_selection(current_canvas.canvas_layer.current_layer_index)
				drag_start_index = -1
				return
		else:
			if is_dragging:
				var target_index = layer_list.get_item_at_position(event.position, true)
				_finish_drag(target_index)
			drag_start_index = -1
			is_dragging = false
	elif event is InputEventMouseMotion and drag_start_index != -1 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		is_dragging = true

func _finish_drag(target_index: int):
	if drag_start_index != -1 and target_index != -1 and current_canvas:
		current_canvas.move_layer(drag_start_index, target_index)
	_refresh_list()
	if current_canvas:
		_update_selection(current_canvas.canvas_layer.current_layer_index)
	drag_start_index = -1
	is_dragging = false

func _get_selected_index() -> int:
	if layer_list.get_selected_items().is_empty():
		return -1
	return layer_list.get_selected_items()[0]
