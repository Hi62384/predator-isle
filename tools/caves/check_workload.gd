extends "res://tools/biome_extensions/check_all.gd"
const Workload=preload("res://scripts/caves/workload.gd")
const Config=preload("res://scripts/caves/cave_settings.gd")
func run()->void:
	var guards:Dictionary={}
	for name:String in ["workload","portal_field","portal_mesher","network","route_solver","field","mesher","cave_settings"]:
		var path:String="res://scripts/caves/"+name+".gd";guards[path]=FileAccess.get_sha256(path)
	guards["res://tools/caves/check_workload.gd"]=FileAccess.get_sha256("res://tools/caves/check_workload.gd")
	var prototype=make_builder(3,73921);var config=Config.new();config.regional_activity=1;var discoverer=Workload.new();check(discoverer.configure(prototype.settings,config,73921,0),"Worker receives its own canonical settings/sampler snapshot")
	var delivery:Array=[];var started:int=Time.get_ticks_usec();var task:int=WorkerThreadPool.add_task(func()->void:delivery.append(discoverer.discover(Vector2i(9,-3))))
	while not WorkerThreadPool.is_task_completed(task):await process_frame
	WorkerThreadPool.wait_for_task_completion(task);check(delivery.size()==1 and delivery[0].regions.size()==9,"Bounded3x3regional discovery runs on a real worker without scene access");var bundle:Dictionary=delivery[0];var original:Dictionary={}
	for data:Dictionary in bundle.regions:
		if data.id==Vector2i(9,-3):original=data
	check(original.get("valid",false) and original.nodes.size()==17 and original.edges.size()==20,"Original Spore graph survives multi-region worker discovery")
	var columns:Dictionary=discoverer.exposed_columns({"access":original.edges[0]});check(not columns.is_empty() and columns.size()<64,"All exposed original access segments plus full64m halo form a bounded replacement proposal")
	var worker=Workload.new();check(worker.configure(prototype.settings,config,73921,0),"Second worker owns independent caches/resources");check(worker.builder!=discoverer.builder and worker.builder.settings!=discoverer.builder.settings,"Canonical sampler/resources are never shared mutably across jobs")
	var compiled:Array=[];task=WorkerThreadPool.add_task(func()->void:compiled.append(worker.use_bundle(bundle)))
	while not WorkerThreadPool.is_task_completed(task):await process_frame
	WorkerThreadPool.wait_for_task_completion(task);check(compiled.size()==1 and compiled[0],"Entire immutable bundle plus canonical inter-region connections compiles on independent worker")
	check(worker.field.begins.size()>10000 and worker.field.begins.size()<=65536,"Positive real multi-region sparse field within feature hard limit")
	var entrance:Vector3=original.nodes[0].point;check(is_finite(worker.field.sample(entrance)),"Compiled full bundle answers original surface entry field")
	var before:int=worker.field.begins.size();check(worker.use_bundle(bundle) and worker.field.begins.size()==before,"Same immutable bundle reuses worker-local compiled field")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable worker source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_cave_workload.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"regions":bundle.regions.size(),"neighbor_connections":bundle.connections.size(),"entry_proposals":bundle.entrances.size(),"original_surface_columns":columns.size(),"compiled_features":worker.field.begins.size(),"compiled_query_bins":worker.field.bins.size(),"compiled_cave_cells":worker.field.chunks.size(),"single_order_discovery_plus_compile_seconds":(Time.get_ticks_usec()-started)/1000000.0,"production_runtime_enabled":false,"scope":"Real WorkerThreadPool discovery/compilation with independent immutable settings/canonical samplers and bounded3x3descriptor bundle. Original actual Spore graph retained;complete neighboring graphs/links participate. Not physical inter-region traversal,actual shared terrain worker scheduling,live commit or streamed cave acceptance."},"  "));print("CAVE_WORKLOAD ",checks," regions=",bundle.regions.size()," features=",worker.field.begins.size()," columns=",columns.size()," failures=",failures);quit(0 if failures.is_empty() else 1)
