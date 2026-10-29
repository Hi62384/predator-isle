extends "res://tools/biome_extensions/render_all.gd"
const Fixture=preload("res://tools/biome_extensions/ground_union_worker_fixture.gd")
const INPUT="res://tools/biome_extensions/artifacts/render_tissue_variation_registered.json"
var failures:Array=[]
var captures:Dictionary={}
func verify(ok:bool,label:String)->void:
	if not ok:failures.append(label);print("FAILED_GROUND_UNION_DOMAINS ",label)
func vector(text:String)->Vector3:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func digest(mesh:ArrayMesh)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):context.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return context.finish().hex_encode()
func stable_structure(mesh:ArrayMesh)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	for surface in range(mesh.get_surface_count()):
		var arrays:Array=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var xz:=PackedVector2Array();xz.resize(vertices.size())
		for index in range(vertices.size()):xz[index]=Vector2(vertices[index].x,vertices[index].z)
		context.update(var_to_bytes([xz,arrays[Mesh.ARRAY_COLOR],arrays[Mesh.ARRAY_TEX_UV],arrays[Mesh.ARRAY_INDEX]]))
	return context.finish().hex_encode()
func map_digest(mesh:ArrayMesh)->String:
	if not mesh.has_meta("alien_tissue_flow"):return "none"
	var texture:ImageTexture=mesh.get_meta("alien_tissue_flow");var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(texture.get_image().get_data());context.update(var_to_bytes([mesh.get_meta("alien_tissue_flow_span",Vector2.ZERO),mesh.get_meta("alien_tissue_flow_offset",Vector2.ZERO)]));return context.finish().hex_encode()
func cut()->Dictionary:
	var result:Dictionary={}
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var collision:Dictionary=node.mesh.get_meta("collision_data").duplicate();var structure_faces:PackedVector3Array=collision.structure_faces;collision.erase("structure_faces")
		var record:Dictionary={"resolution":node.get_meta("resolution"),"terrain":digest(node.mesh),"non_structure_collision":var_to_bytes(collision).hex_encode().sha256_text(),"structure_collision":structure_faces.to_byte_array().hex_encode().sha256_text(),"terrain_flow":map_digest(node.mesh),"structures":"none","stable_structure":"none","structure_flow":"none"}
		for field:String in ["swamp_water_mesh","terrain_features"]:record[field]=digest(node.mesh.get_meta(field)) if node.mesh.has_meta(field) else "none"
		if node.mesh.has_meta("extension_structures"):
			var mesh:ArrayMesh=node.mesh.get_meta("extension_structures");record.structures=digest(mesh);record.stable_structure=stable_structure(mesh);record.structure_flow=map_digest(mesh);var faces:=PackedVector3Array()
			for surface in range(mesh.get_surface_count()):faces.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			verify(faces==structure_faces,"Actual GPU root positions equal complete worker-prepared collision faces")
		result[str(key)]=record
	return result
func different(a:Image,b:Image)->int:
	var first:PackedByteArray=a.get_data();var second:PackedByteArray=b.get_data();verify(first.size()==second.size(),"Same native raster size");var count:int=0
	for index in range(first.size()):
		if first[index]!=second[index]:count+=1
	return count
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var input=JSON.parse_string(FileAccess.get_file_as_string(INPUT));assert(input.passed)
	for path:String in input.source_sha256:verify(FileAccess.get_sha256(path)==input.source_sha256[path],"Fresh original native fixture source "+path);hashes[path]=input.source_sha256[path]
	for path:String in [INPUT,"res://tools/biome_extensions/render_ground_union_worker_domains.gd","res://tools/biome_extensions/ground_union_worker_fixture.gd","res://tools/biome_extensions/conduit_ground_union_candidate.gd","res://tools/biome_extensions/conduit_shoulder_candidate.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/biome_extension_structures.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var phases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var views:Array=[]
		for view:Dictionary in input.views:
			if view.seed==seed_id:views.append(view)
		assert(views.size()==3);var focus:Vector3=vector(views[0].focus);var original_cut:Dictionary={};var original_images:Dictionary={}
		for phase in range(3):
			var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(seed_id,true);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;camera.position=vector(views[0].camera);terrain=scene.get_node("Terrain");Fixture.configure(terrain,phase==1);terrain.world_seed=seed_id;terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.emission_strength=0;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
			for property:Dictionary in terrain.get_property_list():
				if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
			var marker:=Marker3D.new();marker.position=focus;scene.add_child(marker);terrain.target=marker;var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();verify(await settle(),"Actual private original/candidate worker cut committed");var fill:float=(Time.get_ticks_usec()-started)/1000000.0;var current:Dictionary=cut();var changed_roots:int=0
			if phase==0:original_cut=current
			elif phase==2:verify(current==original_cut,"Complete original cut returns byte-exact,including complete body/collision geometry")
			else:
				verify(current.size()==original_cut.size(),"Same actual partition size")
				for key:String in original_cut:
					verify(current.has(key),"Same original active key "+key)
					if not current.has(key):continue
					for field:String in original_cut[key]:
						if field not in ["structures","structure_collision"]:verify(current[key][field]==original_cut[key][field],"Only body Y/normals/corresponding collision change,not "+field)
					if current[key].structures!=original_cut[key].structures:changed_roots+=1
				verify(changed_roots>0,"Actual candidate workers change complete roots,not only private display meshes")
			if terrain._water!=null:terrain._water.hide()
			for node:MeshInstance3D in terrain._active_chunks.values():
				var water:Node3D=node.get_node_or_null("SwampWater")
				if water!=null:water.hide()
			for view:Dictionary in views:
				camera.position=vector(view.camera);camera.look_at(focus)
				for idle in range(24):await process_frame
				await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/ground_union_worker_%d_%d_%s.png"%[seed_id,phase,view.view];verify(image.save_png(path)==OK,"Full actual private worker image saved");captures[path]=FileAccess.get_sha256(path);var changed_bytes:int=0
				if phase==0:original_images[view.view]=image
				else:changed_bytes=different(original_images[view.view],image)
				records.append({"seed":seed_id,"phase":phase,"view":view.view,"focus":str(focus),"camera":str(camera.position),"different_bytes_from_original_cold_scene":changed_bytes,"capture":path})
			phases.append({"seed":seed_id,"phase":phase,"leaves":current.size(),"changed_roots":changed_roots,"initial_fill_seconds":fill,"cut":current});print("GROUND_UNION_NATIVE_DOMAINS ",seed_id," phase=",phase," changed_roots=",changed_roots);scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable private actual worker render source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_ground_union_worker_domains.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":records,"phases":phases,"scope":"PRIVATE actual four-worker/controller original/candidate/original at ALL three original frozen pure-Alien ground/near/context fixtures,nine full cuts/27 images. Only one constructor in inherited original dispatch changes;actual builder/class-sensitive bounds,batching,collision,materials and configured tissue variation remain production. Complete terrain/water/features/partition/map bytes/body XZ/count/semantic controls unchanged;new body Y/normals and actual GPU-matching collision faces change. Original complete cut returns exact. Cross-cold-scene pixel differences reported,NOT falsely certified exact;strict same-scene original-image returns are in the separate12-image single-root trial. Emission0/waterhidden only for comparable images,lighting unchanged. BoundedLOD4/18km,not full-world art/streaming/performance/cave acceptance. Ordered fills are costs,not isolated benchmarks. No production edits."},"  "));quit(0 if failures.is_empty() else 1)
