extends "res://scripts/chunk_terrain.gd"
## Private worker-producer trial; no production registration or scene-file edit.
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
				builder.settings=_settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
				builder.water_level=water_level;builder.world_seed=world_seed
				builder._configure_noise()
			var batch: Array[Vector4i]=[cache_key]
			var sampling_work: int=_estimated_sampling_work(cache_key)
			_inflight[key]=true
			while key.z>0 and batch.size()<distant_job_batch and not _pending_chunks.is_empty():
				var next: Vector3i=_pending_chunks.front()
				if next.z==0: break
				var next_key: Vector4i=_mesh_key(next)
				var next_work: int=_estimated_sampling_work(next_key)
				if sampling_work+next_work>4096:break
				_pending_chunks.pop_front()
				if _inflight.has(next) or not _wanted.has(next): continue
				batch.append(next_key);_inflight[next]=true
				sampling_work+=next_work
			var result: Array=[]
			var job: Dictionary={"task":-1,"result":result,"builder":builder}
			var base_size:=chunk_size
			var support_steps:PackedFloat64Array=preload("res://scripts/biome_extension_structures.gd").support_grids(base_size,close_resolution,middle_resolution,maximum_lod)
			job.task=WorkerThreadPool.add_task(func() -> void:
				for item in batch:
					var begin:=Time.get_ticks_usec()
					builder.chunk_size=base_size*float(1<<item.z)
					var arrays: Array=builder.build(Vector2i(item.x,item.y),item.w)
					var has_features:bool=builder._extras_enabled or (builder._tropical!=null and builder.settings.tropical.waterfall_frequency>0 and builder.settings.water_enabled)
					var feature_mesher=preload("res://scripts/terrain_feature_meshes.gd").new()
					var features:Dictionary=feature_mesher.build(builder,Vector2i(item.x,item.y)) if has_features else {}
					if item.z<=1 and not features.is_empty() and not features.openings.is_empty():features["ground_collision"]=preload("res://scripts/terrain_collision.gd").clipped_ground(arrays,features.openings,item.w)
					var structures:Array=preload("res://tools/biome_extensions/far_conduit_lod_candidate.gd").new().build(builder,Vector2i(item.x,item.y),support_steps,feature_mesher.portal_sites) if builder._extras_enabled else []
					var collision_data:Dictionary=preload("res://scripts/terrain_collision.gd").prepare(arrays,item.w,item.z<=1,structures,features)
					result.append({"key":Vector3i(item.x,item.y,item.z),"resolution":item.w,"arrays":arrays,"swamp_water":builder.build_swamp_water(arrays,item.w),"extension_data":builder.built_extension_data,"extension_rows":builder.built_extension_rows,"extension_mask":builder.built_extension_mask,"badlands_palette_slot":builder.built_badlands_palette_slot,"structures":structures,"features":features,"collision_data":collision_data,"begin":begin,"end":Time.get_ticks_usec()})
			)
			_jobs[key]=job
		if Time.get_ticks_usec()-started>=upload_budget_ms*1000.0: break
	_commit_partition()
