extends "res://tools/biome_extensions/render_all.gd"
func vector(text:String)->Vector3:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func set_flow(enabled:bool)->void:
	for node:MeshInstance3D in terrain._active_chunks.values():
		if node.mesh.has_meta("alien_tissue_flow"):node.mesh.surface_get_material(0).set_shader_parameter("alien_tissue_flow_enabled",enabled)
		if node.mesh.has_meta("extension_structures"):
			var mesh:ArrayMesh=node.mesh.get_meta("extension_structures")
			for surface in range(mesh.get_surface_count()):
				var material:ShaderMaterial=mesh.surface_get_material(surface)
				if material.get_shader_parameter("family")==7 and material.get_shader_parameter("alien_tissue_flow")!=null:material.set_shader_parameter("alien_tissue_flow_enabled",enabled)
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var reference:String="res://tools/biome_extensions/artifacts/render_alien_tissue_flow.json";var report=JSON.parse_string(FileAccess.get_file_as_string(reference));assert(report.passed)
	for path:String in report.source_sha256:assert(FileAccess.get_sha256(path)==report.source_sha256[path]);hashes[path]=report.source_sha256[path]
	for path:String in [reference,"res://tools/biome_extensions/profile_tissue_flow_runtime.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var views:Array=[]
	for view:Dictionary in report.views:
		if view.seed==73921 and view.phase==1:views.append(view)
	assert(views.size()==3);var focus:Vector3=vector(views[0].focus);var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(73921,true)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;camera.position=vector(views[0].camera);terrain=scene.get_node("Terrain");terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.emission_strength=0;terrain.world_seed=73921;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
	for property:Dictionary in terrain.get_property_list():
		if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
	var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
	if terrain._water!=null:terrain._water.hide()
	for node:MeshInstance3D in terrain._active_chunks.values():
		var water:Node3D=node.get_node_or_null("SwampWater")
		if water!=null:water.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var samples:Array=[]
	for view:Dictionary in views:
		camera.position=vector(view.camera);camera.look_at(focus)
		for block in range(8):
			var enabled:bool=block%4==1 or block%4==2;set_flow(enabled)
			for idle in range(24):await process_frame
			var frames:Array=[];var gpu:Array=[];var last:int=Time.get_ticks_usec()
			for index in range(120):
				await process_frame;var now:int=Time.get_ticks_usec();frames.append(float(now-last)/1000);last=now
				var measured:float=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
				if measured>0:gpu.append(measured)
			frames.sort();gpu.sort();samples.append({"view":view.view,"block":block,"enabled":enabled,"frames":frames.size(),"wall_frame_p50_ms":frames[60],"wall_frame_p95_ms":frames[114],"wall_frame_p99_ms":frames[118],"wall_frame_max_ms":frames[-1],"gpu_samples":gpu.size(),"gpu_p50_ms":gpu[gpu.size()/2] if not gpu.is_empty() else null,"actual_camera":str(camera.position)})
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_tissue_flow_runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":hashes,"samples":samples,"leaves":terrain._active_chunks.size(),"scope":"One actual committed seed73921 pure-AlienLOD4 cut,three fixed native-review views,off/on/on/off repeated twice,120 measured frames per block after24 warmups,VSync/maxFPS disabled only in this process. Numeric maps stay resident in both modes,only material flow uniforms toggle;no geometry,reloading or worker scheduling differences. Wall frame intervals include submission/backpressure/host scheduling,not isolated GPU time. Actual measured GPU timer is null when unavailable;never substitute CPU intervals for it. This is a bounded overhead characterization,not an all-world frame-rate guarantee or speedup."},"  "));scene.queue_free();await process_frame;quit()
