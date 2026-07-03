# CanvasDraw.gd
class_name CanvasDraw
extends RefCounted

var paint_canvas: Node2D
var _pending_updates := {}
var _last_draw_time := 0.0
const MIN_UPDATE_INTERVAL = 1.0/60.0  # 60FPS
var chunk_update_times := {}  # チャンクごとの更新時間を記録
var debug_update_time := 0.5  # 更新状態を表示する時間（秒）
const GUIDE_POINT_MIN_DISTANCE := 4.0
const MAX_GUIDE_POINTS := 192

# ストロークガイド関連の変数
var show_stroke_guide: bool = false
var guide_points: Array[Vector2] = []
var guide_start_point: Vector2
var guide_color: Color = Color(1, 1, 0, 0.9)  # 半透明の赤色
var is_guide_active: bool = false  # ガイドが現在アクティブかどうか

func _init(canvas: Node2D):
	paint_canvas = canvas

func draw():
	pass

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
				chunk.sync_texture()
			chunk.dirty = false
			chunk_update_times[chunk.position] = Time.get_ticks_msec()
			was_updated = true  # 更新があったことを記録

	_pending_updates.clear()
	_last_draw_time = current_time
	
	# 更新があった場合はシグナルを発行
	if was_updated:
		paint_canvas.queue_debug_overlay_redraw()
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
				chunk.set_pixel(fx, fy, blend_color)
		else:
			# メインピクセルの描画
			if 0 <= fx and fx < paint_canvas.CHUNK_SIZE and 0 <= fy and fy < paint_canvas.CHUNK_SIZE:
				chunk.set_pixel(fx, fy, color)
		
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
				chunk.set_pixel(x, y, color)

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
					chunk.set_pixel(x, y, color)

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
	paint_canvas.queue_preview_overlay_redraw()

func start_stroke_guide(position: Vector2) -> void:
	if not show_stroke_guide:
		return
	
	guide_points.clear()
	guide_start_point = position
	guide_points.append(position)
	is_guide_active = true
	paint_canvas.queue_preview_overlay_redraw()

func update_stroke_guide(position: Vector2) -> void:
	if not show_stroke_guide or not is_guide_active:
		return
	if guide_points.size() > 0 and guide_points[-1].distance_to(position) < GUIDE_POINT_MIN_DISTANCE:
		return
	guide_points.append(position)
	if guide_points.size() > MAX_GUIDE_POINTS:
		guide_points.remove_at(0)

func end_stroke_guide() -> void:
	is_guide_active = false
	paint_canvas.queue_preview_overlay_redraw()

func clear_stroke_guide() -> void:
	guide_points.clear()
	is_guide_active = false
	paint_canvas.queue_preview_overlay_redraw()
