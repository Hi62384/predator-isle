extends SceneTree
func _initialize()->void:
	var original:String="res://tools/caves/check_actual_graph_native.gd";var source:String=FileAccess.get_file_as_string(original)
	source=source.replace('const Mesher=preload("res://tools/caves/cave_mesher_candidate.gd")','const Mesher=preload("res://tools/caves/cave_mesher_candidate.gd")\nconst Candidate=preload("res://tools/caves/cave_gradient_mesher_candidate.gd")')
	var marker:String='var field=Field.new();';assert(source.count(marker)==1)
	source=source.replace(marker,'''var reference_b=make_builder(3,73921);var reference=Field.new();check(reference.compile([data],reference_b._get_height),"Independent initially cold reference field on the SAME repaired original graph")
	var paired_chunks:Array=[];var reference_total:float=0;var candidate_total:float=0
	'''+marker)
	var mesh:String='var arrays:Array=Mesher.new().build(field,key,2);';assert(source.count(mesh)==1)
	source=source.replace(mesh,'''var pair:Dictionary={}
		for old:bool in ([true,false] if built%2==0 else [false,true]):
			var started_mesh:int=Time.get_ticks_usec();var a:Array=(Mesher.new() if old else Candidate.new()).build(reference if old else field,key,2);var elapsed:float=(Time.get_ticks_usec()-started_mesh)/1000000.0;var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(a));pair[old]={"arrays":a,"sha256":h.finish().hex_encode(),"seconds":elapsed}
		check(pair[false].sha256==pair[true].sha256,"Every complete actual mesh position/normal/color array identical for the SAME repaired graph")
		reference_total+=pair[true].seconds;candidate_total+=pair[false].seconds;paired_chunks.append({"key":str(key),"centroid_orientation_seconds":pair[true].seconds,"linear_tetra_gradient_seconds":pair[false].seconds,"reference_complete_arrays_sha256":pair[true].sha256,"candidate_complete_arrays_sha256":pair[false].sha256,"equal":pair[false].sha256==pair[true].sha256});var arrays:Array=pair[false].arrays;''')
	source=source.replace('"largest_single_chunk_mesh_seconds":largest_chunk_seconds','"paired_chunks":paired_chunks,"reference_total_mesh_seconds":reference_total,"candidate_total_mesh_seconds":candidate_total,"candidate_reference_ratio":candidate_total/maxf(reference_total,.000001),"largest_combined_pair_seconds":largest_chunk_seconds')
	source=source.replace('res://tools/caves/check_actual_graph_native.gd','res://tools/caves/profile_gradient_mesher.gd').replace('check_cave_actual_graph_native.json','profile_cave_gradient_mesher.json')
	var guard:String='var guards:Dictionary={}';assert(source.count(guard)==1);source=source.replace(guard,guard+';guards["'+original+'"]=FileAccess.get_sha256("'+original+'");guards["res://tools/caves/cave_gradient_mesher_candidate.gd"]=FileAccess.get_sha256("res://tools/caves/cave_gradient_mesher_candidate.gd")')
	source=source.replace('PRIVATE original actual canonical Spore surface geographic cell,Default-only17node/20edge3D implicit union.','PRIVATE tetrahedral-gradient orientation comparison at the SAME repaired original actual Spore graph. All complete mesh arrays must match centroid-normal reference,with separate initially cold canonical samplers and alternating pair order. Graph now has supported chamber endpoint flats/crossing alternatives and segment floor-plane continuation;NOT compared as exact against older pre-repair geometry. Actual vertex shading normals unchanged. NON-ISOLATED single serial traversal,not repeated four-worker/runtime/startup speedup. Default-only17node/20edge3D implicit union.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
