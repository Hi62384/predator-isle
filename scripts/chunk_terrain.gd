class_name ChunkTerrain
extends Node3D

## Deterministic, endless terrain streamed in reusable square chunks.
## Climate noise creates broad believable biome regions, while separate masks
## keep dramatic biomes smaller and rarer.

enum Biome { GRASS, DESERT, SNOW, STONE }

const BIOME_NAMES: PackedStringArray = ["Grass", "Desert", "Snow", "Stone"]

@export_category("Terrain Preset")
## Expand to tune biome regions, individual landforms, materials and water. Restart to apply.
@export var settings: TerrainSettings = preload("res://terrain_settings.tres")
## Explicit test override; saved biome settings remain untouched.
@export var grass_preview: bool = false
@export_category("Cliff Normal Controls")
## Edit cliff_normals.tres. Saved changes reload automatically while running.
@export var cliff_normal_settings: CliffNormalSettings = preload("res://cliff_normals.tres")
@export var auto_reload_cliff_settings: bool = true
var _cliff_poll_time: float = 0.0
var _cliff_file_time: int = 0
var _cliff_uniform_cache: Dictionary = {}
var _cliff_texture_cache: Array = []
var _cliff_array: Texture2DArray
@export_category("Ground Material Controls")
@export var ground_material_settings: GroundMaterialSettings = preload("res://ground_materials.tres")
@export var auto_reload_ground_settings: bool = true
var _ground_file_time: int = 0
var _ground_uniform_cache: Dictionary = {}
var terrain_debug_view := 0

@export_category("World")
@export var world_seed: int = 73921
@export_range(-20.0, 20.0, 0.25) var water_level: float = 0.0

@export_category("Chunk Streaming")
@export_range(16.0, 256.0, 1.0) var chunk_size: float = 256.0
@export_range(8, 64, 1) var chunk_resolution: int = 64
@export_range(1, 32, 1) var chunks_created_per_frame: int = 16
@export var target: Node3D
@export_range(1, 6) var worker_count: int = 4
@export_range(1, 8) var distant_job_batch: int = 8
@export_range(0.5, 5.0) var upload_budget_ms: float = 1.5
@export_range(0, 128) var cached_mesh_limit: int = 64

@export_category("Detail Levels")
## Camera leaf uses 2 m vertices at the default 256 m base size.
@export_range(64, 128, 16) var close_resolution: int = 128
## Grid resolution for large parent chunks. LOD1 uses at least 32.
@export_range(4, 64) var middle_resolution: int = 16
@export var terrain_shadows: bool = true

var _settings_snapshot: TerrainSettings
var _sampler: RefCounted
const MeshBuilder = preload("res://scripts/terrain_mesh_builder.gd")
var _jobs: Dictionary = {}
var _inflight: Dictionary = {}
var _ready_chunks: Array = []
var _wanted: Dictionary = {}
var _mesh_cache: Dictionary = {}

var _active_chunks: Dictionary = {}
var _chunk_pool: Array[MeshInstance3D] = []
var _pending_chunks: Array[Vector3i] = []
var _partition = preload("res://scripts/terrain_partition.gd").new()
var _staged: Dictionary = {}
var _last_plan_position:=Vector2(INF,INF)
@export_range(3, 7) var maximum_lod: int = 6
@export_range(0.5, 3.0) var split_distance_ratio: float = 0.95
@export_range(0.1, 1.0) var merge_hysteresis: float = 0.35
var partition_revision:=0
var committed_revision:=0
var _teleport_pending:=false
var _teleport_destination:=Vector3.ZERO
var _target_chunk := Vector2i(2147483647, 2147483647)
var _terrain_material: ShaderMaterial
var _lod_materials: Dictionary={}
var _last_material_debug: int=-1
var _water: MeshInstance3D
var profile_streaming := false
var streaming_records: Array[Dictionary] = []
var _queued_at: Dictionary = {}
var _idle_builders: Array[RefCounted] = []
var max_plan_ms:=0.0
var max_partition_swap_ms:=0.0

func _ready() -> void:
	_settings_snapshot = settings.duplicate(true) as TerrainSettings
	grass_preview = grass_preview or OS.get_cmdline_user_args().has("grass-preview")
	if grass_preview:
		_settings_snapshot.grass_coverage = 100.0
		_settings_snapshot.desert_coverage = 0.0
		_settings_snapshot.snow_coverage = 0.0
		_settings_snapshot.stone_coverage = 0.0
	RenderingServer.set_debug_generate_wireframes(true)
	_configure_noise()
	_terrain_material = preload("res://materials/terrain.tres").duplicate() as ShaderMaterial
	# Bind explicitly as well as in the resource: inspector material saves must
	# never silently turn an unbound array into white cliffs / invalid normals.
	_terrain_material.set_shader_parameter("palette_color",preload("res://materials/palette_color_roughness.res"))
	_terrain_material.set_shader_parameter("palette_normal",preload("res://materials/palette_normals.res"))
	_terrain_material.set_shader_parameter("cliff_ambient_normals",preload("res://materials/cliff_ambient_normals.tres"))
	_terrain_material.set_shader_parameter("cliff_world_seed",float(world_seed))
	_terrain_material.set_shader_parameter("grass_macro",preload("res://materials/grass_macro.res"))
	_terrain_material.set_shader_parameter("meso_mask",preload("res://materials/meso_macro.res"))
	assert(_terrain_material.get_shader_parameter("palette_color").get_layers()==9)
	assert(_terrain_material.get_shader_parameter("palette_normal").get_layers()==9)
	_terrain_material.set_shader_parameter("water_level", water_level)
	_apply_material_settings()
	_terrain_material.set_shader_parameter("chunk_size_metres",chunk_size)
	_lod_materials[0]=_terrain_material
	for level in range(1,maximum_lod+1):
		var material:=_terrain_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("chunk_lod",float(level))
		material.set_shader_parameter("chunk_size_metres",chunk_size*float(1<<level))
		_lod_materials[level]=material
	_refresh_cliff_settings(true)
	_refresh_ground_settings(true)
	_create_water()

	if target == null:
		target = get_viewport().get_camera_3d()
	_refresh_visible_chunks()


func _process(_delta: float) -> void:
	_cliff_poll_time+=_delta
	if _cliff_poll_time>=0.5:
		_cliff_poll_time=0.0
		if auto_reload_cliff_settings and cliff_normal_settings and not cliff_normal_settings.resource_path.is_empty():
			var config_path:=cliff_normal_settings.resource_path
			var modified:=FileAccess.get_modified_time(config_path)
			if modified!=_cliff_file_time:
				var updated=ResourceLoader.load(config_path,"",ResourceLoader.CACHE_MODE_REPLACE)
				if updated is CliffNormalSettings: cliff_normal_settings=updated
				_cliff_file_time=modified
		_refresh_cliff_settings()
		_refresh_ground_settings()
	var mode: int=_terrain_material.get_shader_parameter("debug_view")
	if mode!=_last_material_debug:
		for material: ShaderMaterial in _lod_materials.values(): material.set_shader_parameter("debug_view",mode)
		_last_material_debug=mode
	if not is_instance_valid(target):
		target = get_viewport().get_camera_3d()
		if target == null:
			return

	var new_target_chunk := world_to_chunk(target.global_position)
	var moved:=Vector2(target.position.x,target.position.z).distance_to(_last_plan_position)
	if not _teleport_pending and (new_target_chunk != _target_chunk or moved>chunk_size*0.5):
		# Finish an in-progress cut instead of starving it with new plans every
		# few flight frames. A large teleport can supersede obsolete work.
		if committed_revision==partition_revision or moved>chunk_size*float(1<<maximum_lod)*0.5:
			_refresh_visible_chunks()

	_collect_jobs()
	_dispatch_jobs()


func _exit_tree() -> void:
	# Workers own their samplers and never access this node or the scene tree.
	for job: Dictionary in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(job.task)
	_jobs.clear()


func _refresh_cliff_settings(force: bool=false) -> void:
	if cliff_normal_settings==null: return
	var values:=cliff_normal_settings.uniforms()
	var signature:=cliff_normal_settings.texture_signature()
	if force or signature!=_cliff_texture_cache:
		var rebuilt:=cliff_normal_settings.build_texture_array()
		if rebuilt==null:
			push_error("Cliff normal texture array rebuild failed; previous settings retained")
			return
		_cliff_array=rebuilt
		_cliff_texture_cache=signature
		for material: ShaderMaterial in _lod_materials.values(): material.set_shader_parameter("cliff_ambient_normals",_cliff_array)
	if force or values!=_cliff_uniform_cache:
		for material: ShaderMaterial in _lod_materials.values():
			for parameter in values: material.set_shader_parameter(parameter,values[parameter])
		_cliff_uniform_cache=values
	if force and not cliff_normal_settings.resource_path.is_empty():
		_cliff_file_time=FileAccess.get_modified_time(cliff_normal_settings.resource_path)


func _refresh_ground_settings(force: bool = false) -> void:
	if ground_material_settings == null: return
	var path := ground_material_settings.resource_path
	if auto_reload_ground_settings and not path.is_empty():
		var modified := FileAccess.get_modified_time(path)
		if not force and modified != _ground_file_time:
			var updated = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
			if updated is GroundMaterialSettings: ground_material_settings = updated
		_ground_file_time = modified
	var values := ground_material_settings.uniforms()
	if force or values != _ground_uniform_cache:
		for material: ShaderMaterial in _lod_materials.values():
			for parameter in values: material.set_shader_parameter(parameter, values[parameter])
		_ground_uniform_cache = values


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.z / chunk_size)
	)


func get_loaded_chunk_count() -> int:
	return _active_chunks.size()


func cycle_debug_view() -> void:
	terrain_debug_view = (terrain_debug_view+1)%28
	_terrain_material.set_shader_parameter("debug_view",0 if terrain_debug_view==5 or terrain_debug_view>=21 else terrain_debug_view)
	for material: ShaderMaterial in _lod_materials.values():
		material.set_shader_parameter("cliff_normal_debug",terrain_debug_view-21 if terrain_debug_view>=21 else 0)
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if terrain_debug_view==5 else Viewport.DEBUG_DRAW_DISABLED


func get_debug_view_name() -> String:
	if terrain_debug_view>=21:
		return ["Cliff ambient normals: combined","Cliff base normal only / overlays off","Cliff macro normals only","Cliff medium normals only","Cliff coverage: macro red / medium green","Cliff ambient texture IDs","Cliff combined world normal"][terrain_debug_view-21]
	return ["Shaded","Material weights","Dominant material ID","Unlit albedo","Geometry normals","Wireframe","Geology: red scree / green drainage / blue cliff","Normal maps OFF","Mapped normals","Quadtree LOD / bounds","Macro grass","Exposed soil","Drainage wetness","Dryness","Cliff coverage","Fracture recess","Scree","Meso controls","Micro detail disabled","Region fields: highland / drainage / exposure","Macro only (meso and micro disabled)"][terrain_debug_view]


func get_target_chunk() -> Vector2i:
	return _target_chunk


func get_biome_name_at(world_position: Vector3) -> String:
	return BIOME_NAMES[_get_biome(world_position.x, world_position.z)]


func get_height_at(world_position: Vector3) -> float:
	return _get_height(world_position.x, world_position.z)


func get_temperature_at(world_position: Vector3) -> float:
	return _sampler.get_temperature(world_position.x, world_position.z)


func get_climate_description(world_position: Vector3) -> String:
	if not _settings_snapshot.temperature_enabled:
		return "climate OFF"
	var value := get_temperature_at(world_position)
	if value <= _settings_snapshot.snow_max_temperature:
		return "cold / snow climate"
	if value >= maxf(_settings_snapshot.desert_min_temperature,_settings_snapshot.snow_max_temperature+5.0):
		return "hot / desert climate"
	return "temperate buffer"


func _configure_noise() -> void:
	if _settings_snapshot == null:
		_settings_snapshot = settings.duplicate(true) as TerrainSettings
	_sampler = MeshBuilder.new()
	_sampler.settings = _settings_snapshot
	_sampler.water_level = water_level
	_sampler.world_seed = world_seed
	_sampler.chunk_size = chunk_size
	_sampler._configure_noise()


func _apply_material_settings() -> void:
	var config := _settings_snapshot
	_terrain_material.set_shader_parameter("tile_metres", Vector4(
		maxf(config.texture_tile_metres.x, 0.1), maxf(config.texture_tile_metres.y, 0.1),
		maxf(config.texture_tile_metres.z, 0.1), maxf(config.texture_tile_metres.w, 0.1)))
	for parameter in ["sand_tint", "normal_strength", "detail_distance", "texture_blend_sharpness", "shore_width", "shore_strength", "slope_rock_start", "slope_rock_end", "grass_roughness_floor", "grass_specular", "grass_normal_scale"]:
		_terrain_material.set_shader_parameter(parameter, config.get(parameter))


func _tile_resolution(key: Vector3i) -> int:
	if key.z==1: return maxi(32,middle_resolution)
	if key.z>0: return middle_resolution
	return maxi(chunk_resolution,close_resolution) if Vector2i(key.x,key.y)==_target_chunk else chunk_resolution


func _mesh_key(key: Vector3i) -> Vector4i:
	return Vector4i(key.x,key.y,key.z,_tile_resolution(key))


func request_teleport(destination: Vector3) -> void:
	if not destination.is_finite(): return
	_teleport_pending=true
	_teleport_destination=destination
	_refresh_visible_chunks(destination)


func _refresh_visible_chunks(destination: Vector3=Vector3.INF) -> void:
	if target==null: return
	var plan_start:=Time.get_ticks_usec()
	var point:=destination if destination.is_finite() else target.global_position
	_target_chunk=world_to_chunk(point)
	_last_plan_position=Vector2(point.x,point.z)
	_partition.base_size=chunk_size
	_partition.maximum_level=maximum_lod
	_partition.split_ratio=split_distance_ratio
	_partition.merge_ratio=split_distance_ratio+merge_hysteresis
	var plan: Dictionary=_partition.select(_last_plan_position,_wanted)
	_wanted=plan
	partition_revision+=1
	_pending_chunks.clear()
	for key: Vector3i in _staged.keys():
		if not _wanted.has(key) or int(_staged[key].get_meta("resolution"))!=_tile_resolution(key):
			_release_node(_staged[key]);_staged.erase(key)
	for key: Vector3i in _wanted:
		if _active_chunks.has(key) and int(_active_chunks[key].get_meta("resolution"))==_tile_resolution(key): continue
		if _staged.has(key) or _inflight.has(key): continue
		_pending_chunks.append(key)
	_pending_chunks.sort_custom(func(a: Vector3i,b: Vector3i) -> bool:
		return _partition.distance_to(a,_last_plan_position)<_partition.distance_to(b,_last_plan_position))
	_queued_at.clear()
	for key in _pending_chunks: _queued_at[key]=Time.get_ticks_usec()
	_update_water_position()
	if profile_streaming: max_plan_ms=maxf(max_plan_ms,(Time.get_ticks_usec()-plan_start)/1000.0)


func _dispatch_jobs() -> void:
	var started:=Time.get_ticks_usec()
	while not _pending_chunks.is_empty() and _jobs.size()<worker_count and _ready_chunks.size()<worker_count*distant_job_batch*2:
		var key: Vector3i=_pending_chunks.pop_front()
		if _inflight.has(key) or not _wanted.has(key): continue
		var cache_key:=_mesh_key(key)
		if _mesh_cache.has(cache_key):
			_stage_chunk(key,cache_key.w,_mesh_cache[cache_key])
			_mesh_cache.erase(cache_key)
		else:
			var builder: RefCounted
			if not _idle_builders.is_empty(): builder=_idle_builders.pop_back()
			else:
				builder=MeshBuilder.new()
				builder.settings=_settings_snapshot.duplicate(true)
				builder.water_level=water_level;builder.world_seed=world_seed
				builder._configure_noise()
			var batch: Array[Vector4i]=[cache_key]
			_inflight[key]=true
			while key.z>0 and batch.size()<distant_job_batch and not _pending_chunks.is_empty():
				var next: Vector3i=_pending_chunks.front()
				if next.z==0: break
				_pending_chunks.pop_front()
				if _inflight.has(next) or not _wanted.has(next): continue
				batch.append(_mesh_key(next));_inflight[next]=true
			var result: Array=[]
			var job: Dictionary={"task":-1,"result":result,"builder":builder}
			var base_size:=chunk_size
			job.task=WorkerThreadPool.add_task(func() -> void:
				for item in batch:
					var begin:=Time.get_ticks_usec()
					builder.chunk_size=base_size*float(1<<item.z)
					var arrays: Array=builder.build(Vector2i(item.x,item.y),item.w)
					result.append({"key":Vector3i(item.x,item.y,item.z),"resolution":item.w,"arrays":arrays,"begin":begin,"end":Time.get_ticks_usec()})
			)
			_jobs[key]=job
		if Time.get_ticks_usec()-started>=upload_budget_ms*1000.0: break
	_commit_partition()


func _collect_jobs() -> void:
	var started:=Time.get_ticks_usec()
	var installed:=0
	for key: Vector3i in _jobs.keys():
		var job: Dictionary=_jobs[key]
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		_idle_builders.append(job.builder);_jobs.erase(key)
		_ready_chunks.append_array(job.result)
	while not _ready_chunks.is_empty():
		var result: Dictionary=_ready_chunks.pop_front()
		var key: Vector3i=result.key
		_inflight.erase(key)
		if not _wanted.has(key): continue
		if result.resolution!=_tile_resolution(key):
			_pending_chunks.push_front(key);continue
		var commit_start:=Time.get_ticks_usec()
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.arrays,[],{},Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(0,_lod_materials[key.z])
		_stage_chunk(key,result.resolution,mesh)
		if profile_streaming:
			streaming_records.append({"lod":key.z,"resolution":result.resolution,"worker_ms":(result.end-result.begin)/1000.0,"queue_ms":(result.begin-_queued_at.get(key,result.begin))/1000.0,"commit_ms":(Time.get_ticks_usec()-commit_start)/1000.0})
			if streaming_records.size()>4096: streaming_records.pop_front()
		_queued_at.erase(key)
		installed+=1
		if installed>=chunks_created_per_frame or Time.get_ticks_usec()-started>=upload_budget_ms*1000.0: break
	_commit_partition()


func _stage_chunk(key: Vector3i,resolution: int,mesh: ArrayMesh) -> void:
	var node: MeshInstance3D
	if _chunk_pool.is_empty():
		node=MeshInstance3D.new();node.visible=false;add_child(node)
	else: node=_chunk_pool.pop_back()
	var size: float=chunk_size*float(1<<key.z)
	node.position=Vector3(key.x*size,0,key.y*size)
	node.mesh=mesh;node.visible=false
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if terrain_shadows and key.z<=1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("resolution",resolution);node.set_meta("tile",key)
	_staged[key]=node


func _release_node(node: MeshInstance3D) -> void:
	var key: Vector3i=node.get_meta("tile")
	if cached_mesh_limit>0:
		_mesh_cache[Vector4i(key.x,key.y,key.z,int(node.get_meta("resolution")))]=node.mesh
		while _mesh_cache.size()>cached_mesh_limit: _mesh_cache.erase(_mesh_cache.keys()[0])
	node.visible=false;node.mesh=null
	if _chunk_pool.size()<128: _chunk_pool.append(node)
	else: node.queue_free()


func _commit_partition() -> void:
	# Transactional cut swap: hidden replacements are prepared under the upload
	# budget. A COMPLETE balanced cut replaces the old cut in one scene update.
	# No frame renders a partially split parent or overlapping parent/children.
	if committed_revision==partition_revision: return
	for key: Vector3i in _wanted:
		if _staged.has(key): continue
		if _active_chunks.has(key) and int(_active_chunks[key].get_meta("resolution"))==_tile_resolution(key): continue
		return
	var swap_start:=Time.get_ticks_usec()
	var next: Dictionary={}
	for key: Vector3i in _wanted:
		if _staged.has(key):
			next[key]=_staged[key];_staged.erase(key)
		else: next[key]=_active_chunks[key]
	for key: Vector3i in _active_chunks:
		if not next.has(key) or next[key]!=_active_chunks[key]: _release_node(_active_chunks[key])
	for node: MeshInstance3D in next.values(): node.visible=true
	_active_chunks=next
	committed_revision=partition_revision
	if _teleport_pending:
		target.global_position=_teleport_destination
		_teleport_pending=false
		_update_water_position()
	if profile_streaming: max_partition_swap_ms=maxf(max_partition_swap_ms,(Time.get_ticks_usec()-swap_start)/1000.0)


func get_partition_debug() -> String:
	var count: Array[int]=[]
	count.resize(maximum_lod+1)
	for key: Vector3i in _active_chunks: count[key.z]+=1
	var point:=Vector2(target.position.x,target.position.z) if target!=null else Vector2.ZERO
	var detail:="awaiting coverage"
	for key: Vector3i in _active_chunks:
		var rect: Rect2=_partition.bounds(key)
		if not rect.has_point(point): continue
		detail="active L%d (%d,%d) bounds %s parent %s children %d" % [key.z,key.x,key.y,str(rect),str(_partition.parent(key)),4 if key.z>0 else 0]
		break
	return "LOD counts %s | staging %d jobs %d | cut %d/%d\n%s" % [str(count),_staged.size(),_jobs.size(),committed_revision,partition_revision,detail]


func _biome_weights(x: float, z: float) -> Vector4:
	return _sampler._biome_weights(x, z)


func _get_height(x: float, z: float) -> float:
	return _sampler._get_height(x, z)


func _get_biome(world_x: float, world_z: float) -> int:
	var weights := _biome_weights(world_x, world_z)
	var strongest := 0
	for i in range(1, 4):
		if weights[i] > weights[strongest]:
			strongest = i
	return strongest


func _create_water() -> void:
	if not _settings_snapshot.water_enabled:
		return
	_water = MeshInstance3D.new()
	_water.name = "InfiniteWater"
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	var water_span := chunk_size * float(1<<maximum_lod) * 5.0
	plane.size = Vector2(water_span, water_span)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://shaders/ocean.gdshader")
	for parameter in ["wave_height", "wave_speed", "water_roughness", "shallow_color", "deep_color"]:
		water_material.set_shader_parameter(parameter, _settings_snapshot.get(parameter))
	plane.material = water_material
	_water.mesh = plane
	add_child(_water)


func _update_water_position() -> void:
	if _water == null or _teleport_pending:
		return
	_water.position = Vector3(
		(_target_chunk.x + 0.5) * chunk_size,
		water_level,
		(_target_chunk.y + 0.5) * chunk_size
	)
