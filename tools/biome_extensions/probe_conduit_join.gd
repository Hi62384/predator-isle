extends "res://tools/biome_extensions/render_all.gd"
var probe_pixels:Array[Vector2]=[Vector2(1100,650),Vector2(1100,695),Vector2(850,600),Vector2(600,650)]
var output_basename:String="probe_conduit_join"
var capture_label:String="join_ray_probe"
var additional_guards:Array[String]=[]
func mesh_hit(node:MeshInstance3D,from:Vector3,direction:Vector3,limit:float,kind:String)->Dictionary:
	assert(node.global_basis.is_equal_approx(Basis.IDENTITY));var local_from:Vector3=from-node.global_position
	if node.get_aabb().intersects_ray(local_from,direction)==null:return {}
	var best:Dictionary={};var nearest:float=limit
	for surface in range(node.mesh.get_surface_count()):
		var arrays:Array=node.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array();var count:int=indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0,count,3):
			var ia:int=indices[i] if not indices.is_empty() else i;var ib:int=indices[i+1] if not indices.is_empty() else i+1;var ic:int=indices[i+2] if not indices.is_empty() else i+2
			var a:Vector3=vertices[ia];var ab:Vector3=vertices[ib]-a;var ac:Vector3=vertices[ic]-a;var cross_value:Vector3=direction.cross(ac);var determinant:float=ab.dot(cross_value)
			if determinant>=-.00000001:continue # actual clockwise rendered front face
			var offset:Vector3=local_from-a;var u:float=offset.dot(cross_value)/determinant
			if u<0 or u>1:continue
			var q:Vector3=offset.cross(ab);var v:float=direction.dot(q)/determinant
			if v<0 or u+v>1:continue
			var distance:float=ac.dot(q)/determinant
			if distance<0 or distance>=nearest:continue
			nearest=distance;var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			var normal:Vector3=(normals[ia]*(1-u-v)+normals[ib]*u+normals[ic]*v).normalized();var projected_uv:Vector2=uv[ia]*(1-u-v)+uv[ib]*u+uv[ic]*v;var color:Color=colors[ia]*(1-u-v)+colors[ib]*u+colors[ic]*v
			best={"kind":kind,"distance_m":distance,"position":from+direction*distance,"normal":normal,"geometric_normal":ac.cross(ab).normalized(),"uv":projected_uv,"color":color,"triangle":i/3,"surface":surface,"triangle_local_positions":[vertices[ia],vertices[ib],vertices[ic]],"triangle_normals":[normals[ia],normals[ib],normals[ic]],"triangle_uvs":[uv[ia],uv[ib],uv[ic]],"triangle_colors":[colors[ia],colors[ib],colors[ic]],"owner_origin":node.global_position}
	return best
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/probe_conduit_join.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	for path:String in additional_guards:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed);var site:Dictionary=admission.cases[0];var p:=Vector2(site.position[0],site.position[1])
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
	var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y)
	await capture(capture_label,"albedo_ground",focus,Vector3(-90,4-site.junction_height*.4,-130),3)
	var probes:Array=[];var failures:Array=[]
	for pixel:Vector2 in probe_pixels:
		# Image.get_pixel addresses a texel, whose raster centre is x+.5/y+.5.
		# An integer camera ray samples its corner and can miss a subpixel join.
		var raster_center:Vector2=pixel+Vector2(.5,.5)
		var from:Vector3=camera.project_ray_origin(raster_center);var direction:Vector3=camera.project_ray_normal(raster_center);var nearest:Dictionary={};var best_terrain:Dictionary={};var best_shell:Dictionary={}
		for node:MeshInstance3D in terrain._active_chunks.values():
			var t:Dictionary=mesh_hit(node,from,direction,best_terrain.get("distance_m",1000.0),"terrain")
			if not t.is_empty():best_terrain=t
			var shell:MeshInstance3D=node.get_node_or_null("BiomeStructures")
			if shell!=null and shell.mesh!=null:
				t=mesh_hit(shell,from,direction,best_shell.get("distance_m",1000.0),"shell")
				if not t.is_empty():best_shell=t
		if not best_terrain.is_empty():nearest=best_terrain
		if not best_shell.is_empty() and best_shell.distance_m<nearest.get("distance_m",1000.0):nearest=best_shell
		assert(not nearest.is_empty(),"Actual rendered front triangle at every selected ground pixel")
		var point:Vector3=nearest.position;var field=terrain._sampler._extras[7];field.sample(point.x,point.z)
		var normal:=Vector3(terrain.get_height_at(point-Vector3(.25,0,0))-terrain.get_height_at(point+Vector3(.25,0,0)),.5,terrain.get_height_at(point-Vector3(0,0,.25))-terrain.get_height_at(point+Vector3(0,0,.25))).normalized()
		var query:=PhysicsRayQueryParameters3D.create(from,from+direction*1000);var hit:Dictionary=camera.get_world_3d().direct_space_state.intersect_ray(query)
		var native_error:float=hit.position.distance_to(point) if not hit.is_empty() else INF
		if native_error>.03:failures.append({"pixel":pixel,"native_mesh_error_m":native_error})
		probes.append({"pixel":pixel,"visible":nearest,"terrain":best_terrain,"shell":best_shell,"terrain_shell_ray_gap_m":absf(best_terrain.distance_m-best_shell.distance_m) if not best_terrain.is_empty() and not best_shell.is_empty() else INF,"native_mesh_error_m":native_error,"canonical_height":terrain.get_height_at(point),"canonical_normal":normal,"canonical_region":field.state[3]*5,"canonical_feature":field.state[4],"native_shape_index":hit.get("shape",-1)})
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Join-ray source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+output_basename+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"actual_render":true,"source_sha256":hashes,"probes":probes,"captures":records,"scope":"Four selected pixels of one actual production albedo view, independent closest clockwise triangle intersections of committed terrain/shell geometry and native Jolt ray agreement. Records actual interpolated UV/color/normals versus canonical controls/normal; diagnostic only, not a join fix, artistic or whole-world certificate."},"  "))
	print("JOIN_RAY_PROBE failures=",failures," probes=",probes.size());scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
