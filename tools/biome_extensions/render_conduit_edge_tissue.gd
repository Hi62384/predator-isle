extends "res://tools/biome_extensions/render_all.gd"
const Candidate=preload("res://tools/biome_extensions/conduit_edge_tissue_candidate.gd")
var candidate_visible:bool=false
var patched:Dictionary={}
var replacements:int=0
var changed_vertices:int=0
var site:Dictionary={}
func apply_candidate()->void:
	var b=terrain._sampler;var old_size:float=b.chunk_size;var had_memo:bool=b.has_meta("conduit_geometry_memo_v1");var old_memo=b.get_meta("conduit_geometry_memo_v1") if had_memo else null
	var p:=Vector3(site.position[0],site.ground,site.position[1])
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var shell:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if shell==null or shell.mesh==null or not shell.get_aabb().grow(600).has_point(shell.to_local(p)):continue
		if patched.get(shell.get_instance_id(),0)==shell.mesh.get_instance_id():continue
		var span:float=terrain.chunk_size*float(1<<key.z);b.chunk_size=span
		var g=Candidate.new();g.conduit_cache_enabled=false;var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
		var data:Array=g.build(b,Vector2i(key.x,key.y),g.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod),guard.portal_sites)
		var mesh:=ArrayMesh.new();var changed:int=0
		for surface in range(shell.mesh.get_surface_count()):
			var material:ShaderMaterial=shell.mesh.surface_get_material(surface);var arrays:Array=shell.mesh.surface_get_arrays(surface)
			if int(material.get_shader_parameter("family"))==7:
				assert(data[2]!=null and arrays[Mesh.ARRAY_VERTEX]==data[2][Mesh.ARRAY_VERTEX],"Exact actual production positions before private alpha-only substitution")
				var previous:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var colors:PackedColorArray=previous.duplicate();var target:PackedColorArray=data[2][Mesh.ARRAY_COLOR]
				for i in range(colors.size()):
					if previous[i].a>.9 and target[i].a<.9:
						var tint:Color=colors[i];tint.a=target[i].a;colors[i]=tint;changed+=1
					assert(Vector3(colors[i].r,colors[i].g,colors[i].b)==Vector3(previous[i].r,previous[i].g,previous[i].b),"All actual uploaded authored RGB preserved")
				arrays[Mesh.ARRAY_COLOR]=colors
			# This shader uses explicit geometric/derivative normals, no tangent.
			arrays[Mesh.ARRAY_TANGENT]=null;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(surface,material)
		if changed>0:shell.mesh=mesh;replacements+=1;changed_vertices+=changed
		patched[shell.get_instance_id()]=shell.mesh.get_instance_id()
	b.chunk_size=old_size
	if had_memo:b.set_meta("conduit_geometry_memo_v1",old_memo)
	elif b.has_meta("conduit_geometry_memo_v1"):b.remove_meta("conduit_geometry_memo_v1")
func settle()->bool:
	var success:bool=await super.settle()
	if success and candidate_visible:apply_candidate()
	return success
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/biome_extension_settings.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/conduit_edge_tissue_candidate.gd","res://tools/biome_extensions/render_conduit_edge_tissue.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json","res://tools/biome_extensions/artifacts/check_conduit_edge_tissue.json"]:hashes[path]=FileAccess.get_sha256(path)
	var validation=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_conduit_edge_tissue.json"));assert(validation.passed)
	for source:String in validation.source_sha256:assert(FileAccess.get_sha256(source)==validation.source_sha256[source])
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed);site=admission.cases[0]
	var p:=Vector2(site.position[0],site.position[1]);var seed_id:int=site.seed
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
	var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
	var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y);var sun:Vector3=scene.get_node("Sun").global_basis.z.normalized();var horizontal:=Vector2(sun.x,sun.z).normalized()*360
	var shots:Dictionary={"medium":Vector3(-240,140,-360),"ground":Vector3(-90,4-site.junction_height*.4,-130),"sunlit":Vector3(horizontal.x,160,horizontal.y)}
	for enabled:bool in [false,true]:
		candidate_visible=enabled
		var label:String="edge_tissue_candidate" if enabled else "edge_tissue_original"
		for kind:String in shots:await capture(label,kind,focus,shots[kind])
		await capture(label,"albedo_ground",focus,shots.ground,3)
	assert(replacements>0 and changed_vertices>100,"Actual original core alpha tags changed on visible production structures")
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Private alpha-only review source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_conduit_edge_tissue.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"prototype_only":true,"production_registration":false,"private_visible_alpha_only":true,"geometry_changed":false,"collision_changed":false,"private_mesh_replacements":replacements,"changed_alpha_vertices":changed_vertices,"captures":records,"source_sha256":hashes,"scope":"Eight same-camera/light/50km original-versus-private core-alpha transition views, including albedo-only ground, at one actual default junction. Exact original streamed vertices verified before changing ONLY selected alpha values in copied visible shell meshes; uploaded RGB/normals/UVs, shaders, collision and production geometry stay original. Not production integration, exact complete join acceptance, mixed/custom/native walk or performance acceptance."},"  "))
	print("CONDUIT_EDGE_TISSUE_RENDER ",records.size()," changed=",changed_vertices," replacements=",replacements);scene.queue_free();await process_frame;quit()
