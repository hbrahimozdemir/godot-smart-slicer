@tool
class_name AutoSlicer

static func slice(image: Image, alpha_threshold: float = 0.1, min_size: Vector2i = Vector2i(4, 4)) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not image: 
		return rects

	var width: int = image.get_width()
	var height: int = image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	visited.fill(0)

	for y in range(height):
		for x in range(width):
			var idx: int = y * width + x
			if visited[idx] != 0: 
				continue

			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > alpha_threshold:
				var bounds: Rect2 = _flood_fill(image, x, y, width, height, visited, alpha_threshold)
				if bounds.size.x >= min_size.x and bounds.size.y >= min_size.y:
					rects.append(bounds)
			else:
				visited[idx] = 1

	return rects

static func _flood_fill(image: Image, start_x: int, start_y: int, width: int, height: int, visited: PackedByteArray, alpha_threshold: float) -> Rect2:
	var queue: Array = [Vector2i(start_x, start_y)]
	visited[start_y * width + start_x] = 1
	var min_x: int = start_x
	var max_x: int = start_x
	var min_y: int = start_y
	var max_y: int = start_y

	var head: int = 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1

		var x: int = p.x
		var y: int = p.y

		var c: Color = image.get_pixel(x, y)
		if c.a > alpha_threshold:
			if x < min_x: 
				min_x = x
			if x > max_x: 
				max_x = x
			if y < min_y: 
				min_y = y
			if y > max_y: 
				max_y = y

			var idx_l := y * width + (x - 1)
			if x > 0 and visited[idx_l] == 0: 
				visited[idx_l] = 1
				queue.append(Vector2i(x - 1, y))

			var idx_r := y * width + (x + 1)
			if x < width - 1 and visited[idx_r] == 0: 
				visited[idx_r] = 1
				queue.append(Vector2i(x + 1, y))

			var idx_u := (y - 1) * width + x
			if y > 0 and visited[idx_u] == 0: 
				visited[idx_u] = 1
				queue.append(Vector2i(x, y - 1))

			var idx_d := (y + 1) * width + x
			if y < height - 1 and visited[idx_d] == 0: 
				visited[idx_d] = 1
				queue.append(Vector2i(x, y + 1))

	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

static func slice_grid(image: Image, cell_w: int, cell_h: int, off_x: int, off_y: int, sep_x: int, sep_y: int, keep_empty: bool = false, alpha_threshold: float = 0.05) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not image:
		return rects

	var W: int = image.get_width()
	var H: int = image.get_height()

	for y in range(off_y, H - cell_h + 1, cell_h + sep_y):
		for x in range(off_x, W - cell_w + 1, cell_w + sep_x):
			var r := Rect2(x, y, cell_w, cell_h)
			if keep_empty or not _is_region_transparent(image, r, alpha_threshold):
				rects.append(r)

	return rects

static func _is_region_transparent(image: Image, r: Rect2, threshold: float) -> bool:
	var x_start: int = int(r.position.x)
	var y_start: int = int(r.position.y)
	var x_end: int = x_start + int(r.size.x)
	var y_end: int = y_start + int(r.size.y)
	
	var W: int = image.get_width()
	var H: int = image.get_height()
	x_start = clamp(x_start, 0, W)
	y_start = clamp(y_start, 0, H)
	x_end = clamp(x_end, 0, W)
	y_end = clamp(y_end, 0, H)

	for py in range(y_start, y_end):
		for px in range(x_start, x_end):
			if image.get_pixel(px, py).a > threshold:
				return false
	return true

