extends "res://tools/biome_extensions/render_crystal_bulk_candidate.gd"
const ARCHIVE="res://tools/biome_extensions/artifacts/revisions/experiment_crystal_bulk_trial_68828270bd88/sources/"
func hash_value(value)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(value));return h.finish().hex_encode()
func configured_cut(enabled:bool)->Dictionary:
	var result:Dictionary={};var expected_shader:String="res://shaders/crystal_bulk.gdshader" if enabled else "res://shaders/crystal_transmission.gdshader"
	verify(terrain._settings_snapshot.crystal_wastes.crystal_bulk_material==enabled,"Actual immutable configured world control")
	verify(terrain._extension_materials[0].shader.resource_path==expected_shader,"Actual controller base material selects configured shader")
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var collision:Dictionary=node.mesh.get_meta("collision_data");var material:ShaderMaterial=node.mesh.surface_get_material(0);var atlas:Texture2D=material.get_shader_parameter("extension_payload")
		var record:Dictionary={"resolution":node.get_meta("resolution"),"terrain":digest(node.mesh),"collision":hash_value(collision),"control_atlas":hash_value(atlas.get_image().get_data()) if atlas!=null else "none","structures":"none","physical_structure":"none"}
		for name:String in ["swamp_water_mesh","terrain_features"]:record[name]=digest(node.mesh.get_meta(name)) if node.mesh.has_meta(name) else "none"
		var visible:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if visible!=null and visible.mesh!=null:
			var mesh:ArrayMesh=visible.mesh;record.structures=digest(mesh);var physical:Array=[];var vertices:=PackedVector3Array()
			for surface in range(mesh.get_surface_count()):
				var a:Array=mesh.surface_get_arrays(surface);physical.append([a[Mesh.ARRAY_VERTEX],a[Mesh.ARRAY_NORMAL],a[Mesh.ARRAY_COLOR],a[Mesh.ARRAY_INDEX]]);vertices.append_array(a[Mesh.ARRAY_VERTEX])
				var bound:ShaderMaterial=mesh.surface_get_material(surface);verify(bound.shader.resource_path==expected_shader,"Actual committed per-root material uses configured old/new shader")
				if enabled:
					for uv:Vector2 in a[Mesh.ARRAY_TEX_UV]:verify(uv.x>=0 and uv.x<=5.25 and uv.y>0,"Real worker/GPU optical habit and thickness metadata")
			verify(vertices==collision.structure_faces,"Unchanged complete actual worker collider positions match GPU geometry")
			record.physical_structure=hash_value(physical)
		result[str(key)]=record
	return result
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);hashes[path]=regression.source_sha256[raw]
	for path:String in ["res://tools/biome_extensions/render_crystal_bulk_registered.gd","res://tools/biome_extensions/render_crystal_bulk_candidate.gd","res://tools/biome_extensions/render_ground_union_worker_domains.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var geographic_path:String=ARCHIVE+"tools/biome_extensions/artifacts/previews.json.txt";var positive_path:String=ARCHIVE+"tools/biome_extensions/artifacts/admit_crystal_bulk_styles.json.txt";hashes[geographic_path]=FileAccess.get_sha256(geographic_path);hashes[positive_path]=FileAccess.get_sha256(positive_path)
	var previews=JSON.parse_string(FileAccess.get_file_as_string(geographic_path));var admission=JSON.parse_string(FileAccess.get_file_as_string(positive_path));assert(admission.passed)
	var cases:Array=[]
	for kind:int in range(6):
		var item:Dictionary=previews.families.crystal_wastes.regions[str(kind)];cases.append({"category":"original_geographic","kind":kind,"position":Vector2(item.x,item.z),"views":["ground","medium"]})
	for item:Dictionary in admission.cases:cases.append({"category":"additional_positive","kind":int(item.kind),"id":item.id,"position":Vector2(item.position[0],item.position[1]),"views":["medium"]})
	var records:Array=[];var phases:Array=[]
	for item:Dictionary in cases:
		var original_cut:Dictionary={};var original_images:Dictionary={}
		for phase in range(3):
			var enabled:bool=phase==1;var p:Vector2=item.position
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;terrain=scene.get_node("Terrain");terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.crystal_wastes.crystal_bulk_material=enabled;terrain.extension_preview="crystal_wastes";terrain.extension_preview_position=p;terrain.maximum_lod=4;terrain.world_seed=73921
			var target:=Marker3D.new();target.position=Vector3(p.x,0,p.y);scene.add_child(target);terrain.target=target;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());var focus:=Vector3(p.x,terrain.get_height_at(Vector3(p.x,0,p.y)),p.y)
			var frozen_count:int=freeze_water_time();var current:Dictionary=configured_cut(enabled);var changed:int=0
			if phase==0:original_cut=current
			else:
				verify(current.keys()==original_cut.keys(),"Same complete actual production partition")
				if phase==2:verify(current==original_cut,"Entire original cut restored,including prior UV arrays")
				for key:String in current:
					if not original_cut.has(key):continue
					for name:String in current[key]:
						if name!="structures":verify(current[key][name]==original_cut[key][name],"No geometry/collision/terrain/water/control change: "+name)
					if current[key].structures!=original_cut[key].structures:changed+=1
				if enabled:verify(changed>0,"Real configured workers change optical metadata")
			var positive_vertices:int=0
			if enabled and item.category=="additional_positive":
				for key:Vector3i in terrain._active_chunks:
					var node:MeshInstance3D=terrain._active_chunks[key];var span:float=terrain.chunk_size*float(1<<key.z)
					if not Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span).has_point(p):continue
					var visible:MeshInstance3D=node.get_node_or_null("BiomeStructures");verify(visible!=null,"Positive actual root is in committed cut")
					if visible==null:continue
					var arrays:Array=visible.mesh.surface_get_arrays(0);positive_vertices=arrays[Mesh.ARRAY_VERTEX].size()
					for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:verify(floori(uv.x)==item.kind,"Actual positive mineral habit from worker optical metadata")
				verify(positive_vertices>0,"Positive foreground crystal,not only an empty regional view")
			for view:String in item.views:
				var position:Vector3=focus+(Vector3(-60,4,-85) if view=="ground" else Vector3(-450,300,-650));position.y=maxf(position.y,terrain.get_height_at(position)+4);camera.position=position;camera.look_at(focus);terrain.set_debug_view(0)
				for idle in range(24):await process_frame
				var frames:Array=[];var gpu:Array=[];var last:int=Time.get_ticks_usec()
				for frame in range(30):
					await process_frame;var now:int=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now;var measured:float=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
					if measured>0:gpu.append(measured)
				await RenderingServer.frame_post_draw;var picture:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/crystal_bulk_registered_%s_%d_%s_%d.png"%[item.category,item.kind,view,phase];verify(picture.save_png(path)==OK,"Configured whole native image saved");captures[path]=FileAccess.get_sha256(path)
				var changed_bytes:int=0
				if phase==0:original_images[view]=picture
				else:changed_bytes=different(original_images[view],picture)
				records.append({"category":item.category,"kind":item.kind,"phase":phase,"enabled":enabled,"view":view,"focus":str(focus),"camera":str(position),"positive_intended_habit_vertices":positive_vertices,"different_bytes_from_original_cold_scene":changed_bytes,"gpu_p50_ms":median(gpu) if not gpu.is_empty() else null,"presented_frame_p50_ms":median(frames),"private_time_zero_material_bindings":frozen_count})
			phases.append({"category":item.category,"kind":item.kind,"phase":phase,"enabled":enabled,"leaves":current.size(),"changed_metadata_roots":changed,"cut":current});print("REGISTERED_CRYSTAL_BULK ",item.category," ",item.kind," phase=",phase," changed=",changed);scene.queue_free();await process_frame;await process_frame
	verify(captures.size()==54 and records.size()==54 and phases.size()==36,"All original18 views,54 images,36 configured cuts")
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable registered native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_crystal_bulk_registered.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":records,"phases":phases,"production_registration":true,"scope":"REGISTERED real immutable Resource crystal_bulk_material false/true/false and unchanged four-worker production controller;no constructor or displayed-mesh substitution. Six ORIGINAL geographic fixtures/two views plus six separately pre-admitted actual-habit positives/one view,36cuts/54images. Actual base and committed root shader bindings/positive habit metadata verified. Entire terrain/water/features/control atlas/structure physical arrays and complete worker collision bytes exact;only optical UV and shader change. Full original cut arrays restore. Cross-cold-scene image bytes reported,NOT strict exact-image proof;the frozen accepted private shader/body already has18 strict same-scene returns. Visible water heldTIME0 in private duplicates equally,not production animation/lighting changes. GPU/presentation observations30frames/view are NON-ISOLATED and may be VSync paced;not universal speedup. Marker-fixedLOD4/18km,not full-world art,traversal or cave completion."},"  "));quit(0 if failures.is_empty() else 1)
