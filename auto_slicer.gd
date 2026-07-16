@tool
class_name AutoSlicer

static func slice(image: Image, alpha_threshold: float = 0.1, min_size: Vector2i = Vector2i(4, 4)) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if not image: 
		return rects

	var width: int = image.get_width()
	var height: int = image.get_height()
	var visited: Array = []
	visited.resize(width * height)
	visited.fill(false)

	for y in range(height):
		for x in range(width):
			var idx: int = y * width + x
			if visited[idx]: 
				continue

			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > alpha_threshold:
				var bounds: Rect2 = _flood_fill(image, x, y, width, height, visited, alpha_threshold)
				if bounds.size.x >= min_size.x and bounds.size.y >= min_size.y:
					rects.append(bounds)
			else:
				visited[idx] = true

	return rects

static func _flood_fill(image: Image, start_x: int, start_y: int, width: int, height: int, visited: Array, alpha_threshold: float) -> Rect2:
	var queue: Array = [Vector2i(start_x, start_y)]
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
		var idx: int = y * width + x
		if visited[idx]: 
			continue
		visited[idx] = true

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

			if x > 0 and not visited[y * width + (x - 1)]: 
				queue.append(Vector2i(x - 1, y))
			if x < width - 1 and not visited[y * width + (x + 1)]: 
				queue.append(Vector2i(x + 1, y))
			if y > 0 and not visited[(y - 1) * width + x]: 
				queue.append(Vector2i(x, y - 1))
			if y < height - 1 and not visited[(y + 1) * width + x]: 
				queue.append(Vector2i(x, y + 1))

	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
