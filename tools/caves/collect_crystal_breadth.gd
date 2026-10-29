extends "res://tools/biome_extensions/check_all.gd"
const ROOT:String="res://tools/biome_extensions/artifacts/"
const TARGETS:Array[String]=["family_0","family_1","family_2","family_3","family_4","family_5","amethyst_geode","layout_0","layout_3","layout_4","profile_geode","profile_ravine","extent_medium","extent_near_1500","host_badlands","host_mountain","host_quarry","host_radiation_wasteland","host_volcanic","host_wise_mountains"]
var guards:Dictionary={}
var capture_hashes:Dictionary={}
func load_report(name:String,runtime_current:bool=true)->Dictionary:
	var path:String=ROOT+name+".json";check(FileAccess.file_exists(path),"Required retained native report "+name)
	if not FileAccess.file_exists(path):return {}
	var report=JSON.parse_string(FileAccess.get_file_as_string(path));check(report is Dictionary and report.get("passed",false) and report.get("failures",["missing"]).is_empty(),"Completed native semantic report "+name)
	if not report is Dictionary or not report.get("passed",false):return {}
	guards[path]=FileAccess.get_sha256(path)
	if runtime_current:
		for source:String in report.get("source_sha256",{}):
			# Tool changes do not rebind archived experiments. Only current
			# production/content dependencies are asserted for this new ledger.
			if source.begins_with("res://scripts/") or source.begins_with("res://shaders/") or source.ends_with(".tres") or source in ["res://scenes/main.tscn","res://project.godot"]:
				check(FileAccess.get_sha256(source)==report.source_sha256[source],"Same current runtime dependency "+source+" in "+name);guards[source]=report.source_sha256[source]
	for capture:String in report.get("capture_sha256",{}):check(FileAccess.get_sha256(capture)==report.capture_sha256[capture],"Retained exact native pixels "+capture);capture_hashes[capture]=report.capture_sha256[capture]
	return report
func run()->void:
	guards[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path);var rows:Array=[];var lod_positive:int=0;var total_cpu:Array=[];var total_gpu:Array=[];var maximum_native_memory_mib:float=0;var all_walks:int=0
	for target:String in TARGETS:
		var report:Dictionary=load_report("render_cave_crystal_profiled_fixed_"+target)
		if report.is_empty():continue
		var controls:Dictionary=report.material_checks;lod_positive+=int(controls.native_lod_reduces_submitted_primitives);check(controls.lod_exact_return,"Exact native near/far/near image return "+target)
		for sample:Dictionary in controls.get("stationary_viewport_time_samples",[]):
			if float(sample.cpu_ms)>0:total_cpu.append(float(sample.cpu_ms))
			if float(sample.gpu_ms)>0:total_gpu.append(float(sample.gpu_ms))
		var receipt_path:String="res://.godot/extensions_render_profiled_"+target+".receipt.json";var receipt=JSON.parse_string(FileAccess.get_file_as_string(receipt_path));check(receipt is Dictionary and receipt.get("passed",false),"Complete native engine receipt "+target)
		if receipt is Dictionary and receipt.get("passed",false):
			guards[receipt_path]=FileAccess.get_sha256(receipt_path)
			if receipt.get("sampled_peak_private_bytes")!=null:maximum_native_memory_mib=maxf(maximum_native_memory_mib,float(receipt.sampled_peak_private_bytes)/1048576.0)
		for walk:Dictionary in report.walks:check(walk.finished and not walk.failed and walk.waypoint==walk.waypoints and float(walk.maximum_unsupported_drop_m)<.75,"Every original ordinary native return "+target);all_walks+=1
		var selection_path:String=ROOT+"check_cave_crystal_fixed_scene_"+target+".json";var selection=JSON.parse_string(FileAccess.get_file_as_string(selection_path));guards[selection_path]=FileAccess.get_sha256(selection_path)
		rows.append({"target":target,"original_location":selection.first_candidates[target],"checks":report.checks,"crystals":report.actual_crystal_prisms,"veins":report.vein_segments,"native_cells":report.native_cells,"native_rock_vertices":report.rock_vertices,"native_mineral_vertices":report.mineral_vertices,"render_profile":controls,"walks":report.walks,"report_path":ROOT+"render_cave_crystal_profiled_fixed_"+target+".json","receipt_path":receipt_path})
	check(rows.size()==20 and lod_positive>0 and maximum_native_memory_mib>0 and maximum_native_memory_mib<2048,"All20original unique normal scenes,positive actual index-LOD reductions and bounded sampled native memory")
	var supporting:Dictionary={}
	for name:String in ["check_cave_live_crystal_return","check_cave_floor_relief_adoption","check_cave_crystal_features","check_cave_crystal_foundation","render_cave_crystal_transition_default_crystal","render_cave_crystal_transition_frozen_crystal","render_cave_crystal_shallow_current","render_cave_crystal_current_fixed_rare_luminous","render_cave_crystal_lake_current"]:
		var report:Dictionary=load_report(name)
		if not report.is_empty():supporting[name]={"path":ROOT+name+".json","checks":report.checks,"scope":report.scope}
	var native_receipts:Dictionary={}
	for prefix:String in ["current_floor_full_return","render_crystal_frozen_transition","render_crystal_default_transition_window","current_crystal_shallow","current_crystal_rare_luminous","current_crystal_lake"]:
		var receipt_path:String="res://.godot/extensions_"+prefix+".receipt.json";var receipt=JSON.parse_string(FileAccess.get_file_as_string(receipt_path));check(receipt is Dictionary and receipt.get("passed",false),"Complete supporting native engine receipt "+prefix)
		if not receipt is Dictionary or not receipt.get("passed",false):continue
		guards[receipt_path]=FileAccess.get_sha256(receipt_path);native_receipts[prefix]=receipt
		for suffix:String in ["engine.log","out.log","err.log"]:
			var path:String="res://.godot/extensions_"+prefix+"."+suffix;check(FileAccess.file_exists(path),"Original supporting native runner log "+path)
			if FileAccess.file_exists(path):guards[path]=FileAccess.get_sha256(path)
	var surface_path:String="res://data/surface_regression_20261018.json";var surface=JSON.parse_string(FileAccess.get_file_as_string(surface_path));check(surface is Dictionary and surface.get("passed",false) and int(surface.test_count)==31,"Complete latest shared31surface regressions")
	if surface is Dictionary:
		guards[surface_path]=FileAccess.get_sha256(surface_path)
		for raw:String in surface.get("source_sha256",{}):var source:String="res://"+raw.replace("\\","/");check(FileAccess.get_sha256(source)==surface.source_sha256[raw],"Same shared regression runtime "+source);guards[source]=surface.source_sha256[raw]
	total_cpu.sort();total_gpu.sort();var timing:Dictionary={"cpu_samples":total_cpu.size(),"gpu_samples":total_gpu.size(),"scope":"Positive actual30-frame stationary viewport samples per normal scene,Compatibility renderer,other Godot sessions intentionally running. No isolated or uninterrupted traversal FPS/frame-budget claim."}
	if not total_cpu.is_empty():timing["cpu_median_ms"]=total_cpu[total_cpu.size()/2];timing["cpu_p95_ms"]=total_cpu[mini(total_cpu.size()-1,floori(total_cpu.size()*.95))]
	if not total_gpu.is_empty():timing["gpu_median_ms"]=total_gpu[total_gpu.size()/2];timing["gpu_p95_ms"]=total_gpu[mini(total_gpu.size()-1,floori(total_gpu.size()*.95))]
	for source:String in guards:check(FileAccess.get_sha256(source)==guards[source],"Stable current collected evidence/runtime "+source)
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"capture_sha256":capture_hashes,"normal_scenes":rows,"supporting_components":supporting,"supporting_native_receipts":native_receipts,"normal_native_walks":all_walks,"positive_native_lod_scenes":lod_positive,"maximum_native_sampled_private_mib":maximum_native_memory_mib,"stationary_renderer_timing":timing,"saved_registry_at_capture":["default","frozen"],"root_enabled":false,"all_user_tasks_complete":false,"reference_art_acceptance":false,"scope":"Current production dependency and retained-pixel ledger for20original unique normal mineral/host/layout/profile/extent scenes plus full live return,independent floor adoption,six-family geometry,distribution,actual Default/Frozen transitions,shallow38m chamber,normal rare emission and retained lake. Historical catalogue hashes and older component source maps are never rebound;fixed locations revalidated separately. Native functional/LOD/render measurements do not certify all50visual cases or14reference-quality scenes,uninterrupted FPS,cold startup,root activation,Magma or all-user completion. Saved registry migration has its own subsequent proof."}
	FileAccess.open(ROOT+"check_cave_crystal_current_breadth.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CRYSTAL_CURRENT_BREADTH ",checks," scenes=",rows.size()," lod=",lod_positive," memory_mib=",maximum_native_memory_mib," timing=",timing," failures=",failures.slice(0,6));quit(0 if failures.is_empty() else 1)
