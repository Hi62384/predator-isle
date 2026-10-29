extends "res://tools/biome_extensions/render_all.gd"
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
const Full=preload("res://scripts/biome_extension_structures.gd")
const Prototype=preload("res://tools/biome_extensions/margin_retaining_lod_candidate.gd")
func worker_proof()->Dictionary:
	var candidates:Array=[]
	for node:MeshInstance3D in terrain._active_chunks.values():
		var key:Vector3i=node.get_meta("tile")
		if terrain.chunk_size*(1<<key.z)<8192:continue
		var payload:Dictionary=node.mesh.get_meta("collision_data")
		if payload.structure_faces.size()>1000:candidates.append(node)
	candidates.sort_custom(func(a,b):return a.mesh.get_meta("collision_data").structure_faces.size()<b.mesh.get_meta("collision_data").structure_faces.size())
	for node:MeshInstance3D in candidates.slice(0,12):
		var key:Vector3i=node.get_meta("tile");var b=Builder.new();b.world_seed=terrain.world_seed;b.water_level=terrain.water_level;b.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b._configure_noise();b.chunk_size=terrain.chunk_size*(1<<key.z)
		var coordinate:=Vector2i(key.x,key.y);var resolution:int=node.get_meta("resolution");b.build(coordinate,resolution)
		var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.build(b,coordinate)
		var steps:PackedFloat64Array=Full.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
		var expected:Array=Prototype.new().build(b,coordinate,steps,features.portal_sites)
		var payload:PackedVector3Array=node.mesh.get_meta("collision_data").structure_faces
		assert(expected[2]!=null and expected[2][Mesh.ARRAY_VERTEX]==payload,"Actual committed worker vertex positions must equal independent retained-contact emitter")
		var original:Array=Full.new().build(b,coordinate,steps,features.portal_sites)
		if original[2]==null or original[2][Mesh.ARRAY_VERTEX].size()<=payload.size():continue
		return {"tile":key,"span_m":b.chunk_size,"actual_worker_vertex_positions_matched":payload.size(),"original_full_vertices":original[2][Mesh.ARRAY_VERTEX].size(),"reduced":true,"scope":"Complete committed numeric worker position payload, not GPU readback; all non-position attributes, topology and ownership have separate guarded numerical checks"}
	return {}
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for path:String in ["res://scenes/main.tscn","res://project.godot","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/terrain_collision.gd","res://scripts/terrain_settings.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_conduit_contact_lod.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/rocky_coast_sampler.gd","res://scripts/beach_sampler.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/rocky_coast_material.gdshaderinc","res://shaders/beach_material.gdshaderinc","res://tools/biome_extensions/margin_retaining_lod_candidate.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/render_margin_lod_shores.gd","res://tools/biome_extensions/artifacts/check_margin_lod_shore_sites.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_margin_lod_shore_sites.json"));assert(admission.passed and admission.cases.size()==3)
	var proofs:Array=[]
	for site:Dictionary in admission.cases:
		var p:=Vector2(site.position[0],site.position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;camera.position=Vector3(p.x,site.canonical_ground_m+600,p.y)
		terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.target=camera;terrain.profile_streaming=true;terrain.extension_preview="Disabled"
		# Do not use extension_preview: it explicitly disables real coasts.
		terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		for key:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical","badlands"]+TerrainSettings.EXTENSION_KEYS:terrain.settings.set(key+"_coverage",0)
		terrain.settings.alien_infected_coverage=100;terrain.settings.rocky_coast_enabled=true;terrain.settings.beaches_enabled=true
		for property:String in ["start_in_beach","start_in_coast","start_in_mountain","start_in_swamp","start_in_savanna","start_in_forest","start_in_jungle","start_in_tropical","start_in_badlands"]:terrain.set(property,false)
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		assert(terrain._settings_snapshot.rocky_coast_enabled and terrain._settings_snapshot.beaches_enabled and terrain.maximum_lod==6 and terrain._settings_snapshot.alien_infected.hive_structure_lod_enabled)
		var ground:float=terrain._sampler._get_height(p.x,p.y);var coast_amount:float=terrain._sampler._last_coast.x
		assert(coast_amount>=.12 and absf(ground-site.canonical_ground_m)<.01,"Native fixture must retain the actual discovered shore, not silently disable its overlay")
		var proof:Dictionary=worker_proof();assert(not proof.is_empty(),"At least one complete actual far-worker retained-margin reduction required for every seeded shore scene");proof.seed=site.seed;proof.actual_coastal_overlay_amount=coast_amount;proofs.append(proof)
		print("MARGIN_SHORE_NATIVE_WORKER ",proof)
		var focus:=Vector3(p.x,ground+8,p.y)
		for view:String in ["medium","aerial","ground"]:
			var offset:Vector3=Vector3(-600,300,-800) if view=="medium" else (Vector3(-2400,1800,-3200) if view=="aerial" else Vector3(-90,4,-130))
			await capture("margin_shore_"+str(int(site.seed)),view,focus,offset);records[-1]["seed"]=site.seed;records[-1]["actual_root_coastal_overlay_amount"]=coast_amount
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Native shore source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_margin_lod_shores.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"actual_render":true,"production_registration":true,"captures":records,"worker_proofs":proofs,"source_sha256":hashes,"scope":"Nine actual production-worker native shore renders over three normal-rarity roots with genuine coastal overlay and default feature scale. Full maximum_lod6/50km hierarchy, original scene lighting, coast/beach/ordinary water and all normal morphology guards retained. Each seed additionally matches a complete actual far-worker position payload to the independent contact-retaining emitter and proves lower vertex count than the original full emitter. Other attributes/topology/ownership have separate checks. Settled frame/GPU samples are diagnostic, not shader-only timing, cold-launch, traversal, all shores or art acceptance."},"  "))
	print("MARGIN_SHORE_RENDER_DONE ",records.size());quit()
