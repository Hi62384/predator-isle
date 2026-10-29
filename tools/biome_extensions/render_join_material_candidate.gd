extends "res://tools/biome_extensions/render_all.gd"
var candidate_visible:bool=false
var changed_shader:Shader
func apply_candidate()->void:
	# Change ONLY the private scene's terrain material instances. The original
	# shader resource, shell materials, geometry, collision and renderer stay put.
	for material:ShaderMaterial in terrain._lod_materials.values():material.shader=changed_shader
	for node:MeshInstance3D in terrain._active_chunks.values():
		for surface in range(node.mesh.get_surface_count()):
			var material:ShaderMaterial=node.mesh.surface_get_material(surface)
			if material!=null:material.shader=changed_shader
func settle()->bool:
	var success:bool=await super.settle()
	if success and candidate_visible:apply_candidate()
	return success
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/biome_extension_settings.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/join_material_candidate.gd","res://tools/biome_extensions/render_join_material_candidate.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	changed_shader=preload("res://tools/biome_extensions/join_material_candidate.gd").new().terrain_shader()
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed)
	var site:Dictionary=admission.cases[0];var p:=Vector2(site.position[0],site.position[1]);var seed_id:int=site.seed
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
	var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
	var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y);var toward_sun:Vector3=scene.get_node("Sun").global_basis.z.normalized();var horizontal:=Vector2(toward_sun.x,toward_sun.z).normalized()*360
	var shots:Dictionary={"medium":Vector3(-240,140,-360),"ground":Vector3(-90,4-site.junction_height*.4,-130),"sunlit":Vector3(horizontal.x,160,horizontal.y)}
	for enabled:bool in [false,true]:
		candidate_visible=enabled
		if enabled:apply_candidate()
		var label:String="join_tissue_candidate" if enabled else "join_tissue_original"
		for kind:String in shots:await capture(label,kind,focus,shots[kind])
		await capture(label,"albedo_ground",focus,shots.ground,3)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Material-only private review source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_join_material_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"prototype_only":true,"production_registration":false,"private_terrain_shader_only":true,"geometry_changed":false,"collision_changed":false,"captures":records,"source_sha256":hashes,"scope":"Eight unchanged-camera/light/50km production-streamed original-versus-private material views at one real root, including albedo-only ground views. Private terrain shading converges to the existing apron tissue response near actual nerve influence; no production shader, shell shader, geometry, collision, texture, control channel, scene lighting or saved coverage mutation. Not exact complete albedo-join acceptance, mixed-owner/custom cases, performance or artistic sign-off."},"  "))
	print("JOIN_MATERIAL_RENDER_DONE ",records.size());scene.queue_free();await process_frame;quit()
