# RatioManager.gd
class_name RatioManager
extends RefCounted

enum TargetParameter {
	LENGTH,
	ANGLE
}

class RatioEntry:
	var ratio: float = 1.0
	var connection: CanvasPreview.ConnectionLine
	var is_reference: bool = false
	
	func _init(r: float, c: CanvasPreview.ConnectionLine, ref: bool = false):
		ratio = r
		connection = c
		is_reference = ref

var target_parameter: TargetParameter = TargetParameter.LENGTH
var entries: Array[RatioEntry] = []
var canvas: Node2D

func set_canvas(new_canvas: Node2D):
	canvas = new_canvas

func add_entry(ratio: float, connection: CanvasPreview.ConnectionLine, is_reference: bool = false):
	entries.append(RatioEntry.new(ratio, connection, is_reference))

func get_reference_entry() -> RatioEntry:
	for entry in entries:
		if entry.is_reference:
			return entry
	return null

func update_connections():
	var reference = get_reference_entry()
	if not reference:
		return
		
	var ref_value = _get_parameter_value(reference.connection)
	
	for entry in entries:
		if entry == reference:
			continue
			
		var target_value = ref_value * (entry.ratio / reference.ratio)
		_set_parameter_value(entry.connection, target_value)
	
	canvas.queue_redraw()

func _get_parameter_value(connection: CanvasPreview.ConnectionLine) -> float:
	match target_parameter:
		TargetParameter.LENGTH:
			return connection.get_length()
		TargetParameter.ANGLE:
			return rad_to_deg((connection.end_point.position - connection.start_point.position).angle())
	return 0.0

func _set_parameter_value(connection: CanvasPreview.ConnectionLine, value: float):
	match target_parameter:
		TargetParameter.LENGTH:
			var direction = (connection.end_point.position - connection.start_point.position).normalized()
			connection.end_point.position = connection.start_point.position + direction * value
		TargetParameter.ANGLE:
			var length = connection.get_length()
			var angle = deg_to_rad(value)
			var direction = Vector2(cos(angle), sin(angle))
			connection.end_point.position = connection.start_point.position + direction * length
