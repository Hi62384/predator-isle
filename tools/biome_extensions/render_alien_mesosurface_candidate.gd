extends "res://tools/biome_extensions/render_all.gd"
## A/B material trial on the SAME committed production geometry/camera/light.
var trial_shader:Shader
var trial_structure_shader:Shader
var enabled:bool=false
var trial_ready:bool=false
func ground_statistics()->Dictionary:
	var image:Image=root.get_texture().get_image();var total:float=0;var squared:float=0;var neighbor_delta:float=0;var count:int=0
	for y in range(520,712,3):
		for x in range(8,1271,3):
			var a:Color=image.get_pixel(x,y);var b:Color=image.get_pixel(x+1,y)
			var value:float=a.r*.3+a.g*.5+a.b*.2
			total+=value;squared+=value*value;neighbor_delta+=absf(value-(b.r*.3+b.g*.5+b.b*.2));count+=1
	var mean_value:float=total/maxi(count,1)
	return {"sampled_pixels":count,"mean_display_luminance":mean_value,"display_luminance_standard_deviation":sqrt(maxf(0,squared/maxi(count,1)-mean_value*mean_value)),"normalized_mean_adjacent_luminance_delta":neighbor_delta/maxi(count,1)/maxf(mean_value,.0001),"scope":"Lower ground rows, display-referred diagnostic statistics only, not a repetition detector, physical albedo measurement or art acceptance threshold"}
func expanded(path:String)->String:
	var source:String=FileAccess.get_file_as_string(path)
	var pattern:=RegEx.new();assert(pattern.compile('#include "([^"]+)"')==OK)
	var includes:Array[RegExMatch]=pattern.search_all(source)
	for i in range(includes.size()-1,-1,-1):
		var item:RegExMatch=includes[i];var target:String=item.get_string(1)
		if target=="res://shaders/biological_sampling.gdshaderinc":
			target="res://tools/biome_extensions/alien_mesosurface_candidate.gdshaderinc"
			# Expand this one explicitly; its original shared include is deliberate.
			var candidate:String=FileAccess.get_file_as_string(target).replace('#include "res://shaders/biological_sampling.gdshaderinc"',FileAccess.get_file_as_string("res://shaders/biological_sampling.gdshaderinc"))
			source=source.substr(0,item.get_start())+candidate+source.substr(item.get_end())
		else:source=source.substr(0,item.get_start())+expanded(target)+source.substr(item.get_end())
	return source
func set_trial_parameters(material:ShaderMaterial)->void:
	material.set_shader_parameter("alien_mesosurface_amount",1.0 if enabled else 0.0)
	material.set_shader_parameter("alien_detail_contrast",.42 if enabled else 1.0)
func bind_trial()->void:
	print("MESOSURFACE_BIND_BEGIN")
	for material:ShaderMaterial in terrain._lod_materials.values():
		material.shader=trial_shader;set_trial_parameters(material)
	for node:MeshInstance3D in terrain._active_chunks.values():
		for surface in range(node.mesh.get_surface_count()):
			var material:ShaderMaterial=node.mesh.surface_get_material(surface)
			if material!=null:material.shader=trial_shader;set_trial_parameters(material)
		var child:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if child==null or child.mesh==null:continue
		for surface in range(child.mesh.get_surface_count()):
			var material:ShaderMaterial=child.mesh.surface_get_material(surface)
			if material!=null:material.shader=trial_structure_shader;set_trial_parameters(material)
	print("MESOSURFACE_BIND_END")
func settle()->bool:
	var success:bool=await super.settle()
	if success and trial_ready:bind_trial()
	return success
func run()->void:
	hashes["res://scripts/alien_conduit_contact_lod.gd"]=FileAccess.get_sha256("res://scripts/alien_conduit_contact_lod.gd")
	print("MESOSURFACE_BEGIN")
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	var guarded:Array[String]=["res://scenes/main.tscn","res://config/world/terrain_settings.tres","res://scripts/chunk_terrain.gd","res://scripts/lod_biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/biome_extension_settings.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_structures.gdshader","res://shaders/biome_extensions.gdshaderinc","res://tools/biome_extensions/alien_mesosurface_candidate.gdshaderinc","res://tools/biome_extensions/render_alien_mesosurface_candidate.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]
	for path:String in guarded:hashes[path]=FileAccess.get_sha256(path)
	# Bind the trial to the completed shared production source version too,
	# including nested shader includes not visible in the top-level strings.
	var regression=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"));assert(regression.passed)
	for path:String in regression.source_sha256:
		var canonical:String="res://"+path.replace("\\","/")
		assert(FileAccess.get_sha256(canonical)==regression.source_sha256[path],"Shared checkpoint must still be current before this private material trial")
		hashes[canonical]=regression.source_sha256[path]
	for directory:String in ["res://materials","res://assets/textures/biological"]:
		for file:String in DirAccess.get_files_at(directory):
			if directory.ends_with("biological") or file.begins_with("biological_"):hashes[directory+"/"+file]=FileAccess.get_sha256(directory+"/"+file)
	print("MESOSURFACE_GUARDS_READY ",hashes.size())
	var terrain_source:String=expanded("res://shaders/terrain_biomes.gdshader")
	var structure_source:String=expanded("res://shaders/biome_structures.gdshader")
	print("MESOSURFACE_EXPANDED ",terrain_source.length()," / ",structure_source.length())
	# Keep the original shared sampler call graph: the earlier wrapper-heavy
	# trial exceeded the private engine memory bound during shader preparation.
	# No extra texture lookups; soften detail using its already sampled average.
	var old_mix:String="return mix(average,biological_sample(layer,layer==2?2.0:1.5,dx,dy,projection,n),detail);"
	var new_mix:String="return mix(average,biological_sample(layer,layer==2?2.0:1.5,dx,dy,projection,n),detail*alien_detail_contrast);"
	assert(terrain_source.count(old_mix)==1 and structure_source.count(old_mix)==1)
	terrain_source=terrain_source.replace(old_mix,new_mix);structure_source=structure_source.replace(old_mix,new_mix)
	var old_call:String="if(family==7)alien_tissue_sample(region,view_distance,dx,dy,projection,n,bio,tissue_rough);"
	assert(terrain_source.count(old_call)==1)
	terrain_source=terrain_source.replace(old_call,"if(family==7){alien_tissue_sample(region,view_distance,dx,dy,projection,n,bio,tissue_rough);alien_mesosurface_finish(bio,tissue_rough);}")
	var old_height:String="float height=dot(bio,vec3(.3,.5,.2))*(family==3?.001: .003)*coverage;"
	assert(terrain_source.count(old_height)==1)
	terrain_source=terrain_source.replace(old_height,"float height=(family==7?alien_mesosurface_height(bio,view_distance):dot(bio,vec3(.3,.5,.2))*.001)*coverage;")
	var old_shell_call:String="alien_tissue_sample(semantic?UV.x:0.0,length(VERTEX),position_dx,position_dy,w,n,tissue,rough);"
	assert(structure_source.count(old_shell_call)==1)
	structure_source=structure_source.replace(old_shell_call,old_shell_call+"alien_mesosurface_finish(tissue,rough);")
	assert(structure_source.count("float height=dot(tissue,vec3(.3,.5,.2))*.003;")==1)
	structure_source=structure_source.replace("float height=dot(tissue,vec3(.3,.5,.2))*.003;","float height=alien_mesosurface_height(tissue,length(VERTEX));")
	# Private process-local override of the cached resources, NOT saved files.
	# Keeping a separately cloned master shader resident alongside the original
	# exceeded this fixture's memory cap even after sequential preparation.
	trial_shader=load("res://shaders/terrain_biomes.gdshader");trial_shader.code=terrain_source
	trial_structure_shader=load("res://shaders/biome_structures.gdshader");trial_structure_shader.code=structure_source
	trial_ready=true;print("MESOSURFACE_SINGLE_RESOURCE_OVERRIDES_READY")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));assert(manifest.passed)
	var failures:Array=[]
	for site:Dictionary in manifest.cases:
		var p:=Vector2(site.position[0],site.position[1]);scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
		print("MESOSURFACE_SCENE_INSTANTIATED ",site.seed)
		terrain=scene.get_node("Terrain");terrain.world_seed=int(site.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=p;terrain.target=camera
		var started:int=Time.get_ticks_usec();root.add_child(scene);scene.get_node("Interface").hide();print("MESOSURFACE_SCENE_ADDED");assert(await settle());fill_seconds=(Time.get_ticks_usec()-started)/1000000.0
		print("MESOSURFACE_INITIAL_SETTLE_DONE")
		var ground:float=terrain.get_height_at(Vector3(p.x,0,p.y));var focus:=Vector3(p.x,ground+site.junction_height*.4,p.y)
		for view:String in ["ground","medium"]:
			var offset:=Vector3(-90,4-site.junction_height*.4,-130) if view=="ground" else Vector3(-240,140,-360)
			for trial:bool in [false,true]:
				enabled=trial;bind_trial();await capture("mesosurface_"+str(int(site.seed)),view+"_"+("trial" if trial else "off"),focus,offset)
				records[-1]["ground_statistics"]=ground_statistics()
			enabled=false;bind_trial();await capture("mesosurface_"+str(int(site.seed)),view+"_off_return",focus,offset)
			records[-1]["ground_statistics"]=ground_statistics()
			var first:Dictionary=records[-3];var returned:Dictionary=records[-1]
			if first.sha256!=returned.sha256:failures.append({"seed":site.seed,"view":view,"reason":"Disabled return pixels not identical"})
		scene.queue_free();await process_frame;await process_frame
	for path:String in hashes:assert(hashes[path]==FileAccess.get_sha256(path),"Material trial source changed "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/render_alien_mesosurface_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"prototype_only":true,"production_registration":false,"actual_render":true,"single_process_local_shader_resource_overrides":true,"captures":records,"source_sha256":hashes,"scope":"Private A/B/off-return actual production geometry renders under unchanged scene lighting. Cached shader resources overridden only in this isolated process before scene loading; no second resident master shader, no saved shader edits. Shared terrain/shell opaque tissue finish only; no geometry or collision changes. Disabled return image identity required. Performance samples are settled end-to-end frames, not isolated shader timing, launch or total shader-preparation cost; neither broad art acceptance nor production adoption."},"  "))
	quit(0 if failures.is_empty() else 1)
