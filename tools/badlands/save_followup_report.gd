extends SceneTree
var source_failures:Array[String]=[]
func read_report(name:String)->Dictionary:
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://tools/badlands/artifacts/"+name+".json"))
	assert(report is Dictionary,"Missing report "+name)
	if report.has("failures"):assert(report.failures.is_empty(),"Failed report "+name)
	if report.has("passed"):assert(report.passed,"Report did not pass: "+name)
	return report
func verify_sources(report:Dictionary)->void:
	for pair:Array in [["sampler_sha256","res://scripts/badlands_sampler.gd"],["builder_sha256","res://scripts/terrain_mesh_builder.gd"],["chunk_terrain_sha256","res://scripts/chunk_terrain.gd"],["shader_sha256","res://shaders/badlands_material.gdshaderinc"]]:
		if report.has(pair[0]) and FileAccess.get_sha256(pair[1])!=report[pair[0]]:source_failures.append("Stale evidence: "+pair[1])
	for path:String in report.get("source_sha256",{}):
		if FileAccess.get_sha256(path)!=report.source_sha256[path]:source_failures.append("Stale evidence: "+path)
func _initialize()->void:
	var tests:Dictionary={};var total:int=0
	for name:String in ["invariants","check_geology","check_regional_hills","check_segment_index","check_catchment_support","check_hoodoos","check_palette","check_clay_gullies","check_incised_profiles","check_detail_selection","check_compact_seams","check_normal_interleave","check_collision_precision","check_native_landmarks","check_streamed_wash"]:
		var report:Dictionary=read_report(name);verify_sources(report);tests[name]=report;total+=int(report.checks)
	var gpu:Dictionary={}
	for name:String in ["check_geology_gpu","check_geology_gpu_scaled","check_palette_gpu","check_color_space_gl_compatibility","check_color_space_forward_plus","check_material_roles"]:
		var report:Dictionary=read_report(name);verify_sources(report);gpu[name]=report
	var review:Dictionary=read_report("render_review");verify_sources(review)
	assert(review.actual_render and review.complete,"Native review must finish")
	assert(review.camera_far_m==50000 and review.maximum_lod==6,"Full draw distance and terrain hierarchy must be retained")
	var locations:Dictionary={}
	for capture:Dictionary in review.captures:
		var path:String="res://tools/badlands/artifacts/views/"+capture.feature+"_"+capture.view+".png"
		assert(FileAccess.get_sha256(path)==capture.png_sha256,"Changed capture "+path)
		assert(capture.committed_revision==capture.partition_revision,"Uncommitted capture")
		locations[capture.feature]=true
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/badlands_previews.json"))
	assert(review.captures.size()==manifest.features.size()*6 and locations.size()==manifest.features.size(),"Incomplete native review")
	var benchmarks:Dictionary={}
	for name:String in ["benchmark_cubic_cache","benchmark_segment_index","benchmark_normal_interleave","benchmark_grade_bound","benchmark_badlands","benchmark_grass"]:
		var report:Dictionary=read_report(name);verify_sources(report);benchmarks[name]=report
	var transition:Dictionary=read_report("render_palette_transition");verify_sources(transition)
	assert(transition.actual_render and transition.nine_slot_material_nodes>0 and transition.captures.size()==2)
	for capture:Dictionary in transition.captures:
		var path:String="res://tools/biome_extensions/artifacts/"+capture.biome+"_"+capture.view+".png"
		assert(capture.committed and FileAccess.get_sha256(path)==capture.sha256,"Changed or uncommitted transition capture")
	var ownership=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain_settings_ownership_20261018.json"))
	assert(ownership is Dictionary and ownership.passed and ownership.failures.is_empty())
	verify_sources(ownership);tests.settings_ownership=ownership;total+=int(ownership.checks)
	var normal:Dictionary=read_report("normal_visibility");verify_sources(normal)
	assert(normal.actual_render and normal.records.size()==4)
	var result:Dictionary={"date":"2026-10-18","status":"completion_pass_in_progress","full_reference_quality_complete":false,"artistic_signoff":false,"infinite_default_cave_complete":false,"cave_biome_registry_complete":false,"frozen_caverns_complete":false,"crystal_caverns_complete":false,"magma_caverns_complete":false,"scope":"Badlands continuation only; previous whole-queue reports retain their own historical source hashes","assertions":total,"tests":tests,"gpu_tests":gpu,"native_capture_count":review.captures.size(),"native_locations":locations.size(),"native_renderer":review.renderer,"native_adapter":review.adapter,"source_sha256":review.source_sha256,"normal_visibility":read_report("normal_visibility"),"palette_transition":transition,"benchmarks":benchmarks,"implemented":["Continuous geological dip/folds and unequal thickness; CPU/GPU alignment including height multiplier and sea level","Connected source gullies with smooth regional eligibility and convex-up eroded walls","Geology-aligned varied terrain-supported caprock; no separate decorative props","Continuous regional material weights in existing numeric atlas; one-slot and nine-slot layouts preserve other owners and retained water","Canonical-array ownership fix, bounded FIFO and exact polynomial interpolation cache","Conservative drainage spatial index with exact full-scan and complete-array comparisons"],"known_remaining":["Natural/reference-quality landforms and every scenic target are not approved: rounded interfluves, coarse distant gullies and repetitive broad geology still need work.","Heightfield-supported caprock has no detached caps, true overhangs or narrow undercut columns.","Material roles use documented existing PBR appearance analogues, not mineral-certified clay/shale/mudstone scans.","The one 2.74km wash walk pauses for preloading; it is not all-world, all-seed, custom-scale or uninterrupted streaming certification.","Native benchmarks and isolated numerical builds are separate scopes. Cold shader compilation and worst-case distant generation remain performance work.","Desert and Mesa are not live owners in the current terrain; their requested transition demonstrations remain unsupported.","Earlier surface work remains unfinished. Infinite Default Cave, registry/Default/Frozen, Crystal and Magma remain unimplemented, in that strict order."]}
	result.normal_visibility=normal
	result.implemented.append("Independent scene/worker snapshots include all sixteen external biome configurations; controlled fixtures cannot leak settings")
	result.implemented.append("Denser connected hillslope tributaries; erosion strength controls the physical valley width rather than shallow serial dents")
	result.implemented.append("Measured secondary incisions and cross-sections across three seeds; local rugged-region detail selection without changing other owners")
	result.implemented.append("Renderer-correct authored geological colours, measured against source_color textures in native Compatibility and Forward+ swatch tests")
	result.implemented.append("Narrow joint-eroded caprock, local-height-extended visual skirts, exact sparse-normal scheduling and conservative grade rejection")
	result.implemented.append("Province-specific physical painted/clay hills; zero strength preserves six complete prior terrain/water/atlas outputs across three seeds")
	result.implemented.append("Derivative-filtered subordinate sediment bedding; procedural relief obeys normal-off/detail controls, with exact native zero-strength/off agreement in four regions")
	result.implemented.append("Steep near-terrain collision uses exact visible triangles when the estimated Jolt heightfield quantization bound exceeds one centimetre; flat near tiles retain compact heightfields and distant tiles allocate no collision")
	result.known_remaining[0]="Reference-quality landforms and every scenic target are not approved: broad sediment bands, overly smooth distant faces and some repeated channel silhouettes remain visible in current captures."
	var cache_work:Dictionary=read_report("profile_cache_reuse");verify_sources(cache_work)
	result.cache_work_diagnostic=cache_work
	var drainage:Dictionary=read_report("profile_channel_grades");verify_sources(drainage)
	var drainage_counts:Dictionary={}
	for item:Dictionary in drainage.actual_downhill_traces:
		var terminal:String=item.trace.terminal;drainage_counts[terminal]=int(drainage_counts.get(terminal,0))+1
	result.drainage_diagnostic={"profiles":drainage.cases.size(),"net_descriptor_reversals":drainage.gross_net_reverse_cases.size(),"actual_trace_terminals":drainage_counts,"scope":drainage.scope,"sampler_sha256":drainage.sampler_sha256}
	result.known_remaining.append("The canonical downhill diagnostic is not a hydraulic simulation or a guarantee of depression-free drainage; see the current trace terminal counts.")
	var shared=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_regression_20261018.json"))
	assert(shared is Dictionary and shared.passed and shared.test_count==31);verify_sources(shared);result.shared_surface_regression=shared
	result.report_generator_sha256=FileAccess.get_sha256("res://tools/badlands/save_followup_report.gd")
	# A GDScript assertion inside a helper only returns from that helper. Never
	# write a report after a nested source check failed, even if the runner will
	# subsequently detect the engine error. Validate at the write boundary.
	if not source_failures.is_empty():
		push_error("Follow-up evidence rejected: "+str(source_failures));quit(1);return
	result.evidence_validated=true
	FileAccess.open("res://data/badlands_completion_followup_20261018.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("BADLANDS_FOLLOWUP_SAVED ",total," assertions; completion remains false");quit()
