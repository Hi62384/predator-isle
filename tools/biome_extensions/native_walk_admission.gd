extends RefCounted
## Bounded test-only approach admission. Never changes terrain, moves a walker,
## relaxes its 45-degree floor limit, or counts a rejected route as a success.
const ANGLES:Array[int]=[0,15,-15,30,-30,45,-45,60,-60,75,-75,90,-90]
const MAX_GRADE_DEGREES:float=44
func support(space:PhysicsDirectSpaceState3D,terrain,walker,q:Vector2)->Dictionary:
	var p:=Vector3(q.x,0,q.y);var canonical:float=terrain.get_height_at(p)
	var up:=PhysicsRayQueryParameters3D.create(Vector3(q.x,canonical+2,q.y),Vector3(q.x,canonical+1000,q.y));up.exclude=[walker.get_rid()]
	var ceiling:Dictionary=space.intersect_ray(up)
	var top:float=minf(canonical+24,ceiling.position.y-.25) if not ceiling.is_empty() else canonical+24
	var down:=PhysicsRayQueryParameters3D.create(Vector3(q.x,top,q.y),Vector3(q.x,canonical-10,q.y));down.exclude=[walker.get_rid()]
	var floor:Dictionary=space.intersect_ray(down)
	if floor.is_empty():return {"accepted":false,"reason":"no_native_floor","xz":q,"canonical_y":canonical}
	var normal:Vector3=floor.normal
	if normal.y<cos(deg_to_rad(MAX_GRADE_DEGREES)):return {"accepted":false,"reason":"floor_exceeds_admitted_grade","xz":q,"normal":normal,"slope_degrees":rad_to_deg(acos(clampf(normal.y,-1,1)))}
	return {"accepted":true,"xz":q,"floor_y":floor.position.y,"normal":normal,"canonical_y":canonical,"ceiling_y":ceiling.position.y if not ceiling.is_empty() else INF,"floor_collider":str(floor.collider)}
func plan(space:PhysicsDirectSpaceState3D,terrain,walker,capsule:CapsuleShape3D,center:Vector2,side:Vector2)->Dictionary:
	var attempts:Array=[]
	for angle:int in ANGLES:
		var direction:Vector2=side.rotated(deg_to_rad(angle)).normalized();var probes:Array=[];var rejected:Dictionary={};var previous:Dictionary={}
		for index in range(121):
			var q:Vector2=center+direction*(-60+index);var sample:Dictionary=support(space,terrain,walker,q)
			if not sample.accepted:rejected=sample;break
			if not previous.is_empty() and absf(sample.floor_y-previous.floor_y)>tan(deg_to_rad(MAX_GRADE_DEGREES))*q.distance_to(previous.xz)+.01:
				rejected={"reason":"edge_exceeds_admitted_grade","xz":q};break
			# Exact declared capsule, above the actual native support plane. The
			# offset follows the vertical capsule/plane support relation; it is
			# only a proposed static spawn/overlap probe, never motion assistance.
			var height:float=capsule.height*.5-capsule.radius+capsule.radius/sample.normal.y+.05
			var clear:bool=false;var standing:=Vector3(q.x,sample.floor_y+height,q.y)
			for extra:float in [0.0,.025,.05,.1,.2]:
				standing.y=sample.floor_y+height+extra
				if standing.y+capsule.height*.5+.01>=sample.ceiling_y:continue
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,standing);query.exclude=[walker.get_rid()];query.margin=.001
				if space.intersect_shape(query,1).is_empty():clear=true;break
			if not clear:rejected={"reason":"declared_capsule_overlaps_native_geometry","xz":q};break
			sample["standing_center"]=standing;probes.append(sample);previous=sample
		if not rejected.is_empty():attempts.append({"angle_degrees":angle,"accepted":false,"first_rejection":rejected});continue
		attempts.append({"angle_degrees":angle,"accepted":true,"native_support_probes":probes.size()})
		var route:Array[Vector3]=[]
		for step in range(1,13):
			var sample:Dictionary=probes[step*10];route.append(Vector3(sample.xz.x,sample.floor_y+.95,sample.xz.y))
		var start:Vector3=probes[0].standing_center
		for step in range(11,-1,-1):route.append(route[step-1] if step>0 else start)
		return {"accepted":true,"angle_degrees":angle,"start":start,"route":route,"probes":probes,"attempts":attempts,"admitted_maximum_grade_degrees":MAX_GRADE_DEGREES,"capsule_floor_limit_degrees":45.0,"nominal_horizontal_return_metres":240}
	var curved:Dictionary=graph_plan(space,terrain,walker,capsule,center,side)
	curved["straight_attempts"]=attempts
	return curved

func standing_support(space:PhysicsDirectSpaceState3D,terrain,walker,capsule:CapsuleShape3D,q:Vector2)->Dictionary:
	var sample:Dictionary=support(space,terrain,walker,q)
	if not sample.accepted:return sample
	var height:float=capsule.height*.5-capsule.radius+capsule.radius/sample.normal.y+.05
	for extra:float in [0.0,.025,.05,.1,.2]:
		var standing:=Vector3(q.x,sample.floor_y+height+extra,q.y)
		if standing.y+capsule.height*.5+.01>=sample.ceiling_y:continue
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,standing);query.exclude=[walker.get_rid()];query.margin=.001
		if space.intersect_shape(query,1).is_empty():sample["standing_center"]=standing;return sample
	return {"accepted":false,"reason":"declared_capsule_overlaps_native_geometry","xz":q}

func clear_edge(space:PhysicsDirectSpaceState3D,walker,capsule:CapsuleShape3D,a:Dictionary,b:Dictionary)->bool:
	if absf(a.floor_y-b.floor_y)>tan(deg_to_rad(MAX_GRADE_DEGREES))*a.xz.distance_to(b.xz)+.01:return false
	# Sweep BOTH ways with the actual one-sided shape policy. A hollow volume
	# must not admit a one-way escape that fails on the return journey.
	for pair:Array in [[a,b],[b,a]]:
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,pair[0].standing_center);query.motion=pair[1].standing_center-pair[0].standing_center;query.exclude=[walker.get_rid()];query.margin=.001
		var motion:PackedFloat32Array=space.cast_motion(query)
		if motion.size()!=2 or motion[0]<.999:return false
	return true

func graph_plan(space:PhysicsDirectSpaceState3D,terrain,walker,capsule:CapsuleShape3D,center:Vector2,side:Vector2)->Dictionary:
	var centre_sample:Dictionary=standing_support(space,terrain,walker,capsule,center)
	if not centre_sample.accepted:return {"accepted":false,"reason":"membrane_midpoint_not_admitted","midpoint":centre_sample}
	if not is_finite(centre_sample.ceiling_y):return {"accepted":false,"reason":"No actual overhead at the required membrane midpoint"}
	# A bounded 192m square, aligned with the actual 2m near-terrain lattice.
	# This is fixture setup only, not a new game navigation system.
	const RADIUS:int=48
	const STEP:float=2
	var anchor:=Vector2(floorf(center.x/STEP)*STEP,floorf(center.y/STEP)*STEP)
	var graph:=AStar3D.new();var indices:Dictionary={};var samples:Dictionary={};var negative:Array=[];var positive:Array=[];var rejected:int=0;var next_id:int=0
	for z in range(-RADIUS,RADIUS+1):
		for x in range(-RADIUS,RADIUS+1):
			var q:Vector2=anchor+Vector2(x,z)*STEP;var sample:Dictionary=standing_support(space,terrain,walker,capsule,q)
			if not sample.accepted:rejected+=1;continue
			var cell:=Vector2i(x,z);var id:int=next_id;next_id+=1;indices[cell]=id;samples[id]=sample
			graph.add_point(id,Vector3(q.x,sample.floor_y+.95,q.y))
			var projection:float=(q-center).dot(side)
			if projection<=-62:negative.append({"id":id,"score":q.distance_squared_to(center-side*64)})
			if projection>=62:positive.append({"id":id,"score":q.distance_squared_to(center+side*64)})
	var edges:int=0
	for cell:Vector2i in indices:
		for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE,Vector2i(1,-1)]:
			var neighbor:Vector2i=cell+direction
			if not indices.has(neighbor):continue
			var a:int=indices[cell];var b:int=indices[neighbor]
			if clear_edge(space,walker,capsule,samples[a],samples[b]):graph.connect_points(a,b);edges+=1
	var center_id:int=next_id;graph.add_point(center_id,Vector3(center.x,centre_sample.floor_y+.95,center.y));samples[center_id]=centre_sample
	for cell:Vector2i in indices:
		var id:int=indices[cell]
		if samples[id].xz.distance_to(center)>STEP*1.6:continue
		if clear_edge(space,walker,capsule,centre_sample,samples[id]):graph.connect_points(center_id,id);edges+=1
	for candidates:Array in [negative,positive]:candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.id<b.id if a.score==b.score else a.score<b.score)
	var paths:Array[PackedVector3Array]=[];var chosen:Array[int]=[]
	for candidates:Array in [negative,positive]:
		var path:=PackedVector3Array();var selected:int=-1
		for candidate:Dictionary in candidates.slice(0,32):
			path=graph.get_point_path(center_id,candidate.id)
			if path.size()>1:selected=candidate.id;break
		if path.size()<2:return {"accepted":false,"reason":"No complete two-sided native capsule route through the same midpoint","graph_nodes":samples.size(),"graph_edges":edges,"rejected_cells":rejected,"negative_goal_candidates":negative.size(),"positive_goal_candidates":positive.size()}
		paths.append(path);chosen.append(selected)
	var outbound:Array[Vector3]=[]
	for index in range(paths[0].size()-1,-1,-1):outbound.append(paths[0][index])
	for index in range(1,paths[1].size()):outbound.append(paths[1][index])
	var horizontal_length:float=0
	for index in range(1,outbound.size()):horizontal_length+=Vector2(outbound[index].x-outbound[index-1].x,outbound[index].z-outbound[index-1].z).length()
	if horizontal_length<120:return {"accepted":false,"reason":"Native graph path shorter than the declared minimum approach"}
	var route:Array[Vector3]=[]
	for index in range(1,outbound.size()):route.append(outbound[index])
	var start:Vector3=samples[chosen[0]].standing_center
	for index in range(outbound.size()-2,-1,-1):route.append(outbound[index] if index>0 else start)
	var path_probes:Array=[]
	for path_id:int in graph.get_id_path(center_id,chosen[0]):path_probes.append(samples[path_id])
	for path_id:int in graph.get_id_path(center_id,chosen[1]):path_probes.append(samples[path_id])
	return {"accepted":true,"curved_native_route":true,"start":start,"route":route,"probes":path_probes,"graph_nodes":samples.size(),"graph_edges":edges,"rejected_cells":rejected,"admitted_maximum_grade_degrees":MAX_GRADE_DEGREES,"capsule_floor_limit_degrees":45.0,"nominal_horizontal_return_metres":horizontal_length*2,"same_membrane_midpoint":center,"bidirectional_capsule_sweeps":true}
