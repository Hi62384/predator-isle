extends Node3D
## Sparse cave backend sharing the host terrain's TOTAL worker allowance.
## Surface transactions are installed separately; closed terrain is retained
## until its complete corresponding portal replacement is ready.
const Workload=preload("res://scripts/caves/workload.gd")
const REGION:float=1536
const SurfaceRenderer=preload("res://scripts/caves/surface_renderer.gd")
const SurfaceTransaction=preload("res://scripts/caves/surface_transaction.gd")
const SurfaceBatch=preload("res://scripts/csharp/caves/SurfaceBatch.cs")
const WaterRenderer=preload("res://scripts/caves/water_renderer.gd")
const Palette=preload("res://scripts/caves/material_palette.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
const BiomeRegions=preload("res://scripts/caves/biome_regions.gd")
const BiomeMaterials=preload("res://scripts/caves/biome_materials.gd")
const FeatureRenderer=preload("res://scripts/caves/feature_renderer.gd")
var TraversalEnvelope=preload("res://scripts/csharp/caves/TraversalEnvelope.cs").new()
var SurfacePolicy=preload("res://scripts/csharp/caves/SurfaceStreamingPolicy.cs").new()
var host
var configuration
var _jobs:Dictionary={}
var _idle:Array=[]
var _ready:Array=[]
var _cells:Dictionary={}
var _wanted:Dictionary={}
var _pending:Array[Vector3i]=[]
var _inflight:Dictionary={}
var _bundle:Dictionary={}
var _region:=Vector2i(2147483647,2147483647)
var _generation:int=0
var _discovery_pending:bool=false
var _last_plan:=Vector3.INF
var _materials:Dictionary={}
var last_error:String=""
var surface_status:String="awaiting discovery"
var _surface_transaction
var _surface_snapshot:Dictionary={}
var _surface_owned:Dictionary={}
var _surface_request:Dictionary={}
var _surface_staging:Dictionary={}
var _surface_prepared
var _surface_build_pending:bool=false
var _surface_batch
var _surface_serial:int=0
var _surface_columns:Dictionary={}
var _surface_interest:=Vector3.ZERO
var _rebuild_nodes:Array=[]
var _rebuild_columns:Dictionary={}
var _protected_point:=Vector3.ZERO
var _surface_poll_usec:int=0
var _close_surface_on_partition:bool=false
var _detail_columns:Dictionary={}
var _frontiers_dirty:bool=false
var _biome_debug:String=""
var _biome_runtime_controllers:Array=[]
func initialize(terrain_node)->void:
	host=terrain_node;configuration=host.cave_settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	configure_biome_runtime()
func configure_biome_runtime()->void:
	for controller in _biome_runtime_controllers:controller.release()
	_biome_runtime_controllers.clear()
	if configuration==null or not configuration.enabled or not configuration.biome_regions.enabled:return
	for definition:Resource in configuration.biome_regions.definitions:
		if not definition.enabled or definition.spawn_chance_percent<=0 or definition.surface_provider==null:continue
		var provider=definition.surface_provider.new()
		if not provider.has_method("create_runtime_controller"):continue
		var controller=provider.create_runtime_controller(definition.material_configuration)
		if controller!=null:_biome_runtime_controllers.append(controller)
func job_count()->int:return _jobs.size()
func worker():
	if not _idle.is_empty():return _idle.pop_back()
	var work=Workload.new()
	if not work.configure(host._settings_snapshot,configuration,host.world_seed,host.water_level):return null
	return work
static func dispatch_allowance(terrain_free_slots:int,cave_jobs:int,terrain_waiting:bool,total_workers:int=4)->int:
	var free:int=maxi(0,terrain_free_slots-cave_jobs)
	# The reservation is a TOTAL concurrent cave-job limit, not one new cave
	# job each frame. Replenishing four existing cave jobs starved near terrain.
	var reserved_caves:int=1 if total_workers>1 else 0
	return mini(free,maxi(0,reserved_caves-cave_jobs)) if terrain_waiting else free
func tick(point:Vector3,protected_point:Vector3,terrain_free_slots:int,terrain_waiting:bool)->void:
	_protected_point=protected_point;collect();var cell:=Vector2i(floori(point.x/REGION),floori(point.z/REGION))
	for controller in _biome_runtime_controllers:controller.update(self,protected_point)
	if cell!=_region:
		clear_surface_staging();_surface_request={};_surface_batch=null;_surface_build_pending=false;_rebuild_nodes=[];_rebuild_columns={}
		_region=cell;_generation+=1;_bundle={};_wanted.clear();_pending.clear();_ready.clear();_last_plan=Vector3.INF;_discovery_pending=true
	if not _bundle.is_empty():
		if not _last_plan.is_finite() or _last_plan.distance_to(point)>=16:plan(point,protected_point)
		elif _pending.is_empty():refill_pending()
	if host.has_method("_commit_partition"):service_surface(point)
	if _surface_batch==null and not _surface_request.is_empty():
		_surface_serial+=1;var batch=SurfaceBatch.new()
		if batch.configure(_surface_serial,_generation,_surface_request):_surface_batch=batch;_surface_build_pending=true
		else:surface_status="Invalid bounded surface batch"
		_surface_request={}
	var allowance:int=dispatch_allowance(terrain_free_slots,_jobs.size(),terrain_waiting,host.worker_count)
	while allowance>0 and _ready.size()<8:
		var work=worker()
		if work==null:last_error="Invalid cave worker configuration";return
		var result:Array=[];var generation:int=_generation;var job:Dictionary={"work":work,"result":result,"generation":generation,"kind":"discovery" if _discovery_pending else "mesh"};var task:int=-1
		if _discovery_pending:
			_discovery_pending=false;var region:Vector2i=_region
			task=WorkerThreadPool.add_task(func()->void:result.append(work.discover(region)))
		elif _surface_batch!=null and _surface_batch.pending():
			var part:Dictionary=_surface_batch.take();job.kind="portal";job["batch_id"]=part.batch_id;job["part"]=part.part;var bundle:Dictionary=_bundle;var columns:Dictionary=_surface_batch.request.columns;var parents:Array=_surface_batch.request.snapshot.records;var owned:Dictionary=part.columns;var ground:bool=part.part==0
			task=WorkerThreadPool.add_task(func()->void:result.append(work.portal(bundle,columns,parents,owned,ground)))
		elif not _pending.is_empty() and not _bundle.is_empty():
			var key:Vector3i=_pending.pop_front();var bundle:Dictionary=_bundle;job["key"]=key;_inflight[key]=generation
			task=WorkerThreadPool.add_task(func()->void:result.append(work.build_cell(key) if work.use_bundle(bundle) else {"key":key,"arrays":[],"valid":false}))
		else:_idle.append(work);break
		_jobs[task]=job;allowance-=1
func collect()->void:
	for task:int in _jobs.keys():
		if not WorkerThreadPool.is_task_completed(task):continue
		WorkerThreadPool.wait_for_task_completion(task);var job:Dictionary=_jobs[task];_jobs.erase(task);_idle.append(job.work)
		if job.kind=="mesh" and _inflight.get(job.key,-1)==job.generation:_inflight.erase(job.key)
		if job.generation!=_generation or job.result.is_empty():continue
		if job.kind=="discovery":
			var bundle:Dictionary=job.result[0]
			if bundle.has("error"):last_error=bundle.error;continue
			_bundle=bundle;_last_plan=Vector3.INF;_biome_debug=BiomeRegions.description(bundle.get("cave_biome_regions",{}))
		elif job.kind=="portal":
			if _surface_batch==null or job.batch_id!=_surface_batch.id:continue
			_surface_batch.accept(job.batch_id,job.generation,job.part,job.result[0])
			if not _surface_batch.failure.is_empty():surface_status=_surface_batch.failure;_surface_batch=null;_surface_build_pending=false;continue
			if _surface_batch.complete():
				var data:Dictionary=_surface_batch.assemble();var request:Dictionary=_surface_batch.request;_surface_batch=null;_surface_build_pending=false
				if data.get("valid",false):_surface_staging={"request":request,"data":data,"remaining":data.cells.duplicate(),"nodes":[]}
				else:surface_status=data.get("reason","Portal extraction failed")
		else:_ready.append(job.result[0])
	var begin:int=Time.get_ticks_usec()
	while not _ready.is_empty():
		var data:Dictionary=_ready.pop_front();var key:Vector3i=data.key
		if not _wanted.has(key) or _cells.has(key):continue
		if not data.valid:last_error="Cave worker field compilation rejected";continue
		var interior:ShaderMaterial=material_for(key,data.get("biome_ids",[]))
		if interior==null:last_error="Cave biome material rejected";continue
		var node:MeshInstance3D=null
		if not data.arrays.is_empty():
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.arrays);mesh.surface_set_material(0,interior);node=MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(key)*64;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if host.get("terrain_shadows")!=false else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_mask=0;body.collision_layer=1 if host.get("terrain_collision_enabled")!=false else 0;var shape_node:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(data.arrays[Mesh.ARRAY_VERTEX]);shape_node.shape=shape;body.add_child(shape_node);node.add_child(body);add_child(node)
			WaterRenderer.attach(node,data.get("water",{}),configuration.common_vertex_projection)
		elif not data.get("frontiers",{}).is_empty() or not data.get("features",[]).is_empty():
			node=MeshInstance3D.new();node.position=Vector3(key)*64;var body:=StaticBody3D.new();body.name="CaveCollision";body.collision_layer=1 if not data.get("features",[]).is_empty() and host.get("terrain_collision_enabled")!=false else 0;body.collision_mask=0;node.add_child(body);add_child(node)
		if node!=null:
			if not FeatureRenderer.attach(node,data.get("features",[]),configuration.biome_regions,configuration.common_vertex_projection,host.get("terrain_shadows")!=false):node.free();last_error="Cave biome feature material rejected";continue
			Frontiers.attach(node,data.get("frontiers",{}),interior,host.get("terrain_shadows")!=false)
		_cells[key]=node
		_frontiers_dirty=true
		if Time.get_ticks_usec()-begin>=host.upload_budget_ms*1000:break
	refresh_frontiers()
func refresh_frontiers()->void:
	if not _frontiers_dirty:return
	Frontiers.synchronize(_cells,host.get("terrain_collision_enabled")!=false);_frontiers_dirty=false
func plan(point:Vector3,protected_point:Vector3)->void:
	_last_plan=point;var ranked:Array=[]
	for key:Vector3i in _bundle.get("cells",[]):
		var origin:Vector3=Vector3(key)*64;var distance:float=point.distance_to(point.clamp(origin,origin+Vector3.ONE*64))
		if distance<=configuration.preload_radius_metres:ranked.append({"key":key,"distance":distance})
	ranked.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance);_wanted.clear()
	for record:Dictionary in ranked.slice(0,configuration.resident_cell_limit):_wanted[record.key]=true
	_pending.clear();refill_pending()
	for key:Vector3i in _cells.keys():
		if _wanted.has(key) or _surface_owned.has(key):continue
		var origin:Vector3=Vector3(key)*64
		if protected_point.distance_to(protected_point.clamp(origin,origin+Vector3.ONE*64))<=96:continue
		var node:MeshInstance3D=_cells[key]
		if is_instance_valid(node):node.get_node("CaveCollision").collision_layer=0;node.queue_free()
		_cells.erase(key)
		_frontiers_dirty=true
	refresh_frontiers()
func refill_pending()->void:
	# Preserve the current near-first selection. Waiting on an upload is NOT
	# unsubmitted work,and stationary queue refill must not sort thousands of
	# regional cells every frame while the last few workers are still busy.
	var completed:Dictionary={}
	for data:Dictionary in _ready:completed[data.key]=true
	for key:Vector3i in _wanted:
		if _pending.size()>=configuration.pending_job_limit:break
		if not _cells.has(key) and not _inflight.has(key) and not completed.has(key):_pending.append(key)
func position_ready(point:Vector3=Vector3.INF)->bool:
	if point.is_finite() and (_region!=Vector2i(floori(point.x/REGION),floori(point.z/REGION)) or not _last_plan.is_finite() or _last_plan.distance_to(point)>=16):return false
	if _bundle.is_empty() or _discovery_pending:return false
	for key:Vector3i in _wanted:
		if not _cells.has(key):return false
	return true
func traversal_ready(point:Vector3)->bool:
	if configuration.seal_stream_frontiers:
		if not TraversalEnvelope.ready(point,_cells,_wanted):return false
	elif not _cells.has(Vector3i(floori(point.x/64),floori(point.y/64),floori(point.z/64))):return false
	for entrance:Dictionary in _bundle.get("entrances",[]):
		if not entrance_needed(entrance,point):continue
		if _surface_transaction==null or not _surface_transaction.committed:return false
		for column:Vector2i in entrance.columns:
			if not _surface_columns.has(column):return false
	return true
func entrance_needed(entrance:Dictionary,point:Vector3)->bool:
	# The same real three-dimensional mouth envelope governs readiness AND
	# extraction. Horizontal proximity alone used to rebuild outdoor portals
	# hundreds of metres above a walker who did not need them for support.
	return point.y>=float(entrance.get("minimum_exposed_floor",entrance.point.y))-configuration.main_route_height_metres*2 and point.distance_to(entrance.point)<=configuration.preload_radius_metres
func defer_surface_plan(point:Vector3)->bool:
	if configuration==null or not configuration.retain_deep_surface_cut or _bundle.is_empty() or not point.is_finite() or not is_instance_valid(host):return false
	var ground:float=host.get_height_at(point)
	if not SurfacePolicy.can_defer(point,ground,true,false):return false
	return nearby_columns(point).is_empty()
func material_for(key:Vector3i,biome_ids:Array=[])->ShaderMaterial:
	var region:=Vector2i(floori(float(key.x)/24),floori(float(key.z)/24));var style:int=0;var pools:Array=[];var hive_region:float=1.0
	for data:Dictionary in _bundle.get("regions",[]):
		if data.id==region:style=int(data.get("render_style",data.get("geology",0)));pools=data.get("pools",[]);hive_region=float(data.get("hive_region",1.0));break
	var cache_key=region if biome_ids.is_empty() else str(region)+"/"+str(biome_ids)
	if _materials.has(cache_key):return _materials[cache_key]
	# At most the current3x3region palette is cached; GPU images are shared.
	if _materials.size()>=16:_materials.erase(_materials.keys()[0])
	var material:=ShaderMaterial.new()
	if style==7:
		var variation:bool=true;var strength:float=.7
		if is_instance_valid(host) and host.get("_settings_snapshot")!=null:variation=host._settings_snapshot.alien_infected.nerve_material_variation;strength=host._settings_snapshot.alien_infected.normal_strength
		material.shader=load("res://shaders/hive_cave.gdshader");material.set_shader_parameter("biological_colors",load("res://materials/biological_colors_v3.tres"));material.set_shader_parameter("hive_region",hive_region);material.set_shader_parameter("alien_tissue_variation_enabled",variation);material.set_shader_parameter("normal_strength",strength)
	else:material.shader=load("res://shaders/default_cave_rock.gdshader");Palette.bind(material,style,pools,configuration==null or configuration.specialize_insect_palette)
	# ShaderMaterial does not promise a stored value for an unset/unused
	# shader default. Keep construction identity in explicit CPU metadata.
	var registry:Resource=configuration.biome_regions if configuration!=null else null
	if not biome_ids.is_empty():
		var adapted:Shader=BiomeMaterials.shader(material.shader,biome_ids,registry)
		if adapted==null:return null
		material.shader=adapted;BiomeMaterials.bind(material,biome_ids,registry,{"pools":pools,"geology":style})
	material.set_meta("biome_context",{"pools":pools,"geology":style})
	var common_projection:bool=configuration==null or configuration.common_vertex_projection;material.set_shader_parameter("cave_common_projection",common_projection);material.set_meta("cave_common_projection",common_projection);material.set_meta("cave_style",style);material.set_meta("biome_ids",biome_ids);material.set_meta("biome_registry",registry);_materials[cache_key]=material;return material
func shutdown()->void:
	for controller in _biome_runtime_controllers:controller.release()
	_biome_runtime_controllers.clear()
	for task:int in _jobs:WorkerThreadPool.wait_for_task_completion(task)
	_jobs.clear();_ready.clear();_idle.clear();_surface_batch=null;_surface_request={};_surface_build_pending=false
	if _surface_transaction!=null:_surface_transaction.reset()
	clear_surface_staging()
	Frontiers.synchronize(_cells,false)
	for node in _cells.values():
		if is_instance_valid(node):node.get_node("CaveCollision").collision_layer=0
	_cells.clear()
func active_parent_nodes()->Array:return host._active_chunks.values()
func detail_rectangles()->Array[Rect2]:
	var result:Array[Rect2]=[]
	for column:Vector2i in _detail_columns:result.append(Rect2(Vector2(column)*64,Vector2.ONE*64))
	return result
func needs_fine_surface(key:Vector3i)->bool:
	if key.z!=0:return false
	var span:float=host.chunk_size;var bounds:=Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span)
	for column:Vector2i in _detail_columns:
		if bounds.intersects(Rect2(Vector2(column)*64,Vector2.ONE*64)):return true
	return false
func reserve_detail(columns:Dictionary)->void:
	if columns==_detail_columns:return
	_detail_columns=columns.duplicate();_rebuild_nodes=[]
	# Discovery happens after the initial terrain plan. Replan once when this
	# bounded reservation changes; do not repeatedly invalidate running jobs.
	host._refresh_visible_chunks(host._teleport_destination if host._teleport_pending else Vector3.INF)
func partition_ready(nodes:Array)->bool:
	# A pending teleport can be below an exposed mouth. Its complete patch
	# must be prepared against the DESTINATION cut before moving the actor.
	# Meanwhile the actual old position keeps its original entrance floor.
	if host._teleport_pending:
		var destination_columns:Dictionary=nearby_columns(host._teleport_destination)
		if not destination_columns.is_empty():
			if _surface_transaction!=null and destination_columns==_surface_columns and SurfaceRenderer.matches(_surface_snapshot,nodes,_surface_columns):return true
			_rebuild_nodes=nodes;_rebuild_columns=destination_columns
			return _surface_prepared!=null and _surface_prepared.ready_to_commit() and _surface_staging.request.columns==destination_columns and SurfaceRenderer.matches(_surface_staging.request.snapshot,nodes,destination_columns)
		if _surface_transaction!=null:_close_surface_on_partition=true;return true
	if _surface_transaction==null:return true
	if SurfaceRenderer.matches(_surface_snapshot,nodes,_surface_columns):return true
	if surface_distance(_protected_point)>96 or host._teleport_pending:_close_surface_on_partition=true;return true
	_rebuild_nodes=nodes;_rebuild_columns=_surface_columns.duplicate()
	return _surface_prepared!=null and _surface_prepared.ready_to_commit() and SurfaceRenderer.matches(_surface_staging.request.snapshot,nodes,_surface_staging.request.columns)
func partition_committed()->void:
	if _close_surface_on_partition:close_surface();_close_surface_on_partition=false;_rebuild_nodes=[];_rebuild_columns={}
	if _surface_prepared!=null and _surface_prepared.ready_to_commit():
		if _surface_prepared.commit():adopt_surface(_surface_prepared,_surface_staging.request.snapshot,_surface_staging.data)
		_surface_prepared=null;_surface_staging={};_rebuild_nodes=[];_rebuild_columns={}
	if _surface_transaction!=null:
		for node:MeshInstance3D in active_parent_nodes():_surface_transaction.apply_node(node)
func apply_parent(node:MeshInstance3D)->void:
	if _surface_transaction!=null:_surface_transaction.apply_node(node)
func release_parent(node:MeshInstance3D)->void:
	if _surface_transaction!=null:_surface_transaction.release_node(node)
func clear_surface_staging()->void:
	for node in _surface_staging.get("nodes",[]):
		if is_instance_valid(node):node.queue_free()
	_surface_staging={};_surface_prepared=null
func surface_distance(point:Vector3)->float:
	var distance:float=INF;var p:=Vector2(point.x,point.z)
	for key:Vector2i in _surface_columns:
		var origin:Vector2=Vector2(key)*64;distance=minf(distance,p.distance_to(p.clamp(origin,origin+Vector2.ONE*64)))
	return distance
func close_surface()->void:
	if _surface_transaction!=null:_surface_transaction.reset()
	for key:Vector3i in _surface_owned:
		var node=_cells.get(key)
		if is_instance_valid(node):node.queue_free()
		_cells.erase(key)
	_surface_transaction=null;_surface_owned.clear();_surface_columns.clear();_surface_snapshot={};_last_plan=Vector3.INF;_frontiers_dirty=true;refresh_frontiers()
func nearby_columns(point:Vector3)->Dictionary:
	var columns:Dictionary={};var nearby:Array=_bundle.get("entrances",[]).duplicate()
	nearby.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return Vector2(a.point.x,a.point.z).distance_squared_to(Vector2(point.x,point.z))<Vector2(b.point.x,b.point.z).distance_squared_to(Vector2(point.x,point.z)))
	for entrance:Dictionary in nearby:
		if not entrance_needed(entrance,point):continue
		var complete:Dictionary=columns.duplicate()
		for key:Vector2i in entrance.columns:complete[key]=true
		if complete.size()<=64:columns=complete
	return columns
func service_surface(point:Vector3)->void:
	_surface_interest=point
	if not _surface_staging.is_empty():
		var request:Dictionary=_surface_staging.request;var desired:Array=_rebuild_nodes if not _rebuild_nodes.is_empty() else active_parent_nodes()
		if not SurfaceRenderer.matches(request.snapshot,desired,request.columns):clear_surface_staging();surface_status="surface parents changed; retaining old entrance";return
		if not _surface_staging.remaining.is_empty():
			var data:Dictionary=_surface_staging.remaining.pop_front();var interior:ShaderMaterial=material_for(data.key,data.get("biome_ids",[]))
			if interior==null:clear_surface_staging();surface_status="Cave biome material rejected";return
			var style:int=int(interior.get_meta("cave_style",0));var built:Dictionary=SurfaceRenderer.node(data,request.snapshot.sources,interior,style,host.terrain_shadows,configuration.specialize_insect_palette)
			if not built.valid:clear_surface_staging();surface_status=built.reason;return
			if built.node!=null:add_child(built.node);_surface_staging.nodes.append(built.node)
			SurfaceRenderer.release_uploaded_data(data)
			return
		if _surface_prepared==null:
			var transaction=SurfaceTransaction.new();transaction.collision_enabled=host.terrain_collision_enabled;transaction.common_vertex_projection=configuration.common_vertex_projection
			var nodes:Array=[]
			for source:Dictionary in request.snapshot.sources.values():nodes.append(source.node)
			if not transaction.prepare(nodes,_surface_staging.nodes,request.columns,Vector2(point.x,point.z),_surface_transaction,_surface_staging.data.ground):clear_surface_staging();surface_status="surface commit preparation rejected";return
			_surface_prepared=transaction
		if _rebuild_nodes.is_empty() and not host._teleport_pending and _surface_prepared.ready_to_commit():
			if _surface_prepared.commit():adopt_surface(_surface_prepared,request.snapshot,_surface_staging.data)
			_surface_prepared=null;_surface_staging={}
		return
	if _bundle.is_empty() or _surface_build_pending or not _surface_request.is_empty() or Time.get_ticks_usec()-_surface_poll_usec<250000:return
	_surface_poll_usec=Time.get_ticks_usec();var columns:Dictionary=nearby_columns(point)
	if not _rebuild_nodes.is_empty():columns=_rebuild_columns.duplicate()
	if columns.is_empty():
		if _surface_transaction!=null and _rebuild_nodes.is_empty():
			if host._teleport_pending:
				reserve_detail({});surface_status="active retained entrance";return
			if surface_distance(_protected_point)<=96:surface_status="active retained entrance";return
			close_surface()
		reserve_detail({})
		surface_status="no nearby admitted entrance";return
	reserve_detail(columns)
	var nodes:Array=_rebuild_nodes if not _rebuild_nodes.is_empty() else active_parent_nodes()
	if _surface_transaction!=null and columns==_surface_columns and SurfaceRenderer.matches(_surface_snapshot,nodes,columns):surface_status="active";_rebuild_nodes=[];return
	var snapshot:Dictionary=SurfaceRenderer.capture(nodes,columns)
	if not snapshot.valid:surface_status=snapshot.reason;return
	_surface_request={"snapshot":snapshot,"columns":columns};surface_status="building complete hidden entrance"
func adopt_surface(transaction,snapshot:Dictionary,data:Dictionary)->void:
	var retained:Dictionary={}
	for node:MeshInstance3D in transaction.patches:retained[node.get_meta("cave_cell")]=node
	for key:Vector3i in _surface_owned:
		var old=_cells.get(key)
		if is_instance_valid(old) and not retained.values().has(old):old.queue_free()
		if not retained.has(key):_cells.erase(key)
	_surface_owned.clear()
	for result:Dictionary in data.cells:
		var key:Vector3i=result.key;var node=retained.get(key);var old=_cells.get(key)
		if is_instance_valid(old) and old!=node:old.visible=false;old.get_node("CaveCollision").collision_layer=0;old.queue_free()
		_cells[key]=node;_surface_owned[key]=true
	_surface_transaction=transaction;_surface_columns=data.columns.duplicate();_surface_snapshot=snapshot;_last_plan=Vector3.INF;surface_status="active";_frontiers_dirty=true;refresh_frontiers()
func surface_materials()->Array:
	var result:Array=[]
	if _surface_transaction!=null:
		result.append_array(_surface_transaction.materials())
		for node:MeshInstance3D in _surface_transaction.patches:
			if is_instance_valid(node):
				for i in range(node.mesh.get_surface_count()):result.append(node.mesh.surface_get_material(i))
	return result
func debug_text()->String:return "Shared caves: %d/%d cells, %d jobs; entrance %s\n%s"%[_cells.size(),_wanted.size(),_jobs.size(),surface_status,_biome_debug]
