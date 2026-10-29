extends "res://tools/biome_extensions/render_all.gd"
const Candidate=preload("res://tools/biome_extensions/insect_sculpted_mound_candidate.gd")
const Structures=preload("res://scripts/lod_biome_extension_structures.gd")
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array=[]
var checks:int=0
var captures:Dictionary={}
func registered_study()->bool:return false
func report_name()->String:return "render_insect_mound_profiles"
func image_prefix()->String:return "insect_mound_profile"
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func vec(value:String)->Vector3:
	var items:PackedStringArray=value.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(items[0]),float(items[1]),float(items[2]))
func picture(label:String)->Image:
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/"+image_prefix()+"_"+label+".png";check(image.save_png(path)==OK,"Saved native mound profile "+label);captures[path]=FileAccess.get_sha256(path);return image
func freeze_animated_materials()->int:
	# Visible water stays present;only private duplicated TIME uniforms freeze
	# for same-image comparisons. Live production animation is not changed.
	var cache:Dictionary={};var count:int=0
	for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null:continue
		for surface in range(node.mesh.get_surface_count()):
			var material:Material=node.get_active_material(surface)
			if not material is ShaderMaterial or not material.shader.code.contains("TIME"):continue
			if not cache.has(material):var copy:ShaderMaterial=material.duplicate();var shader:=Shader.new();shader.code=material.shader.code.replace("TIME","0.0");copy.shader=shader;cache[material]=copy
			node.set_surface_override_material(surface,cache[material]);count+=1
	scene.set_meta("profile_fixed_time_materials",cache);return count
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);hashes[path]=regression.source_sha256[relative]
	for path:String in ["res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/render_insect_mound_profiles.gd","res://tools/biome_extensions/insect_mound_profile_candidate.gd","res://tools/biome_extensions/insect_sculpted_mound_candidate.gd","res://tools/biome_extensions/artifacts/render_all.json"]:hashes[path]=FileAccess.get_sha256(path)
	hashes[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path);var baseline=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/render_all.json"));var views:Array=[];var focus:=Vector3(11406.63,70.50573,-3068.074)
	for view:Dictionary in baseline.captures:
		if view.biome=="insect_colony" and view.view in ["ground","medium","aerial"]:views.append({"name":"original_"+view.view,"point":vec(view.camera),"focus":vec(view.focus)})
	check(views.size()==3,"Every original geographic ground/medium/aerial pose retained");scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain=scene.get_node("Terrain");terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.insect_colony.nest_construction_profiles=false;terrain.extension_preview="insect_colony";terrain.extension_preview_position=Vector2(focus.x,focus.z);terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();check(await settle(),"Actual fullLOD6/four-worker scene committed");var b=Builder.new();b.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=terrain.world_seed;b.water_level=terrain.water_level;b._configure_noise();var descriptor:Dictionary=b._extras[6].nearby(Vector2(focus.x,focus.z),2100*b.settings.insect_colony.feature_scale);var p:Vector2=descriptor.position;var scale:float=b.settings.insect_colony.nest_height*(.45+descriptor.age);var center:=Vector3(p.x,b._get_height(p.x,p.y)+scale*.42,p.y);views.append({"name":"additional_front","point":center+Vector3(-scale*.8,scale*.1,-scale*1.3),"focus":center});views.append({"name":"additional_side","point":center+Vector3(scale*1.2,-scale*.1,scale*.5),"focus":center});var proofs:Array=[];var positive:int=0
	for view:Dictionary in views:
		var point:Vector3=view.point;point.y=maxf(point.y,terrain.get_height_at(point)+3);terrain.request_teleport(point);check(await settle(),"Actual camera cut committed "+view.name);camera.look_at(view.focus);var frozen_materials:int=freeze_animated_materials();var leaf:MeshInstance3D;var leaf_key:=Vector3i.ZERO
		for key:Vector3i in terrain._active_chunks:
			var span:float=terrain.chunk_size*(1<<key.z)
			if Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span).has_point(p):leaf=terrain._active_chunks[key];leaf_key=key;break
		check(is_instance_valid(leaf) and leaf.has_node("BiomeStructures"),"Original target has actual committed structure owner "+view.name)
		if not is_instance_valid(leaf) or not leaf.has_node("BiomeStructures"):continue
		var node:MeshInstance3D=leaf.get_node("BiomeStructures");var old:ArrayMesh=node.mesh;check(old!=null and old.get_surface_count()==1,"Single unchanged actual Insect material group");b.chunk_size=terrain.chunk_size*(1<<leaf_key.z);var features=preload("res://scripts/terrain_feature_meshes.gd").new();features.builder=b;var steps:PackedFloat64Array=Structures.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod);var began:int=Time.get_ticks_usec();var control:Array=Structures.new().build(b,Vector2i(leaf_key.x,leaf_key.y),steps,features.portal_sites);var old_usec:int=Time.get_ticks_usec()-began;began=Time.get_ticks_usec();b.settings.insect_colony.nest_construction_profiles=registered_study();var generator=Structures.new() if registered_study() else Candidate.new();var changed:Array=generator.build(b,Vector2i(leaf_key.x,leaf_key.y),steps,features.portal_sites);b.settings.insect_colony.nest_construction_profiles=false;var new_usec:int=Time.get_ticks_usec()-began;check(control[1]!=null and changed[1]!=null,"Both independent whole-worker geometry payloads exist");var reference:=ArrayMesh.new();reference.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,control[1]);check(var_to_bytes(reference.surface_get_arrays(0))==var_to_bytes(old.surface_get_arrays(0)),"Independent complete original root equals actual committed GPU arrays");var replacement:=ArrayMesh.new();replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,changed[1]);replacement.surface_set_material(0,old.surface_get_material(0));check(changed[1][Mesh.ARRAY_VERTEX]!=control[1][Mesh.ARRAY_VERTEX] and changed[1][Mesh.ARRAY_VERTEX].size()==control[1][Mesh.ARRAY_VERTEX].size(),"Positive actual equal-budget root intervention");var first:Image;var cost:Array=[]
		for phase in range(3):
			node.mesh=replacement if phase==1 else old;var image:Image=await picture(view.name+"_"+["original","candidate","original_return"][phase]);var gpu:Array=[]
			for frame in range(12):
				await process_frame;var value:float=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid());if value>0:gpu.append(value)
			cost.append(median(gpu))
			if phase==0:first=image
			elif phase==1:positive+=int(image.get_data()!=first.get_data())
			else:check(image.get_data()==first.get_data(),"Exact same-scene original full-image return "+view.name)
		proofs.append({"view":view.name,"camera":str(point),"focus":str(view.focus),"owner":str(leaf_key),"triangles":changed[1][Mesh.ARRAY_VERTEX].size()/3,"private_fixed_time_materials":frozen_materials,"reference_usec":old_usec,"candidate_usec":new_usec,"gpu_ordered_single_block_ms":cost});print("INSECT_PROFILE_NATIVE ",proofs[-1])
	check(positive>=3,"Positive visible geometry change in at least three retained actual views")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable native profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+report_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":proofs,"positive_image_views":positive,"production_registration":registered_study(),"scope":"Same-scene native equal-budget shell comparison on original actual Insect primary geography,fullLOD6/four-worker/50kmfar main scene. All three original ground/medium/aerial geographic poses retained plus two separately labelled close poses. Actual committed target-root GPU arrays equal independent original whole-worker rebuild before candidate replacement;original/candidate/original pixel return at each pose. Only target visual structure mesh replaced for study;production terrain/collision/settings/shader unchanged. Original full scene explicitly uses saved flagfalse. Registered child uses actual production whole-root build with flagtrue;private base uses prototype. Main-thread native collision/worker pipeline tested separately. Visible animated water is retained at TIME0 only in private duplicate materials for exact image controls;production animation unchanged. Ordered single worker/GPU observations are not isolated benchmark or speedup claims;no full art/all-task certificate."},"  "));print(report_name().to_upper()," ",checks," failures=",failures);scene.queue_free();quit(0 if failures.is_empty() else 1)
