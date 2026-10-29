extends SceneTree
## Real game controller, mesh builder, material and water. No static demo terrain.
var scene: Node
var terrain: Node
var camera: Camera3D
var records: Array=[]
var started: int
var run_source_hashes: Dictionary={}

func set_view_parameter(parameter: String, value: Variant) -> void:
	# Every active LOD owns a material duplicate. Updating only LOD0 made
	# medium/aerial diagnostics silently retain ordinary shaded materials.
	for material: ShaderMaterial in terrain._lod_materials.values():
		material.set_shader_parameter(parameter,value)

func _initialize() -> void:call_deferred("run")

func settle() -> bool:
	var tick: int=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision:
		await process_frame
		if Time.get_ticks_msec()-tick>120000:
			push_error("Desert preview partition timeout")
			return false
	return true

func capture(name: String,focus: Vector3,offset: Vector3) -> bool:
	if OS.get_cmdline_user_args().has("qa-no-shadows"):name+="_no_shadows"
	if OS.get_cmdline_user_args().has("qa-legacy-projection"):name+="_legacy_projection"
	var position: Vector3=focus+offset
	# Keep the camera above the actual canonical terrain, including nearby crests.
	position.y=maxf(position.y,terrain.get_height_at(position)+1.8)
	# Do not review a landmark through an intervening ridge. Raise only the
	# inspection camera, never the terrain, until the target line is clear.
	var margin: float=0.25 if offset.length()<30.0 else 3.0
	for step in range(1,16):
		var t: float=float(step)/16.0
		var point: Vector3=position.lerp(focus+Vector3.UP*0.7,t)
		position.y+=maxf(0.0,terrain.get_height_at(point)+margin-point.y)/(1.0-t)
	camera.near=clampf((position.y-terrain.get_height_at(position))*0.01,0.1,10.0)
	terrain.request_teleport(position)
	if not await settle():return false
	camera.look_at(focus+Vector3.UP*0.7)
	for frame in range(20):await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	if image==null or image.is_empty():
		push_error("No rendered viewport image; headless is not visual validation")
		return false
	var file: String="res://tools/desert/artifacts/"+name+".png"
	if image.save_png(file)!=OK:return false
	records.append({"name":name,"sha256":FileAccess.get_sha256(file),"focus":[focus.x,focus.y,focus.z],"camera":[camera.position.x,camera.position.y,camera.position.z],"file":file,"leaves":terrain.get_loaded_chunk_count()})
	print("Captured ",name)
	return true

func run() -> void:
	started=Time.get_ticks_msec()
	for path in ["scripts/desert_sampler.gd","scripts/desert_drainage.gd","scripts/desert_settings.gd","scripts/terrain_mesh_builder.gd","scripts/chunk_terrain.gd","shaders/terrain_biomes.gdshader","shaders/desert_material.gdshaderinc","shaders/desert_control_decode.gdshaderinc","config/biomes/desert_settings.tres","data/desert_previews.json","tools/desert/preview_desert.gd","config/world/terrain_settings.tres","scenes/main.tscn"]:
		run_source_hashes[path]=FileAccess.get_sha256("res://"+path)
	if DisplayServer.get_name() == "headless":
		push_error("Native visual review requires an actual rendered viewport")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/desert/artifacts"))
	var locations: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/desert/preview_locations.json"))
	assert(locations.get("all_found",false))
	for mixed in [false,true]:
		var wanted: PackedStringArray=OS.get_cmdline_user_args()
		if not wanted.is_empty():
			var needed: bool=false
			for feature in wanted:
				if locations.features.has(feature) and (feature=="desert_grass_transition")==mixed:needed=true
			if not needed:continue
		scene=load("res://scenes/main.tscn").instantiate()
		terrain=scene.get_node("Terrain")
		terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		terrain.world_seed=int(locations.seed)
		terrain.settings.temperature_enabled=false
		terrain.settings.grass_coverage=50.0 if mixed else 0.0
		terrain.settings.desert_coverage=50.0 if mixed else 100.0
		terrain.settings.snow_coverage=0;terrain.settings.stone_coverage=0
		if mixed:
			terrain.settings.grass_region_size=24000;terrain.settings.desert_region_size=24000;terrain.settings.biome_size=1.0
		camera=scene.get_node("FreeCamera")
		# Keep the real camera/scene but disable interactive capture before _ready.
		# Match FreeCamera's existing 50 km far distance explicitly.
		camera.set_script(null)
		camera.far=50000.0
		root.add_child(scene)
		if OS.get_cmdline_user_args().has("qa-no-shadows"):scene.get_node("Sun").shadow_enabled=false
		if OS.get_cmdline_user_args().has("qa-legacy-projection"):set_view_parameter("diagnostic_surface",3)
		scene.get_node("Interface").hide()
		for name in locations.features:
			if (name=="desert_grass_transition")!=mixed:continue
			var requested: PackedStringArray=OS.get_cmdline_user_args()
			if not requested.is_empty() and not requested.has(name):continue
			var item: Dictionary=locations.features[name]
			var focus:=Vector3(item.x,0,item.z)
			focus.y=terrain.get_height_at(focus)
			var offsets: Dictionary={"ground":Vector3(-8,1.8,-13),"medium":Vector3(550,210,620),"aerial":Vector3(3900,2300,4100)}
			for distance in offsets:
				if not await capture(name+"_"+distance,focus,offsets[distance]):
					await finish(false)
					return
			if OS.get_cmdline_user_args().has("qa-geometry"):
				set_view_parameter("diagnostic_surface",1)
				await capture(name+"_geometry",focus,offsets.ground)
				await capture(name+"_geometry_medium",focus,offsets.medium)
				set_view_parameter("diagnostic_surface",2)
				await capture(name+"_albedo",focus,offsets.ground)
				await capture(name+"_albedo_medium",focus,offsets.medium)
				set_view_parameter("diagnostic_surface",0)
				set_view_parameter("debug_view",48)
				await capture(name+"_families_medium",focus,offsets.medium)
				set_view_parameter("debug_view",0)
			if name=="sand_sea" or name=="major_canyon" or mixed:
				for mode in [3,8,40,42,44,48,49,50,51,52,53]:
					set_view_parameter("debug_view",mode)
					if not await capture(name+"_debug_"+str(mode),focus,offsets.aerial):
						await finish(false)
						return
				set_view_parameter("debug_view",0)
		scene.queue_free()
		for frame in range(4):await process_frame
		scene=null
	await finish(true)

func finish(ok: bool) -> void:
	var result: Dictionary={"completed":ok,"source_hashes":run_source_hashes,"engine":Engine.get_version_info().string,"os":OS.get_name(),"elapsed_s":(Time.get_ticks_msec()-started)/1000.0,"captures":records,"note":"Images require human visual review; saved images alone do not establish acceptance."}
	var report_name: String="preview_report.json" if OS.get_cmdline_user_args().is_empty() else "preview_report_selection.json"
	FileAccess.open("res://tools/desert/artifacts/"+report_name,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	if is_instance_valid(scene):scene.queue_free();await process_frame
	quit(0 if ok else 1)
