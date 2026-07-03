# CanvasFill.gd
# 塗りつぶし（バケツツール）のチャンク単位2階層フラッドフィル。
# - 第1階層: チャンク全体が対象色なら SOLID/EMPTY 化で O(1) で塗り、4隣接へ全辺シードを伝播
# - 第2階層: 不均一な BITMAP チャンクのみ、int32 バッファ上でスキャンラインフィル
# 全体をメインスレッドでフレーム時間予算付きに実行し、巨大キャンバスでもUIを固めない。
class_name CanvasFill
extends RefCounted

# チャンク全辺シードのマーカー。Vector3i(SPAN_FULL_EDGE, 辺ID, 0) で表す
const SPAN_FULL_EDGE := -1
const EDGE_LEFT := 0    # 受け側チャンクの左端列 x=0 をシード
const EDGE_RIGHT := 1   # 受け側チャンクの右端列 x=valid_w-1 をシード
const EDGE_TOP := 2     # 受け側チャンクの上端行 y=0 をシード
const EDGE_BOTTOM := 3  # 受け側チャンクの下端行 y=valid_h-1 をシード

class ChunkBuffer:
	extends RefCounted
	# image.get_data().to_int32_array()。1画素=int32（RGBA8をネイティブエンディアンで解釈）
	var ints: PackedInt32Array
	var width: int = 0    # ストライド。旧fillがCHUNK_SIZE未満のimageを残している場合がある
	var height: int = 0
	var valid_w: int = 0  # キャンバス内の有効幅（端の部分チャンク対応）
	var valid_h: int = 0
	var modified: bool = false

var paint_canvas: Node2D
var active: bool = false

# --- 操作中のみ有効なコンテキスト ---
var layer_index: int = 0
var fill_color: Color = Color.TRANSPARENT
var fill_int: int = 0
var fill_is_transparent: bool = false
var target_int: int = 0
var transparent_int: int = 0
var chunk_grid: Vector2i = Vector2i.ZERO  # キャンバスを覆うチャンク数

var queue: Array[Vector2i] = []    # 処理待ちチャンク座標
var queued: Dictionary = {}        # chunk_pos -> true（重複enqueue防止）
var pending: Dictionary = {}       # chunk_pos -> Array[Vector3i] シードスパン
var buffers: Dictionary = {}       # chunk_pos -> ChunkBuffer（操作中のint32バッファキャッシュ）
var visited: Dictionary = {}       # 均一判定を実施済みのチャンク
var done_uniform: Dictionary = {}  # 均一fill済みチャンク（以後スキップ）

func _init(canvas: Node2D):
	paint_canvas = canvas

# 色→int32 は必ず「RGBA8バイト列 → to_int32_array()」経路で変換する。
# バッファ側（image.get_data().to_int32_array()）と同じネイティブエンディアンで
# 解釈を揃えるため。シフト演算での手動構築は禁止。
func _rgba_int(color: Color) -> int:
	var rgba: PackedByteArray = paint_canvas._color_to_rgba8(color)
	return rgba.to_int32_array()[0]

# 塗りつぶし開始。no-op（開始点が塗りつぶし色と同色）なら false を返す。
# true を返したら呼び出し側が step() を完了まで呼ぶこと。
func begin(layer_idx: int, start: Vector2i, color: Color) -> bool:
	_reset()
	layer_index = layer_idx
	fill_color = color
	var fill_rgba: PackedByteArray = paint_canvas._color_to_rgba8(color)
	fill_is_transparent = fill_rgba[3] == 0
	fill_int = fill_rgba.to_int32_array()[0]
	transparent_int = _rgba_int(Color.TRANSPARENT)
	var chunk_size: int = paint_canvas.CHUNK_SIZE
	chunk_grid = Vector2i(
		ceili(paint_canvas.canvas_size.x / float(chunk_size)),
		ceili(paint_canvas.canvas_size.y / float(chunk_size))
	)
	var chunk_pos := Vector2i(start.x >> paint_canvas.CHUNK_BITS, start.y >> paint_canvas.CHUNK_BITS)
	var local := Vector2i(start.x & paint_canvas.CHUNK_MASK, start.y & paint_canvas.CHUNK_MASK)
	# 対象色は開始画素の実バイトから決める（Color経由の丸め誤差を避ける）
	var chunk = _get_chunk(chunk_pos)
	if chunk == null or chunk.storage_mode == CanvasChunk.StorageMode.EMPTY:
		target_int = transparent_int
	elif chunk.storage_mode == CanvasChunk.StorageMode.SOLID:
		target_int = _rgba_int(chunk.solid_color)
	else:
		var buf := _get_buffer(chunk_pos, chunk)
		if local.x >= buf.valid_w or local.y >= buf.valid_h:
			_reset()
			return false
		target_int = buf.ints[local.y * buf.width + local.x]
	if fill_int == target_int:
		_reset()
		return false
	active = true
	_enqueue(chunk_pos, Vector3i(local.x, local.x, local.y))
	return true

# キューを予算内（マイクロ秒）で処理する。true = fill完了（結果は適用済み）
func step(budget_usec: int) -> bool:
	if not active:
		return true
	var start_time := Time.get_ticks_usec()
	while not queue.is_empty():
		var chunk_pos: Vector2i = queue.pop_back()
		queued.erase(chunk_pos)
		var spans: Array = pending.get(chunk_pos, [])
		pending.erase(chunk_pos)
		_process_chunk(chunk_pos, spans)
		if Time.get_ticks_usec() - start_time > budget_usec:
			return false
	_finalize()
	return true

func _get_chunk(chunk_pos: Vector2i) -> CanvasChunk:
	var layer = paint_canvas.layers[layer_index]
	if not layer.chunks.has(chunk_pos):
		return null
	return layer.chunks[chunk_pos]

func _get_buffer(chunk_pos: Vector2i, chunk: CanvasChunk) -> ChunkBuffer:
	var buf: ChunkBuffer = buffers.get(chunk_pos)
	if buf != null:
		return buf
	var image: Image = chunk.image
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	buf = ChunkBuffer.new()
	buf.width = image.get_width()
	buf.height = image.get_height()
	var rect: Rect2i = paint_canvas._get_chunk_canvas_rect(chunk_pos)
	buf.valid_w = mini(buf.width, rect.size.x)
	buf.valid_h = mini(buf.height, rect.size.y)
	buf.ints = image.get_data().to_int32_array()
	buffers[chunk_pos] = buf
	return buf

func _enqueue(chunk_pos: Vector2i, span: Vector3i) -> void:
	if chunk_pos.x < 0 or chunk_pos.y < 0 or chunk_pos.x >= chunk_grid.x or chunk_pos.y >= chunk_grid.y:
		return
	if done_uniform.has(chunk_pos):
		return
	if pending.has(chunk_pos):
		pending[chunk_pos].append(span)
	else:
		pending[chunk_pos] = [span]
	if not queued.has(chunk_pos):
		queued[chunk_pos] = true
		queue.append(chunk_pos)

func _process_chunk(chunk_pos: Vector2i, spans: Array) -> void:
	if done_uniform.has(chunk_pos):
		return
	var chunk = _get_chunk(chunk_pos)
	if not visited.has(chunk_pos):
		visited[chunk_pos] = true
		if _is_chunk_uniform_target(chunk_pos, chunk):
			_fill_chunk_uniform(chunk_pos, chunk)
			return
	if chunk == null or chunk.storage_mode != CanvasChunk.StorageMode.BITMAP:
		return  # 対象色でない EMPTY/SOLID = 塗り領域の境界
	_scanline_fill(chunk_pos, _get_buffer(chunk_pos, chunk), spans)

func _is_chunk_uniform_target(chunk_pos: Vector2i, chunk: CanvasChunk) -> bool:
	if chunk == null or chunk.storage_mode == CanvasChunk.StorageMode.EMPTY:
		return target_int == transparent_int
	if chunk.storage_mode == CanvasChunk.StorageMode.SOLID:
		return _rgba_int(chunk.solid_color) == target_int
	# BITMAP はネイティブの count() で全画素一致を判定（GDScriptの画素ループ禁止）
	var buf := _get_buffer(chunk_pos, chunk)
	return buf.ints.count(target_int) == buf.ints.size()

# 第1階層: チャンク全体が対象色 → O(1) で塗り、4隣接へ全辺シードを伝播
func _fill_chunk_uniform(chunk_pos: Vector2i, chunk: CanvasChunk) -> void:
	buffers.erase(chunk_pos)
	done_uniform[chunk_pos] = true
	paint_canvas._record_chunk_state_compact(layer_index, chunk_pos)
	if fill_is_transparent:
		# 透明で塗る場合、対象は非透明チャンクのみ（同色no-opはbegin()で除外済み）
		if chunk != null:
			chunk.clear_to_empty()
			paint_canvas._mark_chunk_for_update(chunk, layer_index)
	else:
		var target_chunk = paint_canvas._get_or_create_layer_chunk(layer_index, chunk_pos)
		target_chunk.set_solid(fill_color)
		paint_canvas._mark_chunk_for_update(target_chunk, layer_index)
	_enqueue(chunk_pos + Vector2i(1, 0), Vector3i(SPAN_FULL_EDGE, EDGE_LEFT, 0))
	_enqueue(chunk_pos + Vector2i(-1, 0), Vector3i(SPAN_FULL_EDGE, EDGE_RIGHT, 0))
	_enqueue(chunk_pos + Vector2i(0, 1), Vector3i(SPAN_FULL_EDGE, EDGE_TOP, 0))
	_enqueue(chunk_pos + Vector2i(0, -1), Vector3i(SPAN_FULL_EDGE, EDGE_BOTTOM, 0))

# 第2階層: BITMAPチャンク内のスキャンラインフィル（int32比較1回/画素）
func _scanline_fill(chunk_pos: Vector2i, buf: ChunkBuffer, seed_spans: Array) -> void:
	# PackedInt32Arrayはコピーオンライトのためローカルで書き換えて最後に書き戻す
	var ints: PackedInt32Array = buf.ints
	var w: int = buf.width
	var vw: int = buf.valid_w
	var vh: int = buf.valid_h
	var target: int = target_int
	var fill_value: int = fill_int
	var stack: Array[Vector2i] = []
	for span in seed_spans:
		_expand_seed_span(ints, w, vw, vh, target, span, stack)
	if stack.is_empty():
		return
	var recorded: bool = buf.modified
	var modified: bool = false
	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		var row: int = pos.y * w
		if ints[row + pos.x] != target:
			continue
		var left: int = pos.x
		var right: int = pos.x
		while left > 0 and ints[row + left - 1] == target:
			left -= 1
		while right + 1 < vw and ints[row + right + 1] == target:
			right += 1
		if not recorded:
			# 最初の書き込み前に元状態をundoスナップショットへ記録
			paint_canvas._record_chunk_state_compact(layer_index, chunk_pos)
			recorded = true
		modified = true
		for offset in range(row + left, row + right + 1):
			ints[offset] = fill_value
		# チャンク境界に達したスパンを隣接チャンクへシードとして伝播
		if left == 0:
			_propagate(chunk_pos + Vector2i(-1, 0), EDGE_RIGHT, pos.y, pos.y)
		if right == vw - 1:
			_propagate(chunk_pos + Vector2i(1, 0), EDGE_LEFT, pos.y, pos.y)
		if pos.y == 0:
			_propagate(chunk_pos + Vector2i(0, -1), EDGE_BOTTOM, left, right)
		if pos.y == vh - 1:
			_propagate(chunk_pos + Vector2i(0, 1), EDGE_TOP, left, right)
		# 上下の行から対象色の連続区間の先頭をスタックへ積む
		if pos.y > 0:
			_seed_row_range(ints, (pos.y - 1) * w, left, right, target, pos.y - 1, stack)
		if pos.y + 1 < vh:
			_seed_row_range(ints, (pos.y + 1) * w, left, right, target, pos.y + 1, stack)
	if modified:
		buf.modified = true
		buf.ints = ints

# 隣接チャンクの受け入れ辺座標に変換してシードを積む
# entry_edge が LEFT/RIGHT のとき a = 行y、TOP/BOTTOM のとき a..b = 列範囲
func _propagate(neighbor_pos: Vector2i, entry_edge: int, a: int, b: int) -> void:
	if neighbor_pos.x < 0 or neighbor_pos.y < 0 or neighbor_pos.x >= chunk_grid.x or neighbor_pos.y >= chunk_grid.y:
		return
	var rect: Rect2i = paint_canvas._get_chunk_canvas_rect(neighbor_pos)
	match entry_edge:
		EDGE_LEFT:
			_enqueue(neighbor_pos, Vector3i(0, 0, a))
		EDGE_RIGHT:
			var x := rect.size.x - 1
			_enqueue(neighbor_pos, Vector3i(x, x, a))
		EDGE_TOP:
			_enqueue(neighbor_pos, Vector3i(a, b, 0))
		EDGE_BOTTOM:
			_enqueue(neighbor_pos, Vector3i(a, b, rect.size.y - 1))

func _expand_seed_span(ints: PackedInt32Array, w: int, vw: int, vh: int, target: int, span: Vector3i, stack: Array[Vector2i]) -> void:
	if vw <= 0 or vh <= 0:
		return
	if span.x == SPAN_FULL_EDGE:
		match span.y:
			EDGE_LEFT:
				_seed_column(ints, w, 0, vh, target, stack)
			EDGE_RIGHT:
				_seed_column(ints, w, vw - 1, vh, target, stack)
			EDGE_TOP:
				_seed_row_range(ints, 0, 0, vw - 1, target, 0, stack)
			EDGE_BOTTOM:
				_seed_row_range(ints, (vh - 1) * w, 0, vw - 1, target, vh - 1, stack)
		return
	var y := clampi(span.z, 0, vh - 1)
	var x0 := clampi(span.x, 0, vw - 1)
	var x1 := clampi(span.y, 0, vw - 1)
	_seed_row_range(ints, y * w, x0, x1, target, y, stack)

# row_offset の行の [x0, x1] から、対象色の連続区間の先頭だけを stack へ積む
func _seed_row_range(ints: PackedInt32Array, row_offset: int, x0: int, x1: int, target: int, y: int, stack: Array[Vector2i]) -> void:
	var x := x0
	while x <= x1:
		if ints[row_offset + x] == target:
			stack.append(Vector2i(x, y))
			x += 1
			while x <= x1 and ints[row_offset + x] == target:
				x += 1
		else:
			x += 1

func _seed_column(ints: PackedInt32Array, w: int, x: int, vh: int, target: int, stack: Array[Vector2i]) -> void:
	var prev := false
	for y in range(vh):
		if ints[y * w + x] == target:
			if not prev:
				stack.append(Vector2i(x, y))
			prev = true
		else:
			prev = false

# 変更のあったバッファをチャンクへ書き戻す（すべてネイティブ操作）
func _finalize() -> void:
	for chunk_pos in buffers.keys():
		var buf: ChunkBuffer = buffers[chunk_pos]
		if not buf.modified:
			continue
		var chunk = paint_canvas._get_or_create_layer_chunk(layer_index, chunk_pos)
		if buf.ints.count(fill_int) == buf.ints.size():
			# fillの結果チャンク全体が単色になった → SOLID/EMPTYへ正規化
			if fill_is_transparent:
				chunk.clear_to_empty()
			else:
				chunk.set_solid(fill_color)
		else:
			var image := Image.create_from_data(buf.width, buf.height, false, Image.FORMAT_RGBA8, buf.ints.to_byte_array())
			chunk.set_bitmap_from_image(image)
		paint_canvas._mark_chunk_for_update(chunk, layer_index)
	_reset()

func _reset() -> void:
	active = false
	queue.clear()
	queued.clear()
	pending.clear()
	buffers.clear()
	visited.clear()
	done_uniform.clear()
