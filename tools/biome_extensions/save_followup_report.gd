extends SceneTree
func read_report(name:String)->Dictionary:
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/"+name+".json"));assert(report is Dictionary,name)
	if report.has("failures"):assert(report.failures.is_empty(),name+" still fails")
	return report
func percentile(values:Array,f:float)->float:
	values.sort();return values[clampi(floori(values.size()*f),0,values.size()-1)] if not values.is_empty() else 0
func _initialize()->void:
	var tests:Dictionary={};var total:int=0
	for name:String in ["check_all","check_integration","check_sample_alias","check_features","check_liquids","check_waterfalls","check_spore_ecology","check_quarry_access","check_roundtrip","check_roundtrip_17041","check_roundtrip_98123","check_streamed_roundtrip"]:
		var report:Dictionary=read_report(name);tests[name]=report;total+=int(report.checks)
	var audit:Dictionary=read_report("check_completion_review");var rendered:Dictionary=read_report("render_all")
	for path:String in rendered.source_sha256:assert(FileAccess.get_sha256(path)==rendered.source_sha256[path],"Source changed after render "+path)
	var sources:Dictionary=rendered.source_sha256.duplicate()
	for path:String in ["res://data/biological_material_sources.json","res://assets/textures/biological/mycelium_albedo_v2.png","res://materials/biological_colors_v2.tres","res://materials/biological_color_mycelium_v2.res"]:sources[path]=FileAccess.get_sha256(path)
	var captures:Array=[]
	for name:String in ["render_all","render_features","render_mixed"]:captures.append_array(read_report(name).captures)
	for key:String in TerrainSettings.EXTENSION_KEYS:captures.append_array(read_report("render_regions_"+key).captures)
	var gpu:Array=[];var fill:Array=[];var wait:Array=[];var memory:Array=[]
	for capture:Dictionary in captures:
		if capture.gpu_p50_ms!=null:gpu.append(capture.gpu_p50_ms)
		fill.append(capture.initial_stream_fill_s);wait.append(capture.stream_wait_max_ms);memory.append(capture.video_bytes)
	var profiling:Dictionary={}
	for label:String in ["baseline","cpu_payload","collision_phases"]:
		var report:Dictionary=read_report("profile_streaming_alien_infected_"+label);var commits:Array=[];var stages:Array=[]
		for record:Dictionary in report.streaming:commits.append(record.commit_ms);stages.append(record.node_and_collision_stage_ms)
		profiling[label]={"chunks":commits.size(),"commit_p50_ms":percentile(commits,.5),"commit_p95_ms":percentile(commits,.95),"commit_max_ms":percentile(commits,1),"stage_p95_ms":percentile(stages,.95),"stage_max_ms":percentile(stages,1),"initial_fill_s":report.initial_fill_s}
	var queue=JSON.parse_string(FileAccess.get_file_as_string("res://data/biome_implementation_queue.json"))
	var result:Dictionary={"date":"2026-10-18","status":"completion_pass_in_progress","full_reference_quality_complete":false,"infinite_default_cave_complete":false,"cave_biome_registry_complete":false,"frozen_caverns_complete":false,"previous_phase_report":"data/biome_completion_validation_20261018.json","current_assertion_total":total,"tests":tests,"asset_validation":read_report("check_assets"),"gpu_payload_validation":read_report("check_gpu_payload"),"capture_integrity":audit,"current_core_source_sha256":sources,"native_capture_metrics":{"captures":captures.size(),"gpu_view_median_min_ms":percentile(gpu,0),"gpu_view_median_max_ms":percentile(gpu,1),"initial_fill_min_s":percentile(fill,0),"initial_fill_max_s":percentile(fill,1),"stream_wait_frame_max_ms":percentile(wait,1),"video_memory_min_bytes":percentile(memory,0),"video_memory_max_bytes":percentile(memory,1)},"earlier_followup_streaming_diagnostic":profiling,"profiling_caveat":"Three ordered Alien runs, not a randomized repeat distribution. Measured before the latest fungal/transition/rim revisions. Payload retains worker numeric collision arrays and removes mesh readback/duplicate cavity uploads; a 51.874 ms staging outlier still occurred. Not a claim that stalls are solved.","latest_queued_request":queue.entries[-1],"known_remaining":["Natural/reference-quality shape, material, regional/scenic-target work remains; artistic sign-off is false.","Finite spiral-shaft/gallery fixtures are not natural infinite connected cave networks or deep brain chambers.","Twelve static walks cover three seeds; the one actual streaming walk pauses to preload and is not uninterrupted performance certification.","Quarry grades cover eight admitted inland centreline routes on canonical and 2/4 m grids; not exhaustive capsule, mixed-owner, custom-scale or all-quarry traversal certification.","Generated mycelium is an original 1254-square albedo resampled to 2048, not a photographed PBR scan; mirrored/rotated shader borders do not prove source pixels are perfectly tileable.","Accelerated fixed-step headless physics sometimes emitted a Jolt job-capacity warning; no actual runtime-performance conclusion is drawn from its elapsed time.","Cold startup and streaming frame spikes remain measured performance work.","Infinite Default Cave foundation remains queued after surface completion. The new generic registry plus Default/Frozen brief is queued after that foundation, on the same network; no other cave biomes are authorized."]}
	result.known_remaining[-1]="Infinite Default Cave remains queued after surface completion, followed by the same-network registry plus Default/Frozen, then Crystal Caverns, then Magma Caverns. Later biome implementation is authorized only in that strict sequential order; no specialized cave biome is complete."
	FileAccess.open("res://data/biome_completion_followup_20261018.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("FOLLOWUP_REPORT_SAVED ",total," checks, ",captures.size()," native captures; completion remains false");quit()
