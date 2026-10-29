extends SceneTree
func _initialize()->void:
	var original:String="res://tools/biome_extensions/check_structure_collision_blocks_dense.gd";var source:String=FileAccess.get_file_as_string(original)
	source=source.replace('extends "res://tools/biome_extensions/check_structure_collision_blocks_real.gd"','extends "res://tools/biome_extensions/check_structure_collision_blocks_real.gd"\nconst Spatial=preload("res://tools/biome_extensions/structure_collision_spatial_candidate.gd")\nconst Bounded=preload("res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd")')
	var build:String='var bounds:PackedVector3Array=Blocks.build(faces)';assert(source.count(build)==1);source=source.replace(build,'var metadata:Dictionary=Spatial.build(faces);var bounds:PackedVector3Array=metadata.bounds')
	source=source.replace('Blocks.select(faces,bounds,point)','Spatial.select(faces,metadata,point)').replace('verify_query(faces,bounds,point)','verify_spatial_query(faces,metadata,point)')
	var synthetic:String=FileAccess.get_file_as_string("res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd");var begin:int=synthetic.find('func verify_query(');var end:int=synthetic.find('\nfunc run()',begin);assert(begin>=0 and end>begin)
	var oracle:String=synthetic.substr(begin,end-begin).replace('func verify_query(faces:PackedVector3Array,bounds:PackedVector3Array,point:Vector3)','func verify_spatial_query(faces:PackedVector3Array,metadata:Dictionary,point:Vector3)');oracle=oracle.replace('Blocks.select(faces,bounds,point)','Spatial.select(faces,metadata,point)').replace('bounds.size()*12','Spatial.numeric_bytes(metadata)');source+='\n'+oracle+'\n'
	source=source.replace('res://tools/biome_extensions/check_structure_collision_blocks_dense.gd','res://tools/biome_extensions/check_collision_spatial_dense.gd')
	var marker:String='\tvar b=make_builder(7,92881);';assert(source.count(marker)==1)
	source=source.replace(marker,'''\tguards["res://tools/biome_extensions/check_structure_collision_blocks_dense.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/check_structure_collision_blocks_dense.gd")
	for path:String in ["res://tools/biome_extensions/structure_collision_spatial_candidate.gd","res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd"]:guards[path]=FileAccess.get_sha256(path)
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]
'''+marker)
	var native:String='var native:Dictionary=await detailed_native(faces,selected,point);';assert(source.count(native)==1)
	source=source.replace(native,'''check(selected.faces==Bounded.select(faces,bounds,point).faces,"Spatial selection exactly matches accepted bounds-preserving source bytes/order")
	var native:Dictionary=await detailed_native(faces,selected,point);
	check(native.maximum_native_normal_difference<.00001,"Spatial candidate retains full original native normals")
	''')
	source=source.replace('"old_error_to_own_original_face_normal":old_error','"old_error_to_own_original_face_normal":old_error if full_face>=0 else null').replace('"new_error_to_own_original_face_normal":new_error','"new_error_to_own_original_face_normal":new_error if subset_face>=0 else null')
	source=source.replace('"index_bytes":bounds.size()*12','"index_bytes":Spatial.numeric_bytes(metadata),"bucket_count":metadata.bins.size(),"bucket_references":metadata.references,"overflow_blocks":metadata.overflow.size()')
	source=source.replace('artifacts/check_structure_collision_blocks_dense.json','artifacts/check_collision_spatial_dense.json').replace('PRIVATE ADDITIONAL original dense16km','PRIVATE SPATIALLY INDEXED BOUNDS-PRESERVING ADDITIONAL original dense16km')
	source=source.replace('Native face IDs/original geometric normals diagnose any normal changes,not assumed equivalent.','Exact accepted bounds-preserving selection bytes/order and native normals within1e-5 required. Retains original extremal blocks,no dummy geometry.1024m2coarse buckets with bounded overflow avoid whole-index per-query scans. Unavailable native face indices produce null per-face errors,not invented reference errors.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
