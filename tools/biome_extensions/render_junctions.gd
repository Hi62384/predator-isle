extends "res://tools/biome_extensions/render_all.gd"
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	assert(DisplayServer.get_name()!="headless")
	hashes["res://scripts/alien_carapace_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_carapace_geometry.gd")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	hashes["res://scenes/main.tscn"]=FileAccess.get_sha256("res://scenes/main.tscn")
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://shaders/biome_structures.gdshader","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://shaders/terrain_biomes.gdshader","res://tools/biome_extensions/artifacts/check_junction_admission.json","res://tools/biome_extensions/render_junctions.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed)
	for item:Dictionary in admission.cases:
		var p:=Vector2(item.position[0],item.position[1]);var seed_id:int=item.seed
		scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		terrain=scene.get_node("Terrain");terrain.world_seed=seed_id;terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
		var start:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());fill_seconds=(Time.get_ticks_usec()-start)/1000000.0
		var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+item.junction_height*.4,p.y)
		await capture("alien_junction_"+str(seed_id),"medium",focus,Vector3(-240,140,-360))
		# Prove the real streamed worker/staging path includes the monument,
		# rather than displaying a separately instantiated test-side mesh.
		var elevated_vertices:int=0
		for node:MeshInstance3D in terrain._active_chunks.values():
			var shell:MeshInstance3D=node.get_node_or_null("BiomeStructures")
			if shell==null or shell.mesh==null:continue
			for surface in range(shell.mesh.get_surface_count()):
				for v:Vector3 in shell.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var world:Vector3=shell.to_global(v)
					if Vector2(world.x-p.x,world.z-p.y).length()<item.width*2 and world.y>ground+item.junction_height*.8:elevated_vertices+=1
		assert(elevated_vertices>=20,"Actual production junction admitted at default rarity with normal cavity guards")
		records[-1]["production_elevated_vertices"]=elevated_vertices;records[-1]["seed"]=seed_id
		var membrane_vertices:int=0
		if item.get("membrane_present",false):
			var field=terrain._sampler._extras[7];var cell:=Vector2i(floori(p.x/4096),floori(p.y/4096));var edges:PackedVector2Array=field.network_edges(cell);var descriptor:Dictionary=field.descriptor(cell,4096)
			for key:Vector3i in terrain._active_chunks:
				var node:MeshInstance3D=terrain._active_chunks[key];var span:float=terrain.chunk_size*float(1<<key.z)
				if not Rect2(Vector2(node.position.x,node.position.z),Vector2.ONE*span).has_point(p):continue
				var shell:MeshInstance3D=node.get_node_or_null("BiomeStructures");assert(shell!=null)
				var g=preload("res://scripts/biome_extension_structures.gd").new();g.origin=node.global_position;g._support_steps=g.support_grids(terrain.chunk_size,terrain.close_resolution,terrain.middle_resolution,terrain.maximum_lod)
				preload("res://scripts/alien_membrane_geometry.gd").new().emit(g,terrain._sampler,p,(edges[1]-p).normalized(),item.width,item.junction_height,descriptor.angle)
				for surface in range(shell.mesh.get_surface_count()):
					var material:ShaderMaterial=shell.mesh.surface_get_material(surface)
					if int(material.get_shader_parameter("family"))!=7:continue
					var vertices:PackedVector3Array=shell.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					assert(vertices.slice(vertices.size()-g.vertices.size())==g.vertices,"Exact actual worker/staged membrane vertices, no private mesh replacement")
					membrane_vertices=g.vertices.size()
			assert(membrane_vertices==5136,"Actual complete default-rarity membrane in production cut")
		records[-1]["production_membrane_vertices"]=membrane_vertices
		await capture("alien_junction_"+str(seed_id),"aerial",focus,Vector3(-650,450,-900));records[-1]["seed"]=seed_id
		await capture("alien_junction_"+str(seed_id),"ground",focus,Vector3(-90,4-item.junction_height*.4,-130));records[-1]["seed"]=seed_id
		# Keep the original views and add the opposite, sun-facing side. Do
		# not relight the scene to disguise its actual material response.
		var toward_sun:Vector3=scene.get_node("Sun").global_basis.z.normalized()
		var horizontal:=Vector2(toward_sun.x,toward_sun.z).normalized()*360
		await capture("alien_junction_"+str(seed_id),"sunlit",focus,Vector3(horizontal.x,160,horizontal.y));records[-1]["seed"]=seed_id
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Junction review source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_junctions.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_render":true,"renderer":RenderingServer.get_current_rendering_method(),"captures":records,"source_sha256":hashes,"scope":"Twelve views (medium/aerial/ground plus opposite sun-facing side) of three real dry default-rarity hive junctions in the production streaming cut, unchanged scene lighting/cave guards and 50km view distance. No artistic completion, uninterrupted streaming or whole-world traversal certificate."},"  "))
	print("JUNCTION_RENDER_DONE ",records.size());quit()
