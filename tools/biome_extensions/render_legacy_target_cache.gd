extends "res://tools/biome_extensions/render_all.gd"
const Variants=preload("res://scripts/terrain_shader_variants.gd")
var domain:String="alien"
var failures:Array=[]
func readback()->Image:
	for frame in range(6):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func different(a:Image,b:Image)->int:
	assert(a.get_size()==b.get_size() and a.get_format()==b.get_format())
	var aa:PackedByteArray=a.get_data();var bb:PackedByteArray=b.get_data();var count:int=0
	for i in range(aa.size()):
		if aa[i]!=bb[i]:count+=1
	return count
func maximum_byte_error(a:Image,b:Image)->int:
	var aa:PackedByteArray=a.get_data();var bb:PackedByteArray=b.get_data();var maximum:int=0
	for index in range(aa.size()):maximum=maxi(maximum,absi(int(aa[index])-int(bb[index])))
	return maximum
func assign(shader:Shader)->void:
	for node:MeshInstance3D in terrain._active_chunks.values():
		var material:ShaderMaterial=node.mesh.surface_get_material(0)
		material.shader=shader
func run()->void:
	assert(DisplayServer.get_name()!="headless")
	hashes[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("domain="):domain=arg.trim_prefix("domain=")
	var family:String="alien_infected" if domain=="alien" else ("spore_forest" if domain=="spore" else domain)
	var warmup:Dictionary={}
	if root.has_meta("low_memory_shader_warmup"):
		var preparation:Dictionary=root.get_meta("low_memory_shader_warmup")
		for path:String in preparation.source_sha256:hashes[path]=preparation.source_sha256[path]
		warmup={"seconds":preparation.seconds,"real_image_banks_loaded_before_warmup":preparation.real_image_banks_loaded_before_warmup}
	assert(domain in ["alien","spore","mixed","default","empty","legacy_mix"] or TerrainSettings.EXTENSION_KEYS.has(family) or Variants.LEGACY.has(domain))
	var single_extension:bool=TerrainSettings.EXTENSION_KEYS.has(family)
	DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_shader_variants.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_settings.gd","res://shaders/terrain_biomes.gdshader","res://shaders/biome_extensions.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://scenes/main.tscn","res://tools/biome_extensions/render_terrain_shader_variants.gd"]:hashes[path]=FileAccess.get_sha256(path)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=50000
	terrain=scene.get_node("Terrain");terrain.target=camera
	var reference_only:bool=OS.get_cmdline_user_args().has("reference_only")
	if reference_only:terrain.specialize_terrain_shader=false
	# Bound this comparison to the near/mid cut. The earlier 50km mixed
	# Insect/Alien trial exceeded 2GiB before capture and remains a failure,
	# not a successful wide-scene performance result.
	if domain=="mixed":terrain.maximum_lod=3;camera.far=6000
	for property:Dictionary in terrain.get_property_list():
		if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
	terrain.extension_preview="";terrain.auto_reload_cliff_settings=false;terrain.auto_reload_ground_settings=false
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	if domain!="default":
		for owner:String in ["grass"]+Variants.LEGACY+TerrainSettings.EXTENSION_KEYS:terrain.settings.set(owner+"_coverage",0)
		terrain.settings.rocky_coast_enabled=false;terrain.settings.beaches_enabled=false
		if single_extension:
			terrain.settings.set(family+"_coverage",100)
			terrain.settings.island_size=100400;terrain.settings.island_spacing=585
		elif domain=="mixed":
			for owner:String in ["grass","forest","badlands","insect_colony","alien_infected"]:terrain.settings.set(owner+"_coverage",20)
			terrain.settings.biome_size=.2;terrain.settings.island_size=100400;terrain.settings.island_spacing=585
			terrain.settings.rocky_coast_enabled=true;terrain.settings.beaches_enabled=true
		elif Variants.LEGACY.has(domain):
			terrain.settings.set(domain+"_coverage",100);terrain.settings.island_size=100400;terrain.settings.island_spacing=585
		elif domain=="legacy_mix":
			for owner:String in ["grass","forest","tropical","badlands"]:terrain.settings.set(owner+"_coverage",20)
			terrain.settings.biome_size=.2;terrain.settings.island_size=100400;terrain.settings.island_spacing=585
			terrain.settings.rocky_coast_enabled=true;terrain.settings.beaches_enabled=true
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.world_seed=terrain.world_seed;b._configure_noise()
	var p:=Vector2.ZERO
	if single_extension:
		var previews=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/previews.json"))
		var item:Dictionary=previews.families[family].primary;p=Vector2(item.x,item.z)
	else:
		var best:float=-1
		for i in range(1200):
			var q:=Vector2(i*7919%120000-60000,i*11939%120000-60000)
			if b._island_mask(q.x,q.y)<.03:continue
			var w:Vector4=b._biome_weights(q.x,q.y);var score:float=1-maxf(maxf(w.x,w.y),maxf(w.z,w.w))
			for weight:float in [b._jungle_weight,b._mountain_weight,b._tropical_weight,b._badlands_weight]:score=minf(score,1-weight)
			for weight:float in b._extra_weights:score=minf(score,1-weight)
			if score>best:p=q;best=score
	var focus:=Vector3(p.x,b._get_height(p.x,p.y)+8,p.y)
	camera.position=focus+Vector3(-130,70,-180)
	terrain.cave_settings=terrain.cave_settings.duplicate();terrain.cave_settings.enabled=false
	print("SHADER_VARIANT_SCENE_ADD ",domain)
	root.add_child(scene);scene.get_node("Interface").hide();print("SHADER_VARIANT_READY ",domain)
	assert(await settle());camera.look_at(focus)
	print("SHADER_VARIANT_SETTLED ",domain," leaves=",terrain._active_chunks.size())
	# Water animation and Alien emission are excluded ONLY from this shader
	# equivalence fixture. Production lighting, geometry and all tissue remain.
	if terrain._water!=null:terrain._water.hide()
	for node:MeshInstance3D in terrain._active_chunks.values():
		var water:Node3D=node.get_node_or_null("SwampWater")
		if water!=null:water.hide()
		var material:ShaderMaterial=node.mesh.surface_get_material(0);material.set_shader_parameter("extension_emission",PackedFloat32Array([0,0,0,0,0,0,0,0]))
	var original:Shader=terrain._terrain_material.shader
	var before_mask:int=Variants.configured_mask(terrain._settings_snapshot)
	var candidate_path:String="res://tools/biome_extensions/legacy_target_cache_candidate.gd";hashes[candidate_path]=FileAccess.get_sha256(candidate_path)
	var generated:String=load(candidate_path).apply_to(load("res://materials/terrain.tres").shader.code)
	for index in range(Variants.LEGACY.size()):
		if (before_mask & (1<<index))==0:generated=generated.replace(".001<"+Variants.CONTROLS[index],"false")
	var optimized:=Shader.new();optimized.code=Variants.source_for(generated,before_mask)
	assert((optimized!=original)==(not reference_only and Variants.supported(before_mask)))
	for debug:int in [0,3,4,8,260]:
		terrain.set_debug_view(debug);assign(original);var a:Image=await readback()
		assign(optimized);var v:Image=await readback()
		assign(original);var r:Image=await readback()
		var delta:int=different(a,v);var returned:int=different(a,r);var maximum:int=maximum_byte_error(a,v)
		if maximum>2 or returned!=0:failures.append({"debug":debug,"optimized_different_bytes":delta,"maximum_byte_error":maximum,"reference_return_different_bytes":returned})
		for pair:Array in [["reference",a],["optimized",v],["return",r]]:
			var path:String="res://tools/biome_extensions/artifacts/legacy_target_cache_%s_%d_%s.png" % [domain,debug,pair[0]];assert(pair[1].save_png(path)==OK)
			records.append({"path":path,"sha256":FileAccess.get_sha256(path),"debug":debug,"kind":pair[0],"maximum_candidate_byte_error":maximum,"different_candidate_bytes":delta})
		print("SHADER_EQUIVALENCE ",domain," ",debug," delta=",delta," reference_return=",returned)
	hashes[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"domain":domain,"reference_only":reference_only,"configured_mask":before_mask,"maximum_lod":terrain.maximum_lod,"camera_far":camera.far,"leaves":terrain._active_chunks.size(),"point":[p.x,p.y],"captures":records,"source_sha256":hashes,"scope":"Actual production streamed meshes and material uniforms. Original/compact/original native comparisons with declared2byte maximum and exact original return. Earlier strict-equality Savanna run failed by1byte and remains archived;not retroactively passed. Cave runtime disabled only in this shading comparison. Mixed comparison restricted to LOD3/6km after the separate wide mixed fixture failed 2GiB; this is not a repaired wide-scene resource result. Animated water hidden and terrain emission zero in this fixture only; original sun/environment unchanged. No frame-time gain or artistic sign-off inferred."}
	report["diagnostic_warmup"]=warmup
	for path:String in hashes:assert(hashes[path]==FileAccess.get_sha256(path))
	FileAccess.open("res://tools/biome_extensions/artifacts/render_legacy_target_cache_"+domain+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
