extends "res://tools/biome_extensions/check_insect_vents.gd"
const BEFORE="res://tools/biome_extensions/artifacts/revisions/experiment_insect_vent_continuation_8ddeb9cbb953/sources/scripts/biome_extension_structures.gd.txt"
func reserved(_bounds:Rect2,p:Vector2)->Array:return [{"position":p,"half":96.0}]
func locate_dome(b)->Dictionary:
	var field=b._extras[6];var span:float=2100*field.settings.feature_scale
	var guard=preload("res://scripts/terrain_feature_meshes.gd").new();guard.builder=b
	for z in range(-30,31):
		for x in range(-30,31):
			var cell:=Vector2i(x,z);var d:Dictionary=field.descriptor(cell,span);var p:Vector2=d.position
			if d.chance>field.settings.structure_density or clampi(roundi(field.region(p)),0,5)!=3 or b._island_mask(p.x,p.y)<.03:continue
			var h:float=b._get_height(p.x,p.y)
			if h<b.get_water_surface_height(p.x,p.y)+2:continue
			var scale:float=field.settings.nest_height*(.45+d.age)
			var clear:bool=true
			for site:Dictionary in guard.portal_sites(Rect2(p-Vector2.ONE*1024,Vector2.ONE*2048)):
				if p.distance_to(site.position)<scale*.84*1.6+maxf(320,site.half*1.2):clear=false;break
			if clear:return {"seed":b.world_seed,"position":[p.x,p.y],"cell":[x,z],"ground":h,"scale":scale,"width":scale*.84,"height":maxf(scale*.42,minf(scale,18)),"phase":d.angle,"id":d.id}
	return {}
func run()->void:
	var hashes:Dictionary={}
	for path:String in [BEFORE,"res://tools/biome_extensions/check_insect_domes.gd","res://tools/biome_extensions/check_insect_vents.gd","res://scripts/biome_extension_structures.gd","res://scripts/biome_extension_settings.gd","res://scripts/insect_vent_geometry.gd","res://scripts/insect_colony_sampler.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var before:=GDScript.new();before.source_code=FileAccess.get_file_as_string(BEFORE);check(before.reload()==OK,"Complete preserved vent-era emitter loads")
	var flat=preload("res://tools/biome_extensions/flat_conduit_builder.gd").new();flat._configure_noise()
	var variants:int=0;var smallest_visible_crown:float=INF
	for scale:float in [9,20,54,120,507.5]:
		for phase:float in [.17,2.3,5.7]:
			for vented:bool in [false,true]:
				var width:float=scale*.84;var height:float=maxf(scale*.42,minf(scale,18));var depth:float=minf(height*.18,24) if vented else 0
				var g=Structures.new();g.mound(flat,Vector3(0,-8,0),width,height,3,phase,Color(.5,.4,.3),depth,true)
				var bounds:=AABB(g.vertices[0],Vector3.ZERO);var edges:Dictionary={}
				for i in range(0,g.vertices.size(),3):
					var a:Vector3=g.vertices[i];var b:Vector3=g.vertices[i+1];var c:Vector3=g.vertices[i+2]
					check((c-a).cross(b-a).length_squared()>.00000001,"Nondegenerate broad dome/rim/lining triangle")
					for p:Vector3 in [a,b,c]:bounds=bounds.expand(p)
					for pair:Array in [[a,b],[b,c],[c,a]]:
						var key:Array=pair if pair[0]<pair[1] else [pair[1],pair[0]];edges[key]=int(edges.get(key,0))+1
				for edge:Array in edges:check(edges[edge]==2 or (edges[edge]==1 and edge[0].y<=-8 and edge[1].y<=-8),"No new open boundary beyond the buried foundation")
				for normal:Vector3 in g.normals:check(normal.is_finite() and normal.length_squared()>.9,"Finite broad dome/rim/lining normals")
				check(absf(bounds.end.y-(height-8))<.0001 and bounds.position.y<=-8,"Exact summit and buried base")
				smallest_visible_crown=minf(smallest_visible_crown,bounds.end.y)
				check(bounds.size.x<=width*2.7 and bounds.size.z<=width*2.7,"Conservative protected-portal footprint bound")
				if scale>=54:check(bounds.size.x/bounds.size.y>3 and bounds.size.z/bounds.size.y>2.5,"Mature domes are broad low earthworks, not upright eggs")
				var center:=Vector2(width*.16*sin(2+phase),width*.12)
				check(absf(top_height(g.vertices,center)-(height-8-depth))<.0002,"Profile asymmetry does not cover the true vent or move its floor")
				variants+=1
	check(smallest_visible_crown>=1,"Smallest supported young dome keeps a visible crown")
	var sites:Array=[]
	for seed_id:int in [73921,17,92881]:
		var b=make_builder(6,seed_id);b.settings.insect_colony.nest_vent_frequency=0
		var site:Dictionary=locate_dome(b);check(not site.is_empty(),"Actual dry default-rarity dome outside protected portals")
		if site.is_empty():continue
		var p:=Vector2(site.position[0],site.position[1]);b.chunk_size=256;var cell:=Vector2i(floori(p.x/256),floori(p.y/256))
		var current:Array=build_structures(b,cell);var old:Array=before.new().build(b,cell)
		check(current[1]!=null and old[1]!=null and current[1][Mesh.ARRAY_VERTEX].size()==old[1][Mesh.ARRAY_VERTEX].size(),"Broad morphology reuses the original triangle budget")
		check(current[1][Mesh.ARRAY_VERTEX]!=old[1][Mesh.ARRAY_VERTEX],"Actual primary dome shape changes, not just a setting registration")
		b.settings.insect_colony.nest_broad_domes=false
		check(Structures.new().build(b,cell)==old,"Independent disabled mode preserves all original full structure arrays")
		b.settings.insect_colony.nest_broad_domes=true
		b.settings.insect_colony.nest_protect_burrows=false
		check(Structures.new().build(b,cell,PackedFloat64Array(),reserved.bind(p))==old,"Reserved real entrance suppresses footprint expansion exactly")
		b.settings.insect_colony.nest_protect_burrows=true
		b.chunk_size=512;var parent_cell:=Vector2i(floori(p.x/512),floori(p.y/512));var parent:Array=build_structures(b,parent_cell)
		var expected:Array[String]=world_vertices(parent,Vector3(parent_cell.x*512,0,parent_cell.y*512));var children:Array[String]=[]
		b.chunk_size=256
		for z in range(2):
			for x in range(2):
				var child:Vector2i=parent_cell*2+Vector2i(x,z);children.append_array(world_vertices(build_structures(b,child),Vector3(child.x*256,0,child.y*256)))
		expected.sort();children.sort();check(expected==children,"One unchanged root owner at parent/four child cuts")
		sites.append(site)
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable dome source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_insect_domes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":checks,"variants":variants,"sites":sites,"smallest_young_crown_m":smallest_visible_crown,"source_sha256":hashes,"production_registration":true,"scope":"Thirty broad dome primitive variants, including young crowns and maximum supported nest maturity, capped/open topology/normals/bounds, independently measured vent depth and true broad mature proportions. Three actual seeded full complexes verify changed morphology with identical triangle budgets, exact independent legacy mode, reserved-entrance fallback and stable root ownership. Not reference-quality art or whole-biome/cave completion."},"  "))
	print("INSECT_DOMES ",checks," checks; failures=",failures);quit(0 if failures.is_empty() else 1)
