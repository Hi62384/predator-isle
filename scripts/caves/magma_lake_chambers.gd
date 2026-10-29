extends RefCounted
## Bounded source-backed bank and unequal basalt-vault profile on the shared cave field.
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const Field=preload("res://scripts/caves/field.gd")
const Regions=preload("res://scripts/caves/biome_regions.gd")
static func covered(point:Vector3,radius:float,headroom:float,height:Callable,maximum_depth:float,minimum_roof:float)->bool:
	for z in range(-2,3):
		for x in range(-2,3):
			if Vector2(x,z).length()>2.1:continue
			var surface:float=height.call(point.x+x*radius*.5,point.z+z*radius*.5)
			if not is_finite(surface) or surface-point.y>maximum_depth-4 or surface-point.y<headroom+minimum_roof+4:return false
	return true
static func dry_bank(field,pool:Dictionary)->bool:
	for offset:float in [1.0,2.0,3.0]:
		for station in range(64):
			var angle:float=TAU*station/64;var p:Vector3=pool.center+Vector3(cos(angle),0,sin(angle))*(pool.radius+offset);var low:Vector3=p-Vector3.UP*4;var high:Vector3=p+Vector3.UP*6
			if field.sample(low)<.1 or field.sample(high)>-.3:return false
			for iteration in range(16):
				var mid:Vector3=(low+high)*.5
				if field.sample(mid)>=0:low=mid
				else:high=mid
			var floor_point:Vector3=(low+high)*.5
			if floor_point.y<pool.water_y+.2 or floor_point.y>pool.center.y+4 or field.normal(floor_point).y<.8 or field.sample(floor_point+Vector3.UP*1.8)>-.3:return false
	return true
static func prepare(region:Dictionary,height:Callable,seed_id:int,settings:Dictionary,maximum_depth:float,minimum_roof:float,heat_context)->Dictionary:
	if not settings.get("large_lake_chambers",false) or heat_context==null or not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:return region
	for index in range(region.get("pools",[]).size()):
		var pool:Dictionary=region.pools[index]
		if pool.get("fluid_kind","")!="magma" or pool.get("magma_large_lake",false) or not pool.get("stream_edges",[]).is_empty() or Regions.random(str(pool.id),seed_id,"magma/large_lake")>=float(settings.get("large_lake_chance",.08)):continue
		var parent_id:String=str(pool.id).trim_suffix(":seepage");var parent:Dictionary={}
		for room:Dictionary in region.nodes+region.get("pockets",[]):
			if str(room.id)==parent_id:parent=room;break
		if parent.is_empty():continue
		var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),parent_id,parent_id,0,0);var source_id:String=str(assignment.candidate_ids.get("magma",""));var fits_extent:bool=false
		for candidate:Dictionary in region.get("cave_biome_regions",{}).get("candidates",[]):
			if str(candidate.id)==source_id and float(candidate.distances.get(parent_id,INF))+float(parent.chamber_radius)+34<=float(candidate.reach_m)-float(candidate.transition_m):fits_extent=true;break
		if not fits_extent:continue
		var direction:Vector3=(pool.center-parent.point)*Vector3(1,0,1)
		if direction.length_squared()<.01:continue
		direction=direction.normalized();var center:Vector3=parent.point+direction*(parent.chamber_radius+20);var radius:float=14.0;var bank_radius:float=36.0;var regional:=Vector2(region.id)*1536
		if center.x-bank_radius<regional.x+4 or center.x+bank_radius>regional.x+1532 or center.z-bank_radius<regional.y+4 or center.z+bank_radius>regional.y+1532:continue
		if not Profiles.compatible(center,bank_radius,10,region,region.get("pockets",[])) or not covered(center,bank_radius,12,height,maximum_depth,minimum_roof) or not Basins.route_clear(center,radius,center.y-4.5,pool.water_y,region):continue
		var source:Dictionary=heat_context.sample(Vector3(center.x,pool.water_y,center.z));var admitted:bool=float(source.heat)>=.5 and str(source.get("id",""))==str(pool.thermal_source)
		for station in range(32):
			var angle:float=TAU*station/32;var witness:Dictionary=heat_context.sample(Vector3(center.x+cos(angle)*radius,pool.water_y,center.z+sin(angle)*radius))
			if float(witness.heat)<.5 or str(witness.get("id",""))!=str(pool.thermal_source):admitted=false;break
		for other:Dictionary in region.pools:
			if other.id!=pool.id and Vector2(other.center.x-center.x,other.center.z-center.z).length()<bank_radius+other.radius+2 and absf(other.water_y-pool.water_y)<14:admitted=false;break
		if not admitted:continue
		var result:Dictionary=region.duplicate(true);var grown:Dictionary=result.pools[index];var old_center:Vector3=grown.center;var ratio:float=radius/grown.radius;grown.center=center;grown.radius=radius;grown.water_radius=radius*.8;grown.depth=4.5;grown.bed_y=center.y-4.5;grown.bed.point=Vector3(center.x,grown.bed_y,center.z);grown.bed.chamber_radius=radius*.85;grown.bed.chamber_height=12.5;grown["surface_witness"]=source.surface_witness;grown["source_heat"]=source.heat
		for lobe:Dictionary in grown.get("bed_lobes",[]):
			var offset:Vector3=(lobe.point-old_center)*Vector3(1,0,1);lobe.point=Vector3(center.x,grown.bed_y+.15,center.z)+offset*ratio;lobe.chamber_radius=radius*.65;lobe.chamber_height=12.5
		grown["bank_lobes"]=[{"id":str(pool.id)+":magma:bank","point":center,"level":parent.level,"chamber_radius":bank_radius,"chamber_height":10.0,"cross_section_style":0,"biome_parent":parent_id,"parent":parent_id}]
		var tall:bool=true
		for side:int in [-1,1]:
			var point:Vector3=center+direction.cross(Vector3.UP)*float(side)*10;var vault:float=38.0 if side<0 else 46.0
			if not Profiles.compatible(point,24,vault,region,region.get("pockets",[])) or not covered(point,24,vault,height,maximum_depth,minimum_roof):tall=false;break
			grown.bank_lobes.append({"id":str(pool.id)+":magma:vault:"+str(side),"point":point,"level":parent.level,"chamber_radius":24.0,"chamber_height":vault,"cross_section_style":0,"biome_parent":parent_id,"parent":parent_id})
		if not tall:continue
		grown["bank_access"]=[{"from":parent_id,"to":parent_id,"points":PackedVector3Array([parent.point,center-direction*(radius+2)]),"half_width":1.0,"headroom":3.0,"entrance":false,"biome_parent":parent_id}];grown["precise_shore"]=true;grown["protected_dry_bank"]=true;grown["magma_large_lake"]=true
		var field=Field.new();field.maximum_depth=maximum_depth;field.minimum_roof=minimum_roof
		if not field.compile([result],height,[],result.get("cave_biome_regions",{})) or not dry_bank(field,grown):continue
		return result
	return region
