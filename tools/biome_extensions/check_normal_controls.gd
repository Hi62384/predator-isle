extends "res://tools/biome_extensions/render_all.gd"
## Real production material controls, not test-side normal formulas.
func frame(mode:int)->Image:
	terrain.set_debug_view(mode)
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	assert(DisplayServer.get_name()!="headless")
	hashes["res://scripts/lod_biome_extension_structures.gd"]=FileAccess.get_sha256("res://scripts/lod_biome_extension_structures.gd")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/badlands_material.gdshaderinc","res://tools/biome_extensions/check_normal_controls.gd","res://tools/biome_extensions/artifacts/previews.json"]:hashes[path]=FileAccess.get_sha256(path)
	hashes["res://shaders/biological_sampling.gdshaderinc"]=FileAccess.get_sha256("res://shaders/biological_sampling.gdshaderinc")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"));var failures:Array=[];var cases:Array=[]
	for key:String in TerrainSettings.EXTENSION_KEYS:
		var item:Dictionary=manifest.families[key].primary
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.near=.1;camera.far=50000
		terrain=scene.get_node("Terrain");terrain.extension_preview=key;terrain.extension_preview_position=Vector2(item.x,item.z);terrain.target=camera
		root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
		var point:=Vector3(item.x-6,0,item.z-8)
		var ground_height:float=terrain.get_height_at(point)
		var dry:bool=ground_height>maxf(terrain.water_level,terrain._sampler.get_water_surface_height(point.x,point.z))+3
		# A submerged crater centre placed the camera above the ocean, hundreds
		# of metres from the actual ground. With the ocean hidden its distant
		# flat floor correctly had no fine normals. Admit a real dry rim instead.
		if not dry:
			for radius:float in [64.0,128.0,256.0,512.0,1024.0,2048.0]:
				for sector in range(16):
					var candidate:=Vector3(item.x+cos(sector*TAU/16)*radius,0,item.z+sin(sector*TAU/16)*radius)
					var height:float=terrain.get_height_at(candidate)
					if height>maxf(terrain.water_level,terrain._sampler.get_water_surface_height(candidate.x,candidate.z))+3:
						point=candidate;ground_height=height;dry=true;break
				if dry:break
		assert(dry,"Actual dry near-ground material fixture required: "+key)
		point.y=ground_height+2
		terrain.request_teleport(point);assert(await settle());camera.look_at(point+Vector3(12,-4,16))
		# Isolate terrain normal controls from animated water, glow and structure
		# shadows. Only this test scene is changed, not the production defaults.
		if terrain._water!=null:terrain._water.hide()
		for node:MeshInstance3D in terrain._active_chunks.values():
			for child_name:String in ["SwampWater","BiomeStructures","TerrainFeatures"]:
				var child:Node3D=node.get_node_or_null(child_name)
				if child!=null:child.hide()
		var materials:Array=terrain._material_variants();var values:Array=[]
		for material:ShaderMaterial in materials:
			values.append(material.get_shader_parameter("extension_normals"));material.set_shader_parameter("extension_emission",PackedFloat32Array([0,0,0,0,0,0,0,0]))
		var on:Image=await frame(0);var off:Image=await frame(7)
		for material:ShaderMaterial in materials:material.set_shader_parameter("extension_normals",PackedFloat32Array([0,0,0,0,0,0,0,0]))
		var zero:Image=await frame(0)
		for i in range(materials.size()):materials[i].set_shader_parameter("extension_normals",values[i])
		var geometry:Image=await frame(4);var count:int=0;var changed:int=0;var mean:float=0;var maximum_error:float=0
		for y in range(360,700,3):
			for x in range(20,1260,3):
				if geometry.get_pixel(x,y).g<.55:continue
				var a:Color=on.get_pixel(x,y);var b:Color=off.get_pixel(x,y);var c:Color=zero.get_pixel(x,y)
				var difference:float=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3
				mean+=difference;count+=1
				if difference>.003:changed+=1
				maximum_error=maxf(maximum_error,maxf(absf(b.r-c.r),maxf(absf(b.g-c.g),absf(b.b-c.b))))
		mean/=maxi(count,1);var passed:bool=count>100 and changed>10 and mean>.0001 and maximum_error<.008
		if not passed:failures.append(key)
		cases.append({"biome":key,"passed":passed,"pixels_tested":count,"changed_pixels":changed,"mean_on_off_rgb_difference":mean,"maximum_off_zero_rgb_error":maximum_error,"camera":point,"canonical_ground_height":ground_height,"dry_near_ground_fixture":dry})
		print("EXTENSION_NORMAL_CONTROL ",cases.back())
		on.save_png("res://tools/biome_extensions/artifacts/normal_control_"+key+"_on.png");off.save_png("res://tools/biome_extensions/artifacts/normal_control_"+key+"_off.png");zero.save_png("res://tools/biome_extensions/artifacts/normal_control_"+key+"_zero.png")
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Source changed during normal controls")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_normal_controls.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"passed":failures.is_empty(),"failures":failures,"records":cases,"source_sha256":hashes,"scope":"Eight actual pure-owner production terrain scenes; global ocean and local water/structure nodes hidden, emission disabled only to isolate normal controls. Not whole-world artistic or performance acceptance."},"  "))
	quit(0 if failures.is_empty() else 1)
