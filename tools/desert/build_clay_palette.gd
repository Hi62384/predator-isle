extends SceneTree
## Offline preparation only. Preserve the original six-source palette/resources.
const SOURCE := "res://assets/textures/desert/polyhaven/mud_cracked_dry_riverbed_002/"
const IDS := ["Ground092A", "Ground054", "Gravel020", "Rock061", "polyhaven_clay", "Ground033"]
const OUTPUTS := ["res://materials/desert_color_polyhaven_clay.res", "res://materials/desert_normal_polyhaven_clay.res", "res://materials/desert_color_roughness_clay.tres", "res://materials/desert_normals_clay.tres"]

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func _initialize() -> void:
	for output in OUTPUTS:
		if FileAccess.file_exists(output):
			fail("Refusing to overwrite existing prepared clay resource: " + output)
			return
	var provenance = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "provenance.json"))
	if not provenance is Dictionary or provenance.get("license", "") != "CC0-1.0":
		fail("Missing verified CC0 clay provenance")
		return
	for record in provenance.maps:
		if FileAccess.get_sha256(SOURCE + str(record.file)) != str(record.sha256):
			fail("Clay source SHA256 mismatch")
			return
	var color := Image.load_from_file(SOURCE + "mud_cracked_dry_riverbed_002_diff_2k.jpg")
	var rough := Image.load_from_file(SOURCE + "mud_cracked_dry_riverbed_002_rough_2k.jpg")
	var normal := Image.load_from_file(SOURCE + "mud_cracked_dry_riverbed_002_nor_gl_2k.jpg")
	if color == null or rough == null or normal == null:
		fail("Clay source maps unavailable")
		return
	if color.get_size() != Vector2i(2048, 2048) or rough.get_size() != color.get_size() or normal.get_size() != color.get_size():
		fail("Unexpected clay source dimensions")
		return
	color.convert(Image.FORMAT_RGBA8)
	var pixels := color.get_data()
	rough.convert(Image.FORMAT_R8)
	var roughness := rough.get_data()
	for pixel in range(2048 * 2048): pixels[pixel * 4 + 3] = roughness[pixel]
	color = Image.create_from_data(2048, 2048, false, Image.FORMAT_RGBA8, pixels)
	color.generate_mipmaps()
	if color.compress_from_channels(Image.COMPRESS_S3TC, Image.USED_CHANNELS_RGBA) != OK:
		fail("Clay albedo/roughness compression failed")
		return
	normal.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	normal.convert(Image.FORMAT_RG8)
	normal.generate_mipmaps()
	if normal.compress_from_channels(Image.COMPRESS_S3TC, Image.USED_CHANNELS_RG) != OK:
		fail("Clay OpenGL XY normal compression failed")
		return
	if color.get_format() != Image.FORMAT_DXT5 or normal.get_format() != Image.FORMAT_RGTC_RG:
		fail("Unexpected prepared clay formats")
		return
	if ResourceSaver.save(color, OUTPUTS[0]) != OK or ResourceSaver.save(normal, OUTPUTS[1]) != OK:
		fail("Prepared clay image save failed")
		return
	for normal_array in [false, true]:
		var text := "[gd_resource type=\"Texture2DArray\" load_steps=7 format=3]\n\n"
		var references: Array[String] = []
		for index in range(IDS.size()):
			var path: String = "res://materials/desert_%s_%s.res" % ["normal" if normal_array else "color", IDS[index]]
			if not FileAccess.file_exists(path):
				fail("Existing Desert source layer missing: " + path)
				return
			text += "[ext_resource type=\"Image\" path=\"%s\" id=\"%d\"]\n" % [path, index + 1]
			references.append("ExtResource(\"%d\")" % (index + 1))
		text += "\n[resource]\n_images = Array[Image]([" + ", ".join(references) + "])\n"
		var destination: String = OUTPUTS[3 if normal_array else 2]
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			fail("Clay array save failed")
			return
		file.store_string(text)
	var report := {"source":provenance.source, "license":provenance.license,
		"role":"Cracked dry riverbed clay; not salt", "physical_repeat_metres":2.0,
		"color_bytes":color.get_data_size(), "normal_bytes":normal.get_data_size(),
		"color_format":"2K BC3 with linear roughness alpha", "normal_format":"1K BC5 OpenGL XY",
		"mipmaps":color.has_mipmaps() and normal.has_mipmaps(), "original_resources_preserved":true}
	FileAccess.open("res://tools/desert/clay_palette_preparation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
