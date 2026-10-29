extends RefCounted
## Persistent world-space grips with stance/reach/release states. Legs use a
## two-bone hinge; vines use fixed-length FABRIK; passive chains use damped
## Verlet constraints. Digits/bulbs are skinned to these same terminal frames.
const Guard=preload("res://scripts/blobs/blob_curve_guard.gd")
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
const JOINTS=8
const MAX_CHAINS=16
var actor: Node3D
var chains: Array[Dictionary]=[]
var rests:=PackedVector4Array()
var poses:=PackedVector4Array()
var rest_normals:=PackedVector4Array()
var pose_normals:=PackedVector4Array()
var planted_count:=0
var active_count:=0
var maximum_lock_error:=.0
var maximum_length_error:=.0
var noise:=FastNoiseLite.new()
var elapsed:=.0
var gait_enabled:=true
var secondary_enabled:=true
var force_release:=false
var corrected_poses:=0
var rejected_poses:=0
var collision_corrections:=0
var collision_enabled:=true
var full_guard_checks:=0

func configure(owner_actor: Node3D, definitions: Array) -> void:
	actor=owner_actor
	noise.seed=int(actor.anatomy.dna.seed)
	noise.frequency=.4
	for i in definitions.size():
		var d: Dictionary=definitions[i].duplicate(true)
		var points:=PackedVector3Array()
		for p: Vector3 in d.rest: points.append(actor.global_position+Vector3.UP*actor.solver.height+actor.solver.map_bound(p,int(d.group),1.0))
		d["frame_seed"]=actor.solver.pose_frame*Frames.normals(d.rest)[0]
		if actor.anatomy.features[d.feature_id].feature_type=="membrane_support":d.kind="web"
		d["bend"]=Vector3.ZERO;d["bend_velocity"]=Vector3.ZERO
		d["points"]=points
		d["previous"]=points.duplicate()
		d["target"]=_terrain_target(points[-1])
		d["from"]=points[-1]
		d["goal"]=d.target
		d["state"]="stance"
		d["timer"]=float(d.phase)*.75
		d["duration"]=.5
		d["active"]=false
		d["plant_root"]=points[0]
		d["pull_distance"]=float(d.length)*.28
		d["pull_duration"]=.8
		d["cycles"]=0
		d["motion_phase"]="plant"
		d["planted_reference"]=d.target
		for item:Dictionary in actor.anatomy.appendages:
			if item.feature.id==d.feature_id:Guard.prepare(d,item.mesh);break
		chains.append(d)
	# Keep a small coordinated set of prime movers. Remaining vines have an
	# explicit secondary role and retain bounded secondary animation.
	for kind in ["vine","leg"]:
		var candidates:Array[Dictionary]=[]
		for c:Dictionary in chains:
			c["motor"]=false if c.kind==kind else c.get("motor",false)
			if c.kind!=kind:continue
			var root:=_root(c)
			if root.y-_terrain_target(root).y<float(c.length)*(.82 if kind=="vine" else .94):candidates.append(c)
		candidates.sort_custom(func(a:Dictionary,b:Dictionary):return (_root(a).y-(_root(a)-actor.global_position).dot(actor.direction)*.5)<(_root(b).y-(_root(b)-actor.global_position).dot(actor.direction)*.5))
		for i in mini(candidates.size(),3 if kind=="vine" else 4):candidates[i].motor=true
		for c:Dictionary in chains:
			if c.kind==kind:actor.anatomy.features[c.feature_id]["animation_role"]="locomotor" if c.motor else "secondary"
	_upload()

func _terrain_target(p: Vector3) -> Vector3:
	var result:=p
	if is_instance_valid(actor.terrain): result.y=actor.terrain.get_height_at(p)
	else: result.y=actor.global_position.y
	return result

func _root(c: Dictionary) -> Vector3:
	return actor.global_position+Vector3.UP*actor.solver.height+actor.solver.map_bound(c.rest[0],int(c.group),1.0)

func _active(c: Dictionary, mode: String) -> bool:
	if not gait_enabled or c.kind not in ["vine","leg"] or not c.get("motor",false): return false
	var root:=_root(c)
	if root.y-_terrain_target(root).y>float(c.length)*(.82 if c.kind=="vine" else .94): return false
	if c.kind=="leg": return mode in ["limb","hybrid","multicontact"]
	return mode in ["vine","hybrid","drag","multicontact"]

func traction(mode: String) -> float:
	var active:=0
	var planted:=0
	for c in chains:
		if _active(c,mode):
			active+=1
			if c.state=="stance": planted+=1
	if active==0: return 0.0
	return clampf(float(planted)/maxf(float(active)*.45,1.0),0.0,1.0)

func step(delta: float, mode: String, movement: Vector3, speed: float) -> void:
	var dt:=clampf(delta,.0,.033334)
	elapsed+=dt
	active_count=0; planted_count=0; maximum_lock_error=.0; maximum_length_error=.0
	for c in chains:
		c.active=_active(c,mode)
		if c.active: active_count+=1
		if c.active and c.state=="stance": planted_count+=1
	var travel:=movement.normalized()*(1.0 if speed>=0 else -1.0)
	for i in chains.size():
		var c: Dictionary=chains[i]
		var root:=_root(c)
		var previous_pose:PackedVector3Array=c.points.duplicate()
		if c.active:
			var reach: float=c.length*.96
			var moving:=absf(speed)>.025
			if c.state=="stance":
				if moving: c.timer+=dt
				var overdue: bool=c.timer>float(c.pull_duration)
				c.motion_phase="plant" if c.timer<.06 else "pull"
				var overstretched: bool=root.distance_to(c.target)>reach
				if force_release or overstretched or (overdue and (active_count==1 or planted_count>maxi(1,active_count/2))):
					_begin_reach(c,root,travel,speed)
					planted_count-=1
			if c.state=="reach":
				c.timer+=dt
				var t:=clampf(float(c.timer)/float(c.duration),.0,1.0)
				c.motion_phase="release" if t<.18 else ("recover" if t<.65 else "reach")
				var smooth:=t*t*t*(10.0+t*(-15.0+t*6.0))
				var lift:=16.0*t*t*(1.0-t)*(1.0-t)*minf(float(c.length)*.22,.42)
				c.target=c.from.lerp(c.goal,smooth)+Vector3.UP*lift
				if t>=1:
					c.state="stance"; c.timer=.0; c.target=c.goal; c.planted_reference=c.goal; planted_count+=1
					c.plant_root=root;c.pull_distance=minf(float(c.length)*.32,maxf(.1,(c.target-root).dot(travel)*.85));c.pull_duration=clampf(float(c.pull_distance)/maxf(absf(speed),.2),.35,1.3);c.cycles+=1;c.motion_phase="plant"
			if c.kind=="leg": _solve_leg(c,root,c.target)
			else: _solve_vine(c,root,c.target)
			if c.state=="stance":
				var error: float=c.points[-1].distance_to(c.planted_reference)
				if error>.015: _begin_reach(c,root,travel,speed)
				else: maximum_lock_error=maxf(maximum_lock_error,error)
		elif c.kind=="web":
			for j in JOINTS:c.points[j]=actor.global_position+Vector3.UP*actor.solver.height+actor.solver.map_point(c.rest[j])
		else: _passive(c,root,dt,i)
		if collision_enabled and c.active:_avoid_obstacles(c)
		var local:=PackedVector3Array()
		for p:Vector3 in c.points:local.append(p-actor.global_position-Vector3.UP*actor.solver.height)
		var seed:Vector3=c.frame_seed
		var guarded:bool=c.active
		if guarded:full_guard_checks+=1
		if guarded and not Guard.valid(c,local,seed):
			corrected_poses+=1
			var root_delta:Vector3=root-previous_pose[0]
			var accepted:=false
			for attempt in 4:
				var blend:=pow(.5,float(attempt+1));local.clear()
				for j in JOINTS:local.append((previous_pose[j]+root_delta).lerp(c.points[j],blend)-actor.global_position-Vector3.UP*actor.solver.height)
				if Guard.valid(c,local,seed):
					for j in JOINTS:c.points[j]=local[j]+actor.global_position+Vector3.UP*actor.solver.height
					accepted=true;break
			if not accepted:
				rejected_poses+=1
				for j in JOINTS:c.points[j]=previous_pose[j]+root_delta
			c.previous=c.points.duplicate()
			if c.active:_begin_reach(c,root,travel,speed)
		if c.active and c.state=="stance":
			var final_error:float=c.points[-1].distance_to(c.planted_reference)
			if final_error>.015:_begin_reach(c,root,travel,speed)
			else:maximum_lock_error=maxf(maximum_lock_error,final_error)
		for j in JOINTS-1:
			maximum_length_error=maxf(maximum_length_error,absf(c.points[j].distance_to(c.points[j+1])-float(c.lengths[j])))
	planted_count=0
	for c:Dictionary in chains:
		if c.active and c.state=="stance":planted_count+=1
	force_release=false
	_upload()

func _begin_reach(c: Dictionary, root: Vector3, direction: Vector3, speed: float) -> void:
	c.state="reach"
	c.motion_phase="recover"
	c.timer=.0
	c.duration=clampf(float(c.length)*.22/maxf(absf(speed),.3),.24,.7)
	c.from=c.points[-1]
	var height:=root.y-_terrain_target(root).y
	var horizontal:=sqrt(maxf(float(c.length)*float(c.length)*.78-height*height,.02))
	var outward:=Vector3(c.rest[0].x,0,c.rest[0].z).normalized()
	var goal:=root+direction*horizontal*.78+outward*horizontal*.22
	goal=_terrain_target(goal)
	if goal.distance_to(root)>float(c.length)*.92:
		goal=root+(goal-root).normalized()*float(c.length)*.92
		goal=_terrain_target(goal)
	c.goal=goal

func _solve_vine(c: Dictionary, root: Vector3, target: Vector3) -> void:
	var points: PackedVector3Array=c.points
	var goal:=target
	if root.distance_to(goal)>float(c.length)*.999:
		goal=root+(goal-root).normalized()*float(c.length)*.999
	for iteration in 32:
		points[-1]=goal
		for j in range(JOINTS-2,-1,-1):
			var direction: Vector3=(points[j]-points[j+1]).normalized()
			if direction.length_squared()<.1: direction=Vector3.UP
			points[j]=points[j+1]+direction*float(c.lengths[j])
		points[0]=root
		for j in JOINTS-1:
			var direction: Vector3=(points[j+1]-points[j]).normalized()
			if direction.length_squared()<.1: direction=Vector3.DOWN
			points[j+1]=points[j]+direction*float(c.lengths[j])
		_limit_bends(c,points)
	_limit_bends(c,points)
	c.points=points

func _solve_leg(c: Dictionary, root: Vector3, target: Vector3) -> void:
	var upper:=.0
	var lower:=.0
	for j in JOINTS-1:
		if j<3: upper+=float(c.lengths[j])
		else: lower+=float(c.lengths[j])
	var delta:=target-root
	var distance:=clampf(delta.length(),absf(upper-lower)+.001,upper+lower-.001)
	var axis:=delta.normalized()
	if axis.length_squared()<.1: axis=Vector3.DOWN
	var preferred: Vector3=actor.solver.pose_frame*(c.rest[3]-c.rest[0])
	var bend: Vector3=preferred-axis*preferred.dot(axis)
	if bend.length_squared()<.001: bend=axis.cross(Vector3.RIGHT)
	if bend.length_squared()<.001: bend=axis.cross(Vector3.FORWARD)
	bend=bend.normalized()
	var along: float=(upper*upper+distance*distance-lower*lower)/(2.0*distance)
	var knee:=root+axis*along+bend*sqrt(maxf(upper*upper-along*along,.0))
	var goal:=root+axis*distance
	var points:=PackedVector3Array([root])
	var accumulated:=.0
	for j in range(1,JOINTS):
		if j<=3:
			accumulated+=float(c.lengths[j-1])
			points.append(root.lerp(knee,accumulated/maxf(upper,.001)))
		else:
			if j==4: accumulated=.0
			accumulated+=float(c.lengths[j-1])
			points.append(knee.lerp(goal,accumulated/maxf(lower,.001)))
	c.points=points
	_solve_vine(c,root,target)

func _passive(c:Dictionary,root:Vector3,dt:float,index:int)->void:
	# A bounded elastic bend mode preserves the appendage's grown curve; it
	# cannot coil a thick stalk into a crease under a point-gravity solver.
	var target:=Vector3(noise.get_noise_2d(elapsed*.7,index*19),-.25,noise.get_noise_2d(index*31,elapsed*.6))*.035
	if not secondary_enabled:target=Vector3.ZERO
	target.z-=clampf(float(actor.solver.acceleration)*.004,-.015,.015)
	c.bend_velocity+=((target-c.bend)*12-c.bend_velocity*7)*dt
	c.bend=(c.bend+c.bend_velocity*dt).limit_length(.05)
	for j in JOINTS:
		var t:=float(j)/float(JOINTS-1)
		c.points[j]=root+actor.solver.pose_frame*(c.rest[j]-c.rest[0])+c.bend*float(c.length)*t*t
	if c.kind=="leg":
		var clearance:=.0
		for j in range(1,JOINTS):clearance=maxf(clearance,_terrain_target(c.points[j]).y+.012-c.points[j].y)
		for j in range(1,JOINTS):c.points[j].y+=clearance*pow(float(j)/float(JOINTS-1),1.5)
	c.previous=c.points.duplicate()

func _upload() -> void:
	rests.clear(); poses.clear();rest_normals.clear();pose_normals.clear()
	for c in chains:
		var rest_axes:=Frames.normals(c.rest)
		var local_points:=PackedVector3Array()
		for point:Vector3 in c.points:local_points.append(point-actor.global_position-Vector3.UP*actor.solver.height)
		var axes:=Frames.normals(local_points,c.frame_seed)
		c.frame_seed=axes[0]
		for i in JOINTS:
			var rest: Vector3=c.rest[i]
			var pose: Vector3=c.points[i]-actor.global_position-Vector3.UP*actor.solver.height
			rests.append(Vector4(rest.x,rest.y,rest.z,0))
			poses.append(Vector4(pose.x,pose.y,pose.z,0))
			var a:Vector3=rest_axes[i];var b:Vector3=axes[i]
			rest_normals.append(Vector4(a.x,a.y,a.z,0));pose_normals.append(Vector4(b.x,b.y,b.z,0))
	rests.resize(MAX_CHAINS*JOINTS); poses.resize(MAX_CHAINS*JOINTS)
	rest_normals.resize(MAX_CHAINS*JOINTS);pose_normals.resize(MAX_CHAINS*JOINTS)

func uniforms() -> Dictionary:
	return {"chain_count":chains.size(),"chain_rest":rests,"chain_pose":poses,"chain_rest_normal":rest_normals,"chain_pose_normal":pose_normals}


func pull_displacement(delta:float,direction:Vector3,speed:float,mode:String)->Vector3:
	var result:=Vector3.ZERO;var count:=0
	var heading:=direction.normalized()*(1 if speed>=0 else -1)
	for c:Dictionary in chains:
		if not _active(c,mode) or c.state!="stance":continue
		var t:=clampf((float(c.timer)+delta)/float(c.pull_duration),0,1)
		var progress:=t*t*(3-2*t)
		var desired:Vector3=c.plant_root+heading*float(c.pull_distance)*progress
		var correction:Vector3=desired-_root(c);correction.y=0
		result+=correction;count+=1
	if count==0:return Vector3.ZERO
	var forward:=maxf(.0,(result/float(count)).dot(heading))
	return heading*minf(forward,absf(speed)*delta*1.5)

func _limit_bends(c:Dictionary,points:PackedVector3Array)->void:
	# Broad cartilage/stalk curves cannot turn tighter than their own thickness.
	var limit:=.45 if c.kind=="vine" else .4
	for j in range(1,JOINTS-1):
		var incoming:Vector3=(points[j]-points[j-1]).normalized()
		var outgoing:Vector3=(points[j+1]-points[j]).normalized()
		var angle:=incoming.angle_to(outgoing)
		if angle>limit:outgoing=incoming.slerp(outgoing,limit/angle).normalized()
		points[j+1]=points[j]+outgoing*float(c.lengths[j])

func _avoid_obstacles(c:Dictionary)->void:
	var points:PackedVector3Array=c.points
	for j in range(3,JOINTS):
		for volume:Dictionary in actor.anatomy.rig.get("obstacle_volumes",[]):
			var rest_root:Vector3=c.rest[0]
			if (j<4 or c.kind=="leg") and ((volume.basis.transposed()*(rest_root-volume.center))/volume.radii).length()<1.35:continue
			var center:Vector3=actor.global_position+Vector3.UP*actor.solver.height+actor.solver.map_point(volume.center)
			var basis:Basis=actor.solver.pose_frame*volume.basis
			var radii:Vector3=volume.radii*.92+Vector3.ONE*float(c.radius)*.65
			var q:Vector3=(basis.transposed()*(points[j]-center))/radii
			if q.length_squared()<1 and q.length_squared()>.0001:
				var outside:Vector3=center+basis*(q.normalized()*radii)
				points[j]+=(outside-points[j]).limit_length(float(c.length)*.12);collision_corrections+=1
		for other:Dictionary in chains:
			if other.feature_id==c.feature_id:continue
			for k in range(2,JOINTS):
				var delta:Vector3=points[j]-other.points[k]
				var radius:float=(float(c.radius)+float(other.radius))*.7
				if delta.length_squared()<radius*radius and delta.length_squared()>.000001:
					points[j]+=delta.normalized()*(radius-delta.length())*.6;collision_corrections+=1
	c.points=points
