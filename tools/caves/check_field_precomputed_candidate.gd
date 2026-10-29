extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://scripts/terrain_mesh_builder.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var source:String=FileAccess.get_file_as_string("res://scripts/caves/field.gd");var changes:Array=[
		["var begins:=PackedVector3Array()","var directions:=PackedVector2Array()\nvar span_squared:=PackedFloat64Array()\nvar span_length:=PackedFloat64Array()\nvar arch_height:=PackedFloat64Array()\nvar arch_center:=PackedFloat64Array()\nvar arch_scale:=PackedFloat64Array()\nvar begins:=PackedVector3Array()"],
		["begins.clear();ends.clear()","directions.clear();span_squared.clear();span_length.clear();arch_height.clear();arch_center.clear();arch_scale.clear();begins.clear();ends.clear()"],
		["var feature:int=begins.size();begins.append(a)","var ab:=Vector2(b.x-a.x,b.z-a.z);directions.append(ab);span_squared.append(maxf(ab.length_squared(),.000001));span_length.append(ab.length());arch_height.append(size.y*.6);arch_center.append(size.y*.4);arch_scale.append(minf(size.x,size.y*.6))\n\tvar feature:int=begins.size();begins.append(a)"],
		["var ab:=Vector2(ends[feature].x-begins[feature].x,ends[feature].z-begins[feature].z)","var ab:Vector2=directions[feature]"],
		["var ab:=Vector2(b.x-a.x,b.z-a.z);var q:=Vector2(point.x-a.x,point.z-a.z)","var ab:Vector2=directions[feature];var q:=Vector2(point.x-a.x,point.z-a.z)"],
		["q.dot(ab)/maxf(ab.length_squared(),.000001)","q.dot(ab)/span_squared[feature]"],
		["Vector2(point.x-begins[feature].x,point.z-begins[feature].z).dot(ab)/maxf(ab.length_squared(),.000001)","Vector2(point.x-begins[feature].x,point.z-begins[feature].z).dot(ab)/span_squared[feature]"],
		["along*ab.length()*endpoint_grades","along*span_length[feature]*endpoint_grades"],
		["(along-1)*ab.length()*endpoint_grades","(along-1)*span_length[feature]*endpoint_grades"],
		["(y-size.y*.4)/(size.y*.6)","(y-arch_center[feature])/arch_height[feature]"],
		["*minf(size.x,size.y*.6)","*arch_scale[feature]"],
		["for component:float in [point.x,point.y,point.z]:\n\t\tif absf(component)>2147483646.0*BIN_METRES:return FAR","if absf(point.x)>2147483646.0*BIN_METRES or absf(point.y)>2147483646.0*BIN_METRES or absf(point.z)>2147483646.0*BIN_METRES:return FAR"]
	]
	for pair:Array in changes:check(source.contains(pair[0]),"Private exact expression precomputation matches "+pair[0]);source=source.replace(pair[0],pair[1])
	var shim:String="\nvar surface_columns:Dictionary={}\nvar surface_limits:Dictionary={}\nvar top_height:Callable\nvar include_surface_air:bool=false\nfunc cave_sample(point:Vector3)->float:return sample(point)\nfunc surface_height(point:Vector2)->float:return float(top_height.call(point.x,point.y)) if top_height.is_valid() else float(height.call(point.x,point.y))\n";var candidate:=GDScript.new();candidate.source_code=source+shim;check(candidate.reload()==OK,"PRIVATE packed exact-expression field compiles")
	var config=Config.new();config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=make_builder(5,73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original normal Crystal worker for exact private comparison");var output:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(6,-2));var original=work.field;var alternate=candidate.new();var baseline:Dictionary={};var rows:Array=[]
		for item:Dictionary in [{"name":"production","field":original},{"name":"private_precomputed","field":alternate},{"name":"production_return","field":original}]:
			work.field=item.field;work.field.maximum_depth=config.maximum_depth_metres;work.field.minimum_roof=config.minimum_rock_cover_metres;work.bundle_key=Vector2i(2147483647,2147483647);var valid:bool=work.use_bundle(bundle);work._water_cache.clear();var start:int=Time.get_ticks_usec();var exact:bool=true;var vertices:int=0
			for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
				var data:Dictionary=work.build_cell(key);var bytes:PackedByteArray=var_to_bytes(data)
				if item.name=="production":baseline[key]=bytes
				else:exact=exact and bytes==baseline[key]
				if not data.arrays.is_empty():vertices+=data.arrays[Mesh.ARRAY_VERTEX].size()
			rows.append({"mode":item.name,"valid":valid,"complete_payload_exact":exact,"base_vertices":vertices,"single_order_nonisolated_seconds":(Time.get_ticks_usec()-start)/1000000.0})
		var mismatches:int=0;var probes:int=0
		for i in range(12000):
			var point:=Vector3(10120.125+(i%113)*1.137,-180.375+(i%67)*1.013,-2480.625+(i%101)*1.017);probes+=1
			if original.sample(point)!=alternate.sample(point) or original.normal(point)!=alternate.normal(point) or original.biome_weights_at(point,["crystal"])!=alternate.biome_weights_at(point,["crystal"]):mismatches+=1
		output.append({"rows":rows,"sample_normal_weights_probes":probes,"mismatches":mismatches,"compiled_feature_count":alternate.begins.size(),"additional_numeric_bytes":alternate.begins.size()*48})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var result:Dictionary=output[0] if not output.is_empty() else {};check(not result.is_empty(),"Complete original/private/return study")
	for row:Dictionary in result.get("rows",[]):check(row.valid and row.complete_payload_exact and row.base_vertices>0,"COMPLETE actual original three-cell payload byte equality "+row.mode)
	check(result.get("mismatches",-1)==0 and result.get("sample_normal_weights_probes",0)==12000,"Exact sampled scalars,full six-sample normals and biome weights,including real room/route overlaps")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"No production source changed during private study "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_field_precomputed_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"private_source_sha256":candidate.source_code.sha256_text(),"records":result,"scope":"PRIVATE compile-time caching of unchanged Vector2 direction,length,exact Float64 arch expressions and denominator,not reciprocal multiplication or geometric approximation. Complete actual original three-cell payload equality,12000sample/normal/biome probes,current/private/current-return single-order nonisolated timings. No production adoption/full-live/FPS claim."},"  "));print("FIELD_PRECOMPUTED_CANDIDATE ",checks," ",result," failures=",failures);quit(0 if failures.is_empty() else 1)
