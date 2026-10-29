extends "res://tools/biome_extensions/check_all.gd"
const BeforeSquared=preload("res://tools/biome_extensions/reference_pre_squared_alien_sampler.gd")
func run()->void:
	var hashes:Dictionary={}
	var experiment:bool=OS.get_cmdline_user_args().has("candidate=bounded")
	if experiment:hashes["res://tools/biome_extensions/reference_bounded_distance_experiment.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/reference_bounded_distance_experiment.gd")
	for path:String in ["res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_sampler.gd","res://tools/biome_extensions/reference_pre_squared_alien_sampler.gd","res://tools/biome_extensions/profile_network_distances.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var paired:Array=[]
	for seed_id:int in [73921,17,92881]:
		var locator=make_builder(7,seed_id);var field=locator._extras[7];var a:Vector2=field.hive_node(Vector2i(-12,-12));var end:Vector2=field.hive_node(Vector2i(-11,-12));var side:Vector2=(end-a).orthogonal().normalized()
		var points:Array[Vector2]=[]
		for i in range(512):points.append(((a.lerp(end,float(i)/511)+side*(i%7-3)*16)/16).floor()*16)
		for repeat in range(3):
			var values:Dictionary={};var times:Dictionary={}
			for optimized:bool in ([false,true] if repeat%2==0 else [true,false]):
				var host=make_builder(7,seed_id);var sampler=host._extras[7] if optimized else BeforeSquared.new()
				if optimized and experiment:sampler=preload("res://tools/biome_extensions/reference_bounded_distance_experiment.gd").new()
				if not optimized or experiment:sampler.configure(host.settings.alien_infected,seed_id,host,7)
				var output:Array=[];var start:int=Time.get_ticks_usec()
				for p:Vector2 in points:output.append(sampler.network(p))
				var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
				values[optimized]=output;times[optimized]=elapsed;records.append({"seed":seed_id,"repeat":repeat,"production":optimized,"network_queries":points.size(),"cpu_ms":elapsed})
			check(values[true]==values[false],"Complete exact original network results for measured queries")
			paired.append(times[true]/times[false])
	var summary:Dictionary={}
	for optimized:bool in [false,true]:
		var times:Array=[]
		for record:Dictionary in records:
			if record.production==optimized:times.append(record.cpu_ms)
		times.sort();summary["production" if optimized else "reference"]={"median_ms":times[times.size()/2],"minimum_ms":times[0],"maximum_ms":times[-1],"runs":times.size()}
	paired.sort();summary["median_paired_production_reference_ratio"]=paired[paired.size()/2]
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable network benchmark source "+path)
	var suffix:String="_rejected" if experiment else ""
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_network_distances"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"rejected_experiment_only":experiment,"failures":failures,"records":records,"summary":summary,"source_sha256":hashes,"scope":"512 actual 16m-lattice network queries around a real trunk, three seeds and three alternating paired cold-sampler repetitions, checking complete exact network dictionaries. candidate=bounded selects the separately saved rejected experiment without modifying production. This isolates network work, not terrain/resource/streaming/physics/GPU cost."},"  "))
	print("NETWORK_DISTANCE_CPU ",summary);quit(0 if failures.is_empty() else 1)
