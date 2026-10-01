@tool
extends RefCounted

## Handles slice actions and magic-wand preview independently of input routing.
var _canvas

func _init(host) -> void:
	_canvas = host

func _recalculate_wand_preview(img_p: Vector2i) -> void:
	_canvas.preview_mask.clear()
	if not _canvas.texture:
		_canvas._preview_mask_tex = null
		return
	var img = _canvas.texture.get_image()
	if not img or img.is_empty():
		_canvas._preview_mask_tex = null
		return
	var W = img.get_width()
	var H = img.get_height()
	if img_p.x < 0 or img_p.y < 0 or img_p.x >= W or img_p.y >= H:
		_canvas._preview_mask_tex = null
		return

	var bg = img.get_pixel(img_p.x, img_p.y)
	if bg.a < 0.01:
		_canvas._preview_mask_tex = null
		return

	# PackedInt32Array encodes pixel as y*W+x — no Vector2i heap allocations
	var visited = PackedByteArray()
	visited.resize(W * H)
	visited.fill(0)
	var queue = PackedInt32Array()
	var head = 0
	var start_idx = img_p.y * W + img_p.x
	visited[start_idx] = 1
	queue.append(start_idx)

	const MAX_PREVIEW := 8000
	var bg_r = bg.r; var bg_g = bg.g; var bg_b = bg.b

	while head < queue.size() and queue.size() < MAX_PREVIEW:
		var flat: int = queue[head]
		head += 1
		var px: int = flat % W
		var py: int = flat / W
		_canvas.preview_mask.append(Vector2i(px, py))

		var nx: int
		var ny: int
		var n_idx: int
		var c: Color
		var dr: float; var dg: float; var db: float

		nx = px - 1
		if nx >= 0:
			n_idx = py * W + nx
			if visited[n_idx] == 0:
				visited[n_idx] = 1
				c = img.get_pixel(nx, py)
				dr = c.r - bg_r; dg = c.g - bg_g; db = c.b - bg_b
				if sqrt(dr*dr*0.299 + dg*dg*0.587 + db*db*0.114) <= _canvas.tolerance:
					queue.append(n_idx)

		nx = px + 1
		if nx < W:
			n_idx = py * W + nx
			if visited[n_idx] == 0:
				visited[n_idx] = 1
				c = img.get_pixel(nx, py)
				dr = c.r - bg_r; dg = c.g - bg_g; db = c.b - bg_b
				if sqrt(dr*dr*0.299 + dg*dg*0.587 + db*db*0.114) <= _canvas.tolerance:
					queue.append(n_idx)

		ny = py - 1
		if ny >= 0:
			n_idx = ny * W + px
			if visited[n_idx] == 0:
				visited[n_idx] = 1
				c = img.get_pixel(px, ny)
				dr = c.r - bg_r; dg = c.g - bg_g; db = c.b - bg_b
				if sqrt(dr*dr*0.299 + dg*dg*0.587 + db*db*0.114) <= _canvas.tolerance:
					queue.append(n_idx)

		ny = py + 1
		if ny < H:
			n_idx = ny * W + px
			if visited[n_idx] == 0:
				visited[n_idx] = 1
				c = img.get_pixel(px, ny)
				dr = c.r - bg_r; dg = c.g - bg_g; db = c.b - bg_b
				if sqrt(dr*dr*0.299 + dg*dg*0.587 + db*db*0.114) <= _canvas.tolerance:
					queue.append(n_idx)

	if not _canvas.preview_mask.is_empty():
		var mask_color = Color(0.3, 0.7, 1.0, 0.45) if _canvas.erase_mode else _canvas.paint_color
		mask_color.a = 0.45

		if _canvas._preview_mask_img == null or _canvas._preview_mask_img.get_width() != W or _canvas._preview_mask_img.get_height() != H:
			_canvas._preview_mask_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
		else:
			_canvas._preview_mask_img.fill(Color.TRANSPARENT)

		for p in _canvas.preview_mask:
			_canvas._preview_mask_img.set_pixel(p.x, p.y, mask_color)

		if _canvas._preview_mask_tex == null:
			_canvas._preview_mask_tex = ImageTexture.create_from_image(_canvas._preview_mask_img)
		else:
			_canvas._preview_mask_tex.update(_canvas._preview_mask_img)
	else:
		_canvas._preview_mask_tex = null

func _delete_rect(idx: int) -> void:
	_canvas.rects.remove_at(idx)
	_canvas.slice_names.remove_at(idx)
	if idx < _canvas.slice_materials.size():
		_canvas.slice_materials.remove_at(idx)
	if idx < _canvas.locked_states.size():
		_canvas.locked_states.remove_at(idx)
	_canvas.selected_indices.erase(idx)
	# Shift remaining indices down
	for i in range(_canvas.selected_indices.size()):
		if _canvas.selected_indices[i] > idx:
			_canvas.selected_indices[i] -= 1
	_canvas._emit_selection_changed()
	_canvas.rects_changed.emit()
	_canvas.queue_redraw()

func _delete_selected_rects() -> void:
	_canvas.slice_action_started.emit()
	var to_delete = _canvas.selected_indices.duplicate()
	to_delete.sort()
	to_delete.reverse() # Delete from back to prevent index shifts
	for idx in to_delete:
		_canvas.rects.remove_at(idx)
		_canvas.slice_names.remove_at(idx)
		if idx < _canvas.slice_materials.size():
			_canvas.slice_materials.remove_at(idx)
		if idx < _canvas.locked_states.size():
			_canvas.locked_states.remove_at(idx)
	_canvas.selected_indices.clear()
	_canvas._emit_selection_changed()
	_canvas.rects_changed.emit()
	_canvas.queue_redraw()

func _duplicate_selected_rects() -> void:
	if _canvas.selected_indices.is_empty():
		return
	
	_canvas.slice_action_started.emit()
	var offset = Vector2(8, 8)
	var tex_w = _canvas.texture.get_width()
	var tex_h = _canvas.texture.get_height()
	
	var new_selected_indices: Array = []
	for idx in _canvas.selected_indices:
		var orig_rect = _canvas.rects[idx]
		var orig_name = _canvas.slice_names[idx]
		
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
		
		var new_mat = ""
		if idx < _canvas.slice_materials.size():
			new_mat = _canvas.slice_materials[idx]
		
		_canvas.rects.append(new_rect)
		_canvas.slice_names.append(new_name)
		_canvas.slice_materials.append(new_mat)
		_canvas.locked_states.append(false)
		new_selected_indices.append(_canvas.rects.size() - 1)
		
	_canvas.selected_indices = new_selected_indices
	_canvas._emit_selection_changed()
	_canvas.rects_changed.emit()
	_canvas.queue_redraw()

func _merge_selected_rects() -> void:
	if _canvas.selected_indices.size() < 2:
		return
		
	_canvas.slice_action_started.emit()
	
	var union_rect: Rect2 = _canvas.rects[_canvas.selected_indices[0]]
	for i in range(1, _canvas.selected_indices.size()):
		var idx = _canvas.selected_indices[i]
		union_rect = union_rect.merge(_canvas.rects[idx])
		
	var to_delete = _canvas.selected_indices.duplicate()
	to_delete.sort()
	to_delete.reverse()
	for idx in to_delete:
		_canvas.rects.remove_at(idx)
		_canvas.slice_names.remove_at(idx)
		if idx < _canvas.slice_materials.size():
			_canvas.slice_materials.remove_at(idx)
		if idx < _canvas.locked_states.size():
			_canvas.locked_states.remove_at(idx)
			
	_canvas.rects.append(union_rect)
	_canvas.slice_names.append("")
	_canvas.slice_materials.append("")
	_canvas.locked_states.append(false)
	
	_canvas.selected_indices = [_canvas.rects.size() - 1]
	_canvas._emit_selection_changed()
	_canvas.rects_changed.emit()
	_canvas.queue_redraw()
