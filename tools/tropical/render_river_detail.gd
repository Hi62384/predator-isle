extends "res://tools/biome_extensions/render_all.gd"
var images:Dictionary={}
var phases:Array=[]
func streaming_target(p:Vector2,key:Vector3i)->Vector2:
	# The production 2:1 balancing pass can split a nominal LOD3 tile further.
	# Select a fixed spectator target using that SAME planner, without moving
	# the frozen river, altering split ratios, or reducing production budgets.
	for distance:float in [5000,5500,6000,6500,7000,7500,8000]:
		var planner=preload("res://scripts/terrain_partition.gd").new();planner.maximum_level=5;planner.split_ratio=.95;planner.merge_ratio=1.3
		var point:Vector2=p+Vector2(distance,0);var cut:Dictionary=planner.select(point,{})
		if cut.has(key) and planner.select(point,cut).has(key):return point
	assert(false,"No bounded spectator target retains the frozen river at LOD3");return Vector2.INF
func mesh_digest(mesh:ArrayMesh)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return hash.finish().hex_encode()
func visible_cut()->Dictionary:
	var cut:Dictionary={}
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var water:Node3D=node.get_node_or_null("SwampWater")
		cut[str(key)]={"resolution":node.get_meta("resolution"),"vertices":node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(),"terrain":mesh_digest(node.mesh),"water":mesh_digest(water.mesh) if water!=null and water.mesh!=null else "none"}
	return cut
func shot(seed_id:int,phase:int,kind:String,focus:Vector3,offset:Vector3)->void:
	camera.position=focus+offset;camera.look_at(focus)
	for frame in range(20):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/tropical/artifacts/river_detail_%d_%d_%s.png" % [seed_id,phase,kind]
	assert(image.save_png(path)==OK);images[path]=FileAccess.get_sha256(path)
	records.append({"seed":seed_id,"phase":phase,"view":kind,"camera":str(camera.position),"focus":str(focus),"width":image.get_width(),"height":image.get_height(),"capture":path,"sha256":images[path]})
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var numeric=JSON.parse_string(FileAccess.get_file_as_string("res://tools/tropical/artifacts/check_river_detail.json"));assert(numeric.passed)
	for path:String in numeric.source_sha256:assert(FileAccess.get_sha256(path)==numeric.source_sha256[path]);hashes[path]=numeric.source_sha256[path]
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);hashes[path]=regression.source_sha256[relative]
	for path:String in ["res://data/surface_regression_20261018.json","res://tools/tropical/artifacts/check_river_detail.json","res://tools/tropical/render_river_detail.gd","res://tools/biome_extensions/render_all.gd"]:hashes[path]=FileAccess.get_sha256(path)
	for seed_id:int in [73921,17,92881]:
		var site:Dictionary={}
		for item:Dictionary in numeric.cases:
			if int(item.seed)==seed_id:site=item;break
		assert(not site.is_empty())
		# JSON's Vector2 values are strings; the actual frozen cell/lane and
		# carrier are reconstructed without inventing a new fixture coordinate.
		var cell_text:String=site.cell;var components:PackedStringArray=cell_text.trim_prefix("(").trim_suffix(")").split(",")
		var cell:=Vector2i(int(components[0]),int(components[1]));var x:float=cell.x*2048
		var b=preload("res://tools/tropical/check_river_detail.gd").create(seed_id)
		var p:=Vector2(x,b._tropical._carrier(x,int(site.lane)).x)
		var focus:=Vector3(p.x,b._get_height(p.x,p.y)+4,p.y)
		var frozen_key:=Vector3i(cell.x,cell.y,3);var stream_point:Vector2=streaming_target(p,frozen_key)
		var reference:Dictionary={}
		for phase in range(3):
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000
			terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			terrain.settings.tropical.river_detail_metres=32 if phase==1 else 0
			# A preview intentionally relocates its target on startup. Use the
			# same explicit pure-world settings instead, retaining this fixture's
			# separate fixed streaming target and unchanged physical river site.
			terrain.tropical_preview=false;terrain.extension_preview="";terrain.maximum_lod=5
			for property:Dictionary in terrain.get_property_list():
				if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
			var target:=Marker3D.new();target.name="RiverDetailStreamingTarget";target.position=Vector3(stream_point.x,focus.y+150,stream_point.y);scene.add_child(target);terrain.target=target
			camera.position=focus+Vector3(-300,260,-450)
			var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
			var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0
			var key:=Vector3i(cell.x,cell.y,3)
			if not terrain._active_chunks.has(key):
				var covering:Array=[]
				for leaf:Vector3i in terrain._active_chunks:
					if terrain._partition.bounds(leaf).has_point(p+Vector2.ONE):covering.append(leaf)
				print("RIVER_FIXTURE_DIAGNOSTIC seed=",seed_id," frozen=",key," target_expected=",stream_point," actual_target=",terrain.target.global_position," actual_plan=",terrain._last_plan_position," wanted=",terrain._wanted.has(key)," covering=",covering," ratios=",[terrain._partition.split_ratio,terrain._partition.merge_ratio])
			assert(terrain._active_chunks.has(key),"Frozen river fixture must really remain at LOD3 under the spectator camera")
			var node:MeshInstance3D=terrain._active_chunks[key];var expected:int=int(site.new_resolution if phase==1 else site.old_resolution)
			assert(int(node.get_meta("resolution"))==expected,"Actual committed worker density matches policy")
			var arrays:Array=node.mesh.surface_get_arrays(0);var probes:int=0
			for i in range(0,(expected+1)*(expected+1),maxi(1,expected/4)):
				var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var world:Vector3=node.position+vertex
				assert(absf(terrain.get_height_at(world)-world.y)<.001,"Native root vertex remains canonical")
				probes+=1
			var cut:Dictionary=visible_cut()
			var vertex_total:int=0
			for entry:Dictionary in cut.values():vertex_total+=int(entry.vertices)
			var detailed_lod4:int=0
			for leaf:Vector3i in terrain._active_chunks:
				if leaf.z==4 and int(terrain._active_chunks[leaf].get_meta("resolution"))==64:detailed_lod4+=1
			assert(detailed_lod4>0 if phase==1 else detailed_lod4==0,"Actual LOD4 foreground refinement is present only in the enabled phase")
			if phase==0:reference=cut
			elif phase==2:assert(reference==cut,"Disabled reference-return must reproduce complete terrain and water arrays for every committed leaf")
			phases.append({"seed":seed_id,"phase":phase,"river_key":str(key),"streaming_target":str(stream_point),"actual_resolution":expected,"refined_lod4_leaves":detailed_lod4,"leaves":cut.size(),"total_terrain_vertices":vertex_total,"canonical_worker_probes":probes,"initial_fill_seconds":elapsed,"reference_return_exact":phase==2,"cut":cut})
			await shot(seed_id,phase,"bank",focus,Vector3(-300,260,-450));await shot(seed_id,phase,"overview",focus,Vector3(-900,750,-1300))
			print("TROPICAL_RIVER_NATIVE ",seed_id," phase=",phase," actualLOD3=",expected," fill=",elapsed)
			scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	var report:Dictionary={"passed":true,"failures":[],"source_sha256":hashes,"capture_sha256":images,"views":records,"phases":phases,"production_registration":true,"scope":"Three seeded actual production cuts. A fixed spectator target is selected5–8km from each unchanged river using the original balanced production planner, retainingLOD3. Earlier fixture attempts were rejected when Tropical preview startup relocated that target; explicit equivalent pure-world settings now avoid preview relocation. Original/refined/original settings,18 native images, actual worker densities/canonical probes and complete per-leaf terrain/water array reference returns. Unchanged canonical lighting and animated water; images are not byte-equal because geometry/time differ. Ordered non-isolated timings are not a performance gain. Not distant/tributary/art completion."}
	FileAccess.open("res://tools/tropical/artifacts/render_river_detail.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
