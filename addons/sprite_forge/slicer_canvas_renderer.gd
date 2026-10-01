@tool
extends RefCounted

## Draws canvas overlays and frame gizmos during the host draw callback.
var _canvas

func _init(host) -> void:
	_canvas = host

func _draw() -> void:
	# Cached checkerboard background
	_draw_checkerboard()

	if not _canvas.texture:
		return

	# If order_behind is true, draw frame texture underneath main texture
	if _canvas.order_behind and _canvas.frame_mode and _canvas.frame_tex:
		_draw_frame_texture()

	# Draw main texture (scaled by zoom)
	var tex_size = Vector2(_canvas.texture.get_width(), _canvas.texture.get_height()) * _canvas.zoom
	_canvas.draw_texture_rect(_canvas.texture, Rect2(Vector2.ZERO, tex_size), false)

	# If order_behind is false, draw frame texture on top of main texture
	if not _canvas.order_behind and _canvas.frame_mode and _canvas.frame_tex:
		_draw_frame_texture()

	# Draw grid snap visual helpers if active
	if _canvas.snap_to_grid:
		var tex_w = _canvas.texture.get_width()
		var tex_h = _canvas.texture.get_height()
		var grid_color = Color(1.0, 1.0, 1.0, 0.12)
		var sw = float(_canvas.snap_w)
		var sh = float(_canvas.snap_h)
		var x_pos = sw
		while x_pos < float(tex_w):
			_canvas.draw_line(Vector2(x_pos, 0) * _canvas.zoom, Vector2(x_pos, tex_h) * _canvas.zoom, grid_color, 1.0)
			x_pos += sw
		var y_pos = sh
		while y_pos < float(tex_h):
			_canvas.draw_line(Vector2(0, y_pos) * _canvas.zoom, Vector2(tex_w, y_pos) * _canvas.zoom, grid_color, 1.0)
			y_pos += sh

	# Draw slices (font fetched once)
	var font = _canvas.get_theme_font("font")
	
	# Viewport culling optimization
	var has_vis_rect = false
	var vis_rect = Rect2()
	var parent = _canvas.get_parent()
	if parent is ScrollContainer:
		var sc = parent as ScrollContainer
		vis_rect = Rect2(sc.scroll_horizontal, sc.scroll_vertical, sc.size.x, sc.size.y)
		# Expand by a margin to prevent popping when scrolling fast
		vis_rect = vis_rect.grow(100.0)
		has_vis_rect = true

	for i in range(_canvas.rects.size()):
		if has_vis_rect:
			var sr: Rect2 = _canvas._s(_canvas.rects[i])
			if not vis_rect.intersects(sr):
				continue
		_draw_slice(i, font)

	# Drag selection box preview
	if _canvas._selecting:
		var sel_rect = Rect2(_canvas._select_p1 * _canvas.zoom, (_canvas._select_p2 - _canvas._select_p1) * _canvas.zoom)
		_canvas.draw_rect(sel_rect, Color(0.2, 0.6, 1.0, 0.15), true)
		_canvas.draw_rect(sel_rect, Color(0.3, 0.7, 1.0, 0.8), false, 1.5)

	# Drag creation box preview
	if _canvas._creating:
		var preview = Rect2(_canvas._create_p1, _canvas._create_p2 - _canvas._create_p1).abs()
		var sr: Rect2 = _canvas._s(preview)
		_canvas.draw_rect(sr, Color(0.3, 0.8, 1.0, 0.18), true)
		_canvas.draw_rect(sr, Color(0.3, 0.8, 1.0, 0.9), false, 1.5)

	# Brush hover indicator
	if (_canvas.brush_erase_mode or _canvas.paint_mode) and _canvas.is_hovering:
		var rad: float = float(_canvas.brush_size) * _canvas.zoom
		var col = _canvas.paint_color if _canvas.paint_mode else Color(1.0, 0.3, 0.3, 0.75)
		col.a = 0.8
		if _canvas.brush_is_square:
			var size_val = rad * 2.0
			var rect = Rect2(_canvas.hover_mouse_pos - Vector2(rad, rad), Vector2(size_val, size_val))
			_canvas.draw_rect(rect, col, false, 1.5)
		else:
			_canvas.draw_arc(_canvas.hover_mouse_pos, rad, 0.0, TAU, 32, col, 1.5)

	# Draw magic wand preview mask
	if (_canvas.erase_mode or _canvas.recolor_mode) and _canvas.is_hovering and _canvas._preview_mask_tex:
		var overlay_size = Vector2(_canvas.texture.get_width(), _canvas.texture.get_height()) * _canvas.zoom
		_canvas.draw_texture_rect(_canvas._preview_mask_tex, Rect2(Vector2.ZERO, overlay_size), false)

	# Draw frame gizmo handles
	if _canvas.frame_mode and _canvas.frame_tex:
		_draw_frame_gizmo()

func _get_frame_transform_screen() -> Transform2D:
	var t = Transform2D()
	var zscale = _canvas.frame_scale * _canvas.zoom
	if _canvas.frame_flip_h: zscale.x *= -1.0
	if _canvas.frame_flip_v: zscale.y *= -1.0
	t.x = Vector2(cos(_canvas.frame_rotation), sin(_canvas.frame_rotation)) * zscale.x
	t.y = Vector2(-sin(_canvas.frame_rotation), cos(_canvas.frame_rotation)) * zscale.y
	t.origin = (_canvas.frame_pos * _canvas.zoom) - (t.x * _canvas.frame_pivot.x + t.y * _canvas.frame_pivot.y)
	return t

func _get_frame_corners_screen() -> Dictionary:
	if not _canvas.frame_tex:
		return {}
	var xform = _get_frame_transform_screen()
	var w = float(_canvas.frame_tex.get_width())
	var h = float(_canvas.frame_tex.get_height())
	var center_s = xform * Vector2(w * 0.5, h * 0.5)
	var top_mid = xform * Vector2(w * 0.5, 0.0)
	var rot_handle = xform * Vector2(w * 0.5, -32.0 / (_canvas.frame_scale.y * _canvas.zoom))
	return {
		"tl": xform * Vector2(0, 0),
		"tr": xform * Vector2(w, 0),
		"bl": xform * Vector2(0, h),
		"br": xform * Vector2(w, h),
		"center": center_s,
		"top_mid": top_mid,
		"rot_handle": rot_handle
	}

func _draw_frame_texture() -> void:
	var draw_pos = _canvas.frame_pos * _canvas.zoom
	var draw_scale = _canvas.frame_scale * _canvas.zoom
	if _canvas.frame_flip_h: draw_scale.x *= -1.0
	if _canvas.frame_flip_v: draw_scale.y *= -1.0
	_canvas.draw_set_transform(draw_pos, _canvas.frame_rotation, draw_scale)
	_canvas.draw_texture(_canvas.frame_tex, -_canvas.frame_pivot, Color(1.0, 1.0, 1.0, 0.75))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_frame_gizmo() -> void:
	if not _canvas.frame_tex:
		return

	var w = float(_canvas.frame_tex.get_width())
	var h = float(_canvas.frame_tex.get_height())
	var draw_pos = _canvas.frame_pos * _canvas.zoom
	var draw_scale = _canvas.frame_scale * _canvas.zoom
	if _canvas.frame_flip_h: draw_scale.x *= -1.0
	if _canvas.frame_flip_v: draw_scale.y *= -1.0
	var eff_scale = draw_scale.abs()

	# Apply exact same GPU matrix as _draw_frame_texture()
	_canvas.draw_set_transform(draw_pos, _canvas.frame_rotation, draw_scale)

	# Local rectangle corners relative to pivot
	var tl: Vector2 = -_canvas.frame_pivot
	var tr: Vector2 = -_canvas.frame_pivot + Vector2(w, 0.0)
	var br: Vector2 = -_canvas.frame_pivot + Vector2(w, h)
	var bl: Vector2 = -_canvas.frame_pivot + Vector2(0.0, h)

	var poly = PackedVector2Array([tl, tr, br, bl])
	var line_w: float = 2.0 / max(0.001, (eff_scale.x + eff_scale.y) * 0.5)
	var shadow_w: float = 3.5 / max(0.001, (eff_scale.x + eff_scale.y) * 0.5)

	# High contrast bounding box & fill
	_canvas.draw_polyline(poly + PackedVector2Array([tl]), Color(0.0, 0.0, 0.0, 0.95), shadow_w)
	_canvas.draw_polyline(poly + PackedVector2Array([tl]), Color(0.1, 0.85, 1.0, 1.0), line_w)
	_canvas.draw_colored_polygon(poly, Color(0.1, 0.75, 1.0, 0.12))

	# 4 Corner scale handles
	var handle_r_avg: float = 7.0 / max(0.001, (eff_scale.x + eff_scale.y) * 0.5)
	for cp in [tl, tr, bl, br]:
		_canvas.draw_circle(cp, handle_r_avg, Color(0.1, 0.85, 1.0))
		_canvas.draw_arc(cp, handle_r_avg, 0.0, TAU, 20, Color.WHITE, line_w)

	# Rotation handle
	var top_mid: Vector2 = -_canvas.frame_pivot + Vector2(w * 0.5, 0.0)
	var rot_off_y: float = -32.0 / max(0.001, eff_scale.y)
	var rot_handle: Vector2 = top_mid + Vector2(0.0, rot_off_y)
	var rot_r_avg: float = 9.0 / max(0.001, (eff_scale.x + eff_scale.y) * 0.5)

	_canvas.draw_line(top_mid, rot_handle, Color(1.0, 0.75, 0.1, 0.9), line_w * 1.2)
	_canvas.draw_circle(rot_handle, rot_r_avg, Color(1.0, 0.55, 0.0, 0.95))
	_canvas.draw_arc(rot_handle, rot_r_avg, 0.0, TAU, 24, Color.WHITE, line_w * 1.2)

	# ↻ Icon inside rotation handle
	var arc_r: float = rot_r_avg * 0.5
	_canvas.draw_arc(rot_handle, arc_r, -0.6 * PI, 1.1 * PI, 16, Color.WHITE, line_w * 1.2)
	var tip_angle: float = 1.1 * PI
	var tip_pos: Vector2 = rot_handle + Vector2(cos(tip_angle), sin(tip_angle)) * arc_r
	var arrow_p1: Vector2 = tip_pos + Vector2(3.0 / eff_scale.x, -2.0 / eff_scale.y)
	var arrow_p2: Vector2 = tip_pos + Vector2(-1.0 / eff_scale.x, 3.0 / eff_scale.y)
	_canvas.draw_line(tip_pos, arrow_p1, Color.WHITE, line_w * 1.2)
	_canvas.draw_line(tip_pos, arrow_p2, Color.WHITE, line_w * 1.2)

	# Pivot marker at center
	_canvas.draw_circle(Vector2.ZERO, 4.0 / max(0.001, (eff_scale.x + eff_scale.y) * 0.5), Color(1.0, 0.3, 0.3, 0.9))

	# Restore default transform
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_checkerboard() -> void:
	if _canvas._checker_tex == null:
		var cell: int = 8
		var img = Image.create(cell * 2, cell * 2, false, Image.FORMAT_RGB8)
		var c0 = Color(0.22, 0.22, 0.22)
		var c1 = Color(0.30, 0.30, 0.30)
		for y in range(cell * 2):
			for x in range(cell * 2):
				var is_c0: bool = ((x < cell) and (y < cell)) or ((x >= cell) and (y >= cell))
				img.set_pixel(x, y, c0 if is_c0 else c1)
		_canvas._checker_tex = ImageTexture.create_from_image(img)
	
	_canvas.draw_texture_rect(_canvas._checker_tex, Rect2(Vector2.ZERO, _canvas.size), true)

func _draw_slice(i: int, font: Font) -> void:
	var sr: Rect2 = _canvas._s(_canvas.rects[i])
	var is_sel = _canvas._selected_set.has(i)
	var is_locked = i < _canvas.locked_states.size() and _canvas.locked_states[i]

	# Pre-defined color constants to avoid repeated Color literal allocations
	const COL_SEL_LOCKED_FILL  := Color(0.60, 0.60, 0.60, 0.15)
	const COL_SEL_LOCKED_BORDER:= Color(0.55, 0.55, 0.55, 1.00)
	const COL_SEL_FILL         := Color(0.15, 1.00, 0.25, 0.20)
	const COL_SEL_BORDER       := Color(0.10, 1.00, 0.20, 1.00)
	const COL_HANDLE_RED       := Color(1.0, 0.2, 0.2)
	const COL_NORM_LOCKED_FILL := Color(0.50, 0.50, 0.50, 0.08)
	const COL_NORM_LOCKED_BDR  := Color(0.50, 0.50, 0.50, 0.65)
	const COL_NORM_FILL        := Color(1.00, 0.85, 0.00, 0.12)
	const COL_NORM_BORDER      := Color(1.00, 0.85, 0.00, 0.90)

	if is_sel:
		if is_locked:
			_canvas.draw_rect(sr, COL_SEL_LOCKED_FILL, true)
			_canvas.draw_rect(sr, COL_SEL_LOCKED_BORDER, false, 2.0)
		else:
			_canvas.draw_rect(sr, COL_SEL_FILL, true)
			_canvas.draw_rect(sr, COL_SEL_BORDER, false, 2.0)
			
			# Show handles only when exactly one slice is selected
			if _canvas.selected_indices.size() == 1:
				var corners = [
					sr.position,
					Vector2(sr.end.x, sr.position.y),
					Vector2(sr.position.x, sr.end.y),
					sr.end
				]
				for cp in corners:
					_canvas.draw_circle(cp, _canvas.HANDLE_R, COL_HANDLE_RED)
					_canvas.draw_arc(cp, _canvas.HANDLE_R, 0.0, TAU, 20, Color.WHITE, 1.5)
	else:
		if is_locked:
			_canvas.draw_rect(sr, COL_NORM_LOCKED_FILL, true)
			_canvas.draw_rect(sr, COL_NORM_LOCKED_BDR, false, 1.5)
		else:
			_canvas.draw_rect(sr, COL_NORM_FILL, true)
			_canvas.draw_rect(sr, COL_NORM_BORDER, false, 1.5)

	var label_col = Color(0.5, 0.5, 0.5) if is_locked else (Color(0.1, 1.0, 0.2) if is_sel else Color(1.0, 0.9, 0.1))
	var label_txt = "L " + str(i) if is_locked else str(i)
	_canvas.draw_string(font, sr.position + Vector2(3, 13), label_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_col)

# --- Input handling ---
