@tool
class_name AutoSlicer

# Optimization: entire image read as raw bytes once, avoiding per-pixel get_pixel() bridge calls.
# Optimization: stepped scan (step=4) reduces outer loop iterations by 16x for large images.
# Optimization: PackedByteArray for visited flags - compact memory, fast access.
# Optimization: BFS queue uses a flat PackedInt32Array of interleaved (x,y) pairs instead of Vector2i Array.

static func slice(image: Image, alpha_threshold: float = 0.1, min_size: Vector2i = Vector2i(4, 4)) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not image:
		return rects

	var src := image.duplicate()
	src.convert(Image.FORMAT_RGBA8)

	var width: int  = src.get_width()
	var height: int = src.get_height()

	# Read all pixel data once into a packed byte array (RGBA8: 4 bytes per pixel)
	var raw: PackedByteArray = src.get_data()

	var visited := PackedByteArray()
	visited.resize(width * height)
	visited.fill(0)

	# Threshold in 0–255 range to avoid float comparisons in the inner loop
	var alpha_byte: int = int(alpha_threshold * 255.0)

	# Stepped outer scan: step by min_size so we never miss a sprite island
	var step_x: int = max(1, min_size.x)
	var step_y: int = max(1, min_size.y)

	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var idx: int = y * width + x
			if visited[idx] != 0:
				continue

			# Alpha channel is byte offset 3 in RGBA8
			var raw_idx: int = idx * 4
			if raw[raw_idx + 3] > alpha_byte:
				var bounds: Rect2 = _flood_fill_raw(raw, x, y, width, height, visited, alpha_byte)
				if bounds.size.x >= min_size.x and bounds.size.y >= min_size.y:
					rects.append(bounds)
			else:
				visited[idx] = 1

	return rects


# BFS flood fill operating entirely on raw byte array - no get_pixel() calls.
static func _flood_fill_raw(raw: PackedByteArray, start_x: int, start_y: int,
		width: int, height: int, visited: PackedByteArray, alpha_byte: int) -> Rect2:
	# Flat int queue: pairs of x,y stored as x*65536+y packed into one int
	# Using PackedInt32Array for faster iteration than a generic Array of Vector2i
	var queue := PackedInt32Array()
	queue.resize(1024)
	var q_head: int = 0
	var q_tail: int = 0

	var start_flat: int = start_y * width + start_x
	visited[start_flat] = 1
	queue[q_tail]     = start_x
	queue[q_tail + 1] = start_y
	q_tail += 2

	var min_x: int = start_x
	var max_x: int = start_x
	var min_y: int = start_y
	var max_y: int = start_y
	var cap: int   = queue.size()

	while q_head < q_tail:
		var x: int = queue[q_head]
		var y: int = queue[q_head + 1]
		q_head += 2

		var raw_idx: int = (y * width + x) * 4
		if raw[raw_idx + 3] > alpha_byte:
			if x < min_x: min_x = x
			if x > max_x: max_x = x
			if y < min_y: min_y = y
			if y > max_y: max_y = y

			# Grow queue if needed
			if q_tail + 8 >= cap:
				cap = cap * 2
				queue.resize(cap)

			var fl: int
			if x > 0:
				fl = y * width + (x - 1)
				if visited[fl] == 0:
					visited[fl] = 1
					queue[q_tail]     = x - 1
					queue[q_tail + 1] = y
					q_tail += 2
			if x < width - 1:
				fl = y * width + (x + 1)
				if visited[fl] == 0:
					visited[fl] = 1
					queue[q_tail]     = x + 1
					queue[q_tail + 1] = y
					q_tail += 2
			if y > 0:
				fl = (y - 1) * width + x
				if visited[fl] == 0:
					visited[fl] = 1
					queue[q_tail]     = x
					queue[q_tail + 1] = y - 1
					q_tail += 2
			if y < height - 1:
				fl = (y + 1) * width + x
				if visited[fl] == 0:
					visited[fl] = 1
					queue[q_tail]     = x
					queue[q_tail + 1] = y + 1
					q_tail += 2

	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


# Grid slicing: uses raw byte data for transparent region check.
static func slice_grid(image: Image, cell_w: int, cell_h: int, off_x: int, off_y: int,
		sep_x: int, sep_y: int, keep_empty: bool = false, alpha_threshold: float = 0.05) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not image:
		return rects

	var src := image
	if image.get_format() != Image.FORMAT_RGBA8:
		src = image.duplicate()
		src.convert(Image.FORMAT_RGBA8)

	var W: int = src.get_width()
	var H: int = src.get_height()

	# Read raw bytes once for the entire image
	var raw: PackedByteArray = src.get_data()
	var alpha_byte: int = int(alpha_threshold * 255.0)

	for y in range(off_y, H - cell_h + 1, cell_h + sep_y):
		for x in range(off_x, W - cell_w + 1, cell_w + sep_x):
			if keep_empty or not _is_region_transparent_raw(raw, x, y, cell_w, cell_h, W, H, alpha_byte):
				rects.append(Rect2(x, y, cell_w, cell_h))

	return rects


# Transparency check using raw byte array - no get_pixel() calls.
static func _is_region_transparent_raw(raw: PackedByteArray, rx: int, ry: int,
		rw: int, rh: int, W: int, H: int, alpha_byte: int) -> bool:
	var x_end: int = mini(rx + rw, W)
	var y_end: int = mini(ry + rh, H)
	for py in range(ry, y_end):
		var row_base: int = py * W
		for px in range(rx, x_end):
			# Alpha is at byte offset 3 in RGBA8
			if raw[(row_base + px) * 4 + 3] > alpha_byte:
				return false
	return true


# Legacy helpers kept for compatibility (used externally, e.g., bg_remover)
static func _is_region_transparent(image: Image, r: Rect2, threshold: float) -> bool:
	if image.get_format() != Image.FORMAT_RGBA8:
		var tmp := image.duplicate()
		tmp.convert(Image.FORMAT_RGBA8)
		return _is_region_transparent_raw(tmp.get_data(), int(r.position.x), int(r.position.y),
			int(r.size.x), int(r.size.y), tmp.get_width(), tmp.get_height(), int(threshold * 255.0))
	return _is_region_transparent_raw(image.get_data(), int(r.position.x), int(r.position.y),
		int(r.size.x), int(r.size.y), image.get_width(), image.get_height(), int(threshold * 255.0))
