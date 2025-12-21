# CanvasLayer.gd
class_name PaintCanvasLayer
extends RefCounted

var paint_canvas: Node2D
var current_layer_index := 0
var current_layer_name := "layer0"

func _init(canvas: Node2D):
	paint_canvas = canvas

# レイヤー切り替えロジックのみ残す（外部から呼ばれる用）
func set_active_layer(index: int):
	if index >= 0 and index < paint_canvas.layers.size():
		current_layer_index = index
		current_layer_name = paint_canvas.layers[index].name
		print("Active layer changed to:", index)
