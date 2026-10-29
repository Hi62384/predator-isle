extends RefCounted
## Private procedural bank chamber,not a new graph node or water source.
## A low36m-radius lobe shares the retained pool parent's exact floor.
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Base=preload("res://scripts/caves/crystal_profiles.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
static func prepare(region:Dictionary,height:Callable,seed_id:int,settings:Dictionary,maximum_depth:float=400,minimum_roof:float=10)->Dictionary:
	if not settings.get("lake_chambers",false) or not settings.get("chamber_growth",true) or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	for index in range(region.get("pools",[]).size()):
		var pool:Dictionary=region.pools[index];var parent_id:String=str(pool.id).trim_suffix(":seepage")
		if pool.get("crystal_large_lake",false) or not pool.get("stream_edges",[]).is_empty():continue
		var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),parent_id,parent_id,0,0)
		if float(assignment.weights.get("crystal",0))<.8 or Regions.random(str(pool.id),seed_id,"crystal/large_lake")>=float(settings.get("large_lake_frequency",.12)):continue
		var parent:Dictionary={}
		for room:Dictionary in region.nodes+region.get("pockets",[]):
			if str(room.id)==parent_id:parent=room;break
		if parent.is_empty() or absf(parent.point.y-pool.center.y)>.01:continue
		var radius:float=36;var headroom:float=10;var regional:Vector2=Vector2(region.id)*1536
		if pool.center.x-radius<regional.x+4 or pool.center.x+radius>regional.x+1532 or pool.center.z-radius<regional.y+4 or pool.center.z+radius>regional.y+1532:continue
		if not Profiles.compatible(pool.center,radius,headroom,region,region.get("pockets",[])) or not Base.covered(pool.center,radius,headroom,height,maximum_depth,minimum_roof):continue
		var unsafe_water:bool=false
		for other:Dictionary in region.get("pools",[]):
			if other.id!=pool.id and other.water_y>pool.center.y+.1 and Vector2(other.center.x-pool.center.x,other.center.z-pool.center.z).length()<radius+other.radius+2:unsafe_water=true
		if unsafe_water:continue
		var bank:Dictionary={"id":str(pool.id)+":crystal:bank","point":pool.center,"level":parent.level,"chamber_radius":radius,"chamber_height":headroom,"cross_section_style":0,"biome_parent":parent_id,"parent":parent_id,"crystal_region":str(assignment.candidate_ids.get("crystal",parent_id)),"crystal_layout":4,"crystal_profile":"lake_bank"};var candidate:Dictionary=region.duplicate(true);candidate.nodes.append(bank);candidate.erase("crystal_connected_profiles_version");var controls:Dictionary=settings.duplicate();controls.geode_frequency=0.0;controls.ravine_frequency=0.0;var result:Dictionary=Base.decorate(candidate,height,seed_id,controls,maximum_depth,minimum_roof)
		if not result.pools[index].get("crystal_large_lake",false):continue
		var nodes:Array=[]
		for room:Dictionary in result.nodes:
			if str(room.id)!=str(bank.id):nodes.append(room)
		result.nodes=nodes;result.pools[index]["bank_lobes"]=[bank];result.pools[index]["precise_shore"]=settings.get("precise_shores",true)
		var direction:Vector3=parent.point-pool.center;direction.y=0
		if direction.length_squared()<.01:continue
		var shore:Vector3=pool.center+direction.normalized()*(result.pools[index].radius+2)
		result.pools[index]["bank_access"]=[{"from":parent_id,"to":parent_id,"points":PackedVector3Array([parent.point,shore]),"half_width":1.0,"headroom":3.0,"entrance":false,"biome_parent":parent_id}]
		var final_field=Base.BankField.new();final_field.maximum_depth=maximum_depth;final_field.minimum_roof=minimum_roof
		if not final_field.compile([result],height):continue
		return result
	return region
