extends "res://tools/biome_extensions/check_all.gd"
const Reference=preload("res://tools/biome_extensions/reference_pre_edge_cache_alien_sampler.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/reference_pre_edge_cache_alien_sampler.gd","res://tools/biome_extensions/check_alien_edge_cache.gd"]:hashes[path]=FileAccess.get_sha256(path)
	for seed_id:int in [73921,17,92881]:
		for scale:float in [.2,1.0,2.0]:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale;b.settings.alien_infected.nerve_fibre_height=0;b._configure_noise()
			var actual=b._extras[7];var reference=Reference.new();reference.configure(b.settings.alien_infected,seed_id,b,7)
			var points:Array[Vector2]=[]
			for i in range(600):points.append(Vector2(i*7919%400000-200000,i*11939%400000-200000))
			# Tight samples include real ridge/trunk transitions, not only empty fronts.
			var node:Vector2=actual.hive_node(Vector2i(-12,-11))
			for i in range(120):points.append(node+Vector2(i*16-960,i%9*16-64))
			for p:Vector2 in points:
				check(actual.network(p)==reference.network(p),"Exact original path network")
				check(actual.sample(p.x,p.y)==reference.sample(p.x,p.y) and actual.state==reference.state,"Exact original sampled field and controls")
				check(actual._network_edges.size()<=512,"Bounded edge geometry cache")
			points.reverse();actual._network_cache.clear();actual._nodes.clear()
			for p:Vector2 in points:check(actual.network(p)==reference.network(p),"Exact after eviction/reverse query order")
			# Full builder arrays against the previous sampler under identical settings.
			var old=make_builder(7,seed_id);old.settings.alien_infected.feature_scale=scale;old.settings.alien_infected.nerve_fibre_height=0;old._configure_noise();old._extras[7]=Reference.new();old._extras[7].configure(old.settings.alien_infected,seed_id,old,7)
			for size:int in [256,4096]:
				b.chunk_size=size;old.chunk_size=size;var cell:=Vector2i(floori(node.x/size),floori(node.y/size))
				var a:Array=b.build(cell,16);var payload:PackedByteArray=b.built_extension_data.duplicate();var water:Array=b.build_swamp_water(a,16)
				var expected:Array=old.build(cell,16)
				check(a==expected and payload==old.built_extension_data and water==old.build_swamp_water(expected,16),"Complete original geometry/metadata/water arrays")
			# Reconfigure a USED sampler; all derived caches must be invalidated.
			actual.configure(b.settings.alien_infected,seed_id+1,b,7)
			check(actual._network_edges.is_empty() and actual._hive_nodes.is_empty() and actual._network_cache.is_empty(),"All derived caches cleared by configure")
			var fresh=load("res://scripts/alien_infected_sampler.gd").new();fresh.configure(b.settings.alien_infected,seed_id+1,b,7)
			for p:Vector2 in points.slice(0,32):check(actual.network(p)==fresh.network(p),"Reconfigured sampler matches fresh seed")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_alien_edge_cache.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"scope":"Three seeds, minimum/default/maximum feature scale, exact original network/field/control values, reverse-order cache eviction, full near/far builder geometry/metadata/water arrays and used-sampler reconfiguration. Separate paired benchmarks establish speed, not these assertions."},"  "))
	print("ALIEN_EDGE_CACHE ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
