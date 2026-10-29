extends "res://tools/biome_extensions/render_all.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://tools/biome_extensions/membrane_geometry_candidate.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/render_membrane_candidate.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json","res://tools/biome_extensions/artifacts/check_membrane_candidate.json"]:hashes[path]=FileAccess.get_sha256(path)
	var validation=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_membrane_candidate.json"));assert(validation.passed)
	for source:String in validation.source_sha256:assert(FileAccess.get_sha256(source)==validation.source_sha256[source])
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed)
	for item:Dictionary in admission.cases.slice(0,1):
		var p:=Vector2(item.position[0],item.position[1]);var seed_id:int=item.seed
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
		# Keep this historical original/standalone-web comparison meaningful
		# after production adoption: never add a second web over an existing one.
		terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.hive_membrane_frequency=0;terrain.settings.alien_infected.hive_longitudinal_ribs=false;terrain.settings.alien_infected.hive_surface_guided_roots=false;terrain.settings.alien_infected.hive_structure_lod_enabled=false
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		assert(terrain._settings_snapshot.alien_infected.hive_membrane_frequency==0,"Explicit pre-adoption production baseline, not a duplicated wall")
		var field=terrain._sampler._extras[7];var cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var edges:PackedVector2Array=field.network_edges(cell);var descriptor:Dictionary=field.descriptor(cell,4096)
		var g=preload("res://scripts/biome_extension_structures.gd").new();g.origin=Vector3(p.x,0,p.y);g._support_steps=g.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
		preload("res://tools/biome_extensions/membrane_geometry_candidate.gd").new().emit(g,terrain._sampler,p,(edges[1]-p).normalized(),item.width,item.junction_height,descriptor.angle)
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=g.vertices;arrays[Mesh.ARRAY_NORMAL]=g.normals;arrays[Mesh.ARRAY_COLOR]=g.colors;arrays[Mesh.ARRAY_TEX_UV]=g.uvs
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,terrain._extension_materials[2])
		var web:=MeshInstance3D.new();web.mesh=mesh;web.position=g.origin;scene.add_child(web);web.hide()
		var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+item.junction_height*.4,p.y);var toward_sun:Vector3=scene.get_node("Sun").global_basis.z.normalized();var horizontal:=Vector2(toward_sun.x,toward_sun.z).normalized()*360
		var shots:Dictionary={"medium":Vector3(-240,140,-360),"ground":Vector3(-90,4-item.junction_height*.4,-130),"sunlit":Vector3(horizontal.x,160,horizontal.y)}
		for kind:String in shots:await capture("membrane_original_"+str(seed_id),kind,focus,shots[kind])
		web.show()
		for kind:String in shots:await capture("membrane_candidate_"+str(seed_id),kind,focus,shots[kind])
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Private membrane review source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_membrane_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"prototype_only":true,"production_registration":false,"standalone_private_mesh":true,"captures":records,"source_sha256":hashes,"scope":"Six same-camera/same-light original-versus-private membrane views at one real default-admitted streamed junction. The existing terrain/blades/strut use production workers; ONLY the added membrane is a standalone private numeric mesh using the actual production material and anchors. Not production worker/staging admission, native collision/walk, performance or artistic acceptance."},"  "))
	print("MEMBRANE_RENDER_DONE ",records.size());quit()
