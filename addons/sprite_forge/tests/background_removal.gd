extends SceneTree

const Remover = preload("res://addons/sprite_forge/bg_remover.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var transparent := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	transparent.fill(Color(0, 0, 0, 0))
	transparent.fill_rect(Rect2i(4, 4, 8, 8), Color.BLACK)
	var original := transparent.get_data()
	var result: Image = Remover.remove(transparent, 0.18, true)
	check(result.get_data() == original, "Already-transparent black sprite was changed")
	check(transparent.get_data() == original, "Input image was mutated")

	var white := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	white.fill_rect(Rect2i(4, 4, 8, 8), Color.RED)
	result = Remover.remove(white, 0.05, false)
	check(result.get_pixel(0, 0).a == 0.0, "White background remains")
	check(result.get_pixel(4, 4) == Color.RED, "Hard edge altered foreground")
	check(result.get_pixel(8, 8) == Color.RED, "Foreground center was erased")

	var mixed := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	mixed.fill(Color.WHITE)
	mixed.fill_rect(Rect2i(8, 0, 8, 1), Color(0.6, 0.6, 0.6))
	mixed.fill_rect(Rect2i(8, 4, 4, 4), Color(0.6, 0.6, 0.6))
	mixed.fill_rect(Rect2i(3, 9, 4, 4), Color.RED)
	result = Remover.remove(mixed, 0.01, false)
	check(result.get_pixel(9, 5).a == 0.0, "Background colors cannot traverse previously removed regions")
	check(result.get_pixel(4, 10).a == 1.0, "Mixed background erased foreground")

	var ring := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	ring.fill(Color.WHITE)
	ring.fill_rect(Rect2i(3, 3, 10, 10), Color.BLACK)
	ring.fill_rect(Rect2i(6, 6, 4, 4), Color.WHITE)
	result = Remover.remove(ring, 0.05, false)
	check(result.get_pixel(0, 0).a == 0.0, "Ring outer background remains")
	check(result.get_pixel(7, 7).a == 1.0, "Enclosed foreground highlight was erased")

	var antialias := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	antialias.fill(Color.WHITE)
	antialias.fill_rect(Rect2i(3, 3, 10, 10), Color.RED)
	antialias.set_pixel(8, 8, Color(0, 0, 0, 0))
	result = Remover.remove(antialias, 0.05, true)
	check(result.get_pixel(8, 7).a == 1.0, "Feather eroded a pre-existing transparent hole")
	check(result.get_pixel(3, 4).a < 1.0, "Feather did not soften a newly removed edge")

	var thin := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	thin.fill(Color.WHITE)
	result = Remover.remove(thin, 0.05, false)
	check(result.get_pixel(0, 1).a == 0.0, "Single-column image was not processed")
	check(Remover.remove(null) == null, "Null image was not handled")
	check(Remover.remove(Image.new()) == null, "Empty image was not handled")
	_test_span_connectivity()
	print("Background removal tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
func _test_span_connectivity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73142
	for trial in range(80):
		var width := rng.randi_range(1, 25)
		var height := rng.randi_range(1, 25)
		var mask := PackedByteArray()
		mask.resize(width * height)
		for i in range(mask.size()):
			mask[i] = 1 if rng.randf() > 0.35 else 0
		var expected := PackedByteArray()
		expected.resize(mask.size())
		var queue: Array[Vector2i] = []
		for y in range(height):
			for x in range(width):
				if (x == 0 or y == 0 or x == width - 1 or y == height - 1) and mask[y * width + x] == 1:
					expected[y * width + x] = 2
					queue.append(Vector2i(x, y))
		var head := 0
		while head < queue.size():
			var point := queue[head]
			head += 1
			for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = point + delta
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
					continue
				var index := neighbor.y * width + neighbor.x
				if mask[index] == 1 and expected[index] == 0:
					expected[index] = 2
					queue.append(neighbor)
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		var optimized = load("res://addons/sprite_forge/background_removal.gd")
		var actual: PackedByteArray = optimized._fill_spans(image.get_data(), mask.duplicate(), width, height)
		check(actual == expected, "Scanline connectivity differs from BFS in trial %d" % trial)
