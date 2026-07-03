extends Window

var canvas: Node2D
var point_editor: PointEditor
var connection_editor: ConnectionEditor
var ratio_editor: RatioEditorUI
var intersection_ratio_editor: IntersectionRatioEditorUI
var angle_ratio_editor: AngleRatioEditorUI
var ui_manager: PreviewLinesUIManager
var last_update_time: float = 0.0
const MIN_UPDATE_INTERVAL: float = 0.1  # 100ms

func _ready():
	title = "プレビュー線エディタ"
	position = Vector2i(100, 100)
	size = Vector2i(500, 600)
	
	point_editor = PointEditor.new()
	connection_editor = ConnectionEditor.new()
	ratio_editor = RatioEditorUI.new()
	intersection_ratio_editor = IntersectionRatioEditorUI.new()
	angle_ratio_editor = AngleRatioEditorUI.new()
	
	# タブ付きUIマネージャーのセットアップ
	ui_manager = PreviewLinesUIManager.new()
	add_child(ui_manager)
	ui_manager.setup_ui(point_editor, connection_editor, ratio_editor, 
					   intersection_ratio_editor, angle_ratio_editor)

func set_active_canvas(new_canvas: Node2D):
	# 以前のキャンバスからシグナルを切断
	if canvas and canvas.is_connected("canvas_updated", _on_canvas_updated):
		canvas.disconnect("canvas_updated", _on_canvas_updated)
	
	canvas = new_canvas
	if canvas:
		# 新しいキャンバスにシグナルを接続
		if not canvas.is_connected("canvas_updated", _on_canvas_updated):
			canvas.connect("canvas_updated", _on_canvas_updated)
		
		point_editor.canvas = canvas
		connection_editor.canvas = canvas
		ratio_editor.setup(canvas)
		intersection_ratio_editor.setup(canvas)
		angle_ratio_editor.setup(canvas)
		update_editor()

func update_editor():
	if !canvas:
		return
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_update_time < MIN_UPDATE_INTERVAL:
		return
		
	point_editor.update_points()
	connection_editor.update_connections()
	last_update_time = current_time

# キャンバスが更新されたときのコールバック
func _on_canvas_updated():
	update_editor()

# ウィンドウが閉じられるときの処理
func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if canvas and canvas.is_connected("canvas_updated", _on_canvas_updated):
			canvas.disconnect("canvas_updated", _on_canvas_updated)
		hide()
		# ウィンドウを閉じるだけで、完全な破棄は行わない
