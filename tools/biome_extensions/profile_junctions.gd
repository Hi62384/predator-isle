extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={}
	hashes["res://scripts/alien_membrane_geometry.gd"]=FileAccess.get_sha256("res://scripts/alien_membrane_geometry.gd")
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/profile_junctions.gd","res://tools/biome_extensions/artifacts/check_junction_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_admission.json"));check(admission.passed,"Valid actual admission fixtures")
	var records:Array=[]
	for item:Dictionary in admission.cases:
		for repeat in range(3):
			for enabled:bool in ([false,true] if repeat%2==0 else [true,false]):
				var b=make_builder(7,int(item.seed));b.settings.alien_infected.caves_enabled=false;b.settings.alien_infected.hive_carapace_frequency=0;b.settings.alien_infected.hive_junction_frequency=.12 if enabled else 0;b._configure_noise()
				var p:=Vector2(item.position[0],item.position[1]);var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256));b.chunk_size=256
				var start:int=Time.get_ticks_usec();var arrays:Array=build_structures(b,coordinate);var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
				var vertices:int=0
				for surface in arrays:
					if surface!=null:vertices+=surface[Mesh.ARRAY_VERTEX].size()
				records.append({"seed":item.seed,"repeat":repeat,"junction":enabled,"cpu_ms":elapsed,"triangles":vertices/3,"numeric_array_bytes":vertices*48})
	var summary:Dictionary={}
	for enabled:bool in [false,true]:
		var times:Array=[]
		for record:Dictionary in records:
			if record.junction==enabled:times.append(record.cpu_ms)
		times.sort();summary["junction_and_network" if enabled else "network_only"]={"median_cpu_ms":times[times.size()/2],"min_cpu_ms":times[0],"max_cpu_ms":times[-1],"runs":times.size()}
	var deltas:Array=[];var total_delta:float=0
	for record:Dictionary in records:
		if not record.junction:continue
		for baseline:Dictionary in records:
			if not baseline.junction and baseline.seed==record.seed and baseline.repeat==record.repeat:
				var delta:float=record.cpu_ms-baseline.cpu_ms;deltas.append(delta);total_delta+=delta;break
	deltas.sort();summary["paired_junction_overhead_ms"]={"median":deltas[deltas.size()/2],"mean":total_delta/deltas.size(),"minimum":deltas[0],"maximum":deltas[-1],"pairs":deltas.size(),"note":"Individual negative timing deltas are measurement noise, not free geometry."}
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable benchmark source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_junctions.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"records":records,"summary":summary,"source_sha256":hashes,"scope":"Three actual default-rarity junction sites, three alternating paired repetitions, cold per-candidate builders, same 256m owner leaf and complete network geometry. Cavities and carapace additions disabled equally in both candidates to isolate junction cost. Numeric geometry cost only, not production worker/streaming/GPU/physics timings."},"  "))
	print("JUNCTION_CPU ",summary);quit(0 if failures.is_empty() else 1)
