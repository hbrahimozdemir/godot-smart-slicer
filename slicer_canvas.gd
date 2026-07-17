@tool
extends Control

signal selection_changed(indices: Array)
signal rects_changed()
signal zoom_changed(new_zoom: float)
signal erase_clicked(img_pos: Vector2i)
signal brush_erase_clicked(img_pos: Vector2i)
signal brush_erase_dragged(img_pos: Vector2i)
signal brush_erase_released()
signal brush_paint_clicked(img_pos: Vector2i)
signal brush_paint_dragged(img_pos: Vector2i)
signal brush_paint_released()
signal recolor_clicked(img_pos: Vector2i)
signal stamp_pasted(img_pos: Vector2i, stamp_tex: Texture2D)
signal slice_action_started()

var texture: Texture2D = null
var rects: Array[Rect2] = []
var slice_names: Array[String] = []
var slice_materials: Array[String] = []
var selected_indices: Array = []
var locked_states: Array[bool] = []

var snap_to_grid: bool = false
var snap_w: int = 16
var snap_h: int = 16
var zoom: float = 1.0
var erase_mode: bool = false
var brush_erase_mode: bool = false
var paint_mode: bool = false
var recolor_mode: bool = false
var stamp_mode: bool = false
var stamp_tex: Texture2D = null
var paint_color: Color = Color.WHITE
var tolerance: float = 0.18
var preview_mask: Array[Vector2i] = []
var last_preview_pixel: Vector2i = Vector2i(-1, -1)
var _brush_erasing: bool = false
var _brush_painting: bool = false

var brush_size: int = 8
var hover_mouse_pos: Vector2 = Vector2.ZERO
var is_hovering: bool = false

# Checkerboard cache
var _checker_tex: ImageTexture = null
var _checker_size: Vector2i = Vector2i.ZERO

# Drag/Create state
var _dragging: bool = false
var _drag_mode: String = ""   # "move" | "create" | "tl" | "tr" | "bl" | "br"
var _drag_start_mouse_img: Vector2
var _drag_start_rects: Dictionary = {} # maps index (int) -> Rect2

# Create-preview (Right-click drag)
var _creating: bool = false
var _create_p1: Vector2 = Vector2.ZERO
var _create_p2: Vector2 = Vector2.ZERO
var _right_click_down_pos: Vector2 = Vector2.ZERO
var _right_dragged: bool = false

# Selection-preview (Left-click drag on empty space)
var _selecting: bool = false
var _select_p1: Vector2 = Vector2.ZERO
var _select_p2: Vector2 = Vector2.ZERO

var _panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_scroll: Vector2 = Vector2.ZERO

const HANDLE_R: float = 5.0

func _ready() -> void:
	focus_mode = FOCUS_CLICK

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		is_hovering = false
		preview_mask.clear()
		last_preview_pixel = Vector2i(-1, -1)
		queue_redraw()

func load_texture(tex: Texture2D) -> void:
	texture = tex
	rects.clear()
	slice_names.clear()
	slice_materials.clear()
	selected_indices.clear()
	locked_states.clear()
	_update_min_size()
	queue_redraw()

## Updates texture without resetting slice data (rects, names, locks).
func update_texture(tex: Texture2D) -> void:
	texture = tex
	_update_min_size()
	queue_redraw()

func set_rects(new_rects: Array[Rect2]) -> void:
	rects = new_rects.duplicate()
	slice_names.clear()
	slice_materials.clear()
	for i in range(rects.size()):
		slice_names.append("")
		slice_materials.append("")
	selected_indices.clear()
	locked_states.clear()
	locked_states.resize(rects.size())
	locked_states.fill(false)
	queue_redraw()

func select_rect(index: int) -> void:
	selected_indices = [index]
	queue_redraw()

func update_rect_at(index: int, r: Rect2) -> void:
	if index >= 0 and index < rects.size():
		rects[index] = r
		queue_redraw()

func set_zoom(z: float) -> void:
	zoom = clamp(z, 0.1, 8.0)
	_update_min_size()
	zoom_changed.emit(zoom)
	queue_redraw()

# --- Internal helpers ---

func _update_min_size() -> void:
	if texture:
		custom_minimum_size = Vector2(texture.get_width(), texture.get_height()) * zoom + Vector2(1, 1)
	else:
		custom_minimum_size = Vector2(256, 256)

func _s(r: Rect2) -> Rect2:
	return Rect2(r.position * zoom, r.size * zoom)

func _img(p: Vector2) -> Vector2:
	return p / zoom

func snap_point(pt: Vector2) -> Vector2:
	if not snap_to_grid:
		return pt
	var x: float = round(pt.x / float(snap_w)) * float(snap_w)
	var y: float = round(pt.y / float(snap_h)) * float(snap_h)
	return Vector2(x, y)

func _handle_at(pos: Vector2) -> String:
	if selected_indices.size() != 1:
		return ""
	var idx: int = selected_indices[0]
	if idx < 0 or idx >= rects.size():
		return ""
	if idx < locked_states.size() and locked_states[idx]:
		return ""
	var sr: Rect2 = _s(rects[idx])
	var corners := {
		"tl": sr.position,
		"tr": Vector2(sr.end.x,      sr.position.y),
		"bl": Vector2(sr.position.x, sr.end.y),
		"br": sr.end,
	}
	for name in corners:
		if pos.distance_to(corners[name]) <= HANDLE_R + 3.0:
			return name
	return ""

func _rect_at(pos: Vector2) -> int:
	for i in range(rects.size() - 1, -1, -1):
		if i < locked_states.size() and locked_states[i]:
			continue
		if _s(rects[i]).has_point(pos):
			return i
	return -1

# --- Drawing ---

func _draw() -> void:
	# Cached checkerboard background
	_draw_checkerboard()

	if not texture:
		return

	# Draw main texture (scaled by zoom)
	var tex_size := Vector2(texture.get_width(), texture.get_height()) * zoom
	draw_texture_rect(texture, Rect2(Vector2.ZERO, tex_size), false)

	# Draw grid snap visual helpers if active
	if snap_to_grid:
		var tex_w := texture.get_width()
		var tex_h := texture.get_height()
		var grid_color := Color(1.0, 1.0, 1.0, 0.12)
		var x_pos := float(snap_w)
		while x_pos < float(tex_w):
			draw_line(Vector2(x_pos, 0) * zoom, Vector2(x_pos, tex_h) * zoom, grid_color, 1.0)
			x_pos += float(snap_w)
		var y_pos := float(snap_h)
		while y_pos < float(tex_h):
			draw_line(Vector2(0, y_pos) * zoom, Vector2(tex_w, y_pos) * zoom, grid_color, 1.0)
			y_pos += float(snap_h)

	# Draw slices (font fetched once)
	var font := get_theme_font("font")
	for i in range(rects.size()):
		_draw_slice(i, font)

	# Drag selection box preview
	if _selecting:
		var sel_rect := Rect2(_select_p1 * zoom, (_select_p2 - _select_p1) * zoom)
		draw_rect(sel_rect, Color(0.2, 0.6, 1.0, 0.15), true)
		draw_rect(sel_rect, Color(0.3, 0.7, 1.0, 0.8), false, 1.5)

	# Drag creation box preview
	if _creating:
		var preview := Rect2(_create_p1, _create_p2 - _create_p1).abs()
		var sr: Rect2 = _s(preview)
		draw_rect(sr, Color(0.3, 0.8, 1.0, 0.18), true)
		draw_rect(sr, Color(0.3, 0.8, 1.0, 0.9), false, 1.5)

	# Brush hover indicator
	if (brush_erase_mode or paint_mode) and is_hovering:
		var rad: float = float(brush_size) * zoom
		var col := paint_color if paint_mode else Color(1.0, 0.3, 0.3, 0.75)
		col.a = 0.8
		draw_arc(hover_mouse_pos, rad, 0.0, TAU, 32, col, 1.5)

	# Draw magic wand preview mask
	if (erase_mode or recolor_mode) and is_hovering and not preview_mask.is_empty():
		var mask_color := Color(0.3, 0.7, 1.0, 0.4) if erase_mode else paint_color
		mask_color.a = 0.45
		var psz := Vector2(zoom, zoom)
		for p in preview_mask:
			draw_rect(Rect2(Vector2(p) * zoom, psz), mask_color)

	# Draw stamp preview
	if stamp_mode and stamp_tex and is_hovering:
		var sz := Vector2(stamp_tex.get_width(), stamp_tex.get_height()) * zoom
		var dest_pos := hover_mouse_pos - sz / 2.0
		draw_texture_rect(stamp_tex, Rect2(dest_pos, sz), false, Color(1.0, 1.0, 1.0, 0.6))

func _draw_checkerboard() -> void:
	if _checker_tex == null:
		var cell: int = 8
		var img := Image.create(cell * 2, cell * 2, false, Image.FORMAT_RGB8)
		var c0 := Color(0.22, 0.22, 0.22)
		var c1 := Color(0.30, 0.30, 0.30)
		for y in range(cell * 2):
			for x in range(cell * 2):
				var is_c0: bool = ((x < cell) and (y < cell)) or ((x >= cell) and (y >= cell))
				img.set_pixel(x, y, c0 if is_c0 else c1)
		_checker_tex = ImageTexture.create_from_image(img)
	
	draw_texture_rect(_checker_tex, Rect2(Vector2.ZERO, size), true)

func _draw_slice(i: int, font: Font) -> void:
	var sr: Rect2 = _s(rects[i])
	var is_sel := i in selected_indices
	var is_locked := i < locked_states.size() and locked_states[i]

	if is_sel:
		if is_locked:
			draw_rect(sr, Color(0.60, 0.60, 0.60, 0.15), true)
			draw_rect(sr, Color(0.55, 0.55, 0.55, 1.00), false, 2.0)
		else:
			draw_rect(sr, Color(0.15, 1.00, 0.25, 0.20), true)
			draw_rect(sr, Color(0.10, 1.00, 0.20, 1.00), false, 2.0)
			
			# Show handles only when exactly one slice is selected
			if selected_indices.size() == 1:
				var corners := [
					sr.position,
					Vector2(sr.end.x, sr.position.y),
					Vector2(sr.position.x, sr.end.y),
					sr.end
				]
				for cp in corners:
					draw_circle(cp, HANDLE_R, Color(1.0, 0.2, 0.2))
					draw_arc(cp, HANDLE_R, 0.0, TAU, 20, Color.WHITE, 1.5)
	else:
		if is_locked:
			draw_rect(sr, Color(0.50, 0.50, 0.50, 0.08), true)
			draw_rect(sr, Color(0.50, 0.50, 0.50, 0.65), false, 1.5)
		else:
			draw_rect(sr, Color(1.00, 0.85, 0.00, 0.12), true)
			draw_rect(sr, Color(1.00, 0.85, 0.00, 0.90), false, 1.5)

	var label_col := Color(0.5, 0.5, 0.5) if is_locked else (Color(0.1, 1.0, 0.2) if is_sel else Color(1.0, 0.9, 0.1))
	var label_txt := "L " + str(i) if is_locked else str(i)
	draw_string(font, sr.position + Vector2(3, 13), label_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_col)

# --- Input handling ---

func _gui_input(event: InputEvent) -> void:
	if not texture:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(zoom * 1.15)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(zoom / 1.15)
			accept_event()
			return

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_panning = true
				_pan_start_mouse = get_viewport().get_mouse_position()
				var parent = get_parent()
				if parent is ScrollContainer:
					_pan_start_scroll = Vector2(parent.scroll_horizontal, parent.scroll_vertical)
			else:
				_panning = false
			accept_event()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_lmb_down(event.position)
			else:
				_on_lmb_up(event.position)
			accept_event()
			return

		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_on_rmb_down(event.position)
			else:
				_on_rmb_up(event.position)
			accept_event()
			return

	elif event is InputEventMouseMotion:
		if _panning:
			var curr_mouse = get_viewport().get_mouse_position()
			var diff = curr_mouse - _pan_start_mouse
			var parent = get_parent()
			if parent is ScrollContainer:
				parent.scroll_horizontal = int(_pan_start_scroll.x - diff.x)
				parent.scroll_vertical = int(_pan_start_scroll.y - diff.y)
			accept_event()
			return

		_on_mouse_motion(event.position)
		if _dragging or _selecting:
			accept_event()
			return

func _input(event: InputEvent) -> void:
	if not visible or not texture:
		return
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		var vp := get_viewport()
		var focus_owner: Control = vp.gui_get_focus_owner() if vp else null
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return # Do not intercept text editing (like SpinBoxes)

		var is_mac: bool = OS.get_name() == "macOS"
		var is_ctrl: bool = key_event.ctrl_pressed or (is_mac and key_event.meta_pressed)

		# 1. Non-echo shortcuts (ignore echo)
		if not key_event.echo:
			# Delete selected
			var is_delete: bool = key_event.keycode == KEY_DELETE or (is_mac and key_event.keycode == KEY_BACKSPACE)
			if is_delete and not selected_indices.is_empty():
				_delete_selected_rects()
				get_viewport().set_input_as_handled()
				return

			# Duplicate selected (Ctrl + D)
			if is_ctrl and key_event.keycode == KEY_D and not selected_indices.is_empty():
				_duplicate_selected_rects()
				get_viewport().set_input_as_handled()
				return

			# Select All (Ctrl + A)
			if is_ctrl and key_event.keycode == KEY_A and not rects.is_empty():
				selected_indices.clear()
				for i in range(rects.size()):
					selected_indices.append(i)
				selection_changed.emit(selected_indices)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return

			# Deselect All (Escape)
			if key_event.keycode == KEY_ESCAPE:
				if not selected_indices.is_empty():
					selected_indices.clear()
					selection_changed.emit(selected_indices)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return

			# Lock/Unlock selected (L)
			if key_event.keycode == KEY_L and not selected_indices.is_empty():
				var any_unlocked := false
				for idx in selected_indices:
					if idx < locked_states.size() and not locked_states[idx]:
						any_unlocked = true
						break
				slice_action_started.emit()
				for idx in selected_indices:
					if idx < locked_states.size():
						locked_states[idx] = any_unlocked
				selection_changed.emit(selected_indices)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return

			# Merge selected (Ctrl + M)
			if is_ctrl and key_event.keycode == KEY_M and selected_indices.size() >= 2:
				_merge_selected_rects()
				get_viewport().set_input_as_handled()
				return

		# 2. Echo-allowed shortcuts (nudge and resize using Arrow keys)
		var is_arrow: bool = key_event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
		if is_arrow and not selected_indices.is_empty():
			# Do not nudge if another control like ItemList or OptionButton is focused
			if focus_owner is ItemList or focus_owner is OptionButton:
				return

			if not key_event.echo:
				slice_action_started.emit()

			var shift_pressed: bool = key_event.shift_pressed
			var nudge_amount := 8 if shift_pressed else 1
			
			var move_dir := Vector2.ZERO
			match key_event.keycode:
				KEY_LEFT: move_dir.x = -1
				KEY_RIGHT: move_dir.x = 1
				KEY_UP: move_dir.y = -1
				KEY_DOWN: move_dir.y = 1
				
			var tex_w := texture.get_width()
			var tex_h := texture.get_height()
			
			if key_event.alt_pressed:
				# Resize mode
				for idx in selected_indices:
					var r := rects[idx]
					var new_size := r.size + move_dir * nudge_amount
					# Clamp size
					if new_size.x < 2:
						new_size.x = 2
					if new_size.y < 2:
						new_size.y = 2
					# Clamp to texture bounds
					if r.position.x + new_size.x > tex_w:
						new_size.x = tex_w - r.position.x
					if r.position.y + new_size.y > tex_h:
						new_size.y = tex_h - r.position.y
						
					rects[idx] = Rect2(r.position, new_size)
			else:
				# Move mode
				for idx in selected_indices:
					var r := rects[idx]
					var new_pos := r.position + move_dir * nudge_amount
					# Clamp to texture bounds
					if new_pos.x + r.size.x > tex_w:
						new_pos.x = tex_w - r.size.x
					if new_pos.y + r.size.y > tex_h:
						new_pos.y = tex_h - r.size.y
					if new_pos.x < 0:
						new_pos.x = 0
					if new_pos.y < 0:
						new_pos.y = 0
						
					rects[idx] = Rect2(new_pos, r.size)
					
			rects_changed.emit()
			queue_redraw()
			get_viewport().set_input_as_handled()

func _on_lmb_down(pos: Vector2) -> void:
	grab_focus()
	if erase_mode:
		var img_p = _img(pos)
		erase_clicked.emit(Vector2i(img_p))
		return
		
	if recolor_mode:
		var img_p = _img(pos)
		recolor_clicked.emit(Vector2i(img_p))
		return

	if stamp_mode and stamp_tex:
		var img_p = _img(pos)
		stamp_pasted.emit(Vector2i(img_p), stamp_tex)
		return

	if brush_erase_mode:
		_brush_erasing = true
		brush_erase_clicked.emit(Vector2i(_img(pos)))
		return

	if paint_mode:
		_brush_painting = true
		brush_paint_clicked.emit(Vector2i(_img(pos)))
		return
		
	# 1. Check handles (only when exactly one slice is selected)
	var handle: String = _handle_at(pos)
	if handle != "" and selected_indices.size() == 1:
		slice_action_started.emit()
		_dragging = true
		_drag_mode = handle
		_drag_start_mouse_img = _img(pos)
		var idx: int = selected_indices[0]
		_drag_start_rects = { idx: rects[idx] }
		return

	# 2. Check if clicked inside any rect
	var clicked: int = _rect_at(pos)
	if clicked != -1:
		slice_action_started.emit()
		if not clicked in selected_indices:
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
				selected_indices.append(clicked)
			else:
				selected_indices = [clicked]
			selection_changed.emit(selected_indices)

		_dragging = true
		_drag_mode = "move"
		_drag_start_mouse_img = _img(pos)
		_drag_start_rects = {}
		for idx in selected_indices:
			_drag_start_rects[idx] = rects[idx]
		queue_redraw()
		return

	# 3. Clicked empty space -> start drag selection box
	_selecting = true
	_select_p1 = _img(pos)
	_select_p2 = _select_p1
	
	if not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
		selected_indices.clear()
		selection_changed.emit(selected_indices)
	queue_redraw()

func _on_lmb_up(pos: Vector2) -> void:
	if _brush_erasing:
		_brush_erasing = false
		brush_erase_released.emit()
		return
		
	if _brush_painting:
		_brush_painting = false
		brush_paint_released.emit()
		return
		
	if _selecting:
		_selecting = false
		var sel_rect := Rect2(_select_p1, _select_p2 - _select_p1).abs()
		
		# If it's a drag box selection
		if sel_rect.size.x >= 3 and sel_rect.size.y >= 3:
			var newly_selected := []
			for i in range(rects.size()):
				# Skip locked slices in box selection
				if i < locked_states.size() and locked_states[i]:
					continue
				if sel_rect.intersects(rects[i]):
					newly_selected.append(i)
					
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
				for idx in newly_selected:
					if not idx in selected_indices:
						selected_indices.append(idx)
			else:
				selected_indices = newly_selected
		else:
			# Single click on empty space -> clear selection
			if not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
				selected_indices.clear()
				
		selection_changed.emit(selected_indices)
		queue_redraw()
		
	elif _dragging:
		_dragging = false
		_drag_mode = ""
		_drag_start_rects.clear()

func _on_rmb_down(pos: Vector2) -> void:
	grab_focus()
	_right_click_down_pos = pos
	_right_dragged = false
	
	# Start drawing a new rect
	_dragging = true
	_drag_mode = "create"
	_creating = true
	_create_p1 = snap_point(_img(pos))
	_create_p2 = _create_p1
	queue_redraw()

func _on_rmb_up(pos: Vector2) -> void:
	if _creating:
		_creating = false
		_dragging = false
		
		if _right_dragged:
			# Dragged -> create the slice
			var new_rect := Rect2(_create_p1, _create_p2 - _create_p1).abs()
			if new_rect.size.x >= 2 and new_rect.size.y >= 2:
				slice_action_started.emit()
				rects.append(new_rect)
				slice_names.append("")
				slice_materials.append("")
				locked_states.append(false)
				selected_indices = [rects.size() - 1]
				selection_changed.emit(selected_indices)
				rects_changed.emit()
				
		queue_redraw()

func _on_mouse_motion(pos: Vector2) -> void:
	if brush_erase_mode or paint_mode or stamp_mode:
		hover_mouse_pos = pos
		is_hovering = true
		queue_redraw()
		
	if (erase_mode or recolor_mode) and texture:
		hover_mouse_pos = pos
		is_hovering = true
		var img_p := Vector2i(_img(pos))
		if img_p != last_preview_pixel:
			last_preview_pixel = img_p
			_recalculate_wand_preview(img_p)
			queue_redraw()

	if _brush_erasing:
		brush_erase_dragged.emit(Vector2i(_img(pos)))
		return

	if _brush_painting:
		brush_paint_dragged.emit(Vector2i(_img(pos)))
		return
		
	if _selecting:
		_select_p2 = _img(pos)
		queue_redraw()
		return

	if _creating:
		_create_p2 = snap_point(_img(pos))
		if pos.distance_to(_right_click_down_pos) > 5.0:
			_right_dragged = true
		queue_redraw()
		return

	if not _dragging:
		return

	var raw_d: Vector2 = _img(pos) - _drag_start_mouse_img

	if _drag_mode == "move":
		for idx in _drag_start_rects:
			var start_r: Rect2 = _drag_start_rects[idx]
			var new_pos = snap_point(start_r.position + raw_d)
			rects[idx] = Rect2(new_pos, start_r.size)
		rects_changed.emit()
		queue_redraw()
		
	elif _drag_mode == "tl" or _drag_mode == "tr" or _drag_mode == "bl" or _drag_mode == "br":
		if selected_indices.is_empty() or not selected_indices[0] in _drag_start_rects:
			return
		var idx: int = selected_indices[0]
		var rs: Rect2 = _drag_start_rects.get(idx, Rect2())
		var new_r: Rect2
		
		match _drag_mode:
			"tl":
				var p1 = snap_point(rs.position + raw_d)
				var p2 = rs.end
				new_r = Rect2(p1, p2 - p1).abs()
			"tr":
				var p1 = Vector2(rs.position.x, snap_point(Vector2(0, rs.position.y + raw_d.y)).y)
				var p2 = Vector2(snap_point(Vector2(rs.end.x + raw_d.x, 0)).x, rs.end.y)
				new_r = Rect2(p1, p2 - p1).abs()
			"bl":
				var p1 = Vector2(snap_point(Vector2(rs.position.x + raw_d.x, 0)).x, rs.position.y)
				var p2 = Vector2(rs.end.x, snap_point(Vector2(0, rs.end.y + raw_d.y)).y)
				new_r = Rect2(p1, p2 - p1).abs()
			"br":
				var p1 = rs.position
				var p2 = snap_point(rs.end + raw_d)
				new_r = Rect2(p1, p2 - p1).abs()
				
		rects[idx] = new_r
		rects_changed.emit()
		queue_redraw()

func _recalculate_wand_preview(img_p: Vector2i) -> void:
	preview_mask.clear()
	if not texture:
		return
	var img := texture.get_image()
	if not img or img.is_empty():
		return
	var W := img.get_width()
	var H := img.get_height()
	if img_p.x < 0 or img_p.y < 0 or img_p.x >= W or img_p.y >= H:
		return

	var bg := img.get_pixel(img_p.x, img_p.y)
	if bg.a < 0.01:
		return

	var visited := {}
	var queue := [img_p]
	var head := 0
	
	const MAX_PREVIEW = 8000
	
	while head < queue.size() and queue.size() < MAX_PREVIEW:
		var p: Vector2i = queue[head]
		head += 1
		
		var idx := p.y * W + p.x
		if idx in visited:
			continue
		visited[idx] = true
		preview_mask.append(p)
		
		# 4-way check
		var neighbors := [
			Vector2i(p.x - 1, p.y),
			Vector2i(p.x + 1, p.y),
			Vector2i(p.x, p.y - 1),
			Vector2i(p.x, p.y + 1)
		]
		for n in neighbors:
			if n.x >= 0 and n.x < W and n.y >= 0 and n.y < H:
				var n_idx: int = n.y * W + n.x
				if not n_idx in visited:
					var c: Color = img.get_pixel(n.x, n.y)
					var dr: float = c.r - bg.r
					var dg: float = c.g - bg.g
					var db: float = c.b - bg.b
					var dist: float = sqrt(dr * dr * 0.299 + dg * dg * 0.587 + db * db * 0.114)
					if dist <= tolerance:
						queue.append(n)

func _delete_rect(idx: int) -> void:
	rects.remove_at(idx)
	slice_names.remove_at(idx)
	if idx < slice_materials.size():
		slice_materials.remove_at(idx)
	if idx < locked_states.size():
		locked_states.remove_at(idx)
	selected_indices.erase(idx)
	# Shift remaining indices down
	for i in range(selected_indices.size()):
		if selected_indices[i] > idx:
			selected_indices[i] -= 1
	selection_changed.emit(selected_indices)
	rects_changed.emit()
	queue_redraw()

func _delete_selected_rects() -> void:
	slice_action_started.emit()
	var to_delete := selected_indices.duplicate()
	to_delete.sort()
	to_delete.reverse() # Delete from back to prevent index shifts
	for idx in to_delete:
		rects.remove_at(idx)
		slice_names.remove_at(idx)
		if idx < slice_materials.size():
			slice_materials.remove_at(idx)
		if idx < locked_states.size():
			locked_states.remove_at(idx)
	selected_indices.clear()
	selection_changed.emit(selected_indices)
	rects_changed.emit()
	queue_redraw()

func _duplicate_selected_rects() -> void:
	if selected_indices.is_empty():
		return
	
	slice_action_started.emit()
	var offset := Vector2(8, 8)
	var tex_w := texture.get_width()
	var tex_h := texture.get_height()
	
	var new_selected_indices: Array = []
	for idx in selected_indices:
		var orig_rect = rects[idx]
		var orig_name = slice_names[idx]
		
		# Offset and clamp within texture boundaries
		var new_pos = orig_rect.position + offset
		if new_pos.x + orig_rect.size.x > tex_w:
			new_pos.x = tex_w - orig_rect.size.x
		if new_pos.y + orig_rect.size.y > tex_h:
			new_pos.y = tex_h - orig_rect.size.y
		if new_pos.x < 0:
			new_pos.x = 0
		if new_pos.y < 0:
			new_pos.y = 0
			
		var new_rect = Rect2(new_pos, orig_rect.size)
		var new_name = orig_name
		if new_name != "":
			new_name = new_name + "_copy"
		
		var new_mat := ""
		if idx < slice_materials.size():
			new_mat = slice_materials[idx]
		
		rects.append(new_rect)
		slice_names.append(new_name)
		slice_materials.append(new_mat)
		locked_states.append(false)
		new_selected_indices.append(rects.size() - 1)
		
	selected_indices = new_selected_indices
	selection_changed.emit(selected_indices)
	rects_changed.emit()
	queue_redraw()

func _merge_selected_rects() -> void:
	if selected_indices.size() < 2:
		return
		
	slice_action_started.emit()
	
	var union_rect: Rect2 = rects[selected_indices[0]]
	for i in range(1, selected_indices.size()):
		var idx = selected_indices[i]
		union_rect = union_rect.merge(rects[idx])
		
	var to_delete := selected_indices.duplicate()
	to_delete.sort()
	to_delete.reverse()
	for idx in to_delete:
		rects.remove_at(idx)
		slice_names.remove_at(idx)
		if idx < slice_materials.size():
			slice_materials.remove_at(idx)
		if idx < locked_states.size():
			locked_states.remove_at(idx)
			
	rects.append(union_rect)
	slice_names.append("")
	slice_materials.append("")
	locked_states.append(false)
	
	selected_indices = [rects.size() - 1]
	selection_changed.emit(selected_indices)
	rects_changed.emit()
	queue_redraw()
