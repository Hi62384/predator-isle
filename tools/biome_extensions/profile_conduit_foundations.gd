extends "res://tools/biome_extensions/check_all.gd"
## Paired cold-builder CPU measurements. Not an end-to-end streaming benchmark.
const Legacy=preload("res://tools/biome_extensions/reference_pre_footing_structures.gd")
const NoEdgeCache=preload("res://tools/biome_extensions/reference_pre_edge_cache_alien_sampler.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/reference_pre_footing_structures.gd","res://tools/biome_extensions/reference_pre_edge_cache_alien_sampler.gd","res://tools/biome_extensions/profile_conduit_foundations.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[]
	for seed_id:int in [73921,17,92881]:
		for repeat in range(3):
			# Rotate order; each candidate owns a fresh builder. Mode 1 keeps
			# identical attached geometry but uses the pre-cache sampler.
			for index in range(3):
				var mode:int=(index+repeat)%3;var enabled:bool=mode!=0
				var b=make_builder(7,seed_id)
				if mode==1:
					b._extras[7]=NoEdgeCache.new();b._extras[7].configure(b.settings.alien_infected,seed_id,b,7)
				var field=b._extras[7]
				var a:Vector2=field.hive_node(Vector2i(-12,-11));var end:Vector2=field.hive_node(Vector2i(-11,-11))
				var g=Structures.new() if enabled else Legacy.new();g.origin=Vector3(a.x,0,a.y)
				if enabled:g._support_steps=Structures.support_grids()
				var start:int=Time.get_ticks_usec()
				g.conduit(b,a,end,20,.4,Color(.34,.28,.26))
				var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
				check(not g.vertices.is_empty(),"Measured actual conduit output")
				records.append({"seed":seed_id,"repeat":repeat,"foundations":enabled,"edge_cache":mode!=1,"cpu_ms":elapsed,"triangles":g.vertices.size()/3,"numeric_array_bytes":g.vertices.size()*(12+12+16+8),"support_cache_entries":g._support_heights.size() if enabled else 0})
				print("CONDUIT_CPU ",records.back())
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	var summary:Dictionary={}
	for mode in range(3):
		var times:Array=[]
		for record:Dictionary in records:
			if record.foundations==(mode!=0) and record.edge_cache==(mode!=1):times.append(record.cpu_ms)
		times.sort();summary[["legacy","attached_uncached_edges","attached"][mode]]={"median_cpu_ms":times[times.size()/2],"minimum_cpu_ms":times[0],"maximum_cpu_ms":times[-1],"runs":times.size()}
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_conduit_foundations.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"records":records,"summary":summary,"source_sha256":hashes,"scope":"Three seeds, three rotated paired repetitions, fresh per-candidate builders, same real conduit endpoints. Attached candidates use identical geometry with cached/reference path construction. Includes numeric sampling/geometry, excludes Resource creation, protected-site enumeration, workers, streaming, GPU, collision and cold shader compilation."},"  "))
	print("CONDUIT_CPU_SUMMARY ",summary);quit(0 if failures.is_empty() else 1)
