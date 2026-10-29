extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Mesher=preload("res://scripts/caves/portal_mesher.gd")
const Base=preload("res://scripts/caves/stream_frontiers.gd")
const Candidate=preload("res://tools/caves/frontier_sparse_candidate.gd")
func run()->void:
	var guards:Dictionary={}
	for path:String in [get_script().resource_path,"res://tools/caves/frontier_sparse_candidate.gd","res://scripts/caves/stream_frontiers.gd","res://scripts/caves/mesher.gd","res://scripts/caves/portal_mesher.gd","res://scripts/caves/workload.gd"]:guards[path]=FileAccess.get_sha256(path)
	var result:Array=[];var task:int=WorkerThreadPool.add_task(func()->void:
		for family:int in [3,6,7]:
			var b=make_builder(family,73921);var config=Config.new();config.regional_activity=1;config.formation_density=0;config.seepage_density=0;var work=Workload.new();var valid:bool=work.configure(b.settings,config,73921,0);var cell:Vector2i={3:Vector2i(9,-3),6:Vector2i(7,-2),7:Vector2i(-31,-31)}[family];var region:Dictionary=work.network.region(cell);valid=valid and region.valid and work.use_bundle({"cell":cell,"regions":[region],"connections":[]});var keys:Dictionary={}
			for room:Dictionary in region.nodes.slice(1,4):
				var center:Vector3=room.point+Vector3(0,2,0);var key:Vector3i=work.field.cell(center)
				for offset:Vector3i in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:keys[key+offset]=true
			work.field.include_surface_air=false;work.field.opening_rock_cover=6;var all_exact:bool=true;var positive:int=0;var reference_usec:int=0;var candidate_usec:int=0
			for key:Vector3i in keys:
				var mesher=Mesher.new();mesher.capture_boundary_values=true;mesher.build(work.field,key)
				for pair in range(3):
					var a:Dictionary;var c:Dictionary;var began:int=Time.get_ticks_usec()
					if pair%2==0:
						a=Base.build(work.field,key,mesher.boundary_values);reference_usec+=Time.get_ticks_usec()-began;began=Time.get_ticks_usec();c=Candidate.build(work.field,key,mesher.boundary_values);candidate_usec+=Time.get_ticks_usec()-began
					else:
						c=Candidate.build(work.field,key,mesher.boundary_values);candidate_usec+=Time.get_ticks_usec()-began;began=Time.get_ticks_usec();a=Base.build(work.field,key,mesher.boundary_values);reference_usec+=Time.get_ticks_usec()-began
					all_exact=all_exact and var_to_bytes(a)==var_to_bytes(c)
					if pair==0 and not a.is_empty():positive+=1
				# Fresh sampling path must match too,including explicit surface-air
				# exclusion while the worker field is in portal-union mode.
				work.field.include_surface_air=true;all_exact=all_exact and var_to_bytes(Base.build(work.field,key))==var_to_bytes(Candidate.build(work.field,key));work.field.include_surface_air=false
			result.append({"family":family,"valid":valid,"keys":keys.size(),"positive":positive,"all_bytes_exact":all_exact,"reference_microseconds":reference_usec,"candidate_microseconds":candidate_usec})
	)
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task)
	for item:Dictionary in result:check(item.valid and item.positive>0 and item.all_bytes_exact,"Actual original host complete numeric cap arrays exact across room/adjacent/empty cells,reused/fresh/portal-union paths")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable sparse frontier source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frontier_sparse_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":result,"scope":"PRIVATE candidate,one real numeric worker,original fixed Spore/Insect/Alien seed73921regions/three original room coordinates and adjacent/empty cells. Complete cap render/collision-source arrays compared byte-for-byte,three alternating measured pairs per cell plus fresh sampling under portal surface-air union. No graph/mesh/texture/view/physics change. Within-run microseconds only,not broad isolated hardware or full live-return timing acceptance."},"  "));print("SPARSE_FRONTIER_CANDIDATE ",checks," records=",result," failures=",failures);quit(0 if failures.is_empty() else 1)
