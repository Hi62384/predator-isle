extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	preload("res://tools/biome_extensions/inactive_region_patch_candidate.gd").apply()
	var rows:Array=[];var ratios:Array[float]=[];var failed:bool=false;var coordinates:Array[Vector2i]=[Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]
	for index:int in range(coordinates.size()):
		var payloads:Dictionary={};var times:Dictionary={}
		for enabled:bool in ([false,true] if index%2==0 else [true,false]):
			var b=load("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			for key:String in ["badlands"]+TerrainSettings.EXTENSION_KEYS:b.settings.set(key+"_coverage",12)
			b._configure_noise();b.chunk_size=16384
			for sampler in b._extras:
				if sampler!=null:sampler.skip_saturated_regions=enabled
			var start:int=Time.get_ticks_usec();var arrays:Array=b.build(coordinates[index],128);times[enabled]=(Time.get_ticks_usec()-start)/1000.0
			payloads[enabled]=[var_to_bytes(arrays),b.built_extension_data,b.built_alien_tissue_flow]
		var exact:bool=payloads[false]==payloads[true];failed=failed or not exact
		var ratio:float=times[true]/times[false];ratios.append(ratio)
		rows.append({"coordinate":str(coordinates[index]),"original_ms":times[false],"candidate_ms":times[true],"ratio":ratio,"complete_payload_exact":exact});print("INACTIVE_REGION_COST ",rows[-1])
	ratios.sort();var report:Dictionary={"passed":not failed,"cases":rows,"median_ratio":ratios[1],"scope":"Three cold actual LOD6/128grid all-owner worker surfaces;paired order alternates. Exact full mesh/control/flow bytes. Non-isolated CPU observation,not universal startup/FPS improvement."}
	FileAccess.open("res://tools/biome_extensions/artifacts/benchmark_inactive_regions.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));quit(1 if failed else 0)
