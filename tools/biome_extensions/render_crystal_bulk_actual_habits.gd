extends SceneTree
func _initialize()->void:
	var source_path:String="res://tools/biome_extensions/render_crystal_bulk_candidate.gd";var source:String=FileAccess.get_file_as_string(source_path)
	var marker:String='\tvar records:Array=[];var rebuilds:Array=[]';assert(source.count(marker)==1)
	source=source.replace(marker,'''\tvar admission_path:String="res://tools/biome_extensions/artifacts/admit_crystal_bulk_styles.json";var admission=JSON.parse_string(FileAccess.get_file_as_string(admission_path));assert(admission.passed and admission.cases.size()==6);hashes[admission_path]=FileAccess.get_sha256(admission_path)
	for path:String in admission.source_sha256:assert(FileAccess.get_sha256(path)==admission.source_sha256[path]);hashes[path]=admission.source_sha256[path]
	hashes["res://tools/biome_extensions/render_crystal_bulk_actual_habits.gd"]=FileAccess.get_sha256("res://tools/biome_extensions/render_crystal_bulk_actual_habits.gd")
	for selected:Dictionary in admission.cases:
		var item:Dictionary=previews.families.crystal_wastes.regions[str(int(selected.kind))];item.x=selected.position[0];item.z=selected.position[1];item.height=selected.height
'''+marker)
	source=source.replace('var root_count:int=0','var root_count:int=0;var actual_positive_vertices:int=0')
	var compare:String='\t\t\tvar old:ShaderMaterial=visible.mesh.surface_get_material(0);';assert(source.count(compare)==1)
	source=source.replace(compare,'''\t\t\tif Rect2(Vector2(key.x,key.y)*builder.chunk_size,Vector2.ONE*builder.chunk_size).has_point(p):
				actual_positive_vertices+=candidate[0][Mesh.ARRAY_VERTEX].size()
				for uv:Vector2 in candidate[0][Mesh.ARRAY_TEX_UV]:verify(floori(uv.x)==kind,"Actual committed root metadata has the intended positive mineral habit")
'''+compare)
	source=source.replace('verify(root_count>0,"Actual procedural mineral structures present")','verify(root_count>0 and actual_positive_vertices>0,"Actual positive intended-mineral root rebuilt from committed GPU arrays")')
	source=source.replace('for view:String in positions:','for view:String in positions:\n\t\t\tif view!="medium":continue')
	source=source.replace('"root_count":root_count,','"root_count":root_count,"positive_intended_habit_vertices":actual_positive_vertices,')
	source=source.replace('crystal_bulk_%d_%s_%d.png','crystal_bulk_actual_habit_%d_%s_%d.png').replace('artifacts/render_crystal_bulk_candidate.json','artifacts/render_crystal_bulk_actual_habits.json')
	source=source.replace('ALL six original procedural Crystal region fixtures,ground/medium cameras,36 original/candidate/original images','SIX ADDITIONAL pre-admitted actual-mineral roots,one medium camera each,18 original/candidate/original images;the original geographic36-image study is retained separately,not replaced')
	source=source.replace('Twelve strict original image returns.','Six strict original image returns;actual intended-habit metadata and positive foreground geometry verified for every admitted root.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
