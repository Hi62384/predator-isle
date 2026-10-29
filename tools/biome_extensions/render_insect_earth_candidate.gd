extends "res://tools/biome_extensions/render_crystal_bulk_candidate.gd"
const BASELINE="res://tools/biome_extensions/artifacts/revisions/experiment_render_all_bdc262d54413/evidence/tools/biome_extensions/artifacts/render_all.json"
func material_pairs()->Array:
	var pairs:Array=[]
	for node:MeshInstance3D in terrain._active_chunks.values():
		var visible:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if visible==null or visible.mesh==null:continue
		var mesh:ArrayMesh=visible.mesh
		for surface in range(mesh.get_surface_count()):
			var old:ShaderMaterial=mesh.surface_get_material(surface)
			if old.get_shader_parameter("family")!=6:continue
			var replacement:ShaderMaterial=old.duplicate();replacement.shader=preload("res://tools/biome_extensions/insect_earth_candidate.gdshader")
			for parameter:String in ["structure_colors","structure_normals","normal_strength","debug_view"]:replacement.set_shader_parameter(parameter,old.get_shader_parameter(parameter))
			pairs.append({"mesh":mesh,"surface":surface,"original":old,"candidate":replacement})
	return pairs
func close_pose(focus:Vector3,sun_facing:bool=false,sun_clear:bool=false)->Dictionary:
	var nearest:float=INF;var chosen:Dictionary={}
	for node:MeshInstance3D in terrain._active_chunks.values():
		if not node.mesh.has_meta("extension_structures"):continue
		var mesh:ArrayMesh=node.mesh.get_meta("extension_structures")
		for surface in range(mesh.get_surface_count()):
			var material:ShaderMaterial=mesh.surface_get_material(surface)
			if material.get_shader_parameter("family")!=6:continue
			var a:Array=mesh.surface_get_arrays(surface);var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			for i in range(0,v.size(),3):
				var center:Vector3=(v[i]+v[i+1]+v[i+2])/3+node.position;var normal:Vector3=(v[i+2]-v[i]).cross(v[i+1]-v[i]).normalized()
				if normal.y<.05 or normal.y>.8 or center.y<terrain.get_height_at(center)+12:continue
				if sun_facing and normal.dot(scene.get_node("Sun").global_basis.z.normalized())<.4:continue
				var score:float=center.distance_squared_to(focus+Vector3(0,24,0))
				if score>=nearest:continue
				var eye:Vector3=center+normal*6+Vector3.UP*1.8
				var hit:Dictionary=node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,center-normal*.1))
				if hit.is_empty() or hit.position.distance_to(center)>.15:continue
				if sun_clear and not node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*.2,center+scene.get_node("Sun").global_basis.z.normalized()*2000)).is_empty():continue
				nearest=score;chosen={"view":"additional_unoccluded_close" if sun_clear else ("additional_lit_close" if sun_facing else "additional_close"),"camera":str(eye),"focus":str(center),"selected_triangle":i/3,"native_contact_error_m":hit.position.distance_to(center),"native_sun_ray_clear":sun_clear}
	return chosen
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);hashes[path]=regression.source_sha256[raw]
	for path:String in [BASELINE,"res://tools/biome_extensions/insect_earth_candidate.gdshader","res://tools/biome_extensions/insect_earth_optics.gdshaderinc","res://tools/biome_extensions/render_insect_earth_candidate.gd","res://tools/biome_extensions/render_crystal_bulk_candidate.gd","res://tools/biome_extensions/render_ground_union_worker_domains.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var baseline=JSON.parse_string(FileAccess.get_file_as_string(BASELINE));var views:Array=[]
	for item:Dictionary in baseline.captures:
		if item.biome=="insect_colony" and item.view!="regions":views.append(item.duplicate(true))
	assert(views.size()==3);var main_focus:Vector3=vector(views[0].focus)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain=scene.get_node("Terrain");terrain.extension_preview="insect_colony";terrain.extension_preview_position=Vector2(main_focus.x,main_focus.z);terrain.target=camera
	root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());freeze_water_time()
	var close:Dictionary=close_pose(main_focus);verify(not close.is_empty(),"Additional close pose admitted by actual original native surface before new material")
	if not close.is_empty():views.append(close)
	var lit_close:Dictionary=close_pose(main_focus,true);verify(not lit_close.is_empty(),"Separate sun-facing close pose follows unchanged saved Sun,not relighting")
	if not lit_close.is_empty():views.append(lit_close)
	var clear_close:Dictionary=close_pose(main_focus,true,true);verify(not clear_close.is_empty(),"Additional native2000m clear sun ray control,not only a facing normal")
	if not clear_close.is_empty():views.append(clear_close)
	var records:Array=[]
	for view:Dictionary in views:
		terrain.request_teleport(vector(view.camera));assert(await settle());camera.look_at(vector(view.focus));freeze_water_time()
		var pairs:Array=material_pairs();verify(not pairs.is_empty(),"Actual original production insect material bindings exist")
		var original_cut:Dictionary=cut();var original_image:Image
		for phase:int in range(3):
			for pair:Dictionary in pairs:pair.mesh.surface_set_material(pair.surface,pair.candidate if phase==1 else pair.original)
			terrain.set_debug_view(0)
			for idle in range(24):await process_frame
			verify(cut()==original_cut,"All complete GPU geometry/terrain/water/atlases/physical collision bytes unchanged")
			await RenderingServer.frame_post_draw;var picture:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/insect_earth_%s_%d.png"%[view.view,phase];verify(picture.save_png(path)==OK,"Saved whole native image");captures[path]=FileAccess.get_sha256(path)
			var changed:int=0
			if phase==0:original_image=picture
			else:changed=different(original_image,picture)
			if phase==2:verify(changed==0,"Same-scene original material image returns exactly")
			var gpu:Array=[]
			for frame in range(12):
				await process_frame
				var cost:float=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
				if cost>0:gpu.append(cost)
			records.append({"view":view.view,"phase":phase,"camera":view.camera,"focus":view.focus,"different_bytes_from_original":changed,"material_bindings":pairs.size(),"gpu_median_ms":median(gpu) if not gpu.is_empty() else null})
		print("INSECT_EARTH_NATIVE ",view.view," original/new/original complete")
	scene.queue_free();await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable private earth source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_insect_earth_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":records,"close_admission":close,"lit_close_admission":lit_close,"clear_close_admission":clear_close,"production_registration":false,"scope":"Private same-scene material-only intervention on actual current production fullLOD6/four-worker cuts. All three original frozen Insect cameras plus separately physically admitted6m shadow,sun-facing and native2000m sun-ray-clear close views selected before new material. Sun-facing alone was still occluded and is retained,not falsely labelled proven lit. Complete geometry/control/terrain/water/collision payloads exact;original material image returns must be strict. Existing photographed red-soil bank only;6mm/35mm filtered authored apparent relief,not scans/displacement/holes. Water remains visible atTIME0 in private duplicates only;lighting unchanged. GPU block medians NON-ISOLATED,single phase order,not repeated or end-to-end benchmark. No artistic completion/performance/cave claim."},"  "));quit(0 if failures.is_empty() else 1)
