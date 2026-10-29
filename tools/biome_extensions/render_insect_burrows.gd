extends "res://tools/biome_extensions/render_insect_vents.gd"
const DISCOVERY="res://tools/biome_extensions/artifacts/revisions/experiment_find_insect_burrow_conflicts_wide_24a12b15e1b3/evidence/tools/biome_extensions/artifacts/find_insect_burrow_conflicts_wide.json"
func clearance(record:Dictionary)->Dictionary:
	var q:=Vector2(record.mound_position[0],record.mound_position[1]);var owner:MeshInstance3D
	for node:MeshInstance3D in terrain._active_chunks.values():
		var key:Vector3i=node.get_meta("tile");var span:float=terrain.chunk_size*(1<<key.z)
		if Rect2(Vector2(key.x*span,key.y*span),Vector2.ONE*span).has_point(q):owner=node;break
	assert(owner!=null and owner.get_meta("tile").z==0)
	var faces:PackedVector3Array=owner.mesh.get_meta("collision_data").structure_faces;assert(faces.is_empty())
	var b=Builder.new();b.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.insect_colony.nest_protect_burrows=false;b.world_seed=17;b._configure_noise();b.chunk_size=256
	var key:Vector3i=owner.get_meta("tile");var coordinate:=Vector2i(key.x,key.y);b.build(coordinate,owner.get_meta("resolution"))
	var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.build(b,coordinate)
	var old:Array=Emitter.new().build(b,coordinate,Emitter.support_grids(),features.portal_sites)
	assert(old[1]!=null and old[1][Mesh.ARRAY_VERTEX].size()==int(record.structure_vertices))
	return {"portal_id":record.portal_id,"mound_id":record.mound_id,"actual_committed_worker_vertices":0,"independent_unsafe_vertices":old[1][Mesh.ARRAY_VERTEX].size(),"actual_default_cave_frequency":terrain._settings_snapshot.insect_colony.cave_frequency,"root_tile":key}
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var inventory=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"))
	for raw:String in inventory.source_sha256:
		var path:String="res://"+raw.replace("\\","/");hashes[path]=FileAccess.get_sha256(path)
	for path:String in [DISCOVERY,"res://tools/biome_extensions/render_insect_burrows.gd","res://tools/biome_extensions/render_insect_vents.gd","res://tools/biome_extensions/render_all.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var discovery=JSON.parse_string(FileAccess.get_file_as_string(DISCOVERY));assert(discovery.passed and discovery.candidates.size()==2)
	var proofs:Array=[]
	for index in range(2):
		var record:Dictionary=discovery.candidates[index];var p:=Vector2(record.portal_position[0],record.portal_position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=17;terrain.extension_preview="insect_colony";terrain.extension_preview_position=p;terrain.target=camera
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		assert(terrain._settings_snapshot.insect_colony.nest_protect_burrows and terrain._settings_snapshot.insect_colony.cave_frequency==.18)
		var portal:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y)),p.y)
		allow_subsurface=false
		await capture("insect_burrow_"+str(index),"entry",portal,Vector3(150,70,-70));proofs.append(clearance(record))
		await capture("insect_burrow_"+str(index),"aerial",portal,Vector3(-500,420,-600))
		allow_subsurface=true
		await capture("insect_burrow_"+str(index),"gallery",Vector3(p.x+112,float(record.portal.floor)+5,p.y),Vector3(90,0,3))
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Stable native burrow source")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_insect_burrows.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"actual_render":true,"production_registration":true,"captures":records,"worker_proofs":proofs,"source_sha256":hashes,"scope":"Six actual full-hierarchy production entry/aerial/gallery views at the two frozen default-rarity finite Insect burrows, original lighting and default cave frequency0.18. Actual committed close-worker payload excludes the obstructing complex; independent unsafe-mode rebuild recovers all37044 original vertices at each root. Interior camera is explicitly inside the existing finite gallery, not height-clamped above it. Capsule returns, geometry controls and warning/performance scopes remain separate. No infinite cave claim."},"  "))
	print("INSECT_BURROW_RENDER_DONE ",records.size()," native views");quit()
