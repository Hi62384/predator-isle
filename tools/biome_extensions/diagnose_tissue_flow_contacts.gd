extends "res://tools/biome_extensions/probe_conduit_join.gd"
const RENDER="res://tools/biome_extensions/artifacts/revisions/experiment_render_alien_tissue_flow_d9a111d59fab/evidence/tools/biome_extensions/artifacts/render_alien_tissue_flow.json"
func set_flow(ground:bool,shells:bool)->void:
	for node:MeshInstance3D in terrain._active_chunks.values():
		if node.mesh.has_meta("alien_tissue_flow"):node.mesh.surface_get_material(0).set_shader_parameter("alien_tissue_flow_enabled",ground)
		if node.mesh.has_meta("extension_structures"):
			var mesh:ArrayMesh=node.mesh.get_meta("extension_structures")
			for surface in range(mesh.get_surface_count()):
				var material:ShaderMaterial=mesh.surface_get_material(surface)
				if material.get_shader_parameter("family")==7:material.set_shader_parameter("alien_tissue_flow_enabled",shells)
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	for path:String in [RENDER,"res://tools/biome_extensions/diagnose_tissue_flow_contacts.gd","res://tools/biome_extensions/probe_conduit_join.gd","res://tools/biome_extensions/render_all.gd","res://tools/biome_extensions/check_alien_tissue_transport.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_tissue_coordinates.gd","res://scripts/biome_extension_settings.gd","res://shaders/alien_tissue_flow.gdshaderinc","res://shaders/biological_sampling.gdshaderinc","res://shaders/biome_extensions.gdshaderinc","res://shaders/biome_structures.gdshader"]:hashes[path]=FileAccess.get_sha256(path)
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for relative:String in regression.source_sha256:
		var path:String="res://"+relative.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[relative]);hashes[path]=regression.source_sha256[relative]
	var frozen=JSON.parse_string(FileAccess.get_file_as_string(RENDER));var view:Dictionary={}
	for record:Dictionary in frozen.views:
		if record.seed==17 and record.phase==1 and record.view=="context":view=record
	assert(not view.is_empty())
	var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(17,true);var field=locator._extras[7];var p:=Vector2.INF;var frame:Dictionary={}
	for index in range(4096):
		var paths:PackedVector2Array=field.network_edges(Vector2i(index%64-32,index/64-32));var point:Vector2=paths[0].lerp(paths[1],.5)
		if locator._island_mask(point.x,point.y)<.2 or field.region(point)<.75 or field.region(point)>1.5:continue
		var candidate:Dictionary=preload("res://scripts/alien_tissue_coordinates.gd").sample(field,point)
		if candidate.weight>.5:p=point;frame=candidate;break
	assert(p.is_finite());var axis:Vector2=frame.tangent;var normal:=Vector2(-axis.y,axis.x);var focus:=Vector3(p.x,locator._get_height(p.x,p.y)+2,p.y);assert(str(focus)==view.focus)
	var viewpoint:Vector3=focus+Vector3(normal.x*180-axis.x*250,180,normal.y*180-axis.y*250);viewpoint.y=maxf(viewpoint.y,locator._get_height(viewpoint.x,viewpoint.z)+12);assert(str(viewpoint)==view.camera)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.far=18000;camera.position=viewpoint;terrain=scene.get_node("Terrain");terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.emission_strength=0;terrain.world_seed=17;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
	# Isolate the original flow study from later independently switched work.
	terrain.settings.alien_infected.nerve_material_variation=false
	terrain.settings.alien_infected.hive_grounded_shoulders=false
	for property:Dictionary in terrain.get_property_list():
		if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
	var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());camera.look_at(focus)
	if terrain._water!=null:terrain._water.hide()
	for node:MeshInstance3D in terrain._active_chunks.values():
		var water:Node3D=node.get_node_or_null("SwampWater")
		if water!=null:water.hide()
	var images:Dictionary={};var captures:Dictionary={}
	for mode:int in [0,3,4,8]:
		for variant:String in (["off","both","terrain","shells"] if mode==0 else ["off","both"]):
			set_flow(variant in ["both","terrain"],variant in ["both","shells"]);terrain.set_debug_view(mode)
			for idle in range(24):await process_frame
			await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/tissue_contacts_%d_%s.png"%[mode,variant];assert(image.save_png(path)==OK);captures[path]=FileAccess.get_sha256(path);images[str(mode)+variant]=image
	# Original reviewed locations,never reselected from the corrected image.
	var pixels:Array[Vector2]=[Vector2(607,260),Vector2(606,298),Vector2(602,312),Vector2(600,339),Vector2(592,358),Vector2(586,373),Vector2(580,385)]
	var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,fog_disabled;uniform vec3 source_id;void fragment(){ALBEDO=source_id;}"
	var ground_id:=ShaderMaterial.new();ground_id.shader=shader;ground_id.set_shader_parameter("source_id",Vector3(1,0,0))
	var shell_id:=ShaderMaterial.new();shell_id.shader=shader;shell_id.set_shader_parameter("source_id",Vector3(0,1,0));var overrides:Array=[]
	for node:MeshInstance3D in terrain._active_chunks.values():
		overrides.append([node,node.material_override]);node.material_override=ground_id
		var structure:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if structure!=null:overrides.append([structure,structure.material_override]);structure.material_override=shell_id
	for idle in range(24):await process_frame
	await RenderingServer.frame_post_draw;var source_ids:Image=root.get_texture().get_image();var id_path:String="res://tools/biome_extensions/artifacts/tissue_contacts_scaled_source_ids.png";assert(source_ids.save_png(id_path)==OK);captures[id_path]=FileAccess.get_sha256(id_path)
	for pair:Array in overrides:pair[0].material_override=pair[1]
	var logical_size:Vector2=camera.get_viewport().get_visible_rect().size;var raster_size:=Vector2(source_ids.get_size());var source_matches:int=0
	var probes:Array=[]
	for pixel:Vector2 in pixels:
		var logical_pixel:Vector2=(pixel+Vector2(.5,.5))*logical_size/raster_size
		var from:Vector3=camera.project_ray_origin(logical_pixel);var direction:Vector3=camera.project_ray_normal(logical_pixel);var ground:Dictionary={};var shell:Dictionary={}
		for node:MeshInstance3D in terrain._active_chunks.values():
			var hit:Dictionary=mesh_hit(node,from,direction,ground.get("distance_m",2000.0),"terrain")
			if not hit.is_empty():ground=hit
			var structure:MeshInstance3D=node.get_node_or_null("BiomeStructures")
			if structure!=null and structure.mesh!=null:
				hit=mesh_hit(structure,from,direction,shell.get("distance_m",2000.0),"shell")
				if not hit.is_empty():shell=hit
		var sampled:Dictionary={}
		for name:String in images:sampled[name]=images[name].get_pixel(int(pixel.x),int(pixel.y))
		var visible:Dictionary=shell if not shell.is_empty() and shell.distance_m<ground.get("distance_m",2000.0) else ground
		var id:Color=source_ids.get_pixel(int(pixel.x),int(pixel.y));var gpu_kind:String="terrain" if id.r>.2 and id.r>id.g*2 else ("shell" if id.g>.2 and id.g>id.r*2 else "unclassified")
		assert(visible.get("kind","")==gpu_kind,"Corrected closest triangle must match independent GPU source IDs");source_matches+=1
		probes.append({"pixel":pixel,"logical_pixel":logical_pixel,"visible":visible,"gpu_kind":gpu_kind,"source_matches":true,"ground":ground,"shell":shell,"ray_gap_metres":absf(ground.distance_m-shell.distance_m) if not ground.is_empty() and not shell.is_empty() else INF,"colors_by_mode_and_layer":sampled})
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/diagnose_tissue_flow_contacts_scaled.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":hashes,"capture_sha256":captures,"probes":probes,"cpu_gpu_source_matches":source_matches,"scope":"Corrected raster-to-logical camera diagnostic at the exact frozen seed17 context pose and seven original pixels. Actual terrain/shell GPU IDs independently agree with all corrected closest-triangle rays. Later material variation and grounded shoulders explicitly disabled to isolate original flow geometry. Flow toggled terrain/shell/both/off;physical/unlit/geometric/mapped views. Not a geometry fix,art acceptance or new proof of the older broken UV-derivative counterfactual."},"  "));print("TISSUE_CONTACT_SCALED probes=",probes.size()," source_matches=",source_matches);scene.queue_free();await process_frame;quit()
