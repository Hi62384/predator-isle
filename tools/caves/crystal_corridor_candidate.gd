extends RefCounted
## Private SAME-volume proposal: only existing real wide corridor/room joins
## can accept minerals outside the original entire protected8x8m passage.
## Narrow passages remain clear;no SDF widening or new cave engine.
const Regions=preload("res://scripts/caves/biome_regions.gd")
const MAX_CANDIDATES:int=64
const MAX_FORMS:int=24
static func order(a:Dictionary,b:Dictionary)->bool:return a.priority<b.priority or (a.priority==b.priority and a.id<b.id)
static func propose(candidates:Array,seen:Dictionary,region:Dictionary,edge:Dictionary,total:float,along:float,middle:Vector3,side:Vector3,station_id:int,origin:Vector3,seed_id:int,density:float)->void:
	if middle.x<origin.x-36 or middle.x>origin.x+100 or middle.z<origin.z-36 or middle.z>origin.z+100 or middle.y<origin.y-36 or middle.y>origin.y+100:return
	var assignment:Dictionary=Regions.along_edge(region.get("cave_biome_regions",{}),str(edge.get("from","")),str(edge.get("to","")),along,total)
	if float(assignment.weights.get("crystal",0))<.6:return
	var theme:String=str(assignment.candidate_ids.get("crystal",""));var family:int=mini(5,int(Regions.random(theme,seed_id,"crystal/mineral")*6))
	for direction:int in range(3):
		var id:String="corridor/"+str(edge.get("from",""))+"/"+str(edge.get("to",""))+"/"+str(station_id)+"/"+str(direction)
		if seen.has(id) or Regions.random(id,seed_id,"corridor/admit")>density*.65:continue
		seen[id]=true;candidates.append({"id":id,"theme":theme,"family":family,"start":middle+Vector3.UP*3.5,"direction":Vector3.UP if direction==2 else side*(1 if direction==0 else -1),"priority":Regions.random(id,seed_id,"corridor/priority")})
		if candidates.size()>MAX_CANDIDATES:candidates.sort_custom(order);candidates.resize(MAX_CANDIDATES)
static func append(generator,field,regions:Array,seed_id:int,configuration:Dictionary)->int:
	if not configuration.get("corridor_growth",false) or float(configuration.get("density",.65))<=0:return 0
	var candidates:Array=[];var seen:Dictionary={};var origin:Vector3=generator.origin;var density:float=float(configuration.get("density",.65))
	for region:Dictionary in regions:
		if not region.get("valid",false) or region.get("cave_family",-1) in [6,7]:continue
		var regional:Vector2=Vector2(region.id)*1536
		if origin.x+64<regional.x-36 or origin.x>regional.x+1572 or origin.z+64<regional.y-36 or origin.z>regional.y+1572:continue
		for edge:Dictionary in region.edges+region.get("pocket_passages",[]):
			if edge.get("entrance",false):continue
			var points:PackedVector3Array=edge.points;var total:float=0;var station:float=0
			for index in range(points.size()-1):total+=points[index].distance_to(points[index+1])
			for index in range(points.size()-1):
				var a:Vector3=points[index];var b:Vector3=points[index+1];var length:float=a.distance_to(b);var first:int=maxi(0,ceili(station/8.0-.5));var last:int=ceili((station+length)/8.0-.5)-1;var start:float=station;station+=length
				if length<.01:continue
				var forward:=Vector3(b.x-a.x,0,b.z-a.z).normalized();var side:=Vector3(-forward.z,0,forward.x)
				if side.length_squared()<.9:continue
				for station_id:int in range(first,last+1):
					var along:float=(station_id+.5)*8.0;var middle:Vector3=a.lerp(b,(along-start)/length);propose(candidates,seen,region,edge,total,along,middle,side,station_id,origin,seed_id,density)
	candidates.sort_custom(order);var emitted:int=0
	for candidate:Dictionary in candidates:
		if emitted>=MAX_FORMS or generator.placements.size()>=160:break
		var root:Vector3=generator.boundary(field,candidate.start,candidate.direction,32)
		if not root.is_finite() or field.cell(root)!=generator.key:continue
		var axis:Vector3=field.normal(root);var height:float=minf(float(configuration.get("maximum_height",32)),1.2+Regions.random(candidate.id,seed_id,"corridor/height")*1.6);var width:float=height*(.06 if candidate.family==2 else .14)
		if candidate.family==4:width=height/sqrt(2)
		elif candidate.family==5:width=height*.55
		if generator.form(field,root,axis,width,height,candidate.family,Regions.random(candidate.id,seed_id,"corridor/broken")<.2,Regions.random(candidate.theme,seed_id,"crystal/weather")*.7,candidate.id,1,true,Regions.random(candidate.id,seed_id,"corridor/phase")*TAU):generator.placements[-1]["corridor_crystal"]=true;generator.placements[-1]["region_theme"]=candidate.theme;emitted+=1
	return emitted
