extends SceneTree
func _initialize()->void:call_deferred("run")
func total(records:Array,key:String)->float:
	var result:float=0
	for record:Dictionary in records:result+=float(record.get(key,0))
	return result
func maximum(records:Array,key:String)->float:
	var result:float=0
	for record:Dictionary in records:result=maxf(result,float(record.get(key,0)))
	return result
func median(values:Array)->float:values.sort();return values[values.size()/2]
func run()->void:
	var prefix:String="timed_root";var query_study:bool=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("prefix="):prefix=arg.trim_prefix("prefix=")
		if arg=="study=query":query_study=true
	assert(prefix.is_valid_identifier())
	var hashes:Dictionary={"res://tools/biome_extensions/review_conduit_memo_streaming.gd":FileAccess.get_sha256("res://tools/biome_extensions/review_conduit_memo_streaming.gd")};var captures:Dictionary={};var rows:Array=[];var failures:Array=[];var fill_ratios:Array=[];var wait_ratios:Array=[];var cpu_ratios:Array=[]
	for repeat in range(3):
		var pair:Dictionary={}
		for enabled:bool in [false,true]:
			var label:String=prefix+"_"+("on" if enabled else "off")+"_"+str(repeat);var path:String="res://tools/biome_extensions/artifacts/profile_streaming_alien_infected_"+label+".json"
			var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report is Dictionary and report.passed and report.actual_render and report.scenario=="root" and report.view_distance==50000)
			assert(report.conduit_cache_mib==(8 if query_study else (8 if enabled else 0)) and report.runs.size()==5 and report.captures.size()==5)
			assert(report.network_query_cache_enabled==(enabled if query_study else true),"Isolate query versus conduit memo controls")
			hashes[path]=FileAccess.get_sha256(path)
			for source:String in report.source_sha256:
				assert(FileAccess.get_sha256(source)==report.source_sha256[source],"Stale native profile source "+source)
				if hashes.has(source):assert(hashes[source]==report.source_sha256[source],"Different production revisions in paired runs")
				hashes[source]=report.source_sha256[source]
			for view:Dictionary in report.captures:
				var png:String="res://tools/biome_extensions/artifacts/"+view.biome+"_"+view.view+".png";assert(view.committed and FileAccess.get_sha256(png)==view.sha256)
				var pixels:=Image.load_from_file(png);assert(pixels!=null and pixels.get_size()==Vector2i(1280,720));captures[png]=view.sha256
			for worker:Dictionary in report.worker_conduit_caches:
				assert(worker.numeric_bytes<=(8*1024*1024 if enabled or query_study else 0) and worker.entries<=(32 if enabled or query_study else 0))
			assert(report.worker_network_query_caches.size()==report.worker_conduit_caches.size())
			for worker:Dictionary in report.worker_network_query_caches:
				assert(worker.tiles<=512 and worker.admission_tiles<=512)
				if query_study and not enabled:assert(worker.tiles==0 and worker.admission_tiles==0)
			for cut:Dictionary in report.runs:assert(cut.committed==cut.revision and cut.has("cut_wait_s"))
			var row:Dictionary={"repeat":repeat,"cache_enabled":enabled,"source_report":path,"initial_fill_s":report.initial_fill_s,"total_replacement_cut_wait_s":total(report.runs,"cut_wait_s"),"summed_worker_elapsed_ms":total(report.streaming,"worker_ms"),"generated_chunk_records":report.streaming.size(),"maximum_stream_wait_frame_ms":maximum(report.captures,"stream_wait_max_ms"),"maximum_partition_swap_ms":report.max_partition_swap_ms,"observed_workers":report.worker_conduit_caches.size(),"cache_numeric_bytes":total(report.worker_conduit_caches,"numeric_bytes"),"cache_hits":total(report.worker_conduit_caches,"hits"),"cache_misses":total(report.worker_conduit_caches,"misses"),"runs":report.runs}
			rows.append(row);pair[enabled]=row
			row["network_query_cache_enabled"]=report.network_query_cache_enabled;row["serialized_query_metadata_bytes"]=total(report.worker_network_query_caches,"serialized_metadata_bytes");row["query_tile_hits"]=total(report.worker_network_query_caches,"tile_hits")
		assert(pair[false].runs.size()==pair[true].runs.size())
		for i in range(pair[false].runs.size()):assert(pair[false].runs[i].camera==pair[true].runs[i].camera,"Same real camera path in both candidates")
		assert(pair[false].total_replacement_cut_wait_s>0 and pair[false].summed_worker_elapsed_ms>0)
		fill_ratios.append(pair[true].initial_fill_s/pair[false].initial_fill_s);wait_ratios.append(pair[true].total_replacement_cut_wait_s/pair[false].total_replacement_cut_wait_s);cpu_ratios.append(pair[true].summed_worker_elapsed_ms/pair[false].summed_worker_elapsed_ms)
	assert(captures.size()==30)
	for source:String in hashes:assert(FileAccess.get_sha256(source)==hashes[source],"Source changed during native review")
	var summary:Dictionary={"paired_median_initial_fill_ratio":median(fill_ratios),"paired_median_replacement_cut_wait_ratio":median(wait_ratios),"paired_median_summed_worker_elapsed_ratio":median(cpu_ratios),"maximum_observed_wait_frame_ms":maximum(rows,"maximum_stream_wait_frame_ms"),"maximum_retained_numeric_cache_bytes":maximum(rows,"cache_numeric_bytes"),"pairs":3,"captures":captures.size()}
	summary["maximum_serialized_query_metadata_bytes"]=maximum(rows,"serialized_query_metadata_bytes");summary["study"]="network_query_tiles" if query_study else "conduit_memo"
	var destination:String="res://tools/biome_extensions/artifacts/"+("profile_network_tile_streaming_" if query_study else "profile_conduit_memo_streaming_")+prefix+".json"
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"actual_render":true,"records":rows,"summary":summary,"capture_sha256":captures,"source_sha256":hashes,"performance_completion":false,"all_user_tasks_complete":false,"scope":"Three alternating off/on native root-focused streaming pairs at one actual seeded site, identical five-teleport camera path, 50km far plane, complete cuts and real bounded worker counters. Direct replacement-cut waits exclude planning; initial fill excludes process launch/instantiation. Per-worker elapsed sums overlap across threads: not hardware CPU utilisation or wall time. Warm frame/GPU samples and wait-frame spikes do not certify uninterrupted traversal, cold launch or whole-world performance."},"  "))
	print("CONDUIT_MEMO_NATIVE_REVIEW ",prefix," ",summary);quit()
