extends "res://tools/biome_extensions/render_all.gd"
var images:Dictionary={}
var phases:Array=[]
var failures:Array=[]
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func mesh_digest(mesh:ArrayMesh)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return hash.finish().hex_encode()
func cut_digest()->Dictionary:
	var cut:Dictionary={}
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var water:Node3D=node.get_node_or_null("SwampWater")
		cut[str(key)]={"resolution":node.get_meta("resolution"),"terrain":mesh_digest(node.mesh),"water":mesh_digest(water.mesh) if water!=null and water.mesh!=null else "none"}
	return cut
func shot(seed_id:int,phase:int,kind:String,focus:Vector3,offset:Vector3)->void:
	camera.position=focus+offset;camera.look_at(focus)
	verify(camera.position.y>terrain.get_height_at(camera.position)+3,"Frozen spectator view is above canonical terrain")
	for frame in range(24):await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image();var path:String="res://tools/badlands/artifacts/fan_apron_%d_%d_%s.png" % [seed_id,phase,kind]
	verify(image.save_png(path)==OK,"Native capture saved");images[path]=FileAccess.get_sha256(path)
	records.append({"seed":seed_id,"phase":phase,"view":kind,"camera":str(camera.position),"focus":str(focus),"width":image.get_width(),"height":image.get_height(),"capture":path,"sha256":images[path]})
func run()->void:
	verify(DisplayServer.get_name()!="headless","Native renderer required")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var numeric_path:String="res://tools/badlands/artifacts/check_fan_geometry.json"
	var numeric=JSON.parse_string(FileAccess.get_file_as_string(numeric_path));assert(numeric.passed)
	for path:String in numeric.source_sha256:verify(FileAccess.get_sha256(path)==numeric.source_sha256[path],"Current numeric source "+path);hashes[path]=numeric.source_sha256[path]
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed and regression.test_count==31)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");verify(FileAccess.get_sha256(path)==regression.source_sha256[relative],"Current shared source "+path);hashes[path]=regression.source_sha256[relative]
	for path:String in [numeric_path,"res://data/surface_regression_20261018.json","res://tools/badlands/render_fan_aprons.gd","res://tools/biome_extensions/render_all.gd"]:hashes[path]=FileAccess.get_sha256(path)
	if not failures.is_empty():quit(1);return
	for item:Dictionary in numeric.cases:
		var seed_id:int=item.seed;var site:Dictionary=item.floor_cases[0]
		var b=preload("res://tools/badlands/check_fan_geometry.gd").builder(seed_id,0)
		var tree:Dictionary=b._badlands._tree(int(site.index),int(site.lane),1)
		var frame:PackedFloat64Array=preload("res://scripts/badlands_fan_geometry.gd").frame(tree)
		var origin:=Vector2(frame[0],frame[1]);var axis:=Vector2(frame[2],frame[3]);var normal:=Vector2(-axis.y,axis.x);var reach:float=minf(425,maxf(32,frame[4]*.85))
		var p:Vector2=origin+axis*reach*.4;var focus:=Vector3(p.x,b._get_height(p.x,p.y)+2,p.y)
		var reference:Dictionary={}
		for phase in range(3):
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000
			terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.settings=b.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			terrain.settings.badlands.fan_shape_strength=1 if phase==1 else 0
			terrain.badlands_preview=false;terrain.tropical_preview=false;terrain.extension_preview="";terrain.maximum_lod=5
			for property:Dictionary in terrain.get_property_list():
				if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
			var target:=Marker3D.new();target.name="FanApronFixedTarget";target.position=focus;scene.add_child(target);terrain.target=target
			camera.position=focus+Vector3(normal.x*380-axis.x*550,500,normal.y*380-axis.y*550)
			var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide()
			verify(await settle(),"Committed native cut");var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0
			verify(Vector2(terrain.target.global_position.x,terrain.target.global_position.z).distance_to(p)<.01,"No preview target relocation")
			var probes:int=0;var vertex_total:int=0
			for key:Vector3i in terrain._active_chunks:
				var node:MeshInstance3D=terrain._active_chunks[key];var resolution:int=node.get_meta("resolution");var arrays:Array=node.mesh.surface_get_arrays(0);vertex_total+=arrays[Mesh.ARRAY_VERTEX].size()
				if key.z>1:continue
				for i in range(0,(resolution+1)*(resolution+1),maxi(1,resolution*8)):
					var world:Vector3=node.position+arrays[Mesh.ARRAY_VERTEX][i]
					verify(absf(terrain.get_height_at(world)-world.y)<.001,"Actual native worker vertex remains canonical");probes+=1
			var cut:Dictionary=cut_digest()
			if phase==0:reference=cut
			elif phase==2:verify(reference==cut,"Full original/reference-return terrain and water arrays")
			phases.append({"seed":seed_id,"phase":phase,"index":site.index,"lane":site.lane,"root":site.root,"fixed_streaming_target":str(focus),"leaves":cut.size(),"vertices":vertex_total,"worker_probes":probes,"initial_fill_seconds":elapsed,"reference_return_exact":phase==2,"cut":cut})
			await shot(seed_id,phase,"apron",focus,Vector3(normal.x*380-axis.x*550,500,normal.y*380-axis.y*550))
			await shot(seed_id,phase,"throat",focus,Vector3(normal.x*280+axis.x*220,320,normal.y*280+axis.y*220))
			print("BADLANDS_FAN_NATIVE ",seed_id," phase=",phase," fill=",elapsed," leaves=",cut.size())
			scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Source unchanged throughout native review "+path)
	FileAccess.open("res://tools/badlands/artifacts/render_fan_aprons.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":images,"views":records,"phases":phases,"production_registration":true,"scope":"Three frozen on-land fan-province roots, original/shaped/original, two identical spectator views each, actual committed worker vertex probes and complete terrain/water array reference returns. Explicit pure Badlands settings, no preview relocation. Bounded LOD5/18km native fixture; separate existing full-LOD6 streamed wash and three static apron collision returns have different scopes. Lighting unchanged. Animated water/time and intentional geometry differences mean images are not byte-equality evidence. Ordered non-isolated fill measurements are not performance gains or whole-biome art acceptance."},"  "))
	quit(0 if failures.is_empty() else 1)
