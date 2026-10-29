extends RefCounted
## Bounded widening of existing solved short passages. Points,graph IDs,
## longitudinal floors and grades remain unchanged;no second route solver.
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
static func clear(p:Vector3,width:float,headroom:float,region:Dictionary,height:Callable,maximum_depth:float,minimum_roof:float)->bool:
	if not Profiles.compatible(p,width,headroom,region,region.get("pockets",[])):return false
	for offset:Vector2 in [Vector2.ZERO,Vector2(width,0),Vector2(-width,0),Vector2(0,width),Vector2(0,-width)]:
		var surface:float=height.call(p.x+offset.x,p.z+offset.y)
		if not is_finite(surface) or surface-p.y>maximum_depth-4 or surface-p.y<headroom+minimum_roof+4:return false
	for pool:Dictionary in region.get("pools",[]):
		if Vector2(p.x-pool.center.x,p.z-pool.center.z).length()<width+pool.radius+2 and p.y+headroom>pool.bed_y-1 and p.y<pool.water_y+1:return false
		if not Basins.route_clear(p,width,p.y-.5,p.y+headroom,{"edges":pool.get("stream_edges",[])}):return false
	return true
static func decorate(region:Dictionary,height:Callable,seed_id:int,configuration:Dictionary,maximum_depth:float,minimum_roof:float)->Dictionary:
	if not configuration.get("cooled_tubes",true) or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	var result:Dictionary=region;var changed:bool=false;var additions:int=0
	for table:String in ["edges","pocket_passages"]:
		var edges:Array=region.get(table,[]).duplicate()
		for index in range(edges.size()):
			if additions>=2:break
			var edge:Dictionary=edges[index]
			if edge.entrance:continue
			var points:PackedVector3Array=edge.points;var length:float=0
			for station in range(1,points.size()):length+=points[station-1].distance_to(points[station])
			if length<8 or length>256:continue
			var frequency:float=float(configuration.get("tube_frequency",1.0))
			if frequency<=0 or (frequency<1 and Regions.random(str(edge.from)+":"+str(edge.to),seed_id,"magma/tube_admission")>=frequency):continue
			var a:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(edge.from),str(edge.to),0,length);var b:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(edge.from),str(edge.to),length,length)
			if minf(float(a.weights.get("magma",0)),float(b.weights.get("magma",0)))<.8:continue
			var identity:String=str(a.candidate_ids.get("magma",edge.from));var shape:int=mini(2,int(Regions.random(identity,seed_id,"magma/tube_profile")*3));var width:float=8.0 if shape==0 else 6.0;var headroom:float=12.0 if shape==0 else (18.0 if shape==1 else 13.0);var admitted:bool=true
			# A rare tall fracture reuses the solved passage and its dry floor.
			# Roof and crossing-floor tests cover the entire taller cross-section.
			if Regions.random(identity,seed_id,"magma/fissure")<float(configuration.get("fissure_frequency",.12)):shape=3;width=6.0;headroom=32.0
			for station in range(1,points.size()):
				var steps:int=maxi(1,ceili(points[station-1].distance_to(points[station])/2))
				for probe in range(steps+1):
					if not clear(points[station-1].lerp(points[station],float(probe)/steps),width,headroom,region,height,maximum_depth,minimum_roof):admitted=false;break
				if not admitted:break
			if not admitted:continue
			var tube:Dictionary=edge.duplicate();tube.half_width=maxf(edge.half_width,width);tube.headroom=maxf(edge.headroom,headroom);tube["cross_section_style"]=0 if shape<2 else (2 if shape==3 else 3);tube["retain_cross_section_style"]=true;tube["magma_tube_profile"]=["broad_cooled_flow","high_cooled_tube","irregular_cooled_tube","great_volcanic_fissure"][shape];edges[index]=tube;additions+=1
			if not changed:result=region.duplicate();changed=true
		if changed:result[table]=edges
	return result
