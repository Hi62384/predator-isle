extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://scripts/terrain_mesh_builder.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var source:String=FileAccess.get_file_as_string("res://scripts/caves/field.gd");var original:String="\tfor component:float in [point.x,point.y,point.z]:\n\t\tif absf(component)>2147483646.0*BIN_METRES:return FAR";var replacement:String="\tif absf(point.x)>2147483646.0*BIN_METRES or absf(point.y)>2147483646.0*BIN_METRES or absf(point.z)>2147483646.0*BIN_METRES:return FAR";check(source.contains(original),"Private experiment identifies exact existing per-sample temporary three-element bounds Array")
	var shim:String="\nvar surface_columns:Dictionary={}\nvar surface_limits:Dictionary={}\nvar top_height:Callable\nvar include_surface_air:bool=false\nfunc cave_sample(point:Vector3)->float:return sample(point)\nfunc surface_height(point:Vector2)->float:return float(top_height.call(point.x,point.y)) if top_height.is_valid() else float(height.call(point.x,point.y))\n";var candidate:=GDScript.new();candidate.source_code=source.replace(original,replacement)+shim;check(candidate.reload()==OK,"Private exact-boolean direct-bounds numeric field compiles")
	var config=Config.new();config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=make_builder(5,73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual original normal Crystal worker for full-payload comparison");var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(6,-2));var original_field=work.field;var private_field=candidate.new();var baseline:Dictionary={};var rows:Array=[]
		for item:Dictionary in [{"name":"production","field":original_field},{"name":"private_direct_bounds","field":private_field},{"name":"production_return","field":original_field}]:
			work.field=item.field;work.field.maximum_depth=config.maximum_depth_metres;work.field.minimum_roof=config.minimum_rock_cover_metres;work.bundle_key=Vector2i(2147483647,2147483647);var valid:bool=work.use_bundle(bundle);work._water_cache.clear();var start:int=Time.get_ticks_usec();var exact:bool=true;var vertices:int=0
			for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
				var data:Dictionary=work.build_cell(key);var bytes:PackedByteArray=var_to_bytes(data)
				if item.name=="production":baseline[key]=bytes
				else:exact=exact and bytes==baseline[key]
				if not data.arrays.is_empty():vertices+=data.arrays[Mesh.ARRAY_VERTEX].size()
			rows.append({"mode":item.name,"valid":valid,"complete_payload_exact":exact,"base_vertices":vertices,"single_order_nonisolated_seconds":(Time.get_ticks_usec()-start)/1000000.0})
		var bounds:Array=[]
		for value:float in [0,1,-1,2147483645.0*16,2147483646.0*16,2147483647.0*16,-2147483646.0*16,INF,-INF,NAN]:
			for axis in range(3):
				var point:=Vector3.ZERO;point[axis]=value;bounds.append({"point":str(point),"same":original_field.sample(point)==private_field.sample(point)})
		output.append({"rows":rows,"bounds":bounds})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var result:Dictionary=output[0] if not output.is_empty() else {};check(not result.is_empty(),"Complete private sampling experiment result")
	for row:Dictionary in result.get("rows",[]):check(row.valid and row.complete_payload_exact and row.base_vertices>0,"Complete actual three-cell mesh/normal/UV/feature/collision/LOD/water/frontier bytes exactly restored "+row.mode)
	for record:Dictionary in result.get("bounds",[]):check(record.same,"Finite/NaN/infinity/all-axis/far signed bound predicates exactly equivalent")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"No production sampling source changed during private candidate "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_field_sampling_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"private_source_sha256":candidate.source_code.sha256_text(),"records":result,"scope":"PRIVATE in-memory removal of one temporary three-element Array per scalar call,exact same finite/bounds boolean comparisons. Actual original Crystal full three-cell production/private/production-return payload equality and30signed/far/nonfinite predicate controls. No production adoption,arithmetic shortcut,skipped safety check,new sampling resolution or full-live/FPS claim."},"  "));print("FIELD_SAMPLING_CANDIDATE ",checks," ",result.get("rows",[])," failures=",failures);quit(0 if failures.is_empty() else 1)
