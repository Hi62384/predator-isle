extends "res://tools/biome_extensions/render_all.gd"
func normal_frame(mode:int)->Image:
	terrain.set_debug_view(mode)
	for frame in range(12):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func pick_face(p:Vector2,plate_habit:int=-1,membrane_only:bool=false)->Dictionary:
	var best:Dictionary={};var distance:float=INF
	var membrane_axis:=Vector2.RIGHT;var membrane_width:float=0
	if membrane_only:
		var field=terrain._sampler._extras[7];var cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var edges:PackedVector2Array=field.network_edges(cell);membrane_axis=(edges[1]-p).normalized();membrane_width=terrain._settings_snapshot.alien_infected.hive_junction_width*terrain._settings_snapshot.alien_infected.feature_scale
	for node:MeshInstance3D in terrain._active_chunks.values():
		var shell:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if shell==null or shell.mesh==null:continue
		for surface in range(shell.mesh.get_surface_count()):
			var arrays:Array=shell.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for i in range(0,vertices.size(),3):
				if membrane_only:
					var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
					if absf(uvs[i].x-3)>.0001:continue
				if plate_habit>=0:
					var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
					if absf(colors[i].r-(.74 if plate_habit==5 else .25))>1.0/255 or uvs[i]!=Vector2(plate_habit,1):continue
				var center:Vector3=shell.to_global((vertices[i]+vertices[i+1]+vertices[i+2])/3)
				if membrane_only:
					var along:float=(Vector2(center.x,center.z)-p).dot(membrane_axis)
					if along<membrane_width*1.2 or along>membrane_width*3.1:continue
				var d:float=Vector2(center.x-p.x,center.z-p.y).length_squared()
				if d>=distance or d>1000000:continue
				var normal:Vector3=(shell.global_basis*normals[i]).normalized()
				if normal.y<-.2 or normal.y>.85:continue
				var height:float=center.y-terrain.get_height_at(center)
				if height<12:continue
				distance=d;best={"center":center,"normal":normal,"height_above_canonical":height}
	return best
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	assert(DisplayServer.get_name()!="headless")
	for source:String in ["res://scripts/alien_carapace_geometry.gd","res://scripts/biome_extension_settings.gd"]:hashes[source]=FileAccess.get_sha256(source)
	hashes["res://tools/biome_extensions/artifacts/check_carapace_admission.json"]=FileAccess.get_sha256("res://tools/biome_extensions/artifacts/check_carapace_admission.json")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://scripts/chunk_terrain.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://shaders/biome_structures.gdshader","res://shaders/crystal_transmission.gdshader","res://shaders/biological_sampling.gdshaderinc","res://tools/biome_extensions/check_structure_normal_controls.gd","res://tools/biome_extensions/artifacts/previews.json","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"));var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"))
	var plates=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_carapace_admission.json"));assert(plates.passed)
	var cases:Array=[];var failures:Array=[];var capture_hashes:Dictionary={}
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	for case_id in range(6):
		var family_id:int=[5,6,7,7,7,7][case_id];var plate_habit:int=2 if case_id==3 else (5 if case_id==4 else -1);var seed_id:int=73921;var membrane_only:bool=case_id==5
		var key:String=TerrainSettings.EXTENSION_KEYS[family_id];var item:Dictionary=manifest.families[key].primary
		var p:=Vector2(item.x,item.z)
		if family_id==7:p=Vector2(admission.cases[0].position[0],admission.cases[0].position[1])
		if plate_habit>=0:
			for plate:Dictionary in plates.cases:
				if int(plate.seed)==17 and int(plate.habit)==plate_habit:p=Vector2(plate.position[0],plate.position[1]);seed_id=17;break
		var label:String=key+("_hardened_plate" if plate_habit==2 else ("_dormant_plate" if plate_habit==5 else ("_membrane" if membrane_only else "")))
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.extension_preview=key;terrain.extension_preview_position=p;terrain.target=camera;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
		if membrane_only:assert(admission.cases[0].get("membrane_present",false),"Actual default-rarity membrane site required")
		var face:Dictionary=pick_face(p,plate_habit,membrane_only);assert(not face.is_empty(),"Actual above-ground supplemental face required "+label)
		terrain.request_teleport(face.center+face.normal*16+Vector3.UP*2);assert(await settle());camera.look_at(face.center)
		# Keep actual production shells visible. Hide only other render layers
		# in this private fixture; no test-side mesh or substitute shader.
		if terrain._water!=null:terrain._water.hide()
		for node:MeshInstance3D in terrain._active_chunks.values():
			node.layers=0;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for child_name:String in ["SwampWater","TerrainFeatures"]:
				var child:Node3D=node.get_node_or_null(child_name)
				if child!=null:child.hide()
		var material:ShaderMaterial=terrain._extension_materials[family_id-5];var strength:float=terrain._settings_snapshot.get(key).normal_strength
		if family_id>5:assert(is_equal_approx(float(material.get_shader_parameter("normal_strength")),strength),"Production setting bound to actual shell")
		var mapped_on:Image=await normal_frame(8)
		assert(int(material.get_shader_parameter("debug_view"))==8,"Global mapped-normal diagnostic propagated")
		if family_id>5:material.set_shader_parameter("normal_strength",0.0)
		var mapped_zero:Image=await normal_frame(8);var geometric:Image=await normal_frame(4)
		if family_id>5:material.set_shader_parameter("normal_strength",strength)
		var physical_off:Image=await normal_frame(7)
		if family_id>5:material.set_shader_parameter("normal_strength",0.0)
		var physical_zero:Image=await normal_frame(0)
		var max_geometric_error:float=0;var max_off_zero_error:float=0;var changed:int=0;var count:int=0
		for y in range(8,712,2):
			for x in range(8,1272,2):
				var a:Color=mapped_on.get_pixel(x,y);var b:Color=mapped_zero.get_pixel(x,y);var c:Color=geometric.get_pixel(x,y);var d:Color=physical_off.get_pixel(x,y);var e:Color=physical_zero.get_pixel(x,y)
				if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>1.0/255:changed+=1
				max_geometric_error=maxf(max_geometric_error,maxf(absf(b.r-c.r),maxf(absf(b.g-c.g),absf(b.b-c.b))))
				max_off_zero_error=maxf(max_off_zero_error,maxf(absf(d.r-e.r),maxf(absf(d.g-e.g),absf(d.b-e.b))));count+=1
		var passed:bool=max_geometric_error<=2.0/255 and max_off_zero_error<=2.0/255 and (changed>100 if family_id>5 else changed==0)
		if not passed:failures.append(label)
		cases.append({"biome":label,"passed":passed,"actual_structure_face":face,"camera":camera.global_position,"sampled_pixels":count,"mapped_normal_changed_pixels":changed,"maximum_zero_geometric_rgb_error":max_geometric_error,"maximum_physical_off_zero_rgb_error":max_off_zero_error,"configured_normal_strength":strength if family_id>5 else null,"fine_normals_supported":family_id>5,"plate_habit":plate_habit,"seed":seed_id})
		for view:String in ["mapped_on","mapped_zero","geometric","physical_off","physical_zero"]:
			var image:Image={"mapped_on":mapped_on,"mapped_zero":mapped_zero,"geometric":geometric,"physical_off":physical_off,"physical_zero":physical_zero}[view]
			var path:String="res://tools/biome_extensions/artifacts/structure_normal_"+label+"_"+view+".png"
			assert(image.save_png(path)==OK);capture_hashes[path]=FileAccess.get_sha256(path)
		print("STRUCTURE_NORMAL_CONTROL ",cases.back());scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Structure control source changed")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_structure_normal_controls.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"passed":failures.is_empty(),"failures":failures,"records":cases,"capture_sha256":capture_hashes,"source_sha256":hashes,"scope":"Six actual production-streamed supplemental cases: Crystal/Insect/Alien nerve, hardened/dormant carapace plates and a default-rarity thick membrane, original bound shaders, terrain/water hidden only in private fixtures. Tests global debug propagation, configured Insect/Alien strength, mapped-versus-geometric normals and physical normal-off/zero equality. Crystal has geometric facets only, not an invented fine normal map. No whole-biome artistic or performance certificate."},"  "))
	quit(0 if failures.is_empty() else 1)
