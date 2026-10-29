extends SceneTree
func percentile(values:Array,f:float)->float:
	values.sort();return values[clampi(floori(values.size()*f),0,values.size()-1)]
func mesh_hash(arrays:Array,atlas:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	for data in arrays:context.update(var_to_bytes(data))
	context.update(var_to_bytes(atlas))
	return context.finish().hex_encode()
func make_builder(seed_id:int,span:float):
	var builder=preload("res://scripts/terrain_mesh_builder.gd").new();builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);builder.world_seed=seed_id;builder.chunk_size=span
	builder.settings.beaches_enabled=false;builder.settings.rocky_coast_enabled=false
	for biome:String in ["grass","forest","savanna","swamp","jungle","mountain","tropical"]:builder.settings.set(biome+"_coverage",0)
	builder.settings.badlands_coverage=100;builder._configure_noise();return builder
func inland_cell(seed_id:int,span:float)->Vector2i:
	var probe=make_builder(seed_id,span)
	for ring in range(1,33):
		for z in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				if absi(x)!=ring and absi(z)!=ring:continue
				var coordinate:=Vector2i(floori(x*4096.0/span),floori(z*4096.0/span))
				var p:Vector2=(Vector2(coordinate)+Vector2.ONE*.5)*span
				if probe._island_mask(p.x,p.y)<.2:continue
				return coordinate
	assert(false,"Actual inland benchmark chunk not found");return Vector2i.ZERO
func _initialize()->void:
	var segment_mode:bool=OS.get_cmdline_user_args().has("segment-index")
	var normal_mode:bool=OS.get_cmdline_user_args().has("normal-interleave")
	var grade_mode:bool=OS.get_cmdline_user_args().has("grade-bound")
	var records:Array=[];var summaries:Array=[]
	for dimensions:Vector2i in [Vector2i(256,64),Vector2i(256,128),Vector2i(16384,64)]:
		var cached:Array=[];var reference:Array=[]
		for repeat in range(3):
			var seed_id:int=[73921,17,92881][repeat];var coordinate:Vector2i=inland_cell(seed_id,dimensions.x)
			var hashes:Dictionary={}
			for mode:String in (["reference","cached"] if repeat%2==0 else ["cached","reference"]):
				var builder=make_builder(seed_id,dimensions.x)
				if mode=="reference":
					if grade_mode:builder._badlands._use_grade_bound=false
					elif normal_mode:builder.interleave_badlands_normals=false
					elif segment_mode:builder._badlands._use_segment_index=false
					else:
						builder._badlands=preload("res://tools/badlands/reference_cubic_sampler.gd").new();builder._badlands.configure(builder.settings.badlands,builder.world_seed,builder)
				var start:int=Time.get_ticks_usec();var arrays:Array=builder.build(coordinate,dimensions.y);var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
				assert(not builder.built_extension_data.is_empty(),"Actual inland fixture carries Badlands controls")
				var water:Array=builder.build_swamp_water(arrays,dimensions.y)
				hashes[mode]=mesh_hash(arrays,builder.built_extension_data)+mesh_hash(water,PackedByteArray())
				if mode=="cached":cached.append(elapsed)
				else:reference.append(elapsed)
				assert(builder._badlands._nodes.size()<=16384 and builder._badlands._patches.size()<=1024)
				records.append({"span":dimensions.x,"resolution":dimensions.y,"repeat":repeat,"seed":builder.world_seed,"cell":coordinate,"mode":mode,"ms":elapsed,"atlas_bytes":builder.built_extension_data.size(),"hash":hashes[mode]})
			assert(hashes.cached==hashes.reference,"Optimization changed complete mesh arrays")
		var summary:Dictionary={"span":dimensions.x,"resolution":dimensions.y,"cached_median_ms":percentile(cached,.5),"reference_median_ms":percentile(reference,.5),"cached_max_ms":percentile(cached,1),"reference_max_ms":percentile(reference,1),"full_mesh_arrays_exact":true}
		summaries.append(summary);print("BADLANDS_CUBIC_CACHE ",summary)
	var result:Dictionary={"records":records,"summaries":summaries,"optimization":"segment_index" if segment_mode else "cubic_cache","same_current_geology":true,"alternating_order":true,"repeats":3,"sampler_sha256":FileAccess.get_sha256("res://scripts/badlands_sampler.gd"),"scope":"Isolated cold numerical mesh builds; excludes native rendering, feature/collision upload, streaming and cold shader compilation"}
	var output:String="benchmark_segment_index" if segment_mode else "benchmark_cubic_cache"
	if normal_mode:output="benchmark_normal_interleave";result.optimization="normal_interleave"
	if grade_mode:output="benchmark_grade_bound";result.optimization="grade_bound"
	result.builder_sha256=FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd")
	result.fixture="Actual inland chunk centres, same per paired comparison; seeds 73921, 17, 92881. Locator is outside timed cold builds. Not the old Vector2i.ONE fixture, which could be ocean."
	FileAccess.open("res://tools/badlands/artifacts/"+output+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));quit()
