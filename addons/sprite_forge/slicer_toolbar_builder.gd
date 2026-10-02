@tool
extends RefCounted

## Builds toolbar controls and wires them to host callbacks.
var _ui
var _tool_tabs: TabContainer
var _active_tool_label: Label

func _init(host) -> void:
	_ui = host

func _make_toolbar() -> Control:
	var tb_outer = VBoxContainer.new()
	tb_outer.add_theme_constant_override("separation", 8)

	# --- Row 1: File, Slice, Undo/Redo, Zoom ---
	var tb1 = HBoxContainer.new()
	tb1.add_theme_constant_override("separation", 6)
	tb_outer.add_child(tb1)

	var browse_btn = Button.new()
	browse_btn.text = "Open sheet..."
	browse_btn.pressed.connect(_ui._on_browse)
	tb1.add_child(browse_btn)

	_ui._path_label = LineEdit.new()
	_ui._path_label.editable              = false
	_ui._path_label.placeholder_text      = "No texture selected"
	_ui._path_label.custom_minimum_size   = Vector2(100, 0)
	_ui._path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui._path_label.expand_to_text_length = false
	tb1.add_child(_ui._path_label)

	_tool_tabs = TabContainer.new()
	_tool_tabs.name = "ToolTabs"
	_tool_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_outer.add_child(_tool_tabs)
	var image_tools := _make_tool_page("Image")
	var slice_tools := _make_tool_page("Slice")
	var paint_tools := _make_tool_page("Paint")
	var compose_tools := _make_tool_page("Compose")


	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.tooltip_text = "Return to slice selection mode"
	select_btn.pressed.connect(func(): _ui._select_tool(""))
	slice_tools.add_child(select_btn)

	var auto_btn = Button.new()
	auto_btn.text = "Auto Slice"
	auto_btn.tooltip_text = "Detect sprites via flood-fill"
	auto_btn.pressed.connect(_ui._on_auto_slice)
	slice_tools.add_child(auto_btn)

	var grid_btn = Button.new()
	grid_btn.text = "Grid Slice..."
	grid_btn.tooltip_text = "Slice into a uniform grid"
	grid_btn.pressed.connect(func():
		if _ui._dialogs:
			_ui._dialogs.open_grid_dialog()
	)
	slice_tools.add_child(grid_btn)

	var resize_btn = Button.new()
	resize_btn.text = "Resize Image..."
	resize_btn.tooltip_text = "Resize the main image resolution (with optional slice scaling)"
	resize_btn.pressed.connect(func():
		if _ui._dialogs and _ui._current_tex:
			var img: Image = _ui._current_tex.get_image()
			if img:
				_ui._dialogs.open_resize_dialog(img.get_width(), img.get_height())
	)
	image_tools.add_child(resize_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.tooltip_text = "Remove all slices"
	clear_btn.pressed.connect(_ui._on_clear)
	slice_tools.add_child(clear_btn)

	
	var flip_h_btn = Button.new()
	flip_h_btn.text = "↔"
	flip_h_btn.tooltip_text = "Flip Image Horizontally"
	flip_h_btn.pressed.connect(func(): _ui._flip_main_texture(true, false))
	image_tools.add_child(flip_h_btn)
	
	var flip_v_btn = Button.new()
	flip_v_btn.text = "↕"
	flip_v_btn.tooltip_text = "Flip Image Vertically"
	flip_v_btn.pressed.connect(func(): _ui._flip_main_texture(false, true))
	image_tools.add_child(flip_v_btn)


	_ui._undo_btn = Button.new()
	_ui._undo_btn.text = "Undo"
	_ui._undo_btn.tooltip_text = "Undo last action (Ctrl+Z)"
	_ui._undo_btn.disabled = true
	_ui._undo_btn.pressed.connect(_ui._undo)
	tb1.add_child(_ui._undo_btn)

	_ui._redo_btn = Button.new()
	_ui._redo_btn.text = "Redo"
	_ui._redo_btn.tooltip_text = "Redo (Ctrl+Y / Ctrl+Shift+Z)"
	_ui._redo_btn.disabled = true
	_ui._redo_btn.pressed.connect(_ui._redo)
	tb1.add_child(_ui._redo_btn)


	var zminus = Button.new()
	zminus.text = "-"
	zminus.custom_minimum_size = Vector2(26, 0)
	zminus.pressed.connect(func(): _ui._canvas.set_zoom(_ui._zoom / 1.25))
	tb1.add_child(zminus)

	_ui._zoom_label = Label.new()
	_ui._zoom_label.text                  = "100%"
	_ui._zoom_label.custom_minimum_size   = Vector2(50, 0)
	_ui._zoom_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	tb1.add_child(_ui._zoom_label)

	var zplus = Button.new()
	zplus.text = "+"
	zplus.custom_minimum_size = Vector2(26, 0)
	zplus.pressed.connect(func(): _ui._canvas.set_zoom(_ui._zoom * 1.25))
	tb1.add_child(zplus)

	var remove_bg_btn = Button.new()
	remove_bg_btn.text = "Remove BG"
	remove_bg_btn.tooltip_text = "Remove background color using flood-fill"
	remove_bg_btn.pressed.connect(_ui._on_remove_bg)
	image_tools.add_child(remove_bg_btn)

	var tol_label = Label.new()
	tol_label.text = "Tolerance:"


	var tol_spin = SpinBox.new()
	tol_spin.min_value = 1
	tol_spin.max_value = 80
	tol_spin.step = 1
	tol_spin.value = int(_ui._bg_tolerance * 100)
	tol_spin.custom_minimum_size = Vector2(68, 0)
	tol_spin.suffix = "%"
	tol_spin.tooltip_text = "Background removal tolerance"
	tol_spin.value_changed.connect(func(v: float): 
		_ui._bg_tolerance = v / 100.0
		if _ui._canvas:
			_ui._canvas.tolerance = _ui._bg_tolerance
	)



	_ui._wand_btn = Button.new()
	_ui._wand_btn.text = "Wand erase"
	_ui._wand_btn.toggle_mode = true
	_ui._wand_btn.tooltip_text = "Click to erase matching color regions"
	_ui._wand_btn.toggled.connect(_ui._on_wand_toggled)
	paint_tools.add_child(_ui._wand_btn)

	_ui._brush_erase_btn = Button.new()
	_ui._brush_erase_btn.text = "Eraser"
	_ui._brush_erase_btn.toggle_mode = true
	_ui._brush_erase_btn.tooltip_text = "Click and drag to erase pixels"
	_ui._brush_erase_btn.toggled.connect(_ui._on_brush_toggled)
	paint_tools.add_child(_ui._brush_erase_btn)


	_ui._recolor_btn = Button.new()
	_ui._recolor_btn.text = "Recolor"
	_ui._recolor_btn.toggle_mode = true
	_ui._recolor_btn.tooltip_text = "Click to recolor matching color regions"
	_ui._recolor_btn.toggled.connect(_ui._on_recolor_toggled)
	paint_tools.add_child(_ui._recolor_btn)

	_ui._paint_btn = Button.new()
	_ui._paint_btn.text = "Paint"
	_ui._paint_btn.toggle_mode = true
	_ui._paint_btn.tooltip_text = "Click and drag to paint with color"
	_ui._paint_btn.toggled.connect(_ui._on_paint_toggled)
	paint_tools.add_child(_ui._paint_btn)

	_ui._color_picker = ColorPickerButton.new()
	_ui._color_picker.color = Color.WHITE
	_ui._color_picker.custom_minimum_size = Vector2(40, 0)
	_ui._color_picker.tooltip_text = "Select paint/recolor color"
	_ui._color_picker.color_changed.connect(func(col: Color):
		if _ui._canvas:
			_ui._canvas.paint_color = col
			_ui._canvas.queue_redraw()
	)
	paint_tools.add_child(_ui._color_picker)
	paint_tools.add_child(tol_label)
	paint_tools.add_child(tol_spin)


	_ui._stamp_btn = Button.new()
	_ui._stamp_btn.text = "Add frame..."
	_ui._stamp_btn.toggle_mode = true
	_ui._stamp_btn.tooltip_text = "Load an image frame onto the canvas (click again while active to load another)"
	_ui._stamp_btn.toggled.connect(func(pressed: bool):
		if pressed:
			if _ui._dialogs:
				_ui._dialogs.open_frame_dialog()
		else:
			if _ui._canvas and _ui._canvas.frame_mode:
				_ui._select_tool("")
	)
	compose_tools.add_child(_ui._stamp_btn)

	_ui._text_btn = Button.new()
	_ui._text_btn.text = "Add text"
	_ui._text_btn.toggle_mode = true
	_ui._text_btn.tooltip_text = "Write custom text with font selection onto the canvas"
	_ui._text_btn.toggled.connect(func(pressed: bool):
		if pressed:
			_ui._select_tool("text")
		else:
			if _ui._canvas and _ui._canvas.frame_mode:
				_ui._select_tool("")
	)
	compose_tools.add_child(_ui._text_btn)

	# --- Stamp animation frame navigation ---
	_ui._stamp_prev_frame_btn = Button.new()
	_ui._stamp_prev_frame_btn.text = "◀"
	_ui._stamp_prev_frame_btn.custom_minimum_size = Vector2(24, 0)
	_ui._stamp_prev_frame_btn.disabled = true
	_ui._stamp_prev_frame_btn.tooltip_text = "Previous frame (animation)"
	_ui._stamp_prev_frame_btn.pressed.connect(func():
		_ui._stamp_frame_idx -= 1
		_ui._update_stamp_frame()
	)
	compose_tools.add_child(_ui._stamp_prev_frame_btn)

	_ui._stamp_frame_label = Label.new()
	_ui._stamp_frame_label.text = "-/-"
	_ui._stamp_frame_label.custom_minimum_size = Vector2(32, 0)
	_ui._stamp_frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui._stamp_frame_label.tooltip_text = "Current frame / Total frames"
	compose_tools.add_child(_ui._stamp_frame_label)

	_ui._stamp_next_frame_btn = Button.new()
	_ui._stamp_next_frame_btn.text = "▶"
	_ui._stamp_next_frame_btn.custom_minimum_size = Vector2(24, 0)
	_ui._stamp_next_frame_btn.disabled = true
	_ui._stamp_next_frame_btn.tooltip_text = "Next frame (animation)"
	_ui._stamp_next_frame_btn.pressed.connect(func():
		_ui._stamp_frame_idx += 1
		_ui._update_stamp_frame()
	)
	compose_tools.add_child(_ui._stamp_next_frame_btn)




	var brush_size_label = Label.new()
	brush_size_label.text = "Size:"
	paint_tools.add_child(brush_size_label)

	_ui._brush_size_spin = SpinBox.new()
	_ui._brush_size_spin.min_value = 0.5
	_ui._brush_size_spin.max_value = 100.0
	_ui._brush_size_spin.value = 8.0
	_ui._brush_size_spin.step = 0.25
	_ui._brush_size_spin.custom_minimum_size = Vector2(60, 0)
	_ui._brush_size_spin.tooltip_text = "Brush radius"
	_ui._brush_size_spin.value_changed.connect(func(val: float):
		if _ui._canvas != null:
			_ui._canvas.brush_size = float(val)
			_ui._canvas.queue_redraw()
	)
	paint_tools.add_child(_ui._brush_size_spin)
	if _ui._canvas != null:
		_ui._canvas.brush_size = 8.0


	var shape_lbl = Label.new()
	shape_lbl.text = "Shape:"
	paint_tools.add_child(shape_lbl)

	var shape_opt = OptionButton.new()
	shape_opt.add_item("Circle", 0)
	shape_opt.add_item("Square", 1)
	shape_opt.selected = 0
	shape_opt.item_selected.connect(func(idx: int):
		if _ui._canvas != null:
			_ui._canvas.brush_is_square = (idx == 1)
			_ui._canvas.queue_redraw()
	)
	paint_tools.add_child(shape_opt)


	var order_lbl = Label.new()
	order_lbl.text = "Order:"
	compose_tools.add_child(order_lbl)

	_ui._order_opt = OptionButton.new()
	_ui._order_opt.add_item("In Front", 0)
	_ui._order_opt.add_item("Behind", 1)
	_ui._order_opt.selected = 0
	_ui._order_opt.tooltip_text = "Layer order: paint/frame placed in front of or behind existing sprite pixels"
	_ui._order_opt.item_selected.connect(func(idx: int):
		if _ui._canvas != null:
			_ui._canvas.order_behind = (idx == 1)
			_ui._canvas.queue_redraw()
	)
	compose_tools.add_child(_ui._order_opt)


	# Mirror shared settings so they remain available in every relevant workflow.
	var image_tolerance_label := Label.new()
	image_tolerance_label.text = "Tolerance:"
	image_tools.add_child(image_tolerance_label)
	var image_tolerance := SpinBox.new()
	image_tolerance.min_value = tol_spin.min_value
	image_tolerance.max_value = tol_spin.max_value
	image_tolerance.step = tol_spin.step
	image_tolerance.value = tol_spin.value
	image_tolerance.suffix = "%"
	image_tolerance.custom_minimum_size = Vector2(68, 0)
	image_tolerance.tooltip_text = "Color matching tolerance for background removal"
	image_tools.add_child(image_tolerance)
	image_tolerance.value_changed.connect(func(value: float): tol_spin.value = value)
	tol_spin.value_changed.connect(func(value: float): image_tolerance.set_value_no_signal(value))
	var paint_order := OptionButton.new()
	paint_order.add_item("In Front", 0)
	paint_order.add_item("Behind", 1)
	paint_order.tooltip_text = "Paint in front of or behind existing pixels"
	paint_tools.add_child(paint_order)
	paint_order.item_selected.connect(func(index: int):
		_ui._order_opt.select(index)
		_ui._order_opt.item_selected.emit(index)
	)
	_ui._order_opt.item_selected.connect(func(index: int): paint_order.select(index))

	_active_tool_label = Label.new()
	_active_tool_label.text = "Select mode · Drag to select or create slices"
	_active_tool_label.modulate.a = 0.7
	_active_tool_label.add_theme_font_size_override("font_size", 12)
	tb_outer.add_child(_active_tool_label)
	return tb_outer

func _make_tool_page(title: String) -> HFlowContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_tool_tabs.add_child(margin)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	margin.add_child(flow)
	return flow

func sync_tool(tool_name: String) -> void:
	if _active_tool_label == null:
		return
	var titles := {"wand": "Wand erase", "brush_erase": "Eraser", "recolor": "Recolor", "paint": "Paint", "stamp": "Frame", "text": "Text"}
	_active_tool_label.text = str(titles.get(tool_name, "Select")) + " mode"
	if tool_name in ["wand", "brush_erase", "recolor", "paint"]:
		_tool_tabs.current_tab = 2
	elif tool_name in ["stamp", "text"]:
		_tool_tabs.current_tab = 3
