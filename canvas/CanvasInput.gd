# CanvasInput.gd
class_name CanvasInput
extends RefCounted

var paint_canvas: Node2D
var last_input_position: Vector2 = Vector2.ZERO
var is_connecting_points := false
var connection_start_point: CanvasPreview.PreviewPoint = null
var connection_end_point: Vector2
var is_ctrl_right_click_dragging := false
var ctrl_right_click_start_pos := Vector2.ZERO
var selected_point = null

func _init(canvas: Node2D):
	paint_canvas = canvas

func handle_input(event):
	# まずアクティブ状態をチェック
	var main = paint_canvas.get_tree().root.get_node("Main")
	if !paint_canvas.solo:
		if paint_canvas != main.active_paint_canvas:
			return
		
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		var new_position = paint_canvas.to_local(event.position)
		
		# グリッドハイライトが有効な場合は交点チェック
		if paint_canvas.show_grid and paint_canvas.show_grid_highlight:
			_check_grid_intersection(last_input_position, new_position)
		
		last_input_position = new_position
		paint_canvas.last_input_position = new_position
		
		if paint_canvas.show_grid and paint_canvas.show_grid_highlight:
			_update_grid_history(last_input_position)
			paint_canvas.queue_redraw()
		
		last_input_position = paint_canvas.to_local(event.position)
		paint_canvas.last_input_position = last_input_position
		var local_pos = paint_canvas.to_local(event.position)
		
	
		if paint_canvas.canvas_resize.is_resizing:
			paint_canvas._update_resize(event.position)
			paint_canvas.get_viewport().set_input_as_handled()
			paint_canvas.queue_redraw()
		elif paint_canvas.canvas_move.is_moving:
			paint_canvas._update_move(event.position)
			paint_canvas.get_viewport().set_input_as_handled()
		elif paint_canvas.is_drawing and paint_canvas._is_position_in_canvas(last_input_position):
			paint_canvas.commit_line(paint_canvas.last_draw_position, last_input_position, Main.stroke_color, Main.stroke_width)
			paint_canvas.last_draw_position = last_input_position
		elif is_connecting_points:
			connection_end_point = last_input_position
			paint_canvas.queue_redraw()
		elif is_ctrl_right_click_dragging:
			if selected_point != null:
				var delta = last_input_position - selected_point.position
				selected_point.position = last_input_position
				
				# 接続されている線の位置を更新
				for connection in paint_canvas.preview_connections:
					if connection is CanvasPreview.ConnectionLine:  # 型チェックを追加
						if connection.get_start_position().is_equal_approx(selected_point.position - delta):
							connection.set_start_position(selected_point.position)
						if connection.get_end_position().is_equal_approx(selected_point.position - delta):
							connection.set_end_position(selected_point.position)
					
				paint_canvas.queue_redraw()

		# プレビュー線の表示更新
		if paint_canvas.show_preview_line:
			paint_canvas.queue_redraw()
			
		# ストロークガイドの更新
		if paint_canvas.canvas_draw.show_stroke_guide and paint_canvas.preview_points.size() > 0 and paint_canvas.is_drawing:
			paint_canvas.canvas_draw.update_stroke_guide(new_position)

	# マウスボタンとタッチ入力の処理
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		var local_pos = paint_canvas.to_local(event.position)
		
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					if paint_canvas.show_preview_line:
						if Input.is_key_pressed(KEY_SHIFT):
							if event.pressed:
								var start_point = _get_or_create_point_at(local_pos)
								is_connecting_points = true
								connection_start_point = start_point
								connection_end_point = local_pos
							else:
								if is_connecting_points:
									var end_point = _get_or_create_point_at(local_pos)
									if end_point != connection_start_point:
										paint_canvas.create_connection(connection_start_point, end_point)
									is_connecting_points = false
									paint_canvas.queue_redraw()
						else:
							if event.pressed:
								if Input.is_key_pressed(KEY_CTRL):
									is_ctrl_right_click_dragging = true
									ctrl_right_click_start_pos = local_pos
									var clicked_point = paint_canvas._find_point_at_position(local_pos)
									if clicked_point != null:
										selected_point = clicked_point
								else:
									_handle_right_click(local_pos)
									if paint_canvas.canvas_draw.show_stroke_guide:
										paint_canvas.canvas_draw.start_stroke_guide(local_pos)
							else:
								if is_ctrl_right_click_dragging:
									is_ctrl_right_click_dragging = false
									selected_point = null
								elif paint_canvas.canvas_draw.show_stroke_guide:
									paint_canvas.canvas_draw.end_stroke_guide()
									
					paint_canvas.get_viewport().set_input_as_handled()
					return
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					return
				MOUSE_BUTTON_LEFT:
					if paint_canvas.is_valid_draw_position(local_pos) or (Input.is_key_pressed(KEY_ALT) and paint_canvas._get_resize_edge(local_pos) != Vector2.ZERO):
						if event.pressed:
							if Input.is_key_pressed(KEY_CTRL):
								paint_canvas._start_move(event.position)
							elif Input.is_key_pressed(KEY_ALT):
								var edge = paint_canvas._get_resize_edge(local_pos)
								if edge != Vector2.ZERO:
									paint_canvas._start_resize(edge, event.position)
							else:
								if !paint_canvas.is_drawing:
									paint_canvas.commit_line(local_pos, local_pos, Main.stroke_color, Main.stroke_width)
								paint_canvas.is_drawing = true
								paint_canvas.last_draw_position = local_pos
								last_input_position = local_pos
						else:
							if paint_canvas.canvas_resize.is_resizing:
								paint_canvas._end_resize()
							elif paint_canvas.canvas_move.is_moving:
								paint_canvas._end_move()
							elif paint_canvas.is_drawing:
								paint_canvas.is_drawing = false
								if paint_canvas.last_draw_position != local_pos:
									paint_canvas.commit_line(local_pos, local_pos, Main.stroke_color, Main.stroke_width)

						paint_canvas.get_viewport().set_input_as_handled()

	# キー入力の処理
	if event is InputEventKey and event.pressed:
		# グリッドとガイド表示の制御（Gキー関連）
		if event.keycode == KEY_G:
			if event.shift_pressed:
				# Shift+G: グリッドハイライトの表示切り替え
				paint_canvas.show_grid_highlight = not paint_canvas.show_grid_highlight
				paint_canvas.queue_redraw()
			elif event.ctrl_pressed:
				# Ctrl+G: ストロークガイドの表示切り替え
				paint_canvas.canvas_draw.toggle_stroke_guide()
				# プレビュー点が存在する場合、現在のマウス位置でガイドを開始
				if paint_canvas.canvas_draw.show_stroke_guide and paint_canvas.preview_points.size() > 0:
					var mouse_pos = paint_canvas.get_local_mouse_position()
					paint_canvas.canvas_draw.start_stroke_guide(mouse_pos)
			else:
				# G: 通常のグリッド表示切り替え
				paint_canvas.show_grid = not paint_canvas.show_grid
				paint_canvas.queue_redraw()
		
		# プレビュー線の表示制御（Pキー）
		elif event.keycode == KEY_P:
			paint_canvas.show_preview_line = not paint_canvas.show_preview_line
			paint_canvas.queue_redraw()
		
		# プレビュー点とプレビュー線のリセット（Rキー）
		elif event.keycode == KEY_R:
			paint_canvas.preview_points.clear()
			paint_canvas.preview_connections.clear()
			paint_canvas.queue_redraw()
		
		# カーソル十字の表示制御（Oキー）
		elif event.keycode == KEY_O:
			paint_canvas.show_cursor_cross = not paint_canvas.show_cursor_cross
			paint_canvas.queue_redraw()
		
		# レイヤー追加（Lキー）
		elif event.keycode == KEY_L:
			paint_canvas._add_layer(str(paint_canvas.layers.size() - 1))
		
		# ストロークガイドのクリア（Ctrl+C）
		elif event.keycode == KEY_C and event.ctrl_pressed:
			paint_canvas.canvas_draw.clear_stroke_guide()

func _check_grid_intersection(from: Vector2, to: Vector2):
	if not paint_canvas._is_position_in_canvas(from) or not paint_canvas._is_position_in_canvas(to):
		return
		
	var grid_size = paint_canvas.grid_size
	
	# 開始点と終了点のグリッド座標を計算
	var start_x = floor(from.x / grid_size)
	var start_y = floor(from.y / grid_size)
	var end_x = floor(to.x / grid_size)
	var end_y = floor(to.y / grid_size)
	
	# 水平方向のグリッド線との交点をチェック
	var min_y = min(start_y, end_y)
	var max_y = max(start_y, end_y)
	for y in range(min_y, max_y + 2):
		var grid_y = y * grid_size
		if grid_y >= 0 and grid_y <= paint_canvas.canvas_size.y:
			var t = inverse_lerp(from.y, to.y, grid_y)
			if t >= 0 and t <= 1:
				var intersection_x = lerp(from.x, to.x, t)
				if intersection_x >= 0 and intersection_x <= paint_canvas.canvas_size.x:
					_add_intersection(Vector2(intersection_x, grid_y))
	
	# 垂直方向のグリッド線との交点をチェック
	var min_x = min(start_x, end_x)
	var max_x = max(start_x, end_x)
	for x in range(min_x, max_x + 2):
		var grid_x = x * grid_size
		if grid_x >= 0 and grid_x <= paint_canvas.canvas_size.x:
			var t = inverse_lerp(from.x, to.x, grid_x)
			if t >= 0 and t <= 1:
				var intersection_y = lerp(from.y, to.y, t)
				if intersection_y >= 0 and intersection_y <= paint_canvas.canvas_size.y:
					_add_intersection(Vector2(grid_x, intersection_y))

func _add_intersection(intersection: Vector2):
	# 既に同じ位置の交点が存在する場合は追加しない
	for existing in paint_canvas.grid_intersections:
		if existing.distance_to(intersection) < 1.0:  # 1ピクセル以内なら同じ位置とみなす
			return
	
	# 新しい交点を追加
	paint_canvas.grid_intersections.push_front(intersection)
	
	# 履歴の長さを制限
	while paint_canvas.grid_intersections.size() > paint_canvas.grid_intersection_history_length:
		paint_canvas.grid_intersections.pop_back()

func _update_grid_history(position: Vector2):
	if not paint_canvas._is_position_in_canvas(position):
		return
		
	# 現在のグリッドマスの位置を計算
	var grid_size = paint_canvas.grid_size
	var current_grid_pos = Vector2i(
		floor(position.x / grid_size),
		floor(position.y / grid_size)
	)
	
	# 前回と同じマスなら更新しない
	if paint_canvas.grid_history.size() > 0 and paint_canvas.grid_history[0] == current_grid_pos:
		return
		
	# 履歴に追加
	paint_canvas.grid_history.push_front(current_grid_pos)
	
	# 指定された長さを超えた分を削除
	while paint_canvas.grid_history.size() > paint_canvas.grid_history_length:
		paint_canvas.grid_history.pop_back()

func _get_or_create_point_at(position: Vector2) -> CanvasPreview.PreviewPoint:
	var existing_point = paint_canvas._find_point_at_position(position)
	if existing_point:
		return existing_point
	
	# 新しい点を作成
	var new_point = paint_canvas.canvas_preview.PreviewPoint.new(position)
	paint_canvas.preview_points.append(new_point)
	return new_point

func _handle_right_click(position: Vector2):
	if Input.is_key_pressed(KEY_SHIFT):
		return
	
	if Input.is_key_pressed(KEY_CTRL):
		var clicked_point = paint_canvas._find_point_at_position(position)
		if clicked_point != null:
			if clicked_point.has_property(paint_canvas.PointProperty.INFINITE_LINE):
				clicked_point.remove_property(paint_canvas.PointProperty.INFINITE_LINE)
			else:
				clicked_point.add_property(paint_canvas.PointProperty.INFINITE_LINE)
			paint_canvas.emit_signal("canvas_updated")
	else:
		var existing_point = paint_canvas._find_point_at_position(position)
		if existing_point != null:
			selected_point = existing_point
			
			for property in range(paint_canvas.popup_menu.item_count - 2):
				var property_id = paint_canvas.popup_menu.get_item_id(property)
				paint_canvas.popup_menu.set_item_checked(property, 
					selected_point.has_property(property_id))
			
			paint_canvas.popup_menu.position = paint_canvas.get_viewport().get_mouse_position()
			paint_canvas.popup_menu.popup()
		else:
			paint_canvas.preview_points.append(paint_canvas.canvas_preview.PreviewPoint.new(position))
			paint_canvas.emit_signal("canvas_updated")
	
	paint_canvas._emit_preview_lines_requested()
	paint_canvas.queue_redraw()
