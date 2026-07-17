@tool
class_name SpriteExtractor

static func extract(texture: Texture2D, rects: Array[Rect2], export_png: bool, export_atlas: bool, export_spriteframes: bool, tex_path: String = "", names: Array[String] = [], anim_name: String = "default", slice_materials: Array[String] = []) -> void:
	var src_path := tex_path if tex_path != "" else texture.resource_path
	var base_path := src_path.get_base_dir()
	var base_name := src_path.get_file().get_basename()
	var out_dir := base_path + "/" + base_name + "_slices"

	var dir := DirAccess.open(base_path)
	if dir and not dir.dir_exists(base_name + "_slices"):
		dir.make_dir(base_name + "_slices")

	var img := texture.get_image()
	if img == null or img.is_empty():
		push_error("SpriteSlicer: Source image is null or empty.")
		return

	for i in range(rects.size()):
		var r := rects[i]
		var file_name := base_name + "_" + str(i)
		if i < names.size() and names[i].strip_edges() != "":
			file_name = names[i].strip_edges()

		if export_png:
			var region := img.get_region(Rect2i(r))
			var save_path := out_dir + "/" + file_name + ".png"
			var abs_save := ProjectSettings.globalize_path(save_path)
			var err := region.save_png(abs_save)
			if err != OK:
				push_error("SpriteSlicer: Could not save PNG: %s (error %d)" % [abs_save, err])
			else:
				print("Saved PNG: ", save_path)
			
		if export_atlas:
			var atlas := AtlasTexture.new()
			var actual_tex: Texture2D = texture
			if texture is ImageTexture and src_path != "":
				var loaded = load(src_path)
				if loaded is Texture2D:
					actual_tex = loaded
			atlas.atlas = actual_tex
			atlas.region = r
			var save_path := out_dir + "/" + file_name + ".tres"
			var err := ResourceSaver.save(atlas, save_path)
			if err != OK:
				push_error("SpriteSlicer: Could not save AtlasTexture: %s (error %d)" % [save_path, err])
			else:
				print("Saved AtlasTexture: ", save_path)

		# Export custom Godot scene if a shader/material path is assigned to this slice
		if i < slice_materials.size() and slice_materials[i] != "":
			var mat_path := slice_materials[i]
			var loaded_mat = load(mat_path)
			if loaded_mat:
				# Create a Sprite2D and save as .tscn scene
				var sprite := Sprite2D.new()
				sprite.name = file_name
				
				# Load base texture (prefer physical texture resource if it's ImageTexture)
				var actual_tex: Texture2D = texture
				if texture is ImageTexture and src_path != "":
					var loaded = load(src_path)
					if loaded is Texture2D:
						actual_tex = loaded
				sprite.texture = actual_tex
				sprite.region_enabled = true
				sprite.region_rect = r
				sprite.material = loaded_mat
				
				# Pack scene
				var packed_scene := PackedScene.new()
				var pack_err := packed_scene.pack(sprite)
				if pack_err == OK:
					var scene_path := out_dir + "/" + file_name + ".tscn"
					var save_err := ResourceSaver.save(packed_scene, scene_path)
					if save_err != OK:
						push_error("SpriteSlicer: Could not save TSCN scene: %s (error %d)" % [scene_path, save_err])
					else:
						print("Saved Shader Scene: ", scene_path)
				else:
					push_error("SpriteSlicer: Could not pack Sprite2D node (error %d)" % pack_err)
				
				# Clean up node reference
				sprite.queue_free()

	if export_spriteframes:
		var sf := SpriteFrames.new()
		var a_name := anim_name.strip_edges()
		if a_name == "":
			a_name = "default"
		
		# SpriteFrames initializes with "default" automatically
		if sf.has_animation("default") and a_name != "default":
			sf.remove_animation("default")
			
		if not sf.has_animation(a_name):
			sf.add_animation(a_name)
			
		sf.set_animation_speed(a_name, 8.0)
		sf.set_animation_loop(a_name, true)
		
		for i in range(rects.size()):
			var r := rects[i]
			var atlas := AtlasTexture.new()
			var actual_tex: Texture2D = texture
			if texture is ImageTexture and src_path != "":
				var loaded = load(src_path)
				if loaded is Texture2D:
					actual_tex = loaded
			atlas.atlas = actual_tex
			atlas.region = r
			sf.add_frame(a_name, atlas)
			
		var sf_save_path := out_dir + "/" + base_name + "_animation.tres"
		var err := ResourceSaver.save(sf, sf_save_path)
		if err != OK:
			push_error("SpriteSlicer: Could not save SpriteFrames: %s (error %d)" % [sf_save_path, err])
		else:
			print("Saved SpriteFrames: ", sf_save_path)

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
