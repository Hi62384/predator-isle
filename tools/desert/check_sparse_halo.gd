extends SceneTree
## Compare all returned bytes, not just visible heights. No export.
const Builder=preload("res://scripts/terrain_mesh_builder.gd")
var failures:Array[String]=[]
func _initialize()->void:
	var comparisons:int=0
	var timings:Dictionary={"reference_us":0,"pruned_us":0}
	for seed_value in [73921,-91827,214748]:
		for coverage in [0.0,50.0,100.0]:
			for size in [256.0,2048.0,16384.0]:
				var a=Builder.new();var b=Builder.new()
				for item in [a,b]:
					item.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
					item.settings.grass_coverage=100.0-coverage;item.settings.desert_coverage=coverage
					item.settings.snow_coverage=0;item.settings.stone_coverage=0;item.settings.temperature_enabled=false
					item.chunk_size=size;item.world_seed=seed_value;item._configure_noise()
				a.prune_unused_halo=false
				a.cache_dense_payloads=true
				for coordinate in [Vector2i.ZERO,Vector2i(-3,5),Vector2i(17,-11)]:
					var resolution:int=64 if size==256.0 else 16
					var tick:int=Time.get_ticks_usec()
					var old:Array=a.build(coordinate,resolution)
					timings.reference_us+=Time.get_ticks_usec()-tick
					tick=Time.get_ticks_usec()
					var actual:Array=b.build(coordinate,resolution)
					timings.pruned_us+=Time.get_ticks_usec()-tick
					for channel in range(Mesh.ARRAY_MAX):
						if old[channel]==null or actual[channel]==null:
							if old[channel]!=actual[channel]:failures.append("Optional channel changed")
						elif old[channel].to_byte_array()!=actual[channel].to_byte_array():
							failures.append("Bytes differ seed %s coverage %s size %s tile %s channel %s"%[seed_value,coverage,size,coordinate,channel])
						comparisons+=1
	FileAccess.open("res://tools/desert/sparse_halo_results.json",FileAccess.WRITE).store_string(JSON.stringify({"comparisons":comparisons,"timings":timings,"failures":failures},"\t"))
	for failure in failures:push_error(failure)
	print("Sparse halo comparisons: ",comparisons," failures: ",failures.size()," timings: ",timings)
	quit(0 if failures.is_empty() else 1)
