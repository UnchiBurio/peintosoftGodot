class_name AngleRatioManager
extends RefCounted

var canvas: Node2D
var base_line: CanvasPreview.ConnectionLine
var target_lines: Array[CanvasPreview.ConnectionLine] = []
var reference_line: CanvasPreview.ConnectionLine = null
var angle_ratios: Dictionary = {}  # key: ConnectionLine, value: float (角度の比率)

func set_canvas(new_canvas: Node2D):
	canvas = new_canvas

func set_base_line(line: CanvasPreview.ConnectionLine):
	base_line = line
	print("Base line set: ", line, " angle: ", _get_angle(line))

func set_reference_line(line: CanvasPreview.ConnectionLine):
	reference_line = line
	print("Reference line set: ", line, " angle: ", _get_angle(line))

func add_target_line(line: CanvasPreview.ConnectionLine, ratio: float = 1.0):
	if line != base_line and !target_lines.has(line):
		target_lines.append(line)
		angle_ratios[line] = ratio
		print("Target line added: ", line, " ratio: ", ratio, " angle: ", _get_angle(line))

func remove_target_line(line: CanvasPreview.ConnectionLine):
	var idx = target_lines.find(line)
	if idx != -1:
		if line == reference_line:
			reference_line = null
		target_lines.remove_at(idx)
		angle_ratios.erase(line)
		print("Target line removed: ", line)

func set_angle_ratio(line: CanvasPreview.ConnectionLine, ratio: float):
	if target_lines.has(line):
		angle_ratios[line] = ratio
		print("Ratio updated for line: ", line, " new ratio: ", ratio)

func _get_angle(line: CanvasPreview.ConnectionLine) -> float:
	if !line:
		return 0.0
	var direction = line.end_point.position - line.start_point.position
	return rad_to_deg(direction.angle())

func _get_base_angle() -> float:
	return rad_to_deg((base_line.end_point.position - base_line.start_point.position).angle())

func _get_reference_angle() -> float:
	if !reference_line:
		return 0.0
	return rad_to_deg((reference_line.end_point.position - reference_line.start_point.position).angle())

func update_angles():
	print("\n=== Starting angle update ===")
	if !base_line:
		print("Error: Base line is not set")
		return
		
	if !reference_line:
		print("Error: Reference line is not set")
		return
		
	if target_lines.is_empty():
		print("Error: No target lines")
		return

	var base_angle = _get_base_angle()
	var ref_angle = _get_reference_angle()
	var angle_diff = ref_angle - base_angle

	print("Base angle: ", base_angle)
	print("Reference angle: ", ref_angle)
	print("Angle difference: ", angle_diff)

	for line in target_lines:
		if line == reference_line:
			print("Skipping reference line: ", line)
			continue
			
		print("\nProcessing line: ", line)
		var ratio = angle_ratios[line]
		print("Line ratio: ", ratio)
		
		var current_angle = _get_angle(line)
		print("Current angle: ", current_angle)
		
		var target_angle = base_angle + (angle_diff * ratio)
		print("Target angle: ", target_angle)
		
		var line_length = line.get_length()
		print("Line length: ", line_length)
		
		var direction = Vector2.RIGHT.rotated(deg_to_rad(target_angle))
		line.end_point.position = line.start_point.position + direction * line_length
		
		var new_angle = _get_angle(line)
		print("New angle after update: ", new_angle)

	canvas.queue_redraw()
	print("=== Angle update completed ===\n")
