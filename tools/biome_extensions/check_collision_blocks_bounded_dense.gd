extends SceneTree
func _initialize()->void:
	var original:String="res://tools/biome_extensions/check_structure_collision_blocks_dense.gd";var source:String=FileAccess.get_file_as_string(original)
	source=source.replace('extends "res://tools/biome_extensions/check_structure_collision_blocks_real.gd"','extends "res://tools/biome_extensions/check_structure_collision_blocks_real.gd"\nconst Bounded=preload("res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd")')
	source=source.replace('Blocks.build(', 'Bounded.build(').replace('Blocks.select(', 'Bounded.select(').replace('verify_query(faces,bounds,point)','verify_bounded_query(faces,bounds,point)')
	var synthetic:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd");var begin:int=synthetic.find('func verify_query(');var end:int=synthetic.find('\nfunc run()',begin);assert(begin>=0 and end>begin)
	source+='\n'+synthetic.substr(begin,end-begin).replace('func verify_query(', 'func verify_bounded_query(').replace('Blocks.', 'Bounded.')+'\n'
	source=source.replace('res://tools/biome_extensions/check_structure_collision_blocks_dense.gd','res://tools/biome_extensions/check_collision_blocks_bounded_dense.gd')
	var marker:String='\tvar b=make_builder(7,92881);';assert(source.count(marker)==1)
	source=source.replace(marker,'''\tguards["res://tools/biome_extensions/check_structure_collision_blocks_dense.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_structure_collision_blocks_dense.gd")
	guards["res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd")
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]
'''+marker)
	var native:String='var native:Dictionary=await detailed_native(faces,selected,point);';assert(source.count(native)==1)
	source=source.replace(native,'''var source_low:=Vector3(INF,INF,INF);var source_high:=Vector3(-INF,-INF,-INF);var selected_low:=Vector3(INF,INF,INF);var selected_high:=Vector3(-INF,-INF,-INF)
	for v:Vector3 in faces:source_low=source_low.min(v);source_high=source_high.max(v)
	for v:Vector3 in selected.faces:selected_low=selected_low.min(v);selected_high=selected_high.max(v)
	check(source_low==selected_low and source_high==selected_high,"Exact original dense mesh-wide bounds retained")
	var native:Dictionary=await detailed_native(faces,selected,point);
	check(native.maximum_native_normal_difference<.00001,"Bounds-preserving candidate retains original native contact normals in the dense fixture")
	''')
	# Face indices are unavailable under the unchanged production Jolt setting.
	# Do not present distance to a zero vector as an original-normal error.
	source=source.replace('"old_error_to_own_original_face_normal":old_error','"old_error_to_own_original_face_normal":old_error if full_face>=0 else null').replace('"new_error_to_own_original_face_normal":new_error','"new_error_to_own_original_face_normal":new_error if subset_face>=0 else null')
	source=source.replace('artifacts/check_structure_collision_blocks_dense.json','artifacts/check_collision_blocks_bounded_dense.json')
	source=source.replace('PRIVATE ADDITIONAL original dense16km','PRIVATE BOUNDS-PRESERVING ADDITIONAL original dense16km').replace('Native face IDs/original geometric normals diagnose any normal changes,not assumed equivalent.','Up to six ORIGINAL extremal64-triangle blocks keep mesh-wide compression bounds;no dummy geometry. Original native normal-difference gate1e-5 required for this bounded candidate. Native face IDs can be unavailable under unchanged Jolt settings;unavailable original-face errors explicitly null,not invented.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
