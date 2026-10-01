@tool
extends RefCounted

## Builds the scrollable sidebar, properties and animation preview.
var _ui

func _init(host) -> void:
	_ui = host

func _make_right_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical  = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 10)
	margin.add_child(sidebar)
	# Keep animation feedback visible while browsing properties and export settings.
	_ui._preview_player = _ui._PreviewPlayerScript.new()
	sidebar.add_child(_ui._preview_player)
	sidebar.add_child(HSeparator.new())
	var scroll = ScrollContainer.new()
	scroll.name = "SidebarScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_FILL
	scroll.add_child(vbox)

	var list_header = HBoxContainer.new()
	list_header.add_theme_constant_override("separation", 4)
	vbox.add_child(list_header)

	_ui._count_label = Label.new()
	_ui._count_label.text = "SLICES (0)"
	_ui._count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_header.add_child(_ui._count_label)

	var sel_all_btn = Button.new()
	sel_all_btn.text = "All"
	sel_all_btn.tooltip_text = "Select all slices (Ctrl + A)"
	sel_all_btn.pressed.connect(func():
		if _ui._canvas and not _ui._canvas.rects.is_empty():
			_ui._canvas.selected_indices.clear()
			for i in range(_ui._canvas.rects.size()):
				_ui._canvas.selected_indices.append(i)
			_ui._canvas._emit_selection_changed()
			_ui._canvas.queue_redraw()
	)
	list_header.add_child(sel_all_btn)

	var desel_all_btn = Button.new()
	desel_all_btn.text = "None"
	desel_all_btn.tooltip_text = "Deselect all slices (Escape)"
	desel_all_btn.pressed.connect(func():
		if _ui._canvas and not _ui._canvas.selected_indices.is_empty():
			_ui._canvas.selected_indices.clear()
			_ui._canvas._emit_selection_changed()
			_ui._canvas.queue_redraw()
	)
	list_header.add_child(desel_all_btn)

	_ui._slice_list = ItemList.new()
	_ui._slice_list.select_mode = ItemList.SELECT_MULTI
	_ui._slice_list.size_flags_vertical  = Control.SIZE_FILL
	_ui._slice_list.custom_minimum_size  = Vector2(0, 150)
	_ui._slice_list.item_selected.connect(_ui._on_list_item_selected)
	vbox.add_child(_ui._slice_list)

	vbox.add_child(HSeparator.new())

	_ui._props_box = VBoxContainer.new()
	_ui._props_box.add_theme_constant_override("separation", 4)
	_ui._props_box.visible = false
	vbox.add_child(_ui._props_box)

	# Frame Properties Box
	_ui._stamp_props_box = VBoxContainer.new()
	_ui._stamp_props_box.add_theme_constant_override("separation", 6)
	_ui._stamp_props_box.visible = false
	vbox.add_child(_ui._stamp_props_box)

	var stamp_title = Label.new()
	stamp_title.text = "Frame Properties"
	_ui._stamp_props_box.add_child(stamp_title)

	var stamp_grid = GridContainer.new()
	stamp_grid.columns = 2
	stamp_grid.add_theme_constant_override("h_separation", 4)
	stamp_grid.add_theme_constant_override("v_separation", 4)
	_ui._stamp_props_box.add_child(stamp_grid)

	_ui._stamp_pos_x = _make_stamp_spin_inline("Pos X", stamp_grid, -8192.0, 8192.0, 1.0, 0.0)
	_ui._stamp_pos_y = _make_stamp_spin_inline("Pos Y", stamp_grid, -8192.0, 8192.0, 1.0, 0.0)
	
	_ui._stamp_scale_x = _make_stamp_spin_inline("Scale X", stamp_grid, 0.05, 50.0, 0.05, 1.0)
	_ui._stamp_scale_y = _make_stamp_spin_inline("Scale Y", stamp_grid, 0.05, 50.0, 0.05, 1.0)
	
	_ui._stamp_pivot_x = _make_stamp_spin_inline("Pivot X", stamp_grid, -8192.0, 8192.0, 1.0, 0.0)
	_ui._stamp_pivot_y = _make_stamp_spin_inline("Pivot Y", stamp_grid, -8192.0, 8192.0, 1.0, 0.0)
	
	_ui._stamp_rot = _make_stamp_spin_inline("Rot Deg", stamp_grid, -360.0, 360.0, 1.0, 0.0)
	
	# Empty labels to align grid
	var empty_lbl1 = Label.new()
	var empty_lbl2 = Label.new()
	empty_lbl1.free()
	empty_lbl2.free()

	# Stamp Actions
	var stamp_actions = HBoxContainer.new()
	stamp_actions.add_theme_constant_override("separation", 6)
	_ui._stamp_props_box.add_child(stamp_actions)
	
	var stamp_flip_h = Button.new()
	stamp_flip_h.text = "↔"
	stamp_flip_h.tooltip_text = "Flip Horizontal"
	stamp_flip_h.pressed.connect(func():
		if _ui._canvas:
			_ui._canvas.frame_flip_h = not _ui._canvas.frame_flip_h
			_ui._canvas.queue_redraw()
	)
	stamp_actions.add_child(stamp_flip_h)
	
	var stamp_flip_v = Button.new()
	stamp_flip_v.text = "↕"
	stamp_flip_v.tooltip_text = "Flip Vertical"
	stamp_flip_v.pressed.connect(func():
		if _ui._canvas:
			_ui._canvas.frame_flip_v = not _ui._canvas.frame_flip_v
			_ui._canvas.queue_redraw()
	)
	stamp_actions.add_child(stamp_flip_v)

	var apply_stamp_btn = Button.new()
	apply_stamp_btn.text = "Apply Frame"
	apply_stamp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_stamp_btn.pressed.connect(_ui._apply_stamp)
	stamp_actions.add_child(apply_stamp_btn)

	var cancel_stamp_btn = Button.new()
	cancel_stamp_btn.text = "Cancel"
	cancel_stamp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_stamp_btn.pressed.connect(_ui._cancel_stamp)
	stamp_actions.add_child(cancel_stamp_btn)

	# Text Tool Properties Box
	_ui._text_props_box = VBoxContainer.new()
	_ui._text_props_box.add_theme_constant_override("separation", 6)
	_ui._text_props_box.visible = false
	vbox.add_child(_ui._text_props_box)

	var text_title = Label.new()
	text_title.text = "Text Properties"
	_ui._text_props_box.add_child(text_title)

	_ui._text_input = LineEdit.new()
	_ui._text_input.placeholder_text = "Enter text..."
	_ui._text_input.text = "Text"
	_ui._text_input.text_changed.connect(func(_t: String): _ui._update_text_preview())
	_ui._text_props_box.add_child(_ui._text_input)

	var font_box = HBoxContainer.new()
	font_box.add_theme_constant_override("separation", 4)
	_ui._text_props_box.add_child(font_box)

	_ui._font_path_label = LineEdit.new()
	_ui._font_path_label.placeholder_text = "Default Font"
	_ui._font_path_label.editable = false
	_ui._font_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	font_box.add_child(_ui._font_path_label)

	_ui._font_browse_btn = Button.new()
	_ui._font_browse_btn.text = "..."
	_ui._font_browse_btn.tooltip_text = "Select Font File (.ttf, .otf, .woff, .tres)"
	_ui._font_browse_btn.pressed.connect(func():
		if _ui._dialogs:
			_ui._dialogs.open_font_dialog()
	)
	font_box.add_child(_ui._font_browse_btn)

	var text_style_grid = GridContainer.new()
	text_style_grid.columns = 2
	text_style_grid.add_theme_constant_override("h_separation", 4)
	text_style_grid.add_theme_constant_override("v_separation", 4)
	_ui._text_props_box.add_child(text_style_grid)

	var size_lbl = Label.new()
	size_lbl.text = "Font Size:"
	text_style_grid.add_child(size_lbl)

	_ui._text_font_size_spin = SpinBox.new()
	_ui._text_font_size_spin.min_value = 8
	_ui._text_font_size_spin.max_value = 256
	_ui._text_font_size_spin.value = 24
	_ui._text_font_size_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._text_font_size_spin.value_changed.connect(func(_v: float): _ui._update_text_preview())
	text_style_grid.add_child(_ui._text_font_size_spin)

	var col_lbl = Label.new()
	col_lbl.text = "Color:"
	text_style_grid.add_child(col_lbl)

	_ui._text_color_picker = ColorPickerButton.new()
	_ui._text_color_picker.color = Color.WHITE
	_ui._text_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._text_color_picker.color_changed.connect(func(_c: Color): _ui._update_text_preview())
	text_style_grid.add_child(_ui._text_color_picker)

	# Text Actions
	var text_actions = HBoxContainer.new()
	text_actions.add_theme_constant_override("separation", 6)
	_ui._text_props_box.add_child(text_actions)
	
	var text_flip_h = Button.new()
	text_flip_h.text = "↔"
	text_flip_h.tooltip_text = "Flip Horizontal"
	text_flip_h.pressed.connect(func():
		if _ui._canvas:
			_ui._canvas.frame_flip_h = not _ui._canvas.frame_flip_h
			_ui._canvas.queue_redraw()
	)
	text_actions.add_child(text_flip_h)
	
	var text_flip_v = Button.new()
	text_flip_v.text = "↕"
	text_flip_v.tooltip_text = "Flip Vertical"
	text_flip_v.pressed.connect(func():
		if _ui._canvas:
			_ui._canvas.frame_flip_v = not _ui._canvas.frame_flip_v
			_ui._canvas.queue_redraw()
	)
	text_actions.add_child(text_flip_v)

	var apply_text_btn = Button.new()
	apply_text_btn.text = "Apply Text"
	apply_text_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_text_btn.pressed.connect(_ui._apply_stamp)
	text_actions.add_child(apply_text_btn)

	var cancel_text_btn = Button.new()
	cancel_text_btn.text = "Cancel"
	cancel_text_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_text_btn.pressed.connect(func(): _ui._select_tool(""))
	text_actions.add_child(cancel_text_btn)

	var props_title = Label.new()
	props_title.text = "Selected Slice"
	_ui._props_box.add_child(props_title)

	_ui._name_edit = LineEdit.new()
	_ui._name_edit.placeholder_text = "Custom Name"
	_ui._name_edit.text_changed.connect(_ui._on_name_changed)
	_ui._props_box.add_child(_ui._name_edit)

	_ui._mat_box = HBoxContainer.new()
	_ui._mat_box.add_theme_constant_override("separation", 4)
	_ui._props_box.add_child(_ui._mat_box)
	
	_ui._mat_edit = LineEdit.new()
	_ui._mat_edit.placeholder_text = "No Material/Shader"
	_ui._mat_edit.editable = false
	_ui._mat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._mat_box.add_child(_ui._mat_edit)
	
	_ui._mat_browse_btn = Button.new()
	_ui._mat_browse_btn.text = "..."
	_ui._mat_browse_btn.tooltip_text = "Select Shader/Material file (.tres)"
	_ui._mat_browse_btn.pressed.connect(func():
		if _ui._dialogs:
			_ui._dialogs.open_material_dialog()
	)
	_ui._mat_box.add_child(_ui._mat_browse_btn)

	_ui._props_grid = GridContainer.new()
	_ui._props_grid.columns = 2
	_ui._props_grid.add_theme_constant_override("h_separation", 4)
	_ui._props_grid.add_theme_constant_override("v_separation", 3)
	_ui._props_box.add_child(_ui._props_grid)

	_ui._spin_x = _make_spin("X", _ui._props_grid)
	_ui._spin_y = _make_spin("Y", _ui._props_grid)
	_ui._spin_w = _make_spin("W", _ui._props_grid)
	_ui._spin_h = _make_spin("H", _ui._props_grid)

	for sb in [_ui._spin_x, _ui._spin_y, _ui._spin_w, _ui._spin_h]:
		sb.value_changed.connect(func(_v: float) -> void: _ui._on_prop_changed())

	var actions_grid = GridContainer.new()
	actions_grid.columns = 2
	actions_grid.add_theme_constant_override("h_separation", 4)
	actions_grid.add_theme_constant_override("v_separation", 4)
	_ui._props_box.add_child(actions_grid)

	var del_btn = Button.new()
	del_btn.text = "Delete"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.tooltip_text = "Delete selected slices (Delete / Backspace)"
	del_btn.pressed.connect(_ui._on_delete_selected)
	actions_grid.add_child(del_btn)

	var dup_btn = Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.tooltip_text = "Duplicate selected slices (Ctrl + D)"
	dup_btn.pressed.connect(func():
		if _ui._canvas and not _ui._canvas.selected_indices.is_empty():
			_ui._canvas._duplicate_selected_rects()
	)
	actions_grid.add_child(dup_btn)

	_ui._merge_btn = Button.new()
	_ui._merge_btn.text = "Merge"
	_ui._merge_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._merge_btn.tooltip_text = "Merge selected slices into one (Ctrl + M)"
	_ui._merge_btn.pressed.connect(func():
		if _ui._canvas and _ui._canvas.selected_indices.size() >= 2:
			_ui._canvas._merge_selected_rects()
	)
	actions_grid.add_child(_ui._merge_btn)

	_ui._lock_btn = Button.new()
	_ui._lock_btn.text = "Lock"
	_ui._lock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._lock_btn.tooltip_text = "Lock/Unlock selected slices to prevent editing (L)"
	_ui._lock_btn.pressed.connect(_ui._on_lock_toggle)
	actions_grid.add_child(_ui._lock_btn)

	vbox.add_child(HSeparator.new())

	var export_box := _make_section(vbox, "Export", true)

	_ui._chk_png = CheckBox.new()
	_ui._chk_png.text = "PNG Slices (.png)"
	_ui._chk_png.button_pressed = true
	export_box.add_child(_ui._chk_png)

	_ui._chk_atlas = CheckBox.new()
	_ui._chk_atlas.text = "AtlasTexture (.tres)"
	_ui._chk_atlas.button_pressed = false
	export_box.add_child(_ui._chk_atlas)

	var sf_box = HBoxContainer.new()
	sf_box.add_theme_constant_override("separation", 4)
	export_box.add_child(sf_box)

	_ui._chk_spriteframes = CheckBox.new()
	_ui._chk_spriteframes.text = "SpriteFrames"
	_ui._chk_spriteframes.button_pressed = false
	sf_box.add_child(_ui._chk_spriteframes)

	_ui._anim_name_edit = LineEdit.new()
	_ui._anim_name_edit.placeholder_text = "Anim: default"
	_ui._anim_name_edit.custom_minimum_size = Vector2(80, 0)
	_ui._anim_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sf_box.add_child(_ui._anim_name_edit)

	var naming_box := _make_section(export_box, "File naming", false)
	var naming_grid = GridContainer.new()
	naming_grid.columns = 2
	naming_grid.add_theme_constant_override("h_separation", 4)
	naming_grid.add_theme_constant_override("v_separation", 4)
	naming_box.add_child(naming_grid)
	
	var folder_lbl = Label.new()
	folder_lbl.text = "Folder:"
	naming_grid.add_child(folder_lbl)
	
	_ui._export_folder_edit = LineEdit.new()
	_ui._export_folder_edit.placeholder_text = "slices_folder"
	_ui._export_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naming_grid.add_child(_ui._export_folder_edit)
	
	var base_lbl = Label.new()
	base_lbl.text = "Base File:"
	naming_grid.add_child(base_lbl)
	
	_ui._export_base_edit = LineEdit.new()
	_ui._export_base_edit.placeholder_text = "file_base"
	_ui._export_base_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naming_grid.add_child(_ui._export_base_edit)

	_ui._chk_subfolder = CheckBox.new()
	_ui._chk_subfolder.text = "Create Subfolder"
	_ui._chk_subfolder.button_pressed = true
	_ui._chk_subfolder.tooltip_text = "If unchecked, exports directly into the same directory as the texture"
	_ui._chk_subfolder.toggled.connect(func(pressed: bool):
		if _ui._export_folder_edit:
			_ui._export_folder_edit.editable = pressed
	)
	naming_box.add_child(_ui._chk_subfolder)

	_ui._chk_auto_unique = CheckBox.new()
	_ui._chk_auto_unique.text = "Auto Unique Names"
	_ui._chk_auto_unique.button_pressed = true
	_ui._chk_auto_unique.tooltip_text = "If a file with the same name exists, automatically appends _1, _2 to prevent overwriting"
	naming_box.add_child(_ui._chk_auto_unique)

	naming_box.add_child(HSeparator.new())

	var export_actions := VBoxContainer.new()
	export_actions.add_theme_constant_override("separation", 4)
	export_box.add_child(export_actions)
	var export_all := Button.new()
	export_all.text = "Export all slices"
	export_all.pressed.connect(func(): _ui._on_extract(false))
	export_actions.add_child(export_all)
	var export_selected := Button.new()
	export_selected.text = "Export selected slices"
	export_selected.pressed.connect(func(): _ui._on_extract(true))
	export_actions.add_child(export_selected)

	var snap_box := _make_section(vbox, "Grid snapping", false)

	_ui._chk_snap = CheckBox.new()
	_ui._chk_snap.text = "Snap to Grid"
	_ui._chk_snap.button_pressed = false
	_ui._chk_snap.toggled.connect(func(t: bool):
		if _ui._canvas:
			_ui._canvas.snap_to_grid = t
			_ui._canvas.queue_redraw()
	)
	snap_box.add_child(_ui._chk_snap)

	var snap_grid = GridContainer.new()
	snap_grid.columns = 2
	snap_grid.add_theme_constant_override("h_separation", 6)
	snap_grid.add_theme_constant_override("v_separation", 4)
	snap_box.add_child(snap_grid)

	var snap_w_lbl = Label.new()
	snap_w_lbl.text = "Snap W:"
	snap_grid.add_child(snap_w_lbl)

	_ui._spin_snap_w = SpinBox.new()
	_ui._spin_snap_w.min_value = 1
	_ui._spin_snap_w.max_value = 1024
	_ui._spin_snap_w.value = 16
	_ui._spin_snap_w.step = 1
	_ui._spin_snap_w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._spin_snap_w.value_changed.connect(func(v: float):
		if _ui._canvas:
			_ui._canvas.snap_w = int(v)
	)
	snap_grid.add_child(_ui._spin_snap_w)

	var snap_h_lbl = Label.new()
	snap_h_lbl.text = "Snap H:"
	snap_grid.add_child(snap_h_lbl)

	_ui._spin_snap_h = SpinBox.new()
	_ui._spin_snap_h.min_value = 1
	_ui._spin_snap_h.max_value = 1024
	_ui._spin_snap_h.value = 16
	_ui._spin_snap_h.step = 1
	_ui._spin_snap_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._spin_snap_h.value_changed.connect(func(v: float):
		if _ui._canvas:
			_ui._canvas.snap_h = int(v)
	)
	snap_grid.add_child(_ui._spin_snap_h)

	snap_box.add_child(HSeparator.new())


	return panel

func _make_spin(lbl_text: String, parent: Control) -> SpinBox:
	var lbl = Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(16, 0)
	parent.add_child(lbl)

	var sb = SpinBox.new()
	sb.min_value              = 0
	sb.max_value              = 8192
	sb.step                   = 1
	sb.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	parent.add_child(sb)
	return sb

func _make_stamp_spin_inline(lbl_text: String, parent: Control, min_val: float, max_val: float, step_val: float, default_val: float) -> SpinBox:
	var lbl = Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(45, 0)
	parent.add_child(lbl)
	
	var sb = SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step_val
	sb.value = default_val
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sb)
	
	sb.value_changed.connect(func(_v: float) -> void:
		_ui._on_stamp_prop_changed()
	)
	return sb

func _make_section(parent: Control, title: String, expanded: bool) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	var header := Button.new()
	header.name = title.replace(" ", "") + "Section"
	header.toggle_mode = true
	header.button_pressed = expanded
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.text = ("▼  " if expanded else "▶  ") + title
	header.tooltip_text = "Expand or collapse " + title.to_lower()
	section.add_child(header)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.visible = expanded
	section.add_child(content)
	header.toggled.connect(func(open: bool):
		content.visible = open
		header.text = ("▼  " if open else "▶  ") + title
	)
	return content
