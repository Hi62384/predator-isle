extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Fixture=preload("res://tools/caves/frozen_fixture.gd")
const Field=preload("res://scripts/caves/field.gd")
func run()->void:
	var guards:Dictionary={}
	for folder:String in ["res://scripts/caves"]:
		for name:String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):var path:String=folder+"/"+name;guards[path]=FileAccess.get_sha256(path)
	for path:String in [get_script().resource_path,"res://scripts/terrain_mesh_builder.gd","res://config/caves/biomes/crystal_cave_definition.tres","res://config/caves/cave_biome_regions.tres","res://config/world/terrain_settings.tres"]:guards[path]=FileAccess.get_sha256(path)
	var config=Config.new();config.biome_regions=Fixture.registry(config.biome_regions,load("res://config/caves/biomes/crystal_cave_definition.tres"));var b=make_builder(5,73921);var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original normal Crystal worker for complete field/mesh/feature/water/frontier reference comparison");var results:Array=[]
	var task:int=WorkerThreadPool.add_task(func()->void:
		var bundle:Dictionary=work.discover(Vector2i(6,-2));var canonical:Callable=work.field.height;var counter:Array=[0]
		work.field.height=func(x:float,z:float)->float:counter[0]+=1;return float(canonical.call(x,z))
		var baseline:Dictionary={};var rows:Array=[]
		for mode:String in ["memo_off_a","memo_on_cold","memo_on_warm","memo_off_b"]:
			work.field.cache_height_samples=mode.begins_with("memo_on");counter[0]=0;work._water_cache.clear()
			if mode!="memo_on_warm":work.field._height_memo.clear()
			var began:int=Time.get_ticks_usec();var exact:bool=true;var vertices:int=0;var cells:int=0
			for key:Vector3i in [Vector3i(159,-2,-38),Vector3i(159,-2,-39),Vector3i(160,-2,-38)]:
				var cell:Dictionary=work.build_cell(key);var bytes:PackedByteArray=var_to_bytes(cell)
				if mode=="memo_off_a":baseline[key]=bytes
				else:exact=exact and bytes==baseline[key]
				if not cell.arrays.is_empty():vertices+=cell.arrays[Mesh.ARRAY_VERTEX].size()
				for batch:Dictionary in cell.get("features",[]):vertices+=batch.arrays[Mesh.ARRAY_VERTEX].size()
				cells+=1
			rows.append({"mode":mode,"complete_payload_exact":exact,"canonical_height_calls":counter[0],"retained_memo_entries":work.field._height_memo.size(),"cells":cells,"vertices":vertices,"single_order_seconds":(Time.get_ticks_usec()-began)/1000000.0})
		results.append(rows)
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);var rows:Array=results[0] if not results.is_empty() else [];check(rows.size()==4,"All predeclared original/cold-cache/warm-cache/original-return controls retained")
	for row:Dictionary in rows:check(row.complete_payload_exact and row.vertices>0 and row.cells==3 and row.retained_memo_entries<=8192,"COMPLETE same three actual worker payloads byte-identical,including mesh/normals/UV/minerals/water/frontiers/features/collision/LOD "+row.mode)
	if rows.size()==4:check(rows[1].canonical_height_calls<rows[0].canonical_height_calls*.6 and rows[2].canonical_height_calls<rows[3].canonical_height_calls*.6,"Predeclared at least40percent real canonical-call reduction,both cold and warm,not an empty or synthetic speedup")
	var field=Field.new();var calls:Array=[0]
	field.height=func(x:float,z:float)->float:calls[0]+=1;return 200+sin(x*.003)+cos(z*.007)
	var points:Array[Vector3]=[Vector3(20000.125,0,-19999.875),Vector3(20000.25,100,-19999.75),Vector3(-20000.125,-50,19999.875)];var reference:Array=[]
	for p:Vector3 in points:reference.append(field.ground_height(p));check(reference[-1]==200+sin(p.x*.003)+cos(p.z*.007),"Exact fractional positive/negative canonical coordinates,no integer or grid rounding")
	var first_calls:int=calls[0]
	for p:Vector3 in points:check(field.ground_height(p)==reference[points.find(p)],"Exact same XZ at different/cached heights")
	check(calls[0]==first_calls,"Repeated exact XZ reuses numeric column")
	for i in range(9000):field.ground_height(Vector3(i*1.125,0,-i*.875))
	check(field._height_memo.size()<=8192,"Bounded8192-entry infinite-world memo through real eviction")
	for p:Vector3 in points:check(field.ground_height(p)==reference[points.find(p)],"Eviction regenerates original canonical height exactly")
	field.height=func(_x:float,_z:float)->float:return 250.0
	check(field._height_memo.is_empty() and field.ground_height(points[0])==250,"Changing canonical provider invalidates every old cached height")
	check(field.compile([],field.height) and field._height_memo.is_empty(),"New compiled bundle invalidates memo,not persistent stale terrain settings")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual height memo source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_height_memo.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"rows":rows,"scope":"Same actual original normal Crystal73921/(6,-2)3x3field,three positive worker cells,complete old/cold memo/warm memo/old return payload byte equality;actual canonical callback counts and single-order nonisolated times. Exact fractional/signed XZ,8192-entry eviction,provider/bundle invalidation. Numeric-only cache,no new job or altered scalar/mesh. Not a full live performance/FPS or all-task acceptance claim."},"  "));print("CAVE_HEIGHT_MEMO ",checks," ",rows," failures=",failures);quit(0 if failures.is_empty() else 1)
