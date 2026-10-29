extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var selected_workers:int=4;var poll_ms:int=1
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("workers="):selected_workers=int(argument.trim_prefix("workers="))
		if argument.begins_with("poll="):poll_ms=int(argument.trim_prefix("poll="))
	check(selected_workers in [4,6],"Only existing supported four/six-worker concurrency controls")
	check(poll_ms in [1,8,16],"Declared headless-only preload polling yields")
	var suffix:String="_workers_"+str(selected_workers)+"_poll_"+str(poll_ms)
	var hashes:Dictionary={}
	for source:String in ["res://scenes/main.tscn","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_collision.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/alien_infected_sampler.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_carapace_geometry.gd","res://tools/biome_extensions/probe_dense_custom_preload.gd","res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"]:hashes[source]=FileAccess.get_sha256(source)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"));check(admission.passed,"Actual default-admission manifest")
	var item:Dictionary={}
	for site:Dictionary in admission.cases:
		if int(site.seed)==92881 and float(site.feature_scale)==.2:item=site
	check(not item.is_empty(),"Required dense minimum-scale failing site")
	var scene=load("res://scenes/main.tscn").instantiate();var terrain=scene.get_node("Terrain");scene.get_node("FreeCamera").set_script(null)
	var walker:=CharacterBody3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;var shape:=CollisionShape3D.new();shape.shape=capsule;walker.add_child(shape);root.add_child(walker);walker.set_physics_process(false)
	terrain.world_seed=int(item.seed);terrain.extension_preview="alien_infected";terrain.extension_preview_position=Vector2(item.position[0],item.position[1]);terrain.target=walker
	terrain.settings=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);terrain.settings.alien_infected.feature_scale=.2;terrain.profile_streaming=true;terrain.worker_count=selected_workers
	var started:int=Time.get_ticks_msec();root.add_child(scene);scene.get_node("Interface").hide()
	var records:Array=[];var last:int=0
	while terrain.committed_revision!=terrain.partition_revision and Time.get_ticks_msec()-started<175000:
		await process_frame;OS.delay_msec(poll_ms)
		var elapsed:int=Time.get_ticks_msec()-started
		if elapsed-last<2000:continue
		last=elapsed;var jobs:Array=[]
		for key:Vector3i in terrain._jobs:jobs.append({"key":key,"completed":WorkerThreadPool.is_task_completed(terrain._jobs[key].task)})
		var row:Dictionary={"elapsed_ms":elapsed,"target":walker.position,"cut":terrain.committed_revision,"wanted_revision":terrain.partition_revision,"wanted":terrain._wanted.size(),"pending":terrain._pending_chunks.size(),"ready":terrain._ready_chunks.size(),"staged":terrain._staged.size(),"active":terrain._active_chunks.size(),"jobs":jobs,"installed_records":terrain.streaming_records.size()}
		records.append(row);print("DENSE_PRELOAD_PROGRESS ",row)
		# Save diagnostic progress before any later timeout; never call an
		# incomplete cut a success or read a mutable live worker result.
		FileAccess.open("res://tools/biome_extensions/artifacts/probe_dense_custom_preload_progress"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":false,"diagnostic_only":true,"workers":selected_workers,"headless_preload_poll_ms":poll_ms,"records":records,"source_sha256":hashes,"scope":"Incomplete first-cut progress, not acceptance. Live builder/results are never inspected."},"  "))
	var complete:bool=terrain.committed_revision==terrain.partition_revision;check(complete,"Complete original full-hierarchy dense cut within unchanged preload budget")
	for source:String in hashes:check(FileAccess.get_sha256(source)==hashes[source],"Stable diagnostic source "+source)
	check(terrain.maximum_lod==6 and terrain._active_chunks.size()==terrain._wanted.size() if complete else true,"Full configured hierarchy retained")
	var fill_elapsed_ms:int=Time.get_ticks_msec()-started
	var collision_hashes:Dictionary={}
	if complete:
		for key:Vector3i in terrain._active_chunks:
			var node:MeshInstance3D=terrain._active_chunks[key];var data:Dictionary=node.mesh.get_meta("collision_data");var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(data));collision_hashes[str(key)]=hash.finish().hex_encode()
	FileAccess.open("res://tools/biome_extensions/artifacts/probe_dense_custom_preload"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"completed":complete,"workers":selected_workers,"headless_preload_poll_ms":poll_ms,"cpu_logical_count":OS.get_processor_count(),"elapsed_ms":fill_elapsed_ms,"maximum_lod":terrain.maximum_lod,"leaf_collision_payload_sha256":collision_hashes,"records":records,"installed":terrain.streaming_records,"source_sha256":hashes,"scope":"Single fresh-engine first-cut diagnostic at actual seed92881 default-rarity scale0.2 site, existing public four/six worker control, declared headless-only preload polling yield, 175s cap below original 180s walk timeout. No geometry/view/rarity/timeout changes, native capsule motion, art or uninterrupted performance acceptance. Completed leaf numeric collision payloads hashed after timing."},"  "))
	print("DENSE_PRELOAD_COMPLETE ",complete," elapsed_ms=",Time.get_ticks_msec()-started);scene.queue_free();walker.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
