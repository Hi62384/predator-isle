extends RefCounted
## Canonical regional chamber growth. Joined,unequal geological lobes extend
## existing rooms at their same floor,not disconnected decorative rock props.
## Admission reserves every existing local passage and room at other heights.
const MAX_POCKETS:int=24
static func random(cell:Vector2i,seed_id:int,salt:int)->float:
	var h:int=(cell.x*374761393+cell.y*668265263+seed_id*69069+salt*1274126177)&0x7fffffff;h=((h^(h>>13))*1274126177)&0x7fffffff;return float(h^(h>>16))/2147483647.0
static func compatible(p:Vector3,radius:float,headroom:float,region:Dictionary,pockets:Array)->bool:
	for other:Dictionary in region.nodes+pockets:
		if int(other.get("level",0))<0:continue
		var separation:float=absf(p.y-other.point.y)
		if separation<=.25 or separation>=maxf(headroom,other.chamber_height)+3:continue
		if Vector2(p.x-other.point.x,p.z-other.point.z).length()<radius+other.chamber_radius+2:return false
	for edge:Dictionary in region.edges:
		var points:PackedVector3Array=edge.points;var clearance:float=radius+edge.half_width+2
		for i in range(points.size()-1):
			var a:Vector3=points[i];var b:Vector3=points[i+1]
			if p.x+clearance<minf(a.x,b.x) or p.x-clearance>maxf(a.x,b.x) or p.z+clearance<minf(a.z,b.z) or p.z-clearance>maxf(a.z,b.z):continue
			var ab:=Vector2(b.x-a.x,b.z-a.z);var q:=Vector2(p.x-a.x,p.z-a.z);var t:float=clampf(q.dot(ab)/maxf(ab.length_squared(),.000001),0,1)
			if (q-ab*t).length()>=clearance:continue
			var floor_y:float=lerpf(a.y,b.y,t);var separation:float=absf(p.y-floor_y)
			if separation>.25 and separation<maxf(headroom,edge.headroom)+3:return false
	return true
static func make(region:Dictionary,height:Callable,seed_id:int,maximum_depth:float=400,minimum_roof:float=10)->Array:
	var pockets:Array=[]
	if not region.get("valid",false) or not height.is_valid():return pockets
	var cell:Vector2i=region.id;var soluble:bool=int(region.get("geology",0)) in [0,2,5];var chance:float=.6 if soluble else .22
	for index in range(region.nodes.size()):
		var node:Dictionary=region.nodes[index]
		if int(node.get("level",-1))<0 or random(cell,seed_id,900+index)>chance:continue
		var count:int=2 if soluble else 1
		for lobe in range(count):
			if pockets.size()>=MAX_POCKETS:break
			var salt:int=1000+index*16+lobe*4;var angle:float=random(cell,seed_id,salt)*TAU;var radius:float=22+random(cell,seed_id,salt+1)*6;var span:float=23+random(cell,seed_id,salt+2)*7;var p:Vector3=node.point+Vector3(cos(angle)*span,0,sin(angle)*span);var headroom:float=18+random(cell,seed_id,salt+3)*8
			if not compatible(p,radius,headroom,region,pockets):continue
			# Reserve a genuinely capsule-wide,flat neck as well as the lobe.
			# No narrow accidental overlap or incompatible crossing may be the
			# only route into a geological enlargement.
			var neck_clear:bool=true
			for station in range(ceili(span/2)+1):
				if not compatible(node.point.lerp(p,float(station)/ceili(span/2)),4,8,region,pockets):neck_clear=false;break
			if not neck_clear:continue
			var admitted:bool=true
			for z in range(-2,3):
				for x in range(-2,3):
					if Vector2(x,z).length()>2.1:continue
					var surface:float=height.call(p.x+x*radius*.5,p.z+z*radius*.5)
					if not is_finite(surface) or surface-p.y>maximum_depth-4 or surface-p.y<headroom+minimum_roof+4:admitted=false
			if not admitted:continue
			pockets.append({"id":str(node.id)+":lobe:"+str(lobe),"point":p,"level":node.level,"chamber_radius":radius,"chamber_height":headroom,"parent":node.id})
	return pockets
static func passages(region:Dictionary,pockets:Array)->Array:
	var result:Array=[]
	for pocket:Dictionary in pockets:
		for parent:Dictionary in region.nodes:
			if parent.id!=pocket.parent:continue
			result.append({"from":parent.id,"to":pocket.id,"points":PackedVector3Array([parent.point,pocket.point]),"half_width":4.0,"headroom":8.0,"entrance":false,"maximum_grade":0.0});break
	return result
static func protected_edges(pockets:Array)->Array:
	# Inter-region connectors must also protect canonical chamber growth.
	# These zero-length numeric guards are NOT traversable graph edges.
	var guards:Array=[]
	for pocket:Dictionary in pockets:
		if int(pocket.get("level",-1))<0:continue
		guards.append({"from":pocket.id,"to":pocket.id,"points":PackedVector3Array([pocket.point,pocket.point]),"half_width":pocket.chamber_radius,"headroom":pocket.chamber_height,"entrance":false})
	return guards
