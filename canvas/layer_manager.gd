extends Window

@onready var layer_list: ItemList = $Panel/VBoxContainer/LayerList
@onready var add_button: Button = $Panel/VBoxContainer/HBoxContainer/AddButton
@onready var delete_button: Button = $Panel/VBoxContainer/HBoxContainer/DeleteButton

var current_canvas: Node2D = null

func _ready():
	# ウィンドウの「閉じる（X）」ボタンが押された時の挙動
	# close_requestedシグナルを接続して、消去(queue_free)せずに非表示(hide)にする
	close_requested.connect(func(): hide())
	
	# UIシグナル接続
	add_button.pressed.connect(_on_add_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	layer_list.item_selected.connect(_on_layer_selected)
	
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
		# 名前管理がまだ簡易的なので "Layer [index]" と表示
		var layer_name = "Layer " + str(i)
		layer_list.add_item(layer_name)
		print("LayerManager: Added item ", layer_name) # デバッグ用
	
	# 現在の選択状態を反映
	_update_selection(current_canvas.canvas_layer.current_layer_index)

func _update_selection(index: int):
	# 一旦選択解除
	layer_list.deselect_all()
	if layer_list.item_count > index:
		layer_list.select(index)

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
