extends "res://tools/biome_extensions/save_insect_vent_continuation.gd"
const VENT_BASE="res://tools/biome_extensions/artifacts/revisions/experiment_insect_vent_continuation_8ddeb9cbb953"
func replace_once(source:String,old:String,replacement:String)->String:
	assert(source.count(old)==1,"Unexpected dome integration baseline: "+old.left(80))
	return source.replace(old,replacement)
func _initialize()->void:
	for path:String in ["res://tools/biome_extensions/save_insect_dome_continuation.gd","res://tools/biome_extensions/save_insect_vent_continuation.gd"]:bind(path)
	var prior_path:String=VENT_BASE+"/evidence/tools/biome_extensions/artifacts/insect_vent_continuation.json";bind(prior_path)
	var previous=JSON.parse_string(FileAccess.get_file_as_string(prior_path));assert(previous.passed)
	var baseline:String=VENT_BASE+"/sources/scripts/biome_extension_structures.gd.txt";bind(baseline)
	assert(FileAccess.get_sha256(baseline)==previous.source_sha256["res://scripts/biome_extension_structures.gd"])
	var expected:String=FileAccess.get_file_as_string(baseline).replace("\r\n","\n")
	expected=replace_once(expected,"vent_depth:float=0)->void:\n","vent_depth:float=0,broad_dome:bool=false)->void:\n\tassert(not broad_dome or archetype==3)\n")
	var radial:String="\t\t\tif archetype==3:radius=width*sqrt(maxf(.005,1-t*t))\n"
	expected=replace_once(expected,radial,radial+"\t\t\tif broad_dome:radius*=1+.10*sin(a*3+phase)+.04*sin(a*7-phase+t*.4)\n")
	expected=replace_once(expected,"sin(a)*radius*(.22 if archetype==2 else 1)","sin(a)*radius*(.82 if broad_dome else (.22 if archetype==2 else 1))")
	var family_loop:String="\tfor family_id in [5,6,7]:\n"
	expected=replace_once(expected,family_loop,"\tvar insect_portals:Array=[]\n\tvar insect_portals_ready:bool=false\n"+family_loop)
	var old_primary:String="\t\t\t\t\tvar vent_depth:float=0\n\t\t\t\t\tif type in [0,3,5] and scale>=40 and sampler.random(x,z,178)<sampler.settings.nest_vent_frequency:\n\t\t\t\t\t\tvent_depth=preload(\"res://scripts/insect_vent_geometry.gd\").admitted_depth(builder,anchor,scale*.4,scale,d.angle,minf(scale*.18,24))\n\t\t\t\t\tmound(builder,anchor,scale*.4,scale,type,d.angle,color,vent_depth)"
	var new_primary:String="\t\t\t\t\tvar broad_dome:bool=type==3 and sampler.settings.nest_broad_domes\n\t\t\t\t\t# Do not expand the footprint into an existing reserved entrance.\n\t\t\t\t\tif broad_dome:\n\t\t\t\t\t\t# Do not query nearby portals for an empty or non-dome tile.\n\t\t\t\t\t\tif not insect_portals_ready:\n\t\t\t\t\t\t\tif portal_provider.is_valid():insect_portals=portal_provider.call(bounds.grow(sampler.settings.nest_height*1.45*1.2+512))\n\t\t\t\t\t\t\tinsect_portals_ready=true\n\t\t\t\t\t\tfor site:Dictionary in insect_portals:\n\t\t\t\t\t\t\tif p.distance_to(site.position)<scale*.84*1.6+maxf(320,site.half*1.2):broad_dome=false;break\n\t\t\t\t\tvar mound_width:float=scale*(.84 if broad_dome else .4)\n\t\t\t\t\t# Preserve a visible young crown above the original 8m footing.\n\t\t\t\t\tvar mound_height:float=maxf(scale*.42,minf(scale,18)) if broad_dome else scale\n\t\t\t\t\tvar vent_depth:float=0\n\t\t\t\t\tif type in [0,3,5] and mound_height>=40 and sampler.random(x,z,178)<sampler.settings.nest_vent_frequency:\n\t\t\t\t\t\tvent_depth=preload(\"res://scripts/insect_vent_geometry.gd\").admitted_depth(builder,anchor,mound_width,mound_height,d.angle,minf(mound_height*.18,24))\n\t\t\t\t\tmound(builder,anchor,mound_width,mound_height,type,d.angle,color,vent_depth,broad_dome)"
	expected=replace_once(expected,old_primary,new_primary)
	assert(expected==FileAccess.get_file_as_string("res://scripts/biome_extension_structures.gd").replace("\r\n","\n"),"Only the declared dome profile and protected-footprint policy may change the shared emitter")
	var settings_path:String=VENT_BASE+"/sources/scripts/biome_extension_settings.gd.txt";bind(settings_path)
	assert(FileAccess.get_sha256(settings_path)==previous.source_sha256["res://scripts/biome_extension_settings.gd"])
	var settings_text:String=FileAccess.get_file_as_string(settings_path).replace("\r\n","\n")
	var marker:String="@export_range(0,1,.05) var nest_vent_frequency:float=.25\n"
	settings_text=replace_once(settings_text,marker,marker+"## Broad, low, asymmetric earth domes rather than stretched upright hemispheres.\n## Independent false restores the prior primary proportions and profile.\n@export var nest_broad_domes:bool=true\n")
	assert(settings_text==FileAccess.get_file_as_string("res://scripts/biome_extension_settings.gd").replace("\r\n","\n"))
	for unchanged:String in ["res://scripts/terrain_mesh_builder.gd","res://scripts/insect_vent_geometry.gd","res://scripts/terrain_collision.gd","res://config/world/terrain_settings.tres","res://shaders/terrain_biomes.gdshader","res://shaders/biome_structures.gdshader"]:
		assert(FileAccess.get_sha256(unchanged)==previous.source_sha256[unchanged]);bind(unchanged)
	var domes:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_domes.json")
	var vents:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_vents.json")
	var queries:Dictionary=validate("res://tools/biome_extensions/artifacts/check_insect_dome_queries.json")
	var dome_render:Dictionary=validate("res://tools/biome_extensions/artifacts/render_insect_domes.json")
	var vent_render:Dictionary=validate("res://tools/biome_extensions/artifacts/render_insect_vents.json")
	var cost:Dictionary=validate("res://tools/biome_extensions/artifacts/profile_insect_vents.json")
	var regression:Dictionary=validate("res://data/surface_regression_20261018.json")
	assert(domes.checks==354197 and domes.variants==30 and vents.checks==331294 and vents.native_floor_and_lining_rays==21)
	assert(dome_render.captures.size()==9 and vent_render.captures.size()==9 and cost.pairs.size()==12 and regression.test_count==31)
	var captures:Array=dome_render.captures+vent_render.captures
	for capture:Dictionary in captures:
		var path:String="res://tools/biome_extensions/artifacts/"+capture.biome+"_"+capture.view+".png";assert(FileAccess.get_sha256(path)==capture.sha256)
	var report:Dictionary={"passed":true,"failures":[],"completed_utc":Time.get_datetime_string_from_system(true),"production_registration":true,"all_user_tasks_complete":false,"surface_reference_quality_complete":false,"cave_biomes_implemented":false,"source_sha256":hashes,"captures":captures,"dome_checks":domes.checks,"dome_variants":30,"vent_checks":vents.checks,"vent_native_floor_and_lining_rays":21,"lazy_query_checks":queries.checks,"dome_worker_and_collision_proofs":dome_render.worker_proofs,"vent_worker_and_collision_proofs":vent_render.worker_proofs,"shared_regression_scripts":31,"generation_cost_pairs":12,"combined_median_added_generation_ms":cost.median_added_ms,"combined_median_ratio":cost.median_ratio,"dome_added_triangles":0,"new_texture_resources":0,"only_declared_shared_emitter_and_settings_changes":true,"builder_collision_shaders_and_saved_preset_unchanged":true,"runner_observations_transcribed":{"dome_native_sampled_peak_private_mib":1324.9,"vent_native_sampled_peak_private_mib":1419.4,"native_cap_mib":2048,"cost_sampled_peak_private_mib":81.2,"cost_cap_mib":512,"sample_period_ms":500,"isolation":"No other Godot process observed at 500ms samples during the cost run; shorter overlaps not excluded. These external runner receipts are transcribed, not independently present in engine logs."},"scope":"Registered broad, low, irregular Insect dome primary profile with the original triangle budget, young crown preservation, independent legacy mode and conservative fallback near reserved entrances. Actual empty/non-dome/disabled tiles issue no new portal query; coarse dome tiles share one query. Current vent topology/collision and eighteen actual dome/vent views pass, with complete committed worker position comparisons, six real streamed cap/floor rays and all 31 shared regressions. Combined old/new generation cost includes actual protected-entrance callbacks after canonical terrain/feature prepass; not a frame-time or universal performance claim. Text-only change audit normalizes line endings; both complete files are hash-bound. Remaining surface quality/coverage, original known diagnostics and all ordered cave phases remain incomplete."}
	FileAccess.open("res://tools/biome_extensions/artifacts/insect_dome_continuation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open("res://data/insect_dome_continuation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("INSECT_DOME_CONTINUATION ",hashes.size()," guards, ",captures.size()," native images");quit()
