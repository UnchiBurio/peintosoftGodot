# CanvasMove.gd
class_name CanvasMove
extends RefCounted

var paint_canvas: Node2D
var is_moving := false
var drag_start_position := Vector2.ZERO
var initial_canvas_position := Vector2.ZERO

func _init(canvas: Node2D):
	paint_canvas = canvas

func start_move(global_pos: Vector2):
	is_moving = true
	# グローバル座標を保存
	drag_start_position = global_pos
	initial_canvas_position = paint_canvas.position
	
	# マウスカーソルが子キャンバス内のどの位置をつかんでいるかを記録
	var local_grab_pos = paint_canvas.to_local(global_pos)
	if not paint_canvas._is_position_in_canvas(local_grab_pos):
		is_moving = false  # キャンバス外なら移動をキャンセル

func update_move(global_pos: Vector2):
	if is_moving:
		# グローバル座標をキャンバスの親のローカル座標に変換
		var parent_space_current = paint_canvas.get_parent().get_global_transform().affine_inverse() * global_pos
		var parent_space_start = paint_canvas.get_parent().get_global_transform().affine_inverse() * drag_start_position
		
		# 親空間でのデルタを計算
		var delta = parent_space_current - parent_space_start
		paint_canvas.position = initial_canvas_position + delta

func end_move():
	is_moving = false
