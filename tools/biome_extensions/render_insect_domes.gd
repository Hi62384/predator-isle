extends "res://tools/biome_extensions/render_insect_vents.gd"
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var inventory=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"))
	for raw:String in inventory.source_sha256:
		var path:String="res://"+raw.replace("\\","/");hashes[path]=FileAccess.get_sha256(path)
	for path:String in ["res://tools/biome_extensions/render_insect_domes.gd","res://tools/biome_extensions/render_insect_vents.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/artifacts/check_insect_domes.json"]:hashes[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_insect_domes.json"));assert(manifest.passed and manifest.sites.size()==3)
	var proofs:Array=[]
	for original:Dictionary in manifest.sites:
		var site:Dictionary=original.duplicate(true);var p:=Vector2(site.position[0],site.position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="insect_colony";terrain.extension_preview_position=p;terrain.target=camera
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		assert(terrain._settings_snapshot.insect_colony.nest_broad_domes and terrain._settings_snapshot.insect_colony.nest_vent_frequency==.25)
		site["vent_depth"]=0.0
		var field=terrain._sampler._extras[6]
		if site.height>=40 and field.random(site.cell[0],site.cell[1],178)<.25:
			site.vent_depth=preload("res://scripts/insect_vent_geometry.gd").admitted_depth(terrain._sampler,Vector3(p.x,site.ground-8,p.y),site.width,site.height,site.phase,minf(site.height*.18,24))
		var focus:=Vector3(p.x,site.ground+site.height*.4,p.y)
		await capture("insect_dome_"+str(int(site.seed)),"ground",focus,Vector3(-site.width*2,4-site.height*.4,-site.width*2.5))
		var proof:Dictionary=await worker_proof(site);proof["dome_width_parameter_m"]=site.width;proof["dome_height_parameter_m"]=site.height;proof["vented"]=site.vent_depth>0;proof["blind_recess_not_passage"]=site.vent_depth>0;proofs.append(proof)
		await capture("insect_dome_"+str(int(site.seed)),"aerial",focus,Vector3(-site.width*.8,site.width*.9,-site.width))
		await capture("insect_dome_"+str(int(site.seed)),"normals",focus,Vector3(-site.width*.8,site.width*.9,-site.width),4)
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during actual dome rendering")
	FileAccess.open("res://tools/biome_extensions/artifacts/render_insect_domes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"actual_render":true,"production_registration":true,"source_sha256":hashes,"captures":records,"worker_proofs":proofs,"scope":"Nine actual full-hierarchy production dome views over three default-rarity sites with unchanged lighting. Full actual committed worker positions equal independent rebuilds; actual near collision reaches the cap or recess floor as independently expected. Real default vent admission is retained, not forced. No private substitute mesh, new textures, cave or artistic/completion certificate."},"  "))
	print("INSECT_DOME_RENDER_DONE ",records.size()," actual views");quit()
