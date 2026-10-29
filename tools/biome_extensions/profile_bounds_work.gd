extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/reference_bounded_distance_experiment.gd","res://tools/biome_extensions/trace_alien_bounds_sampler.gd","res://tools/biome_extensions/profile_bounds_work.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(7,seed_id);var sampler=preload("res://tools/biome_extensions/trace_alien_bounds_sampler.gd").new();sampler.configure(b.settings.alien_infected,seed_id,b,7)
		var a:Vector2=sampler.hive_node(Vector2i(-12,-12));var end:Vector2=sampler.hive_node(Vector2i(-11,-12));var side:Vector2=(end-a).orthogonal().normalized()
		for i in range(512):
			var p:Vector2=((a.lerp(end,float(i)/511)+side*(i%7-3)*16)/16).floor()*16;sampler.network(p)
		check(sampler.projections>0 and sampler.projections<sampler.bound_tests,"Actual conservative pruning exercised")
		check(sampler._edge_bounds.size()<=512 and sampler._network_edges.size()<=512,"Both bounded path caches")
		cases.append({"seed":seed_id,"candidate_segment_tests":sampler.bound_tests,"exact_projections":sampler.projections,"skipped_projections":sampler.bound_tests-sampler.projections,"retained_bound_cells":sampler._edge_bounds.size()})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable work-count source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_bounds_work.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"rejected_experiment_only":true,"production_change_kept":false,"failures":failures,"cases":cases,"source_sha256":hashes,"scope":"Instrumented REJECTED bounded-distance candidate, not the production sampler, for 512 near-trunk lattice queries per seed. No timing values: instrumentation adds dispatch overhead. It preserved tested outputs but was slower; production was restored."},"  "))
	print("ALIEN_BOUNDS_WORK ",cases);quit(0 if failures.is_empty() else 1)
