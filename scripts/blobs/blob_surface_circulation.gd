extends RefCounted
## A composition of injective Cartesian maps. No angular chart, nearest-region
## selection, independent rigid-island blending or global volume rescaling.
const MODES=["roll","vine","limb","contractile","peristaltic","hybrid","drag","pulse","multicontact","undulate"]
var dna:Dictionary
var rig:Dictionary
var circulation:=.0
var phase:=.0
var current_speed:=.0
var acceleration:=.0
var compression:=.0
var compression_velocity:=.0
var height:=1.0
var spread:=1.0
var motion_mix:=.0
var ground:=PackedFloat32Array([0,0,0,0,0,0,0,0,0])
var footprint:=Vector2.ONE
var heading:=.0
var pose_frame:=Basis.IDENTITY
var strain:=Vector3.ZERO
var idle_enabled:=true
var contact_enabled:=true
var secondary_enabled:=true
var circulation_enabled:=true
var support_samples:Array[Dictionary]=[]
var contact_count:=0
var volume_scale:=1.0
var group_states:Array[Dictionary]=[]
var pulse_cells:=PackedVector4Array()
var pulse_values:=PackedFloat32Array()
var _pulse_states:Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()
var _height_velocity:=.0
var idle_shear:=Vector3.ZERO
var _idle_velocity:=Vector3.ZERO
var _idle_target:=Vector3(.002,-.003,.002)
var _idle_timer:=.0
var roll_safe:=false
var use_leg_support:=false
var track_length:=1.0
func configure(value:Dictionary,binding_rig:Dictionary={},body_mesh:Dictionary={}) -> void:
	dna=value; rig=binding_rig; _rng.seed=int(dna.seed)*7919+11
	var r:Vector3=dna.core_radii
	footprint=Vector2.ONE*maxf(r.x,r.z)*2.0
	track_length=TAU*r.z
	roll_safe=bool(rig.get("roll_safe",false))
	use_leg_support=dna.locomotion=="limb"
	for group:Dictionary in rig.get("material_groups",[]):
		group_states.append({"squash":1.0})
		if group.tissue!="sac" or pulse_cells.size()>=8: continue
		var c:Vector3=group.center
		pulse_cells.append(Vector4(c.x,c.y,c.z,maxf(group.radii.length()*1.25,.15)))
		pulse_values.append(.0)
		_pulse_states.append({"value":.0,"velocity":.0,"target":_rng.randf_range(.04,.13),"timer":_rng.randf_range(0,2.0),"interval":_rng.randf_range(2.5,5.0)})
	if not body_mesh.is_empty():
		var bins:Dictionary={}
		for i in body_mesh.vertices.size():
			var p:Vector3=body_mesh.vertices[i]
			var theta:=fposmod(atan2(p.z/r.z,p.y/r.y)/TAU,1.0)
			var key:=Vector2i(clampi(int((p.x/r.x*.5+.5)*6),0,5),mini(int(theta*32),31))
			var radial:=Vector2(p.y/r.y,p.z/r.z).length_squared()
			if not bins.has(key) or radial>bins[key].radial: bins[key]={"p":p,"radial":radial,"group":-1,"weight":0.0}
		for sample:Dictionary in bins.values(): support_samples.append(sample)
	compression=_target_compression()
	_solve_support(0,true)
func _target_compression()->float:
	if not contact_enabled: return 0
	var c:Dictionary=dna.controls
	return clampf(float(c.softness)*float(c.gravity)*(.13+minf(float(dna.get("estimated_mass",5))/80.0,.13))*(1.0-float(c.stiffness)*.5),0,.18)
func step(delta:float,requested_speed:float,_mode:String)->void:
	motion_mix=1.0 if _mode=="roll" else (.4 if _mode=="hybrid" else .0)
	var dt:=clampf(delta,0,.04)
	var previous:=current_speed
	current_speed=lerpf(current_speed,requested_speed,1.0-exp(-dt*5.0))
	acceleration=(current_speed-previous)/maxf(dt,.00001)
	phase+=dt
	compression_velocity+=((_target_compression()-compression)*45-compression_velocity*13)*dt
	compression=clampf(compression+compression_velocity*dt,0,.2)
	var dx:float=(ground[5]-ground[3])/(footprint.x*2)
	var dz:float=(ground[7]-ground[1])/(footprint.y*2)
	var normal:=Vector3(-dx,1,-dz).normalized()
	pose_frame=pose_frame.slerp(Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,heading),1-exp(-dt*7))
	_idle_timer+=dt
	if _idle_timer>2.7:
		_idle_timer=0; _idle_target=Vector3(_rng.randf_range(-.006,.006),_rng.randf_range(-.006,.006),_rng.randf_range(-.004,.004))
	var target:=_idle_target if idle_enabled else Vector3.ZERO
	_idle_velocity+=((target-idle_shear)*4-_idle_velocity*4)*dt
	idle_shear+=_idle_velocity*dt
	for i in _pulse_states.size():
		var state:Dictionary=_pulse_states[i]; state.timer+=dt
		if state.timer>state.interval: state.timer=0; state.target=_rng.randf_range(-.035,.13)
		var desired:float=state.target if idle_enabled else 0.0
		state.velocity+=((desired-state.value)*7.0-state.velocity*5.0)*dt
		state.value=clampf(state.value+state.velocity*dt,-.035,.14)
		pulse_values[i]=state.value
	_solve_support(dt,false)
func advance_distance(distance:float)->void:
	if roll_safe and circulation_enabled: circulation+=distance/maxf(dna.core_radii.z,.2)*float(dna.controls.circulation)*motion_mix
func _update_groups(_dt:float)->void: pass
func _update_volume()->void: pass
func map_base(rest:Vector3,_gain:float=1.0)->Vector3:
	var p:=rest
	for i in pulse_cells.size():
		var cell:=pulse_cells[i]; var d:=p-Vector3(cell.x,cell.y,cell.z)
		p+=d*(pulse_values[i]*exp(-2*d.length_squared()/(cell.w*cell.w)))
	var r:Vector3=dna.core_radii
	var angle:float=-circulation if roll_safe else 0.0
	var co:=cos(angle); var si:=sin(angle)
	var y:=p.y/r.y; var z:=p.z/r.z
	p.y=(co*y-si*z)*r.y; p.z=(si*y+co*z)*r.z
	for i in 3:
		var w:float=r.z*.6; var center:float=(float(i)-1)*r.z*.5
		var th:=tanh((p.z-center)/w)
		var a:=clampf(strain[i],-.1,.22)
		var derivative:=1-a*(1-th*th)
		p.z-=a*w*th; p.x/=sqrt(derivative); p.y/=sqrt(derivative)
	# Each idle shear is independent of the coordinate it displaces: det=1.
	p.x+=r.x*idle_shear.x*exp(-pow(p.y/r.y,2)-pow(p.z/r.z,2))
	p.z+=r.z*idle_shear.z*exp(-pow(p.x/r.x,2)-pow(p.y/r.y,2))
	p.y+=r.y*idle_shear.y*exp(-pow(p.x/r.x,2)-pow(p.z/r.z,2))
	var width:float=r.y*.9
	var v:float=(p.y+r.y)/width
	var derivative:=1-2*compression*r.y*v/width*exp(-v*v)
	p.y+=compression*r.y*exp(-v*v)
	p.x/=sqrt(derivative); p.z/=sqrt(derivative)
	return pose_frame*p
func map_point(rest:Vector3)->Vector3: return map_base(rest)
func map_bound(rest:Vector3,_group:int,_weight:float)->Vector3: return map_base(rest)
func map_normal(rest:Vector3,normal:Vector3)->Vector3:
	var e:float=maxf(.0003,float(dna.size)*.0005)
	var p:=map_point(rest)
	var j:=Basis((map_point(rest+Vector3.RIGHT*e)-p)/e,(map_point(rest+Vector3.UP*e)-p)/e,(map_point(rest+Vector3.BACK*e)-p)/e)
	return (j.inverse().transposed()*normal).normalized()
func _solve_support(dt:float,initial:bool)->void:
	var required:=.0; contact_count=0
	for sample:Dictionary in support_samples:
		var p:=map_point(sample.p); required=maxf(required,ground_at(p.x,p.z)-p.y)
	if use_leg_support:
		for chain:Dictionary in rig.get("chains",[]):
			if chain.kind=="leg":
				var tip:=map_point(chain.rest[-1]);required=maxf(required,ground_at(tip.x,tip.z)-tip.y)
	var desired:=required+.006
	if initial: height=desired
	else:
		_height_velocity+=((desired-height)*70-_height_velocity*17)*dt
		height=maxf(height+_height_velocity*dt,required-.008)
	for sample:Dictionary in support_samples:
		var p:=map_point(sample.p)
		if absf(p.y+height-ground_at(p.x,p.z))<.06: contact_count+=1
func ground_at(x:float,z:float)->float:
	var u:=clampf(x/footprint.x+1,0,2); var v:=clampf(z/footprint.y+1,0,2)
	var ix:=mini(int(u),1); var iz:=mini(int(v),1); var i:=iz*3+ix
	return lerpf(lerpf(ground[i],ground[i+1],u-ix),lerpf(ground[i+3],ground[i+4],u-ix),v-iz)
func uniforms()->Dictionary:
	var cells:=pulse_cells.duplicate(); cells.resize(8)
	var values:=pulse_values.duplicate(); values.resize(8)
	return {"body_radii":dna.core_radii,"circulation":circulation if roll_safe else 0.0,"compression":compression,"pose_frame":pose_frame,"strain":strain,"idle_shear":idle_shear,"pulse_count":pulse_cells.size(),"pulse_cells":cells,"pulse_values":values,"body_height":height}
