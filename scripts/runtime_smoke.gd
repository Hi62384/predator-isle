extends Node
## Opt-in game/build smoke probe. Inactive unless -- smoke-test is supplied.
var elapsed: float=0.0
var ready_frames: int=0
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	get_tree().root.size=Vector2i(1280,720)
func _process(delta: float) -> void:
	elapsed+=delta
	var terrain=get_parent()
	if elapsed>120.0:
		push_error("RUNTIME_SMOKE_TIMEOUT: no complete streamed partition")
		get_tree().quit(2);set_process(false);return
	if terrain.committed_revision!=terrain.partition_revision or terrain._active_chunks.is_empty():return
	ready_frames+=1
	if OS.get_cmdline_user_args().has("extension-debug-smoke") and ready_frames>=20 and ready_frames<25:
		var debug_index:int=ready_frames-20
		terrain.set_debug_view(149+debug_index)
		var names:Array[String]=["Extension ownership","Extension regional identity","Extension feature intensity","Extension wetness","Extension geometric normals"]
		if terrain.get_debug_view_name()!=names[debug_index] or int(terrain._terrain_material.get_shader_parameter("debug_view"))!=260+debug_index:
			push_error("RUNTIME_SMOKE_DEBUG: extension HUD or shader mode mismatch")
			get_tree().quit(3);set_process(false);return
	if ready_frames==25 and OS.get_cmdline_user_args().has("extension-debug-smoke"):terrain.set_debug_view(0)
	if ready_frames<30:return
	set_process(false)
	await RenderingServer.frame_post_draw
	var failure: String=""
	for uniform in ["palette_color","palette_normal"]:
		var palette: Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
		if palette==null or palette.get_layers()!=9:failure="Missing nine-layer Grass palette: "+uniform
	if terrain.target.global_position.y<terrain.get_height_at(terrain.target.global_position)+1.0:failure="Camera started below terrain"
	if terrain._settings_snapshot.forest_coverage>0:
		for uniform in ["forest_colors","forest_normals"]:
			var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
			if array==null or array.get_layers()!=2:failure="Forest CC0 array missing: "+uniform
	if terrain._settings_snapshot.tropical_coverage>0:
		for bank:Array in [["savanna",8],["jungle",7],["swamp",3],["mountain",3]]:
			for kind:String in ["colors","normals"]:
				var uniform:String=bank[0]+"_"+kind;var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
				if array==null or array.get_layers()!=bank[1]:failure="Tropical shared PBR array missing: "+uniform
	if terrain._settings_snapshot.badlands_coverage>0:
		for bank:Array in [["savanna",8],["jungle",7],["mountain",3]]:
			for kind:String in ["colors","normals"]:
				var uniform:String=bank[0]+"_"+kind;var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
				if array==null or array.get_layers()!=bank[1]:failure="Badlands shared PBR array missing: "+uniform
	if terrain._settings_snapshot.beaches_enabled:
		for uniform in ["beach_colors","beach_normals"]:
			var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
			if array==null or array.get_layers()!=4:failure="Beach CC0 array missing: "+uniform
	if terrain._settings_snapshot.mountain_coverage>0 or terrain._settings_snapshot.rocky_coast_enabled or terrain._settings_snapshot.beaches_enabled:
		for uniform in ["mountain_colors","mountain_normals"]:
			var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
			if array==null or array.get_layers()!=3:failure="Mountain CC0 array missing: "+uniform
	if terrain._settings_snapshot.savanna_coverage>0 or terrain._settings_snapshot.mountain_coverage>0 or terrain._settings_snapshot.rocky_coast_enabled:
		for uniform in ["savanna_colors","savanna_normals"]:
			var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
			if array==null or array.get_layers()!=8:failure="Savanna CC0 array missing: "+uniform
	if terrain._settings_snapshot.swamp_coverage>0:
		for uniform in ["swamp_colors","swamp_normals"]:
			var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
			if array==null or array.get_layers()!=3:failure="Swamp CC0 array missing: "+uniform
	if terrain._settings_snapshot.jungle_coverage>0 or terrain._settings_snapshot.forest_coverage>0 or terrain._settings_snapshot.swamp_coverage>0 or terrain._settings_snapshot.mountain_coverage>0 or terrain._settings_snapshot.rocky_coast_enabled:
		for uniform in ["jungle_colors","jungle_normals"]:
			var array:Texture2DArray=terrain._terrain_material.get_shader_parameter(uniform)
			if array==null or array.get_layers()!=7:failure="Jungle CC0 array missing: "+uniform
	var output: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("smoke-output="):output=arg.trim_prefix("smoke-output=")
	var report: Dictionary={"elapsed_s":elapsed,"loaded_chunks":terrain.get_loaded_chunk_count(),"revision":terrain.committed_revision,"feature":terrain.jungle_preview_feature,"position":str(terrain.target.global_position),"ground_height":terrain.get_height_at(terrain.target.global_position),"biome":terrain.get_biome_name_at(terrain.target.global_position),"failure":failure,"exported":not OS.has_feature("editor"),"engine":Engine.get_version_info().string}
	report["jungle_preview"]=terrain.jungle_preview
	report["forest_preview"]=terrain.forest_preview
	report["savanna_preview"]=terrain.savanna_preview
	report["mountain_preview"]=terrain.mountain_preview
	report["coast_preview"]=terrain.coast_preview
	report["beach_preview"]=terrain.beach_preview
	report["tropical_preview"]=terrain.tropical_preview
	report["badlands_preview"]=terrain.badlands_preview
	report["extension_preview"]=terrain.extension_preview
	report["extension_debug_smoke"]=OS.get_cmdline_user_args().has("extension-debug-smoke")
	if terrain.badlands_preview:report["feature"]=terrain.badlands_preview_feature
	if terrain.tropical_preview:report["feature"]=terrain.tropical_preview_feature
	if terrain.beach_preview:report["feature"]=terrain.beach_preview_feature
	if terrain.coast_preview:report["feature"]=terrain.coast_preview_feature
	report["swamp_preview"]=terrain.swamp_preview
	var water_tiles:int=0
	for node:MeshInstance3D in terrain._active_chunks.values():
		var water:MeshInstance3D=node.get_node_or_null("SwampWater")
		if water!=null and water.mesh!=null:water_tiles+=1
	report["swamp_water_tiles"]=water_tiles
	report["local_water_level"]=terrain._sampler.get_water_surface_height(terrain.target.global_position.x,terrain.target.global_position.z)
	if terrain.mountain_preview:report["feature"]=terrain.mountain_preview_feature
	if terrain.swamp_preview:report["feature"]=terrain.swamp_preview_feature
	if terrain.forest_preview:report["feature"]=terrain.forest_preview_feature
	if terrain.savanna_preview:report["feature"]=terrain.savanna_preview_feature
	if terrain.jungle_preview:report["feature"]=terrain.jungle_preview_feature
	if not output.is_empty():
		var file:=FileAccess.open(output+".json",FileAccess.WRITE)
		if file==null:failure="Cannot write requested smoke result"
		else:file.store_string(JSON.stringify(report,"\t"))
		var pixels: Image=get_viewport().get_texture().get_image()
		if pixels==null or pixels.save_png(output+".png")!=OK:failure="Cannot save rendered smoke capture"
	print("RUNTIME_SMOKE_", "PASS" if failure.is_empty() else "FAIL", ": ",JSON.stringify(report))
	if not failure.is_empty():push_error(failure)
	get_tree().quit(0 if failure.is_empty() else 1)
