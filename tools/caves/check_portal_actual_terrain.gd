extends SceneTree
func _initialize()->void:
	var original:String="res://tools/caves/check_portal_native.gd";var source:String=FileAccess.get_file_as_string(original)
	source=source.replace('const Mesher=preload("res://tools/caves/cave_portal_mesher_candidate.gd")','const Mesher=preload("res://tools/caves/cave_portal_mesher_candidate.gd")\nconst Memo=preload("res://tools/caves/cave_height_memo_candidate.gd")')
	var height:String='var height:Callable=func(_x:float,_z:float)->float:return 120';assert(source.count(height)==1)
	source=source.replace(height,'var b=make_builder(3,73921);var memo=Memo.new();memo.configure(b._get_height);var height:Callable=memo.sample')
	source=source.replace('var water:Callable=func(_x:float,_z:float)->float:return 0','var water:Callable=b.get_water_surface_height')
	source=source.replace('network.region(Vector2i.ZERO)','network.region(Vector2i(9,-3))').replace('start.y=120.95','start.y=float(height.call(start.x,start.z))+.95')
	var bounds:String='field.surface_min_y=120;field.surface_max_y=120';assert(source.count(bounds)==1)
	source=source.replace(bounds,'''field.surface_min_y=INF;field.surface_max_y=-INF
	for z in range(29):
		for x in range(29):
			var q:Vector2=field.surface_rect.position+Vector2(x,z)*16;var h:float=height.call(q.x,q.y);field.surface_min_y=minf(field.surface_min_y,h);field.surface_max_y=maxf(field.surface_max_y,h)
	field.surface_min_y-=32;field.surface_max_y+=32''')
	var plane:String='for x in range(floori(field.surface_rect.position.x/64),ceili(field.surface_rect.end.x/64)):keys[Vector3i(x,1,z)]=true';assert(source.count(plane)==1)
	source=source.replace(plane,'''for x in range(floori(field.surface_rect.position.x/64),ceili(field.surface_rect.end.x/64)):
			for y in range(floori(field.surface_min_y/64),floori(field.surface_max_y/64)+1):keys[Vector3i(x,y,z)]=true''')
	source=source.replace('check(keys.size()<128,','check(keys.size()<256,').replace('var bodies:Array=[];','var bodies:Array=[];var physical:Array=[];')
	source=source.replace('var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];','var faces:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];physical.append({"origin":Vector3(key)*64,"faces":faces});')
	source=source.replace('var depth:float=120-point.y','var depth:float=float(height.call(point.x,point.z))-point.y')
	source=source.replace('var state:PhysicsDirectSpaceState3D=','var ground_at_hole:float=height.call(hole.x,hole.z);var state:PhysicsDirectSpaceState3D=')
	source=source.replace('Vector3(hole.x,124,hole.z),Vector3(hole.x,100,hole.z)','Vector3(hole.x,ground_at_hole+4,hole.z),Vector3(hole.x,ground_at_hole-20,hole.z)').replace('ray.position.y<119','ray.position.y<ground_at_hole-.5')
	var ray:String='if not ray.is_empty():check(absf(ray.position.y-hole.y)<.03,"Visible/extracted/native opening floor within unchanged30mm bound")';assert(source.count(ray)==1)
	source=source.replace(ray,'''var rendered_hit:=Vector3.INF;var ray_start:=Vector3(hole.x,ground_at_hole+4,hole.z)
	for chunk:Dictionary in physical:
		if hole.x<chunk.origin.x or hole.x>chunk.origin.x+64 or hole.z<chunk.origin.z or hole.z>chunk.origin.z+64:continue
		var faces:PackedVector3Array=chunk.faces
		for i in range(0,faces.size(),3):
			var a:Vector3=faces[i]+chunk.origin;var bv:Vector3=faces[i+1]+chunk.origin;var c:Vector3=faces[i+2]+chunk.origin
			if hole.x<minf(a.x,minf(bv.x,c.x)) or hole.x>maxf(a.x,maxf(bv.x,c.x)) or hole.z<minf(a.z,minf(bv.z,c.z)) or hole.z>maxf(a.z,maxf(bv.z,c.z)):continue
			var hit=Geometry3D.ray_intersects_triangle(ray_start,Vector3.DOWN,a,bv,c)
			if hit!=null and hit.y>=ground_at_hole-20 and (not rendered_hit.is_finite() or hit.y>rendered_hit.y):rendered_hit=hit
	check(rendered_hit.is_finite() and not ray.is_empty() and rendered_hit.distance_to(ray.position)<.03,"Actual CPU visible-triangle/native floor intersection agrees within unchanged30mm physics bound")''')
	var spawn:String='walker.position=start;walker.route=route;';assert(source.count(spawn)==1)
	source=source.replace(spawn,'''walker.position=start;var initial:=PhysicsShapeQueryParameters3D.new();initial.shape=capsule;initial.transform=walker.global_transform;initial.exclude=[walker.get_rid()];initial.margin=.001;var overlaps:Array=walker.get_world_3d().direct_space_state.intersect_shape(initial,8);check(overlaps.is_empty(),"Original canonical surface start is not embedded in actual extracted surface");walker.route=route;''')
	source=source.replace('"synthetic_surface_height_m":120','"surface_family":"spore_forest","canonical_surface_min_y_with32m_guard":field.surface_min_y,"canonical_surface_max_y_with32m_guard":field.surface_max_y,"initial_capsule_overlap_count":overlaps.size(),"cpu_visible_triangle_opening_hit":str(rendered_hit),"opening_plan_extraction_error_m":absf(rendered_hit.y-hole.y),"memo_statistics":memo.statistics()').replace('"region":"(0,0)"','"region":"(9,-3)"')
	source=source.replace('res://tools/caves/check_portal_native.gd','res://tools/caves/check_portal_actual_terrain.gd').replace('check_cave_portal_native.json','check_cave_portal_actual_terrain.json')
	var guard:String='var guards:Dictionary={}';assert(source.count(guard)==1)
	source=source.replace(guard,'''var guards:Dictionary={};guards["'''+original+'''"]=FileAccess.get_sha256("'''+original+'''");guards["res://tools/caves/cave_height_memo_candidate.gd"]=FileAccess.get_sha256("res://tools/caves/cave_height_memo_candidate.gd")
	var regression_path:String="res://data/surface_regression_20261018.json";var regression=JSON.parse_string(FileAccess.get_file_as_string(regression_path));assert(regression.passed and regression.test_count==31);guards[regression_path]=FileAccess.get_sha256(regression_path)
	for raw:String in regression.source_sha256:
		var path:String="res://"+raw.replace("\\\\","/");assert(FileAccess.get_sha256(path)==regression.source_sha256[raw]);guards[path]=regression.source_sha256[raw]''')
	source=source.replace('Original deterministic flat120m canonical field/seed73921Default graph entrance;','Original actual Spore canonical geographic cell(9,-3)/seed73921Default graph entrance,not rerolled. Same admission as previous real graph study;pure exact height memo. Independent native/CPU-rendered-triangle ray bound30mm;off-grid analytic plan extraction error reported separately,not mislabeled collider error. Surface altitude from fixed16m survey+32mvertical guard,≤256preloadcells declared before testing;')
	source=source.replace('synthetic field only,no original-world surface patch/attribute transport/material/real streaming or installed cave claim.','Actual immutable canonical terrain only;finite private surface replacement,not the actual production ChunkTerrain patch/packed attribute transport/material/streaming or installed cave system.')
	var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK);set_script(script);call_deferred("run")
