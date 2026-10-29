extends SceneTree
func _initialize()->void:
	var original:String="res://tools/biome_extensions/check_structure_collision_blocks_real.gd";var source:String=FileAccess.get_file_as_string(original)
	var first_line:String='extends "res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd"';assert(source.count(first_line)==1)
	source=source.replace(first_line,first_line+'\nconst Bounded=preload("res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd")')
	source=source.replace('Blocks.', 'Bounded.').replace('verify_query(', 'verify_bounded_query(')
	var synthetic_path:String="res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd";var synthetic:String=FileAccess.get_file_as_string(synthetic_path);var begin:int=synthetic.find('func verify_query(');var end:int=synthetic.find('\nfunc run()',begin);assert(begin>=0 and end>begin)
	source+='\n'+synthetic.substr(begin,end-begin).replace('func verify_query(', 'func verify_bounded_query(').replace('Blocks.', 'Bounded.')+'\n'
	source=source.replace('res://tools/biome_extensions/check_structure_collision_blocks_real.gd','res://tools/biome_extensions/check_collision_blocks_bounded_real.gd')
	var guard:String='\tvar cases:Array=[];';assert(source.count(guard)==1)
	source=source.replace(guard,'''\tguards["res://tools/biome_extensions/check_structure_collision_blocks_real.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_structure_collision_blocks_real.gd")
	guards["res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd")
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]
'''+guard)
	var native:String='\t\tvar native:Dictionary=await native_pair(faces,primary.faces,local_primary)';assert(source.count(native)==1)
	source=source.replace(native,native+'\n\t\tcheck(native.maximum_native_normal_delta<.00001,"All original native junction/parent normals retained within1e-5 by bounds-preserving subset")')
	source=source.replace('artifacts/check_structure_collision_blocks_real.json','artifacts/check_collision_blocks_bounded_real.json')
	source=source.replace('PRIVATE index over complete ACTUAL','PRIVATE BOUNDS-PRESERVING index over complete ACTUAL').replace('24bytes/64triangles index cost','Up to six actual original extremal blocks retain original mesh-wide compression bounds;no dummy geometry. Original native normal-difference gate1e-5 required.24bytes/64triangles index cost')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
