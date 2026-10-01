@tool
extends RefCounted

## Loads fonts and renders text into temporary viewport images.
var _ui

func _init(host) -> void:
	_ui = host

func _load_font_file(path: String) -> void:
	var res = load(path)
	if res is Font:
		_ui._current_font = res
		_ui._current_font_path = path
	else:
		var ff = FontFile.new()
		var abs_p = ProjectSettings.globalize_path(path)
		var err = ff.load_dynamic_font(abs_p)
		if err == OK:
			_ui._current_font = ff
			_ui._current_font_path = path

	if _ui._font_path_label:
		_ui._font_path_label.text = path.get_file() if _ui._current_font else "Default Font"
		_ui._font_path_label.tooltip_text = path if _ui._current_font else "Default Font"

	_update_text_preview()

func _update_text_preview() -> void:
	if not _ui._canvas or not _ui._current_tex:
		return
	var txt = _ui._text_input.text if _ui._text_input else ""
	if txt.strip_edges() == "":
		_ui._canvas.frame_tex = null
		_ui._canvas.queue_redraw()
		return

	var f_size = int(_ui._text_font_size_spin.value) if _ui._text_font_size_spin else 24
	var col = _ui._text_color_picker.color if _ui._text_color_picker else Color.WHITE

	var img: Image = await _render_text_image(txt, _ui._current_font, f_size, col)
	if img and not img.is_empty():
		var tex = ImageTexture.create_from_image(img)
		var pivot_x: float = tex.get_width() / 2.0
		var pivot_y: float = tex.get_height() / 2.0

		var is_first_text_init: bool = (_ui._canvas.frame_tex == null or not _ui._canvas.frame_mode)
		if is_first_text_init:
			var base_img: Image = _ui._current_tex.get_image()
			if base_img:
				var center_x: float = base_img.get_width() / 2.0
				var center_y: float = base_img.get_height() / 2.0

				_ui._canvas.frame_pos = Vector2(center_x, center_y)
				_ui._canvas.frame_scale = Vector2.ONE
				_ui._canvas.frame_rotation = 0.0

				if _ui._stamp_pos_x: _ui._stamp_pos_x.set_value_no_signal(center_x)
				if _ui._stamp_pos_y: _ui._stamp_pos_y.set_value_no_signal(center_y)
				if _ui._stamp_scale_x: _ui._stamp_scale_x.set_value_no_signal(1.0)
				if _ui._stamp_scale_y: _ui._stamp_scale_y.set_value_no_signal(1.0)
				if _ui._stamp_rot: _ui._stamp_rot.set_value_no_signal(0.0)

		# ALWAYS keep frame_pivot aligned with the text texture center
		_ui._canvas.frame_pivot = Vector2(pivot_x, pivot_y)
		if _ui._stamp_pivot_x: _ui._stamp_pivot_x.set_value_no_signal(pivot_x)
		if _ui._stamp_pivot_y: _ui._stamp_pivot_y.set_value_no_signal(pivot_y)

		_ui._canvas.frame_tex = tex
		_ui._canvas.frame_mode = true
		_ui._canvas.queue_redraw()

## Renders text into an Image using TextLine (no SubViewport/await needed).
## Works in @tool context without a scene tree.

func _render_text_image(text: String, font: Font, font_size: int, color: Color) -> Image:
	if text.strip_edges() == "":
		return null

	var font_to_use: Font = font
	if font_to_use == null:
		font_to_use = ThemeDB.fallback_font
	if font_to_use == null:
		return null

	# Build a TextLine to measure the text precisely
	var tl = TextLine.new()
	tl.add_string(text, font_to_use, font_size)

	var text_w: float = tl.get_line_width()
	var ascent: float  = tl.get_line_ascent()
	var descent: float = tl.get_line_descent()
	var total_h: float = ascent + descent

	var pad = 8
	var w = int(ceil(text_w)) + pad * 2
	var h = int(ceil(total_h)) + pad * 2
	if w <= 4 or h <= 4:
		return null

	# Create a transparent image and draw the text onto it using a
	# temporary offscreen Control inside an editor SubViewport when available,
	# or fall back to a simple solid-color block when the scene tree is absent.
	var root: Window = _ui.get_tree().root if _ui.get_tree() else null
	if root == null:
		# Fallback: solid-color rectangle (no scene tree available)
		var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(color)
		return img

	# Full path: render via Label in a SubViewport
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font_to_use)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(w, h)
	label.size = Vector2(w, h)

	var vp = SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(w, h)
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(label)
	root.add_child(vp)
	await RenderingServer.frame_post_draw

	var tex = vp.get_texture()
	var img: Image = null
	if tex:
		img = tex.get_image()
	root.remove_child(vp)
	vp.free()
	return img
