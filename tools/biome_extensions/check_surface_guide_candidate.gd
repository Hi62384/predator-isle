extends "res://tools/biome_extensions/check_membrane_collision.gd"
const GuidedJunction=preload("res://tools/biome_extensions/surface_guided_junction_candidate.gd")
const GuidedMembrane=preload("res://tools/biome_extensions/surface_guided_membrane_candidate.gd")
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://tools/biome_extensions/reference_deep_guide_junction.gd","res://tools/biome_extensions/reference_deep_guide_membrane.gd","res://scripts/biome_extension_settings.gd"]:hashes[path]=FileAccess.get_sha256(path)
	for path:String in ["res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/biome_extension_structures.gd","res://scripts/alien_infected_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://tools/biome_extensions/surface_guided_junction_candidate.gd","res://tools/biome_extensions/surface_guided_membrane_candidate.gd","res://tools/biome_extensions/check_surface_guide_candidate.gd","res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"]:hashes[path]=FileAccess.get_sha256(path)
	var sites=JSON.parse_string(FileAccess.get_file_as_string("res://tools/biome_extensions/artifacts/check_junction_custom_admission.json"));check(sites.passed and sites.cases.size()==6,"Full actual normal-rarity custom-scale manifest")
	var cases:Array=[];var old_obstructions:int=0
	for item:Dictionary in sites.cases:
		var b=make_builder(7,int(item.seed));b.settings.alien_infected.feature_scale=item.feature_scale;b._configure_noise()
		var field=b._extras[7];var p:=Vector2(item.position[0],item.position[1]);var cell:=Vector2i(item.hive_cell[0],item.hive_cell[1]);var edges:PackedVector2Array=field.network_edges(cell);var d:Dictionary=field.descriptor(cell,4096*item.feature_scale)
		var directions:Array[Vector2]=[(edges[1]-p).normalized(),(edges[5]-p).normalized()];var width:float=item.width;var height:float=item.junction_height
		var guided=Structures.new();var old=Structures.new();var disabled=Structures.new()
		for g in [guided,old,disabled]:g.origin=Vector3(floorf(p.x/256)*256,0,floorf(p.y/256)*256);g._support_steps=Structures.support_grids()
		GuidedJunction.new().emit(guided,b,p,directions,width,height,d.angle);GuidedMembrane.new().emit(guided,b,p,directions[0],width,height,d.angle)
		preload("res://tools/biome_extensions/reference_deep_guide_junction.gd").new().emit(old,b,p,directions,width,height,d.angle);preload("res://tools/biome_extensions/reference_deep_guide_membrane.gd").new().emit(old,b,p,directions[0],width,height,d.angle)
		var j=GuidedJunction.new();j.surface_guide_enabled=false;j.emit(disabled,b,p,directions,width,height,d.angle)
		var m=GuidedMembrane.new();m.surface_guide_enabled=false;m.emit(disabled,b,p,directions[0],width,height,d.angle)
		check(disabled.vertices==old.vertices and disabled.normals==old.normals and disabled.colors==old.colors and disabled.uvs==old.uvs,"Disabled trial preserves complete old arrays exactly")
		var production=Structures.new();var legacy=Structures.new()
		for g in [production,legacy]:g.origin=guided.origin;g._support_steps=guided._support_steps
		var pj=preload("res://scripts/alien_junction_geometry.gd").new();pj.emit(production,b,p,directions,width,height,d.angle)
		var pm=preload("res://scripts/alien_membrane_geometry.gd").new();pm.emit(production,b,p,directions[0],width,height,d.angle)
		pj.surface_guide_enabled=false;pm.surface_guide_enabled=false;pj.emit(legacy,b,p,directions,width,height,d.angle);pm.emit(legacy,b,p,directions[0],width,height,d.angle)
		check(production.vertices==guided.vertices and production.normals==guided.normals and production.colors==guided.colors and production.uvs==guided.uvs,"Complete production helper arrays equal independently preserved surface-guide trial")
		check(legacy.vertices==old.vertices and legacy.normals==old.normals and legacy.colors==old.colors and legacy.uvs==old.uvs,"Complete production disabled helper arrays equal frozen deep-guide baseline")
		check(guided.vertices.size()==14304,"Original closed geometry budget retained")
		for normal:Vector3 in guided.normals:check(normal.is_finite() and normal.length_squared()>.99,"Finite unit trial normals")
		var axis:Vector2=directions[0];var side:=Vector2(-axis.y,axis.x);var a:Vector2=p+axis*width*.6*sin(.65*PI*.65)+side*width*.07*sin(.65*PI+d.angle)*.65
		var center:Vector2=(a+(p+axis*width*3)*2+(p+axis*width*3.6))*.25;var canonical:float=b._get_height(center.x,center.y)
		var ray_start:Vector3=Vector3(center.x,canonical,center.y)-guided.origin;var ray_end:Vector3=ray_start+Vector3.UP*1000
		var old_parameter:float=ray_parameter(old.vertices,ray_start,ray_end);var new_parameter:float=ray_parameter(guided.vertices,ray_start,ray_end)
		var old_gap:float=old_parameter*1000;var new_gap:float=new_parameter*1000
		if not is_finite(old_gap) or old_gap<2.05:old_obstructions+=1
		check(is_finite(new_gap) and new_gap>2.05,"Actual trial midpoint lower face clears canonical walking surface")
		var endpoint:Vector2=p+axis*width*3.6
		cases.append({"seed":item.seed,"scale":item.feature_scale,"canonical_midpoint_y":canonical,"deep_endpoint_y":guided.footing_height(b,endpoint),"surface_guide_y":b._get_height(endpoint.x,endpoint.y)-8,"old_ceiling_gap_m":old_gap,"trial_ceiling_gap_m":new_gap})
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable trial source "+path)
	check(old_obstructions>0,"Original custom-scale obstruction remains a required negative control")
	FileAccess.open("res://tools/biome_extensions/artifacts/check_surface_guide_candidate.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"cases":cases,"old_obstructed_cases":old_obstructions,"scope":"Private, unregistered visible-arch surface-guide trial over six actual default-rarity custom-scale roots. Original buried endpoint anchors and counts retained, full disabled arrays exact. Midpoint triangle rays only: no native walk, attachment, arbitrary-slope or art acceptance."},"  "))
	print("SURFACE_GUIDE_TRIAL ",cases," failures=",failures);quit(0 if failures.is_empty() else 1)
