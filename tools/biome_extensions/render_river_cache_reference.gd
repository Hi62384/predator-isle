extends "res://tools/biome_extensions/render_all.gd"
var images:Dictionary={}
var phases:Array=[]
var failures:Array=[]
var pixel_differences:Array=[]
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func mesh_digest(mesh:ArrayMesh)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return hash.finish().hex_encode()
func cut_digest()->Dictionary:
	var result:Dictionary={}
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var record:Dictionary={"resolution":node.get_meta("resolution"),"terrain":mesh_digest(node.mesh),"collision":var_to_bytes(node.mesh.get_meta("collision_data")).hex_encode().sha256_text()}
		for type:String in ["swamp_water_mesh","terrain_features","extension_structures"]:record[type]=mesh_digest(node.mesh.get_meta(type)) if node.mesh.has_meta(type) else "none"
		result[str(key)]=record
	return result
func different(a:Image,b:Image)->int:
	if a.get_size()!=b.get_size() or a.get_format()!=b.get_format():return -1
	var first:PackedByteArray=a.get_data();var second:PackedByteArray=b.get_data();var count:int=0
	for index in range(first.size()):
		if first[index]!=second[index]:count+=1
	return count
func run()->void:
	verify(DisplayServer.get_name()!="headless","Native rendering required")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");verify(FileAccess.get_sha256(path)==regression.source_sha256[relative],"Current shared regression source "+path);hashes[path]=regression.source_sha256[relative]
	for path:String in ["res://tools/biome_extensions/render_river_cache_reference.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/check_river_cached_meshes.gd","res://tools/biome_extensions/uncached_river_builder_oracle.gd","res://tools/biome_extensions/uncached_river_mountain_oracle.gd","res://data/surface_regression_20261018.json"]:hashes[path]=FileAccess.get_sha256(path)
	var original:String=FileAccess.get_file_as_string("res://scripts/chunk_terrain.gd").replace("\r\n","\n")
	var marker:String='const MeshBuilder = preload("res://scripts/terrain_mesh_builder.gd")';assert(original.count(marker)==1 and original.begins_with("class_name ChunkTerrain\n"))
	var reference_code:String=original.trim_prefix("class_name ChunkTerrain\n").replace(marker,'const MeshBuilder = preload("res://tools/biome_extensions/uncached_river_builder_oracle.gd")')
	var reference_script:=GDScript.new();reference_script.source_code=reference_code;assert(reference_script.reload()==OK)
	var generated_path:String="res://tools/biome_extensions/artifacts/river_cache_reference_controller.txt";FileAccess.open(generated_path,FileAccess.WRITE).store_string(reference_code);hashes[generated_path]=FileAccess.get_sha256(generated_path)
	if not failures.is_empty():quit(1);return
	for seed_id:int in [73921,17,92881]:
		var locator=preload("res://tools/biome_extensions/check_river_cached_meshes.gd").make(seed_id,4,false);var point:=Vector2.INF;var score:float=-1
		for index in range(1200):
			var q:=Vector2(index*7919%120000-60000,index*11939%120000-60000)
			if locator._island_mask(q.x,q.y)<.2:continue
			var h:float=locator._get_height(q.x,q.y)
			if h<=locator.get_water_surface_height(q.x,q.y)+2:continue
			locator._biome_weights(q.x,q.y);var value:float=minf(locator._mountain_weight,locator._tropical_weight)
			if value>score:score=value;point=q
		# A random inland sample can miss the narrow shared-owner strip. Keep
		# the first1200-proposal site when admitted; otherwise discover a real
		# transition before freezing any camera/target for that seed.
		if score<=.01:
			for index in range(1200,24000):
				var q:=Vector2(index*7919%120000-60000,index*11939%120000-60000)
				locator._biome_weights(q.x,q.y);var value:float=minf(locator._mountain_weight,locator._tropical_weight)
				if value<=.01 or locator._island_mask(q.x,q.y)<.2:continue
				var h:float=locator._get_height(q.x,q.y)
				if h<=locator.get_water_surface_height(q.x,q.y)+2:continue
				point=q;score=value;break
		verify(point.is_finite() and score>.01,"Actual Mountain/Tropical overlap in this low-frequency world")
		var focus:=Vector3(point.x,locator._get_height(point.x,point.y)+3,point.y)
		var views:Dictionary={"valley":focus+Vector3(-300,240,-450),"overview":focus+Vector3(-1000,1000,-1500)}
		for kind:String in views:
			var viewpoint:Vector3=views[kind];viewpoint.y=maxf(viewpoint.y,locator._get_height(viewpoint.x,viewpoint.z)+80);views[kind]=viewpoint
		var expected:Dictionary={};var original_images:Dictionary={}
		for phase in range(3):
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;terrain=scene.get_node("Terrain")
			if phase==1:terrain.set_script(reference_script)
			terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.world_seed=seed_id;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
			for property:Dictionary in terrain.get_property_list():
				if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
			var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;camera.position=views.valley
			var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();verify(await settle(),"Actual committed cached/reference cut")
			var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0
			verify(Vector2(terrain.target.global_position.x,terrain.target.global_position.z).distance_to(point)<.01,"No fixture preview relocation")
			verify(terrain._sampler.get_script()==(preload("res://tools/biome_extensions/uncached_river_builder_oracle.gd") if phase==1 else preload("res://scripts/terrain_mesh_builder.gd")),"Actual controller sampler uses the declared cache mode")
			var workers:int=0
			for builder in terrain._idle_builders:verify(builder.get_script()==terrain._sampler.get_script(),"Every actual completed worker uses the same declared cache mode");workers+=1
			verify(workers>0,"Actual worker production occurred")
			var probes:int=0
			for key:Vector3i in terrain._active_chunks:
				var node:MeshInstance3D=terrain._active_chunks[key];var resolution:int=node.get_meta("resolution");var arrays:Array=node.mesh.surface_get_arrays(0)
				for index in range(0,(resolution+1)*(resolution+1),maxi(1,resolution*8)):
					var world:Vector3=node.position+arrays[Mesh.ARRAY_VERTEX][index];verify(absf(terrain.get_height_at(world)-world.y)<.001,"Committed worker height is canonical");probes+=1
			var cut:Dictionary=cut_digest()
			if phase==0:expected=cut
			else:verify(expected==cut,"Complete terrain/water/features/structures/collision cut equals original cached phase")
			phases.append({"seed":seed_id,"phase":phase,"oracle":phase==1,"leaves":cut.size(),"workers":workers,"canonical_probes":probes,"complete_reference_equal":phase>0,"initial_fill_seconds":elapsed,"cut":cut})
			# Remove only animated water from these optional image comparisons.
			# Its complete CPU geometry remains included above. Lighting unchanged.
			if terrain._water!=null:terrain._water.hide()
			for node:MeshInstance3D in terrain._active_chunks.values():
				var water:Node3D=node.get_node_or_null("SwampWater")
				if water!=null:water.hide()
			for kind:String in views:
				camera.position=views[kind];camera.look_at(focus)
				for frame in range(24):await process_frame
				await RenderingServer.frame_post_draw
				var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/river_cache_%d_%d_%s.png" % [seed_id,phase,kind];verify(image.save_png(path)==OK,"Native review image saved");images[path]=FileAccess.get_sha256(path)
				var delta:int=0
				if phase==0:original_images[kind]=image
				else:delta=different(original_images[kind],image)
				if delta!=0:pixel_differences.append({"seed":seed_id,"phase":phase,"view":kind,"different_bytes":delta})
				records.append({"seed":seed_id,"phase":phase,"view":kind,"focus":str(focus),"camera":str(camera.position),"width":image.get_width(),"height":image.get_height(),"capture":path,"sha256":images[path],"cross_scene_different_bytes":delta})
			print("RIVER_CACHE_NATIVE ",seed_id," phase=",phase," workers=",workers," leaves=",cut.size()," fill=",elapsed)
			scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Source unchanged during reference render "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_river_cache_reference.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":images,"views":records,"phases":phases,"cross_scene_pixel_equivalent":pixel_differences.is_empty(),"cross_scene_pixel_differences":pixel_differences,"scope":"Three seeded real Mountain/Tropical mixed worlds at valid river_frequency.05/ridge_scale1.35. Actual production controller/workers compared cached/uncached-oracle/cached,complete committed terrain,water,feature,structure and collision arrays plus canonical probes. Anonymous reference controller changes only the builder class to cache-cleared actual functions;no alternate formula,worker count,lighting or terrain algorithm. Fixed target and two views,18 native images,boundedLOD4/18km fixture. Water hidden only for optional cross-scene pixel diagnostics;CPU water remains compared. Pixel differences,if any,are reported separately and never silently treated as exact equality. Ordered nonisolated fills are not timing gains;not full-world traversal/art/performance acceptance."},"  "));quit(0 if failures.is_empty() else 1)
