# CanvasResize.gd
class_name CanvasResize
extends RefCounted

var paint_canvas: Node2D
var is_resizing := false
var resize_handle_size := 10.0  # リサイズハンドルの大きさ
var resize_edge : Vector2 = Vector2.ZERO  # どの辺をリサイズしているか (x: -1=左, 1=右, y: -1=上, 1=下)
var min_canvas_size := Vector2(100, 100)  # 最小サイズ
var resize_start_size := Vector2.ZERO
var resize_start_position := Vector2.ZERO
var resize_origin := Vector2.ZERO

func _init(canvas: Node2D):
	paint_canvas = canvas

func start_resize(edge: Vector2, global_pos: Vector2):
	is_resizing = true
	resize_edge = edge
	resize_start_size = paint_canvas.canvas_size
	resize_start_position = paint_canvas.position
	resize_origin = paint_canvas.get_parent().get_global_transform().affine_inverse() * global_pos

func update_resize(global_pos: Vector2):
	if not is_resizing:
		return
	
	var current_pos = paint_canvas.get_parent().get_global_transform().affine_inverse() * global_pos
	var delta = current_pos - resize_origin
	
	var new_size = resize_start_size
	var new_position = resize_start_position
	
	# 水平方向のリサイズ
	if resize_edge.x != 0:
		if resize_edge.x > 0:  # 右端
			new_size.x = max(min_canvas_size.x, resize_start_size.x + delta.x)
		else:  # 左端
			var new_width = max(min_canvas_size.x, resize_start_size.x - delta.x)
			new_position.x = resize_start_position.x + (resize_start_size.x - new_width)
			new_size.x = new_width
	
	# 垂直方向のリサイズ
	if resize_edge.y != 0:
		if resize_edge.y > 0:  # 下端
			new_size.y = max(min_canvas_size.y, resize_start_size.y + delta.y)
		else:  # 上端
			var new_height = max(min_canvas_size.y, resize_start_size.y - delta.y)
			new_position.y = resize_start_position.y + (resize_start_size.y - new_height)
			new_size.y = new_height
	
	# キャンバスサイズを更新
	paint_canvas.canvas_size = new_size
	paint_canvas.position = new_position
	
	# イメージとテクスチャを更新
	paint_canvas._update_canvas_rect()

func end_resize():
	is_resizing = false
	resize_edge = Vector2.ZERO
