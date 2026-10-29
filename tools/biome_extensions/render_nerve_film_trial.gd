extends "res://tools/biome_extensions/render_all.gd"
const SOURCE="res://tools/biome_extensions/experiments/nerve_film_v3_albedo.png"
var reference_array:Texture2DArray
var trial_array:Texture2DArray
var trial_enabled:bool=false
var packed_mode:bool=false
func prepare_arrays()->void:
	var source:Texture2DArray=load("res://materials/biological_colors_v2.tres");assert(source.get_layers()==4)
	if packed_mode:
		reference_array=source;trial_array=load("res://materials/biological_colors_v3.tres")
		assert(trial_array!=null and trial_array.get_layers()==4)
		for layer in range(4):
			var a:Image=reference_array.get_layer_data(layer);var b:Image=trial_array.get_layer_data(layer)
			assert(a.get_format()==b.get_format() and a.get_data_size()==b.get_data_size())
			if layer!=1:assert(a.get_data()==b.get_data(),"All three unrelated packed layers remain identical")
		return
	var images:Array[Image]=[]
	for layer in range(4):
		var image:Image=source.get_layer_data(layer);assert(image!=null)
		if image.is_compressed():assert(image.decompress()==OK)
		image.convert(Image.FORMAT_RGBA8);assert(image.has_mipmaps());images.append(image)
	reference_array=Texture2DArray.new();assert(reference_array.create_from_images(images)==OK)
	var replacement:Image=Image.load_from_file(SOURCE);assert(replacement!=null)
	replacement.convert(Image.FORMAT_RGBA8);replacement.resize(source.get_width(),source.get_height(),Image.INTERPOLATE_LANCZOS);assert(replacement.generate_mipmaps()==OK)
	images[1]=replacement;trial_array=Texture2DArray.new();assert(trial_array.create_from_images(images)==OK)
	# Equal RGBA8 decoded reference/trial formats isolate the new layer. These
	# temporary arrays are NOT a production compressed-resource replacement.
func bind_array()->void:
	var selected:Texture2DArray=trial_array if trial_enabled else reference_array
	for material:ShaderMaterial in terrain._lod_materials.values():material.set_shader_parameter("biological_colors",selected)
	assert(terrain._extension_materials.size()==3);terrain._extension_materials[2].set_shader_parameter("biological_colors",selected)
	for node:MeshInstance3D in terrain._active_chunks.values():
		for surface in range(node.mesh.get_surface_count()):
			var material:ShaderMaterial=node.mesh.surface_get_material(surface)
			if material!=null:material.set_shader_parameter("biological_colors",selected)
func settle()->bool:
	var success:bool=await super.settle()
	if success:bind_array()
	return success
func run()->void:
	packed_mode=OS.get_cmdline_user_args().has("packed")
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var ingress=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_nerve_film_input.json"));assert(ingress.passed,"Private generated source must first pass its predeclared seam input criterion")
	for path:String in [SOURCE,"res://tools/biome_extensions/experiments/nerve_film_v3_provenance.json","res://tools/biome_extensions/artifacts/check_nerve_film_input.json","res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://materials/biological_colors_v2.tres","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/render_nerve_film_trial.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	for file:String in DirAccess.get_files_at("res://materials"):
		if file.begins_with("biological_"):hashes["res://materials/"+file]=FileAccess.get_sha256("res://materials/"+file)
	if packed_mode:
		for path:String in ["res://materials/biological_colors_v3.tres","res://materials/biological_color_nerve_v3.res","res://tools/biome_extensions/artifacts/build_nerve_film_material.json"]:hashes[path]=FileAccess.get_sha256(path)
	prepare_arrays();RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(manifest.passed and manifest.cases.size()==3)
	var failures:Array=[];var normal_controls:Array=[]
	for site:Dictionary in manifest.cases:
		var p:=Vector2(site.position[0],site.position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y);var offset:=Vector3(-90,4-site.junction_height*.4,-130)
		var capture_prefix:String="nerve_film_"+("packed_" if packed_mode else "")+str(int(site.seed))
		for phase in range(3):
			trial_enabled=phase==1;bind_array();var label:String=["reference","trial","reference_return"][phase]
			await capture(capture_prefix,label,focus,offset)
			if label=="reference_return" and records[-1].sha256!=records[-3].sha256:failures.append({"seed":site.seed,"reason":"Decoded reference return pixels not identical"})
		var normals:Array[String]=[]
		for enabled:bool in [false,true]:
			trial_enabled=enabled;bind_array();await capture(capture_prefix,"geometric_normal_"+("trial" if enabled else "reference"),focus,offset,4);normals.append(records[-1].sha256)
		if normals[0]!=normals[1]:failures.append({"seed":site.seed,"reason":"Texture-only trial changed geometric-normal pixels"})
		normal_controls.append({"seed":site.seed,"geometric_normal_pixels_identical":normals[0]==normals[1]})
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Texture-only trial source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_nerve_film_"+("packed_" if packed_mode else "")+"trial.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"actual_render":true,"production_adoption":false,"new_shader_variant":false,"arrays_uncompressed_rgba8":not packed_mode,"packed_bc1_arrays":packed_mode,"native_source_resolution":[ingress.width,ingress.height],"temporary_array_resolution":[reference_array.get_width(),reference_array.get_height()],"normal_controls":normal_controls,"captures":records,"source_sha256":hashes,"scope":"Private bitmap-only actual streamed A/B/reference-return views over three seeds, unchanged scene lighting and complete production geometry. Existing shader resources/code remain untouched during the run; only tissue layer1 differs between same-format reference/trial arrays. Packed mode uses original BC1 array versus the new BC1 array; decoded mode uses equal temporary RGBA8 arrays. Source is AI-generated albedo, not a measured normal/height scan. Geometric-normal pixels and reference return must remain exact. Import resizing does not create native 2K detail. Extra diagnostic-array GPU/RAM cost is not production packing, speed/whole-world or art acceptance."},"  "))
	print("NERVE_FILM_TRIAL_DONE ",records.size()," failures=",failures);quit(0 if failures.is_empty() else 1)
