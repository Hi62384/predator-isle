extends "res://tools/biome_extensions/check_all.gd"
const Reference=preload("res://tools/biome_extensions/reference_pre_footing_structures.gd")
func chord_height(b,p:Vector2,step:float)->float:
	var x:float=floorf(p.x/step)*step;var z:float=floorf(p.y/step)*step
	var a:=Vector3(x,b._get_height(x,z),z);var c:=Vector3(x,b._get_height(x,z+step),z+step)
	var v:=Vector3(x+step,b._get_height(x+step,z),z)
	if (p.x-x+p.y-z)/step>1:a=Vector3(x+step,b._get_height(x+step,z+step),z+step)
	var plane:=Plane(a,v,c)
	return (plane.d-plane.normal.x*p.x-plane.normal.z*p.y)/plane.normal.y
func segment_distance(p:Vector2,a:Vector2,b:Vector2)->float:
	var delta:Vector2=b-a
	return p.distance_to(a+delta*clampf((p-a).dot(delta)/maxf(delta.length_squared(),.000001),0,1))
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/chunk_terrain.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://scripts/alien_infected_sampler.gd","res://tools/biome_extensions/reference_pre_footing_structures.gd","res://tools/biome_extensions/check_conduit_footings.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var records:Array=[];var total_feet:int=0;var protected_triangles:int=0
	for seed_id:int in [73921,17,92881]:
		for variant in range(2):
			var b=make_builder(7,seed_id);var field=b._extras[7]
			var a:Vector2=field.hive_node(Vector2i(-12,-11));var end:Vector2=field.hive_node(Vector2i(-11,-11))
			var grids:PackedFloat64Array=Structures.support_grids(256,128,16,6) if variant==0 else Structures.support_grids(128,96,20,7)
			var g=Structures.new();g.origin=Vector3(a.x,0,a.y);g._support_steps=grids
			var protected_center:Vector2=(a+end)*.5
			g._protected_sites=[{"position":protected_center,"half":96.0}]
			g.conduit(b,a,end,20,.4,Color(.34,.28,.26))
			var feet:int=0;var unique:Dictionary={};var minimum_burial:float=INF
			for i in range(g.vertices.size()):
				var v:Vector3=g.vertices[i]+g.origin
				check(is_finite(v.x) and is_finite(v.y) and is_finite(v.z),"Finite apron position")
				check(absf(g.normals[i].length()-1)<.001,"Finite normalized conduit/apron normal")
				if g.colors[i].a>.1 or unique.has(v):continue
				unique[v]=true;feet+=1;total_feet+=1
				for step:float in grids:
					var actual:float=chord_height(b,Vector2(v.x,v.z),step)
					minimum_burial=minf(minimum_burial,actual-v.y)
					# The independent plane solve has float32 world-plane precision.
					check(v.y<=actual-31.5,"Footing below every possible rendered triangle lattice")
			for i in range(0,g.vertices.size(),3):
				var is_new:bool=false
				for j in range(3):is_new=is_new or g.colors[i+j].a<.4
				if not is_new:continue
				var triangle:=PackedVector2Array()
				for j in range(3):
					var v:Vector3=g.vertices[i+j]+g.origin;triangle.append(Vector2(v.x,v.z))
				var distance:float=0 if Geometry2D.is_point_in_polygon(protected_center,triangle) else minf(segment_distance(protected_center,triangle[0],triangle[1]),minf(segment_distance(protected_center,triangle[1],triangle[2]),segment_distance(protected_center,triangle[2],triangle[0])))
				check(distance>=319.9,"No new apron triangle crosses reserved cavity/spiral/gallery volume")
				protected_triangles+=1
			check(feet>32,"Real outer support vertices exercised")
			check(g._support_heights.size()<=16384,"Bounded numeric support cache")
			# The reference switch reproduces every original conduit array exactly.
			var old=Reference.new();old.origin=g.origin;old.conduit(b,a,end,20,.4,Color(.34,.28,.26))
			var disabled=Structures.new();disabled.origin=g.origin;disabled.conduit_aprons=false;disabled.conduit(b,a,end,20,.4,Color(.34,.28,.26))
			check(old.vertices==disabled.vertices and old.normals==disabled.normals and old.colors==disabled.colors and old.uvs==disabled.uvs,"Disabled aprons preserve complete original conduit arrays")
			records.append({"seed":seed_id,"grid_variant":variant,"grid_spacings":grids,"outer_footings":feet,"minimum_burial_m":minimum_burial,"triangles":g.vertices.size()/3,"original_triangles":old.vertices.size()/3})
	# Deliberately reproduce the old floating margin at the actual native worst point.
	var b=make_builder(7);var known:=Vector2(-47038.5,-43740.58)
	var old_margin:float=b._get_height(known.x,known.y)-3;var coarse:float=chord_height(b,known,128)
	check(old_margin>coarse+1,"Known canonical-only attachment defect is detected")
	var g=Structures.new();g._support_steps=Structures.support_grids()
	check(g.footing_height(b,known)<coarse-31.5,"Conservative footing bound corrects that actual coarse chord")
	for family_id:int in [5,6]:
		b=make_builder(family_id);b.chunk_size=8192
		var expected:Array=Reference.new().build(b,Vector2i.ZERO);var actual:Array=build_structures(b,Vector2i.ZERO)
		check(expected==actual,"Crystal and mound complete structure arrays remain exactly unchanged: "+str(family_id))
	check(total_feet>200 and protected_triangles>100,"Substantial actual footing and protected-face coverage")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable source: "+path)
	var result:Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"records":records,"outer_footings":total_feet,"protected_triangles":protected_triangles,"source_sha256":hashes,"scope":"Three real Alien networks, default/custom grid lattices, independent triangle-plane bounds, a synthetic reserved-cavity cylinder, complete disabled-mode equality, actual legacy negative control and unchanged Crystal/Insect geometry. Native cut attachment, visuals, physics and timings are separate."}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_conduit_footings.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("CONDUIT_FOOTINGS ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
