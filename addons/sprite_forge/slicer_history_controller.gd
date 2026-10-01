@tool
extends RefCounted

## Captures and restores editor state through the history caretaker.
var _ui

func _init(host) -> void:
	_ui = host

func _push_history_state(state: Dictionary) -> void:
	if _ui._history:
		_ui._history.push_state(state)

func _capture_image_state() -> Dictionary:
	if not _ui._current_tex or not _ui._canvas:
		return {}
	var img: Image = _ui._current_tex.get_image()
	if not img or img.is_empty():
		return {}
	return {
		"type": "image",
		"image": img.duplicate(),
		"path": _ui._current_tex_path,
		"rects": _ui._canvas.rects.duplicate(),
		"slice_names": _ui._canvas.slice_names.duplicate(),
		"slice_materials": _ui._canvas.slice_materials.duplicate(),
		"selected_indices": _ui._canvas.selected_indices.duplicate(),
		"locked_states": _ui._canvas.locked_states.duplicate()
	}

func _push_image_state() -> void:
	var state = _capture_image_state()
	if not state.is_empty():
		_push_history_state(state)

func _push_slices_state() -> void:
	if not _ui._canvas:
		return
	_push_history_state({
		"type": "slices",
		"rects": _ui._canvas.rects.duplicate(),
		"slice_names": _ui._canvas.slice_names.duplicate(),
		"slice_materials": _ui._canvas.slice_materials.duplicate(),
		"selected_indices": _ui._canvas.selected_indices.duplicate(),
		"locked_states": _ui._canvas.locked_states.duplicate()
	})

func _on_history_changed(can_u: bool, can_r: bool) -> void:
	if _ui._undo_btn: _ui._undo_btn.disabled = not can_u
	if _ui._redo_btn: _ui._redo_btn.disabled = not can_r

func _undo() -> void:
	if _ui._history:
		_ui._history.undo(_apply_history_state)

func _redo() -> void:
	if _ui._history:
		_ui._history.redo(_apply_history_state)

func _apply_history_state(state: Dictionary) -> Dictionary:
	var current_state = {}

	if state["type"] == "image":
		current_state = _capture_image_state()
		var prev_img: Image = state["image"]
		_ui._current_tex_path = state["path"]
		_ui._path_label.text = _ui._current_tex_path.get_file()
		_ui._path_label.tooltip_text = _ui._current_tex_path
		var new_tex = ImageTexture.create_from_image(prev_img)
		_ui._current_tex = new_tex
		_ui._canvas.update_texture(new_tex)
		_ui._canvas.rects = state["rects"].duplicate()
		_ui._canvas.slice_names = state["slice_names"].duplicate()
		_ui._canvas.slice_materials = state["slice_materials"].duplicate()
		_ui._canvas.selected_indices = state["selected_indices"].duplicate()
		_ui._canvas.locked_states = state["locked_states"].duplicate()
		_ui._canvas._emit_selection_changed()
		_ui._canvas.queue_redraw()
		_ui._refresh_list()
		_ui._update_props()
		_ui._sync_list_highlight(_ui._canvas.selected_indices)
		# History restoration stays in memory; source files are never rewritten.
		if _ui._preview_player:
			_ui._preview_player.sync_preview(new_tex, _ui._canvas.rects, _ui._canvas.selected_indices)

	elif state["type"] == "slices":
		current_state = {
			"type": "slices",
			"rects": _ui._canvas.rects.duplicate(),
			"slice_names": _ui._canvas.slice_names.duplicate(),
			"slice_materials": _ui._canvas.slice_materials.duplicate(),
			"selected_indices": _ui._canvas.selected_indices.duplicate(),
			"locked_states": _ui._canvas.locked_states.duplicate()
		}

		_ui._canvas.rects = state["rects"].duplicate()
		_ui._canvas.slice_names = state["slice_names"].duplicate()
		_ui._canvas.slice_materials = state.get("slice_materials", []).duplicate()
		while _ui._canvas.slice_materials.size() < _ui._canvas.rects.size():
			_ui._canvas.slice_materials.append("")
		while _ui._canvas.slice_names.size() < _ui._canvas.rects.size():
			_ui._canvas.slice_names.append("")

		_ui._canvas.selected_indices = state["selected_indices"].duplicate()
		_ui._canvas.locked_states = state["locked_states"].duplicate()
		_ui._canvas._emit_selection_changed()
		_ui._canvas.queue_redraw()
		_ui._refresh_list()
		_ui._update_props()
		if _ui._preview_player:
			_ui._preview_player.sync_preview(_ui._current_tex, _ui._canvas.rects, _ui._canvas.selected_indices)

	return current_state
