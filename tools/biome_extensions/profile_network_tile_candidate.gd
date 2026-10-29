extends "res://tools/biome_extensions/check_network_tile_candidate.gd"
var profile_basename:String="profile_network_tile_candidate"
var profile_guards:Array[String]=[]
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/network_tile_candidate.gd","res://tools/biome_extensions/check_network_tile_candidate.gd","res://tools/biome_extensions/profile_network_tile_candidate.gd"]:hashes[path]=FileAccess.get_sha256(path)
	for path:String in profile_guards+["res://scripts/biome_extension_settings.gd","res://tools/biome_extensions/reference_pre_network_tiles_alien_sampler.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[];var summary:Array=[]
	for kind:String in ["near_dense","regional","far_sparse","random_queries"]:
		var ratios:Array=[]
		for seed_id:int in [73921,17,92881]:
			for repeat in range(3):
				var times:Dictionary={};var outputs:Dictionary={}
				for accelerated:bool in ([false,true] if repeat%2==0 else [true,false]):
					var b=candidate_builder(seed_id,1,24);var field=install(b) if accelerated else b._extras[7];var started:int=Time.get_ticks_usec();var output
					if kind=="random_queries":
						output=[]
						for i in range(1200):output.append(field.network(Vector2(i*7919%400000-200000,i*11939%400000-200000)))
					else:
						b.chunk_size=256 if kind=="near_dense" else (2048 if kind=="regional" else 16384)
						var arrays:Array=b.build(Vector2i(40,-8) if kind=="near_dense" else (Vector2i(5,-1) if kind=="regional" else Vector2i(0,-1)),32 if kind!="regional" else 64);output=[arrays,b.built_extension_data.duplicate()]
					var elapsed:float=(Time.get_ticks_usec()-started)/1000.0;times[accelerated]=elapsed;outputs[accelerated]=output
					cases.append({"kind":kind,"seed":seed_id,"repeat":repeat,"accelerated":accelerated,"numeric_ms":elapsed,"tile_builds":field.tile_builds if accelerated else 0,"tile_hits":field.tile_hits if accelerated else 0,"retained_tiles":field._query_tiles.size() if accelerated else 0,"probe_entries":field._tile_probes.size() if accelerated else 0,"uncached_queries":field.uncached_queries if accelerated else 0})
				check(outputs[false]==outputs[true],"Every timed workload preserves exact complete output")
				ratios.append(times[true]/maxf(times[false],.001))
		ratios.sort();summary.append({"kind":kind,"pairs":ratios.size(),"paired_median_ratio":ratios[ratios.size()/2]})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable private query profile source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/"+profile_basename+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"summary":summary,"source_sha256":hashes,"private_candidate_only":private_candidate_only,"scope":"Serial alternating cold-builder pairs: actual dense near, regional and sparse far terrain/atlas plus random network queries, three seeds and nine pairs per workload. Exact outputs checked. Numeric CPU only; no native worker/startup/frame/GPU certificate or production adoption."},"  "))
	print("NETWORK_TILE_PROFILE ",summary," failures=",failures);quit(0 if failures.is_empty() else 1)
