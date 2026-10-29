extends "res://tools/biome_extensions/render_all.gd"
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
const Emitter=preload("res://scripts/lod_biome_extension_structures.gd")
func worker_proof(site:Dictionary)->Dictionary:
	var p:=Vector2(site.position[0],site.position[1]);var owner:MeshInstance3D
	for node:MeshInstance3D in terrain._active_chunks.values():
		var key:Vector3i=node.get_meta("tile");var span:float=terrain.chunk_size*(1<<key.z)
		if Rect2(Vector2(key.x*span,key.y*span),Vector2.ONE*span).has_point(p):owner=node;break
	assert(owner!=null)
	var key:Vector3i=owner.get_meta("tile");var span:float=terrain.chunk_size*(1<<key.z);var coordinate:=Vector2i(key.x,key.y)
	var b=Builder.new();b.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=int(site.seed);b.water_level=terrain.water_level;b._configure_noise();b.chunk_size=span;b.build(coordinate,int(owner.get_meta("resolution")))
	var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.build(b,coordinate)
	var expected:Array=Emitter.new().build(b,coordinate,Emitter.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod),features.portal_sites)
	var payload:PackedVector3Array=owner.mesh.get_meta("collision_data").structure_faces
	assert(expected[1]!=null and payload==expected[1][Mesh.ARRAY_VERTEX],"Complete actual committed worker positions must equal independent rebuild")
	var center:=Vector3(p.x,site.ground-8,p.y)+Vector3(site.width*.16*sin(2+site.phase),site.height,site.width*.12)
	var query:=PhysicsRayQueryParameters3D.create(center+Vector3.UP*5,center-Vector3.UP*(site.vent_depth+2))
	for frame in range(3):await physics_frame
	var hit:Dictionary=owner.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and absf(hit.position.y-(center.y-site.vent_depth))<.03,"Actual streamed near collision must enter the shaft and meet its visible floor")
	return {"seed":site.seed,"id":site.id,"tile":key,"complete_worker_positions_matched":payload.size(),"near_native_floor_error_m":absf(hit.position.y-(center.y-site.vent_depth)),"depth_m":site.vent_depth,"blind_recess_not_passage":true}
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"))
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");hashes[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/biome_extensions/render_insect_vents.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/artifacts/check_insect_vents.json"]:hashes[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_insect_vents.json"));assert(manifest.passed and manifest.cases.size()==3)
	var proofs:Array=[]
	for site:Dictionary in manifest.cases:
		var p:=Vector2(site.position[0],site.position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="insect_colony";terrain.extension_preview_position=p;terrain.target=camera
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		assert(terrain._settings_snapshot.insect_colony.nest_vent_frequency==.25)
		var center:=Vector3(p.x,site.ground-8,p.y)+Vector3(site.width*.16*sin(2+site.phase),site.height,site.width*.12)
		await capture("insect_vent_"+str(int(site.seed)),"opening",center-Vector3.UP*site.vent_depth*.5,Vector3(-2,site.vent_depth*.5+14,-2))
		proofs.append(await worker_proof(site))
		await capture("insect_vent_"+str(int(site.seed)),"complex",Vector3(p.x,site.ground+site.height*.4,p.y),Vector3(-site.width*2,site.height*.6,-site.width*2.5))
		await capture("insect_vent_"+str(int(site.seed)),"normals",center-Vector3.UP*site.vent_depth*.5,Vector3(-2,site.vent_depth*.5+14,-2),4)
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during actual vent rendering")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_insect_vents.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"actual_render":true,"production_registration":true,"source_sha256":hashes,"captures":records,"worker_proofs":proofs,"scope":"Nine actual full-hierarchy production views over three default-rarity Insect summit recesses, unchanged lighting and settings except isolated owner/seed/preview location. Complete actual committed worker positions match independent rebuilds, and actual streamed near collision reaches the recess floor. Geometric-normal views are diagnostic, not measured normal-map/material or art acceptance. No traversable passage, infinite cave or broad performance claim."},"  "))
	print("INSECT_VENT_RENDER_DONE ",records.size()," actual views");quit()
