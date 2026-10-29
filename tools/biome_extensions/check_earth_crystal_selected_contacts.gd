extends "res://tools/biome_extensions/check_all.gd"
func ground_height(arrays:Array,resolution:int,span:float,point:Vector2)->float:
	var grid:Vector2=point/span*resolution;var x:int=clampi(floori(grid.x),0,resolution-1);var z:int=clampi(floori(grid.y),0,resolution-1);var f:Vector2=grid-Vector2(x,z);var row:int=resolution+1
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var a:float=vertices[z*row+x].y;var b:float=vertices[z*row+x+1].y;var c:float=vertices[(z+1)*row+x].y;var d:float=vertices[(z+1)*row+x+1].y
	return a+(b-a)*f.x+(c-a)*f.y if f.x+f.y<=1 else d+(c-d)*(1-f.x)+(b-d)*(1-f.y)
func run()->void:
	var input_path:String="res://tools/biome_extensions/artifacts/check_grounded_earth_crystal_candidate.json";var input=JSON.parse_string(FileAccess.get_file_as_string(input_path));assert(input.passed)
	var guards:Dictionary={input_path:FileAccess.get_sha256(input_path)}
	for path:String in input.source_sha256:assert(FileAccess.get_sha256(path)==input.source_sha256[path]);guards[path]=input.source_sha256[path]
	for path:String in ["res://scripts/chunk_terrain.gd","res://scripts/terrain_partition.gd","res://tools/biome_extensions/check_earth_crystal_selected_contacts.gd"]:guards[path]=FileAccess.get_sha256(path)
	var records:Array=[];var actual_old_exposed:int=0;var maximum_actual_old_gap:float=0
	for site:Dictionary in input.cases:
		var b=make_builder(int(site.family),int(site.seed));var field=b._extras[int(site.family)];var parts:PackedStringArray=site.root.trim_prefix("(").trim_suffix(")").split(",");var p:=Vector2(float(parts[0]),float(parts[1]));var network_span:float=(1700 if site.family==5 else 2100)*field.settings.feature_scale
		# Recover exact full-precision descriptor,not rounded diagnostic strings.
		var cell:=Vector2i(floori(p.x/network_span),floori(p.y/network_span));var descriptor:Dictionary=field.descriptor(cell,network_span);p=descriptor.position
		var anchor:=Vector3(p.x,b._get_height(p.x,p.y)-8,p.y);var original=Structures.new();var candidate=preload("res://tools/biome_extensions/grounded_earth_crystal_candidate.gd").script_for().new()
		for g in [original,candidate]:
			g.origin=Vector3.ZERO;g._support_steps=Structures.support_grids()
			if site.family==5:g.prism(b,anchor,field.settings.crystal_height*.1,field.settings.crystal_height,0,descriptor.angle,Vector2(.1,-.08),false,Color(.59,.61,.58))
			else:g.mound(b,anchor,field.settings.nest_height*.6,field.settings.nest_height,0,descriptor.angle,Color(.46,.26,.13))
		var feet:Dictionary={}
		for index in range(original.vertices.size()):
			if original.vertices[index]!=candidate.vertices[index]:feet[original.vertices[index]]=candidate.vertices[index]
		var controller=preload("res://scripts/chunk_terrain.gd").new();controller._settings_snapshot=b.settings;controller._sampler=b;controller.maximum_lod=6
		for distance:float in [2048.0,4096.0,8192.0,16384.0]:
			var viewer:Vector2=p+Vector2(distance,-distance*.25);controller._target_chunk=Vector2i(floori(viewer.x/256),floori(viewer.y/256));controller._partition.base_size=256;controller._partition.maximum_level=6;controller._partition.split_ratio=controller.split_distance_ratio;controller._partition.merge_ratio=controller.split_distance_ratio+controller.merge_hysteresis
			var plan:Dictionary=controller._partition.select(viewer,{});var tiles:Dictionary={};var old_count:int=0;var new_count:int=0;var worst:float=0
			for old:Vector3 in feet:
				var current:Vector3=feet[old];var key:Vector3i;var owned:bool=false;var point:=Vector2(old.x,old.z)
				for leaf:Vector3i in plan:
					if controller._partition.bounds(leaf).has_point(point):key=leaf;owned=true;break
				check(owned,"Actual production partition covers foundation")
				if not owned:continue
				if not tiles.has(key):
					var resolution:int=controller._tile_resolution(key);var span:float=256*float(1<<key.z);b.chunk_size=span;tiles[key]={"arrays":b.build(Vector2i(key.x,key.y),resolution),"resolution":resolution,"span":span}
				var tile:Dictionary=tiles[key];var floor_height:float=ground_height(tile.arrays,tile.resolution,tile.span,point-Vector2(key.x,key.y)*tile.span)
				if old.y>floor_height+.02:old_count+=1;worst=maxf(worst,old.y-floor_height)
				if current.y>floor_height+.02:new_count+=1
				check(current.y<=floor_height+.02,"Lower foot reaches ACTUAL selected terrain triangles")
			actual_old_exposed+=old_count;maximum_actual_old_gap=maxf(maximum_actual_old_gap,worst)
			var selection:Array=[]
			for key:Vector3i in tiles:selection.append({"key":str(key),"resolution":tiles[key].resolution,"spacing_m":tiles[key].span/tiles[key].resolution})
			records.append({"seed":site.seed,"family":site.family,"root":str(p),"viewer_offset_m":distance,"unique_feet":feet.size(),"old_exposed_feet":old_count,"new_exposed_feet":new_count,"maximum_old_gap_m":worst,"actual_selected_tiles":selection})
		controller.free()
	check(records.size()==24,"Six frozen roots at four declared viewer distances")
	# Efficacy has its own gate;absence of real selected gaps must not be
	# mistaken for an adopted fix just because conservative margins changed.
	check(actual_old_exposed>0,"At least one real old foot above actually selected terrain")
	for path:String in guards:check(FileAccess.get_sha256(path)==guards[path],"Stable selected-contact source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_earth_crystal_selected_contacts.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":guards,"cases":records,"original_actual_exposed_feet":actual_old_exposed,"maximum_original_actual_gap_m":maximum_actual_old_gap,"production_registration":false,"scope":"PRIVATE actual production partition+resolution policy and complete canonical terrain arrays,not every hypothetical support grid. Six preselected dry Crystal/Insect roots,four frozen camera offsets,all changed unique feet. Exact descriptor positions,fullLOD6,standard split/merge settings. Candidate must reach every selected clockwise terrain triangle;original exposed-foot efficacy gate independent of32m burial margin. No actual Jolt traversal or continuous-edge guarantee."},"  "))
	print("SELECTED_ROOT_CONTACTS ",checks," original_actual_exposed=",actual_old_exposed," max_gap=",maximum_actual_old_gap," failures=",failures);quit(0 if failures.is_empty() else 1)
