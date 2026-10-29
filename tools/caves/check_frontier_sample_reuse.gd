extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
const Frontiers=preload("res://scripts/caves/stream_frontiers.gd")
class CountedField extends "res://scripts/caves/portal_field.gd":
	var mesh_samples:int=0
	var cap_samples:int=0
	func sample(point:Vector3)->float:mesh_samples+=1;return super.sample(point)
	func cave_sample(point:Vector3)->float:cap_samples+=1;return super.cave_sample(point)
func run()->void:
	var guards:Dictionary={}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var path:String="res://scripts/caves/"+name;guards[path]=FileAccess.get_sha256(path)
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path);var records:Array=[];var jobs:Array=[]
	for family:int in [3,6,7]:
		var b=make_builder(family,73921);var config=Config.new();config.regional_activity=1;config.formation_density=0;config.seepage_density=0;var work=Workload.new();check(work.configure(b.settings,config,73921,0),"Original biological/rock host configured without unrelated decoration in sample-count control");var field:=CountedField.new();work.field=field;var cell:Vector2i={3:Vector2i(9,-3),6:Vector2i(7,-2),7:Vector2i(-31,-31)}[family];var result:Array=[]
		var task:int=WorkerThreadPool.add_task(func()->void:
			var region:Dictionary=work.network.region(cell);var valid:bool=region.valid and work.use_bundle({"cell":cell,"regions":[region],"connections":[]});var key:=Vector3i.ZERO;var selected:bool=false
			if valid:
				for edge:Dictionary in region.edges:
					if edge.entrance:continue
					var previous:=Vector3i(2147483647,0,0)
					for point:Vector3 in edge.points:
						var current:Vector3i=field.cell(point+Vector3(0,2,0))
						if previous.x!=2147483647 and current!=previous:key=previous;selected=true;break
						previous=current
					if selected:break
			var record:Dictionary={"family":family,"original_region":str(cell),"valid":valid,"selected":selected,"key":str(key)}
			if valid and selected:
				field.mesh_samples=0;field.cap_samples=0;var original:Array=work.build(key);record["original_mesh_samples"]=field.mesh_samples;var fresh:Dictionary=Frontiers.build(field,key);record["fresh_cap_samples"]=field.cap_samples;field.mesh_samples=0;field.cap_samples=0;var integrated:Dictionary=work.build_cell(key);record["integrated_mesh_samples"]=field.mesh_samples;record["integrated_cap_samples"]=field.cap_samples;record["geometry_exact"]=var_to_bytes(original)==var_to_bytes(integrated.arrays);record["caps_exact"]=var_to_bytes(fresh)==var_to_bytes(integrated.frontiers);record["faces"]=fresh.size();work.configuration.seal_stream_frontiers=false;var disabled:Dictionary=work.build_cell(key);var stripped:Dictionary=integrated.duplicate();stripped.erase("frontiers");record["off_exact"]=var_to_bytes(disabled)==var_to_bytes(stripped)
			result.append(record)
		)
		jobs.append({"task":task,"result":result,"owner":work})
	# Three real numeric workers;no scene/GPU/physics object is created there.
	for job:Dictionary in jobs:
		while not WorkerThreadPool.is_task_completed(job.task):await process_frame;OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(job.task);check(job.result.size()==1,"Actual worker returns one source-bound result")
		if job.result.is_empty():continue
		var record:Dictionary=job.result[0];records.append(record);check(record.valid and record.selected,"Original fixed host is admitted,not rerolled")
		if not record.valid or not record.selected:continue
		check(record.faces>0 and record.geometry_exact and record.caps_exact and record.off_exact,"Positive original boundary:complete integrated geometry/caps/disabled result exact")
		check(record.fresh_cap_samples==6534 and record.integrated_cap_samples==0 and record.integrated_mesh_samples==record.original_mesh_samples,"Reuse removes all6534extra canonical face samples without changing original extraction/normal sample count")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable actual sample-reuse source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_frontier_sample_reuse.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"records":records,"scope":"Three real numeric workers,original fixed seed73921 Spore/Insect/Alien regions. First deterministic original underground route cell boundary,not world reroll. Counted real field methods and full byte equality for canonical geometry,independently freshly sampled versus reused caps,and exact independent disabled result. Fixture formations/seepage zero to isolate mesh/closure samples. Eliminated redundant queries,not a process-memory or real-time timing/speedup certificate."},"  "));print("FRONTIER_SAMPLE_REUSE ",checks," records=",records," failures=",failures);quit(0 if failures.is_empty() else 1)
