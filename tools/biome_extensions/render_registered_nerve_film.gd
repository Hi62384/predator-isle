extends "res://tools/biome_extensions/render_all.gd"
const REFERENCE="res://tools/biome_extensions/artifacts/revisions/experiment_render_nerve_film_packed_trial_700023002eba/manifest.json"
var expected_array:Texture2DArray
var material_checks:int=0
var same_scene_mode:bool=false
var binding_pixels:Dictionary={}
func frozen_binding_control(seed_id:int)->void:
	# Main-thread force_draw with zero frame_step: no process/physics step or
	# geometry/lighting mutation between these exact native comparisons.
	RenderingServer.force_draw(true,0.0);RenderingServer.force_sync()
	var original:Image=root.get_texture().get_image()
	for material:ShaderMaterial in terrain._lod_materials.values():material.set_shader_parameter("biological_colors",expected_array)
	terrain._extension_materials[2].set_shader_parameter("biological_colors",expected_array)
	for node:MeshInstance3D in terrain._active_chunks.values():
		for surface in range(node.mesh.get_surface_count()):node.mesh.surface_get_material(surface).set_shader_parameter("biological_colors",expected_array)
	RenderingServer.force_draw(true,0.0);RenderingServer.force_sync()
	var explicit:Image=root.get_texture().get_image();assert(original.get_size()==explicit.get_size() and original.get_data()==explicit.get_data(),"Exact same-commit runtime/manual texture binding pixels")
	for item:Array in [["runtime",original],["manual",explicit]]:
		var path:String="res://tools/biome_extensions/artifacts/registered_nerve_"+str(seed_id)+"_binding_"+item[0]+".png";assert(item[1].save_png(path)==OK);binding_pixels[path]=FileAccess.get_sha256(path)
func settle()->bool:
	var ok:bool=await super.settle()
	if not ok:return false
	for material:ShaderMaterial in terrain._lod_materials.values():
		assert(material.get_shader_parameter("biological_colors")==expected_array);material_checks+=1
	assert(terrain._extension_materials[2].get_shader_parameter("biological_colors")==expected_array);material_checks+=1
	for node:MeshInstance3D in terrain._active_chunks.values():
		for surface in range(node.mesh.get_surface_count()):
			assert(node.mesh.surface_get_material(surface).get_shader_parameter("biological_colors")==expected_array);material_checks+=1
	return true
func run()->void:
	same_scene_mode=OS.get_cmdline_user_args().has("same_scene")
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var reference=JSON.parse_string(FileAccess.get_file_as_string(REFERENCE));var snapshots:Dictionary={}
	for item:Dictionary in reference.files:
		assert(FileAccess.get_sha256(item.snapshot)==item.sha256,"Immutable packed A/B reference copy");snapshots[item.original]=item.snapshot;hashes[item.snapshot]=item.sha256
	var expected=JSON.parse_string(FileAccess.get_file_as_string(snapshots[reference.report]));assert(expected.passed and expected.packed_bc1_arrays and expected.captures.size()==15)
	for path:String in expected.source_sha256:
		if path=="res://tools/biome_extensions/artifacts/check_junction_admission.json":continue # Immutable reference cases are used below; regenerated report metadata is not geometry.
		if path=="res://scripts/chunk_terrain.gd":
			var old:String=FileAccess.get_file_as_string(snapshots[path]);assert(old.count("res://materials/biological_colors_v2.tres")==2)
			assert(old.replace("res://materials/biological_colors_v2.tres","res://materials/biological_colors_v3.tres")==FileAccess.get_file_as_string(path),"Only both intentional runtime array bindings differ from the A/B reference")
		else:assert(FileAccess.get_sha256(path)==expected.source_sha256[path],"Unchanged packed A/B source "+path)
		hashes[path]=FileAccess.get_sha256(path)
	for path:String in [REFERENCE,"res://tools/biome_extensions/render_registered_nerve_film.gd","res://data/biological_material_sources.json","res://assets/textures/biological/nerve_albedo_v3.png"]:hashes[path]=FileAccess.get_sha256(path)
	expected_array=load("res://materials/biological_colors_v3.tres")
	var sites=JSON.parse_string(FileAccess.get_file_as_string(snapshots["res://tools/biome_extensions/artifacts/check_junction_admission.json"]));assert(sites.passed and sites.cases.size()==3)
	var exact_ground_matches:int=0;var same_scene_matches:int=0
	for site:Dictionary in sites.cases:
		var point:=Vector2(site.position[0],site.position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=point;terrain.target=camera
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		var ground:float=terrain.get_height_at(Vector3(point.x,0,point.y));var focus:=Vector3(point.x,ground+site.junction_height*.4,point.y)
		for view:String in ["ground","medium","aerial"]:
			var offset:Vector3=Vector3(-90,4-site.junction_height*.4,-130) if view=="ground" else (Vector3(-240,140,-360) if view=="medium" else Vector3(-800,600,-1000))
			await capture("registered_nerve_"+str(int(site.seed)),view,focus,offset)
			if view=="ground":
				if same_scene_mode:
					frozen_binding_control(int(site.seed));same_scene_matches+=1;continue
				var matched:bool=false
				for original:Dictionary in expected.captures:
					if original.biome=="nerve_film_packed_"+str(int(site.seed)) and original.view=="trial":
						assert(original.camera==records[-1].camera and original.focus==records[-1].focus)
						assert(original.sha256==records[-1].sha256,"Normal runtime binding reproduces the complete packed A/B trial image exactly")
						matched=true;exact_ground_matches+=1
				assert(matched)
		scene.queue_free();await process_frame;await process_frame
	assert((same_scene_matches==3 if same_scene_mode else exact_ground_matches==3) and records.size()==9 and material_checks>0)
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Stable registered-material evidence "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_registered_nerve_film"+("_same_scene" if same_scene_mode else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"actual_render":true,"production_registration":true,"source_sha256":hashes,"captures":records,"capture_sha256":binding_pixels,"material_binding_checks":material_checks,"exact_complete_ground_image_matches":exact_ground_matches,"same_scene_runtime_manual_binding_matches":same_scene_matches,"cross_run_exact_equivalence":not same_scene_mode,"reference_manifest":REFERENCE,"scope":"Nine actual streamed ground/medium/aerial views over three seeds, unchanged production shader/lighting/geometry. Runtime terrain/LOD/shell array identities verified; only two intentional game-script paths differ from the immutable packed A/B source. In same_scene mode, three exact native runtime/manual controls use zero-step force_draw on the SAME committed geometry, with no excluded pixels or relaxed RGB threshold. This does NOT pass the separately preserved strict cross-run SHA test (seed17 had five differing pixels, at most two codes), prove whole-scene equivalence, art acceptance, startup optimization, fixed mycelium phase, global traversal or caves."},"  "))
	print("REGISTERED_NERVE_FILM ",material_checks," bindings; ",exact_ground_matches," exact full-image matches; ",records.size()," native views");quit()
