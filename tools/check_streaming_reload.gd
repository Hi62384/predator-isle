extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	var camera=scene.get_node("FreeCamera")
	var terrain=scene.get_node("Terrain")
	camera.set_process(false)
	var original_hash:=0
	for position in [Vector3(0,45,70),Vector3(18000,400,-7000),Vector3(0,45,70),Vector3(-14000,400,11000),Vector3(0,45,70)]:
		camera.position=position
		terrain._refresh_visible_chunks()
		var started:=Time.get_ticks_msec()
		while not terrain._pending_chunks.is_empty() or not terrain._jobs.is_empty() or not terrain._ready_chunks.is_empty():
			await process_frame
			assert(terrain._jobs.size()<=terrain.worker_count)
			assert(terrain._ready_chunks.size()<=terrain.worker_count*terrain.distant_job_batch*3)
			if Time.get_ticks_msec()-started>60000:
				push_error("Reload timed out")
				quit(1)
				return
		assert(terrain.get_loaded_chunk_count()==terrain._wanted.size() and terrain.committed_revision==terrain.partition_revision)
		assert(terrain._inflight.is_empty())
		assert(terrain._mesh_cache.size()<=terrain.cached_mesh_limit)
		assert(terrain._idle_builders.size()<=terrain.worker_count)
		for builder in terrain._idle_builders: assert(builder._height_grid_cache.size()<=8192)
		if position.x==0:
			var data: Array=terrain._active_chunks[Vector3i.ZERO].mesh.surface_get_arrays(0)
			var hash_value: int=hash(data[Mesh.ARRAY_VERTEX].to_byte_array())
			if original_hash==0: original_hash=hash_value
			else: assert(original_hash==hash_value,"Reload changed vertex bytes")
		print("RELOAD ",position," chunks=",terrain.get_loaded_chunk_count()," ms=",Time.get_ticks_msec()-started)
	print("PASS repeated unload/reload, byte-identical origin, bounded worker and mesh pools")
	scene.queue_free()
	await process_frame
	quit()
