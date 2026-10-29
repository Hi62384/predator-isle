extends RefCounted
## Private geological test: a retained pool may need a broad,low connected
## chamber to provide a real dry perimeter. Never enlarge water into rock.
const Base=preload("res://scripts/caves/crystal_profiles.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const MAX_LAKE_ANNEXES:int=1
static func prepare(region:Dictionary,height:Callable,seed_id:int,configuration:Dictionary,maximum_depth:float=400,minimum_roof:float=10,statistics:Dictionary={})->Dictionary:
	if not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	var output:Dictionary=region;var additions:int=0
	for pool:Dictionary in region.get("pools",[]):
		# Separate single lake annex,not four geode/ravine rooms plus an
		# unbounded number of lakes. The total24-pocket hard limit is unchanged.
		if additions>=MAX_LAKE_ANNEXES or output.get("pockets",[]).size()>=Profiles.MAX_POCKETS:break
		if pool.get("crystal_large_lake",false):continue
		var parent_id:String=str(pool.id).trim_suffix(":seepage");var assignment:Dictionary=Regions.along_edge(output.get("cave_biome_regions",{}),parent_id,parent_id,0,0)
		if float(assignment.weights.get("crystal",0))<.8 or Regions.random(str(pool.id),seed_id,"crystal/large_lake")>=float(configuration.get("large_lake_frequency",.12)):continue
		statistics["eligible"]=int(statistics.get("eligible",0))+1
		var parent:Dictionary={}
		for room:Dictionary in output.nodes+output.get("pockets",[]):
			if str(room.id)==parent_id:parent=room;break
		if parent.is_empty():statistics["missing_parent"]=int(statistics.get("missing_parent",0))+1;continue
		var radius:float=8+Regions.random(str(pool.id),seed_id,"crystal/lake_radius")*4;var direction:Vector3=(pool.center-parent.point).normalized();var point:Vector3=pool.center-direction*(radius+7);point.y=pool.center.y
		var reach:float=radius*2.4+14;var headroom:float=16
		if not Profiles.compatible(point,reach,headroom,output,output.get("pockets",[])):statistics["incompatible"]=int(statistics.get("incompatible",0))+1;continue
		if not Base.covered(point,reach,headroom,height,maximum_depth,minimum_roof):statistics["cover"]=int(statistics.get("cover",0))+1;continue
		if not Base.corridor_clear(parent.point,point,output,output.get("pockets",[]),height,maximum_depth,minimum_roof):statistics["corridor"]=int(statistics.get("corridor",0))+1;continue
		statistics["proposed"]=int(statistics.get("proposed",0))+1
		var candidate:Dictionary=output.duplicate(true);var room:Dictionary={"id":str(pool.id)+":crystal:shore","parent":parent_id,"point":point,"level":parent.level,"chamber_radius":reach,"chamber_height":headroom,"cross_section_style":0,"crystal_layout":4,"crystal_profile":"lake_shore","crystal_region":str(assignment.candidate_ids.get("crystal",parent_id))};var pockets:Array=candidate.get("pockets",[]);pockets.append(room);candidate.pockets=pockets;var passages:Array=candidate.get("pocket_passages",[]);passages.append({"from":parent_id,"to":room.id,"points":PackedVector3Array([parent.point,point]),"half_width":4.0,"headroom":8.0,"entrance":false,"maximum_grade":0.0});candidate.pocket_passages=passages;candidate.erase("crystal_connected_profiles_version")
		var topology:Dictionary=Regions.graph(candidate)
		if topology.is_empty():continue
		candidate.cave_biome_regions.edges=topology.edges
		for item:Dictionary in candidate.cave_biome_regions.candidates:
			if item.biome_id=="crystal":item.distances=Regions.distances(topology,item.anchor,item.reach_m)
		var controls:Dictionary=configuration.duplicate();controls.geode_frequency=0.0;controls.ravine_frequency=0.0;var enlarged:Dictionary=Base.decorate(candidate,height,seed_id,controls,maximum_depth,minimum_roof);var admitted:bool=false
		for result:Dictionary in enlarged.get("pools",[]):
			if result.id==pool.id and result.get("crystal_large_lake",false):admitted=true;break
		if admitted:output=enlarged;additions+=1;statistics["admitted"]=int(statistics.get("admitted",0))+1
		else:statistics["bank_or_basin"]=int(statistics.get("bank_or_basin",0))+1
	return output
