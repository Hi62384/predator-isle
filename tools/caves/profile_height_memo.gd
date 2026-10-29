extends SceneTree
func _initialize()->void:
	var original:String="res://tools/caves/check_actual_graph_native.gd";var frozen:String="res://tools/biome_extensions/artifacts/revisions/experiment_profile_cave_field_bins_54f92e5d4afd/evidence/tools/biome_extensions/artifacts/profile_cave_field_bins.json";var source:String=FileAccess.get_file_as_string(original)
	source=source.replace('const Mesher=preload("res://tools/caves/cave_mesher_candidate.gd")','const Mesher=preload("res://tools/caves/cave_mesher_candidate.gd")\nconst Memo=preload("res://tools/caves/cave_height_memo_candidate.gd")')
	var marker:String='var field=Field.new();';assert(source.count(marker)==1)
	source=source.replace(marker,'''var frozen_path:String="'''+frozen+'''";var expected=JSON.parse_string(FileAccess.get_file_as_string(frozen_path));assert(expected.passed and expected.paired_chunks.size()==216);var expected_hashes:Dictionary={}
	for record:Dictionary in expected.paired_chunks:expected_hashes[record.key]=record.complete_arrays_sha256
	var reference_b=make_builder(3,73921);var reference=Field.new();check(reference.compile([data],reference_b._get_height),"Direct unwrapped independent cold canonical provider reference")
	b=make_builder(3,73921);var memo=Memo.new();memo.configure(b._get_height);var paired_chunks:Array=[];var reference_total:float=0;var candidate_total:float=0
	'''+marker)
	source=source.replace('field.compile([data],b._get_height)','field.compile([data],memo.sample)')
	var mesh:String='var arrays:Array=Mesher.new().build(field,key,2);';assert(source.count(mesh)==1)
	source=source.replace(mesh,'''var pair:Dictionary={}
		for direct:bool in ([true,false] if built%2==0 else [false,true]):
			var started_mesh:int=Time.get_ticks_usec();var a:Array=Mesher.new().build(reference if direct else field,key,2);var elapsed:float=(Time.get_ticks_usec()-started_mesh)/1000000.0;var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(a));pair[direct]={"arrays":a,"sha256":h.finish().hex_encode(),"seconds":elapsed}
		check(pair[false].sha256==pair[true].sha256,"Complete original positions/normals/colors exact with memo composition")
		check(expected_hashes.has(str(key)) and pair[false].sha256==expected_hashes.get(str(key)),"Complete array hash also matches separately frozen pre-memo216cell result")
		reference_total+=pair[true].seconds;candidate_total+=pair[false].seconds;paired_chunks.append({"key":str(key),"direct_seconds":pair[true].seconds,"memo_seconds":pair[false].seconds,"complete_arrays_sha256":pair[false].sha256,"equal":pair[false].sha256==pair[true].sha256});var arrays:Array=pair[false].arrays;''')
	source=source.replace('check(keys.size()>8 and keys.size()<256,','check(keys.size()==216,')
	source=source.replace('"largest_single_chunk_mesh_seconds":largest_chunk_seconds','"paired_chunks":paired_chunks,"direct_total_mesh_seconds":reference_total,"memo_total_mesh_seconds":candidate_total,"memo_direct_mesh_ratio":candidate_total/maxf(reference_total,.000001),"memo_statistics":memo.statistics(),"largest_combined_pair_seconds":largest_chunk_seconds')
	source=source.replace('res://tools/caves/check_actual_graph_native.gd','res://tools/caves/profile_height_memo.gd').replace('check_cave_actual_graph_native.json','profile_cave_height_memo.json')
	var guard:String='var guards:Dictionary={}';assert(source.count(guard)==1);source=source.replace(guard,guard+';guards["'+original+'"]=FileAccess.get_sha256("'+original+'");guards["'+frozen+'"]=FileAccess.get_sha256("'+frozen+'");guards["res://tools/caves/cave_height_memo_candidate.gd"]=FileAccess.get_sha256("res://tools/caves/cave_height_memo_candidate.gd")')
	source=source.replace('PRIVATE original actual canonical Spore surface geographic cell,Default-only17node/20edge3D implicit union.','PRIVATE bounded exact height-provider composition at original actual canonical Spore cell,Default-only17node/20edge3D implicit union.216fixedoriginalmeshcells,allcomplete mesh arrays must match direct independent cold canonical provider AND separately frozen pre-memo result. Separate initially cold samplers/alternating pair order. Field equations/16mlookup/2mmesh/64mchunks unchanged.8192FIFO source-specific cache admits only exactF32XY,other doubles bypass;no canonical terrain formula/cache-capacity changes. NON-ISOLATED single serial traversal,not repeated runtime/four-worker/startup gain.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
