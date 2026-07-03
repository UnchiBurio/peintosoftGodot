class_name CanvasOverlay
extends Node2D

enum OverlayKind {
	STATIC,
	GRID,
	PREVIEW,
	CROSSHAIR,
	DEBUG
}

var paint_canvas: Node2D
var overlay_kind: int = OverlayKind.STATIC

func _init(canvas: Node2D, kind: int) -> void:
	paint_canvas = canvas
	overlay_kind = kind
	z_index = 1000 + int(kind)

func _draw() -> void:
	if paint_canvas == null:
		return

	match overlay_kind:
		OverlayKind.STATIC:
			_draw_static_overlay()
		OverlayKind.GRID:
			_draw_grid_overlay()
		OverlayKind.PREVIEW:
			_draw_preview_overlay()
		OverlayKind.CROSSHAIR:
			_draw_crosshair_overlay()
		OverlayKind.DEBUG:
			_draw_debug_overlay()

func _get_main():
	if paint_canvas.get_tree() == null:
		return null
	return paint_canvas.get_tree().root.get_node_or_null("Main")

func _draw_static_overlay() -> void:
	var main = _get_main()
	var draw_color = paint_canvas.border_color
	var draw_width = 1.0
	if main != null and main.active_paint_canvas == paint_canvas:
		draw_color = paint_canvas.highlight_color
		draw_width = paint_canvas.highlight_width

	draw_rect(Rect2(Vector2.ZERO, paint_canvas.canvas_size), draw_color, false, draw_width)

	if Input.is_key_pressed(KEY_ALT):
		var handle_color = Color(0.2, 0.6, 1.0, 0.8)
		for point in paint_canvas._get_resize_handle_points():
			draw_rect(
				Rect2(
					point - Vector2.ONE * paint_canvas.canvas_resize.resize_handle_size * 0.5,
					Vector2.ONE * paint_canvas.canvas_resize.resize_handle_size
				),
				handle_color,
				true
			)

func _draw_grid_overlay() -> void:
	if not paint_canvas.show_grid:
		return

	var grid_size = paint_canvas.grid_size
	if grid_size <= 0:
		return

	var visible_rect: Rect2 = paint_canvas.get_visible_canvas_rect(float(grid_size))
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return

	if paint_canvas.show_grid_highlight:
		for i in range(paint_canvas.grid_history.size()):
			var grid_pos = paint_canvas.grid_history[i]
			var cell_rect = Rect2(
				Vector2(grid_pos.x * grid_size, grid_pos.y * grid_size),
				Vector2.ONE * grid_size
			)
			if not cell_rect.intersects(visible_rect):
				continue
			var highlight_color = paint_canvas.grid_history_colors[i] if i < paint_canvas.grid_history_colors.size() else paint_canvas.grid_history_colors[-1]
			draw_rect(
				cell_rect,
				paint_canvas.grid_highlight_color.darkened(float(i) / max(1, paint_canvas.grid_history_length)),
				true
			)
			draw_rect(
				cell_rect,
				highlight_color,
				false,
				2.0 if i == 0 else 1.0
			)

		for i in range(paint_canvas.grid_intersections.size()):
			var intersection = paint_canvas.grid_intersections[i]
			if not visible_rect.has_point(intersection):
				continue
			var intensity = 1.0 - float(i) / max(1, paint_canvas.grid_intersection_history_length)
			var intersection_color = paint_canvas.grid_intersection_color
			intersection_color.a *= intensity
			draw_circle(intersection, paint_canvas.grid_intersection_size, intersection_color)
			var cross_size = paint_canvas.grid_intersection_size * 1.5
			draw_line(
				intersection + Vector2(-cross_size, 0),
				intersection + Vector2(cross_size, 0),
				intersection_color,
				2.0 if i == 0 else 1.0
			)
			draw_line(
				intersection + Vector2(0, -cross_size),
				intersection + Vector2(0, cross_size),
				intersection_color,
				2.0 if i == 0 else 1.0
			)

	var start_x = int(floor(visible_rect.position.x / grid_size)) * grid_size
	var end_x = int(ceil(visible_rect.end.x / grid_size)) * grid_size
	var start_y = int(floor(visible_rect.position.y / grid_size)) * grid_size
	var end_y = int(ceil(visible_rect.end.y / grid_size)) * grid_size
	var min_y = max(0.0, visible_rect.position.y)
	var max_y = min(paint_canvas.canvas_size.y, visible_rect.end.y)
	var min_x = max(0.0, visible_rect.position.x)
	var max_x = min(paint_canvas.canvas_size.x, visible_rect.end.x)

	for x in range(start_x, end_x + grid_size, grid_size):
		if x < 0 or x > paint_canvas.canvas_size.x:
			continue
		draw_line(Vector2(x, min_y), Vector2(x, max_y), paint_canvas.grid_color)

	for y in range(start_y, end_y + grid_size, grid_size):
		if y < 0 or y > paint_canvas.canvas_size.y:
			continue
		draw_line(Vector2(min_x, y), Vector2(max_x, y), paint_canvas.grid_color)

func _draw_preview_overlay() -> void:
	var main = _get_main()
	if main == null or not paint_canvas.show_preview_line or main.active_paint_canvas != paint_canvas:
		return

	if paint_canvas.canvas_draw.show_stroke_guide and paint_canvas.canvas_draw.is_guide_active and paint_canvas.is_drawing:
		if paint_canvas.preview_points.size() > 0 and paint_canvas.canvas_draw.guide_points.size() >= 1:
			var center_pos = paint_canvas.preview_points[-1].position
			for i in range(1, paint_canvas.canvas_draw.guide_points.size()):
				draw_colored_polygon(
					PackedVector2Array([
						center_pos,
						paint_canvas.canvas_draw.guide_points[i - 1],
						paint_canvas.canvas_draw.guide_points[i]
					]),
					paint_canvas.canvas_draw.guide_color
				)
			if paint_canvas.canvas_draw.guide_points.size() > 2:
				draw_colored_polygon(
					PackedVector2Array([
						center_pos,
						paint_canvas.canvas_draw.guide_points[-1],
						paint_canvas.canvas_draw.guide_points[0]
					]),
					paint_canvas.canvas_draw.guide_color
				)
			draw_line(center_pos, paint_canvas.canvas_draw.guide_points[-1], Color.RED, 2.0)

	if paint_canvas.point_attraction_enabled and paint_canvas.preview_points.size() > 0:
		var attraction_color = Color(0.1, 0.6, 1.0, 0.12)
		var attraction_outline = Color(0.1, 0.6, 1.0, 0.35)
		var attraction_width = max(1.0, 1.0 * paint_canvas.get_zoom_scale())
		for point in paint_canvas.preview_points:
			draw_circle(point.position, paint_canvas.point_attraction_radius, attraction_color)
			draw_arc(point.position, paint_canvas.point_attraction_radius, 0.0, TAU, 96, attraction_outline, attraction_width)

	for point in paint_canvas.preview_points:
		draw_circle(point.position, 3.0, Color.RED)
		for property in point.properties:
			match property:
				paint_canvas.PointProperty.INFINITE_LINE:
					var base_angle = (paint_canvas.last_input_position - point.position).angle()
					var intersections = _get_canvas_intersections(point.position, base_angle)
					draw_line(intersections.start, intersections.end, Color(1, 0, 0, 0.5), 2.0)
					if point.has_property(paint_canvas.PointProperty.PERPENDICULAR_LINE):
						var perp_angle = base_angle + PI / 2.0
						var perp_intersections = _get_canvas_intersections(paint_canvas.last_input_position, perp_angle)
						draw_line(perp_intersections.start, perp_intersections.end, Color(0, 1, 0, 0.5), 2.0)
						var square_size = 10.0
						var corner_pos = paint_canvas.last_input_position
						var point1 = corner_pos + Vector2(cos(base_angle), sin(base_angle)) * square_size
						var point2 = corner_pos + Vector2(cos(perp_angle), sin(perp_angle)) * square_size
						draw_line(corner_pos, point1, Color(0, 1, 0, 0.8), 2.0)
						draw_line(corner_pos, point2, Color(0, 1, 0, 0.8), 2.0)
				paint_canvas.PointProperty.CURSOR_RADIUS_CIRCLE:
					var radius = point.position.distance_to(paint_canvas.last_input_position)
					if radius > 0.0:
						draw_arc(point.position, radius, 0.0, TAU, 96, Color(1, 0.6, 0, 0.85), 2.0)
		draw_line(point.position, paint_canvas.last_input_position, Color.RED, 2.0)

	if paint_canvas.canvas_input.is_connecting_points and paint_canvas.canvas_input.connection_start_point != null:
		draw_line(
			paint_canvas.canvas_input.connection_start_point.position,
			paint_canvas.canvas_input.connection_end_point,
			Color.RED,
			2.0
		)

	for connection in paint_canvas.preview_connections:
		var color = connection.style.color
		if connection.state == CanvasPreview.ConnectionLine.LineState.SELECTED:
			color = color.lightened(0.3)
		draw_line(
			connection.start_point.position,
			connection.end_point.position,
			color,
			connection.style.width
		)

func _draw_crosshair_overlay() -> void:
	var main = _get_main()

	if paint_canvas.show_cursor_cross and paint_canvas._is_position_in_canvas(paint_canvas.last_input_position):
		var line_color = paint_canvas.cursor_color
		line_color.a = paint_canvas.cursor_alpha
		draw_line(
			Vector2(paint_canvas.last_input_position.x, 0),
			Vector2(paint_canvas.last_input_position.x, paint_canvas.canvas_size.y),
			line_color,
			1.0
		)
		draw_line(
			Vector2(0, paint_canvas.last_input_position.y),
			Vector2(paint_canvas.canvas_size.x, paint_canvas.last_input_position.y),
			line_color,
			1.0
		)

	if paint_canvas.show_directional_crosshair:
		for mark in paint_canvas.directional_crosshair_trail_marks:
			if paint_canvas._is_position_in_canvas(mark.position):
				_draw_directional_crosshair_at(mark.position, mark.angle)
		if paint_canvas.is_drawing and paint_canvas._is_position_in_canvas(paint_canvas.directional_crosshair_position):
			_draw_directional_crosshair_at(
				paint_canvas.directional_crosshair_position,
				paint_canvas.directional_crosshair_angle
			)

	if main == null:
		return
	if main.active_paint_canvas != paint_canvas:
		return
	if not paint_canvas._is_position_in_canvas(paint_canvas.last_input_position):
		return
	if main.current_tool != Main.Tool.BRUSH and main.current_tool != Main.Tool.ERASER:
		return

	var radius = max(Main.stroke_width * 0.5, 0.5)
	var center = paint_canvas.attracted_pen_position
	if not paint_canvas.point_attraction_enabled or not paint_canvas.show_preview_line:
		center = paint_canvas.last_input_position
	_draw_point_attraction_feedback(center)

	var outline_width = max(1.0, radius * 0.15) * paint_canvas.get_zoom_scale()
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

	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 32, outline_color, outline_width)

func _draw_point_attraction_feedback(attracted_center: Vector2) -> void:
	if not paint_canvas.point_attraction_visual_enabled:
		return
	if not paint_canvas.point_attraction_enabled or not paint_canvas.show_preview_line:
		return
	if paint_canvas.preview_points.is_empty():
		return
	if paint_canvas.point_attraction_tension <= 0.001:
		return

	var raw_center = paint_canvas.raw_pen_position
	if not paint_canvas._is_position_in_canvas(raw_center):
		return

	var zoom_scale = paint_canvas.get_zoom_scale()
	var tension = clampf(paint_canvas.point_attraction_tension, 0.0, 1.0)
	if paint_canvas.point_attraction_has_primary_point:
		var pull_color = Color(0.1, 0.6, 1.0, lerpf(0.18, 0.42, tension))
		draw_line(
			paint_canvas.point_attraction_primary_position,
			attracted_center,
			pull_color,
			lerpf(1.0, 2.5, tension) * zoom_scale
		)

	var tension_color = Color(1.0, 0.45, 0.05, lerpf(0.35, 0.95, tension))
	draw_line(
		raw_center,
		attracted_center,
		tension_color,
		lerpf(1.0, 5.0, tension) * zoom_scale
	)

	var raw_ring_radius = max(5.0, Main.stroke_width * 0.5 + 4.0) * zoom_scale
	var raw_ring_width = max(1.0, 1.5 * zoom_scale)
	var raw_fill = Color(1.0, 0.45, 0.05, 0.08)
	var raw_outline = Color(1.0, 0.45, 0.05, lerpf(0.45, 0.9, tension))
	draw_circle(raw_center, raw_ring_radius, raw_fill)
	draw_arc(raw_center, raw_ring_radius, 0.0, TAU, 32, raw_outline, raw_ring_width)

func _draw_directional_crosshair_at(center: Vector2, angle: float) -> void:
	var cross_primary_color = paint_canvas.directional_crosshair_primary_color
	var cross_secondary_color = paint_canvas.directional_crosshair_secondary_color
	cross_primary_color.a = paint_canvas.directional_crosshair_alpha
	cross_secondary_color.a = paint_canvas.directional_crosshair_alpha
	var half_length = paint_canvas.directional_crosshair_length * 0.5
	var thickness = paint_canvas.directional_crosshair_thickness
	var direction = Vector2(cos(angle), sin(angle))
	var perpendicular = direction.rotated(PI / 2.0)
	draw_line(center - direction * half_length, center + direction * half_length, cross_primary_color, thickness)
	draw_line(center - perpendicular * half_length, center + perpendicular * half_length, cross_secondary_color, thickness)

func _draw_debug_overlay() -> void:
	if not paint_canvas.deback_mode:
		return

	var current_time = Time.get_ticks_msec()
	var zoom_scale = paint_canvas.get_zoom_scale()
	var visible_rect: Rect2 = paint_canvas.get_visible_canvas_rect(float(paint_canvas.CHUNK_SIZE))
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return

	var start_chunk = paint_canvas._get_chunk_pos(visible_rect.position)
	var end_chunk = paint_canvas._get_chunk_pos(visible_rect.end)
	for layer in paint_canvas.layers:
		if not layer.visible:
			continue
		for x in range(start_chunk.x, end_chunk.x + 1):
			for y in range(start_chunk.y, end_chunk.y + 1):
				var chunk_pos = Vector2i(x, y)
				if not layer.chunks.has(chunk_pos):
					continue
				var is_recently_updated = false
				if paint_canvas.canvas_draw.chunk_update_times.has(chunk_pos):
					var time_since_update = (current_time - paint_canvas.canvas_draw.chunk_update_times[chunk_pos]) / 1000.0
					is_recently_updated = time_since_update < paint_canvas.canvas_draw.debug_update_time
					if not is_recently_updated:
						paint_canvas.canvas_draw.chunk_update_times.erase(chunk_pos)

				var border_color = Color(1, 0, 0, 0.5) if is_recently_updated else Color(0, 1, 0, 0.2)
				var chunk_rect = Rect2(chunk_pos * paint_canvas.CHUNK_SIZE, Vector2.ONE * paint_canvas.CHUNK_SIZE)
				draw_rect(chunk_rect, border_color, false, 2.0 * zoom_scale)

				var font_size = max(8, int(round(16.0 * zoom_scale)))
				var label_pos = Vector2(chunk_pos) * paint_canvas.CHUNK_SIZE + Vector2(10 * zoom_scale, 20 * zoom_scale)
				var text_color = Color.RED if is_recently_updated else Color.WHITE
				var status_text = " (Updated)" if is_recently_updated else ""
				draw_string(
					ThemeDB.fallback_font,
					label_pos,
					"Chunk: " + str(chunk_pos) + status_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size,
					text_color
				)

func _get_canvas_intersections(start_pos: Vector2, angle: float) -> Dictionary:
	var length = sqrt(paint_canvas.canvas_size.x * paint_canvas.canvas_size.x + paint_canvas.canvas_size.y * paint_canvas.canvas_size.y) * 2.0
	var direction = Vector2(cos(angle), sin(angle))
	var far_point1 = start_pos + direction * length
	var far_point2 = start_pos - direction * length
	return {
		"start": _clip_point_to_canvas(far_point1, start_pos),
		"end": _clip_point_to_canvas(far_point2, start_pos)
	}

func _clip_point_to_canvas(point: Vector2, start_pos: Vector2) -> Vector2:
	var clipped = point
	if point.x < 0:
		clipped = _intersection_point(start_pos, point, Vector2.ZERO, Vector2(0, paint_canvas.canvas_size.y))
	elif point.x > paint_canvas.canvas_size.x:
		clipped = _intersection_point(start_pos, point, Vector2(paint_canvas.canvas_size.x, 0), Vector2(paint_canvas.canvas_size.x, paint_canvas.canvas_size.y))

	if point.y < 0:
		var top = _intersection_point(start_pos, point, Vector2.ZERO, Vector2(paint_canvas.canvas_size.x, 0))
		if _is_point_valid(top):
			clipped = top
	elif point.y > paint_canvas.canvas_size.y:
		var bottom = _intersection_point(start_pos, point, Vector2(0, paint_canvas.canvas_size.y), Vector2(paint_canvas.canvas_size.x, paint_canvas.canvas_size.y))
		if _is_point_valid(bottom):
			clipped = bottom
	return clipped

func _is_point_valid(point: Variant) -> bool:
	return point is Vector2 and not is_nan(point.x) and not is_nan(point.y)

func _intersection_point(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
	if denominator == 0:
		return p1
	var ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator
	return Vector2(p1.x + ua * (p2.x - p1.x), p1.y + ua * (p2.y - p1.y))
