extends "res://tools/biome_extensions/probe_conduit_join.gd"
const FIXTURE="res://tools/biome_extensions/artifacts/render_tissue_variation_registered.json"
func vector(text:String)->Vector3:
	var parts:PackedStringArray=text.trim_prefix("(").trim_suffix(")").split(",");return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
func set_layers(ground:bool,shells:bool)->void:
	for node:MeshInstance3D in terrain._active_chunks.values():
		node.layers=1 if ground else 0
		var structure:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if structure!=null:structure.layers=1 if shells else 0
func run()->void:
	assert(DisplayServer.get_name()!="headless");DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(960,540));root.size=Vector2i(960,540)
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));assert(fixture.passed);var view:Dictionary={}
	for item:Dictionary in fixture.views:
		if item.seed==17 and item.view=="ground":view=item;break
	assert(not view.is_empty());hashes[FIXTURE]=FileAccess.get_sha256(FIXTURE)
	for path:String in fixture.source_sha256:assert(FileAccess.get_sha256(path)==fixture.source_sha256[path]);hashes[path]=fixture.source_sha256[path]
	for path:String in ["res://tools/biome_extensions/diagnose_tissue_ground_boundary.gd","res://tools/biome_extensions/probe_conduit_join.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var coordinate_proof_path:String="res://tools/biome_extensions/artifacts/check_raster_camera_coordinates.json";var coordinate_proof=JSON.parse_string(FileAccess.get_file_as_string(coordinate_proof_path));assert(coordinate_proof.passed and coordinate_proof.detected_unscaled_negatives==3);hashes[coordinate_proof_path]=FileAccess.get_sha256(coordinate_proof_path)
	for path:String in coordinate_proof.source_sha256:assert(FileAccess.get_sha256(path)==coordinate_proof.source_sha256[path]);hashes[path]=coordinate_proof.source_sha256[path]
	var focus:Vector3=vector(view.focus);var locator=preload("res://tools/biome_extensions/check_alien_tissue_transport.gd").builder(17,true)
	scene=load("res://scenes/main.tscn").instantiate();camera=scene.get_node("FreeCamera");camera.set_script(null);camera.position=vector(view.camera);camera.far=18000;terrain=scene.get_node("Terrain");terrain.world_seed=17;terrain.settings=locator.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.emission_strength=0;terrain.maximum_lod=4;terrain.extension_preview="";terrain.tropical_preview=false;terrain.badlands_preview=false
	for property:Dictionary in terrain.get_property_list():
		if String(property.name).begins_with("start_in_"):terrain.set(property.name,false)
	var target:=Marker3D.new();target.position=focus;scene.add_child(target);terrain.target=target;root.add_child(scene);scene.get_node("Interface").hide();assert(await settle());camera.look_at(focus)
	if terrain._water!=null:terrain._water.hide()
	for node:MeshInstance3D in terrain._active_chunks.values():
		var water:Node3D=node.get_node_or_null("SwampWater")
		if water!=null:water.hide()
	var captures:Dictionary={};var images:Dictionary={}
	for mode:int in [0,3,4,8]:
		terrain.set_debug_view(mode)
		for variant:String in (["both","ground","shells"] if mode in [0,3] else ["both"]):
			set_layers(variant!="shells",variant!="ground")
			for idle in range(24):await process_frame
			await RenderingServer.frame_post_draw;var image:Image=root.get_texture().get_image();var path:String="res://tools/biome_extensions/artifacts/tissue_ground_boundary_%d_%s.png"%[mode,variant];assert(image.save_png(path)==OK);captures[path]=FileAccess.get_sha256(path);images[str(mode)+variant]=image
	set_layers(true,true);terrain.set_debug_view(0)
	# Independent depth/source raster:override ONLY material,not geometry,
	# transforms,culling or the camera. Terrain red,attached shells green.
	var id_shader:=Shader.new();id_shader.code="shader_type spatial;render_mode unshaded,fog_disabled;uniform vec3 source_id;void fragment(){ALBEDO=source_id;}"
	var ground_id:=ShaderMaterial.new();ground_id.shader=id_shader;ground_id.set_shader_parameter("source_id",Vector3(1,0,0));var shell_id:=ShaderMaterial.new();shell_id.shader=id_shader;shell_id.set_shader_parameter("source_id",Vector3(0,1,0));var overrides:Array=[]
	for node:MeshInstance3D in terrain._active_chunks.values():
		overrides.append([node,node.material_override]);node.material_override=ground_id
		var structure:MeshInstance3D=node.get_node_or_null("BiomeStructures")
		if structure!=null:overrides.append([structure,structure.material_override]);structure.material_override=shell_id
	for idle in range(24):await process_frame
	await RenderingServer.frame_post_draw;var source_ids:Image=root.get_texture().get_image();var source_id_path:String="res://tools/biome_extensions/artifacts/tissue_ground_boundary_source_ids.png";assert(source_ids.save_png(source_id_path)==OK);captures[source_id_path]=FileAccess.get_sha256(source_id_path)
	for pair:Array in overrides:pair[0].material_override=pair[1]
	var probes:Array=[];var selection:Array=[];var physical:Image=images["0both"];var raster_size:=Vector2(physical.get_size());var logical_size:Vector2=camera.get_viewport().get_visible_rect().size;var source_matches:int=0
	for row:int in [360,440,500]:
		var best_x:int=0;var best_score:float=-1
		# Diagnostic selection only: strongest broad step in the original
		# visible strip. This is not a quality mask or a relaxed acceptance gate.
		for x in range(260,680):
			var left:float=0;var right:float=0
			for offset in range(3,21):
				left+=physical.get_pixel(x-offset,row).get_luminance();right+=physical.get_pixel(x+offset,row).get_luminance()
			var score:float=absf(left-right)/18
			if score>best_score:best_score=score;best_x=x
		selection.append({"row":row,"x":best_x,"broad_luminance_step":best_score})
		for delta:int in [-3,0,3]:
			var pixel:=Vector2(best_x+delta,row);var logical_pixel:Vector2=(pixel+Vector2(.5,.5))*logical_size/raster_size;var from:Vector3=camera.project_ray_origin(logical_pixel);var direction:Vector3=camera.project_ray_normal(logical_pixel);var ground:Dictionary={};var shell:Dictionary={}
			for node:MeshInstance3D in terrain._active_chunks.values():
				var hit:Dictionary=mesh_hit(node,from,direction,ground.get("distance_m",1000.0),"terrain")
				if not hit.is_empty():ground=hit
				var structure:MeshInstance3D=node.get_node_or_null("BiomeStructures")
				if structure!=null:
					hit=mesh_hit(structure,from,direction,shell.get("distance_m",1000.0),"shell")
					if not hit.is_empty():shell=hit
			var visible:Dictionary=shell if not shell.is_empty() and shell.distance_m<ground.get("distance_m",1000.0) else ground
			var colors:Dictionary={}
			for key:String in images:colors[key]=str(images[key].get_pixel(int(pixel.x),int(pixel.y)))
			var id:Color=source_ids.get_pixel(int(pixel.x),int(pixel.y));var raster_kind:String="terrain" if id.r>id.g*2 and id.r>.2 else ("shell" if id.g>id.r*2 and id.g>.2 else "unclassified")
			var matches:bool=visible.get("kind","")==raster_kind
			if matches:source_matches+=1
			probes.append({"pixel":str(pixel),"logical_pixel_center":str(logical_pixel),"visible":visible,"terrain":ground,"shell":shell,"colors":colors,"gpu_source_id":str(id),"gpu_visible_kind":raster_kind,"cpu_source_matches_gpu":matches,"reprojection_error_pixels":(camera.unproject_position(visible.position)*raster_size/logical_size-(pixel+Vector2(.5,.5))).length() if not visible.is_empty() else null})
	for path:String in hashes:assert(FileAccess.get_sha256(path)==hashes[path])
	FileAccess.open("res://tools/biome_extensions/artifacts/diagnose_tissue_ground_boundary.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":hashes,"capture_sha256":captures,"focus":str(focus),"camera":str(camera.position),"raster_size":str(raster_size),"logical_viewport_size":str(logical_size),"cpu_gpu_source_matches":source_matches,"selection":selection,"probes":probes,"scope":"CORRECTED DIAGNOSTIC collection of remaining broad ground-level boundary at exact registered seed17 ground view. Actual1280x720 logical camera coordinates explicitly scaled from960x540 raster,independently proven by three known GPU quads with unscaled negatives. Physical/unlit/geometric/mapped views,terrain-only/shell-only isolation,independent closest clockwise actual mesh intersections,and separate red/green actual GPU source-ID raster across three strongest broad visible strip steps. Per-point CPU/GPU source agreement and reprojection errors reported,not silently assumed. No generated geometry,lighting or target changes. Selection is diagnostic,not an exclusion mask or artistic acceptance;no contact fix claimed. Original unscaled ray assignments separately archived as failed."},"  "));print("TISSUE_GROUND_BOUNDARY_DIAGNOSTIC ",probes.size()," source_matches=",source_matches);scene.queue_free();await process_frame;quit()
