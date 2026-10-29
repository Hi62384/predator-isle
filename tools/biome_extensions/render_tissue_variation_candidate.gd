extends "res://tools/biome_extensions/profile_tissue_flow_runtime.gd"
const CANDIDATE=preload("res://tools/biome_extensions/tissue_variation_candidate.gd")
const FROZEN="res://tools/biome_extensions/artifacts/revisions/experiment_tissue_flow_adoption_1e396f3b7915/sources/tools/biome_extensions/artifacts/render_alien_tissue_flow.json.txt"
var failures:Array=[]
var captures:Dictionary={}
func mesh_digest(mesh:ArrayMesh)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	for key:String in ["collision_data","swamp_water_mesh","terrain_features","extension_structures"]:
		if not mesh.has_meta(key):continue
		var payload=mesh.get_meta(key)
		if payload is ArrayMesh:
			for surface in range(payload.get_surface_count()):hash.update(var_to_bytes(payload.surface_get_arrays(surface)))
		else:hash.update(var_to_bytes(payload))
	return hash.finish().hex_encode()
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);print("FAILED_VARIATION_NATIVE ",label)
func set_variation(enabled:bool)->void:
	for node:MeshInstance3D in terrain._active_chunks.values():
		if node.mesh.has_meta("alien_tissue_flow"):node.mesh.surface_get_material(0).set_shader_parameter("alien_tissue_variation_enabled",enabled)
		if node.mesh.has_meta("extension_structures"):
			var mesh:ArrayMesh=node.mesh.get_meta("extension_structures")
			for surface in range(mesh.get_surface_count()):
				var material:ShaderMaterial=mesh.surface_get_material(surface)
				if material.get_shader_parameter("family")==7:material.set_shader_parameter("alien_tissue_variation_enabled",enabled)
func snapshot(path:String)->Image:
	for idle in range(24):await process_frame
	await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();verify(image.save_png(path)==OK,"Actual variation image saved");captures[path]=FileAccess.get_sha256(path);return image
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(FROZEN));assert(fixture.passed)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);hashes[path]=regression.source_sha256[relative]
	for path:String in [FROZEN,"res://tools/biome_extensions/render_tissue_variation_candidate.gd","res://tools/biome_extensions/tissue_variation_candidate.gd","res://tools/biome_extensions/profile_tissue_flow_runtime.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var include:Resource=load(CANDIDATE.BASE);var baseline:String=include.get("code");var candidate:String=CANDIDATE.source_for(baseline);set_meta("held_variation_include",include)
	var cuts:Array=[]
	for seed_id:int in [73921,17,92881]:
		var views:Array=[]
		for view:Dictionary in fixture.views:
			if view.seed==seed_id and view.phase==1:views.append(view)
		assert(views.size()==3);var focus:Vector3=vector(views[0].focus);var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(seed_id,true)
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;camera.position=vector(views[0].camera);terrain=scene.get_node("Terrain");terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.emission_strength=0;terrain.world_seed=seed_id;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
		for property:Dictionary in terrain.get_property_list():
			if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
		var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;root.add_child(scene);scene.get_node("Interface").hide();verify(await settle(),"Actual four-worker cut committed")
		var cut:Dictionary={}
		for key:Vector3i in terrain._active_chunks:
			var node:MeshInstance3D=terrain._active_chunks[key];cut[str(key)]=mesh_digest(node.mesh)
		if terrain._water!=null:terrain._water.hide()
		for node:MeshInstance3D in terrain._active_chunks.values():
			var water:Node3D=node.get_node_or_null("SwampWater")
			if water!=null:water.hide()
		for view:Dictionary in views:
			camera.position=vector(view.camera);camera.look_at(focus);var prefix:String="res://tools/biome_extensions/artifacts/tissue_variation_%d_%s_"%[seed_id,view.view]
			include.set("code",baseline);var original:Image=await snapshot(prefix+"original.png")
			include.set("code",candidate);set_variation(false);var off:Image=await snapshot(prefix+"candidate_off.png");verify(off.get_data()==original.get_data(),"Candidate false exactly matches actual original same-scene image")
			set_variation(true);var on:Image=await snapshot(prefix+"candidate_on.png");var changed:int=0;var a:PackedByteArray=on.get_data();var b:PackedByteArray=original.get_data()
			for index in range(a.size()):
				if a[index]!=b[index]:changed+=1
			verify(changed>100,"Actual private material variation used")
			set_variation(false);var returned:Image=await snapshot(prefix+"candidate_return.png");verify(returned.get_data()==original.get_data(),"Actual candidate return exact")
			include.set("code",baseline);var restored:Image=await snapshot(prefix+"original_return.png");verify(restored.get_data()==original.get_data(),"Actual restored original shader exact")
			records.append({"seed":seed_id,"view":view.view,"focus":str(focus),"camera":str(camera.position),"changed_bytes":changed,"candidate_off_exact":off.get_data()==original.get_data(),"candidate_return_exact":returned.get_data()==original.get_data(),"original_return_exact":restored.get_data()==original.get_data()})
		for key:Vector3i in terrain._active_chunks:
			verify(cut[str(key)]==mesh_digest(terrain._active_chunks[key].mesh),"Material study never changes physical terrain/water/features/structures/collision")
		cuts.append({"seed":seed_id,"leaves":terrain._active_chunks.size(),"cut":cut});print("TISSUE_VARIATION_NATIVE ",seed_id);scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable candidate native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_tissue_variation_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":records,"cuts":cuts,"scope":"Private Resource-only material variation at the EXACT nine frozen adoption views across three actual native production cuts/four workers. Flow enabled in every case. Within-scene original/candidate-false/candidate-true/candidate-false/original controls;all off/returns exact. Geometry/lighting/targets fixed,no scene reroll.45images. This verifies intervention/return,not artistic quality or performance."},"  "));quit(0 if failures.is_empty() else 1)
