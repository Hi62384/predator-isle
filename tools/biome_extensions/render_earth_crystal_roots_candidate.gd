extends "res://tools/biome_extensions/render_ground_union_worker_domains.gd"
const BASELINE="res://tools/biome_extensions/artifacts/revisions/experiment_render_all_bdc262d54413/evidence/tools/biome_extensions/artifacts/render_all.json"
func root_cut()->Dictionary:
	var result:Dictionary={}
	for key:Vector3i in terrain._active_chunks:
		var node:MeshInstance3D=terrain._active_chunks[key];var data:Dictionary=node.mesh.get_meta("collision_data").duplicate();var faces:PackedVector3Array=data.structure_faces;data.erase("structure_faces")
		var record:Dictionary={"terrain":digest(node.mesh),"non_structure_collision":var_to_bytes(data).hex_encode().sha256_text(),"structures":"none","structure_collision":faces.to_byte_array().hex_encode().sha256_text(),"structure_xz_colors":"none"}
		if node.mesh.has_meta("extension_structures"):
			var mesh:ArrayMesh=node.mesh.get_meta("extension_structures");record.structures=digest(mesh);var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);var expected:=PackedVector3Array()
			for surface in range(mesh.get_surface_count()):
				var arrays:Array=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var xz:=PackedVector2Array()
				for v:Vector3 in vertices:xz.append(Vector2(v.x,v.z))
				h.update(var_to_bytes([xz,arrays[Mesh.ARRAY_COLOR]]));expected.append_array(vertices)
			record.structure_xz_colors=h.finish().hex_encode();verify(faces==expected,"Actual changed structure collision matches committed GPU triangles")
		for name:String in ["swamp_water_mesh","terrain_features"]:record[name]=digest(node.mesh.get_meta(name)) if node.mesh.has_meta(name) else "none"
		result[str(key)]=record
	return result
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var baseline=JSON.parse_string(FileAccess.get_file_as_string(BASELINE));hashes[BASELINE]=FileAccess.get_sha256(BASELINE)
	for path:String in baseline.source_sha256:assert(FileAccess.get_sha256(path)==baseline.source_sha256[path]);hashes[path]=baseline.source_sha256[path]
	for path:String in ["res://tools/biome_extensions/render_earth_crystal_roots_candidate.gd","res://tools/biome_extensions/earth_crystal_worker_fixture.gd","res://tools/biome_extensions/grounded_earth_crystal_candidate.gd","res://tools/biome_extensions/ground_union_worker_fixture.gd","res://tools/biome_extensions/render_ground_union_worker_domains.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var phases:Array=[];var views:Array=[]
	for family:String in ["crystal_wastes","insect_colony"]:
		var originals:Dictionary={};var original_cut:Dictionary={}
		for phase in range(3):
			scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000;terrain=scene.get_node("Terrain")
			preload("res://tools/biome_extensions/earth_crystal_worker_fixture.gd").configure(terrain,phase==1)
			terrain.extension_preview=family;terrain.target=camera;var focus:=Vector3.ZERO
			for view:Dictionary in baseline.captures:
				if view.biome==family:focus=vector(view.focus);break
			terrain.extension_preview_position=Vector2(focus.x,focus.z);root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
			var cut_before:Dictionary={};var changed:int=0
			for view:Dictionary in baseline.captures:
				if view.biome!=family or view.view=="regions":continue
				terrain.request_teleport(vector(view.camera));assert(await settle());camera.look_at(focus);terrain.set_debug_view(0)
				var current:Dictionary=root_cut()
				if phase==0:original_cut[view.view]=current
				else:
					var original:Dictionary=original_cut[view.view];verify(current.keys()==original.keys(),"Same complete production partition")
					if phase==2:verify(current==original,"Complete original cut restored")
					for key:String in current:
						if not original.has(key):continue
						for name:String in current[key]:
							if name not in ["structures","structure_collision"]:verify(current[key][name]==original[key][name],"Unchanged "+name)
						if current[key].structures!=original[key].structures:changed+=1
				for idle in range(24):await process_frame
				await RenderingServer.frame_post_draw;var picture:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/earth_crystal_roots_%s_%d_%s.png"%[family,phase,view.view];verify(picture.save_png(path)==OK,"Saved whole native image");captures[path]=FileAccess.get_sha256(path)
				var changed_bytes:int=0
				if phase==0:originals[view.view]=picture
				else:changed_bytes=different(originals[view.view],picture)
				views.append({"family":family,"phase":phase,"view":view.view,"focus":view.focus,"camera":view.camera,"changed_image_bytes_from_original":changed_bytes})
			if phase==1:verify(changed>0,"Actual workers changed geological roots")
			phases.append({"family":family,"phase":phase,"changed_roots_sum_across_views":changed,"maximum_lod":terrain.maximum_lod});print("EARTH_CRYSTAL_ROOT_NATIVE ",family," phase=",phase," changed_roots=",changed);scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:verify(FileAccess.get_sha256(path)==hashes[path],"Stable candidate native source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_earth_crystal_roots_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"source_sha256":hashes,"capture_sha256":captures,"views":views,"phases":phases,"production_registration":false,"scope":"PRIVATE actual original four-worker controller fullLOD6 cuts at two frozen primary Crystal/Insect fixtures,original/candidate/original at unchanged ground/medium/aerial cameras. Constructor substitution only;actual terrain builder/class,collision preparation/material/water paths unchanged. All terrain/water/features/nonstructure collision and complete XZ/color payloads exact;original complete cuts restored;actual GPU roots equal worker collider vertices.18images;cross-cold-scene image differences reported,not exact image proof. Numeric candidate tests separately cover three seeds. Not a complete-settings,continuous-edge,performance or cave certificate."},"  "));quit(0 if failures.is_empty() else 1)
