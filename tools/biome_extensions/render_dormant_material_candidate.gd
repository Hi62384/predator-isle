extends "res://tools/biome_extensions/render_carapace.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for path:String in ["res://scenes/main.tscn","res://scripts/chunk_terrain.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/alien_infected_sampler.gd","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/artifacts/check_carapace_admission.json","res://tools/biome_extensions/render_dormant_material_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_carapace_admission.json"));assert(admission.passed)
	var item:Dictionary={}
	for candidate:Dictionary in admission.cases:
		if candidate.seed==17 and candidate.habit==5:item=candidate;break
	assert(not item.is_empty());var p:=Vector2(item.position[0],item.position[1])
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.world_seed=17;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
	var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
	var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y))+item.height*.4,p.y)
	var toward_sun:Vector3=scene.get_node("Sun").global_basis.z.normalized();var horizontal:=Vector2(toward_sun.x,toward_sun.z).normalized()*480
	var material:ShaderMaterial=terrain._extension_materials[2];var original:Shader=material.shader;var source:String=original.code
	var expression:String="structure_working_color(COLOR.rgb)*(.5+dot(tissue,vec3(.3,.5,.2))*.7)";assert(source.contains(expression))
	for enabled:bool in [false,true]:
		if enabled:
			var shader:=Shader.new();shader.code=source.replace(expression,"structure_working_color(COLOR.rgb)*(.3+dot(tissue,vec3(.3,.5,.2))*.35)");material.shader=shader
		else:material.shader=original
		var key:String="dormant_material_"+("candidate" if enabled else "current")
		await capture(key,"sunlit",focus,Vector3(horizontal.x,200,horizontal.y))
		await capture(key,"ground",focus,Vector3(-210,4-item.height*.4,-280))
		var face:Dictionary=plate_face(p,item.width,5);assert(face.production_tagged_vertices==18000)
		await capture(key,"close",face.center,face.normal*12)
		await capture(key,"close_normal_off",face.center,face.normal*12,7)
		await capture(key,"close_albedo",face.center,face.normal*12,3)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Candidate source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_dormant_material_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"private_material_variant_only":true,"production_change_kept":false,"captures":records,"source_sha256":hashes,"scope":"Same real streamed dormant complex and unchanged lighting, current versus private lower-reflectance shader expression. Candidate is not production and this is visual comparison, not a performance benchmark or acceptance certificate."},"  "))
	print("DORMANT_MATERIAL_CANDIDATE_DONE ",records.size());scene.queue_free();await process_frame;quit()
