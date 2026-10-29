extends "res://tools/biome_extensions/render_all.gd"
var candidate_visible:bool=false
var site:Dictionary={}
var patched:Dictionary={}
var private_replacements:int=0
func settle()->bool:
	var success:bool=await super.settle()
	if success and candidate_visible:replace_visible_junction()
	return success
func replace_visible_junction()->void:
	var p:=Vector2(site.position[0],site.position[1]);var field=terrain._sampler._extras[7];var cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var edges:PackedVector2Array=field.network_edges(cell);var d:Dictionary=field.descriptor(cell,4096)
	var directions:Array[Vector2]=[(edges[1]-p).normalized(),(edges[5]-p).normalized()]
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var origin:Vector3=node.global_position;var span:float=terrain.chunk_size*float(1<<key.z)
		if not Rect2(Vector2(origin.x,origin.z),Vector2.ONE*span).has_point(p):continue
		assert(span<=2048,"Private comparison requires the actual near root owner")
		var shell:MeshInstance3D=node.get_node_or_null("BiomeStructures");assert(shell!=null and shell.mesh!=null)
		if patched.get(shell.get_instance_id(),0)==shell.mesh.get_instance_id():return
		var original=preload("res://scripts/biome_extension_structures.gd").new();var changed=preload("res://scripts/biome_extension_structures.gd").new()
		for g in [original,changed]:g.origin=origin;g._support_steps=g.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
		preload("res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd").new().emit(original,terrain._sampler,p,directions,site.width,site.junction_height,d.angle)
		preload("res://tools/biome_extensions/membrane_junction_candidate.gd").new().emit(changed,terrain._sampler,p,directions,site.width,site.junction_height,d.angle)
		var mesh:=ArrayMesh.new();var found:bool=false
		for surface in range(shell.mesh.get_surface_count()):
			var material:ShaderMaterial=shell.mesh.surface_get_material(surface);var arrays:Array=shell.mesh.surface_get_arrays(surface)
			if int(material.get_shader_parameter("family"))==7:
				var count:int=arrays[Mesh.ARRAY_VERTEX].size()-original.vertices.size();assert(count>=0)
				assert(arrays[Mesh.ARRAY_VERTEX].slice(count)==original.vertices,"Exact actual streamed junction tail before private visible replacement")
				for pair:Array in [[Mesh.ARRAY_VERTEX,changed.vertices],[Mesh.ARRAY_NORMAL,changed.normals],[Mesh.ARRAY_COLOR,changed.colors],[Mesh.ARRAY_TEX_UV,changed.uvs]]:
					var values=arrays[pair[0]].slice(0,count);values.append_array(pair[1]);arrays[pair[0]]=values
				# GPU readback can expose implicit four-float tangents even though
				# the original numerical producer supplied none. This shader uses
				# explicit geometric/derivative normals, not a tangent attribute.
				arrays[Mesh.ARRAY_TANGENT]=null
				found=true
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(surface,material)
		assert(found);shell.mesh=mesh;patched[shell.get_instance_id()]=mesh.get_instance_id();private_replacements+=1;return
	assert(false,"Actual streamed root owner missing")
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://tools/biome_extensions/reference_pre_membrane_junction_geometry.gd","res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://tools/biome_extensions/junction_flutes_candidate.gd","res://tools/biome_extensions/membrane_geometry_candidate.gd","res://tools/biome_extensions/membrane_junction_candidate.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/render_fluted_membrane_candidate.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json","res://tools/biome_extensions/artifacts/check_membrane_junction_candidate.json"]:hashes[path]=FileAccess.get_sha256(path)
	var validation=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_membrane_junction_candidate.json"));assert(validation.passed)
	for source:String in validation.source_sha256:assert(FileAccess.get_sha256(source)==validation.source_sha256[source])
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed);site=admission.cases[0]
	var p:=Vector2(site.position[0],site.position[1]);var seed_id:int=site.seed
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.hive_longitudinal_ribs=false;terrain.settings.alien_infected.hive_membrane_frequency=0;terrain.settings.alien_infected.hive_surface_guided_roots=false;terrain.settings.alien_infected.hive_structure_lod_enabled=false
	var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
	var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y);var toward_sun:Vector3=scene.get_node("Sun").global_basis.z.normalized();var horizontal:=Vector2(toward_sun.x,toward_sun.z).normalized()*360
	var shots:Dictionary={"medium":Vector3(-240,140,-360),"ground":Vector3(-90,4-site.junction_height*.4,-130),"sunlit":Vector3(horizontal.x,160,horizontal.y)}
	for kind:String in shots:await capture("fluted_membrane_original_"+str(seed_id),kind,focus,shots[kind])
	candidate_visible=true
	for kind:String in shots:await capture("fluted_membrane_candidate_"+str(seed_id),kind,focus,shots[kind])
	assert(private_replacements>0)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Private visual replacement source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_fluted_membrane_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"prototype_only":true,"production_registration":false,"private_visible_mesh_replacement":true,"collision_changed":false,"private_replacements":private_replacements,"captures":records,"source_sha256":hashes,"scope":"Six same-camera/same-light original-versus-private fluted-blade/membrane views at one actual default-admitted root. Exact original streamed junction vertices are verified before replacing ONLY the visible junction tail in a private copied child mesh; conduit prefixes, caches, terrain and collision remain original. Not production worker/staging integration, collision/walk, performance or artistic acceptance."},"  "))
	print("FLUTED_MEMBRANE_RENDER_DONE ",records.size());scene.queue_free();await process_frame;quit()
