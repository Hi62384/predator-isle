extends "res://tools/caves/check_frozen_world_cohort.gd"
func digest(value)->String:
	var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(value));return hash.finish().hex_encode()
func run()->void:
	var path:String="res://tools/biome_extensions/artifacts/magma_first_portal_work.bin";var data:Dictionary=FileAccess.open(path,FileAccess.READ).get_var(false);var guards:Dictionary={path:FileAccess.get_sha256(path),get_script().resource_path:FileAccess.get_sha256(get_script().resource_path)}
	for name:String in DirAccess.get_files_at("res://scripts/caves"):
		if name.ends_with(".gd"):var source:String="res://scripts/caves/"+name;guards[source]=FileAccess.get_sha256(source)
	var b=owner("volcanic",17);var config=Config.new();config.enabled=true;config.biome_regions=FrozenFixture.registry(config.biome_regions,load("res://config/caves/biomes/magma_cave_definition.tres"));var code:=GDScript.new();code.source_code=FileAccess.get_file_as_string("res://scripts/caves/workload.gd").replace('const Context=preload("res://scripts/caves/surface_context.gd")','const Context=preload("res://tools/caves/trace_magma_surface_context.gd")');check(code.reload()==OK,"Read-only context failure trace loads");guards["res://tools/caves/trace_magma_surface_context.gd"]=FileAccess.get_sha256("res://tools/caves/trace_magma_surface_context.gd");var work=code.new();check(work.configure(b.settings,config,17,0),"Original source-workload worker configures")
	var part:int=0
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("part="):part=int(arg.trim_prefix("part="))
	var columns:Array=data.columns.keys();columns.sort_custom(func(a:Vector2i,c:Vector2i)->bool:return a.x<c.x or (a.x==c.x and a.y<c.y));var owned:Dictionary={}
	for index in range(columns.size()):
		if index%mini(4,columns.size())==part:owned[columns[index]]=true
	var output:Array=[];var began:int=Time.get_ticks_usec();var task:int=WorkerThreadPool.add_task(func()->void:output.append(work.portal(data.bundle,data.columns,data.parents,owned,part==0)))
	while not WorkerThreadPool.is_task_completed(task):await process_frame;OS.delay_usec(1000)
	WorkerThreadPool.wait_for_task_completion(task);check(output.size()==1,"Exact original production portal function returns a diagnostic result")
	var result:Dictionary=output[0];var elapsed:float=(Time.get_ticks_usec()-began)/1000000.0
	for source:String in guards:check(FileAccess.get_sha256(source)==guards[source],"Stable replay source "+source)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_magma_portal_replay_"+str(part)+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"part":part,"owned_columns":owned.keys(),"elapsed_seconds":elapsed,"portal_valid":result.get("valid",false),"portal_reason":result.get("reason",""),"cells":result.get("cells",[]).size(),"result_sha256":digest(result),"scope":"Read-only exact first failed production snapshot/normal worker replay. Passed means replay completed and source guards held;portal_valid/portal_reason retain actual extraction outcome. Not a passing live preload/performance gate;timing nonisolated."},"  "));print("MAGMA_PORTAL_REPLAY part=",part," valid=",result.get("valid",false)," reason=",result.get("reason","")," cells=",result.get("cells",[]).size()," seconds=",elapsed," failures=",failures);quit(0 if failures.is_empty() else 1)
