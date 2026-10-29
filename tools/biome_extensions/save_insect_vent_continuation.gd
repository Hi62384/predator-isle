extends SceneTree
const PREVIOUS="res://tools/biome_extensions/artifacts/revisions/experiment_coastal_height_cache_adoption_60547d2bad62"
var hashes:Dictionary={}
func bind(path:String)->void:
	assert(FileAccess.file_exists(path));hashes[path]=FileAccess.get_sha256(path)
func validate(path:String)->Dictionary:
	bind(path)
	var report=JSON.parse_string(FileAccess.get_file_as_string(path));assert(report.passed)
	if report.has("failures"):assert(report.failures.is_empty())
	for raw:String in report.source_sha256:
		var canonical:String=raw if raw.begins_with("res://") else "res://"+raw.replace("\\","/")
		assert(FileAccess.get_sha256(canonical)==report.source_sha256[raw],"Stale continuation source "+canonical);bind(canonical)
	return report
func _initialize()->void:
	bind("res://tools/biome_extensions/save_insect_vent_continuation.gd")
	var old_report_path:String=PREVIOUS+"/evidence/tools/biome_extensions/artifacts/coastal_height_cache_adoption.json";bind(old_report_path)
	var previous=JSON.parse_string(FileAccess.get_file_as_string(old_report_path));assert(previous.passed)
	var base:String=PREVIOUS+"/sources/scripts/biome_extension_structures.gd.txt";bind(base)
	assert(FileAccess.get_sha256(base)==previous.source_sha256["res://scripts/biome_extension_structures.gd"])
	var expected:String=FileAccess.get_file_as_string(base).replace("\r\n","\n")
	var original_signature:String="func mound(builder,anchor:Vector3,width:float,height:float,archetype:int,phase:float,color:Color)->void:"
	assert(expected.count(original_signature)==1)
	expected=expected.replace(original_signature,"func mound(builder,anchor:Vector3,width:float,height:float,archetype:int,phase:float,color:Color,vent_depth:float=0)->void:")
	var cap:String="\tfor i in range(sides):triangle(rings[24][i],rings[24][(i+1)%sides],top,color)"
	assert(expected.count(cap)==1)
	expected=expected.replace(cap,"\tif vent_depth>0:preload(\"res://scripts/insect_vent_geometry.gd\").emit(self,rings[24],vent_depth,color)\n\telse:\n\t"+cap)
	var primary:String="\t\t\t\t\tmound(builder,anchor,scale*.4,scale,type,d.angle,color)"
	assert(expected.count(primary)==1)
	expected=expected.replace(primary,"\t\t\t\t\tvar vent_depth:float=0\n\t\t\t\t\tif type in [0,3,5] and scale>=40 and sampler.random(x,z,178)<sampler.settings.nest_vent_frequency:\n\t\t\t\t\t\tvent_depth=preload(\"res://scripts/insect_vent_geometry.gd\").admitted_depth(builder,anchor,scale*.4,scale,d.angle,minf(scale*.18,24))\n\t\t\t\t\tmound(builder,anchor,scale*.4,scale,type,d.angle,color,vent_depth)")
	assert(expected==FileAccess.get_file_as_string("res://scripts/biome_extension_structures.gd").replace("\r\n","\n"),"Only the declared Insect primary-vent integration may change the shared emitter")
	var settings_base:String=PREVIOUS+"/sources/scripts/biome_extension_settings.gd.txt";bind(settings_base)
	assert(FileAccess.get_sha256(settings_base)==previous.source_sha256["res://scripts/biome_extension_settings.gd"])
	var old_settings:String=FileAccess.get_file_as_string(settings_base).replace("\r\n","\n")
	var marker:String="@export_range(0,1,.05) var excavation_strength:float=.7\n"
	assert(old_settings.count(marker)==1)
	old_settings=old_settings.replace(marker,marker+"## Physical, thick summit ducts on selected mature cathedral/dome/rocky nests.\n## Blind recesses, not traversable colony entrances; zero preserves old caps.\n@export_range(0,1,.05) var nest_vent_frequency:float=.25\n")
	assert(old_settings==FileAccess.get_file_as_string("res://scripts/biome_extension_settings.gd").replace("\r\n","\n"))
	assert(FileAccess.get_sha256("res://scripts/terrain_mesh_builder.gd")==previous.source_sha256["res://scripts/terrain_mesh_builder.gd"],"Previously adopted cache logic stays unchanged")
	var numeric:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_vents.json")
	var native:Dictionary=validate("res://tools/biome_extensions/artifacts/render_insect_vents.json")
	var cost:Dictionary=validate("res://tools/biome_extensions/artifacts/profile_insect_vents.json")
	var regression:Dictionary=validate("res://data/surface_regression_20261018.json")
	assert(numeric.checks==331294 and numeric.geometry_cases==27 and numeric.native_floor_and_lining_rays==21 and numeric.cases.size()==3)
	assert(native.captures.size()==9 and native.worker_proofs.size()==3 and cost.pairs.size()==12 and regression.test_count==31)
	for capture:Dictionary in native.captures:
		var path:String="res://tools/biome_extensions/artifacts/"+capture.biome+"_"+capture.view+".png"
		assert(FileAccess.get_sha256(path)==capture.sha256)
	var report:Dictionary={"passed":true,"failures":[],"completed_utc":Time.get_datetime_string_from_system(true),"production_registration":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"source_sha256":hashes,"captures":native.captures,"physical_checks":numeric.checks,"mound_variants":numeric.geometry_cases,"native_floor_and_lining_rays":21,"real_sites":numeric.cases,"actual_worker_and_collision_proofs":native.worker_proofs,"shared_regression_scripts":31,"generation_cost_pairs":12,"median_added_generation_ms":cost.median_added_ms,"median_generation_ratio":cost.median_ratio,"added_vertices_per_admitted_primary":504,"new_texture_resources":0,"previous_cache_policy_unchanged":true,"only_declared_shared_emitter_and_settings_changes":true,"runner_observations_transcribed":{"native_sampled_peak_private_mib":1510.1,"native_cap_mib":2048,"numeric_sampled_peak_private_mib":130.4,"numeric_cap_mib":768,"isolated_cost_sampled_peak_private_mib":81.8,"isolated_cost_cap_mib":512,"sample_period_ms":500,"isolation":"No other Godot process observed at 500ms samples during the cost run; shorter overlaps are not excluded. These external runner receipts are transcribed, not independent engine-log records."},"scope":"Physical blind summit ducts on selected mature cathedral/dome/rocky primary mounds. Independent .25 frequency, exact original zero mode, above-ground/water admission, thick annular rim, inward lining, visible floor and original buried base. Stable parent/child ownership, actual full worker payload and streamed near collision, nine actual native views, measured CPU cost and all 31 shared regressions. Text-only original comparison normalizes line endings while complete file hashes remain bound. No new terrain holes, infinite caves, traversable chimney, broad Insect artistic/completion or whole-project claim. Previous cache and other older checkpoints remain historical by their hashes."}
	FileAccess.open("res://tools/biome_extensions/artifacts/insect_vent_continuation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open("res://data/insect_vent_continuation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("INSECT_VENT_CONTINUATION ",hashes.size()," source guards, nine actual images");quit()
