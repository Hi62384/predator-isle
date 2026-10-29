extends "res://tools/biome_extensions/check_all.gd"
const ROOTS="res://tools/biome_extensions/artifacts/revisions/experiment_earth_crystal_trial_5000e91a1dfb/sources/tools/biome_extensions/artifacts/check_grounded_earth_crystal_candidate.json.txt"
func v2(value:String)->Vector2:
	var parts:PackedStringArray=value.trim_prefix("(").trim_suffix(")").split(",");return Vector2(float(parts[0]),float(parts[1]))
func digest(value)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(value));return h.finish().hex_encode()
func produce(b,coordinate:Vector2i)->Dictionary:
	var start:int=Time.get_ticks_usec();var arrays:Array=b.build(coordinate,16);var features_mesher=preload("res://scripts/terrain_feature_meshes.gd").new();var features:Dictionary=features_mesher.build(b,coordinate)
	var structures:Array=preload("res://scripts/lod_biome_extension_structures.gd").new().build(b,coordinate,Structures.support_grids(),features_mesher.portal_sites);var collision:Dictionary=preload("res://scripts/terrain_collision.gd").prepare(arrays,16,false,structures,features,true)
	return {"seconds":(Time.get_ticks_usec()-start)/1000000.0,"payload":digest([arrays,b.build_swamp_water(arrays,16),b.built_extension_data,b.built_extension_rows,b.built_extension_mask,structures,features,collision]),"positive_vertices":structures[1][Mesh.ARRAY_VERTEX].size() if not structures[1].is_empty() else 0}
func run()->void:
	var guards:Dictionary={ROOTS:FileAccess.get_sha256(ROOTS)};var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]
	for path:String in ["res://tools/biome_extensions/profile_insect_earth_worker.gd","res://tools/biome_extensions/check_all.gd"]:guards[path]=FileAccess.get_sha256(path)
	var input=JSON.parse_string(FileAccess.get_file_as_string(ROOTS));assert(input.passed);var records:Array=[];var ratios:Array=[]
	for item:Dictionary in input.cases:
		if item.family!=6:continue
		for repeat_id in range(3):
			var pair:Dictionary={};var p:Vector2=v2(item.root);var coordinate:=Vector2i(floori(p.x/4096),floori(p.y/4096))
			for enabled:bool in ([false,true] if repeat_id%2==0 else [true,false]):
				var b=make_builder(6,int(item.seed));b.chunk_size=4096;b.settings.insect_colony.nest_earth_material=enabled;var output:Array=[]
				var task:int=WorkerThreadPool.add_task(func()->void:output.append(produce(b,coordinate)))
				while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_msec(1)
				WorkerThreadPool.wait_for_task_completion(task);pair[enabled]=output[0]
			check(pair[false].positive_vertices>0,"Frozen original actual admitted Insect roots present")
			check(pair[false].payload==pair[true].payload,"Whole actual cold worker terrain/water/features/structures/indexed collision bytes exact")
			var ratio:float=pair[true].seconds/maxf(pair[false].seconds,.000001);ratios.append(ratio);records.append({"seed":item.seed,"repeat":repeat_id,"coordinate":str(coordinate),"off":pair[false],"on":pair[true],"ratio":ratio})
	check(records.size()==9,"Nine alternating cold actual WorkerThreadPool pairs across three original seeds")
	ratios.sort()
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable registered worker source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_insect_earth_worker.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"median_on_off_ratio":ratios[ratios.size()/2],"isolated":false,"scope":"Actual registered saved setting false/true,nine alternating cold actual worker pipeline pairs,three original dry admitted roots. Whole terrain/water/semantic atlases/features/structures/indexed collision bytes exact. No numeric geometry or textures added by this material-only control. NON-ISOLATED cost observations,not repeatable global speedup/startup guarantee."},"  "));print("INSECT_EARTH_WORKER ",checks," median ratio=",ratios[ratios.size()/2]," failures=",failures);quit(0 if failures.is_empty() else 1)
