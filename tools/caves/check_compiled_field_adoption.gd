extends "res://tools/biome_extensions/check_all.gd"
const Field=preload("res://scripts/caves/field.gd")
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
const OLD="res://tools/biome_extensions/artifacts/revisions/experiment_check_cave_field_precomputed_candidate_a80e10dd0e70/sources/scripts/caves/field.gd.txt"
func run()->void:
	var guards:Dictionary={OLD:FileAccess.get_sha256(OLD)}
	check(guards[OLD]=="551c7e0cfec44155416018d92cea3bf894a80427e0dc32928a988f213885295b","Exact frozen pre-adoption source,not regenerated reference")
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://scripts/terrain_mesh_builder.gd","res://config/caves/biomes/crystal_cave_definition.tres"]:guards[path]=FileAccess.get_sha256(path)
	var shim:String="\nvar surface_columns:Dictionary={}\nvar surface_limits:Dictionary={}\nvar top_height:Callable\nvar include_surface_air:bool=false\nfunc cave_sample(point:Vector3)->float:return sample(point)\nfunc surface_height(point:Vector2)->float:return float(top_height.call(point.x,point.y)) if top_height.is_valid() else float(height.call(point.x,point.y))\n";var frozen:=GDScript.new();frozen.source_code=FileAccess.get_file_as_string(OLD)+shim;check(frozen.reload()==OK,"Frozen original numeric field compiles independently")
	var sample_count:int=0;var normal_count:int=0;var mismatches:int=0;var cases:int=0
	for style in range(8):
		for offset:float in [0,20000,-20000,10000000,-10000000]:
			for cap:bool in [true,false]:
				var base:=Vector3(offset,20,-offset);var room:Dictionary={"id":"A","level":1,"point":base+Vector3(24,0,24),"chamber_radius":22.0,"chamber_height":34.0};var edge:Dictionary={"from":"A","to":"B","points":PackedVector3Array([base,base+Vector3(12,-2.4,0),base+Vector3(24,0,0),base+Vector3(36,2.4,4)]),"half_width":4.0,"headroom":8.0,"entrance":false};var region:Dictionary={"valid":true,"id":Vector2i.ZERO,"nodes":[room],"edges":[edge],"cross_section_style":style};var assignment:Dictionary={"fallback":"default","candidates":[{"id":"A/crystal","biome_id":"crystal","reach_m":200.0,"transition_m":48.0,"distances":{"A":0.0,"B":38.0}}]}
				var height:Callable=func(_x:float,_z:float)->float:return 200.0
				var current=Field.new();var old=frozen.new();current.continuous_route_floors=cap;old.continuous_route_floors=cap
				check(current.compile([region],height,[],assignment) and old.compile([region],height,[],assignment),"Same room/route/material graph compiles in all8styles/signed/far/cap modes");cases+=1
				for i in range(360):
					var point:Vector3=base+Vector3((i%61)*.8125-4,(i%47)*.8125-3,(i%53)*.8125-4);sample_count+=1;normal_count+=1
					if current.sample(point)!=old.sample(point) or current.normal(point)!=old.normal(point) or current.biome_weights_at(point,["crystal"])!=old.biome_weights_at(point,["crystal"]):mismatches+=1
				check(current.directions.size()==current.begins.size() and current.arch_scale.size()==current.begins.size(),"Every accepted primitive has exactly one complete immutable expression tuple")
				current.clear();check(current.directions.is_empty() and current.span_squared.is_empty() and current.span_length.is_empty() and current.arch_height.is_empty() and current.arch_center.is_empty() and current.arch_scale.is_empty(),"Compile/clear invalidates all primitive expression arrays")
	check(cases==80 and mismatches==0,"All80fixed cases and28800complete scalar/normal/weight probes are bit-exact to frozen source")
	# This historical optimization compares identical content. The later
	# independent physical floor modifier has its own frozen adoption proof.
	var config=Config.new();var definition:Resource=load("res://config/caves/biomes/crystal_cave_definition.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);definition.feature_configuration.floor_ridges=false;config.biome_regions=Fixture.registry(config.biome_regions,definition);var b=make_builder(5,73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Actual original Crystal worker with later independent floor-ridge modifier OFF for unchanged-content optimization comparison");var result:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(6,-2));var current=work.field;var baseline:Dictionary={};var rows:Array=[]
		for item:Dictionary in [{"name":"frozen_original","field":frozen.new()},{"name":"adopted_current","field":current},{"name":"frozen_return","field":frozen.new()}]:
			work.field=item.field;work.field.maximum_depth=config.maximum_depth_metres;work.field.minimum_roof=config.minimum_rock_cover_metres;work.bundle_key=Vector2i(2147483647,2147483647);var valid:bool=work.use_bundle(bundle);work._water_cache.clear();var start:int=Time.get_ticks_usec();var exact:bool=true;var vertices:int=0
			for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
				var data:Dictionary=work.build_cell(key);var bytes:PackedByteArray=var_to_bytes(data)
				if item.name=="frozen_original":baseline[key]=bytes
				else:exact=exact and bytes==baseline[key]
				if not data.arrays.is_empty():vertices+=data.arrays[Mesh.ARRAY_VERTEX].size()
			rows.append({"mode":item.name,"valid":valid,"complete_payload_exact":exact,"base_vertices":vertices,"numeric_bytes":work.field.numeric_bytes(),"single_order_nonisolated_seconds":(Time.get_ticks_usec()-start)/1000000.0})
		result.append(rows)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var rows:Array=result[0] if not result.is_empty() else [];check(rows.size()==3,"Original/adopted/original-return complete")
	for row:Dictionary in rows:check(row.valid and row.complete_payload_exact and row.base_vertices>0,"COMPLETE actual native geometry/normal/collision/UV/features/water/frontier/LOD bytes exact "+row.mode)
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Frozen and adopted sources unchanged throughout "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_compiled_field_adoption.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"geometric_cases":cases,"sample_probes":sample_count,"normal_probes":normal_count,"mismatches":mismatches,"rows":rows,"scope":"Production adoption against verified exact frozen pre-adoption Field source.80all-geology/signed/far/old-new-cap cases,28800scalar+six-sample-normal+biome-weight probes;complete original actual3cell payload frozen/current/frozen-return comparisons. Packed Float64 unchanged expressions,48additional numeric bytes per accepted feature and unchanged feature limits. Nonisolated single-order times,not full-live/FPS acceptance."},"  "));print("COMPILED_FIELD_ADOPTION ",checks," mismatches=",mismatches," ",rows," failures=",failures);quit(0 if failures.is_empty() else 1)
