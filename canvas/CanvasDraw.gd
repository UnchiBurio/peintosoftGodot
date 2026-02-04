# CanvasDraw.gd
class_name CanvasDraw
extends RefCounted

var paint_canvas: Node2D
var _pending_updates := {}
var _last_draw_time := 0.0
const MIN_UPDATE_INTERVAL = 1.0/60.0  # 60FPS
var chunk_update_times := {}  # チャンクごとの更新時間を記録
var debug_update_time := 0.5  # 更新状態を表示する時間（秒）

# ストロークガイド関連の変数
var show_stroke_guide: bool = false
var guide_points: PackedVector2Array = PackedVector2Array()
var guide_start_point: Vector2
var guide_color: Color = Color(1, 1, 0, 0.9)  # 半透明の赤色
var is_guide_active: bool = false  # ガイドが現在アクティブかどうか

func _init(canvas: Node2D):
	paint_canvas = canvas

func draw():
	var current_time = Time.get_ticks_msec()
	var main = paint_canvas.get_tree().root.get_node("Main")
	
	
	# プレビュー線が表示されている場合のみストロークガイドを描画
	if paint_canvas.show_preview_line and show_stroke_guide and is_guide_active and paint_canvas.is_drawing:
		if paint_canvas.preview_points.size() > 0 and guide_points.size() >= 1:
			var active_preview_point = paint_canvas.preview_points[-1]
			var center_pos = active_preview_point.position
			
			# 扇形状の三角形分割で描画
			for i in range(1, guide_points.size()):
				var triangle_points = PackedVector2Array([
					center_pos,
					guide_points[i-1],
					guide_points[i]
				])
				
				# 三角形を描画
				paint_canvas.draw_colored_polygon(triangle_points, guide_color)
			
			# 最後の点と最初の点を結ぶ三角形も描画（閉じた形状にする場合）
			if guide_points.size() > 2:
				var closing_triangle = PackedVector2Array([
					center_pos,
					guide_points[-1],
					guide_points[0]
				])
				paint_canvas.draw_colored_polygon(closing_triangle, guide_color)
			
			# ガイドラインの描画
			if guide_points.size() > 0:
				paint_canvas.draw_line(
					center_pos,
					guide_points[-1],
					Color.RED,
					2.0
				)

			
	# 既存の描画処理の前にグリッドを描画
	if paint_canvas.show_grid:
		_draw_grid()
	
	# チャンクの表示/非表示を制
	if paint_canvas.deback_mode:
		for layer in paint_canvas.layers:
			for chunk in layer.chunks.values():
				chunk.texture_rect.visible = layer.visible # 必要に応じて表示/非表示を切り替え
				
				if not layer.visible:
					continue
				
				# ズームレベルを考慮したデバッグ表示のスケール調整
				var zoom_scale = 1.0
				if paint_canvas.get_parent() and paint_canvas.get_parent().has_method("get_current_zoom"):
					zoom_scale = 1.0 / paint_canvas.get_parent().current_zoom
				
				# 更新状態の確認
				var is_recently_updated = false
				if chunk_update_times.has(chunk.position):
					var time_since_update = (current_time - chunk_update_times[chunk.position]) / 1000.0
					is_recently_updated = time_since_update < debug_update_time
					# 表示時間が過ぎたら記録を削除
					if not is_recently_updated:
						chunk_update_times.erase(chunk.position)
				
				# チャンクの境界を視覚化（デバッグ用）- ズーム対応
				var border_color = Color(1, 0, 0, 0.5) if is_recently_updated else Color(0, 1, 0, 0.2)
				paint_canvas.draw_rect(
					Rect2(chunk.position * paint_canvas.CHUNK_SIZE, Vector2.ONE * paint_canvas.CHUNK_SIZE),
					border_color,
					false,
					2.0 * zoom_scale
				)
				
				# チャンク座標を表示
				var font_size = 16 * zoom_scale
				var label_pos = Vector2(chunk.position) * paint_canvas.CHUNK_SIZE + Vector2(10 * zoom_scale, 20 * zoom_scale) # Vector2iをVector2に変換
				var transform = paint_canvas.get_canvas_transform()
				transform = transform.scaled(Vector2.ONE * zoom_scale)
				paint_canvas.draw_set_transform_matrix(transform)
				
				var text_color = Color.RED if is_recently_updated else Color.WHITE
				var status_text = " (Updated)" if is_recently_updated else ""
				
				paint_canvas.draw_string(
					ThemeDB.fallback_font,
					label_pos,
					"Chunk: " + str(chunk.position) + status_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size,
					text_color
				)
				
				# 変換をリセット
				paint_canvas.draw_set_transform_matrix(paint_canvas.get_canvas_transform())
		
	# キャンバスの境界線を描画
	var draw_color = paint_canvas.border_color
	var draw_width = 1.0
	
	# 自分がアクティブなキャンバスかどうか判定
	if main.active_paint_canvas == paint_canvas:
		draw_color = paint_canvas.highlight_color
		draw_width = paint_canvas.highlight_width
	
	# 枠線の描画実行
	paint_canvas.draw_rect(
		Rect2(Vector2.ZERO, paint_canvas.canvas_size), 
		draw_color, 
		false, 
		draw_width
	)	
	
	# サイズ表示のための設定
	var font_size = 14
	var padding = 5
	var size_text = "%dx%d" % [int(paint_canvas.canvas_size.x), int(paint_canvas.canvas_size.y)]
	
	
	# 背景付きのサイズ表示を描画
	var text_size = ThemeDB.fallback_font.get_string_size(size_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var background_rect = Rect2(
		Vector2(padding, padding),
		text_size + Vector2(padding * 2, padding)
	)
	
	# サイズテキストを描画
	paint_canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(padding * 2, padding + text_size.y),
		size_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)
	
	# リサイズハンドルの描画（必要な場合）
	if Input.is_key_pressed(KEY_ALT):
		paint_canvas._draw_resize_handles()
	
	# プレビュー線の描画
	if paint_canvas.show_preview_line and paint_canvas == main.active_paint_canvas:
		# 全ての点を描画
		for point in paint_canvas.preview_points:
			# 基本の点を描画
			paint_canvas.draw_circle(point.position, 3.0, Color.RED)
			
			# 各点の性質に応じた描画
			for property in point.properties:
				match property:
					paint_canvas.PointProperty.INFINITE_LINE:
						# 無限線の性質がある場合は基準となる直線を描画
						var base_angle = (paint_canvas.last_input_position - point.position).angle()
						var intersections = _get_canvas_intersections(point.position, base_angle)
						paint_canvas.draw_line(intersections.start, intersections.end, Color(1, 0, 0, 0.5), 2.0)
						
						# perpendicular_lineの性質も持っている場合は直角な線も描画
						if point.has_property(paint_canvas.PointProperty.PERPENDICULAR_LINE):
							var perp_angle = base_angle + PI/2  # 90度回転
							var perp_intersections = _get_canvas_intersections(paint_canvas.last_input_position, perp_angle)
							paint_canvas.draw_line(perp_intersections.start, perp_intersections.end, Color(0, 1, 0, 0.5), 2.0)
							
							# 直角マークの描画
							var square_size = 10.0
							var corner_pos = paint_canvas.last_input_position
							var point1 = corner_pos + Vector2(cos(base_angle), sin(base_angle)) * square_size
							var point2 = corner_pos + Vector2(cos(perp_angle), sin(perp_angle)) * square_size
							paint_canvas.draw_line(corner_pos, point1, Color(0, 1, 0, 0.8), 2.0)
							paint_canvas.draw_line(corner_pos, point2, Color(0, 1, 0, 0.8), 2.0)
							
			paint_canvas.draw_line(point.position, paint_canvas.last_input_position, Color.RED, 2.0)
		
		# 接続中の線を描画
		if paint_canvas.canvas_input.is_connecting_points and paint_canvas.canvas_input.connection_start_point != null:
			paint_canvas.draw_line(
				paint_canvas.canvas_input.connection_start_point.position,
				paint_canvas.canvas_input.connection_end_point,
				Color.RED,
				2.0
			)
		
		# 確定した接続線を描画
		for connection in paint_canvas.preview_connections:
			var color = connection.style.color
			if connection.state == CanvasPreview.ConnectionLine.LineState.SELECTED:
				color = color.lightened(0.3)
			
			paint_canvas.draw_line(
				connection.start_point.position,
				connection.end_point.position,
				color,
				connection.style.width
			)
	
	# キャンバスサイズに合わせた十字カーソルの描画
	if paint_canvas.show_cursor_cross:
		if paint_canvas._is_position_in_canvas(paint_canvas.last_input_position):
			# カーソルの色を半透明に設定
			var line_color = paint_canvas.cursor_color
			line_color.a = paint_canvas.cursor_alpha
			
			# 縦線 - キャンバスの上端から下端まで
			paint_canvas.draw_line(
				Vector2(paint_canvas.last_input_position.x, 0),           # キャンバスの上端
				Vector2(paint_canvas.last_input_position.x, paint_canvas.canvas_size.y),  # キャンバスの下端
				line_color,
				1.0
			)
			
			# 横線 - キャンバスの左端から右端まで
			paint_canvas.draw_line(
				Vector2(0, paint_canvas.last_input_position.y),           # キャンバスの左端
				Vector2(paint_canvas.canvas_size.x, paint_canvas.last_input_position.y),  # キャンバスの右端
				line_color,
				1.0
			)
	
	# 回転クロスヘアの描画
	if paint_canvas.show_directional_crosshair:
		for mark in paint_canvas.directional_crosshair_trail_marks:
			if paint_canvas._is_position_in_canvas(mark.position):
				_draw_directional_crosshair_at(mark.position, mark.angle)
		if paint_canvas.is_drawing and paint_canvas._is_position_in_canvas(paint_canvas.directional_crosshair_position):
			_draw_directional_crosshair_at(
				paint_canvas.directional_crosshair_position,
				paint_canvas.directional_crosshair_angle
			)

	_draw_tool_tip_indicator(main)

func _draw_tool_tip_indicator(main: Main) -> void:
	if main.active_paint_canvas != paint_canvas:
		return
	if not main.show_tool_tip_indicator:
		return
	if not paint_canvas._is_position_in_canvas(paint_canvas.last_input_position):
		return
	if main.current_tool != Main.Tool.BRUSH and main.current_tool != Main.Tool.ERASER:
		return

	var radius = max(Main.stroke_width * 0.5, 0.5)
	var center = paint_canvas.last_input_position
	var zoom_scale = 1.0
	if paint_canvas.get_parent() and paint_canvas.get_parent().has_method("get_current_zoom"):
		zoom_scale = 1.0 / paint_canvas.get_parent().current_zoom
	var outline_width = max(1.0, radius * 0.15) * zoom_scale
	var outline_radius = max(radius - outline_width * 0.5, 0.5)
	var fill_color: Color
	var outline_color: Color
	if main.current_tool == Main.Tool.ERASER:
		fill_color = Color(1, 1, 1, 0.15)
		outline_color = Color(0, 0, 0, 0.7)
	else:
		fill_color = Main.stroke_color
		fill_color.a = 0.2
		outline_color = Main.stroke_color
		outline_color.a = 0.85

	paint_canvas.draw_circle(center, radius, fill_color)
	paint_canvas.draw_arc(center, outline_radius, 0.0, TAU, 64, outline_color, outline_width)

func _draw_directional_crosshair_at(center: Vector2, angle: float) -> void:
	var cross_primary_color = paint_canvas.directional_crosshair_primary_color
	var cross_secondary_color = paint_canvas.directional_crosshair_secondary_color
	cross_primary_color.a = paint_canvas.directional_crosshair_alpha
	cross_secondary_color.a = paint_canvas.directional_crosshair_alpha
	var half_length = paint_canvas.directional_crosshair_length * 0.5
	var thickness = paint_canvas.directional_crosshair_thickness
	var direction = Vector2(cos(angle), sin(angle))
	var perpendicular = direction.rotated(PI / 2.0)
	paint_canvas.draw_line(
		center - direction * half_length,
		center + direction * half_length,
		cross_primary_color,
		thickness
	)
	paint_canvas.draw_line(
		center - perpendicular * half_length,
		center + perpendicular * half_length,
		cross_secondary_color,
		thickness
	)

func _draw_grid():
	var size = paint_canvas.canvas_size
	var grid_size = paint_canvas.grid_size
	var color = paint_canvas.grid_color
	
	# 履歴マスのハイライト処理
	if paint_canvas.show_grid_highlight:
		for i in range(paint_canvas.grid_history.size()):
			var grid_pos = paint_canvas.grid_history[i]
			var grid_x = grid_pos.x * grid_size
			var grid_y = grid_pos.y * grid_size
			
			# マスの背景をハイライト（古いものほど薄く）
			var highlight_color = paint_canvas.grid_history_colors[i] if i < paint_canvas.grid_history_colors.size() else paint_canvas.grid_history_colors[-1]
			
			# 背景のハイライト
			paint_canvas.draw_rect(
				Rect2(grid_x, grid_y, grid_size, grid_size),
				paint_canvas.grid_highlight_color.darkened(float(i) / paint_canvas.grid_history_length),
				true
			)
			
			# 枠線の強調
			paint_canvas.draw_rect(
				Rect2(grid_x, grid_y, grid_size, grid_size),
				highlight_color,
				false,
				2.0 if i == 0 else 1.0  # 現在のマスは太い線で
			)
			
			# 交点の強調表示
	if paint_canvas.show_grid_highlight:
		for i in range(paint_canvas.grid_intersections.size()):
			var intersection = paint_canvas.grid_intersections[i]
			var intensity = 1.0 - float(i) / paint_canvas.grid_intersection_history_length
			var intersection_color = paint_canvas.grid_intersection_color
			intersection_color.a *= intensity
			
			# 円を描画
			paint_canvas.draw_circle(
				intersection,
				paint_canvas.grid_intersection_size,
				intersection_color
			)
			
			# 十字マークを描画
			var cross_size = paint_canvas.grid_intersection_size * 1.5
			paint_canvas.draw_line(
				intersection + Vector2(-cross_size, 0),
				intersection + Vector2(cross_size, 0),
				intersection_color,
				2.0 if i == 0 else 1.0  # 最新の交点は太い線で
			)
			paint_canvas.draw_line(
				intersection + Vector2(0, -cross_size),
				intersection + Vector2(0, cross_size),
				intersection_color,
				2.0 if i == 0 else 1.0
			)
	
	# 通常のグリッド線の描画（既存の処理）
	for x in range(0, int(size.x), grid_size):
		paint_canvas.draw_line(
			Vector2(x, 0),
			Vector2(x, size.y),
			color
		)
	
	for y in range(0, int(size.y), grid_size):
		paint_canvas.draw_line(
			Vector2(0, y),
			Vector2(size.x, y),
			color
		)

# キャンバスとの交点を計算する関数を追加
func _get_canvas_intersections(start_pos: Vector2, angle: float) -> Dictionary:
	# 十分な長さのベクトルを作成（キャンバスの対角線より長く）
	var length = sqrt(paint_canvas.canvas_size.x * paint_canvas.canvas_size.x + paint_canvas.canvas_size.y * paint_canvas.canvas_size.y) * 2
	var direction = Vector2(cos(angle), sin(angle))
	
	# 線分の両端
	var far_point1 = start_pos + direction * length
	var far_point2 = start_pos - direction * length
	
	# キャンバスの境界との交点を見つける
	var canvas_rect = Rect2(Vector2.ZERO, paint_canvas.canvas_size)
	var clipped_point1 = _clip_point_to_canvas(far_point1, start_pos)
	var clipped_point2 = _clip_point_to_canvas(far_point2, start_pos)
	
	return {
		"start": clipped_point1,
		"end": clipped_point2
	}
	
# 点をキャンバスの境界にクリップする関数
func _clip_point_to_canvas(point: Vector2, start_pos: Vector2) -> Vector2:
	var clipped = point
	
	# x座標のクリップ
	if point.x < 0:
		clipped = _intersection_point(start_pos, point, Vector2.ZERO, Vector2(0, paint_canvas.canvas_size.y))
	elif point.x > paint_canvas.canvas_size.x:
		clipped = _intersection_point(start_pos, point, Vector2(paint_canvas.canvas_size.x, 0), Vector2(paint_canvas.canvas_size.x, paint_canvas.canvas_size.y))
	
	# y座標のクリップ
	if point.y < 0:
		var temp = _intersection_point(start_pos, point, Vector2.ZERO, Vector2(paint_canvas.canvas_size.x, 0))
		if temp != null and _is_point_valid(temp):
			clipped = temp
	elif point.y > paint_canvas.canvas_size.y:
		var temp = _intersection_point(start_pos, point, Vector2(0, paint_canvas.canvas_size.y), Vector2(paint_canvas.canvas_size.x, paint_canvas.canvas_size.y))
		if temp != null and _is_point_valid(temp):
			clipped = temp
	
	return clipped
	
# 点が有効かどうかをチェック
func _is_point_valid(point: Vector2) -> bool:
	return point != null and not is_nan(point.x) and not is_nan(point.y)

# 2つの線分の交点を計算
func _intersection_point(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
	
	if denominator == 0:
		return p1
	
	var ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
	return Vector2(p1.x + ua * (p2.x - p1.x), p1.y + ua * (p2.y - p1.y))

# 描画更新の最適化
func process_pending_updates(force_update: bool = false)->void:
	var current_time = Time.get_ticks_msec()
	var elapsed = (current_time - _last_draw_time) / 1000.0
	
	if not force_update and elapsed < MIN_UPDATE_INTERVAL:
		return
	
	var was_updated = false  # 更新があったかどうかのフラグ
	
	for chunk in _pending_updates.values():
		if chunk.dirty:
			if chunk.texture_dirty:
				chunk.texture = ImageTexture.create_from_image(chunk.image)
				chunk.texture_rect.texture = chunk.texture
				chunk.texture_dirty = false
			chunk.dirty = false
			chunk_update_times[chunk.position] = Time.get_ticks_msec()
			was_updated = true  # 更新があったことを記録
	
	_pending_updates.clear()
	_last_draw_time = current_time
	paint_canvas.queue_redraw()
	
	# 更新があった場合はシグナルを発行
	if was_updated:
		paint_canvas.emit_signal("canvas_updated")

func draw_line_in_chunk_optimized(chunk: CanvasChunk, from: Vector2, to: Vector2, color: Color, width: float)->void:
	# 線の太さが1以下の場合は、ブレゼンハムのアルゴリズムを使用
	if width <= 1.0:
		_draw_thin_line(chunk, from, to, color)
		return
	
	# それ以外は台形描画を使用（既存の実装）
	var distance = Vector2(to - from).length()
	if distance < width:
		_draw_circle_filled(chunk, (from + to) * 0.5, width * 0.5, color)
		return
	
	var normal = Vector2(to.y - from.y, from.x - to.x).normalized() * (width * 0.5)
	var vertices = PackedVector2Array([
		from + normal,
		to + normal,
		to - normal,
		from - normal
	])
	
	_fill_polygon(chunk, vertices, color)
	_draw_circle_filled(chunk, from, width * 0.5, color)
	_draw_circle_filled(chunk, to, width * 0.5, color)

# 細い線用の最適化された描画関数
func _draw_thin_line(chunk: CanvasChunk, from: Vector2, to: Vector2, color: Color)->void:
	var x0 = int(from.x)
	var y0 = int(from.y)
	var x1 = int(to.x)
	var y1 = int(to.y)
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	while true:
		# アンチエイリアス効果を適用
		var fx = x0
		var fy = y0
		var alpha = 1.0
		
		# エッジのアンチエイリアス処理
		if abs(err) < 1.0:
			alpha = 1.0 - abs(err)
			var blend_color = color
			blend_color.a *= alpha
			
			# エッジピクセルの描画
			if 0 <= fx and fx < paint_canvas.CHUNK_SIZE and 0<= fy and fy < paint_canvas.CHUNK_SIZE:
				chunk.image.set_pixel(fx, fy, blend_color)
		else:
			# メインピクセルの描画
			if 0 <= fx and fx < paint_canvas.CHUNK_SIZE and 0 <= fy and fy < paint_canvas.CHUNK_SIZE:
				chunk.image.set_pixel(fx, fy, color)
		
		if x0 == x1 and y0 == y1:
			break
			
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

# 効率的な円の塗りつぶし
func _draw_circle_filled(chunk: CanvasChunk, center: Vector2, radius: float, color: Color)->void:
	var x0 = int(max(0, center.x - radius))
	var x1 = int(min(paint_canvas.CHUNK_SIZE - 1, center.x + radius))
	var y0 = int(max(0, center.y - radius))
	var y1 = int(min(paint_canvas.CHUNK_SIZE - 1, center.y + radius))
	
	var radius_sq = radius * radius
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx = x - center.x
			var dy = y - center.y
			if dx * dx + dy * dy <= radius_sq:
				chunk.image.set_pixel(x, y, color)

# ポリゴン塗りつぶし（スキャンライン法）
func _fill_polygon(chunk: CanvasChunk, vertices: PackedVector2Array, color: Color)->void:
	# バウンディングボックスを計算
	var min_y = paint_canvas.CHUNK_SIZE
	var max_y = 0
	for v in vertices:
		min_y = min(min_y, int(v.y))
		max_y = max(max_y, int(v.y))
	
	min_y = max(0, min_y)
	max_y = min(paint_canvas.CHUNK_SIZE - 1, max_y)
	
	# 各スキャンライン上での交点を計算
	for y in range(min_y, max_y + 1):
		var intersections = []
		var j = vertices.size() - 1
		
		for i in range(vertices.size()):
			var v1 = vertices[i]
			var v2 = vertices[j]
			
			if (v1.y > y and v2.y <= y) or (v2.y > y and v1.y <= y):
				var x = v1.x + (y - v1.y) * (v2.x - v1.x) / (v2.y - v1.y)
				intersections.append(int(x))
			j = i
		
		# 交点をソート
		intersections.sort()
		
		# 交点間を塗りつぶし
		for i in range(0, intersections.size(), 2):
			if i + 1 < intersections.size():
				var x_start = max(0, intersections[i])
				var x_end = min(paint_canvas.CHUNK_SIZE - 1, intersections[i + 1])
				for x in range(x_start, x_end + 1):
					chunk.image.set_pixel(x, y, color)

func toggle_stroke_guide() -> void:
	show_stroke_guide = not show_stroke_guide
	if not show_stroke_guide:
		clear_stroke_guide()
	else:
		# ガイドを有効にした時、プレビュー点が既にある場合は
		# 現在のマウス位置でガイドを開始
		if paint_canvas.preview_points.size() > 0:
			var mouse_pos = paint_canvas.get_local_mouse_position()
			start_stroke_guide(mouse_pos)
	paint_canvas.queue_redraw()

func start_stroke_guide(position: Vector2) -> void:
	if not show_stroke_guide:
		return
	
	guide_points.clear()
	guide_start_point = position
	guide_points.append(position)
	is_guide_active = true
	paint_canvas.queue_redraw()

func update_stroke_guide(position: Vector2) -> void:
	if not show_stroke_guide or not is_guide_active:
		return
	
	guide_points.append(position)
	paint_canvas.queue_redraw()

func end_stroke_guide() -> void:
	is_guide_active = false
	paint_canvas.queue_redraw()

func clear_stroke_guide() -> void:
	guide_points.clear()
	is_guide_active = false
	paint_canvas.queue_redraw()
