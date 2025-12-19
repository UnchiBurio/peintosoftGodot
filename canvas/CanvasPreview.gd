# CanvasPreview.gd
class_name CanvasPreview
extends RefCounted

var paint_canvas: Node2D

# 点の性質を表す列挙型
enum PointProperty {
	NONE = 0,
	INFINITE_LINE = 1,
	PERPENDICULAR_LINE = 2
	# 今後追加する性質をここに定義
}
# 点の情報を管理するクラス
class PreviewPoint:
	var position: Vector2
	var properties: Array[PointProperty]  # 点が持つ性質の配列
	var name: String = ""
	
	func _init(pos: Vector2, point_name: String = ""):
		position = pos
		properties = []
		name = point_name if point_name else "Point"
	
	# 性質の追加
	func add_property(prop: PointProperty) -> void:
		if not properties.has(prop):
			properties.append(prop)
	
	# 性質の削除
	func remove_property(prop: PointProperty) -> void:
		properties.erase(prop)
	
	# 性質を持っているかチェック
	func has_property(prop: PointProperty) -> bool:
		return properties.has(prop)

# 接続線クラスの定義
class ConnectionLine:
	# 接続線の種類
	enum LineType {
		NORMAL,     # 通常の線
		GUIDE,      # ガイド線
		DIMENSION,  # 寸法線
		EXTENSION   # 延長線
	}

	# 接続線の状態
	enum LineState {
		NORMAL,     # 通常
		SELECTED,   # 選択中
		HIGHLIGHTED # ハイライト
	}

	var start_point: PreviewPoint          # 開始点
	var end_point: PreviewPoint            # 終点
	var type: LineType = LineType.NORMAL   # 線の種類
	var state: LineState = LineState.NORMAL # 線の状態
	var style: Dictionary = {              # 線のスタイル
		"color": Color.BLUE,              # 色
		"width": 2.0,                     # 太さ
		"dash_pattern": [],               # 破線パターン
		"alpha": 1.0                      # 透明度
	}
	var metadata: Dictionary = {}          # 追加情報用
	var name: String = ""# 名前プロパティ
	var position_offset: Vector2 = Vector2.ZERO  # 中点からのオフセット位置

	func _init(start: PreviewPoint, end: PreviewPoint, line_name: String = ""):
		start_point = start
		end_point = end
		name = line_name if line_name else "Line"
		position_offset = Vector2.ZERO
		
	# 線の長さを取得
	func get_length() -> float:
		return start_point.position.distance_to(end_point.position)

	# 線の長さを設定（終点を移動）
	func set_length(new_length: float) -> void:
		var direction = (end_point.position - start_point.position).normalized()
		end_point.position = start_point.position + direction * new_length

	# 点との関係をチェック
	func contains_point(point: PreviewPoint) -> bool:
		return point == start_point or point == end_point

	# 点までの距離を計算
	func distance_to_point(point: Vector2) -> float:
		return _point_line_distance(point, start_point.position, end_point.position)

	# 内部で使用する距離計算
	func _point_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
		var line_vec = line_end - line_start
		var point_vec = point - line_start
		var line_length = line_vec.length()
		if line_length == 0:
			return point_vec.length()
		
		var t = clamp(point_vec.dot(line_vec) / line_vec.length_squared(), 0, 1)
		var projection = line_start + line_vec * t
		return point.distance_to(projection)
		
	func get_start_position() -> Vector2:
		return start_point.position

	func get_end_position() -> Vector2:
		return end_point.position

	func set_start_position(pos: Vector2) -> void:
		start_point.position = pos

	func set_end_position(pos: Vector2) -> void:
		end_point.position = pos
		
	 # 線の中点を取得
	func get_midpoint() -> Vector2:
		return (start_point.position + end_point.position) * 0.5

	# 実際の表示位置を取得（中点 + オフセット）
	func get_display_position() -> Vector2:
		return get_midpoint() + position_offset

	# 表示位置を設定（オフセットを計算）
	func set_display_position(new_pos: Vector2) -> void:
		position_offset = new_pos - get_midpoint()

	# 線の位置を更新（両端点を移動）
	func update_position(new_pos: Vector2) -> void:
		var delta = new_pos - get_display_position()
		start_point.position += delta
		end_point.position += delta

func _init(canvas: Node2D):
	paint_canvas = canvas

func find_nearest_preview_point(position: Vector2) -> Vector2:
	var min_distance := 20.0
	var nearest_point := Vector2.ZERO
	var found := false
	var nearest_distance := INF
	
	for point in paint_canvas.preview_points:
		var distance = position.distance_to(point.position)
		if distance < min_distance and distance < nearest_distance:
			nearest_distance = distance
			nearest_point = point.position
			found = true
	
	return nearest_point if found else position

# 指定位置にある点を探す
func find_point_at_position(position: Vector2, threshold: float = 5.0) -> PreviewPoint:
	for point in paint_canvas.preview_points:
		if position.distance_to(point.position) < threshold:
			return point
	return null

# 最も近い接続線を見つける
func find_nearest_connection(position: Vector2, threshold: float = 10.0) -> ConnectionLine:
	var min_distance := threshold
	var nearest_connection = null
	
	for connection in paint_canvas.preview_connections:
		var distance = connection.distance_to_point(position)
		if distance < min_distance:
			min_distance = distance
			nearest_connection = connection
	
	return nearest_connection

# 最適化された点と線分の距離計算
func _point_line_distance_squared(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_length_squared = line_vec.length_squared()
	
	if line_length_squared == 0:
		return point_vec.length_squared()
	
	var t = clamp(point_vec.dot(line_vec) / line_length_squared, 0, 1)
	var projection = line_start + line_vec * t
	return point.distance_squared_to(projection)
