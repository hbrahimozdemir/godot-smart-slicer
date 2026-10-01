@tool
extends HBoxContainer

# Preloads
const _AutoSlicer   = preload("res://addons/sprite_forge/auto_slicer.gd")
const _Extractor    = preload("res://addons/sprite_forge/extractor.gd")
const _CanvasScript = preload("res://addons/sprite_forge/slicer_canvas.gd")
const _BgRemover    = preload("res://addons/sprite_forge/bg_remover.gd")
const _PreviewPlayerScript = preload("res://addons/sprite_forge/slicer_preview_player.gd")
const _HistoryScript = preload("res://addons/sprite_forge/slicer_history.gd")
const _DialogScript  = preload("res://addons/sprite_forge/slicer_dialogs.gd")


# UI References
var _canvas: _CanvasScript
var _path_label:  LineEdit
var _count_label: Label
var _slice_list:  ItemList
var _name_edit:   LineEdit
var _spin_x:      SpinBox
var _spin_y:      SpinBox
var _spin_w:      SpinBox
var _spin_h:      SpinBox
var _zoom_label:  Label
var _format_opt:  OptionButton
var _props_box:   VBoxContainer
var _file_dialog: FileDialog
var _chk_atlas:   CheckBox
var _chk_spriteframes: CheckBox
var _chk_png: CheckBox
var _wand_btn:    Button
var _brush_erase_btn: Button
var _paint_btn: Button
var _recolor_btn: Button
var _stamp_btn: Button # Frame button alias
var _text_btn: Button
var _order_opt: OptionButton
var _color_picker: ColorPickerButton
var _props_grid: GridContainer

# State & Managers
var _history: _HistoryScript
var _dialogs: _DialogScript
var _current_tex:      Texture2D
var _current_tex_path: String  = ""
var _zoom:             float   = 1.0
var _updating_props:   bool    = false
var _bg_tolerance:     float   = 0.18
var _brush_size_spin: SpinBox

var _merge_btn: Button
var _lock_btn: Button
var _chk_snap: CheckBox
var _spin_snap_w: SpinBox
var _spin_snap_h: SpinBox

var _undo_btn: Button
var _redo_btn: Button

# UI references for Preview Player
var _preview_player: _PreviewPlayerScript
var _anim_name_edit: LineEdit

var _mat_edit: LineEdit
var _mat_browse_btn: Button
var _mat_box: HBoxContainer
var _stamp_props_box: VBoxContainer
var _stamp_pos_x: SpinBox
var _stamp_pos_y: SpinBox
var _stamp_scale_x: SpinBox
var _stamp_scale_y: SpinBox
var _stamp_pivot_x: SpinBox
var _stamp_pivot_y: SpinBox
var _stamp_rot: SpinBox

# Frame animation frames
var _stamp_frames: Array[Texture2D] = []
var _stamp_frame_idx: int = 0
var _stamp_frame_label: Label
var _stamp_prev_frame_btn: Button
var _stamp_next_frame_btn: Button

var _export_folder_edit: LineEdit
var _export_base_edit: LineEdit
var _chk_subfolder: CheckBox
var _chk_auto_unique: CheckBox

# Text Tool UI
var _text_props_box: VBoxContainer
var _text_input: LineEdit
var _font_path_label: LineEdit
var _font_browse_btn: Button
var _text_font_size_spin: SpinBox
var _text_color_picker: ColorPickerButton
var _current_font: Font = null
var _current_font_path: String = ""



const _toolbar_builderScript = preload("res://addons/sprite_forge/slicer_toolbar_builder.gd")
const _sidebar_builderScript = preload("res://addons/sprite_forge/slicer_sidebar_builder.gd")
const _image_controllerScript = preload("res://addons/sprite_forge/slicer_image_controller.gd")
const _history_controllerScript = preload("res://addons/sprite_forge/slicer_history_controller.gd")
const _text_controllerScript = preload("res://addons/sprite_forge/slicer_text_controller.gd")

var _toolbar_builder: _toolbar_builderScript
var _sidebar_builder: _sidebar_builderScript
var _image_controller: _image_controllerScript
var _history_controller: _history_controllerScript
var _text_controller: _text_controllerScript

func _ready() -> void:
	_toolbar_builder = _toolbar_builderScript.new(self)
	_sidebar_builder = _sidebar_builderScript.new(self)
	_image_controller = _image_controllerScript.new(self)
	_history_controller = _history_controllerScript.new(self)
	_text_controller = _text_controllerScript.new(self)
	_history = _HistoryScript.new()
	_history.history_changed.connect(_on_history_changed)

	_build_ui()

	_dialogs = _DialogScript.new()
	_dialogs.texture_selected.connect(_load_texture)
	_dialogs.frame_selected.connect(_load_stamp_image)
	_dialogs.material_selected.connect(_assign_material_to_selected)
	_dialogs.font_selected.connect(_load_font_file)
	_dialogs.grid_slice_requested.connect(_on_grid_slice_confirmed_args)
	_dialogs.resize_image_requested.connect(_on_resize_image_requested)
	add_child(_dialogs)
	_dialogs.setup_dialogs(self)

	if _canvas:
		_canvas.tolerance = _bg_tolerance

# --- UI Construction ---

func _build_ui() -> void:
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	left.add_child(_make_toolbar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)

	_canvas = _CanvasScript.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.selection_changed.connect(_on_canvas_selection_changed)
	_canvas.rects_changed.connect(_on_rects_changed)
	_canvas.rects_updated.connect(_on_rects_updated)
	_canvas.zoom_changed.connect(_on_canvas_zoom_changed)
	_canvas.erase_clicked.connect(_on_erase_clicked)
	_canvas.brush_erase_clicked.connect(_on_brush_erase_clicked)
	_canvas.brush_erase_dragged.connect(_on_brush_erase_dragged)
	_canvas.brush_erase_released.connect(_on_brush_erase_released)
	_canvas.brush_paint_clicked.connect(_on_brush_paint_clicked)
	_canvas.brush_paint_dragged.connect(_on_brush_paint_dragged)
	_canvas.brush_paint_released.connect(_on_brush_paint_released)
	_canvas.recolor_clicked.connect(_on_recolor_clicked)
	_canvas.stamp_pos_changed.connect(_on_canvas_stamp_pos_changed)
	_canvas.stamp_rotation_changed.connect(_on_canvas_stamp_rotation_changed)
	_canvas.stamp_scale_changed.connect(_on_canvas_stamp_scale_changed)
	_canvas.slice_action_started.connect(_push_slices_state)
	scroll.add_child(_canvas)

	var right := _make_right_panel()
	split.add_child(right)
	split.split_offset = -260

func _make_toolbar() -> Control:
	return _toolbar_builder._make_toolbar()

func _make_right_panel() -> PanelContainer:
	return _sidebar_builder._make_right_panel()

func _make_spin(lbl_text: String, parent: Control) -> SpinBox:
	return _sidebar_builder._make_spin(lbl_text, parent)

func _make_stamp_spin_inline(lbl_text: String, parent: Control, min_val: float, max_val: float, step_val: float, default_val: float) -> SpinBox:
	return _sidebar_builder._make_stamp_spin_inline(lbl_text, parent, min_val, max_val, step_val, default_val)

func _on_grid_slice_confirmed_args(cell_w: int, cell_h: int, off_x: int, off_y: int, sep_x: int, sep_y: int, keep_empty: bool) -> void:
	if not _current_tex:
		return
	var img: Image = _current_tex.get_image()
	if not img or img.is_empty():
		return

	_push_slices_state()
	var rects := _AutoSlicer.slice_grid(img, cell_w, cell_h, off_x, off_y, sep_x, sep_y, keep_empty)
	_canvas.set_rects(rects)
	_refresh_list()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_resize_image_requested(new_w: int, new_h: int, interp_mode: int, scale_slices: bool) -> void:
	_image_controller._on_resize_image_requested(new_w, new_h, interp_mode, scale_slices)

func _on_browse() -> void:
	if _dialogs:
		_dialogs.open_texture_dialog()

# --- Action handlers ---

func _load_texture(path: String) -> void:
	var tex: Texture2D = null
	var res = load(path)
	if res is Texture2D:
		tex = res
	elif res is Image:
		tex = ImageTexture.create_from_image(res)
	elif res != null and res.has_method("get_image"):
		var img: Image = res.get_image()
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)

	if tex == null:
		# Fallback: load directly from file system (useful for unimported PNGs or external paths)
		var abs_p := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_p)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)

	if tex == null:
		push_error("SpriteForge: Could not load texture from path: " + path)
		return

	if _history:
		_history.clear()
	_current_tex      = tex
	_current_tex_path = path
	_path_label.text  = path.get_file()
	_path_label.tooltip_text = path
	_canvas.load_texture(tex)
	_canvas.set_zoom(1.0)
	_refresh_list()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_auto_slice() -> void:
	if not _current_tex:
		return
	_push_slices_state()
	_canvas.set_rects(_AutoSlicer.slice(_current_tex.get_image()))
	_refresh_list()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_clear() -> void:
	_push_slices_state()
	_canvas.rects.clear()
	_canvas.slice_names.clear()
	_canvas.slice_materials.clear()
	_canvas.selected_indices.clear()
	_canvas.locked_states.clear()
	_canvas.queue_redraw()
	_refresh_list()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _flip_main_texture(flip_h: bool, flip_v: bool) -> void:
	_image_controller._flip_main_texture(flip_h, flip_v)

func _on_extract(only_selected: bool = false) -> void:
	if not _current_tex or _canvas.rects.is_empty():
		return
		
	var export_rects: Array[Rect2] = []
	var export_names: Array[String] = []
	var export_materials: Array[String] = []
	
	if only_selected and not _canvas.selected_indices.is_empty():
		var sel_sorted = _canvas.selected_indices.duplicate()
		sel_sorted.sort()
		for idx in sel_sorted:
			if idx >= 0 and idx < _canvas.rects.size():
				export_rects.append(_canvas.rects[idx])
				export_names.append(_canvas.slice_names[idx])
				export_materials.append(_canvas.slice_materials[idx])
	else:
		export_rects = _canvas.rects.duplicate()
		export_names = _canvas.slice_names.duplicate()
		export_materials = _canvas.slice_materials.duplicate()
		
	if export_rects.is_empty():
		return

	if _current_tex is ImageTexture:
		_ensure_edited_path()
		if not _save_edited_texture():
			return

	var a_name := "default"
	if _anim_name_edit and _anim_name_edit.text.strip_edges() != "":
		a_name = _anim_name_edit.text.strip_edges()
		
	var custom_folder := ""
	if _export_folder_edit and _export_folder_edit.text.strip_edges() != "":
		custom_folder = _export_folder_edit.text.strip_edges()
		
	var custom_base := ""
	if _export_base_edit and _export_base_edit.text.strip_edges() != "":
		custom_base = _export_base_edit.text.strip_edges()
		
	var use_subfolder := _chk_subfolder.button_pressed if _chk_subfolder else true
	var auto_unique := _chk_auto_unique.button_pressed if _chk_auto_unique else true

	_Extractor.extract(_current_tex, export_rects,
		_chk_png.button_pressed,
		_chk_atlas.button_pressed,
		_chk_spriteframes.button_pressed,
		_current_tex_path, export_names,
		a_name,
		export_materials,
		custom_folder,
		custom_base,
		use_subfolder,
		auto_unique)

func _select_tool(tool_name: String) -> void:
	_toolbar_builder.sync_tool(tool_name)
	var wand_on := (tool_name == "wand")
	var brush_erase_on := (tool_name == "brush_erase")
	var recolor_on := (tool_name == "recolor")
	var paint_on := (tool_name == "paint")
	var stamp_on := (tool_name == "stamp")
	var text_on := (tool_name == "text")
	
	_wand_btn.set_pressed_no_signal(wand_on)
	_brush_erase_btn.set_pressed_no_signal(brush_erase_on)
	if _recolor_btn:
		_recolor_btn.set_pressed_no_signal(recolor_on)
	if _paint_btn:
		_paint_btn.set_pressed_no_signal(paint_on)
	if _stamp_btn:
		_stamp_btn.set_pressed_no_signal(stamp_on)
	if _text_btn:
		_text_btn.set_pressed_no_signal(text_on)
		
	_update_button_modulations()
		
	if _canvas:
		_canvas.erase_mode = wand_on
		_canvas.brush_erase_mode = brush_erase_on
		_canvas.recolor_mode = recolor_on
		_canvas.paint_mode = paint_on
		_canvas.frame_mode = (stamp_on or text_on)
		if not stamp_on and not text_on:
			_canvas.frame_tex = null
			_stamp_frames.clear()
			_stamp_frame_idx = 0
			if _stamp_frame_label:
				_stamp_frame_label.text = "-/-"
			if _stamp_prev_frame_btn:
				_stamp_prev_frame_btn.disabled = true
			if _stamp_next_frame_btn:
				_stamp_next_frame_btn.disabled = true
		_canvas.queue_redraw()
		
	if _stamp_props_box != null:
		_stamp_props_box.visible = stamp_on
	if _text_props_box != null:
		_text_props_box.visible = text_on
	if _props_box != null:
		_props_box.visible = not stamp_on and not text_on and not _canvas.selected_indices.is_empty() if _canvas else false

	if text_on:
		_canvas.frame_tex = null
		_stamp_frames.clear()
		_stamp_frame_idx = 0
		_update_text_preview()

func _update_button_modulations() -> void:
	var active_color := Color(0.3, 0.8, 1.0, 1.0)
	var normal_color := Color.WHITE
	
	_wand_btn.self_modulate = active_color if _wand_btn.button_pressed else normal_color
	_brush_erase_btn.self_modulate = active_color if _brush_erase_btn.button_pressed else normal_color
	if _recolor_btn:
		_recolor_btn.self_modulate = active_color if _recolor_btn.button_pressed else normal_color
	if _paint_btn:
		_paint_btn.self_modulate = active_color if _paint_btn.button_pressed else normal_color
	if _stamp_btn:
		_stamp_btn.self_modulate = active_color if _stamp_btn.button_pressed else normal_color
	if _text_btn:
		_text_btn.self_modulate = active_color if _text_btn.button_pressed else normal_color

func _on_wand_toggled(toggled: bool) -> void:
	_select_tool("wand" if toggled else "")

func _on_brush_toggled(toggled: bool) -> void:
	_select_tool("brush_erase" if toggled else "")

func _on_recolor_toggled(toggled: bool) -> void:
	_select_tool("recolor" if toggled else "")

func _on_paint_toggled(toggled: bool) -> void:
	_select_tool("paint" if toggled else "")

func _load_stamp_image(path: String) -> void:
	if not _canvas or not _current_tex:
		return
	var loaded_textures: Array[Texture2D] = []
	var res = load(path)
	if res is Texture2D:
		loaded_textures.append(res)
	elif res is SpriteFrames:
		var sf := res as SpriteFrames
		var anims := sf.get_animation_names()
		for anim in anims:
			var count := sf.get_frame_count(anim)
			for i in range(count):
				var tex := sf.get_frame_texture(anim, i)
				if tex:
					loaded_textures.append(tex)
	elif res is Image:
		loaded_textures.append(ImageTexture.create_from_image(res))
	elif res != null and res.has_method("get_image"):
		var img: Image = res.get_image()
		if img and not img.is_empty():
			loaded_textures.append(ImageTexture.create_from_image(img))

	if loaded_textures.is_empty():
		return

	for tex in loaded_textures:
		_stamp_frames.append(tex)

	_stamp_frame_idx = _stamp_frames.size() - 1
	var first_tex := loaded_textures[0]

	# First frame: set default transforms based on canvas center
	if _stamp_frames.size() == loaded_textures.size():
		var base_img: Image = _current_tex.get_image()
		if base_img:
			var center_x: float = base_img.get_width() / 2.0
			var center_y: float = base_img.get_height() / 2.0
			var pivot_x: float = first_tex.get_width() / 2.0
			var pivot_y: float = first_tex.get_height() / 2.0

			_canvas.frame_pos = Vector2(center_x, center_y)
			_canvas.frame_scale = Vector2.ONE
			_canvas.frame_rotation = 0.0
			_canvas.frame_pivot = Vector2(pivot_x, pivot_y)
			_canvas.frame_flip_h = false
			_canvas.frame_flip_v = false

			if _stamp_pos_x: _stamp_pos_x.set_value_no_signal(center_x)
			if _stamp_pos_y: _stamp_pos_y.set_value_no_signal(center_y)
			if _stamp_scale_x: _stamp_scale_x.set_value_no_signal(1.0)
			if _stamp_scale_y: _stamp_scale_y.set_value_no_signal(1.0)
			if _stamp_pivot_x: _stamp_pivot_x.set_value_no_signal(pivot_x)
			if _stamp_pivot_y: _stamp_pivot_y.set_value_no_signal(pivot_y)
			if _stamp_rot: _stamp_rot.set_value_no_signal(0.0)

	_update_stamp_frame()
	_select_tool("stamp")

func _update_stamp_frame() -> void:
	if _stamp_frames.is_empty() or not _canvas:
		return
	_stamp_frame_idx = clamp(_stamp_frame_idx, 0, _stamp_frames.size() - 1)
	var curr_tex: Texture2D = _stamp_frames[_stamp_frame_idx]
	_canvas.stamp_tex = curr_tex

	if curr_tex:
		var pivot_x: float = curr_tex.get_width() / 2.0
		var pivot_y: float = curr_tex.get_height() / 2.0
		_canvas.frame_pivot = Vector2(pivot_x, pivot_y)
		if _stamp_pivot_x: _stamp_pivot_x.set_value_no_signal(pivot_x)
		if _stamp_pivot_y: _stamp_pivot_y.set_value_no_signal(pivot_y)

	_canvas.queue_redraw()
	if _stamp_frame_label:
		_stamp_frame_label.text = "%d/%d" % [_stamp_frame_idx + 1, _stamp_frames.size()]
	if _stamp_prev_frame_btn:
		_stamp_prev_frame_btn.disabled = (_stamp_frame_idx == 0)
	if _stamp_next_frame_btn:
		_stamp_next_frame_btn.disabled = (_stamp_frame_idx >= _stamp_frames.size() - 1)

func _assign_material_to_selected(path: String) -> void:
	if not _canvas or _canvas.selected_indices.size() != 1:
		return
	var idx: int = _canvas.selected_indices[0]
	if idx < 0 or idx >= _canvas.rects.size():
		return
	
	_push_slices_state()
	while _canvas.slice_materials.size() <= idx:
		_canvas.slice_materials.append("")
	_canvas.slice_materials[idx] = path
	_update_props()
	_refresh_list()

func _on_canvas_stamp_pos_changed(pos: Vector2) -> void:
	if _stamp_pos_x: _stamp_pos_x.set_value_no_signal(pos.x)
	if _stamp_pos_y: _stamp_pos_y.set_value_no_signal(pos.y)

func _on_canvas_stamp_rotation_changed(deg: float) -> void:
	if _stamp_rot: _stamp_rot.set_value_no_signal(fmod(deg, 360.0))

func _on_canvas_stamp_scale_changed(sc: Vector2) -> void:
	if _stamp_scale_x: _stamp_scale_x.set_value_no_signal(sc.x)
	if _stamp_scale_y: _stamp_scale_y.set_value_no_signal(sc.y)

func _on_stamp_prop_changed() -> void:
	if not _canvas or not _canvas.stamp_tex:
		return
	_canvas.stamp_pos = Vector2(_stamp_pos_x.value, _stamp_pos_y.value)
	_canvas.stamp_scale = Vector2(_stamp_scale_x.value, _stamp_scale_y.value)
	_canvas.stamp_rotation = deg_to_rad(_stamp_rot.value)
	_canvas.stamp_pivot = Vector2(_stamp_pivot_x.value, _stamp_pivot_y.value)
	_canvas.queue_redraw()

func _apply_stamp() -> void:
	_image_controller._apply_stamp()

func _cancel_stamp() -> void:
	_select_tool("")

func _on_brush_erase_clicked(img_pos: Vector2i) -> void:
	_image_controller._on_brush_erase_clicked(img_pos)

func _on_brush_erase_dragged(img_pos: Vector2i) -> void:
	_image_controller._on_brush_erase_dragged(img_pos)

func _on_brush_erase_released() -> void:
	_image_controller._on_brush_erase_released()

func _do_brush_erase(img_pos: Vector2i) -> void:
	_image_controller._do_brush_erase(img_pos)

func _on_brush_paint_clicked(img_pos: Vector2i) -> void:
	_image_controller._on_brush_paint_clicked(img_pos)

func _on_brush_paint_dragged(img_pos: Vector2i) -> void:
	_image_controller._on_brush_paint_dragged(img_pos)

func _on_brush_paint_released() -> void:
	_image_controller._on_brush_paint_released()

func _do_brush_paint(img_pos: Vector2i) -> void:
	_image_controller._do_brush_paint(img_pos)

func _on_recolor_clicked(img_pos: Vector2i) -> void:
	_image_controller._on_recolor_clicked(img_pos)

func _on_erase_clicked(img_pos: Vector2i) -> void:
	_image_controller._on_erase_clicked(img_pos)

func _ensure_edited_path() -> void:
	_image_controller._ensure_edited_path()

func _save_edited_texture() -> bool:
	return _image_controller._save_edited_texture()

func _on_remove_bg() -> void:
	_image_controller._on_remove_bg()

func _on_delete_selected() -> void:
	if _canvas.selected_indices.is_empty():
		return
	# No _push_slices_state() here - _delete_selected_rects() emits slice_action_started
	_canvas._delete_selected_rects()

func _on_lock_toggle() -> void:
	if not _canvas or _canvas.selected_indices.is_empty():
		return
	_push_slices_state()
	var any_unlocked := false
	for idx in _canvas.selected_indices:
		if idx < _canvas.locked_states.size() and not _canvas.locked_states[idx]:
			any_unlocked = true
			break
	for idx in _canvas.selected_indices:
		if idx < _canvas.locked_states.size():
			_canvas.locked_states[idx] = any_unlocked
	_canvas.queue_redraw()
	_refresh_list()
	_update_props()




# --- Signal connections ---

func _on_canvas_zoom_changed(z: float) -> void:
	_zoom = z
	_zoom_label.text = str(int(round(z * 100))) + "%"

func _on_canvas_selection_changed(indices: Array) -> void:
	_sync_list_highlight(indices)
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_rects_changed() -> void:
	_refresh_list()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_rects_updated(indices: Array) -> void:
	for idx in indices:
		_update_list_item(idx)
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_list_item_selected(_index: int) -> void:
	var selected: PackedInt32Array = _slice_list.get_selected_items()
	var canvas_selected: Array = []
	for idx in selected:
		canvas_selected.append(idx)
	_canvas.selected_indices = canvas_selected
	_canvas.queue_redraw()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_prop_changed() -> void:
	if _updating_props:
		return
	if _canvas.selected_indices.size() != 1:
		return
	var idx: int = _canvas.selected_indices[0]
	if idx < 0 or idx >= _canvas.rects.size():
		return
	_push_slices_state()
	_canvas.rects[idx] = Rect2(_spin_x.value, _spin_y.value, _spin_w.value, _spin_h.value)
	_canvas.queue_redraw()
	_update_list_item(idx)

func _sort_indices_spatially(indices: Array) -> Array:
	var sorted := indices.duplicate()
	sorted.sort_custom(func(a_idx: int, b_idx: int) -> bool:
		var a_rect: Rect2 = _canvas.rects[a_idx]
		var b_rect: Rect2 = _canvas.rects[b_idx]
		var y_diff := abs(a_rect.position.y - b_rect.position.y)
		if y_diff < 12.0:
			return a_rect.position.x < b_rect.position.x
		return a_rect.position.y < b_rect.position.y
	)
	return sorted

func _on_name_changed(new_text: String) -> void:
	if _updating_props:
		return
	if _canvas.selected_indices.is_empty():
		return
	if _canvas.selected_indices.size() == 1:
		var idx: int = _canvas.selected_indices[0]
		if idx < 0 or idx >= _canvas.slice_names.size():
			return
		_canvas.slice_names[idx] = new_text
		_update_list_item(idx)
	else:
		var sorted_sel := _sort_indices_spatially(_canvas.selected_indices)
		var num_selected := sorted_sel.size()
		var pad_len := 1
		if num_selected >= 100:
			pad_len = 3
		elif num_selected >= 10:
			pad_len = 2

		for i in range(num_selected):
			var idx: int = sorted_sel[i]
			if idx < 0 or idx >= _canvas.slice_names.size():
				continue
			var suffix := str(i)
			while suffix.length() < pad_len:
				suffix = "0" + suffix
			_canvas.slice_names[idx] = new_text + "_" + suffix
			_update_list_item(idx)


# --- Helper methods ---

func _refresh_list() -> void:
	_slice_list.clear()
	for i in range(_canvas.rects.size()):
		_slice_list.add_item(_item_text(i))
	_count_label.text = "SLICES (%d)" % _canvas.rects.size()

func _update_list_item(idx: int) -> void:
	if idx >= 0 and idx < _slice_list.item_count:
		_slice_list.set_item_text(idx, _item_text(idx))

func _item_text(i: int) -> String:
	var r: Rect2 = _canvas.rects[i]
	var custom_name = ""
	if i < _canvas.slice_names.size() and _canvas.slice_names[i] != "":
		custom_name = "[" + _canvas.slice_names[i] + "] "
	var prefix := ""
	if i < _canvas.locked_states.size() and _canvas.locked_states[i]:
		prefix = "🔒 "
	return "%s%sSlice %d  (%d,%d)  %dx%d" % [prefix, custom_name, i,
		int(r.position.x), int(r.position.y),
		int(r.size.x),     int(r.size.y)]

func _sync_list_highlight(indices: Array) -> void:
	for i in range(_slice_list.item_count):
		_slice_list.deselect(i)
	for idx in indices:
		if idx >= 0 and idx < _slice_list.item_count:
			_slice_list.select(idx)

func _update_props() -> void:
	if _canvas.selected_indices.is_empty():
		_props_box.visible = false
		return
	_props_box.visible = true
	_updating_props = true
	
	if _merge_btn:
		_merge_btn.disabled = _canvas.selected_indices.size() < 2

	if _lock_btn:
		var all_locked := true
		for idx in _canvas.selected_indices:
			if idx < _canvas.locked_states.size() and not _canvas.locked_states[idx]:
				all_locked = false
				break
		_lock_btn.text = "Unlock Slices" if all_locked else "Lock Slices"

	if _canvas.selected_indices.size() == 1:
		var idx: int = _canvas.selected_indices[0]
		if idx < 0 or idx >= _canvas.rects.size():
			_props_box.visible = false
			_updating_props = false
			return
		_props_grid.visible = true
		if _mat_box:
			_mat_box.visible = true
		var r: Rect2 = _canvas.rects[idx]
		var cname = ""
		if idx < _canvas.slice_names.size():
			cname = _canvas.slice_names[idx]
		_name_edit.text = cname
		_name_edit.placeholder_text = "Custom Name"
		
		var mat_path := ""
		if idx < _canvas.slice_materials.size():
			mat_path = _canvas.slice_materials[idx]
		if _mat_edit:
			_mat_edit.text = mat_path.get_file()
			_mat_edit.tooltip_text = mat_path if mat_path != "" else "No Material/Shader"
			
		_spin_x.value = r.position.x
		_spin_y.value = r.position.y
		_spin_w.value = r.size.x
		_spin_h.value = r.size.y
	else:
		_props_grid.visible = false
		if _mat_box:
			_mat_box.visible = false
		_name_edit.text = ""
		_name_edit.placeholder_text = "Seq Name (e.g. chest)"
	_updating_props = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		var vp := get_viewport()
		var focus_owner: Control = vp.gui_get_focus_owner() if vp else null
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return

		var is_mac: bool = OS.get_name() == "macOS"
		var is_ctrl: bool = key_event.ctrl_pressed or (is_mac and key_event.meta_pressed)

		if is_ctrl and key_event.keycode == KEY_Z:
			if key_event.shift_pressed:
				_redo()
			else:
				_undo()
			get_viewport().set_input_as_handled()
		elif is_ctrl and key_event.keycode == KEY_Y:
			_redo()
			get_viewport().set_input_as_handled()

func _push_history_state(state: Dictionary) -> void:
	_history_controller._push_history_state(state)

func _capture_image_state() -> Dictionary:
	return _history_controller._capture_image_state()

func _push_image_state() -> void:
	_history_controller._push_image_state()

func _push_slices_state() -> void:
	_history_controller._push_slices_state()

func _on_history_changed(can_u: bool, can_r: bool) -> void:
	_history_controller._on_history_changed(can_u, can_r)

func _undo() -> void:
	_history_controller._undo()

func _redo() -> void:
	_history_controller._redo()

func _apply_history_state(state: Dictionary) -> Dictionary:
	return _history_controller._apply_history_state(state)

func _load_font_file(path: String) -> void:
	_text_controller._load_font_file(path)

func _update_text_preview() -> void:
	await _text_controller._update_text_preview()

func _render_text_image(text: String, font: Font, font_size: int, color: Color) -> Image:
	return await _text_controller._render_text_image(text, font, font_size, color)
