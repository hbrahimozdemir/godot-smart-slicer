@tool
extends Control

const _rendererScript = preload("res://addons/sprite_forge/slicer_canvas_renderer.gd")
const _actionsScript = preload("res://addons/sprite_forge/slicer_canvas_actions.gd")

var _renderer: _rendererScript = _rendererScript.new(self)
var _actions: _actionsScript = _actionsScript.new(self)

signal selection_changed(indices: Array)
signal rects_changed()
signal rects_updated(indices: Array)
signal zoom_changed(new_zoom: float)
signal erase_clicked(img_pos: Vector2i)
signal brush_erase_clicked(img_pos: Vector2i)
signal brush_erase_dragged(img_pos: Vector2i)
signal brush_erase_released()
signal brush_paint_clicked(img_pos: Vector2i)
signal brush_paint_dragged(img_pos: Vector2i)
signal brush_paint_released()
signal recolor_clicked(img_pos: Vector2i)
signal frame_pos_changed(pos: Vector2)
signal frame_rotation_changed(deg: float)
signal frame_scale_changed(scale: Vector2)
signal frame_flip_changed(h: bool, v: bool)
signal stamp_pos_changed(pos: Vector2)
signal stamp_rotation_changed(deg: float)
signal stamp_scale_changed(scale: Vector2)
signal stamp_flip_changed(h: bool, v: bool)
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
var frame_mode: bool = false
var frame_tex: Texture2D = null
var frame_pos: Vector2 = Vector2.ZERO
var frame_scale: Vector2 = Vector2.ONE
var frame_rotation: float = 0.0
var frame_pivot: Vector2 = Vector2.ZERO
var frame_flip_h: bool = false
var frame_flip_v: bool = false
var order_behind: bool = false

var _frame_dragging: bool = false
var _frame_drag_offset: Vector2 = Vector2.ZERO
var _frame_rotating: bool = false
var _frame_rotate_start_angle: float = 0.0
var _frame_rotate_start_rot: float = 0.0
var _frame_rotate_center_s: Vector2 = Vector2.ZERO
var _frame_scaling: bool = false
var _frame_scale_start_dist: float = 1.0
var _frame_scale_start_scale: Vector2 = Vector2.ONE
var _frame_scale_center_s: Vector2 = Vector2.ZERO

# Aliases for backwards compatibility / legacy access
var stamp_mode: bool:
	get: return frame_mode
	set(v): frame_mode = v
var stamp_tex: Texture2D:
	get: return frame_tex
	set(v): frame_tex = v
var stamp_pos: Vector2:
	get: return frame_pos
	set(v): frame_pos = v
var stamp_scale: Vector2:
	get: return frame_scale
	set(v): frame_scale = v
var stamp_rotation: float:
	get: return frame_rotation
	set(v): frame_rotation = v
var stamp_pivot: Vector2:
	get: return frame_pivot
	set(v): frame_pivot = v
var paint_color: Color = Color.WHITE
var tolerance: float = 0.18
var preview_mask: Array[Vector2i] = []
var last_preview_pixel: Vector2i = Vector2i(-1, -1)
var _brush_erasing: bool = false
var _brush_painting: bool = false

var brush_size: float = 8.0
var brush_is_square: bool = false
var hover_mouse_pos: Vector2 = Vector2.ZERO
var is_hovering: bool = false

# Checkerboard cache
var _checker_tex: ImageTexture = null
var _checker_size: Vector2i = Vector2i.ZERO

var _preview_mask_tex: ImageTexture = null
var _preview_mask_img: Image = null

# Drag/Create state
var _dragging: bool = false
var _drag_mode: String = ""   # "move" | "create" | "tl" | "tr" | "bl" | "br"
var _drag_start_mouse_img: Vector2
var _drag_start_rects: Dictionary = {} # maps index (int) -> Rect2

# O(1) membership lookup for selected_indices (rebuilt on every selection change)
var _selected_set: Dictionary = {}

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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		is_hovering = false
		preview_mask.clear()
		_preview_mask_tex = null
		last_preview_pixel = Vector2i(-1, -1)
		queue_redraw()

func load_texture(tex: Texture2D) -> void:
	texture = tex
	rects.clear()
	slice_names.clear()
	slice_materials.clear()
	selected_indices.clear()
	_selected_set.clear()
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
	_selected_set = { index: true }
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

## Cursor-anchored zooming: keeps the pixel under mouse stationary during zoom
func _zoom_at_point(target_zoom: float, mouse_pos: Vector2) -> void:
	var old_zoom := zoom
	var new_zoom := clamp(target_zoom, 0.1, 8.0)
	if abs(old_zoom - new_zoom) < 0.001:
		return

	var parent = get_parent()
	var scroll_container: ScrollContainer = parent if parent is ScrollContainer else null
	var old_scroll := Vector2.ZERO
	if scroll_container:
		old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)

	zoom = new_zoom
	_update_min_size()
	zoom_changed.emit(zoom)
	queue_redraw()

	if scroll_container:
		var ratio: float = new_zoom / old_zoom
		var new_scroll_x := int(round((old_scroll.x + mouse_pos.x) * ratio - mouse_pos.x))
		var new_scroll_y := int(round((old_scroll.y + mouse_pos.y) * ratio - mouse_pos.y))
		scroll_container.scroll_horizontal = max(0, new_scroll_x)
		scroll_container.scroll_vertical = max(0, new_scroll_y)

# --- Internal helpers ---

func _update_min_size() -> void:
	if texture:
		custom_minimum_size = Vector2(texture.get_width(), texture.get_height()) * zoom + Vector2(1, 1)
	else:
		custom_minimum_size = Vector2(256, 256)

## Rebuilds _selected_set from selected_indices and emits selection_changed.
## Always call this instead of emitting the signal directly.
func _emit_selection_changed() -> void:
	_selected_set.clear()
	for idx in selected_indices:
		_selected_set[idx] = true
	selection_changed.emit(selected_indices)

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
	_renderer._draw()

func _get_frame_transform_screen() -> Transform2D:
	return _renderer._get_frame_transform_screen()

func _get_frame_corners_screen() -> Dictionary:
	return _renderer._get_frame_corners_screen()

func _draw_frame_texture() -> void:
	_renderer._draw_frame_texture()

func _draw_frame_gizmo() -> void:
	_renderer._draw_frame_gizmo()

func _draw_checkerboard() -> void:
	_renderer._draw_checkerboard()

func _draw_slice(i: int, font: Font) -> void:
	_renderer._draw_slice(i, font)

func _gui_input(event: InputEvent) -> void:
	if not texture:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_point(zoom * 1.15, event.position)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_point(zoom / 1.15, event.position)
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
		if _dragging or _selecting or _frame_dragging or _frame_scaling or _frame_rotating:
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
				_emit_selection_changed()
				queue_redraw()
				get_viewport().set_input_as_handled()
				return

			# Deselect All (Escape)
			if key_event.keycode == KEY_ESCAPE:
				if not selected_indices.is_empty():
					selected_indices.clear()
					_emit_selection_changed()
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
				_emit_selection_changed()
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
					
			rects_updated.emit(selected_indices)
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

	if frame_mode and frame_tex:
		var corners := _get_frame_corners_screen()
		var center_s: Vector2 = corners.get("center", frame_pos * zoom)

		# 1. Rotation handle hit test (priority 1)
		if "rot_handle" in corners:
			var rot_handle_s: Vector2 = corners["rot_handle"]
			if pos.distance_to(rot_handle_s) <= 28.0:
				_frame_rotating = true
				_frame_rotate_center_s = center_s
				_frame_rotate_start_angle = (pos - _frame_rotate_center_s).angle()
				_frame_rotate_start_rot = frame_rotation
				get_viewport().set_input_as_handled()
				return

		# 2. Corner Scale Handle hit tests (priority 2)
		for c_name in ["tl", "tr", "bl", "br"]:
			if c_name in corners:
				var corner_pt: Vector2 = corners[c_name]
				if pos.distance_to(corner_pt) <= 25.0:
					_frame_scaling = true
					_frame_scale_center_s = center_s
					_frame_scale_start_dist = max(1.0, pos.distance_to(_frame_scale_center_s))
					_frame_scale_start_scale = frame_scale
					get_viewport().set_input_as_handled()
					return

		# 3. Body drag (only inside texture bounds)
		var img_p := _img(pos)
		var t := Transform2D()
		var f_scale := frame_scale
		if frame_flip_h: f_scale.x *= -1.0
		if frame_flip_v: f_scale.y *= -1.0
		t.x = Vector2(cos(frame_rotation), sin(frame_rotation)) * f_scale.x
		t.y = Vector2(-sin(frame_rotation), cos(frame_rotation)) * f_scale.y
		t.origin = frame_pos - (t.x * frame_pivot.x + t.y * frame_pivot.y)
		var inv: Transform2D = t.affine_inverse()
		var src_pos: Vector2 = inv * img_p
		var w := float(frame_tex.get_width())
		var h := float(frame_tex.get_height())
		if src_pos.x >= 0 and src_pos.x <= w and src_pos.y >= 0 and src_pos.y <= h:
			_frame_dragging = true
			_frame_drag_offset = frame_pos - img_p
			get_viewport().set_input_as_handled()
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
			_emit_selection_changed()

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
		_emit_selection_changed()
	queue_redraw()

func _on_lmb_up(pos: Vector2) -> void:
	if _frame_scaling:
		_frame_scaling = false
		return

	if _frame_rotating:
		_frame_rotating = false
		return

	if _frame_dragging:
		_frame_dragging = false
		return
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
				
		_emit_selection_changed()
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
				_emit_selection_changed()
				rects_changed.emit()
				
		queue_redraw()

func _on_mouse_motion(pos: Vector2) -> void:
	var needs_redraw := false

	if brush_erase_mode or paint_mode or frame_mode or erase_mode or recolor_mode:
		hover_mouse_pos = pos
		is_hovering = true
		needs_redraw = true

	if (erase_mode or recolor_mode) and texture:
		var img_p := Vector2i(_img(pos))
		if img_p != last_preview_pixel:
			last_preview_pixel = img_p
			_recalculate_wand_preview(img_p)
			needs_redraw = true

	if needs_redraw:
		queue_redraw()

	if _frame_scaling:
		var current_dist := pos.distance_to(_frame_scale_center_s)
		var ratio := current_dist / _frame_scale_start_dist
		frame_scale = _frame_scale_start_scale * ratio
		frame_scale.x = clamp(frame_scale.x, 0.05, 50.0)
		frame_scale.y = clamp(frame_scale.y, 0.05, 50.0)
		frame_scale_changed.emit(frame_scale)
		stamp_scale_changed.emit(frame_scale)
		queue_redraw()
		return

	if _frame_rotating:
		var current_angle := (pos - _frame_rotate_center_s).angle()
		var delta := current_angle - _frame_rotate_start_angle
		frame_rotation = _frame_rotate_start_rot + delta
		frame_rotation_changed.emit(rad_to_deg(frame_rotation))
		stamp_rotation_changed.emit(rad_to_deg(frame_rotation))
		queue_redraw()
		return

	if _frame_dragging:
		var img_p = _img(pos)
		frame_pos = img_p + _frame_drag_offset
		frame_pos_changed.emit(frame_pos)
		stamp_pos_changed.emit(frame_pos)
		queue_redraw()
		return

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
		rects_updated.emit(selected_indices)
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
		rects_updated.emit(selected_indices)
		queue_redraw()

func _recalculate_wand_preview(img_p: Vector2i) -> void:
	_actions._recalculate_wand_preview(img_p)

func _delete_rect(idx: int) -> void:
	_actions._delete_rect(idx)

func _delete_selected_rects() -> void:
	_actions._delete_selected_rects()

func _duplicate_selected_rects() -> void:
	_actions._duplicate_selected_rects()

func _merge_selected_rects() -> void:
	_actions._merge_selected_rects()
