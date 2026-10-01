@tool
extends RefCounted

## Coordinates pixel editing, persistence and texture publication.
var _ui

func _init(host) -> void:
	_ui = host

func _on_resize_image_requested(new_w: int, new_h: int, interp_mode: int, scale_slices: bool) -> void:
	if not _ui._current_tex or _ui._current_tex_path.is_empty() or not _ui._canvas:
		return
	var base_img: Image = _ui._current_tex.get_image()
	if not base_img or base_img.is_empty():
		return

	var old_w: int = base_img.get_width()
	var old_h: int = base_img.get_height()
	if old_w == new_w and old_h == new_h:
		return

	_ui._push_image_state()
	_ensure_edited_path()

	var resized_img = base_img.duplicate()
	resized_img.resize(new_w, new_h, interp_mode)

	if scale_slices and not _ui._canvas.rects.is_empty():
		var sx: float = float(new_w) / float(old_w)
		var sy: float = float(new_h) / float(old_h)
		for i in range(_ui._canvas.rects.size()):
			var r = _ui._canvas.rects[i]
			_ui._canvas.rects[i] = Rect2(r.position.x * sx, r.position.y * sy, r.size.x * sx, r.size.y * sy)

	var new_tex = ImageTexture.create_from_image(resized_img)
	_ui._current_tex = new_tex
	_ui._canvas.update_texture(new_tex)
	if _ui._preview_player:
		_ui._preview_player.sync_preview(new_tex, _ui._canvas.rects, _ui._canvas.selected_indices)
	_save_edited_texture()
	_ui._refresh_list()
	_ui._update_props()
	if _ui._preview_player:
		_ui._preview_player.sync_preview(_ui._current_tex, _ui._canvas.rects, _ui._canvas.selected_indices)
	_ui._canvas.queue_redraw()

func _flip_main_texture(flip_h: bool, flip_v: bool) -> void:
	if not _ui._current_tex or _ui._current_tex_path.is_empty():
		return
	_ui._push_image_state()
	_ensure_edited_path()
	var img: Image = _ui._current_tex.get_image()
	if not img:
		return
	
	if flip_h:
		img.flip_x()
	if flip_v:
		img.flip_y()
		
	var new_tex = ImageTexture.create_from_image(img)
	_ui._current_tex = new_tex
	_ui._canvas.update_texture(new_tex)
	if _ui._preview_player:
		_ui._preview_player.sync_preview(new_tex, _ui._canvas.rects, _ui._canvas.selected_indices)
	_save_edited_texture()
	
	# Flip all rects symmetrically
	var w = float(img.get_width())
	var h = float(img.get_height())
	
	for i in range(_ui._canvas.rects.size()):
		var r: Rect2 = _ui._canvas.rects[i]
		if flip_h:
			r.position.x = w - r.position.x - r.size.x
		if flip_v:
			r.position.y = h - r.position.y - r.size.y
		_ui._canvas.rects[i] = r
	
	_ui._canvas.queue_redraw()
	_ui._update_props()
	if _ui._preview_player:
		_ui._preview_player.sync_preview(_ui._current_tex, _ui._canvas.rects, _ui._canvas.selected_indices)

func _apply_stamp() -> void:
	if not _ui._current_tex or _ui._current_tex_path.is_empty() or not _ui._canvas or not _ui._canvas.frame_tex:
		return
	_ui._push_image_state()
	_ensure_edited_path()
	var base_img: Image = _ui._current_tex.get_image()
	var frame_img: Image = _ui._canvas.frame_tex.get_image()
	if not base_img or not frame_img:
		return
	
	var order_behind: bool = (_ui._order_opt.selected == 1) if _ui._order_opt else false

	var result = _ui._BgRemover.paste_frame_transformed(
		base_img,
		frame_img,
		_ui._canvas.frame_pos,
		_ui._canvas.frame_scale,
		_ui._canvas.frame_rotation,
		_ui._canvas.frame_pivot,
		_ui._canvas.frame_flip_h,
		_ui._canvas.frame_flip_v,
		order_behind
	)
	
	if result == null or result.is_empty():
		return
		
	_publish_image(result)
	_save_edited_texture()
	
	_ui._select_tool("")

func _on_brush_erase_clicked(img_pos: Vector2i) -> void:
	_ui._push_image_state()
	_ensure_edited_path()
	_do_brush_erase(img_pos)

func _on_brush_erase_dragged(img_pos: Vector2i) -> void:
	_do_brush_erase(img_pos)

func _on_brush_erase_released() -> void:
	_save_edited_texture()

func _do_brush_erase(img_pos: Vector2i) -> void:
	if not _ui._current_tex or _ui._current_tex_path.is_empty():
		return
	var src_img: Image = _ui._current_tex.get_image()
	if src_img == null or src_img.is_empty():
		return
	# Kopya üzerinde çalış — brush_erase in-place değiştirir
	var work_img = src_img.duplicate()
	var b_size: int = 8
	if _ui._brush_size_spin != null:
		b_size = int(_ui._brush_size_spin.value)
	var is_sq: bool = _ui._canvas.brush_is_square if _ui._canvas else false
	var result = _ui._BgRemover.brush_erase(work_img, img_pos.x, img_pos.y, b_size, is_sq)
	if result == null or result.is_empty():
		return

	_publish_image(result, true)

func _on_brush_paint_clicked(img_pos: Vector2i) -> void:
	_ui._push_image_state()
	_ensure_edited_path()
	_do_brush_paint(img_pos)

func _on_brush_paint_dragged(img_pos: Vector2i) -> void:
	_do_brush_paint(img_pos)

func _on_brush_paint_released() -> void:
	_save_edited_texture()

func _do_brush_paint(img_pos: Vector2i) -> void:
	if not _ui._current_tex or _ui._current_tex_path.is_empty():
		return
	var src_img: Image = _ui._current_tex.get_image()
	if src_img == null or src_img.is_empty():
		return
	# Kopya üzerinde çalış — brush_paint in-place değiştirir
	var work_img = src_img.duplicate()
	var b_size: int = 8
	if _ui._brush_size_spin != null:
		b_size = int(_ui._brush_size_spin.value)
	var col = _ui._color_picker.color if _ui._color_picker else Color.WHITE
	var is_sq: bool = _ui._canvas.brush_is_square if _ui._canvas else false
	var order_behind: bool = (_ui._order_opt.selected == 1) if _ui._order_opt else false
	var result = _ui._BgRemover.brush_paint(work_img, img_pos.x, img_pos.y, b_size, col, is_sq, order_behind)
	if result == null or result.is_empty():
		return

	_publish_image(result, true)

func _on_recolor_clicked(img_pos: Vector2i) -> void:
	if not _ui._current_tex or _ui._current_tex_path.is_empty():
		return
	var src_img: Image = _ui._current_tex.get_image()
	if src_img == null or src_img.is_empty():
		return
	_ui._push_image_state()
	_ensure_edited_path()
	var col = _ui._color_picker.color if _ui._color_picker else Color.WHITE
	var result = _ui._BgRemover.magic_wand_recolor(src_img, img_pos.x, img_pos.y, col, _ui._bg_tolerance)
	if result == null or result.is_empty():
		return
	var abs_out = ProjectSettings.globalize_path(_ui._current_tex_path)
	var err = result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG: " + abs_out)
		return
	_publish_image(result)

func _on_erase_clicked(img_pos: Vector2i) -> void:
	if not _ui._current_tex or _ui._current_tex_path.is_empty():
		return
	var src_img: Image = _ui._current_tex.get_image()
	if src_img == null or src_img.is_empty():
		return
	_ui._push_image_state()
	_ensure_edited_path()
	var result = _ui._BgRemover.magic_wand_erase(src_img, img_pos.x, img_pos.y, _ui._bg_tolerance)
	if result == null or result.is_empty():
		return

	var abs_out = ProjectSettings.globalize_path(_ui._current_tex_path)
	var err = result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG back to disk: " + abs_out)
		return

	_publish_image(result)

func _ensure_edited_path() -> void:
	if _ui._current_tex_path.is_empty():
		return
	var base_dir = _ui._current_tex_path.get_base_dir()
	var base_name = _ui._current_tex_path.get_file().get_basename()
	if not (base_name.ends_with("_nobg") or base_name.ends_with("_edited")):
		_ui._current_tex_path = base_dir + "/" + base_name + "_edited.png"
		_ui._path_label.text = base_name + "_edited.png"

func _save_edited_texture() -> bool:
	if not _ui._current_tex or _ui._current_tex_path.is_empty():
		return false
	var abs_out = ProjectSettings.globalize_path(_ui._current_tex_path)
	var err: Error = _ui._current_tex.get_image().save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG back to disk: " + abs_out)
	return err == OK

func _on_remove_bg() -> void:
	if _ui._current_tex_path.is_empty():
		push_error("SpriteSlicer: No texture path available.")
		return
	_ui._push_image_state()

	var abs_src: String = ProjectSettings.globalize_path(_ui._current_tex_path)
	var src_img: Image = _ui._current_tex.get_image() if _ui._current_tex else null
	if src_img == null or src_img.is_empty():
		push_error("SpriteSlicer: Could not load file: " + abs_src)
		return

	var result: Image = _ui._BgRemover.remove(src_img, _ui._bg_tolerance, true)
	if result == null or result.is_empty():
		push_error("SpriteSlicer: Background removal returned empty image.")
		return

	var base_dir: String = _ui._current_tex_path.get_base_dir()
	var base_name: String = _ui._current_tex_path.get_file().get_basename()
	var res_out: String = base_dir + "/" + base_name + "_nobg.png"
	var abs_out: String = ProjectSettings.globalize_path(res_out)
	var err: Error = result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save PNG: " + abs_out + " (error " + str(err) + ")")
		return

	var new_tex = ImageTexture.create_from_image(result)
	_ui._current_tex      = new_tex
	_ui._current_tex_path = res_out
	_ui._path_label.text  = base_name + "_nobg.png"
	_ui._canvas.update_texture(new_tex)
	if _ui._preview_player:
		_ui._preview_player.sync_preview(new_tex, _ui._canvas.rects, _ui._canvas.selected_indices)
	_ui._canvas.set_zoom(_ui._zoom)
	_ui._refresh_list()
	_ui._update_props()
	if _ui._preview_player:
		_ui._preview_player.sync_preview(_ui._current_tex, _ui._canvas.rects, _ui._canvas.selected_indices)

	if Engine.is_editor_hint():
		var fs = EditorInterface.get_resource_filesystem()
		if fs:
			fs.update_file(res_out)

func _publish_image(image: Image, reuse_texture: bool = false) -> void:
	var texture: ImageTexture
	if reuse_texture and _ui._current_tex is ImageTexture:
		var current: ImageTexture = _ui._current_tex
		if current.get_width() == image.get_width() and current.get_height() == image.get_height() and current.get_format() == image.get_format():
			current.update(image)
			texture = current
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	_ui._current_tex = texture
	_ui._canvas.update_texture(texture)
	if _ui._preview_player:
		_ui._preview_player.sync_preview(texture, _ui._canvas.rects, _ui._canvas.selected_indices)
