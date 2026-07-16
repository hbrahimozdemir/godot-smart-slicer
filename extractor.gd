@tool
class_name SpriteExtractor

static func extract(texture: Texture2D, rects: Array[Rect2], format: String, tex_path: String = "") -> void:
	var src_path := tex_path if tex_path != "" else texture.resource_path
	var base_path := src_path.get_base_dir()
	var base_name := src_path.get_file().get_basename()
	var out_dir := base_path + "/" + base_name + "_slices"

	var dir := DirAccess.open(base_path)
	if dir and not dir.dir_exists(base_name + "_slices"):
		dir.make_dir(base_name + "_slices")

	var img := texture.get_image()

	for i in range(rects.size()):
		var r := rects[i]
		var file_name := base_name + "_" + str(i)

		if format == "png":
			var region := img.get_region(Rect2i(r))
			var save_path := out_dir + "/" + file_name + ".png"
			region.save_png(save_path)
			print("Saved: ", save_path)
		elif format == "tres":
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = r
			var save_path := out_dir + "/" + file_name + ".tres"
			ResourceSaver.save(atlas, save_path)
			print("Saved: ", save_path)

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
