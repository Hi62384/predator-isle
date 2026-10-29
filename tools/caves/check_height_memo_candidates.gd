extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://scripts/terrain_mesh_builder.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://config/caves/cave_biome_regions.tres"]:guards[path]=FileAccess.get_sha256(path)
	var shim:String="\nvar surface_columns:Dictionary={}\nvar surface_limits:Dictionary={}\nvar top_height:Callable\nvar include_surface_air:bool=false\nfunc cave_sample(point:Vector3)->float:return sample(point)\nfunc surface_height(point:Vector2)->float:return float(top_height.call(point.x,point.y)) if top_height.is_valid() else READER\n"
	var source:String=FileAccess.get_file_as_string("res://scripts/caves/field.gd");var candidates:Array=[]
	for size:int in [8192,32768]:
		var script:=GDScript.new();script.source_code=source.replace("MAX_HEIGHT_SAMPLES:int=8192","MAX_HEIGHT_SAMPLES:int="+str(size))+shim.replace("READER","ground_height(Vector3(point.x,0,point.y))");check(script.reload()==OK,"Explicit PRIVATE ordinary-cell canonical fallback memo candidate compiles "+str(size));candidates.append({"script":script,"limit":size,"sha256":script.source_code.sha256_text()})
	var config=Config.new();config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=make_builder(5,73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual original normal Crystal candidate workload");var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(6,-2));var original=work.field;var baseline:Dictionary={};var rows:Array=[];var sequence:Array=[{"name":"production_8192","field":original,"limit":8192},{"name":"private_surface_8192","field":candidates[0].script.new(),"limit":8192},{"name":"private_surface_32768","field":candidates[1].script.new(),"limit":32768},{"name":"production_return","field":original,"limit":8192}]
		for item:Dictionary in sequence:
			work.field=item.field;work.field.maximum_depth=config.maximum_depth_metres;work.field.minimum_roof=config.minimum_rock_cover_metres;work.bundle_key=Vector2i(2147483647,2147483647);var valid:bool=work.use_bundle(bundle);var canonical:Callable=work.field.height;var count:Array=[0]
			work.field.height=func(x:float,z:float)->float:count[0]+=1;return float(canonical.call(x,z))
			work._water_cache.clear();var began:int=Time.get_ticks_usec();var exact:bool=true;var vertices:int=0
			for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
				var data:Dictionary=work.build_cell(key);var bytes:PackedByteArray=var_to_bytes(data)
				if item.name=="production_8192":baseline[key]=bytes
				else:exact=exact and baseline[key]==bytes
				if not data.arrays.is_empty():vertices+=data.arrays[Mesh.ARRAY_VERTEX].size()
			rows.append({"mode":item.name,"valid":valid,"complete_payload_exact":exact,"canonical_height_calls":count[0],"retained_memo_entries":work.field._height_memo.size(),"declared_maximum_entries":item.limit,"base_vertices":vertices,"single_order_nonisolated_seconds":(Time.get_ticks_usec()-began)/1000000.0})
		output.append(rows)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var rows:Array=output[0] if not output.is_empty() else []
	check(rows.size()==4,"All current/private8192/private32768/current-return cases retained")
	for row:Dictionary in rows:check(row.valid and row.complete_payload_exact and row.base_vertices>0 and row.retained_memo_entries<=row.declared_maximum_entries,"COMPLETE actual three-cell payload/collision/UV/feature/LOD/frontier byte equality and explicit candidate bound "+row.mode)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Production source never changed during private memo study "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_height_memo_candidates.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"rows":rows,"private_scripts":[{"limit":candidates[0].limit,"source_sha256":candidates[0].sha256},{"limit":candidates[1].limit,"source_sha256":candidates[1].sha256}],"scope":"PRIVATE in-memory ordinary-cell field shims compare exact canonical surface-height fallback memo and8192/32768limits against production/current-return. Same original actual3x3Crystal field/three positive cells. No production setting/capacity/source adoption by this test. Complete actual payload equality,callback counts and single-order NONISOLATED times;not FPS/full live acceptance."},"  "));print("HEIGHT_MEMO_CANDIDATES ",checks," ",rows," failures=",failures);quit(0 if failures.is_empty() else 1)
