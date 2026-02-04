# CrosshairOverlay.gd
class_name CrosshairOverlay
extends Node2D

var paint_canvas: Node2D

func _init(canvas: Node2D) -> void:
	paint_canvas = canvas

func _draw() -> void:
	if paint_canvas == null:
		return

	# キャンバスサイズに合わせた十字カーソルの描画
	if paint_canvas.show_cursor_cross:
		if paint_canvas._is_position_in_canvas(paint_canvas.last_input_position):
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

func _draw_directional_crosshair_at(center: Vector2, angle: float) -> void:
	var cross_primary_color = paint_canvas.directional_crosshair_primary_color
	var cross_secondary_color = paint_canvas.directional_crosshair_secondary_color
	cross_primary_color.a = paint_canvas.directional_crosshair_alpha
	cross_secondary_color.a = paint_canvas.directional_crosshair_alpha
	var half_length = paint_canvas.directional_crosshair_length * 0.5
	var thickness = paint_canvas.directional_crosshair_thickness
	var direction = Vector2(cos(angle), sin(angle))
	var perpendicular = direction.rotated(PI / 2.0)
	draw_line(
		center - direction * half_length,
		center + direction * half_length,
		cross_primary_color,
		thickness
	)
	draw_line(
		center - perpendicular * half_length,
		center + perpendicular * half_length,
		cross_secondary_color,
		thickness
	)
