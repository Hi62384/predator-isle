extends RefCounted
## PRIVATE candidate. Bounded, joined geological growth in the existing graph,
## never an independent volume/worker or a spherical biome admission field.
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const MAX_ADDITIONS:int=4
static func covered(point:Vector3,radius:float,headroom:float,height:Callable,maximum_depth:float,minimum_roof:float)->bool:
	for z in range(-2,3):
		for x in range(-2,3):
			if Vector2(x,z).length()>2.1:continue
			var surface:float=height.call(point.x+x*radius*.5,point.z+z*radius*.5)
			if not is_finite(surface) or surface-point.y>maximum_depth-4 or surface-point.y<headroom+minimum_roof+4:return false
	return true
static func corridor_clear(a:Vector3,b:Vector3,region:Dictionary,pockets:Array,height:Callable,maximum_depth:float,minimum_roof:float)->bool:
	var stations:int=maxi(1,ceili(a.distance_to(b)/2))
	for i in range(stations+1):
		var p:Vector3=a.lerp(b,float(i)/stations)
		if not Profiles.compatible(p,4,8,region,pockets) or not covered(p,4,8,height,maximum_depth,minimum_roof):return false
		for pool:Dictionary in region.get("pools",[]):
			if p.y+8.5>pool.bed_y-.5 and p.y-.5<pool.water_y+1 and Vector2(p.x-pool.center.x,p.z-pool.center.z).length()<pool.radius+6:return false
			if not Basins.route_clear(p,4,p.y-.5,p.y+8,{"edges":pool.get("stream_edges",[])}):return false
	return true
static func decorate(region:Dictionary,height:Callable,seed_id:int,settings:Dictionary,maximum_depth:float,minimum_roof:float)->Dictionary:
	if not region.get("valid",false) or region.get("cave_family",-1) in [6,7] or region.has("crystal_connected_profiles_version"):return region
	var geodes:float=clampf(float(settings.get("geode_frequency",.15)),0,1);var ravines:float=clampf(float(settings.get("ravine_frequency",.08)),0,1);var lakes:float=clampf(float(settings.get("large_lake_frequency",.12)),0,1)
	if geodes<=0 and ravines<=0 and lakes<=0:return region
	var output:Dictionary=region.duplicate(true);var pockets:Array=output.get("pockets",[]);var passages:Array=output.get("pocket_passages",[]);var parents:Array=output.nodes.duplicate();parents.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return str(a.id)<str(b.id));var added:int=0;var changed:bool=false
	for parent:Dictionary in parents:
		if added>=MAX_ADDITIONS or pockets.size()>=Profiles.MAX_POCKETS:break
		if int(parent.get("level",-1))<0:continue
		if float(parent.get("chamber_radius",0))<20:continue
		var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(parent.id),str(parent.id),0,0)
		if float(assignment.weights.get("crystal",0))<.8:continue
		var identity:String=str(assignment.candidate_ids.get("crystal",parent.id));var sample:float=Regions.random(str(parent.id),seed_id,"crystal/connected_profile");var ravine:bool=sample<ravines;var geode:bool=not ravine and sample<ravines+geodes
		if not ravine and not geode:continue
		var source:Dictionary={}
		for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
			if str(candidate.id)==identity:source=candidate;break
		if source.is_empty():continue
		var heading:float=Regions.random(identity,seed_id,"crystal/profile_axis")*TAU;var previous:Dictionary=parent;var count:int=3 if ravine else 2
		for lobe in range(count):
			if added>=MAX_ADDITIONS or pockets.size()>=Profiles.MAX_POCKETS:break
			var id:String=str(parent.id)+":crystal:"+("ravine:" if ravine else "geode:")+str(lobe);var yaw:float=heading if ravine else heading+(-.75 if lobe==0 else .9);var radius:float=12+Regions.random(id,seed_id,"radius")*3 if ravine else 15+Regions.random(id,seed_id,"radius")*5;var span:float=22 if ravine else 28;var point:Vector3=previous.point+Vector3(cos(yaw),0,sin(yaw))*span;var headroom:float=36+Regions.random(id,seed_id,"vault")*12 if ravine else 26+Regions.random(id,seed_id,"vault")*12
			if float(source.distances.get(str(parent.id),INF))+span*(lobe+1 if ravine else 1)>source.reach_m-source.transition_m:continue
			if not Profiles.compatible(point,radius,headroom,output,pockets) or not corridor_clear(previous.point,point,output,pockets,height,maximum_depth,minimum_roof) or not covered(point,radius,headroom,height,maximum_depth,minimum_roof):continue
			var room:Dictionary={"id":id,"parent":previous.id,"point":point,"level":parent.level,"chamber_radius":radius,"chamber_height":headroom,"cross_section_style":3 if ravine else 0,"crystal_layout":2 if geode else 1,"crystal_profile":"ravine" if ravine else "geode","crystal_region":identity}
			pockets.append(room);passages.append({"from":str(previous.id),"to":id,"points":PackedVector3Array([previous.point,point]),"half_width":4.0,"headroom":8.0,"entrance":false,"maximum_grade":0.0});previous=room if ravine else parent;added+=1;changed=true
	output["pockets"]=pockets;output["pocket_passages"]=passages
	# Retain existing candidates,anchors,chance/extent channels and all legacy
	# Default/Frozen distances. Only Crystal follows the newly real edges.
	if changed:
		var topology:Dictionary=Regions.graph(output)
		if topology.is_empty():return region
		var assignment:Dictionary=output.cave_biome_regions;assignment["edges"]=topology.edges
		for candidate:Dictionary in assignment.candidates:
			if candidate.biome_id=="crystal":candidate["distances"]=Regions.distances(topology,candidate.anchor,candidate.reach_m)
	var pools:Array=output.get("pools",[])
	for index in range(pools.size()):
		var pool:Dictionary=pools[index];var parent:String=str(pool.id).trim_suffix(":seepage");var amount:float=float(Regions.along_edge(output.get("cave_biome_regions",{}),parent,parent,0,0).weights.get("crystal",0))
		if amount<.8 or Regions.random(str(pool.id),seed_id,"crystal/large_lake")>=lakes:continue
		var radius:float=8+Regions.random(str(pool.id),seed_id,"crystal/lake_radius")*4;var depth:float=minf(pool.depth*1.2,4.5);var bed_y:float=pool.center.y-depth
		if radius<=pool.radius or not Basins.route_clear(pool.center,radius,bed_y,pool.water_y,output) or not Profiles.compatible(pool.center,radius,8,output,pockets) or not covered(Vector3(pool.center.x,bed_y,pool.center.z),radius,depth+8,height,maximum_depth,minimum_roof):continue
		var collision:bool=false
		for other:Dictionary in pools:
			if other.id==pool.id:continue
			if Vector2(other.center.x-pool.center.x,other.center.z-pool.center.z).length()<radius+other.radius+2 and absf(other.water_y-pool.water_y)<other.depth+depth+2:collision=true;break
		if collision:continue
		var ratio:float=radius/pool.radius;pool["crystal_original_radius"]=pool.radius;pool["crystal_large_lake"]=true;pool.radius=radius;pool.depth=depth;pool.bed_y=bed_y;pool.water_radius=radius*.8;pool.bed.point.y=bed_y;pool.bed.chamber_radius=radius*.85;pool.bed.chamber_height=depth+8
		for lobe:Dictionary in pool.get("bed_lobes",[]):
			var offset:Vector3=lobe.point-pool.center;lobe.point=Vector3(pool.center.x+offset.x*ratio,bed_y+.15,pool.center.z+offset.z*ratio);lobe.chamber_radius=radius*.65;lobe.chamber_height=depth+8
		changed=true
	if not changed:return region
	output["crystal_connected_profiles_version"]=1;return output
