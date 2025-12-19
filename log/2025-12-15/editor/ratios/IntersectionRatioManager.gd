class_name IntersectionRatioManager
extends RefCounted

var canvas: Node2D
var base_line: CanvasPreview.ConnectionLine
var target_lines: Array[CanvasPreview.ConnectionLine] = []
var segment_ratios: Array[float] = []
var target_ratios: Dictionary = {}  # key: ConnectionLine, value: Vector2 (上部比:下部比)

func set_canvas(new_canvas: Node2D):
	canvas = new_canvas

func set_base_line(line: CanvasPreview.ConnectionLine):
	base_line = line
	_update_segment_ratios()

func add_target_line(line: CanvasPreview.ConnectionLine, ratio: Vector2 = Vector2(1.0, 1.0)):
	# 基準線と同じ線が追加されようとしているかチェック
	if line == base_line:
		print("Warning: Attempting to add base line as target line")
		return
		
	# 既に追加されている線かチェック
	if !target_lines.has(line):
		print("Adding target line: ", line, " with ratio: ", ratio)
		target_lines.append(line)
		target_ratios[line] = ratio
		print("Current target lines count: ", target_lines.size())
		_update_segment_ratios()
		
		# 追加された線の初期状態を出力
		print("Line start: ", line.start_point.position)
		print("Line end: ", line.end_point.position)

func remove_target_line(line: CanvasPreview.ConnectionLine):
	var idx = target_lines.find(line)
	if idx != -1:
		target_lines.remove_at(idx)
		target_ratios.erase(line)
		_update_segment_ratios()

func set_target_ratio(line: CanvasPreview.ConnectionLine, ratio: Vector2):
	if target_lines.has(line):
		target_ratios[line] = ratio

func set_segment_ratio(index: int, ratio: float):
	if index >= 0 and index < segment_ratios.size():
		segment_ratios[index] = ratio

func _update_segment_ratios():
	segment_ratios.clear()
	# 対象線の数 + 1のセグメントが必要
	print("target_lines count:", target_lines.size())  # デバッグ出力を追加
	for i in range(target_lines.size() + 1):
		segment_ratios.append(1.0)
	print("updated segment_ratios size:", segment_ratios.size())

func update_positions():
	print("base_line",base_line," target_lines",target_lines," segment_ratios",segment_ratios," target_ratios",target_ratios)
	if !base_line or target_lines.is_empty():
		return
		
	print("Updating positions with:")
	print("Base line: ", base_line)
	print("Base line start: ", base_line.start_point.position)
	print("Base line end: ", base_line.end_point.position)
	print("Target lines count: ", target_lines.size())
	
	var base_start = base_line.start_point.position
	var base_end = base_line.end_point.position
	var base_vector = base_end - base_start
	var base_length = base_vector.length()
	
	# 基準線が有効な長さを持っているか確認
	if base_length < 0.001:
		print("Warning: Base line is too short")
		return
		
	var unit_vector = base_vector.normalized()
	
	# セグメント比率の合計を計算
	var total_ratio = segment_ratios.reduce(func(accum, ratio): return accum + ratio, 0.0)
	if total_ratio <= 0:
		print("Warning: Invalid total ratio")
		return
	
	# 累積比率を使用して各交点の位置を計算
	var accumulated_length = 0.0
	for i in range(target_lines.size()):
		var segment_ratio = segment_ratios[i] / total_ratio
		var segment_length = base_length * segment_ratio
		accumulated_length += segment_length
		var intersection_pos = base_start + unit_vector * accumulated_length
		
		var target_line = target_lines[i]
		if not target_line:
			print("Warning: Invalid target line at index ", i)
			continue
			
		# 対象線の現在の方向を保持
		var current_direction = (target_line.end_point.position - target_line.start_point.position).normalized()
		var target_length = target_line.get_length()
		
		# 比率に基づいて長さを計算
		var ratio = target_ratios[target_line]
		var ratio_sum = ratio.x + ratio.y
		var upper_length = (target_length * ratio.x) / ratio_sum
		var lower_length = target_length - upper_length
		
		print("Processing target line ", i)
		print("Intersection position: ", intersection_pos)
		print("Direction: ", current_direction)
		print("Lengths - Upper: ", upper_length, " Lower: ", lower_length)
		
		# 新しい位置を設定
		target_line.start_point.position = intersection_pos - current_direction * upper_length
		target_line.end_point.position = intersection_pos + current_direction * lower_length
		
		print("Updated positions - Start: ", target_line.start_point.position, 
			  " End: ", target_line.end_point.position)
	
	canvas.queue_redraw()
