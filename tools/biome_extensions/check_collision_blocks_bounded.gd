extends "res://tools/biome_extensions/check_all.gd"
const Bounded=preload("res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd")
func _initialize()->void:
	var path:String="res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd";var source:String=FileAccess.get_file_as_string(path)
	source=source.replace('res://tools/biome_extensions/structure_collision_blocks_candidate.gd','res://tools/biome_extensions/structure_collision_blocks_bounded_candidate.gd')
	source=source.replace('res://tools/biome_extensions/check_structure_collision_blocks_candidate.gd','res://tools/biome_extensions/check_collision_blocks_bounded.gd')
	var marker:String='\tcheck(faces.to_byte_array()==original,"Index/query never mutates original geometry")';assert(source.count(marker)==1)
	source=source.replace(marker,'''\tvar source_low:=Vector3(INF,INF,INF);var source_high:=Vector3(-INF,-INF,-INF)
	for v:Vector3 in faces:source_low=source_low.min(v);source_high=source_high.max(v)
	for point:Vector3 in [Vector3.ZERO,Vector3(-256,0,-256),Vector3(12000,100,12000)]:
		var selection:Dictionary=Blocks.select(faces,bounds,point);var selected_low:=Vector3(INF,INF,INF);var selected_high:=Vector3(-INF,-INF,-INF)
		for v:Vector3 in selection.faces:selected_low=selected_low.min(v);selected_high=selected_high.max(v)
		check(source_low==selected_low and source_high==selected_high,"Exact complete original mesh bounds preserved using only original source triangles")
'''+marker)
	source=source.replace('artifacts/check_structure_collision_blocks_candidate.json','artifacts/check_collision_blocks_bounded.json').replace('PRIVATE conservative ordered collision-block index','PRIVATE bounds-preserving conservative ordered collision-block index')
	source=source.replace('Synthetic numeric proof only;','Up to six original extremal blocks also retained to keep mesh-wide compression bounds. Synthetic numeric proof only;')
	var guard:String='\tvar faces:=PackedVector3Array()';assert(source.count(guard)==1)
	source=source.replace(guard,'\tguards["'+path+'"]=FileAccess.get_sha256("'+path+'")\n\tguards["res://tools/biome_extensions/structure_collision_blocks_candidate.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/structure_collision_blocks_candidate.gd")\n'+guard)
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
