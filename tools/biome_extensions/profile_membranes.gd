extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://tools/biome_extensions/profile_membranes.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));check(admission.passed,"Current real default-admitted junction identities")
	var records:Array=[];var deltas:Array=[];var total:float=0
	for item:Dictionary in admission.cases:
		for repeat in range(6):
			var pair:Dictionary={}
			for enabled:bool in ([false,true] if repeat%2==0 else [true,false]):
				var b=make_builder(7,int(item.seed));b.settings.alien_infected.hive_membrane_frequency=1 if enabled else 0;b._configure_noise();b.chunk_size=256
				var p:=Vector2(item.position[0],item.position[1]);var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256))
				var started:int=Time.get_ticks_usec();var arrays:Array=build_structures(b,coordinate);var elapsed:float=(Time.get_ticks_usec()-started)/1000.0;var vertices:int=0
				for surface in arrays:
					if surface!=null:vertices+=surface[Mesh.ARRAY_VERTEX].size()
				pair[enabled]={"cpu_ms":elapsed,"vertices":vertices};records.append({"seed":item.seed,"repeat":repeat,"membrane":enabled,"numeric_structure_ms":elapsed,"vertices":vertices,"triangles":vertices/3,"numeric_array_bytes":vertices*48,"normal_cavity_guards":true})
			check(pair[true].vertices-pair[false].vertices==5136,"Actual complete membrane increment at every paired fixture")
			var delta:float=pair[true].cpu_ms-pair[false].cpu_ms;deltas.append(delta);total+=delta
	deltas.sort()
	var summary:Dictionary={"pairs":deltas.size(),"paired_numeric_membrane_overhead_ms":{"median":deltas[deltas.size()/2],"mean":total/deltas.size(),"minimum":deltas[0],"maximum":deltas[-1]},"added_triangles_per_membrane":1712,"added_numeric_array_bytes_per_membrane":246528}
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable production membrane profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_membranes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"summary":summary,"source_sha256":hashes,"scope":"Eighteen serial alternating cold-builder full/zero-membrane pairs at three actual default junction identities with normal cavity guards. Actual complete production numeric structures; added wall geometry CPU/POD cost, not a speed gain, worker frame/GPU timing, process-start measurement or general streaming certificate. Default membrane occurrence remains independently conditional, not forced-on globally."},"  "))
	print("MEMBRANES_PROFILE ",summary," failures=",failures);quit(0 if failures.is_empty() else 1)
