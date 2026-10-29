extends "res://tools/biome_extensions/render_all.gd"
func actual_ground_height(p:Vector3,cache:Dictionary)->float:
	for level in range(terrain.maximum_lod+1):
		var span:float=terrain.chunk_size*float(1<<level);var key:=Vector3i(floori(p.x/span),floori(p.z/span),level)
		if not terrain._active_chunks.has(key):continue
		var node:MeshInstance3D=terrain._active_chunks[key];var resolution:int=node.get_meta("resolution")
		if not cache.has(key):cache[key]=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var vertices:PackedVector3Array=cache[key];var local:Vector3=node.to_local(p)
		var gx:float=clampf(local.x/span*resolution,0,resolution);var gz:float=clampf(local.z/span*resolution,0,resolution)
		var x:int=mini(floori(gx),resolution-1);var z:int=mini(floori(gz),resolution-1);var q:=Vector3(local.x,0,local.z)
		var a:Vector3=vertices[z*(resolution+1)+x];var b:Vector3=vertices[z*(resolution+1)+x+1];var c:Vector3=vertices[(z+1)*(resolution+1)+x];var d:Vector3=vertices[(z+1)*(resolution+1)+x+1]
		# Independent plane equation on the actual committed triangle.
		var plane:=Plane(a,b,c) if gx-x+gz-z<=1 else Plane(d,c,b)
		return (plane.d-plane.normal.x*q.x-plane.normal.z*q.z)/plane.normal.y+node.global_position.y
	return NAN
func plate_face(p:Vector2,width:float,habit:int)->Dictionary:
	var best:Dictionary={};var highest:float=-INF;var count:int=0;var feet:Dictionary={};var cache:Dictionary={};var max_clearance:float=-INF
	for node:MeshInstance3D in terrain._active_chunks.values():
		var shell:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if shell==null or shell.mesh==null:continue
		for surface in range(shell.mesh.get_surface_count()):
			var arrays:Array=shell.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for i in range(0,vertices.size(),3):
				# Native ArrayMesh packs vertex colour to UNORM8. Allow one code
				# value; raw worker-array tests still assert the exact source tint.
				if absf(colors[i].r-(.74 if habit==5 else .25))>1.0/255 or uvs[i]!=Vector2(habit,1):continue
				var center:Vector3=shell.to_global((vertices[i]+vertices[i+1]+vertices[i+2])/3)
				if Vector2(center.x-p.x,center.z-p.y).length()>width*1.8:continue
				count+=3
				for j in range(3):
					if colors[i+j].a>.1:continue
					var foot:Vector3=shell.to_global(vertices[i+j])
					if feet.has(foot):continue
					feet[foot]=true;var ground:float=actual_ground_height(foot,cache);assert(is_finite(ground),"Committed ground below plate footing")
					max_clearance=maxf(max_clearance,foot.y-ground)
				var normal:Vector3=(shell.global_basis*normals[i]).normalized()
				if normal.y>.2 and normal.y<.85 and center.y>highest and center.y>terrain.get_height_at(center)+12:
					highest=center.y;best={"center":center,"normal":normal}
	best["production_tagged_vertices"]=count;best["unique_footings"]=feet.size();best["maximum_footing_clearance_m"]=max_clearance;return best
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	assert(DisplayServer.get_name()!="headless")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for path:String in ["res://scenes/main.tscn","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://tools/biome_extensions/artifacts/check_carapace_admission.json","res://tools/biome_extensions/render_carapace.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_carapace_admission.json"));assert(admission.passed and admission.cases.size()==6)
	for item:Dictionary in admission.cases:
		var p:=Vector2(item.position[0],item.position[1]);var key:String="alien_carapace_"+str(int(item.seed))+"_"+str(int(item.habit))
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=item.seed;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
		var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
		var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+item.height*.4,p.y)
		await capture(key,"medium",focus,Vector3(-600,260,-800))
		var face:Dictionary=plate_face(p,item.width,item.habit)
		print("CARAPACE_STREAMED_FACE ",item.seed," ",item.habit," ",face)
		assert(face.production_tagged_vertices==18000 and face.has("center"),"One complete real streamed plate complex, no test-side mesh")
		assert(face.unique_footings==120 and face.maximum_footing_clearance_m<-.05,"All plate perimeter feet below actual committed ground triangles")
		records[-1]["production_tagged_vertices"]=face.production_tagged_vertices
		records[-1]["unique_footings"]=face.unique_footings;records[-1]["maximum_footing_clearance_m"]=face.maximum_footing_clearance_m
		var toward_sun:Vector3=scene.get_node("Sun").global_basis.z.normalized();var horizontal:=Vector2(toward_sun.x,toward_sun.z).normalized()*480
		await capture(key,"sunlit",focus,Vector3(horizontal.x,200,horizontal.y))
		await capture(key,"ground",focus,Vector3(-210,4-item.height*.4,-280))
		await capture(key,"close",face.center,face.normal*12)
		for record:Dictionary in records.slice(records.size()-4):record["seed"]=item.seed;record["habit"]=item.habit
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Carapace render source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_carapace.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"captures":records,"source_sha256":hashes,"scope":"Twenty-four production-streamed medium/sunlit/ground/close views, three seeds and hardened/dormant regional habits, default admission and cavity guards, unchanged lighting and 50km far plane. Native source-tag count proves actual complete worker output. Warm capture timings are not an isolated performance comparison or artistic completion certificate."},"  "))
	print("CARAPACE_RENDER_DONE ",records.size());quit()
