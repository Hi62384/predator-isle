extends SceneTree
const ORIGINAL="res://tools/biome_extensions/check_streamed_roundtrip.gd"
const DISCOVERY="res://tools/biome_extensions/artifacts/revisions/experiment_find_insect_burrow_conflicts_wide_24a12b15e1b3/evidence/tools/biome_extensions/artifacts/find_insect_burrow_conflicts_wide.json"
func _initialize()->void:
	var conflict:int=0
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("conflict="):conflict=int(arg.trim_prefix("conflict="))
	assert(conflict in [0,1])
	var fixture_path:String="res://tools/biome_extensions/artifacts/check_insect_burrow_structures_17_conflict"+str(conflict)+"_with.json"
	var fixture_report=JSON.parse_string(FileAccess.get_file_as_string(fixture_path));assert(fixture_report.passed and fixture_report.mound_solids_included and not fixture_report.legacy_placement)
	for path:String in fixture_report.source_sha256:assert(FileAccess.get_sha256(path)==fixture_report.source_sha256[path],"Current fixed-site physics proof required")
	var source:String=FileAccess.get_file_as_string(ORIGINAL)
	assert(source.count('res://tools/biome_extensions/artifacts/check_roundtrip.json')==1)
	source=source.replace('res://tools/biome_extensions/artifacts/check_roundtrip.json',fixture_path)
	source=source.replace('terrain.extension_preview="wise_mountains"','terrain.world_seed=17;terrain.extension_preview="insect_colony"')
	source=source.replace('terrain.settings.wise_mountains.cave_frequency=.5','terrain.settings.insect_colony.cave_frequency=.5')
	var header:String="func run()->void:\n";assert(source.count(header)==1)
	source=source.replace(header,header+"\tvar proof_hashes:Dictionary={}\n\tvar inventory=JSON.parse_string(FileAccess.get_file_as_string(\"res://data/surface_regression_20261018.json\"))\n\tfor raw:String in inventory.source_sha256:\n\t\tvar canonical:String=\"res://\"+raw.replace(\"\\\\\",\"/\");proof_hashes[canonical]=FileAccess.get_sha256(canonical)\n\tfor path:String in [\"res://tools/biome_extensions/check_insect_streamed_burrow.gd\",\""+ORIGINAL+"\",\"res://tools/biome_extensions/route_probe.gd\",\""+fixture_path+"\",\""+DISCOVERY+"\"]:proof_hashes[path]=FileAccess.get_sha256(path)\n")
	var start_marker:String="\twalker.route=route;walker.set_physics_process(true)";assert(source.count(start_marker)==1)
	source=source.replace(start_marker,"\tvar worker_clearance:Dictionary=verify_actual_clearance(terrain,"+str(conflict)+")\n"+start_marker)
	var report_marker:String='var report:Dictionary={"checks":checks,"failures":failures,';assert(source.count(report_marker)==1)
	source=source.replace(report_marker,'var report:Dictionary={"passed":failures.is_empty(),"production_registration":true,"source_sha256":proof_hashes,"worker_clearance":worker_clearance,"frozen_conflict_index":'+str(conflict)+',"checks":checks,"failures":failures,')
	var write_marker:String='\tFileAccess.open("res://tools/biome_extensions/artifacts/check_streamed_roundtrip.json"';assert(source.count(write_marker)==1)
	source=source.replace(write_marker,'\tfor path:String in proof_hashes:check(FileAccess.get_sha256(path)==proof_hashes[path],"Stable streamed burrow source "+path)\n\treport.passed=failures.is_empty();report.checks=checks\n'+write_marker)
	source=source.replace('artifacts/check_streamed_roundtrip.json','artifacts/check_insect_streamed_burrow_'+str(conflict)+'.json')
	source=source.replace("One Wise fixture using actual production chunk jobs, staging, caches and transactional collision cuts; test walker pauses while replacement cut preloads; not an infinite cave or uninterrupted performance certificate","Fixed discovered Insect burrow using actual production chunk jobs, staging, caches and transactional collision cuts. Frozen site/capsule/route and original 180s limits/1ms headless preload polling preserved. Complete actual near-worker mound exclusion is checked against an independent unsafe-placement rebuild. Test walker pauses during cut preloads; this is not an infinite cave or uninterrupted-performance certificate.")
	source+='\nfunc verify_actual_clearance(terrain,conflict:int)->Dictionary:\n\tvar discovery=JSON.parse_string(FileAccess.get_file_as_string("'+DISCOVERY+'"))\n\tvar record:Dictionary=discovery.candidates[conflict];var q:=Vector2(record.mound_position[0],record.mound_position[1]);var owner:MeshInstance3D\n\tfor node:MeshInstance3D in terrain._active_chunks.values():\n\t\tvar key:Vector3i=node.get_meta("tile");var span:float=terrain.chunk_size*(1<<key.z)\n\t\tif Rect2(Vector2(key.x*span,key.y*span),Vector2.ONE*span).has_point(q):owner=node;break\n\tassert(owner!=null and owner.get_meta("tile").z==0,"Actual protected root must be in the close production cut")\n\tvar faces:PackedVector3Array=owner.mesh.get_meta("collision_data").structure_faces\n\tassert(faces.is_empty(),"Actual committed worker must exclude the obstructing complex")\n\tvar b=make_builder(6,17);b.settings=terrain._settings_snapshot.duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.insect_colony.nest_protect_burrows=false;b._configure_noise();b.chunk_size=256\n\tvar key:Vector3i=owner.get_meta("tile");var old:Array=build_structures(b,Vector2i(key.x,key.y))\n\tassert(old[1]!=null and old[1][Mesh.ARRAY_VERTEX].size()==int(record.structure_vertices),"Independent unsafe rebuild must recover every original obstructing vertex")\n\treturn {"portal_id":record.portal_id,"mound_id":record.mound_id,"tile":key,"actual_worker_vertices":0,"independent_unsafe_vertices":old[1][Mesh.ARRAY_VERTEX].size(),"world_seed":terrain.world_seed}\n'
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK)
	set_script(script);call_deferred("run")
