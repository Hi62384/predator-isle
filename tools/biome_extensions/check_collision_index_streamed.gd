extends SceneTree
func _initialize()->void:
	var original:String="res://tools/biome_extensions/check_nerve_fibre_walk.gd";var source:String=FileAccess.get_file_as_string(original)
	source=source.replace("check_nerve_fibre_walk.json","check_collision_index_streamed.json")
	var marker:String='\tvar p:=Vector2(';assert(source.count(marker)==1)
	source=source.replace(marker,'''\tvar regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);hashes[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);hashes[path]=regression.source_sha256[raw]
	for path:String in ["res://tools/biome_extensions/check_collision_index_streamed.gd","res://tools/biome_extensions/check_nerve_fibre_walk.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var subset_cells:Dictionary={};var indexed_nodes:int=0;var reduced_nodes:int=0
'''+marker)
	var loop:String='\t\tcuts[terrain.committed_revision]=true';assert(source.count(loop)==1)
	source=source.replace(loop,loop+'''
		for active:MeshInstance3D in terrain._active_chunks.values():
			if active.mesh.has_meta("collision_data"):
				var payload:Dictionary=active.mesh.get_meta("collision_data")
				if not payload.has("structure_index"):continue
				indexed_nodes+=1
				var count:int=active.get_meta("structure_collision_triangles",0)
				if count>0 and count*3<payload.structure_faces.size():reduced_nodes+=1
				if active.has_meta("structure_collision_cell"):subset_cells[str(active.get_meta("structure_collision_cell"))]=true
''')
	var gate:String='\tcheck(walker.finished and walker.waypoint==route.size(),';assert(source.count(gate)==1)
	source=source.replace(gate,'''\tcheck(terrain.spatial_structure_collision and indexed_nodes>0 and reduced_nodes>0,"Actual four-worker registered controller builds and stages reduced native structure colliders")
	check(subset_cells.size()>1,"Moving original route exercises collider cell refreshes")
'''+gate)
	source=source.replace('"finished":walker.finished','"indexed_node_frame_observations":indexed_nodes,"reduced_node_frame_observations":reduced_nodes,"distinct_subset_cells":subset_cells.size(),"finished":walker.finished')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
