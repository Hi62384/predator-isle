extends "res://tools/biome_extensions/render_all.gd"
var corrected:bool=false
var corrected_shader:Shader
var reference_shader:Shader
var terrain_only_debug:bool=false
func set_fixture_visibility()->void:
	# Supplemental shells do not implement extension feature-mask debug modes.
	# Isolate the terrain in that case instead of treating lit shell pixels as
	# a failed terrain emission response. Both original/corrected cases agree.
	if terrain._water!=null:terrain._water.visible=not terrain_only_debug
	for node:MeshInstance3D in terrain._active_chunks.values():
		for child_name:String in ["BiomeStructures","SwampWater","TerrainFeatures"]:
			var child:Node3D=node.get_node_or_null(child_name)
			if child!=null:child.visible=not terrain_only_debug
func apply_test_shader()->void:
	var selected:Shader=corrected_shader if corrected else reference_shader
	for material:ShaderMaterial in terrain._lod_materials.values():material.shader=selected
	for node:MeshInstance3D in terrain._active_chunks.values():
		for surface in range(node.mesh.get_surface_count()):
			var material:ShaderMaterial=node.mesh.surface_get_material(surface)
			if material!=null:material.shader=selected
func settle()->bool:
	var success:bool=await super.settle()
	if success:apply_test_shader()
	if success:set_fixture_visibility()
	return success
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	for path:String in ["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_structures.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/check_debug_light_invariance.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	hashes["res://tools/biome_extensions/reference_pre_unlit_debug_terrain.gdshader"]=FileAccess.get_sha256("res://tools/biome_extensions/reference_pre_unlit_debug_terrain.gdshader")
	corrected_shader=load("res://shaders/terrain_biomes.gdshader");reference_shader=load("res://tools/biome_extensions/reference_pre_unlit_debug_terrain.gdshader")
	var guard:String=" // Overlay blending must not restore physical lighting to emitted-value views.\n // Keep physical shading and both normal-off modes unchanged.\n if(debug_view==3 || debug_view==4 || debug_view==8 || (debug_view>=260 && debug_view<=264)){ALBEDO=vec3(0);ROUGHNESS=1.0;SPECULAR=0.0;}\n"
	assert(corrected_shader.code.count(guard)==1 and corrected_shader.code.replace(guard,"")==reference_shader.code,"The tested final debug guard is the ONLY production shader change")
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(admission.passed);var site:Dictionary=admission.cases[0];var p:=Vector2(site.position[0],site.position[1])
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
	# Controlled diagnostic only: remove fog from this private duplicate so a
	# changing physical sky cannot legitimately tint the emitted-value pixels.
	var world_environment:WorldEnvironment=scene.get_node("WorldEnvironment");world_environment.environment=world_environment.environment.duplicate();world_environment.environment.fog_enabled=false
	root.add_child(scene);scene.get_node("Interface").hide();assert(await settle())
	var sun:DirectionalLight3D=scene.get_node("Sun");var original_sun:Vector3=sun.rotation;var alternate_sun:Vector3=original_sun+Vector3(.7,PI,0)
	var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y);var offset:=Vector3(-90,4-site.junction_height*.4,-130)
	var outcomes:Array=[];var failures:Array=[];var old_negative_controls:int=0
	for mode:int in [3,4,8,262,0,7,18]:
		# Physical response comparison isolates the shader under test. The
		# separate mixed-layer run's four overlap pixels remain an unresolved
		# whole-scene result, not a per-pixel exclusion or relaxed RGB tolerance.
		terrain_only_debug=mode in [262,0,7,18];set_fixture_visibility()
		var images:Dictionary={}
		for fixed:bool in [false,true]:
			corrected=fixed;apply_test_shader()
			for alternative:bool in [false,true]:
				sun.rotation=alternate_sun if alternative else original_sun
				var label:String="debug_light_"+("production" if fixed else "reference")+"_"+str(mode)
				await capture(label,"alternate" if alternative else "default",focus,offset,mode)
				images[Vector2i(int(fixed),int(alternative))]=root.get_texture().get_image()
		if mode in [0,7,18]:
			for alternative:int in [0,1]:
				var a:Image=images[Vector2i(0,alternative)];var b:Image=images[Vector2i(1,alternative)];var maximum:float=0;var changed:int=0
				for y in range(520,712):
					for x in range(8,1272):
						var c:Color=a.get_pixel(x,y);var d:Color=b.get_pixel(x,y);var error:float=maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)));maximum=maxf(maximum,error)
						if error>2.0/255:changed+=1
				if maximum>2.0/255:failures.append({"physical_mode":mode,"sun":alternative,"reference_production_error":maximum,"changed":changed})
				outcomes.append({"physical_mode":mode,"sun":alternative,"maximum_reference_production_rgb_difference":maximum,"changed_pixels_over_two_codes":changed,"sampled_pixels":1264*192})
			continue
		for fixed:bool in [false,true]:
			var a:Image=images[Vector2i(int(fixed),0)];var b:Image=images[Vector2i(int(fixed),1)];var maximum:float=0;var changed:int=0
			for y in range(520,712):
				for x in range(8,1272):
					var c:Color=a.get_pixel(x,y);var d:Color=b.get_pixel(x,y);var error:float=maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)));maximum=maxf(maximum,error)
					if error>2.0/255:changed+=1
			if fixed and maximum>2.0/255:failures.append({"mode":mode,"private_sun_error":maximum,"changed":changed})
			if not fixed and changed>100:old_negative_controls+=1
			outcomes.append({"mode":mode,"private_correction":fixed,"maximum_lower_ground_rgb_change_under_sun_rotation":maximum,"lower_ground_changed_pixels_over_two_codes":changed,"sampled_pixels":1264*192})
	if old_negative_controls<2:failures.append("Original direct-light leak must be detected in at least two debug modes")
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path],"Private debug-light source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_debug_light_invariance.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"actual_render":true,"prototype_only":false,"production_registration":true,"feature_mask_terrain_only":true,"physical_comparison_terrain_only":true,"whole_scene_physical_equivalence":false,"preserved_mixed_layer_mismatch_pixels":4,"records":outcomes,"original_negative_control_modes":old_negative_controls,"captures":records,"source_sha256":hashes,"scope":"Twenty-eight actual streamed renders: frozen original versus bound production shader, four debug modes under two Sun rotations and terrain-only physical modes 0/7/18 equivalence under both lights. Exact source identity excluding only the final debug guard is required. This private fixture alone disables fog/changes Sun; other render layers are hidden equally for feature-mask and physical response comparisons. Lower 192 ground rows test pure emitted-value invariance, required original-leak negatives and unchanged terrain-only physical outputs. The separately preserved mixed-layer run still has four differing overlap pixels; this is not whole-scene physical equivalence, a join fix, runtime or artistic acceptance."},"  "))
	print("DEBUG_LIGHT_INVARIANCE ",outcomes," failures=",failures);scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
