@tool
extends Control

signal selection_changed(indices: Array)
signal rects_changed()
signal zoom_changed(new_zoom: float)
signal erase_clicked(img_pos: Vector2i)
signal brush_erase_clicked(img_pos: Vector2i)
signal brush_erase_dragged(img_pos: Vector2i)

var texture: Texture2D = null
var rects: Array[Rect2] = []
var slice_names: Array[String] = []
var selected_indices: Array = []
var zoom: float = 1.0
var erase_mode: bool = false
var brush_erase_mode: bool = false
var _brush_erasing: bool = false

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

# --- Public API ---

func load_texture(tex: Texture2D) -> void:
	texture = tex
	rects.clear()
	slice_names.clear()
	selected_indices.clear()
	_update_min_size()
	queue_redraw()

func set_rects(new_rects: Array[Rect2]) -> void:
	rects = new_rects.duplicate()
	slice_names.clear()
	for i in range(rects.size()):
		slice_names.append("")
	selected_indices.clear()
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

func _handle_at(pos: Vector2) -> String:
	if selected_indices.size() != 1:
		return ""
	var idx: int = selected_indices[0]
	if idx < 0 or idx >= rects.size():
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
		if _s(rects[i]).has_point(pos):
			return i
	return -1

# --- Drawing ---

func _draw() -> void:
	# Checkerboard background
	var cell: int = 8
	var cols: int = int(ceil(size.x / cell)) + 1
	var rows: int = int(ceil(size.y / cell)) + 1
	for row in range(rows):
		for col in range(cols):
			var c: Color = Color(0.22, 0.22, 0.22) if (row + col) % 2 == 0 else Color(0.30, 0.30, 0.30)
			draw_rect(Rect2(col * cell, row * cell, cell, cell), c)

	if not texture:
		return

	# Texture
	var tex_size := Vector2(texture.get_width(), texture.get_height()) * zoom
	draw_texture_rect(texture, Rect2(Vector2.ZERO, tex_size), false)

	# Slice rects
	for i in range(rects.size()):
		_draw_slice(i)

	# Creation preview (Right-click drag)
	if _creating:
		var preview := Rect2(_create_p1, _create_p2 - _create_p1).abs()
		var sr: Rect2 = _s(preview)
		draw_rect(sr, Color(0.3, 0.8, 1.0, 0.18), true)
		draw_rect(sr, Color(0.3, 0.8, 1.0, 0.9),  false, 1.5)

	# Selection preview (Left-click drag on empty space)
	if _selecting:
		var preview := Rect2(_select_p1, _select_p2 - _select_p1).abs()
		var sr: Rect2 = _s(preview)
		draw_rect(sr, Color(1.0, 1.0, 1.0, 0.08), true)
		# Draw dashed/fine outline
		draw_rect(sr, Color(1.0, 1.0, 1.0, 0.6), false, 1.0)

func _draw_slice(i: int) -> void:
	var sr: Rect2 = _s(rects[i])
	var is_sel := i in selected_indices
	var font  := get_theme_font("font")

	if is_sel:
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
		draw_rect(sr, Color(1.00, 0.85, 0.00, 0.12), true)
		draw_rect(sr, Color(1.00, 0.85, 0.00, 0.90), false, 1.5)

	var label_col := Color(0.1, 1.0, 0.2) if is_sel else Color(1.0, 0.9, 0.1)
	draw_string(font, sr.position + Vector2(3, 13), str(i),
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
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return # Do not intercept text editing (like SpinBoxes)

		var is_mac: bool = OS.get_name() == "macOS"
		var is_delete: bool = event.keycode == KEY_DELETE or (is_mac and event.keycode == KEY_BACKSPACE)
		if is_delete and not selected_indices.is_empty():
			_delete_selected_rects()
			get_viewport().set_input_as_handled()

func _on_lmb_down(pos: Vector2) -> void:
	if erase_mode:
		var img_p = _img(pos)
		erase_clicked.emit(Vector2i(img_p))
		return
		
	if brush_erase_mode:
		_brush_erasing = true
		brush_erase_clicked.emit(Vector2i(_img(pos)))
		return
		
	# 1. Check handles (only when exactly one slice is selected)
	var handle: String = _handle_at(pos)
	if handle != "" and selected_indices.size() == 1:
		_dragging = true
		_drag_mode = handle
		_drag_start_mouse_img = _img(pos)
		var idx: int = selected_indices[0]
		_drag_start_rects = { idx: rects[idx] }
		return

	# 2. Check if clicked inside any rect
	var clicked: int = _rect_at(pos)
	if clicked != -1:
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
		return
		
	if _selecting:
		_selecting = false
		var sel_rect := Rect2(_select_p1, _select_p2 - _select_p1).abs()
		
		# If it's a drag box selection
		if sel_rect.size.x >= 3 and sel_rect.size.y >= 3:
			var newly_selected := []
			for i in range(rects.size()):
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
	_right_click_down_pos = pos
	_right_dragged = false
	
	# Start drawing a new rect
	_dragging = true
	_drag_mode = "create"
	_creating = true
	_create_p1 = _img(pos)
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
				rects.append(new_rect)
				slice_names.append("")
				selected_indices = [rects.size() - 1]
				selection_changed.emit(selected_indices)
				rects_changed.emit()
				
		queue_redraw()

func _on_mouse_motion(pos: Vector2) -> void:
	if _brush_erasing:
		brush_erase_dragged.emit(Vector2i(_img(pos)))
		return
		
	if _selecting:
		_select_p2 = _img(pos)
		queue_redraw()
		return

	if _creating:
		_create_p2 = _img(pos)
		if pos.distance_to(_right_click_down_pos) > 5.0:
			_right_dragged = true
		queue_redraw()
		return

	if not _dragging:
		return

	var d: Vector2 = _img(pos) - _drag_start_mouse_img

	if _drag_mode == "move":
		for idx in _drag_start_rects:
			var start_r: Rect2 = _drag_start_rects[idx]
			rects[idx] = Rect2(start_r.position + d, start_r.size)
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
				new_r = Rect2(rs.position + d, rs.end - (rs.position + d)).abs()
			"tr":
				new_r = Rect2(Vector2(rs.position.x,       rs.position.y + d.y),
				              Vector2(rs.size.x    + d.x,  rs.size.y     - d.y)).abs()
			"bl":
				new_r = Rect2(Vector2(rs.position.x + d.x, rs.position.y),
				              Vector2(rs.size.x     - d.x, rs.size.y     + d.y)).abs()
			"br":
				new_r = Rect2(rs.position, rs.size + d).abs()
				
		rects[idx] = new_r
		rects_changed.emit()
		queue_redraw()

func _delete_rect(idx: int) -> void:
	rects.remove_at(idx)
	slice_names.remove_at(idx)
	selected_indices.erase(idx)
	# Shift remaining indices down
	for i in range(selected_indices.size()):
		if selected_indices[i] > idx:
			selected_indices[i] -= 1
	selection_changed.emit(selected_indices)
	rects_changed.emit()
	queue_redraw()

func _delete_selected_rects() -> void:
	var to_delete := selected_indices.duplicate()
	to_delete.sort()
	to_delete.reverse() # Delete from back to prevent index shifts
	for idx in to_delete:
		rects.remove_at(idx)
		slice_names.remove_at(idx)
	selected_indices.clear()
	selection_changed.emit(selected_indices)
	rects_changed.emit()
	queue_redraw()
