@tool
extends RefCounted

## Edge-color estimation followed by one flood fill over raw RGBA bytes.
## Squared weighted RGB distance preserves the existing tolerance scale.
const MAX_COLORS := 4
const ITERATIONS := 12
const ALPHA_CUTOFF := 12
const FEATHER_RADIUS := 3

static func remove(image: Image, tolerance: float = 0.18, feather: bool = true) -> Image:
	if image == null or image.is_empty():
		return null
	var img: Image = image.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var width := img.get_width()
	var height := img.get_height()
	var raw := img.get_data()
	var centers := _edge_colors(raw, width, height)
	# Transparent border RGB is undefined and must never identify foreground colors.
	if centers.is_empty():
		return img
	var threshold := clampf(tolerance, 0.0, 1.0) * 255.0
	threshold *= threshold
	var eligible := _classify(raw, centers, threshold)
	var removed := _fill_spans(raw, eligible, width, height)
	_apply_mask(raw, removed, width, height, feather)
	img.set_data(width, height, false, Image.FORMAT_RGBA8, raw)
	return img

## Classify once. Flood filling subsequently reads bytes without color calculations.
static func _classify(raw: PackedByteArray, centers: PackedVector3Array, threshold: float) -> PackedByteArray:
	var eligible := PackedByteArray()
	eligible.resize(raw.size() / 4)
	for index in range(eligible.size()):
		var offset := index * 4
		if raw[offset + 3] <= ALPHA_CUTOFF:
			eligible[index] = 1
			continue
		var red: int = raw[offset]
		var green: int = raw[offset + 1]
		var blue: int = raw[offset + 2]
		for center in centers:
			var dr := red - center.x
			var dg := green - center.y
			var db := blue - center.z
			if dr * dr * 0.299 + dg * dg * 0.587 + db * db * 0.114 <= threshold:
				eligible[index] = 1
				break
	return eligible

## Scanline fill queues contiguous row spans instead of every background pixel.
## eligible: 0=foreground, 1=unvisited background, 2=queued, 3=filled.
static func _fill_spans(raw: PackedByteArray, eligible: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var removed := PackedByteArray()
	removed.resize(eligible.size())
	var queue := PackedInt32Array()
	for x in range(width):
		_queue_span(x, eligible, queue)
		_queue_span((height - 1) * width + x, eligible, queue)
	for y in range(1, height - 1):
		_queue_span(y * width, eligible, queue)
		_queue_span(y * width + width - 1, eligible, queue)
	var head := 0
	while head < queue.size():
		var seed: int = queue[head]
		head += 1
		if eligible[seed] == 3:
			continue
		var row := seed / width
		var start := seed
		var row_start := row * width
		var row_end := row_start + width
		while start > row_start and (eligible[start - 1] == 1 or eligible[start - 1] == 2):
			start -= 1
		var above_span := false
		var below_span := false
		var index := start
		while index < row_end and (eligible[index] == 1 or eligible[index] == 2):
			eligible[index] = 3
			removed[index] = 2 if raw[index * 4 + 3] > ALPHA_CUTOFF else 1
			if row > 0:
				var above := index - width
				var available := (eligible[above] == 1 or eligible[above] == 2)
				if available and not above_span:
					_queue_span(above, eligible, queue)
				above_span = available
			if row < height - 1:
				var below := index + width
				var available := (eligible[below] == 1 or eligible[below] == 2)
				if available and not below_span:
					_queue_span(below, eligible, queue)
				below_span = available
			index += 1
	return removed

static func _queue_span(index: int, eligible: PackedByteArray, queue: PackedInt32Array) -> void:
	if eligible[index] == 1:
		eligible[index] = 2
		queue.append(index)

static func _distance_squared(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	return delta.x * delta.x * 0.299 + delta.y * delta.y * 0.587 + delta.z * delta.z * 0.114

static func _sample(raw: PackedByteArray, index: int, samples: PackedVector3Array) -> void:
	var offset := index * 4
	if raw[offset + 3] > ALPHA_CUTOFF:
		samples.append(Vector3(raw[offset], raw[offset + 1], raw[offset + 2]))

static func _edge_colors(raw: PackedByteArray, width: int, height: int) -> PackedVector3Array:
	var samples := PackedVector3Array()
	# Bound sample work even for panoramic images.
	var step_x := maxi(1, width / 120)
	var step_y := maxi(1, height / 120)
	for x in range(0, width, step_x):
		_sample(raw, x, samples)
		_sample(raw, (height - 1) * width + x, samples)
	for y in range(0, height, step_y):
		_sample(raw, y * width, samples)
		_sample(raw, y * width + width - 1, samples)
	for repeat in range(8):
		for index in [0, width - 1, (height - 1) * width, width * height - 1]:
			_sample(raw, index, samples)
	var centers := PackedVector3Array()
	if samples.is_empty():
		return centers
	centers.append(samples[0])
	# Distinct farthest-first seeds avoid several identical centers on flat borders.
	while centers.size() < MAX_COLORS:
		var farthest := 0.0
		var candidate := samples[0]
		for sample in samples:
			var nearest := INF
			for center in centers:
				nearest = minf(nearest, _distance_squared(sample, center))
			if nearest > farthest:
				farthest = nearest
				candidate = sample
		if farthest < 0.001:
			break
		centers.append(candidate)
	for iteration in range(ITERATIONS):
		var sums := PackedVector3Array()
		sums.resize(centers.size())
		var counts := PackedInt32Array()
		counts.resize(centers.size())
		for sample in samples:
			var best := 0
			var distance := _distance_squared(sample, centers[0])
			for i in range(1, centers.size()):
				var current := _distance_squared(sample, centers[i])
				if current < distance:
					distance = current
					best = i
			sums[best] += sample
			counts[best] += 1
		var changed := false
		for i in range(centers.size()):
			if counts[i] > 0:
				var next := sums[i] / float(counts[i])
				changed = changed or _distance_squared(next, centers[i]) > 0.001
				centers[i] = next
		if not changed:
			break
	return centers

static func _apply_mask(raw: PackedByteArray, removed: PackedByteArray, width: int, height: int, feather: bool) -> void:
	for index in range(removed.size()):
		if removed[index] != 0:
			var offset := index * 4
			raw[offset] = 0
			raw[offset + 1] = 0
			raw[offset + 2] = 0
			raw[offset + 3] = 0
	if not feather:
		return
	# Distances beyond the feather radius do not need float precision or storage.
	var distance := PackedByteArray()
	distance.resize(removed.size())
	distance.fill(FEATHER_RADIUS + 1)
	for index in range(removed.size()):
		if removed[index] == 2:
			distance[index] = 0
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			if x > 0:
				distance[index] = mini(distance[index], distance[index - 1] + 1)
			if y > 0:
				distance[index] = mini(distance[index], distance[index - width] + 1)
	for y in range(height - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var index := y * width + x
			if x < width - 1:
				distance[index] = mini(distance[index], distance[index + 1] + 1)
			if y < height - 1:
				distance[index] = mini(distance[index], distance[index + width] + 1)
			if distance[index] > 0 and distance[index] < FEATHER_RADIUS:
				var t := float(distance[index]) / FEATHER_RADIUS
				var smooth_t := t * t * (3.0 - 2.0 * t)
				raw[index * 4 + 3] = int(raw[index * 4 + 3] * smooth_t)
