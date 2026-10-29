extends "res://tools/biome_extensions/render_insect_earth_candidate.gd"
func grab(mode:int,strength:float,pairs:Array)->Image:
	terrain.set_debug_view(mode)
	for pair:Dictionary in pairs:pair.candidate.set_shader_parameter("normal_strength",strength)
	for frame in range(12):await process_frame
	await RenderingServer.frame_post_draw;return root.get_texture().get_image()
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var input_path:String="res://tools/biome_extensions/artifacts/render_insect_earth_candidate.json";var input=JSON.parse_string(FileAccess.get_file_as_string(input_path));assert(input.passed)
	for path:String in input.source_sha256:assert(FileAccess.get_sha256(path)==input.source_sha256[path]);hashes[path]=input.source_sha256[path]
	for path:String in [input_path,"res://tools/biome_extensions/check_insect_earth_normal_controls.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var focus:Vector3=vector(input.views[0].focus);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain=scene.get_node("Terrain");terrain.extension_preview="insect_colony";terrain.extension_preview_position=Vector2(focus.x,focus.z);terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
	var records:Array=[]
	for view:Dictionary in [input.close_admission,input.clear_close_admission]:
		terrain.request_teleport(vector(view.camera));assert(await settle());camera.look_at(vector(view.focus));var pairs:Array=material_pairs();verify(not pairs.is_empty(),"Actual committed original roots receive private earth material")
		for pair:Dictionary in pairs:pair.mesh.surface_set_material(pair.surface,pair.candidate)
		# Isolated normal diagnostic only: actual original meshes stay visible.
		# Full unhidden terrain/water images remain in the separate18-image trial.
		if terrain._water!=null:terrain._water.hide()
		for node:MeshInstance3D in terrain._active_chunks.values():
			node.layers=0
			for name:String in ["SwampWater","TerrainFeatures"]:
				var child:Node3D=node.get_node_or_null(name)
				if child!=null:child.hide()
		var on:Image=await grab(8,.7,pairs);var zero:Image=await grab(8,0,pairs);var geometric:Image=await grab(4,.7,pairs);var disabled:Image=await grab(7,.7,pairs);var physical_zero:Image=await grab(0,0,pairs)
		var max_geometric:float=0;var max_disabled:float=0;var changed:int=0
		for y in range(0,540,2):
			for x in range(0,960,2):
				var a:Color=on.get_pixel(x,y);var b:Color=zero.get_pixel(x,y);var c:Color=geometric.get_pixel(x,y);var d:Color=disabled.get_pixel(x,y);var e:Color=physical_zero.get_pixel(x,y)
				if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>1.0/255:changed+=1
				max_geometric=maxf(max_geometric,maxf(absf(b.r-c.r),maxf(absf(b.g-c.g),absf(b.b-c.b))));max_disabled=maxf(max_disabled,maxf(absf(d.r-e.r),maxf(absf(d.g-e.g),absf(d.b-e.b))))
		verify(changed>100 and max_geometric<=2.0/255 and max_disabled<=2.0/255,"Actual positive mapped normals and exact zero/geometric/off controls under unchanged2/255bound")
		for label:String in ["on","zero","geometric","disabled","physical_zero"]:
			var picture:Image={"on":on,"zero":zero,"geometric":geometric,"disabled":disabled,"physical_zero":physical_zero}[label];var path:String="res://tools/biome_extensions/artifacts/insect_earth_normal_%s_%s.png"%[view.view,label];verify(picture.save_png(path)==OK,"Saved complete diagnostic image");captures[path]=FileAccess.get_sha256(path)
		records.append({"view":view.view,"mapped_changed_pixels":changed,"maximum_zero_geometric_rgb_error":max_geometric,"maximum_disabled_physical_zero_rgb_error":max_disabled});print("EARTH_NORMAL ",records.back())
	scene.queue_free();await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable earth normal control source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_earth_normal_controls.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"records":records,"scope":"PRIVATE actual committed fullLOD6roots at original shadow and separately native-sun-ray-clear close poses. Ten complete diagnostic images. Terrain/water hidden ONLY for isolated normal diagnostic;actual unhidden18-image study retained. Positive mapped normals,zero equals actual geometric normal and physical debug-off equals actual zero-strength under unchanged2/255bound. No substitute mesh/lighting/normal scan or production registration."},"  "));quit(0 if failures.is_empty() else 1)
