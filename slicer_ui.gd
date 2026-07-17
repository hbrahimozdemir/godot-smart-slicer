@tool
extends HBoxContainer

# Preloads
const _AutoSlicer   = preload("res://addons/sprite_slicer/auto_slicer.gd")
const _Extractor    = preload("res://addons/sprite_slicer/extractor.gd")
const _CanvasScript = preload("res://addons/sprite_slicer/slicer_canvas.gd")
const _BgRemover    = preload("res://addons/sprite_slicer/bg_remover.gd")
const _PreviewPlayerScript = preload("res://addons/sprite_slicer/slicer_preview_player.gd")

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
var _color_picker: ColorPickerButton
var _props_grid: GridContainer

# State
var _current_tex:      Texture2D
var _current_tex_path: String  = ""
var _zoom:             float   = 1.0
var _updating_props:   bool    = false
var _bg_tolerance:     float   = 0.18
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _brush_size_spin: SpinBox

var _merge_btn: Button
var _lock_btn: Button
var _chk_snap: CheckBox
var _spin_snap_w: SpinBox
var _spin_snap_h: SpinBox

var _undo_btn: Button
var _redo_btn: Button

# Grid Dialog UI
var _grid_dialog: ConfirmationDialog
var _grid_spin_w: SpinBox
var _grid_spin_h: SpinBox
var _grid_spin_off_x: SpinBox
var _grid_spin_off_y: SpinBox
var _grid_spin_sep_x: SpinBox
var _grid_spin_sep_y: SpinBox
var _grid_chk_keep_empty: CheckBox

# UI references for Preview Player
var _preview_player: _PreviewPlayerScript
var _anim_name_edit: LineEdit

var _stamp_dialog: FileDialog
var _material_dialog: FileDialog
var _mat_edit: LineEdit
var _mat_browse_btn: Button
var _mat_box: HBoxContainer



func _ready() -> void:
	_build_ui()
	_setup_file_dialog()
	_setup_grid_dialog()
	_setup_stamp_dialog()
	_setup_material_dialog()
	if _canvas:
		_canvas.tolerance = _bg_tolerance

# --- UI Construction ---

func _build_ui() -> void:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(left)

	left.add_child(_make_toolbar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)

	_canvas = _CanvasScript.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.selection_changed.connect(_on_canvas_selection_changed)
	_canvas.rects_changed.connect(_on_rects_changed)
	_canvas.zoom_changed.connect(_on_canvas_zoom_changed)
	_canvas.erase_clicked.connect(_on_erase_clicked)
	_canvas.brush_erase_clicked.connect(_on_brush_erase_clicked)
	_canvas.brush_erase_dragged.connect(_on_brush_erase_dragged)
	_canvas.brush_erase_released.connect(_on_brush_erase_released)
	_canvas.brush_paint_clicked.connect(_on_brush_paint_clicked)
	_canvas.brush_paint_dragged.connect(_on_brush_paint_dragged)
	_canvas.brush_paint_released.connect(_on_brush_paint_released)
	_canvas.recolor_clicked.connect(_on_recolor_clicked)
	_canvas.stamp_pasted.connect(_on_canvas_stamp_pasted)
	_canvas.slice_action_started.connect(_push_slices_state)
	scroll.add_child(_canvas)

	add_child(_make_right_panel())

func _make_toolbar() -> Control:
	var tb_outer := VBoxContainer.new()
	tb_outer.add_theme_constant_override("separation", 2)

	# --- Row 1: File, Slice, Undo/Redo, Zoom ---
	var tb1 := HBoxContainer.new()
	tb1.add_theme_constant_override("separation", 4)
	tb_outer.add_child(tb1)

	var browse_btn := Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(_on_browse)
	tb1.add_child(browse_btn)

	_path_label = LineEdit.new()
	_path_label.editable              = false
	_path_label.placeholder_text      = "No texture selected"
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb1.add_child(_path_label)

	tb1.add_child(VSeparator.new())

	var auto_btn := Button.new()
	auto_btn.text = "Auto Slice"
	auto_btn.tooltip_text = "Detect sprites via flood-fill"
	auto_btn.pressed.connect(_on_auto_slice)
	tb1.add_child(auto_btn)

	var grid_btn := Button.new()
	grid_btn.text = "Grid Slice..."
	grid_btn.tooltip_text = "Slice into a uniform grid"
	grid_btn.pressed.connect(func():
		if _grid_dialog:
			_grid_dialog.popup_centered()
	)
	tb1.add_child(grid_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.tooltip_text = "Remove all slices"
	clear_btn.pressed.connect(_on_clear)
	tb1.add_child(clear_btn)

	tb1.add_child(VSeparator.new())

	_undo_btn = Button.new()
	_undo_btn.text = "Undo"
	_undo_btn.tooltip_text = "Undo last action (Ctrl+Z)"
	_undo_btn.disabled = true
	_undo_btn.pressed.connect(_undo)
	tb1.add_child(_undo_btn)

	_redo_btn = Button.new()
	_redo_btn.text = "Redo"
	_redo_btn.tooltip_text = "Redo (Ctrl+Y / Ctrl+Shift+Z)"
	_redo_btn.disabled = true
	_redo_btn.pressed.connect(_redo)
	tb1.add_child(_redo_btn)

	tb1.add_child(VSeparator.new())

	var zminus := Button.new()
	zminus.text = "-"
	zminus.custom_minimum_size = Vector2(26, 0)
	zminus.pressed.connect(func(): _canvas.set_zoom(_zoom / 1.25))
	tb1.add_child(zminus)

	_zoom_label = Label.new()
	_zoom_label.text                  = "100%"
	_zoom_label.custom_minimum_size   = Vector2(50, 0)
	_zoom_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	tb1.add_child(_zoom_label)

	var zplus := Button.new()
	zplus.text = "+"
	zplus.custom_minimum_size = Vector2(26, 0)
	zplus.pressed.connect(func(): _canvas.set_zoom(_zoom * 1.25))
	tb1.add_child(zplus)

	var extract_btn := Button.new()
	extract_btn.text = "Extract All"
	extract_btn.tooltip_text = "Export slices to disk"
	extract_btn.pressed.connect(_on_extract)
	tb1.add_child(extract_btn)

	# --- Row 2: Erase tools ---
	var tb2 := HBoxContainer.new()
	tb2.add_theme_constant_override("separation", 4)
	tb_outer.add_child(tb2)

	var remove_bg_btn := Button.new()
	remove_bg_btn.text = "Remove BG"
	remove_bg_btn.tooltip_text = "Remove background color using flood-fill"
	remove_bg_btn.pressed.connect(_on_remove_bg)
	tb2.add_child(remove_bg_btn)

	var tol_label := Label.new()
	tol_label.text = "Tol:"
	tb2.add_child(tol_label)

	var tol_spin := SpinBox.new()
	tol_spin.min_value = 1
	tol_spin.max_value = 80
	tol_spin.step = 1
	tol_spin.value = int(_bg_tolerance * 100)
	tol_spin.custom_minimum_size = Vector2(68, 0)
	tol_spin.suffix = "%"
	tol_spin.tooltip_text = "Background removal tolerance"
	tol_spin.value_changed.connect(func(v: float): 
		_bg_tolerance = v / 100.0
		if _canvas:
			_canvas.tolerance = _bg_tolerance
	)
	tb2.add_child(tol_spin)

	tb2.add_child(VSeparator.new())

	_wand_btn = Button.new()
	_wand_btn.text = "Magic Wand Erase"
	_wand_btn.toggle_mode = true
	_wand_btn.tooltip_text = "Click to erase matching color regions"
	_wand_btn.toggled.connect(_on_wand_toggled)
	tb2.add_child(_wand_btn)

	_brush_erase_btn = Button.new()
	_brush_erase_btn.text = "Brush Erase"
	_brush_erase_btn.toggle_mode = true
	_brush_erase_btn.tooltip_text = "Click and drag to erase pixels"
	_brush_erase_btn.toggled.connect(_on_brush_toggled)
	tb2.add_child(_brush_erase_btn)

	tb2.add_child(VSeparator.new())

	_recolor_btn = Button.new()
	_recolor_btn.text = "Magic Wand Recolor"
	_recolor_btn.toggle_mode = true
	_recolor_btn.tooltip_text = "Click to recolor matching color regions"
	_recolor_btn.toggled.connect(_on_recolor_toggled)
	tb2.add_child(_recolor_btn)

	_paint_btn = Button.new()
	_paint_btn.text = "Brush Paint"
	_paint_btn.toggle_mode = true
	_paint_btn.tooltip_text = "Click and drag to paint with color"
	_paint_btn.toggled.connect(_on_paint_toggled)
	tb2.add_child(_paint_btn)

	_color_picker = ColorPickerButton.new()
	_color_picker.color = Color.WHITE
	_color_picker.custom_minimum_size = Vector2(40, 0)
	_color_picker.tooltip_text = "Select paint/recolor color"
	_color_picker.color_changed.connect(func(col: Color):
		if _canvas:
			_canvas.paint_color = col
			_canvas.queue_redraw()
	)
	tb2.add_child(_color_picker)

	tb2.add_child(VSeparator.new())

	var stamp_btn := Button.new()
	stamp_btn.text = "Stamp..."
	stamp_btn.tooltip_text = "Paste an external PNG onto the canvas"
	stamp_btn.pressed.connect(func():
		if _stamp_dialog:
			_stamp_dialog.popup_centered_ratio(0.6)
	)
	tb2.add_child(stamp_btn)

	tb2.add_child(VSeparator.new())

	var brush_size_label := Label.new()
	brush_size_label.text = "Size:"
	tb2.add_child(brush_size_label)

	_brush_size_spin = SpinBox.new()
	_brush_size_spin.min_value = 1
	_brush_size_spin.max_value = 100
	_brush_size_spin.value = 8
	_brush_size_spin.step = 1
	_brush_size_spin.custom_minimum_size = Vector2(60, 0)
	_brush_size_spin.tooltip_text = "Brush radius"
	_brush_size_spin.value_changed.connect(func(val: float):
		if _canvas != null:
			_canvas.brush_size = int(val)
			_canvas.queue_redraw()
	)
	tb2.add_child(_brush_size_spin)
	if _canvas != null:
		_canvas.brush_size = 8

	return tb_outer

func _make_right_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	panel.size_flags_vertical  = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var list_header := HBoxContainer.new()
	list_header.add_theme_constant_override("separation", 4)
	vbox.add_child(list_header)

	_count_label = Label.new()
	_count_label.text = "SLICES (0)"
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(_count_label)

	var sel_all_btn := Button.new()
	sel_all_btn.text = "All"
	sel_all_btn.tooltip_text = "Select all slices (Ctrl + A)"
	sel_all_btn.pressed.connect(func():
		if _canvas and not _canvas.rects.is_empty():
			_canvas.selected_indices.clear()
			for i in range(_canvas.rects.size()):
				_canvas.selected_indices.append(i)
			_canvas.selection_changed.emit(_canvas.selected_indices)
			_canvas.queue_redraw()
	)
	list_header.add_child(sel_all_btn)

	var desel_all_btn := Button.new()
	desel_all_btn.text = "None"
	desel_all_btn.tooltip_text = "Deselect all slices (Escape)"
	desel_all_btn.pressed.connect(func():
		if _canvas and not _canvas.selected_indices.is_empty():
			_canvas.selected_indices.clear()
			_canvas.selection_changed.emit(_canvas.selected_indices)
			_canvas.queue_redraw()
	)
	list_header.add_child(desel_all_btn)

	_slice_list = ItemList.new()
	_slice_list.select_mode = ItemList.SELECT_MULTI
	_slice_list.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	_slice_list.custom_minimum_size  = Vector2(0, 80)
	_slice_list.item_selected.connect(_on_list_item_selected)
	vbox.add_child(_slice_list)

	vbox.add_child(HSeparator.new())

	_props_box = VBoxContainer.new()
	_props_box.add_theme_constant_override("separation", 4)
	_props_box.visible = false
	vbox.add_child(_props_box)

	var props_title := Label.new()
	props_title.text = "Selected Slice"
	_props_box.add_child(props_title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Custom Name"
	_name_edit.text_changed.connect(_on_name_changed)
	_props_box.add_child(_name_edit)

	_mat_box = HBoxContainer.new()
	_mat_box.add_theme_constant_override("separation", 4)
	_props_box.add_child(_mat_box)
	
	_mat_edit = LineEdit.new()
	_mat_edit.placeholder_text = "No Material/Shader"
	_mat_edit.editable = false
	_mat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mat_box.add_child(_mat_edit)
	
	_mat_browse_btn = Button.new()
	_mat_browse_btn.text = "..."
	_mat_browse_btn.tooltip_text = "Select Shader/Material file (.tres)"
	_mat_browse_btn.pressed.connect(func():
		if _material_dialog:
			_material_dialog.popup_centered_ratio(0.5)
	)
	_mat_box.add_child(_mat_browse_btn)

	_props_grid = GridContainer.new()
	_props_grid.columns = 2
	_props_grid.add_theme_constant_override("h_separation", 4)
	_props_grid.add_theme_constant_override("v_separation", 3)
	_props_box.add_child(_props_grid)

	_spin_x = _make_spin("X", _props_grid)
	_spin_y = _make_spin("Y", _props_grid)
	_spin_w = _make_spin("W", _props_grid)
	_spin_h = _make_spin("H", _props_grid)

	for sb in [_spin_x, _spin_y, _spin_w, _spin_h]:
		sb.value_changed.connect(func(_v: float) -> void: _on_prop_changed())

	var actions_grid := GridContainer.new()
	actions_grid.columns = 2
	actions_grid.add_theme_constant_override("h_separation", 4)
	actions_grid.add_theme_constant_override("v_separation", 4)
	_props_box.add_child(actions_grid)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.tooltip_text = "Delete selected slices (Delete / Backspace)"
	del_btn.pressed.connect(_on_delete_selected)
	actions_grid.add_child(del_btn)

	var dup_btn := Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.tooltip_text = "Duplicate selected slices (Ctrl + D)"
	dup_btn.pressed.connect(func():
		if _canvas and not _canvas.selected_indices.is_empty():
			_canvas._duplicate_selected_rects()
	)
	actions_grid.add_child(dup_btn)

	_merge_btn = Button.new()
	_merge_btn.text = "Merge"
	_merge_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_merge_btn.tooltip_text = "Merge selected slices into one (Ctrl + M)"
	_merge_btn.pressed.connect(func():
		if _canvas and _canvas.selected_indices.size() >= 2:
			_canvas._merge_selected_rects()
	)
	actions_grid.add_child(_merge_btn)

	_lock_btn = Button.new()
	_lock_btn.text = "Lock"
	_lock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lock_btn.tooltip_text = "Lock/Unlock selected slices to prevent editing (L)"
	_lock_btn.pressed.connect(_on_lock_toggle)
	actions_grid.add_child(_lock_btn)

	vbox.add_child(HSeparator.new())

	var exp_lbl := Label.new()
	exp_lbl.text = "Export Formats"
	vbox.add_child(exp_lbl)

	_chk_png = CheckBox.new()
	_chk_png.text = "PNG Slices (.png)"
	_chk_png.button_pressed = true
	vbox.add_child(_chk_png)

	_chk_atlas = CheckBox.new()
	_chk_atlas.text = "AtlasTexture (.tres)"
	_chk_atlas.button_pressed = false
	vbox.add_child(_chk_atlas)

	var sf_box := HBoxContainer.new()
	sf_box.add_theme_constant_override("separation", 4)
	vbox.add_child(sf_box)

	_chk_spriteframes = CheckBox.new()
	_chk_spriteframes.text = "SpriteFrames"
	_chk_spriteframes.button_pressed = false
	sf_box.add_child(_chk_spriteframes)

	_anim_name_edit = LineEdit.new()
	_anim_name_edit.placeholder_text = "Anim: default"
	_anim_name_edit.custom_minimum_size = Vector2(80, 0)
	_anim_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sf_box.add_child(_anim_name_edit)

	vbox.add_child(HSeparator.new())

	var snap_title := Label.new()
	snap_title.text = "Grid Snapping"
	vbox.add_child(snap_title)

	_chk_snap = CheckBox.new()
	_chk_snap.text = "Snap to Grid"
	_chk_snap.button_pressed = false
	_chk_snap.toggled.connect(func(t: bool):
		if _canvas:
			_canvas.snap_to_grid = t
			_canvas.queue_redraw()
	)
	vbox.add_child(_chk_snap)

	var snap_grid := GridContainer.new()
	snap_grid.columns = 2
	snap_grid.add_theme_constant_override("h_separation", 6)
	snap_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(snap_grid)

	var snap_w_lbl := Label.new()
	snap_w_lbl.text = "Snap W:"
	snap_grid.add_child(snap_w_lbl)

	_spin_snap_w = SpinBox.new()
	_spin_snap_w.min_value = 1
	_spin_snap_w.max_value = 1024
	_spin_snap_w.value = 16
	_spin_snap_w.step = 1
	_spin_snap_w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_snap_w.value_changed.connect(func(v: float):
		if _canvas:
			_canvas.snap_w = int(v)
	)
	snap_grid.add_child(_spin_snap_w)

	var snap_h_lbl := Label.new()
	snap_h_lbl.text = "Snap H:"
	snap_grid.add_child(snap_h_lbl)

	_spin_snap_h = SpinBox.new()
	_spin_snap_h.min_value = 1
	_spin_snap_h.max_value = 1024
	_spin_snap_h.value = 16
	_spin_snap_h.step = 1
	_spin_snap_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_snap_h.value_changed.connect(func(v: float):
		if _canvas:
			_canvas.snap_h = int(v)
	)
	snap_grid.add_child(_spin_snap_h)

	vbox.add_child(HSeparator.new())
	_preview_player = _PreviewPlayerScript.new()
	vbox.add_child(_preview_player)

	return panel

func _make_spin(lbl_text: String, parent: Control) -> SpinBox:
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(16, 0)
	parent.add_child(lbl)

	var sb := SpinBox.new()
	sb.min_value              = 0
	sb.max_value              = 8192
	sb.step                   = 1
	sb.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	parent.add_child(sb)
	return sb

# --- Dialog setup ---

func _setup_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.title = "Select Texture"
	_file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.svg", "Image Files")
	_file_dialog.file_selected.connect(_load_texture)
	add_child(_file_dialog)

func _setup_stamp_dialog() -> void:
	_stamp_dialog = FileDialog.new()
	_stamp_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_stamp_dialog.access = FileDialog.ACCESS_RESOURCES
	_stamp_dialog.title = "Select Stamp Image"
	_stamp_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.svg", "Image Files")
	_stamp_dialog.file_selected.connect(_load_stamp_image)
	add_child(_stamp_dialog)

func _setup_material_dialog() -> void:
	_material_dialog = FileDialog.new()
	_material_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_material_dialog.access = FileDialog.ACCESS_RESOURCES
	_material_dialog.title = "Select Shader/Material Resource"
	_material_dialog.add_filter("*.tres, *.material", "Material Files")
	_material_dialog.file_selected.connect(_assign_material_to_selected)
	add_child(_material_dialog)

func _setup_grid_dialog() -> void:
	_grid_dialog = ConfirmationDialog.new()
	_grid_dialog.title = "Grid Slice Settings"
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	
	# Cell Width
	var lbl_w := Label.new()
	lbl_w.text = "Cell Width:"
	grid.add_child(lbl_w)
	_grid_spin_w = SpinBox.new()
	_grid_spin_w.min_value = 1
	_grid_spin_w.max_value = 8192
	_grid_spin_w.value = 32
	grid.add_child(_grid_spin_w)
	
	# Cell Height
	var lbl_h := Label.new()
	lbl_h.text = "Cell Height:"
	grid.add_child(lbl_h)
	_grid_spin_h = SpinBox.new()
	_grid_spin_h.min_value = 1
	_grid_spin_h.max_value = 8192
	_grid_spin_h.value = 32
	grid.add_child(_grid_spin_h)
	
	# Offset X
	var lbl_off_x := Label.new()
	lbl_off_x.text = "Offset X:"
	grid.add_child(lbl_off_x)
	_grid_spin_off_x = SpinBox.new()
	_grid_spin_off_x.min_value = 0
	_grid_spin_off_x.max_value = 8192
	_grid_spin_off_x.value = 0
	grid.add_child(_grid_spin_off_x)
	
	# Offset Y
	var lbl_off_y := Label.new()
	lbl_off_y.text = "Offset Y:"
	grid.add_child(lbl_off_y)
	_grid_spin_off_y = SpinBox.new()
	_grid_spin_off_y.min_value = 0
	_grid_spin_off_y.max_value = 8192
	_grid_spin_off_y.value = 0
	grid.add_child(_grid_spin_off_y)
	
	# Padding/Separation X
	var lbl_sep_x := Label.new()
	lbl_sep_x.text = "Separation X:"
	grid.add_child(lbl_sep_x)
	_grid_spin_sep_x = SpinBox.new()
	_grid_spin_sep_x.min_value = 0
	_grid_spin_sep_x.max_value = 1024
	_grid_spin_sep_x.value = 0
	grid.add_child(_grid_spin_sep_x)
	
	# Padding/Separation Y
	var lbl_sep_y := Label.new()
	lbl_sep_y.text = "Separation Y:"
	grid.add_child(lbl_sep_y)
	_grid_spin_sep_y = SpinBox.new()
	_grid_spin_sep_y.min_value = 0
	_grid_spin_sep_y.max_value = 1024
	_grid_spin_sep_y.value = 0
	grid.add_child(_grid_spin_sep_y)
	
	# Keep Empty
	var lbl_keep := Label.new()
	lbl_keep.text = "Keep Empty Slices:"
	grid.add_child(lbl_keep)
	_grid_chk_keep_empty = CheckBox.new()
	_grid_chk_keep_empty.button_pressed = false
	grid.add_child(_grid_chk_keep_empty)
	
	_grid_dialog.add_child(grid)
	_grid_dialog.confirmed.connect(_on_grid_slice_confirmed)
	add_child(_grid_dialog)

func _on_grid_slice_confirmed() -> void:
	if not _current_tex:
		return
	var img := _current_tex.get_image()
	if not img or img.is_empty():
		return
	var cell_w := int(_grid_spin_w.value)
	var cell_h := int(_grid_spin_h.value)
	var off_x := int(_grid_spin_off_x.value)
	var off_y := int(_grid_spin_off_y.value)
	var sep_x := int(_grid_spin_sep_x.value)
	var sep_y := int(_grid_spin_sep_y.value)
	var keep_empty := _grid_chk_keep_empty.button_pressed
	
	_push_slices_state()
	var rects := _AutoSlicer.slice_grid(img, cell_w, cell_h, off_x, off_y, sep_x, sep_y, keep_empty)
	_canvas.set_rects(rects)
	_refresh_list()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

func _on_browse() -> void:
	if _file_dialog:
		_file_dialog.popup_centered_ratio(0.6)

# --- Action handlers ---

func _load_texture(path: String) -> void:
	var tex = load(path)
	if not tex is Texture2D:
		return
	_undo_stack.clear()
	_redo_stack.clear()
	_update_history_buttons()
	_current_tex      = tex
	_current_tex_path = path
	_path_label.text  = path.get_file()
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

func _on_extract() -> void:
	if not _current_tex or _canvas.rects.is_empty():
		return
	var a_name := "default"
	if _anim_name_edit and _anim_name_edit.text.strip_edges() != "":
		a_name = _anim_name_edit.text.strip_edges()
	_Extractor.extract(_current_tex, _canvas.rects,
		_chk_png.button_pressed,
		_chk_atlas.button_pressed,
		_chk_spriteframes.button_pressed,
		_current_tex_path, _canvas.slice_names,
		a_name,
		_canvas.slice_materials)

func _select_tool(tool_name: String) -> void:
	var wand_on := (tool_name == "wand")
	var brush_erase_on := (tool_name == "brush_erase")
	var recolor_on := (tool_name == "recolor")
	var paint_on := (tool_name == "paint")
	var stamp_on := (tool_name == "stamp")
	
	_wand_btn.set_pressed_no_signal(wand_on)
	_brush_erase_btn.set_pressed_no_signal(brush_erase_on)
	if _recolor_btn:
		_recolor_btn.set_pressed_no_signal(recolor_on)
	if _paint_btn:
		_paint_btn.set_pressed_no_signal(paint_on)
		
	if _canvas:
		_canvas.erase_mode = wand_on
		_canvas.brush_erase_mode = brush_erase_on
		_canvas.recolor_mode = recolor_on
		_canvas.paint_mode = paint_on
		_canvas.stamp_mode = stamp_on
		if not stamp_on:
			_canvas.stamp_tex = null
		_canvas.queue_redraw()

func _on_wand_toggled(toggled: bool) -> void:
	_select_tool("wand" if toggled else "")

func _on_brush_toggled(toggled: bool) -> void:
	_select_tool("brush_erase" if toggled else "")

func _on_recolor_toggled(toggled: bool) -> void:
	_select_tool("recolor" if toggled else "")

func _on_paint_toggled(toggled: bool) -> void:
	_select_tool("paint" if toggled else "")

func _load_stamp_image(path: String) -> void:
	var tex = load(path)
	if tex is Texture2D and _canvas:
		_canvas.stamp_tex = tex
		_select_tool("stamp")

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

func _on_canvas_stamp_pasted(img_pos: Vector2i, stamp_tex: Texture2D) -> void:
	if not _current_tex or _current_tex_path.is_empty() or not stamp_tex:
		return
	_push_image_state()
	_ensure_edited_path()
	var base_img := _current_tex.get_image()
	var stamp_img := stamp_tex.get_image()
	var result := _BgRemover.paste_stamp(base_img, stamp_img, img_pos.x, img_pos.y)
	if result == null or result.is_empty():
		return
		
	if _current_tex is ImageTexture:
		_current_tex.update(result)
		_canvas.queue_redraw()
	else:
		var new_tex := ImageTexture.create_from_image(result)
		_current_tex = new_tex
		_canvas.update_texture(new_tex)
	_save_edited_texture()

func _on_brush_erase_clicked(img_pos: Vector2i) -> void:
	_push_image_state()
	_ensure_edited_path()
	_do_brush_erase(img_pos)

func _on_brush_erase_dragged(img_pos: Vector2i) -> void:
	_do_brush_erase(img_pos)

func _on_brush_erase_released() -> void:
	_save_edited_texture()

func _do_brush_erase(img_pos: Vector2i) -> void:
	if not _current_tex or _current_tex_path.is_empty():
		return
	var src_img := _current_tex.get_image()
	var b_size: int = 8
	if _brush_size_spin != null:
		b_size = int(_brush_size_spin.value)
	var result := _BgRemover.brush_erase(src_img, img_pos.x, img_pos.y, b_size)
	if result == null or result.is_empty():
		return

	if _current_tex is ImageTexture:
		_current_tex.update(result)
		_canvas.queue_redraw()
	else:
		var new_tex := ImageTexture.create_from_image(result)
		_current_tex = new_tex
		_canvas.update_texture(new_tex)

func _on_brush_paint_clicked(img_pos: Vector2i) -> void:
	_push_image_state()
	_ensure_edited_path()
	_do_brush_paint(img_pos)

func _on_brush_paint_dragged(img_pos: Vector2i) -> void:
	_do_brush_paint(img_pos)

func _on_brush_paint_released() -> void:
	_save_edited_texture()

func _do_brush_paint(img_pos: Vector2i) -> void:
	if not _current_tex or _current_tex_path.is_empty():
		return
	var src_img := _current_tex.get_image()
	var b_size: int = 8
	if _brush_size_spin != null:
		b_size = int(_brush_size_spin.value)
	var col := _color_picker.color if _color_picker else Color.WHITE
	var result := _BgRemover.brush_paint(src_img, img_pos.x, img_pos.y, b_size, col)
	if result == null or result.is_empty():
		return

	if _current_tex is ImageTexture:
		_current_tex.update(result)
		_canvas.queue_redraw()
	else:
		var new_tex := ImageTexture.create_from_image(result)
		_current_tex = new_tex
		_canvas.update_texture(new_tex)

func _on_recolor_clicked(img_pos: Vector2i) -> void:
	if not _current_tex or _current_tex_path.is_empty():
		return
	_push_image_state()
	_ensure_edited_path()
	var src_img := _current_tex.get_image()
	var col := _color_picker.color if _color_picker else Color.WHITE
	var result := _BgRemover.magic_wand_recolor(src_img, img_pos.x, img_pos.y, col, _bg_tolerance)
	if result == null or result.is_empty():
		return
	var abs_out := ProjectSettings.globalize_path(_current_tex_path)
	var err := result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG: " + abs_out)
		return
	var new_tex := ImageTexture.create_from_image(result)
	_current_tex = new_tex
	_canvas.update_texture(new_tex)

func _on_erase_clicked(img_pos: Vector2i) -> void:
	if not _current_tex or _current_tex_path.is_empty():
		return
	_push_image_state()
	_ensure_edited_path()
	var src_img := _current_tex.get_image()
	var result := _BgRemover.magic_wand_erase(src_img, img_pos.x, img_pos.y, _bg_tolerance)
	if result == null or result.is_empty():
		return
		
	var abs_out := ProjectSettings.globalize_path(_current_tex_path)
	var err := result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG back to disk: " + abs_out)
		return
		
	var new_tex := ImageTexture.create_from_image(result)
	_current_tex = new_tex
	_canvas.update_texture(new_tex)

func _ensure_edited_path() -> void:
	if _current_tex_path.is_empty():
		return
	var base_dir := _current_tex_path.get_base_dir()
	var base_name := _current_tex_path.get_file().get_basename()
	if not (base_name.ends_with("_nobg") or base_name.ends_with("_edited")):
		_current_tex_path = base_dir + "/" + base_name + "_edited.png"
		_path_label.text = base_name + "_edited.png"

func _save_edited_texture() -> void:
	if not _current_tex or _current_tex_path.is_empty():
		return
	var abs_out := ProjectSettings.globalize_path(_current_tex_path)
	var err: Error = _current_tex.get_image().save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG back to disk: " + abs_out)

func _on_remove_bg() -> void:
	if _current_tex_path.is_empty():
		push_error("SpriteSlicer: No texture path available.")
		return
	_push_image_state()

	var abs_src: String = ProjectSettings.globalize_path(_current_tex_path)
	var src_img: Image = Image.load_from_file(abs_src)
	if src_img == null or src_img.is_empty():
		push_error("SpriteSlicer: Could not load file: " + abs_src)
		return

	var result: Image = _BgRemover.remove(src_img, _bg_tolerance, true)
	if result == null or result.is_empty():
		push_error("SpriteSlicer: Background removal returned empty image.")
		return

	var base_dir: String = _current_tex_path.get_base_dir()
	var base_name: String = _current_tex_path.get_file().get_basename()
	var res_out: String = base_dir + "/" + base_name + "_nobg.png"
	var abs_out: String = ProjectSettings.globalize_path(res_out)
	var err: Error = result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save PNG: " + abs_out + " (error " + str(err) + ")")
		return

	var new_tex := ImageTexture.create_from_image(result)
	_current_tex      = new_tex
	_current_tex_path = res_out
	_path_label.text  = base_name + "_nobg.png"
	_canvas.update_texture(new_tex)
	_canvas.set_zoom(_zoom)
	_refresh_list()
	_update_props()
	if _preview_player:
		_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

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
	_undo_stack.append(state)
	_redo_stack.clear()
	if _undo_stack.size() > 30:
		_undo_stack.remove_at(0)
	_update_history_buttons()

func _push_image_state() -> void:
	if not _current_tex:
		return
	var img = _current_tex.get_image()
	if img and not img.is_empty():
		var img_copy = Image.new()
		img_copy.copy_from(img)
		_push_history_state({
			"type": "image",
			"image": img_copy,
			"path": _current_tex_path
		})

func _push_slices_state() -> void:
	if not _canvas:
		return
	_push_history_state({
		"type": "slices",
		"rects": _canvas.rects.duplicate(),
		"slice_names": _canvas.slice_names.duplicate(),
		"slice_materials": _canvas.slice_materials.duplicate(),
		"selected_indices": _canvas.selected_indices.duplicate(),
		"locked_states": _canvas.locked_states.duplicate()
	})

func _update_history_buttons() -> void:
	if _undo_btn:
		_undo_btn.disabled = _undo_stack.is_empty()
	if _redo_btn:
		_redo_btn.disabled = _redo_stack.is_empty()

func _undo() -> void:
	if _undo_stack.is_empty():
		return
		
	var prev_state = _undo_stack.pop_back()
	var current_state := {}
	
	if prev_state["type"] == "image":
		var img = _current_tex.get_image()
		var img_copy = Image.new()
		img_copy.copy_from(img)
		current_state = {
			"type": "image",
			"image": img_copy,
			"path": _current_tex_path
		}
		
		var prev_img: Image = prev_state["image"]
		var prev_path: String = prev_state["path"]
		var abs_out := ProjectSettings.globalize_path(prev_path)
		var err = prev_img.save_png(abs_out)
		if err == OK:
			_current_tex_path = prev_path
			_path_label.text = prev_path.get_file()
			var new_tex := ImageTexture.create_from_image(prev_img)
			_current_tex = new_tex
			_canvas.load_texture(new_tex)
			if _preview_player:
				_preview_player.sync_preview(new_tex, _canvas.rects, _canvas.selected_indices)
	elif prev_state["type"] == "slices":
		current_state = {
			"type": "slices",
			"rects": _canvas.rects.duplicate(),
			"slice_names": _canvas.slice_names.duplicate(),
			"slice_materials": _canvas.slice_materials.duplicate(),
			"selected_indices": _canvas.selected_indices.duplicate(),
			"locked_states": _canvas.locked_states.duplicate()
		}
		
		_canvas.rects = prev_state["rects"].duplicate()
		_canvas.slice_names = prev_state["slice_names"].duplicate()
		_canvas.slice_materials = prev_state.get("slice_materials", []).duplicate()
		# Out-of-bounds protection guard
		while _canvas.slice_materials.size() < _canvas.rects.size():
			_canvas.slice_materials.append("")
		while _canvas.slice_names.size() < _canvas.rects.size():
			_canvas.slice_names.append("")
			
		_canvas.selected_indices = prev_state["selected_indices"].duplicate()
		_canvas.locked_states = prev_state["locked_states"].duplicate()
		_canvas.queue_redraw()
		_refresh_list()
		_update_props()
		if _preview_player:
			_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)
			
	_redo_stack.append(current_state)
	_update_history_buttons()

func _redo() -> void:
	if _redo_stack.is_empty():
		return
		
	var next_state = _redo_stack.pop_back()
	var current_state := {}
	
	if next_state["type"] == "image":
		var img = _current_tex.get_image()
		var img_copy = Image.new()
		img_copy.copy_from(img)
		current_state = {
			"type": "image",
			"image": img_copy,
			"path": _current_tex_path
		}
		
		var next_img: Image = next_state["image"]
		var next_path: String = next_state["path"]
		var abs_out := ProjectSettings.globalize_path(next_path)
		var err = next_img.save_png(abs_out)
		if err == OK:
			_current_tex_path = next_path
			_path_label.text = next_path.get_file()
			var new_tex := ImageTexture.create_from_image(next_img)
			_current_tex = new_tex
			_canvas.load_texture(new_tex)
			if _preview_player:
				_preview_player.sync_preview(new_tex, _canvas.rects, _canvas.selected_indices)
	elif next_state["type"] == "slices":
		current_state = {
			"type": "slices",
			"rects": _canvas.rects.duplicate(),
			"slice_names": _canvas.slice_names.duplicate(),
			"slice_materials": _canvas.slice_materials.duplicate(),
			"selected_indices": _canvas.selected_indices.duplicate(),
			"locked_states": _canvas.locked_states.duplicate()
		}
		
		_canvas.rects = next_state["rects"].duplicate()
		_canvas.slice_names = next_state["slice_names"].duplicate()
		_canvas.slice_materials = next_state.get("slice_materials", []).duplicate()
		# Out-of-bounds protection guard
		while _canvas.slice_materials.size() < _canvas.rects.size():
			_canvas.slice_materials.append("")
		while _canvas.slice_names.size() < _canvas.rects.size():
			_canvas.slice_names.append("")
			
		_canvas.selected_indices = next_state["selected_indices"].duplicate()
		_canvas.locked_states = next_state["locked_states"].duplicate()
		_canvas.queue_redraw()
		_refresh_list()
		_update_props()
		if _preview_player:
			_preview_player.sync_preview(_current_tex, _canvas.rects, _canvas.selected_indices)
			
	_undo_stack.append(current_state)
	_update_history_buttons()
