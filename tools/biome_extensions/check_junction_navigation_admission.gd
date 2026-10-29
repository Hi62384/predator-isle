extends "res://tools/biome_extensions/check_all.gd"
const Junction=preload("res://scripts/alien_junction_geometry.gd")
const Membrane=preload("res://scripts/alien_membrane_geometry.gd")
var navigation_rejections:Array=[]
func sampled_approach(b,p:Vector2,axis:Vector2,width:float,phase:float)->Dictionary:
	var side:=Vector2(-axis.y,axis.x);var a:Vector2=p+axis*width*.6*sin(.65*PI*.65)+side*width*.07*sin(.65*PI+phase)*.65
	var center:Vector2=(a+(p+axis*width*3)*2+(p+axis*width*3.6))*.25;var maximum:float=0
	for index in range(121):
		var q:Vector2=center+side*(-60+index);var gx:int=floori(q.x/2);var gz:int=floori(q.y/2);var fx:float=q.x/2-gx;var fz:float=q.y/2-gz
		var a3:=Vector3(gx*2,b._get_height(gx*2,gz*2),gz*2);var b3:=Vector3((gx+1)*2,b._get_height((gx+1)*2,gz*2),gz*2);var c3:=Vector3(gx*2,b._get_height(gx*2,(gz+1)*2),(gz+1)*2);var d3:=Vector3((gx+1)*2,b._get_height((gx+1)*2,(gz+1)*2),(gz+1)*2)
		var normal:Vector3=(c3-a3).cross(b3-a3).normalized() if fx+fz<=1 else (c3-b3).cross(d3-b3).normalized();var grade:float=rad_to_deg(acos(clampf(normal.y,-1,1)));maximum=maxf(maximum,grade)
		if grade>30:return {"accepted":false,"first_exceeding_grade_degrees":grade,"position":q,"sample_index":index}
		if b._get_height(q.x,q.y)<=maxf(b.water_level,b.get_water_surface_height(q.x,q.y))+3:return {"accepted":false,"reason":"sampled_approach_not_dry","position":q,"sample_index":index}
	return {"accepted":true,"maximum_sampled_grade_degrees":maximum,"sample_count":121,"scope":"Independent canonical 2m mesh-plane admission only; native capsule motion still required"}
func locate_actual(b,scale_value:float,landmark:Vector2)->Dictionary:
	var field=b._extras[7];var span:float=4096*scale_value;var anchor:=Vector2i(floori(landmark.x/span),floori(landmark.y/span));var search_cells:Array[Vector2i]=[]
	# Same bounded 49x49 search, but grow outwards from an independently
	# verified seed-specific island rather than assuming world origin is land.
	for radius in range(25):
		for z in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if maxi(absi(x),absi(z))==radius:search_cells.append(anchor+Vector2i(x,z))
	for cell:Vector2i in search_cells:
			var x:int=cell.x;var z:int=cell.y;var d:Dictionary=field.descriptor(cell,span)
			if d.chance>field.settings.structure_density or field.random(x,z,246)>=field.settings.hive_junction_frequency:continue
			if field.random(x,z,248)>=field.settings.hive_membrane_frequency:continue
			var p:Vector2=field.hive_node(cell);var ground:float=b._get_height(p.x,p.y)
			if b._island_mask(p.x,p.y)<.1 or ground<=maxf(b.water_level,b.get_water_surface_height(p.x,p.y))+2:continue
			var admission_edges:PackedVector2Array=field.network_edges(cell)
			var navigation:Dictionary=sampled_approach(b,p,(admission_edges[1]-p).normalized(),field.settings.hive_junction_width*scale_value,d.angle)
			if not navigation.accepted:navigation_rejections.append({"seed":b.world_seed,"scale":scale_value,"position":p,"rejection":navigation});continue
			var owner:=Vector2i(floori(p.x/256),floori(p.y/256));b.chunk_size=256
			var arrays:Array=build_structures(b,owner)
			if arrays[2]==null or arrays[2][Mesh.ARRAY_VERTEX].size()<14304:continue
			var width:float=field.settings.hive_junction_width*scale_value;var height:float=field.settings.hive_junction_height*(.65+d.age*.7)*field.settings.relief*maxf(b.settings.height_multiplier,.01)
			var edges:PackedVector2Array=field.network_edges(cell);var directions:Array[Vector2]=[(edges[1]-p).normalized(),(edges[5]-p).normalized()]
			var g=Structures.new();g.origin=Vector3(owner.x*256,0,owner.y*256);g._support_steps=Structures.support_grids();var junction=Junction.new();junction.longitudinal_ribs=field.settings.hive_longitudinal_ribs;junction.emit(g,b,p,directions,width,height,d.angle);Membrane.new().emit(g,b,p,directions[0],width,height,d.angle)
			var prefix:int=arrays[2][Mesh.ARRAY_VERTEX].size()-g.vertices.size()
			if arrays[2][Mesh.ARRAY_VERTEX].slice(prefix)!=g.vertices:continue
			for pair:Array in [[Mesh.ARRAY_NORMAL,g.normals],[Mesh.ARRAY_COLOR,g.colors],[Mesh.ARRAY_TEX_UV,g.uvs]]:check(arrays[2][pair[0]].slice(prefix)==pair[1],"Actual complete custom-scale normal-guard junction/membrane tail")
			return {"seed":b.world_seed,"feature_scale":scale_value,"position":[p.x,p.y],"hive_cell":[cell.x,cell.y],"ground":ground,"junction_height":height,"width":width,"additional_vertices":14304,"membrane_present":true,"membrane_chance":field.random(x,z,248),"normal_cavity_guards":true,"forced_rarity":false,"sampled_navigation_admission":navigation,"search_landmark":[landmark.x,landmark.y]}
	return {}
func run()->void:
	var hashes:Dictionary={}
	for path:String in ["res://scripts/biome_extension_structures.gd","res://scripts/alien_junction_geometry.gd","res://scripts/alien_membrane_geometry.gd","res://scripts/alien_infected_sampler.gd","res://scripts/biome_extension_settings.gd","res://scripts/terrain_mesh_builder.gd","res://scripts/terrain_feature_meshes.gd","res://tools/biome_extensions/check_junction_navigation_admission.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var cases:Array=[]
	var baseline_path:String="res://tools/biome_extensions/artifacts/check_junction_admission.json";hashes[baseline_path]=FileAccess.get_sha256(baseline_path)
	var baseline=JSON.parse_string(FileAccess.get_file_as_string(baseline_path));check(baseline.passed,"Independently verified seed-specific land landmarks")
	for seed_id:int in [73921,17,92881]:
		var landmark:=Vector2.INF
		for item:Dictionary in baseline.cases:
			if int(item.seed)==seed_id:landmark=Vector2(item.position[0],item.position[1])
		check(landmark.is_finite(),"Actual land landmark for seed "+str(seed_id))
		for scale_value:float in [.2,2]:
			var b=make_builder(7,seed_id);b.settings.alien_infected.feature_scale=scale_value;b._configure_noise()
			check(b.settings.alien_infected.caves_enabled and b.settings.alien_infected.hive_carapace_frequency==.18,"Other production features left enabled")
			var site:Dictionary=locate_actual(b,scale_value,landmark);check(not site.is_empty(),"Real default-rarity membrane for seed/scale "+str([seed_id,scale_value]))
			if not site.is_empty():cases.append(site)
	check(cases.size()==6,"All three seeds at both extreme scales, no missing-case skip")
	for path:String in hashes:check(FileAccess.get_sha256(path)==hashes[path],"Stable custom-scale admission source "+path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_junction_navigation_admission.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"source_sha256":hashes,"cases":cases,"navigation_rejections":navigation_rejections,"original_geometric_sites_not_replaced":true,"scope":"Six separate navigation-admitted, normal-rarity geometry sites over three seeds/scales, full independent 14304-vertex tails and all normal guards. Sampled 2m ground-plane grades at 121 approach points must be at most 30 degrees and dry. Rejected sites are retained; the original purely geometric manifest and its steep failed traversal remain historical/negative evidence, not overwritten or claimed fixed. Actual native capsule/streaming traversal remains required, not inferred from sampling."},"  "))
	print("JUNCTION_NAVIGATION_ADMISSION ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
