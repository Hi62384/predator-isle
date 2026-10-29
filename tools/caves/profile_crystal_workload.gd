extends "res://tools/biome_extensions/check_all.gd"
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	var source:String=FileAccess.get_file_as_string("res://scripts/caves/workload.gd")+"\nvar profile:Dictionary={}\nfunc record_time(label:String,began:int)->void:profile[label]=int(profile.get(label,0))+Time.get_ticks_usec()-began\n"
	for pair:Array in [
		["var arrays:Array=mesher.build(field,key,2)","var stage:int=Time.get_ticks_usec();var arrays:Array=mesher.build(field,key,2);record_time(\"mesh\",stage);stage=Time.get_ticks_usec()"],
		["_last_frontiers=Frontiers.build(field,key,mesher.boundary_values)","_last_frontiers=Frontiers.build(field,key,mesher.boundary_values);record_time(\"frontiers\",stage);stage=Time.get_ticks_usec()"],
		["_last_biome_ids=bound.ids;_last_valid=bound.valid","_last_biome_ids=bound.ids;_last_valid=bound.valid;record_time(\"binding_and_formations\",stage);stage=Time.get_ticks_usec()"],
		["return bound.arrays","record_time(\"frontier_binding\",stage);return bound.arrays"],
		["var features:Dictionary=BiomeFeatures.build(field,key,_seed,_regions,configuration.biome_regions,result.water)","var stage:int=Time.get_ticks_usec();var features:Dictionary=BiomeFeatures.build(field,key,_seed,_regions,configuration.biome_regions,result.water);record_time(\"biome_features\",stage)"],
		["var result:Dictionary=Basins.water_cell(_regions,field,key)","var stage:int=Time.get_ticks_usec();var result:Dictionary=Basins.water_cell(_regions,field,key)"],
		["# Cache only positive immutable water payloads","record_time(\"water\",stage)\n\t# Cache only positive immutable water payloads"]
	]:
		check(source.contains(pair[0]),"Private instrumentation matches exact phase "+pair[0]);source=source.replace(pair[0],pair[1])
	var instrumented:=GDScript.new();instrumented.source_code=source;check(instrumented.reload()==OK,"Private timing-only actual worker compiles")
	var config=Config.new();config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=make_builder(5,73921);var work=instrumented.new();check(work.configure(b.settings,config,73921,0),"Actual original Crystal configuration retained");var result:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var started:int=Time.get_ticks_usec();var bundle:Dictionary=work.discover(Vector2i(6,-2));var discovery:int=Time.get_ticks_usec()-started;var cells:Array=[]
		for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
			work.profile.clear();started=Time.get_ticks_usec();var cell:Dictionary=work.build_cell(key);cells.append({"key":str(key),"valid":cell.valid,"total_usec":Time.get_ticks_usec()-started,"phase_usec":work.profile.duplicate(),"base_vertices":cell.arrays[Mesh.ARRAY_VERTEX].size() if not cell.arrays.is_empty() else 0})
		result.append({"discovery_usec":discovery,"cells":cells,"regions":bundle.regions.size()})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(result.size()==1,"All actual phase records returned")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"No production changes during profile "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_cave_crystal_workload.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"result":result,"scope":"PRIVATE timing-only Workload source instrumentation,actual original Crystal73921/(6,-2) three positive cells. Single-order nonisolated worker phase diagnosis,not optimized production/FPS/full-live acceptance."},"  "));print("CRYSTAL_WORKLOAD_PROFILE ",result," failures=",failures);quit(0 if failures.is_empty() else 1)
