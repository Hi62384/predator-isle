extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_carapace_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/profile_carapace.gd","res://tools/biome_extensions/artifacts/check_carapace_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var admission=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_carapace_admission.json"));check(admission.passed and admission.cases.size()==6,"Valid actual admission fixtures")
	var records:Array=[];var deltas:Array=[];var total:float=0
	for item:Dictionary in admission.cases:
		for repeat in range(3):
			var pair:Dictionary={}
			for enabled:bool in ([false,true] if repeat%2==0 else [true,false]):
				var b=make_builder(7,int(item.seed));b.settings.alien_infected.hive_carapace_frequency=.18 if enabled else 0;b._configure_noise()
				var p:=Vector2(item.position[0],item.position[1]);var coordinate:=Vector2i(floori(p.x/256),floori(p.y/256));b.chunk_size=256
				var start:int=Time.get_ticks_usec();var arrays:Array=build_structures(b,coordinate);var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
				var vertices:int=0
				for surface in arrays:
					if surface!=null:vertices+=surface[Mesh.ARRAY_VERTEX].size()
				pair[enabled]={"cpu_ms":elapsed,"vertices":vertices}
				records.append({"seed":item.seed,"habit":item.habit,"repeat":repeat,"carapace":enabled,"cpu_ms":elapsed,"triangles":vertices/3,"numeric_array_bytes":vertices*48})
			check(pair[true].vertices-pair[false].vertices==18000,"Exactly one 6000-triangle plate complex in paired build")
			var delta:float=pair[true].cpu_ms-pair[false].cpu_ms;deltas.append(delta);total+=delta
	deltas.sort();var summary:Dictionary={"paired_carapace_overhead_ms":{"median":deltas[deltas.size()/2],"mean":total/deltas.size(),"minimum":deltas[0],"maximum":deltas[-1],"pairs":deltas.size()},"additional_triangles_per_complex":6000,"additional_numeric_array_bytes_per_complex":864000}
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable benchmark source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_carapace.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"records":records,"summary":summary,"source_sha256":hashes,"scope":"Six actual default-rarity hardened/dormant sites, three alternating paired repetitions, cold per-candidate builders, same 256m owner leaf and complete network geometry. Normal cavity guards retained. Numeric generation only, not native worker/streaming/GPU/physics timing. Negative individual deltas are measurement noise."},"  "))
	print("CARAPACE_CPU ",summary);quit(0 if failures.is_empty() else 1)
