extends "res://tools/biome_extensions/check_all.gd"
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	var source:String=FileAccess.get_file_as_string("res://scripts/caves/mesher.gd").replace("func emit(","func raw_emit(")
	source=source.replace("normal=field.normal(point)","var normal_began:int=Time.get_ticks_usec();normal=field.normal(point);normal_usec+=Time.get_ticks_usec()-normal_began;normal_calls+=1")
	source=source.replace("for z in range(row):\n\t\tfor y in range(row):","var grid_began:int=Time.get_ticks_usec()\n\tfor z in range(row):\n\t\tfor y in range(row):")
	source=source.replace("if capture_boundary_values and step_metres==2:","grid_usec=Time.get_ticks_usec()-grid_began\n\tif capture_boundary_values and step_metres==2:")
	var portal:String=FileAccess.get_file_as_string("res://scripts/caves/portal_mesher.gd");source+=portal.substr(portal.find("func emit(")).replace("super.emit(a,b,c)","raw_emit(a,b,c)")
	source=source.replace("if not field.surface_columns.has(column) and center.y>=field.surface_height(Vector2(center.x,center.z))-4:return","var clip_began:int=Time.get_ticks_usec();var clipped:bool=not field.surface_columns.has(column) and center.y>=field.surface_height(Vector2(center.x,center.z))-4;clip_usec+=Time.get_ticks_usec()-clip_began;clip_calls+=1\n\tif clipped:return")
	source+="\nvar normal_usec:int=0\nvar normal_calls:int=0\nvar grid_usec:int=0\nvar clip_usec:int=0\nvar clip_calls:int=0\n"
	var mesher:=GDScript.new();mesher.source_code=source;check(mesher.reload()==OK,"PRIVATE exact mesher phase instrumentation compiles")
	var work_source:String=FileAccess.get_file_as_string("res://scripts/caves/workload.gd").replace("const Mesher=preload(\"res://scripts/caves/portal_mesher.gd\")","var Mesher").replace("var arrays:Array=mesher.build(field,key,2)","var began:int=Time.get_ticks_usec();var arrays:Array=mesher.build(field,key,2);last_mesh={\"total_usec\":Time.get_ticks_usec()-began,\"grid_usec\":mesher.grid_usec,\"normal_usec\":mesher.normal_usec,\"normal_calls\":mesher.normal_calls,\"surface_clip_usec\":mesher.clip_usec,\"surface_clip_calls\":mesher.clip_calls}")+"\nvar last_mesh:Dictionary={}\n"
	var private_work:=GDScript.new();private_work.source_code=work_source;check(private_work.reload()==OK,"PRIVATE worker retains only phase counters")
	var config=Config.new();config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=make_builder(5,73921);var work=private_work.new();work.Mesher=mesher;check(work.configure(b.settings,config,73921,0),"Actual Crystal world/field unchanged");var result:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		work.discover(Vector2i(6,-2));var cells:Array=[]
		for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
			var data:Dictionary=work.build_cell(key);cells.append({"key":str(key),"valid":data.valid,"mesh":work.last_mesh.duplicate()})
		result.append(cells)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(result.size()==1,"All private mesh phases returned")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Production unchanged during exact instrumented mesher "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/profile_cave_crystal_mesh_phases.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"result":result,"scope":"PRIVATE timestamps around actual existing lattice loop,exact six-sample normal calls and actual surface-clip queries,not altered geometry. Timestamp overhead included. Original Crystal first3positive cells. Nonisolated phase diagnosis,not production optimization/FPS/full-live acceptance."},"  "));print("CRYSTAL_MESH_PHASES ",result," failures=",failures);quit(0 if failures.is_empty() else 1)
