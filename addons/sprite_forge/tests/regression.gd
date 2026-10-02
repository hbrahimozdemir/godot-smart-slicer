extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	DirAccess.make_dir_recursive_absolute("user://spriteforge-tests")
	var ui = load("res://addons/sprite_forge/slicer_ui.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var path := "user://spriteforge-tests/source.jpg"
	check(image.save_jpg(path) == OK, "Fixture JPG could not be saved")
	var original_bytes := FileAccess.get_file_as_bytes(path)
	ui._current_tex = ImageTexture.create_from_image(image)
	ui._current_tex_path = path
	ui._canvas.load_texture(ui._current_tex)
	var rects: Array[Rect2] = [Rect2(0, 0, 8, 8)]
	ui._canvas.set_rects(rects)
	ui._canvas.slice_names[0] = "hero"
	ui._canvas.slice_materials[0] = "res://example.tres"
	ui._canvas.locked_states[0] = true
	ui._canvas.select_rect(0)
	ui._preview_player.sync_preview(ui._current_tex, rects, [0])
	ui._color_picker.color = Color.BLUE
	ui._do_brush_paint(Vector2i(2, 2))
	check(ui._preview_player.current_tex == ui._current_tex, "Paint did not sync preview")
	ui._current_tex = ImageTexture.create_from_image(image)
	ui._canvas.update_texture(ui._current_tex)
	ui._push_image_state()
	var edited := image.duplicate()
	edited.fill(Color.GREEN)
	ui._current_tex = ImageTexture.create_from_image(edited)
	ui._current_tex_path = "user://spriteforge-tests/source_edited.png"
	ui._canvas.update_texture(ui._current_tex)
	ui._undo()
	check(ui._canvas.slice_names == ["hero"], "Undo lost slice names")
	check(ui._canvas.slice_materials == ["res://example.tres"], "Undo lost materials")
	check(ui._canvas.locked_states == [true], "Undo lost locks")
	check(ui._canvas.selected_indices == [0], "Undo lost selection")
	check(ui._canvas._selected_set.has(0), "Undo selection cache is stale")
	check(ui._current_tex.get_image().get_pixel(0, 0).r > 0.9, "Undo failed to restore pixels")
	check(FileAccess.get_file_as_bytes(path) == original_bytes, "Undo changed source JPG")
	ui._redo()
	check(ui._current_tex.get_image().get_pixel(0, 0).g > 0.9, "Redo failed to restore pixels")
	check(ui._canvas.slice_names == ["hero"], "Redo lost metadata")
	ui._undo()
	ui._canvas.slice_materials[0] = ""
	ui._chk_png.button_pressed = true
	ui._chk_atlas.button_pressed = true
	ui._chk_spriteframes.button_pressed = true
	ui._chk_subfolder.button_pressed = false
	ui._chk_auto_unique.button_pressed = false
	ui._on_extract(true)
	check(FileAccess.get_file_as_bytes(path) == original_bytes, "Export changed source JPG")
	check(FileAccess.file_exists("user://spriteforge-tests/hero.png"), "Selected PNG export failed")
	var atlas = load("user://spriteforge-tests/hero.tres")
	check(atlas is AtlasTexture, "Atlas export failed")
	if atlas is AtlasTexture:
		check(atlas.atlas.get_image().get_pixel(0, 0).r > 0.9, "Atlas contains stale pixels")
	var base := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	base.fill(Color.RED)
	var stamp := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	stamp.fill(Color.BLUE)
	var remover = load("res://addons/sprite_forge/bg_remover.gd")
	var result: Image = remover.paste_stamp_transformed(base, stamp, Vector2.ZERO, Vector2.ONE, 0.0, Vector2.ZERO, true)
	check(result.get_pixel(0, 0).r > 0.9, "Behind stamp overwrote foreground")
	# Exercise the collaborators through the original facade callbacks.
	var sidebar = ui.find_child("SidebarScroll", true, false)
	check(sidebar is ScrollContainer, "Sidebar scroll container missing")
	if sidebar is ScrollContainer:
		check(sidebar.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "Sidebar scrollbar is not always visible")
	ui._history.clear()
	ui._canvas.locked_states[0] = false
	ui._canvas.select_rect(0)
	ui._canvas._duplicate_selected_rects()
	check(ui._canvas.rects.size() == 2, "Duplicate action failed")
	check(ui._canvas.slice_names[1] == "hero_copy", "Duplicate lost name")
	ui._undo()
	check(ui._canvas.rects.size() == 1, "Slice undo failed")
	ui._redo()
	check(ui._canvas.rects.size() == 2, "Slice redo failed")
	ui._canvas.selected_indices = [0, 1]
	ui._canvas._emit_selection_changed()
	ui._canvas._merge_selected_rects()
	check(ui._canvas.rects.size() == 1, "Merge action failed")
	ui._undo()
	check(ui._canvas.rects.size() == 2, "Merge undo failed")
	ui._canvas.select_rect(1)
	ui._canvas._delete_selected_rects()
	check(ui._canvas.rects.size() == 1, "Delete action failed")
	ui._undo()
	check(ui._canvas.rects.size() == 2, "Delete undo failed")
	ui._canvas._recalculate_wand_preview(Vector2i.ZERO)
	check(not ui._canvas.preview_mask.is_empty(), "Wand preview failed")
	ui._color_picker.color = Color.BLUE
	ui._do_brush_paint(Vector2i(2, 2))
	var brush_texture = ui._current_tex
	ui._do_brush_paint(Vector2i(3, 3))
	check(ui._current_tex == brush_texture, "Brush texture was reallocated")
	ui._canvas.snap_to_grid = true
	ui._canvas.frame_tex = ImageTexture.create_from_image(stamp)
	ui._canvas.frame_mode = true
	ui._canvas.frame_scale = Vector2.ONE
	ui._canvas.queue_redraw()
	await process_frame
	await process_frame
	check(ui._canvas._get_frame_corners_screen().size() > 0, "Frame geometry failed")
	ui._on_resize_image_requested(32, 32, Image.INTERPOLATE_NEAREST, true)
	check(ui._current_tex.get_width() == 32, "Resize controller failed")
	ui._undo()
	check(ui._current_tex.get_width() == 16, "Resize undo failed")
	ui._flip_main_texture(true, false)
	ui._undo()
	check(ui._canvas.slice_names.size() == ui._canvas.rects.size(), "Flip undo broke slice arrays")
	var background_fixture := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	background_fixture.fill(Color.WHITE)
	background_fixture.fill_rect(Rect2i(4, 4, 8, 8), Color.RED)
	ui._current_tex = ImageTexture.create_from_image(background_fixture)
	ui._canvas.update_texture(ui._current_tex)
	var names_before_bg = ui._canvas.slice_names.duplicate()
	ui._on_remove_bg()
	check(ui._current_tex.get_image().get_pixel(0, 0).a == 0.0, "Remove BG controller did not publish the result")
	check(ui._preview_player.current_tex == ui._current_tex, "Remove BG preview is stale")
	check(ui._canvas.slice_names == names_before_bg, "Remove BG changed slice metadata")
	ui._undo()
	check(ui._current_tex.get_image().get_pixel(0, 0) == Color.WHITE, "Remove BG undo failed")
	check(ui._canvas.slice_names == names_before_bg, "Remove BG undo lost metadata")
	print("SpriteForge regression tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	ui.free()
	quit(0 if failures == 0 else 1)