extends RefCounted
## Shape-matched shell transport + monotone, determinant-compensated contact
## warp. No radial rescaling, hard vertex-plane clamp, or locomotion sine wave.
const MODES=["roll","vine","limb","contractile","peristaltic","hybrid","drag","pulse","multicontact","undulate"]
var dna: Dictionary
var rig: Dictionary
var circulation:=.0
var phase:=.0
var current_speed:=.0
var acceleration:=.0
var compression:=.0
var compression_velocity:=.0
var height:=1.0
var spread:=1.0
var motion_mix:=1.0
var ground:=PackedFloat32Array([0,0,0,0,0,0,0,0,0])
var footprint:=Vector2.ONE
var heading:=.0
var arc_lengths:=PackedFloat32Array()
var track_length:=1.0
var locomotion_kind:=0
var pose_frame:=Basis.IDENTITY
var group_origins:=PackedVector4Array()
var group_rest:=PackedVector4Array()
var group_x:=PackedVector4Array()
var group_y:=PackedVector4Array()
var group_z:=PackedVector4Array()
var group_states: Array[Dictionary]=[]
var idle_cells:=PackedVector4Array()
var idle_amounts:=Vector4.ZERO
var strain:=Vector3.ZERO
var idle_enabled:=true
var contact_enabled:=true
var secondary_enabled:=true
var circulation_enabled:=true
var idle_time:=.0
var support_samples: Array[Dictionary]=[]
var contact_count:=0
var volume_scale:=1.0
var _height_velocity:=.0
var _idle_rng:=RandomNumberGenerator.new()
var _idle_states: Array[Dictionary]=[]

func configure(value: Dictionary, binding_rig: Dictionary={}, body_mesh: Dictionary={}) -> void:
	dna=value
	rig=binding_rig
	_idle_rng.seed=int(dna.seed)*7919+3
	var r: Vector3=dna.core_radii
	footprint=Vector2.ONE*maxf(r.x,r.z)*1.8
	height=r.y*.94
	for i in 4:
		var center:=Vector3((float(i%2)-.5)*r.x,.1*r.y,(float(i/2)-.5)*r.z)
		idle_cells.append(Vector4(center.x,center.y,center.z,r.length()*.55))
		_idle_states.append({"value":.0,"velocity":.0,"target":.0,"time":float(i)*1.7,"interval":_idle_rng.randf_range(3.5,7.5)})
	for g: Dictionary in rig.get("material_groups",[]):
		group_states.append({"squash":1.0,"velocity":.0,"pulse":.0,"pulse_velocity":.0,"pulse_target":.0,"timer":_idle_rng.randf_range(.0,5.0),"interval":_idle_rng.randf_range(5.0,11.0)})
	if not body_mesh.is_empty():
		var bins: Dictionary={}
		for i in body_mesh.vertices.size():
			var p: Vector3=body_mesh.vertices[i]
			var theta:=fposmod(atan2(p.z/maxf(r.z,.01),p.y/maxf(r.y,.01))/TAU,1.0)
			var key:=Vector2i(clampi(int((p.x/r.x*.5+.5)*3.0),0,2),mini(int(theta*16.0),15))
			var radial:=Vector2(p.y/r.y,p.z/r.z).length_squared()
			if not bins.has(key) or radial>float(bins[key].radial): bins[key]={"p":p,"group":int(body_mesh.binds[i*4])-1,"weight":body_mesh.binds[i*4+1],"radial":radial}
		for sample: Dictionary in bins.values(): support_samples.append(sample)
	else:
		for i in 24:
			var a:=TAU*float(i)/24.0
			support_samples.append({"p":Vector3(0,cos(a)*r.y,sin(a)*r.z),"group":-1,"weight":.0})
	compression=_target_compression()
	_rebuild_track()
	_update_groups(.0)
	_update_volume()
	_solve_support(.0,true)

func _target_compression() -> float:
	if not contact_enabled: return .0
	var c: Dictionary=dna.controls
	return clampf(float(c.softness)*float(c.gravity)*(.09+clampf(float(dna.get("estimated_mass",3.0))/35.0,.0,.12))*(1.0-float(c.stiffness)*.5),.0,.18)

func step(delta: float, requested_speed: float, mode: String) -> void:
	var dt:=clampf(delta,.0,.0333334)
	var previous:=current_speed
	current_speed=lerpf(current_speed,requested_speed,1.0-exp(-dt*(3.0+float(dna.controls.recovery)*4.0)))
	acceleration=clampf((current_speed-previous)/maxf(dt,.00001),-3.0,3.0)
	phase+=dt
	idle_time+=dt
	locomotion_kind=MODES.find(mode)
	var desired_mix:=1.0 if mode=="roll" else (.55 if mode=="hybrid" else .0)
	desired_mix*=float(dna.get("roll_compatibility",1.0))
	motion_mix=move_toward(motion_mix,desired_mix,dt*1.6)
	var target:=_target_compression()+minf(absf(acceleration)*.004,.012)
	compression_velocity+=((target-compression)*42.0-compression_velocity*12.0)*dt
	compression=clampf(compression+compression_velocity*dt,.0,.2)
	spread=1.0/sqrt(maxf(1.0-compression,.7))
	var dx: float=(ground[5]-ground[3])/(footprint.x*2.0)
	var dz: float=(ground[7]-ground[1])/(footprint.y*2.0)
	var normal:=Vector3(-dx,1,-dz).normalized()
	var tilted:=Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,heading)
	pose_frame=pose_frame.slerp(tilted,1.0-exp(-dt*7.0))
	_update_idle(dt)
	_update_groups(dt)
	_update_volume()
	_solve_support(dt,false)

func advance_distance(distance: float) -> void:
	if circulation_enabled:
		circulation+=distance*TAU/maxf(track_length,.1)*motion_mix*float(dna.controls.circulation)
	_update_groups(.0)
	_update_volume()

func _update_volume() -> void:
	var curve: PackedFloat32Array=dna.get("volume_curve",PackedFloat32Array())
	if curve.is_empty(): volume_scale=1.0; return
	var coordinate:=fposmod(circulation/TAU,1.0)*float(curve.size())
	var index:=int(coordinate)
	volume_scale=lerpf(curve[index],curve[(index+1)%curve.size()],coordinate-float(index))
	var strain_curve:PackedFloat32Array=dna.get("strain_volume_curve",PackedFloat32Array())
	if strain_curve.size()==8:
		var t:=strain/ .22
		t=t.clamp(Vector3.ZERO,Vector3.ONE)
		var correction:=.0
		for corner in 8:
			var weight:float=(t.x if corner&1 else 1-t.x)*(t.y if corner&2 else 1-t.y)*(t.z if corner&4 else 1-t.z)
			correction+=strain_curve[corner]*weight
		volume_scale*=correction

func _update_idle(dt: float) -> void:
	for i in _idle_states.size():
		var state: Dictionary=_idle_states[i]
		state.time+=dt
		if state.time>state.interval:
			state.time=.0
			state.target=_idle_rng.randf_range(-.008,.008) if idle_enabled else .0
		var desired: float=state.target if idle_enabled else .0
		state.velocity+=((desired-state.value)*3.0-state.velocity*3.6)*dt
		state.value+=state.velocity*dt
		idle_amounts[i]=state.value

func _update_groups(dt: float) -> void:
	group_origins.clear(); group_rest.clear(); group_x.clear(); group_y.clear(); group_z.clear()
	var groups: Array=rig.get("material_groups",[])
	for i in groups.size():
		var g: Dictionary=groups[i]
		var state: Dictionary=group_states[i]
		var center: Vector3=g.center
		var old_angle:=atan2(center.z/maxf(dna.core_radii.z,.01),center.y/maxf(dna.core_radii.y,.01))
		var angle:=material_angle(old_angle,circulation*float(g.circulation_gain))
		var turn:=normal_angle(angle)-normal_angle(old_angle)
		var rotation:=pose_frame*Basis(Vector3.RIGHT,turn)
		var origin:=map_base(center,float(g.circulation_gain))
		var extent: float=absf(rotation.x.y)*g.radii.x+absf(rotation.y.y)*g.radii.y+absf(rotation.z.y)*g.radii.z
		var pressure:=maxf(.0,ground_at(origin.x,origin.z)-(origin.y+height-extent))/maxf(extent,.1)
		var minimum: float=g.minimum_scale
		var target:=clampf(1.0-pressure*(1.0-float(g.stiffness))*.7,minimum,1.0)
		if dt>0:
			state.velocity+=((target-state.squash)*65.0-state.velocity*16.0)*dt
			state.squash=clampf(state.squash+state.velocity*dt,minimum,1.0)
			state.timer+=dt
			if state.timer>state.interval:
				state.timer=.0
				state.pulse_target=_idle_rng.randf_range(-.009,.016) if g.tissue=="sac" and idle_enabled else .0
			state.pulse_velocity+=((float(state.pulse_target)-float(state.pulse))*4.0-float(state.pulse_velocity)*4.0)*dt
			state.pulse+=state.pulse_velocity*dt
		var pulse: float=1.0+(state.pulse if idle_enabled else .0)
		group_rest.append(Vector4(center.x,center.y,center.z,pulse))
		group_origins.append(Vector4(origin.x,origin.y,origin.z,state.squash))
		group_x.append(Vector4(rotation.x.x,rotation.x.y,rotation.x.z,0))
		group_y.append(Vector4(rotation.y.x,rotation.y.y,rotation.y.z,0))
		group_z.append(Vector4(rotation.z.x,rotation.z.y,rotation.z.z,0))

func _solve_support(dt: float, initial: bool) -> void:
	var required:=.0
	contact_count=0
	for sample: Dictionary in support_samples:
		var p:=map_bound(sample.p,int(sample.group),float(sample.weight))
		required=maxf(required,ground_at(p.x,p.z)-p.y)
	var desired:=required+.012
	if initial: height=desired
	else:
		_height_velocity+=((desired-height)*65.0-_height_velocity*16.0)*dt
		height=maxf(height+_height_velocity*dt,required-.015)
	for sample: Dictionary in support_samples:
		var p:=map_bound(sample.p,int(sample.group),float(sample.weight))
		if absf(p.y+height-ground_at(p.x,p.z))<.08: contact_count+=1

func _track(theta: float) -> Vector3:
	return Vector3(0,cos(theta)*float(dna.core_radii.y),sin(theta)*float(dna.core_radii.z))
func normal_angle(theta: float) -> float:
	return atan2(sin(theta)/maxf(dna.core_radii.z,.01),cos(theta)/maxf(dna.core_radii.y,.01))
func _rebuild_track() -> void:
	arc_lengths.resize(33); arc_lengths[0]=.0
	var previous:=_track(.0)
	for i in range(1,33):
		var p:=_track(TAU*float(i)/32.0)
		arc_lengths[i]=arc_lengths[i-1]+p.distance_to(previous)
		previous=p
	track_length=arc_lengths[32]
	for i in 33: arc_lengths[i]/=maxf(track_length,.01)
func material_angle(theta: float, distance_phase: float=INF) -> float:
	var shift:=circulation if is_inf(distance_phase) else distance_phase
	var u:=fposmod(theta/TAU,1.0)*32.0
	var index:=mini(int(u),31)
	var coordinate:=fposmod(lerpf(arc_lengths[index],arc_lengths[index+1],u-float(index))-shift/TAU,1.0)
	var low:=0
	var high:=32
	for iteration in 5:
		var mid: int=(low+high)/2
		if arc_lengths[mid]<=coordinate: low=mid
		else: high=mid
	return (float(low)+(coordinate-arc_lengths[low])/maxf(arc_lengths[low+1]-arc_lengths[low],.000001))*TAU/32.0

func map_base(rest: Vector3, gain: float=1.0) -> Vector3:
	var r: Vector3=dna.core_radii
	var theta:=atan2(rest.z/maxf(r.z,.01),rest.y/maxf(r.y,.01))
	var angle:=material_angle(theta,circulation*gain)
	var turn:=normal_angle(angle)-normal_angle(theta)
	var base:=_track(angle)+Basis(Vector3.RIGHT,turn)*(rest-_track(theta))
	base.x=rest.x
	# Monotone gravity field. Its derivative stays positive, and the reciprocal
	# lateral stretch compensates displaced volume rather than flattening it.
	var width:=maxf(r.y*.62,.1)
	var v: float=(base.y+r.y)/width
	var lift:=compression*r.y*exp(-v*v)
	var derivative:=clampf(1.0-2.0*compression*r.y*v/width*exp(-v*v),.64,1.25)
	base.y+=lift
	var lateral:=1.0/sqrt(derivative)
	base.x*=lateral; base.z*=lateral
	# Three contractile chambers redistribute axial strain into radial volume.
	for i in 3:
		var center:=Vector3(0,0,(float(i)-1.0)*r.z*.6)
		var d:=base-center
		var weight:=exp(-pow(d.z/maxf(r.z*.65,.1),2.0)*2.0)
		var axial:=1.0-strain[i]*weight
		base=center+Vector3(d.x/sqrt(axial),d.y/sqrt(axial),d.z*axial)
	for i in 4:
		var cell:=idle_cells[i]
		var center:=Vector3(cell.x,cell.y,cell.z)
		var d:=base-center
		var weight:=exp(-d.length_squared()/maxf(cell.w*cell.w,.01)*2.0)
		var amount:=idle_amounts[i]*weight
		base+=Vector3(d.x*.5,-d.y,d.z*.5)*amount
	return pose_frame*base

func map_point(rest: Vector3) -> Vector3: return map_base(rest)*volume_scale
func map_bound(rest: Vector3, group: int, weight: float) -> Vector3:
	var base:=map_base(rest)
	if group<0 or group>=group_origins.size() or weight<=0: return base*volume_scale
	var center:=group_rest[group]
	var origin:=group_origins[group]
	var rotation:=Basis(Vector3(group_x[group].x,group_x[group].y,group_x[group].z),Vector3(group_y[group].x,group_y[group].y,group_y[group].z),Vector3(group_z[group].x,group_z[group].y,group_z[group].z))
	var d:=rotation*(rest-Vector3(center.x,center.y,center.z))
	d.x/=sqrt(origin.w); d.z/=sqrt(origin.w); d.y*=origin.w
	return base.lerp(Vector3(origin.x,origin.y,origin.z)+d*center.w,weight)*volume_scale
func ground_at(x: float,z: float) -> float:
	var u:=clampf(x/maxf(footprint.x,.1)+1,.0,2.0)
	var v:=clampf(z/maxf(footprint.y,.1)+1,.0,2.0)
	var ix:=mini(int(u),1)
	var iz:=mini(int(v),1)
	var i:=iz*3+ix
	return lerpf(lerpf(ground[i],ground[i+1],u-ix),lerpf(ground[i+3],ground[i+4],u-ix),v-iz)
func uniforms() -> Dictionary:
	return {"volume_scale":volume_scale,"body_radii":dna.core_radii,"arc_lengths":arc_lengths,"circulation":circulation,"compression":compression,"body_height":height,"pose_frame":pose_frame,"idle_cells":idle_cells,"idle_amounts":idle_amounts,"strain":strain,"phase":phase,"motion":current_speed,"motion_mix":motion_mix,"group_count":group_origins.size(),"group_rest":_padded(group_rest,32),"group_origin":_padded(group_origins,32),"group_x":_padded(group_x,32),"group_y":_padded(group_y,32),"group_z":_padded(group_z,32)}
func _padded(values: PackedVector4Array, count: int) -> PackedVector4Array:
	var result:=values.duplicate(); result.resize(count); return result
