@tool
extends HBoxContainer

# Preloads
const _AutoSlicer   = preload("res://addons/sprite_slicer/auto_slicer.gd")
const _Extractor    = preload("res://addons/sprite_slicer/extractor.gd")
const _CanvasScript = preload("res://addons/sprite_slicer/slicer_canvas.gd")
const _BgRemover    = preload("res://addons/sprite_slicer/bg_remover.gd")

# UI References
var _canvas
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
var _props_grid: GridContainer

# State
var _current_tex:      Texture2D
var _current_tex_path: String  = ""
var _zoom:             float   = 1.0
var _updating_props:   bool    = false
var _bg_tolerance:     float   = 0.18

func _ready() -> void:
	_build_ui()
	_setup_file_dialog()

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
	scroll.add_child(_canvas)

	add_child(_make_right_panel())

func _make_toolbar() -> HBoxContainer:
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 4)

	var browse_btn := Button.new()
	browse_btn.text = "Browse..."
	browse_btn.pressed.connect(_on_browse)
	tb.add_child(browse_btn)

	_path_label = LineEdit.new()
	_path_label.editable              = false
	_path_label.placeholder_text      = "No texture selected"
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(_path_label)

	tb.add_child(VSeparator.new())

	var remove_bg_btn := Button.new()
	remove_bg_btn.text = "Remove BG"
	remove_bg_btn.tooltip_text = "Remove background color using flood-fill"
	remove_bg_btn.pressed.connect(_on_remove_bg)
	tb.add_child(remove_bg_btn)

	var tol_label := Label.new()
	tol_label.text = "Tol:"
	tb.add_child(tol_label)

	var tol_spin := SpinBox.new()
	tol_spin.min_value = 1
	tol_spin.max_value = 80
	tol_spin.step = 1
	tol_spin.value = int(_bg_tolerance * 100)
	tol_spin.custom_minimum_size = Vector2(68, 0)
	tol_spin.suffix = "%"
	tol_spin.tooltip_text = "Background removal tolerance"
	tol_spin.value_changed.connect(func(v: float): _bg_tolerance = v / 100.0)
	tb.add_child(tol_spin)

	tb.add_child(VSeparator.new())

	var auto_btn := Button.new()
	auto_btn.text = "Auto Slice"
	auto_btn.pressed.connect(_on_auto_slice)
	tb.add_child(auto_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear)
	tb.add_child(clear_btn)

	tb.add_child(VSeparator.new())

	var zminus := Button.new()
	zminus.text = "-"
	zminus.custom_minimum_size = Vector2(26, 0)
	zminus.pressed.connect(func(): _canvas.set_zoom(_zoom / 1.25))
	tb.add_child(zminus)

	_zoom_label = Label.new()
	_zoom_label.text                  = "100%"
	_zoom_label.custom_minimum_size   = Vector2(50, 0)
	_zoom_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(_zoom_label)

	var zplus := Button.new()
	zplus.text = "+"
	zplus.custom_minimum_size = Vector2(26, 0)
	zplus.pressed.connect(func(): _canvas.set_zoom(_zoom * 1.25))
	tb.add_child(zplus)

	tb.add_child(VSeparator.new())

	_wand_btn = Button.new()
	_wand_btn.text = "Magic Wand Erase"
	_wand_btn.toggle_mode = true
	_wand_btn.tooltip_text = "Click on canvas to erase color regions (Magic Wand style)"
	_wand_btn.toggled.connect(_on_wand_toggled)
	tb.add_child(_wand_btn)

	_brush_erase_btn = Button.new()
	_brush_erase_btn.text = "Brush Erase"
	_brush_erase_btn.toggle_mode = true
	_brush_erase_btn.tooltip_text = "Click and drag on canvas to erase pixels (Brush style)"
	_brush_erase_btn.toggled.connect(_on_brush_toggled)
	tb.add_child(_brush_erase_btn)

	var extract_btn := Button.new()
	extract_btn.text = "Extract All"
	extract_btn.pressed.connect(_on_extract)
	tb.add_child(extract_btn)

	return tb

func _make_right_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	panel.size_flags_vertical  = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	_count_label = Label.new()
	_count_label.text = "SLICES (0)"
	vbox.add_child(_count_label)

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

	var del_btn := Button.new()
	del_btn.text = "Delete Selected"
	del_btn.pressed.connect(_on_delete_selected)
	_props_box.add_child(del_btn)

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

	_chk_spriteframes = CheckBox.new()
	_chk_spriteframes.text = "SpriteFrames (.tres)"
	_chk_spriteframes.button_pressed = false
	vbox.add_child(_chk_spriteframes)

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

func _on_browse() -> void:
	if _file_dialog:
		_file_dialog.popup_centered_ratio(0.6)

# --- Action handlers ---

func _load_texture(path: String) -> void:
	var tex = load(path)
	if not tex is Texture2D:
		return
	_current_tex      = tex
	_current_tex_path = path
	_path_label.text  = path.get_file()
	_canvas.load_texture(tex)
	_canvas.set_zoom(1.0)
	_refresh_list()
	_update_props()

func _on_auto_slice() -> void:
	if not _current_tex:
		return
	_canvas.set_rects(_AutoSlicer.slice(_current_tex.get_image()))
	_refresh_list()
	_update_props()

func _on_clear() -> void:
	_canvas.rects.clear()
	_canvas.selected_indices.clear()
	_canvas.queue_redraw()
	_refresh_list()
	_update_props()

func _on_extract() -> void:
	if not _current_tex or _canvas.rects.is_empty():
		return
	_Extractor.extract(_current_tex, _canvas.rects,
		_chk_png.button_pressed,
		_chk_atlas.button_pressed,
		_chk_spriteframes.button_pressed,
		_current_tex_path, _canvas.slice_names)

func _on_wand_toggled(toggled: bool) -> void:
	_canvas.erase_mode = toggled
	if toggled:
		_brush_erase_btn.set_pressed_no_signal(false)
		_canvas.brush_erase_mode = false

func _on_brush_toggled(toggled: bool) -> void:
	_canvas.brush_erase_mode = toggled
	if toggled:
		_wand_btn.set_pressed_no_signal(false)
		_canvas.erase_mode = false

func _on_brush_erase_clicked(img_pos: Vector2i) -> void:
	_do_brush_erase(img_pos)

func _on_brush_erase_dragged(img_pos: Vector2i) -> void:
	_do_brush_erase(img_pos)

func _do_brush_erase(img_pos: Vector2i) -> void:
	if not _current_tex or _current_tex_path.is_empty():
		return
	var src_img := _current_tex.get_image()
	var result := _BgRemover.brush_erase(src_img, img_pos.x, img_pos.y, 8)
	if result == null or result.is_empty():
		return
		
	var base_dir := _current_tex_path.get_base_dir()
	var base_name := _current_tex_path.get_file().get_basename()
	var target_path := _current_tex_path
	if not (base_name.ends_with("_nobg") or base_name.ends_with("_edited")):
		target_path = base_dir + "/" + base_name + "_edited.png"
		_current_tex_path = target_path
		_path_label.text = base_name + "_edited.png"
		
	var abs_out := ProjectSettings.globalize_path(target_path)
	var err := result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG back to disk: " + abs_out)
		return
		
	var new_tex := ImageTexture.create_from_image(result)
	_current_tex = new_tex
	_canvas.load_texture(new_tex)

func _on_erase_clicked(img_pos: Vector2i) -> void:
	if not _current_tex or _current_tex_path.is_empty():
		return
	var src_img := _current_tex.get_image()
	var result := _BgRemover.magic_wand_erase(src_img, img_pos.x, img_pos.y, _bg_tolerance)
	if result == null or result.is_empty():
		return
		
	var base_dir := _current_tex_path.get_base_dir()
	var base_name := _current_tex_path.get_file().get_basename()
	var target_path := _current_tex_path
	if not (base_name.ends_with("_nobg") or base_name.ends_with("_edited")):
		target_path = base_dir + "/" + base_name + "_edited.png"
		_current_tex_path = target_path
		_path_label.text = base_name + "_edited.png"
		
	var abs_out := ProjectSettings.globalize_path(target_path)
	var err := result.save_png(abs_out)
	if err != OK:
		push_error("SpriteSlicer: Could not save edited PNG back to disk: " + abs_out)
		return
		
	var new_tex := ImageTexture.create_from_image(result)
	_current_tex = new_tex
	_canvas.load_texture(new_tex)

func _on_remove_bg() -> void:
	if _current_tex_path.is_empty():
		push_error("SpriteSlicer: No texture path available.")
		return

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
	_canvas.load_texture(new_tex)
	_canvas.set_zoom(_zoom)
	_canvas.rects.clear()
	_canvas.selected_indices.clear()
	_refresh_list()
	_update_props()

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _on_delete_selected() -> void:
	if _canvas.selected_indices.is_empty():
		return
	_canvas._delete_selected_rects()




# --- Signal connections ---

func _on_canvas_zoom_changed(z: float) -> void:
	_zoom = z
	_zoom_label.text = str(int(round(z * 100))) + "%"

func _on_canvas_selection_changed(indices: Array) -> void:
	_sync_list_highlight(indices)
	_update_props()

func _on_rects_changed() -> void:
	_refresh_list()
	_update_props()

func _on_list_item_selected(_index: int) -> void:
	var selected: PackedInt32Array = _slice_list.get_selected_items()
	var canvas_selected: Array = []
	for idx in selected:
		canvas_selected.append(idx)
	_canvas.selected_indices = canvas_selected
	_canvas.queue_redraw()
	_update_props()

func _on_prop_changed() -> void:
	if _updating_props:
		return
	if _canvas.selected_indices.size() != 1:
		return
	var idx: int = _canvas.selected_indices[0]
	if idx < 0 or idx >= _canvas.rects.size():
		return
	_canvas.rects[idx] = Rect2(_spin_x.value, _spin_y.value, _spin_w.value, _spin_h.value)
	_canvas.queue_redraw()
	_update_list_item(idx)

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
		for i in range(_canvas.selected_indices.size()):
			var idx: int = _canvas.selected_indices[i]
			if idx < 0 or idx >= _canvas.slice_names.size():
				continue
			if i == 0:
				_canvas.slice_names[idx] = new_text
			else:
				_canvas.slice_names[idx] = new_text + "_" + str(i)
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
	return "%sSlice %d  (%d,%d)  %dx%d" % [custom_name, i,
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
	
	if _canvas.selected_indices.size() == 1:
		var idx: int = _canvas.selected_indices[0]
		if idx < 0 or idx >= _canvas.rects.size():
			_props_box.visible = false
			_updating_props = false
			return
		_props_grid.visible = true
		var r: Rect2 = _canvas.rects[idx]
		var cname = ""
		if idx < _canvas.slice_names.size():
			cname = _canvas.slice_names[idx]
		_name_edit.text = cname
		_name_edit.placeholder_text = "Custom Name"
		_spin_x.value = r.position.x
		_spin_y.value = r.position.y
		_spin_w.value = r.size.x
		_spin_h.value = r.size.y
	else:
		_props_grid.visible = false
		_name_edit.text = ""
		_name_edit.placeholder_text = "Seq Name (e.g. chest)"
	_updating_props = false
