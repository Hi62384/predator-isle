extends RefCounted
## Cave core: shared underground dependency. Deterministic, locally generated
## regions with an explicitly exit-rooted graph; neighboring regions connect
## only through the same canonical solved edge. Pure descriptor generation; runtime installation is managed separately.
const Solver=preload("res://scripts/caves/route_solver.gd")
const Profiles=preload("res://scripts/caves/chamber_profiles.gd")
const Basins=preload("res://scripts/caves/seepage_basins.gd")
const REGION_METRES:float=1536
const MAX_REGIONS:int=32
var height:Callable
var water:Callable
var seed_id:int=73921
var max_depth:float=400
var half_width:float=4
var headroom:float=8
var minimum_roof:float=10
var maximum_grade:float=.2
var activity:float=.85
var chamber_variety:bool=false
var geological_morphology:bool=false
var seepage_density:float=0
var flat_radius:float=26
var region_context:Callable
var region_decorator:Callable
var region_finalizer:Callable
var access_admission:Callable
var _active_context:Dictionary={}
var _regions:Dictionary={}
var _ring:Array[Vector2i]=[]
var last_support_conflict:Dictionary={}
func configure(surface:Callable,water_surface:Callable,seed_value:int,depth:float=400)->void:
	height=surface;water=water_surface;seed_id=seed_value;max_depth=depth;_regions.clear();_ring.clear()
func random(cell:Vector2i,salt:int)->float:
	var h:int=(cell.x*374761393+cell.y*668265263+seed_id*69069+salt*1274126177)&0x7fffffff;h=((h^(h>>13))*1274126177)&0x7fffffff;return float(h^(h>>16))/2147483647.0
func curve(control:PackedVector2Array)->PackedVector2Array:
	var path:=PackedVector2Array()
	for segment in range(control.size()-1):
		var a:Vector2=control[segment];var b:Vector2=control[segment+1];var before:Vector2=control[maxi(0,segment-1)];var after:Vector2=control[mini(control.size()-1,segment+2)]
		var c:Vector2=a+(b-before)/6;var d:Vector2=b-(after-a)/6;var count:int=maxi(2,ceili((a.distance_to(c)+c.distance_to(d)+d.distance_to(b))/6))
		for i in range(count):
			var t:float=float(i)/count;var s:float=1-t;path.append(a*s*s*s+c*3*s*s*t+d*3*s*t*t+b*t*t*t)
	path.append(control[-1]);return path
func node_floor(p:Vector2,depth:float)->Dictionary:
	var low:float=-INF;var high:float=INF
	for dz:int in [-1,0,1]:
		for dx:int in [-1,0,1]:
			var h:float=height.call(p.x+dx*24,p.y+dz*24)
			if not is_finite(h):return {}
			low=maxf(low,h-max_depth+4+float(_active_context.get("planning_depth_reserve",0)));high=minf(high,h-minimum_roof-18)
	if low>high:return {}
	return {"point":Vector3(p.x,clampf(float(height.call(p.x,p.y))-depth,low,high),p.y),"half_width":half_width,"headroom":headroom,"chamber_radius":18.0,"chamber_height":18.0}
func route(a:Dictionary,b:Dictionary,controls:PackedVector2Array,entry:bool=false,extra_depth_reserve:float=0)->Dictionary:
	var path:PackedVector2Array=curve(controls);var cover:=PackedFloat32Array()
	if entry:
		var length_m:float=0;var distances:=PackedFloat64Array([0])
		for i in range(1,path.size()):length_m+=path[i].distance_to(path[i-1]);distances.append(length_m)
		for distance:float in distances:cover.append(smoothstep(0,.75,distance/length_m))
	var reserve:float=maxf(extra_depth_reserve,float(_active_context.get("planning_depth_reserve",0)));var solved:Dictionary=Solver.solve(path,height,half_width,headroom,minimum_roof,max_depth-reserve,maximum_grade,a.point.y,b.point.y,cover,0 if entry else flat_radius,flat_radius)
	if not solved.valid:return {}
	return {"from":a.id,"to":b.id,"points":solved.points,"half_width":half_width,"headroom":headroom,"entrance":entry,"maximum_grade":solved.maximum_grade,"minimum_measured_roof_m":solved.minimum_measured_roof_m,"maximum_measured_depth_m":solved.maximum_measured_depth_m}
func supported_join(candidate:Dictionary,retained:Array)->bool:
	# A union is not a bridge: overlapping air removes the higher route's
	# floor. Reject incompatible near-height crossings before emitting them.
	# Same-level junctions and genuinely separated over/underpasses are valid.
	last_support_conflict={};var points:PackedVector3Array=candidate.points
	for edge:Dictionary in retained:
		var previous:PackedVector3Array=edge.points;var clearance:float=float(candidate.half_width)+float(edge.half_width)+2
		for i in range(points.size()-1):
			var a:Vector3=points[i];var b:Vector3=points[i+1];var ab:=Vector2(b.x-a.x,b.z-a.z)
			for j in range(previous.size()-1):
				var c:Vector3=previous[j];var d:Vector3=previous[j+1]
				if maxf(a.x,b.x)+clearance<minf(c.x,d.x) or minf(a.x,b.x)-clearance>maxf(c.x,d.x) or maxf(a.z,b.z)+clearance<minf(c.z,d.z) or minf(a.z,b.z)-clearance>maxf(c.z,d.z):continue
				var cd:=Vector2(d.x-c.x,d.z-c.z)
				for t:float in [0.0,.5,1.0]:
					var p:Vector3=a.lerp(b,t);var q:=Vector2(p.x-c.x,p.z-c.z);var u:float=clampf(q.dot(cd)/maxf(cd.length_squared(),.000001),0,1)
					if (q-cd*u).length()>=clearance:continue
					var separation:float=absf(p.y-lerpf(c.y,d.y,u))
					if separation>.35 and separation<maxf(candidate.headroom,edge.headroom)+3:last_support_conflict={"point":p,"separation":separation,"edge":edge.from+">"+edge.to};return false
				for u:float in [0.0,.5,1.0]:
					var p:Vector3=c.lerp(d,u);var q:=Vector2(p.x-a.x,p.z-a.z);var t:float=clampf(q.dot(ab)/maxf(ab.length_squared(),.000001),0,1)
					if (q-ab*t).length()>=clearance:continue
					var separation:float=absf(p.y-lerpf(a.y,b.y,t))
					if separation>.35 and separation<maxf(candidate.headroom,edge.headroom)+3:last_support_conflict={"point":p,"separation":separation,"edge":edge.from+">"+edge.to};return false
	return true
func _build(cell:Vector2i)->Dictionary:
	var empty:Dictionary={"id":cell,"nodes":[],"edges":[],"entrances":[],"valid":false,"reason":"no_admitted_dry_return_route"}
	if not height.is_valid() or not water.is_valid() or max_depth<80 or max_depth>10000:return empty
	if random(Vector2i(floori(float(cell.x)/3),floori(float(cell.y)/3)),17)>activity:return empty
	var center:Vector2=(Vector2(cell)+Vector2(.4+.2*random(cell,1),.4+.2*random(cell,2)))*REGION_METRES;var angle:float=random(cell,3)*TAU;var nodes:Array=[];var edges:Array=[];var entrances:Array=[]
	var first:Dictionary=node_floor(center+Vector2(-120,-120).rotated(angle),minf(50,max_depth*.2))
	if first.is_empty():return empty
	first.id="%d:%d:0:0"%[cell.x,cell.y];first["level"]=0
	# Every admitted region has its own proven numeric route back to dry land.
	# Neighbors can join, but cannot be the sole presumed exit of an unvalidated
	# component. No global flood-fill, load-order state or unbounded search.
	for attempt in range(24):
		var yaw:float=angle+TAU*random(cell,40+attempt);var p:Vector2=center+Vector2(cos(yaw),sin(yaw))*(360+random(cell,80+attempt)*220);var terrain:float=height.call(p.x,p.y);var wet:float=water.call(p.x,p.y)
		if not is_finite(terrain) or not is_finite(wet) or terrain<=wet+12:continue
		var low:float=terrain;var high:float=terrain
		for offset:Vector2 in [Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:
			var h:float=height.call(p.x+offset.x,p.y+offset.y);low=minf(low,h);high=maxf(high,h)
		if high-low>3:continue
		var entry:Dictionary={"id":"%d:%d:entrance"%[cell.x,cell.y],"point":Vector3(p.x,low-.1,p.y),"level":-1};var q:=Vector2(first.point.x,first.point.z);var middle:Vector2=(p+q)*.5+Vector2(-(q-p).y,(q-p).x)*.12
		var access:Dictionary=route(entry,first,PackedVector2Array([p,middle,q]),true)
		if access.is_empty():continue
		if access_admission.is_valid() and not access_admission.call(access):continue
		nodes.append(entry);nodes.append(first);edges.append(access);entrances.append(entry.id);break
	if entrances.is_empty():return empty
	var previous:Dictionary=first
	for level in range(4):
		var layer_nodes:Array=[]
		for corner in range(4):
			var offset:Vector2=[Vector2(-120,-120),Vector2(120,-120),Vector2(120,120),Vector2(-120,120)][corner];var p:Vector2=center+offset.rotated(angle);var node:Dictionary=first if level==0 and corner==0 else node_floor(p,[minf(50,max_depth*.2),max_depth*.34,max_depth*.65,max_depth*.9][level])
			if node.is_empty():break
			node.id="%d:%d:%d:%d"%[cell.x,cell.y,level,corner];node["level"]=level
			if level==0 and corner==0:layer_nodes.append(first);continue
			var a:=Vector2(previous.point.x,previous.point.z);var b:=Vector2(node.point.x,node.point.z);var controls:=PackedVector2Array([a,b])
			if corner==0:
				controls=PackedVector2Array([a,center+Vector2(-450,-450).rotated(angle),center+Vector2(450,-450).rotated(angle),center+Vector2(450,450).rotated(angle),center+Vector2(-450,450).rotated(angle),b])
			var connection:Dictionary=route(previous,node,controls)
			if corner==0:
				# Bounded canonical geometric alternatives,not entrance/site rerolls.
				# Descent spirals must leave the existing access on a compatible side.
				for alternative in range(8):
					if not connection.is_empty() and supported_join(connection,edges):break
					connection={};var winding:=PackedVector2Array([a]);var turn:float=angle+float(alternative/2)*PI*.5;var clockwise:float=1 if alternative%2==0 else -1
					for corner_id in range(4):winding.append(center+Vector2(-450,-450).rotated(turn+clockwise*corner_id*PI*.5))
					winding.append(b);connection=route(previous,node,winding)
				if not connection.is_empty() and not supported_join(connection,edges):connection={}
			if connection.is_empty():break
			nodes.append(node);edges.append(connection);layer_nodes.append(node);previous=node
		if layer_nodes.size()!=4:break
		var a:=Vector2(layer_nodes[-1].point.x,layer_nodes[-1].point.z);var b:=Vector2(layer_nodes[0].point.x,layer_nodes[0].point.z);var loop:Dictionary=route(layer_nodes[-1],layer_nodes[0],PackedVector2Array([a,b]))
		if not loop.is_empty():edges.append(loop)
		previous=layer_nodes[0]
	var result:Dictionary={"id":cell,"center":center,"nodes":nodes,"edges":edges,"entrances":entrances,"valid":true,"reason":"","default_biome_id":0,"geology":mini(5,int(random(cell,102)*6))}
	if geological_morphology:result["cross_section_style"]=result.geology
	if region_decorator.is_valid():result=region_decorator.call(result,_active_context)
	if chamber_variety and not result.has("pockets"):
		result["pockets"]=Profiles.make(result,height,seed_id,max_depth,minimum_roof);result["pocket_passages"]=Profiles.passages(result,result.pockets)
	if seepage_density>0:result["pools"]=Basins.make(result,seed_id,seepage_density)
	if region_finalizer.is_valid():result=region_finalizer.call(result)
	return result
func region(cell:Vector2i)->Dictionary:
	if _regions.has(cell):return _regions[cell]
	var previous_width:float=half_width;var previous_height:float=headroom;var previous_flat:float=flat_radius;_active_context=region_context.call(cell) if region_context.is_valid() else {};half_width=float(_active_context.get("half_width",half_width));headroom=float(_active_context.get("headroom",headroom));flat_radius=float(_active_context.get("flat_radius",flat_radius));var data:Dictionary=_build(cell);half_width=previous_width;headroom=previous_height;flat_radius=previous_flat
	# Even a closed/rejected region retains its surface construction context
	# for neighboring tunnels and ground-only portal cells. This is palette
	# metadata,NOT an assertion that the rejected region contains a cave.
	if _active_context.has("render_style"):data["render_style"]=_active_context.render_style
	if _active_context.has("hive_region"):data["hive_region"]=_active_context.hive_region
	_active_context={}
	if _ring.size()>=MAX_REGIONS:_regions.erase(_ring.pop_front())
	_ring.append(cell);_regions[cell]=data;return data
func connection(first:Vector2i,second:Vector2i)->Dictionary:
	if absi(first.x-second.x)+absi(first.y-second.y)!=1:return {}
	if first.x>second.x or (first.x==second.x and first.y>second.y):var swap:Vector2i=first;first=second;second=swap
	var a:Dictionary=region(first);var b:Dictionary=region(second)
	if not a.valid or not b.valid:return {}
	var from_node:Dictionary=a.nodes[1];var to_node:Dictionary=b.nodes[1];var p:=Vector2(from_node.point.x,from_node.point.z);var q:=Vector2(to_node.point.x,to_node.point.z);var mid:Vector2=(p+q)*.5+Vector2(-(q-p).y,(q-p).x)*(.08*sin(float(first.x+first.y)*1.71))
	var protected:Array=a.edges.duplicate();protected.append_array(b.edges)
	for region_data:Dictionary in [a,b]:
		protected.append_array(region_data.get("pocket_passages",[]));protected.append_array(Profiles.protected_edges(region_data.get("pockets",[])))
		var beds:Array=[]
		for pool:Dictionary in region_data.get("pools",[]):
			# Reserve the whole conservative bed envelope,not only either lobe.
			var guard:Dictionary=pool.bed.duplicate();guard.chamber_radius=pool.radius;beds.append(guard)
			for bank:Dictionary in pool.get("bank_lobes",[]):beds.append(bank)
			protected.append_array(pool.get("stream_edges",[]))
		protected.append_array(Profiles.protected_edges(beds))
	var depth_reserve:float=2 if a.get("cave_family",-1)==7 or b.get("cave_family",-1)==7 else 0;var solved:Dictionary=route(from_node,to_node,PackedVector2Array([p,mid,q]),false,depth_reserve)
	for offset:float in [.0,.12,-.12,.24,-.24,.36,-.36]:
		if not solved.is_empty() and supported_join(solved,protected):break
		mid=(p+q)*.5+Vector2(-(q-p).y,(q-p).x)*offset;solved=route(from_node,to_node,PackedVector2Array([p,mid,q]),false,depth_reserve)
	if not solved.is_empty() and not supported_join(solved,protected):return {}
	if not solved.is_empty():
		solved["id"]="%d:%d>%d:%d"%[first.x,first.y,second.x,second.y]
		if geological_morphology:solved["cross_section_style"]=int(a.get("cross_section_style",0))
	return solved
