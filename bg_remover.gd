@tool
class_name BgRemover

# Perceptual color distance flood-fill background remover with alpha matting.

const _K: int = 4
const _KMEANS_ITER: int = 12
const _MAT_RADIUS: int = 3

static func remove(image: Image, tolerance: float = 0.18, feather: bool = true) -> Image:
	var img: Image = image.duplicate()
	img.convert(Image.FORMAT_RGBA8)

	var W: int = img.get_width()
	var H: int = img.get_height()
	if W < 2 or H < 2:
		return img

	var bg_centers: Array = _edge_kmeans(img, W, H)

	var removed: Array = []
	removed.resize(W * H)
	removed.fill(false)

	for ci in range(bg_centers.size()):
		var bg: Color = bg_centers[ci]
		_bfs_fill(img, bg, tolerance, W, H, removed)

	_apply_matting(img, removed, W, H, feather)

	return img

static func _edge_kmeans(img: Image, W: int, H: int) -> Array:
	var samples: Array = []
	var step: int = max(1, min(W, H) / 60)

	for x in range(0, W, step):
		samples.append(img.get_pixel(x, 0))
		samples.append(img.get_pixel(x, H - 1))
	for y in range(0, H, step):
		samples.append(img.get_pixel(0, y))
		samples.append(img.get_pixel(W - 1, y))

	var corners: Array = [
		img.get_pixel(0, 0),
		img.get_pixel(W - 1, 0),
		img.get_pixel(0, H - 1),
		img.get_pixel(W - 1, H - 1)
	]
	for _r in range(8):
		for c in corners:
			samples.append(c)

	if samples.size() == 0:
		return [Color.WHITE]

	var k: int = min(_K, samples.size())
	var centers: Array = []
	for i in range(k):
		var idx: int = (i * samples.size()) / k
		centers.append(samples[idx])

	for _iter in range(_KMEANS_ITER):
		var sums_r: Array = []
		var sums_g: Array = []
		var sums_b: Array = []
		var counts: Array = []
		for i in range(k):
			sums_r.append(0.0)
			sums_g.append(0.0)
			sums_b.append(0.0)
			counts.append(0)

		for sv in samples:
			var s: Color = sv
			var best_ci: int = 0
			var best_d: float = _dist(s, centers[0])
			for ci in range(1, k):
				var d: float = _dist(s, centers[ci])
				if d < best_d:
					best_d = d
					best_ci = ci
			sums_r[best_ci] = sums_r[best_ci] + s.r
			sums_g[best_ci] = sums_g[best_ci] + s.g
			sums_b[best_ci] = sums_b[best_ci] + s.b
			counts[best_ci] = counts[best_ci] + 1

		for ci in range(k):
			var cnt: int = counts[ci]
			if cnt > 0:
				centers[ci] = Color(sums_r[ci] / cnt, sums_g[ci] / cnt, sums_b[ci] / cnt, 1.0)

	return centers

static func _bfs_fill(img: Image, bg: Color, tol: float,
		W: int, H: int, removed: Array) -> void:
	var visited: Array = []
	visited.resize(W * H)
	visited.fill(false)

	for i in range(W * H):
		if removed[i]:
			visited[i] = true

	var queue: Array = []
	var head: int = 0

	for x in range(W):
		_try_seed(queue, visited, img, x, 0,     bg, tol, W)
		_try_seed(queue, visited, img, x, H - 1, bg, tol, W)
	for y in range(1, H - 1):
		_try_seed(queue, visited, img, 0,     y, bg, tol, W)
		_try_seed(queue, visited, img, W - 1, y, bg, tol, W)

	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		removed[p.y * W + p.x] = true

		var nx: int
		var ny: int

		nx = p.x - 1
		if nx >= 0:
			_try_seed(queue, visited, img, nx, p.y, bg, tol, W)
		nx = p.x + 1
		if nx < W:
			_try_seed(queue, visited, img, nx, p.y, bg, tol, W)
		ny = p.y - 1
		if ny >= 0:
			_try_seed(queue, visited, img, p.x, ny, bg, tol, W)
		ny = p.y + 1
		if ny < H:
			_try_seed(queue, visited, img, p.x, ny, bg, tol, W)

static func _try_seed(queue: Array, visited: Array, img: Image,
		x: int, y: int, bg: Color, tol: float, W: int) -> void:
	var idx: int = y * W + x
	if visited[idx]:
		return
	visited[idx] = true
	var c: Color = img.get_pixel(x, y)
	if c.a < 0.05 or _dist(c, bg) <= tol:
		queue.append(Vector2i(x, y))

static func _apply_matting(img: Image, removed: Array,
		W: int, H: int, feather: bool) -> void:
	for y in range(H):
		for x in range(W):
			if removed[y * W + x]:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	if not feather:
		return

	var dist_map: Array = []
	dist_map.resize(W * H)
	var BIG: int = W + H + 1

	for y in range(H):
		for x in range(W):
			if img.get_pixel(x, y).a < 0.01:
				dist_map[y * W + x] = 0
			else:
				dist_map[y * W + x] = BIG

	for y in range(H):
		for x in range(W):
			var idx: int = y * W + x
			if dist_map[idx] == 0:
				continue
			var best: int = dist_map[idx]
			if x > 0:
				var v: int = dist_map[idx - 1] + 1
				if v < best:
					best = v
			if y > 0:
				var v: int = dist_map[idx - W] + 1
				if v < best:
					best = v
			dist_map[idx] = best

	for y in range(H - 1, -1, -1):
		for x in range(W - 1, -1, -1):
			var idx: int = y * W + x
			if dist_map[idx] == 0:
				continue
			var best: int = dist_map[idx]
			if x < W - 1:
				var v: int = dist_map[idx + 1] + 1
				if v < best:
					best = v
			if y < H - 1:
				var v: int = dist_map[idx + W] + 1
				if v < best:
					best = v
			dist_map[idx] = best

	var snapshot: Image = img.duplicate()
	for y in range(H):
		for x in range(W):
			var c: Color = snapshot.get_pixel(x, y)
			if c.a < 0.01:
				continue
			var d: int = dist_map[y * W + x]
			if d > _MAT_RADIUS:
				continue
			var t: float = float(d) / float(_MAT_RADIUS)
			var smooth_t: float = t * t * (3.0 - 2.0 * t)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * smooth_t))

static func _dist(a: Color, b: Color) -> float:
	var dr: float = a.r - b.r
	var dg: float = a.g - b.g
	var db: float = a.b - b.b
	return sqrt(dr * dr * 0.299 + dg * dg * 0.587 + db * db * 0.114)

static func magic_wand_erase(image: Image, start_x: int, start_y: int, tolerance: float) -> Image:
	var img: Image = image.duplicate()
	img.convert(Image.FORMAT_RGBA8)

	var W: int = img.get_width()
	var H: int = img.get_height()
	if W < 2 or H < 2:
		return img
	if start_x < 0 or start_y < 0 or start_x >= W or start_y >= H:
		return img
		
	var bg: Color = img.get_pixel(start_x, start_y)
	if bg.a < 0.05:
		return img

	var removed: Array = []
	removed.resize(W * H)
	removed.fill(false)
	
	var visited: Array = []
	visited.resize(W * H)
	visited.fill(false)

	var queue: Array = []
	var head: int = 0
	
	_try_seed(queue, visited, img, start_x, start_y, bg, tolerance, W)

	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		removed[p.y * W + p.x] = true

		var nx: int = p.x - 1
		if nx >= 0: _try_seed(queue, visited, img, nx, p.y, bg, tolerance, W)
		nx = p.x + 1
		if nx < W: _try_seed(queue, visited, img, nx, p.y, bg, tolerance, W)
		var ny: int = p.y - 1
		if ny >= 0: _try_seed(queue, visited, img, p.x, ny, bg, tolerance, W)
		ny = p.y + 1
		if ny < H: _try_seed(queue, visited, img, p.x, ny, bg, tolerance, W)

	for y in range(H):
		for x in range(W):
			if removed[y * W + x]:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	return img

static func brush_erase(image: Image, center_x: int, center_y: int, radius: int) -> Image:
	image.convert(Image.FORMAT_RGBA8)
	var W: int = image.get_width()
	var H: int = image.get_height()

	for y in range(max(0, center_y - radius), min(H, center_y + radius + 1)):
		for x in range(max(0, center_x - radius), min(W, center_x + radius + 1)):
			var dx := x - center_x
			var dy := y - center_y
			if dx*dx + dy*dy <= radius*radius:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return image

static func brush_paint(image: Image, center_x: int, center_y: int, radius: int, color: Color) -> Image:
	image.convert(Image.FORMAT_RGBA8)
	var W: int = image.get_width()
	var H: int = image.get_height()

	for y in range(max(0, center_y - radius), min(H, center_y + radius + 1)):
		for x in range(max(0, center_x - radius), min(W, center_x + radius + 1)):
			var dx := x - center_x
			var dy := y - center_y
			if dx*dx + dy*dy <= radius*radius:
				image.set_pixel(x, y, color)
	return image

static func magic_wand_recolor(image: Image, start_x: int, start_y: int, new_color: Color, tolerance: float) -> Image:
	var img: Image = image.duplicate()
	img.convert(Image.FORMAT_RGBA8)

	var W: int = img.get_width()
	var H: int = img.get_height()
	if W < 2 or H < 2:
		return img
	if start_x < 0 or start_y < 0 or start_x >= W or start_y >= H:
		return img
		
	var bg: Color = img.get_pixel(start_x, start_y)
	if bg.a < 0.01:
		return img

	var removed: Array = []
	removed.resize(W * H)
	removed.fill(false)
	
	var visited: Array = []
	visited.resize(W * H)
	visited.fill(false)

	var queue: Array = []
	var head: int = 0
	
	_try_seed(queue, visited, img, start_x, start_y, bg, tolerance, W)

	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		removed[p.y * W + p.x] = true

		var nx: int = p.x - 1
		if nx >= 0: _try_seed(queue, visited, img, nx, p.y, bg, tolerance, W)
		nx = p.x + 1
		if nx < W: _try_seed(queue, visited, img, nx, p.y, bg, tolerance, W)
		var ny: int = p.y - 1
		if ny >= 0: _try_seed(queue, visited, img, p.x, ny, bg, tolerance, W)
		ny = p.y + 1
		if ny < H: _try_seed(queue, visited, img, p.x, ny, bg, tolerance, W)

	for y in range(H):
		for x in range(W):
			if removed[y * W + x]:
				var original := img.get_pixel(x, y)
				# Recolor while keeping original pixel's alpha!
				img.set_pixel(x, y, Color(new_color.r, new_color.g, new_color.b, original.a))

	return img

