extends CharacterBody3D
## One deformable material frame, three batched render groups, and a coarse
## anatomical skeleton/collision rig. No rotating Node3D drives rolling anymore.
const Tissue = preload("res://shaders/blob_organism.gdshader")
const Membrane = preload("res://shaders/blob_membrane.gdshader")
const Circulation = preload("res://scripts/blobs/blob_surface_circulation.gd")
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
const Contacts=preload("res://scripts/blobs/blob_appendage_contacts.gd")
var contacts:=Contacts.new()
var playback_rate:=1.0
var debug_features:=false
var debug_strain:=false
var rest_pose_enabled:=false
var initial_transform:=Transform3D.IDENTITY
var rest_height:=1.0
var seek_token:=0
var gait_fallback_reason:=""
var _stall_time:=.0
var _last_cycles:=0
var debug_contacts:=false
var _debug_mesh:=MeshInstance3D.new()
var gait_enabled:=true
var _stroke_time:=.0
var _body_grips:Dictionary={}
var _body_vertex_ids:=PackedInt32Array()
var body_contact_slip:=.0
var _rear_lag:=.0
var _rear_lag_velocity:=.0
var anatomy: Dictionary
var locomotion := "roll"
var speed := 0.0
var direction := Vector3.FORWARD
var ground_height := 0.0
var body := Node3D.new()
var attachments: Array[Dictionary] = []
var materials: Array[ShaderMaterial] = []
var render_instances: Array[MeshInstance3D] = []
var solver := Circulation.new()
var skeleton := Skeleton3D.new()
var terrain: Node
var travel_enabled := false
var simulation_enabled := true
var debug_circulation := false
var phase := .0
var roll_angle := .0
var _height_tick := .0
var _collision_nodes: Array[CollisionShape3D] = []
var lod_count := 0
var last_simulation_usec := 0

func configure(data: Dictionary) -> void:
	anatomy=data
	initial_transform=global_transform
	var lowest:=.0
	for p:Vector3 in data.body.vertices:lowest=minf(lowest,p.y)
	for item:Dictionary in data.appendages:
		for p:Vector3 in item.mesh.vertices:lowest=minf(lowest,p.y)
	rest_height=-lowest+.01
	if not anatomy.rig.has("obstacle_volumes"):
		anatomy.rig["obstacle_volumes"]=[]
		for f:Dictionary in anatomy.features:
			if f.has("points") or f.subtract or f.radii[f.radii.max_axis_index()]<float(data.dna.size)*.18:continue
			anatomy.rig.obstacle_volumes.append({"center":f.center,"radii":f.radii,"basis":f.get("inverse_basis",Basis.IDENTITY).transposed(),"feature_id":f.id})
	locomotion=data.dna.locomotion
	var radii:Vector3=data.dna.core_radii
	for cell in 3:
		for edge in [-1.0,1.0]:
			var target:=Vector3(0,-radii.y*.85,(float(cell)-1.0)*radii.z*.45+edge*radii.z*.24)
			var best:=INF; var selected:=0
			for i in data.body.vertices.size():
				var p:Vector3=data.body.vertices[i]
				var score:=p.distance_squared_to(target)
				if score<best: best=score; selected=i
			_body_vertex_ids.append(selected)
	solver.configure(data.dna,data.rig,data.body)
	add_child(body)
	body.name="DeformableShell"
	var coupled := _empty_group()
	var membranes := _empty_group()
	for item: Dictionary in data.appendages:
		_merge(membranes if item.feature.tissue=="membrane" else coupled,item.mesh)
		attachments.append({"feature":item.feature})
	var groups: Array = [data.body,coupled,membranes]
	for index in groups.size():
		var group: Dictionary=groups[index]
		if group.vertices.is_empty(): continue
		var mat:=_material(index==2)
		var instance:=_instance(group,mat)
		body.add_child(instance)
		render_instances.append(instance)
	skeleton.name="AnatomicalCage"
	body.add_child(skeleton)
	for i in data.rig.bone_positions.size():
		skeleton.add_bone("mass_%d" % i)
		if i>0: skeleton.set_bone_parent(i,0)
		var parent_rest: Vector3=data.rig.bone_positions[0] if i>0 else Vector3.ZERO
		skeleton.set_bone_rest(i,Transform3D(Basis.IDENTITY,data.rig.bone_positions[i]-parent_rest))
	skeleton.reset_bone_poses()
	# Fewer physics proxies than biological features. Render topology does not
	# participate in the physics solver; all detail follows the material cage.
	for proxy: Dictionary in data.rig.collision_proxies.slice(0,5):
		var collision:=CollisionShape3D.new()
		var shape:=SphereShape3D.new()
		shape.radius=maxf(.12,minf(proxy.radii.x,minf(proxy.radii.y,proxy.radii.z))*.9)
		collision.shape=shape
		collision.position=solver.map_point(proxy.center)+Vector3.UP*solver.height
		add_child(collision)
		_collision_nodes.append(collision)
	set_meta("blob_dna",data.dna)
	set_meta("blob_rig",data.rig)
	add_child(_debug_mesh)
	if not data.dna.has("roll_compatibility"):
		data.dna["roll_compatibility"]=.28 if data.features.any(func(f:Dictionary): return f.feature_type=="embedded_face") else (.5 if data.rig.chains.any(func(c:Dictionary): return c.kind=="leg") else 1.0)
	contacts.configure(self,data.rig.chains)
	set_locomotion(locomotion)
	_update_uniforms()

func _material(is_membrane: bool) -> ShaderMaterial:
	var mat:=ShaderMaterial.new()
	mat.shader=Membrane if is_membrane else Tissue
	mat.set_shader_parameter("tissue_enabled",anatomy.stages[-1].pass==7)
	var c: Dictionary=anatomy.dna.controls
	if is_membrane: mat.set_shader_parameter("translucency",c.translucency)
	else:
		mat.set_shader_parameter("roughness_scale",c.roughness)
		mat.set_shader_parameter("vein_visibility",c.veins)
		mat.set_shader_parameter("microdetail",c.microdetail)
	mat.set_shader_parameter("follow_through",c.follow_through)
	mat.set_shader_parameter("wobble",c.wobble)
	materials.append(mat)
	return mat

func _instance(data: Dictionary, mat: Material) -> MeshInstance3D:
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices
	arrays[Mesh.ARRAY_NORMAL]=data.normals
	arrays[Mesh.ARRAY_INDEX]=data.indices
	arrays[Mesh.ARRAY_COLOR]=data.colors
	arrays[Mesh.ARRAY_TEX_UV]=data.uvs
	arrays[Mesh.ARRAY_TEX_UV2]=data.uvs2
	arrays[Mesh.ARRAY_CUSTOM0]=data.anchors
	arrays[Mesh.ARRAY_CUSTOM1]=data.binds
	arrays[Mesh.ARRAY_CUSTOM2]=data.chain_binds
	var flags: int=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	var importer:=ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},mat,"anatomical_surface",flags)
	# Simplified LODs are withheld until their custom deformation attributes can be certified.
	lod_count+=importer.get_surface_lod_count(0)
	var instance:=MeshInstance3D.new()
	instance.mesh=importer.get_mesh()
	instance.material_override=mat
	instance.extra_cull_margin=maxf(anatomy.dna.core_radii.y,anatomy.dna.core_radii.z)*1.5
	instance.lod_bias=.8
	return instance

static func _empty_group() -> Dictionary:
	return {"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"indices":PackedInt32Array(),"colors":PackedColorArray(),"uvs":PackedVector2Array(),"uvs2":PackedVector2Array(),"anchors":PackedFloat32Array(),"mechanics":PackedFloat32Array(),"binds":PackedFloat32Array(),"chain_binds":PackedFloat32Array()}

static func _merge(group: Dictionary, mesh: Dictionary) -> void:
	var offset: int=group.vertices.size()
	for key in ["vertices","normals","colors","uvs","uvs2","anchors","mechanics","binds","chain_binds"]: group[key].append_array(mesh[key])
	for index: int in mesh.indices: group.indices.append(index+offset)

func _physics_process(delta: float) -> void:
	if simulation_enabled and not rest_pose_enabled: simulate(delta)

func simulate(delta: float) -> void:
	if anatomy.is_empty(): return
	var started:=Time.get_ticks_usec()
	var dt:=clampf(delta*playback_rate,0.0,.04)
	if dt<=0: return
	if direction.length_squared()>.01:
		var desired:=atan2(-direction.x,-direction.z)
		solver.heading+=clampf(angle_difference(solver.heading,desired),-dt*.65,dt*.65)
	var steering:=Vector3.FORWARD.rotated(Vector3.UP,solver.heading)
	_sample_ground()
	var traction:=contacts.traction(locomotion) if gait_enabled else .0
	var drive:=1.0
	if locomotion in ["limb","vine","drag","multicontact"]: drive=traction
	elif locomotion=="hybrid": drive=.55+.45*traction
	# Regional contraction has a rest/anchor/extend/recover stroke, with
	# offset chambers for a travelling peristaltic wave.
	var body_previous:=_body_contact_points()
	_stroke_time+=dt*absf(speed)
	solver.strain=Vector3.ZERO
	if locomotion in ["contractile","peristaltic","undulate","pulse"]:
		var stroke:=fposmod(_stroke_time,1.4)/1.4
		for chamber in 3:
			var t:=fposmod(stroke-float(chamber)*(.22 if locomotion in ["peristaltic","undulate"] else .0),1.0)
			var envelope:=smoothstep(.0,.3,t)*(1.0-smoothstep(.55,.95,t))
			solver.strain[chamber]=envelope*(.13 if locomotion=="pulse" else .22)
		drive=.25+.75*smoothstep(.0,.35,stroke)*(1.0-smoothstep(.6,.95,stroke))
	var drag_target:=.12*minf(absf(speed),1.0)*traction if locomotion=="drag" else .0
	_rear_lag_velocity+=((drag_target-_rear_lag)*12.0-_rear_lag_velocity*6.0)*dt
	_rear_lag+=_rear_lag_velocity*dt
	solver.strain.z+=_rear_lag
	if locomotion=="drag": drive*=.45
	solver.step(dt,speed*drive,locomotion)
	var muscle_delta:=_body_contact_drive(body_previous) if locomotion in ["contractile","peristaltic","undulate","pulse"] else Vector3.ZERO
	if locomotion not in ["contractile","peristaltic","undulate","pulse"]: _body_grips.clear()
	var distance:=solver.current_speed*dt
	if travel_enabled:
		var before:=global_position
		var displacement:=steering*distance
		if locomotion in ["vine","limb","drag","multicontact"]:
			displacement=contacts.pull_displacement(dt,steering,solver.current_speed,locomotion)
		if locomotion in ["contractile","peristaltic","undulate","pulse"]: displacement=muscle_delta
		if is_inside_tree(): move_and_collide(displacement)
		else: position+=displacement
		distance=(global_position-before).dot(steering)
		if is_instance_valid(terrain): ground_height=terrain.get_height_at(global_position)
		global_position.y=lerpf(global_position.y,ground_height,1.0-exp(-dt*14.0))
	solver.advance_distance(distance)
	solver._solve_support(.0,false)
	phase=solver.phase
	roll_angle=solver.circulation
	contacts.gait_enabled=gait_enabled
	contacts.secondary_enabled=solver.secondary_enabled
	contacts.step(dt,locomotion,steering,solver.current_speed)
	var cycles:=0
	for c:Dictionary in contacts.chains:cycles+=c.cycles
	if cycles>_last_cycles:_stall_time=0
	elif travel_enabled and gait_enabled and absf(speed)>.2 and locomotion in ["vine","limb","drag","multicontact"]:_stall_time+=dt
	if not gait_enabled:_stall_time=0
	_last_cycles=cycles
	if _stall_time>1.8:
		var previous_mode:=locomotion
		set_locomotion("contractile")
		gait_fallback_reason="%s could not establish a safe grip; using contraction"%previous_mode.capitalize()
	_update_uniforms()
	for i in skeleton.get_bone_count():
		var rest: Vector3=anatomy.rig.bone_positions[i]
		var parent_position:=Vector3.ZERO
		if i>0:
			var parent_rest: Vector3=anatomy.rig.bone_positions[0]
			parent_position=solver.map_point(parent_rest)
		skeleton.set_bone_pose_position(i,solver.map_point(rest)-parent_position)
	for i in _collision_nodes.size():
		var proxy: Dictionary=anatomy.rig.collision_proxies[i]
		_collision_nodes[i].position=solver.map_point(proxy.center)+Vector3.UP*solver.height
	_draw_debug()
	last_simulation_usec=Time.get_ticks_usec()-started

func _sample_ground() -> void:
	if not is_instance_valid(terrain): return
	var extent:=maxf(solver.footprint.x,solver.footprint.y)
	solver.footprint=Vector2.ONE*extent
	for z in 3:
		for x in 3:
			var sample:=global_position+Vector3(float(x-1)*extent,0,float(z-1)*extent)
			solver.ground[z*3+x]=terrain.get_height_at(sample)-global_position.y

func _update_uniforms() -> void:
	body.position.y=rest_height if rest_pose_enabled else solver.height
	var uniforms: Dictionary=solver.uniforms()
	uniforms.merge(contacts.uniforms(),true)
	for mat in materials:
		for key in uniforms: mat.set_shader_parameter(key,uniforms[key])
		mat.set_shader_parameter("debug_circulation",debug_circulation)
		mat.set_shader_parameter("debug_features",debug_features)
		mat.set_shader_parameter("debug_strain",debug_strain)
		mat.set_shader_parameter("rest_pose",rest_pose_enabled)

func attachment_position(feature_id:int)->Vector3:
	var f:Dictionary=anatomy.features[feature_id]
	var id:int=feature_id
	while id>=0:
		if anatomy.rig.chain_ids.has(id):
			var c:Dictionary=contacts.chains[anatomy.rig.chain_ids[id]]
			if id==feature_id:return c.points[0]
			if f.feature_type in ["sensory_bulb","gripping_digit"]:return c.points[-1]
			return Frames.point(c.points,float(f.get("parent_along",.5)))
		id=anatomy.features[id].parent
	return global_position+Vector3.UP*solver.height+solver.map_point(f.center)

func set_locomotion(mode: String) -> void:
	if mode=="creep": mode="limb"
	if mode not in Circulation.MODES: return
	gait_fallback_reason="";_stall_time=0
	var requested:=mode
	var legs:bool=contacts.chains.any(func(c:Dictionary): return c.kind=="leg" and contacts._root(c).y-contacts._terrain_target(contacts._root(c)).y<float(c.length)*.94)
	var vines:bool=contacts.chains.any(func(c:Dictionary): return c.kind=="vine" and contacts._root(c).y-contacts._terrain_target(contacts._root(c)).y<float(c.length)*.82)
	if mode=="hybrid" and solver.roll_safe:mode="roll"
	if mode in ["roll","hybrid"] and not solver.roll_safe: mode="limb" if legs else ("vine" if vines else "contractile")
	if mode=="limb" and not legs: mode="vine" if vines else "contractile"
	if mode in ["vine","drag"] and not vines: mode="limb" if legs else "contractile"
	if mode=="multicontact" and not (legs or vines): mode="peristaltic"
	if mode!=requested:gait_fallback_reason="%s is incompatible with this anatomy; using %s"%[requested.capitalize(),mode]
	solver.use_leg_support=mode=="limb"
	if mode!=locomotion:
		locomotion=mode; contacts.force_release=true; _body_grips.clear()

func _draw_debug() -> void:
	_debug_mesh.visible=debug_contacts
	if not debug_contacts: return
	var mesh:=ImmediateMesh.new()
	var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.vertex_color_use_as_albedo=true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	for c:Dictionary in contacts.chains:
		mesh.surface_set_color(Color.GREEN if c.state=="stance" and c.active else Color.ORANGE)
		for i in 7:
			mesh.surface_add_vertex(c.points[i]-global_position)
			mesh.surface_add_vertex(c.points[i+1]-global_position)
		var target:Vector3=c.target-global_position
		for axis:Vector3 in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]:
			mesh.surface_add_vertex(target-axis*.07); mesh.surface_add_vertex(target+axis*.07)
	mesh.surface_set_color(Color.CYAN)
	for sample:Dictionary in solver.support_samples:
		var point:Vector3=solver.map_bound(sample.p,int(sample.group),float(sample.weight))+Vector3.UP*solver.height
		mesh.surface_add_vertex(point); mesh.surface_add_vertex(point+Vector3.UP*.05)
	mesh.surface_end(); _debug_mesh.mesh=mesh

func _body_contact_points() -> PackedVector3Array:
	var result:=PackedVector3Array()
	for i in _body_vertex_ids:
		var rest:Vector3=anatomy.body.vertices[i]
		result.append(solver.map_bound(rest,int(anatomy.body.binds[i*4])-1,float(anatomy.body.binds[i*4+1]))+Vector3.UP*solver.height)
	return result

func _body_contact_drive(previous:PackedVector3Array) -> Vector3:
	var current:=_body_contact_points()
	var correction:=Vector3.ZERO
	var contacts_count:=0
	var used:Dictionary={}
	var stroke:=fposmod(_stroke_time,1.4)/1.4
	for cell in 3:
		var t:=fposmod(stroke-float(cell)*(.22 if locomotion in ["peristaltic","undulate"] else .0),1.0)
		# High friction alternates between front and rear tissue. Holding the
		# actual world target converts changing body shape into translation.
		var index:=cell*2+(0 if t<.5 else 1)
		if speed<0: index=cell*2+(1 if t<.5 else 0)
		used[index]=true
		if not _body_grips.has(index): _body_grips[index]=global_position+previous[index]
		var residual:Vector3=_body_grips[index]-(global_position+current[index])
		residual.y=0
		correction+=residual; contacts_count+=1
	for index in _body_grips.keys():
		if not used.has(index): _body_grips.erase(index)
	correction/=maxi(contacts_count,1)
	body_contact_slip=.0
	for index in used:
		var residual:Vector3=_body_grips[index]-(global_position+current[index]+correction)
		residual.y=0; body_contact_slip=maxf(body_contact_slip,residual.length())
	return correction.limit_length(.04)

func seek(seconds:float)->void:
	seek_token+=1;var token:=seek_token
	simulation_enabled=false;rest_pose_enabled=false
	global_transform=initial_transform
	solver=Circulation.new();solver.configure(anatomy.dna,anatomy.rig,anatomy.body)
	contacts=Contacts.new();contacts.configure(self,anatomy.rig.chains)
	_stroke_time=0;_rear_lag=0;_rear_lag_velocity=0;_body_grips.clear();phase=0;roll_angle=0;_stall_time=0;_last_cycles=0
	set_locomotion(locomotion)
	for frame in ceili(clampf(seconds,0,12)*30):
		if token!=seek_token:return
		simulate(1.0/30)
		if frame%8==0:await get_tree().process_frame
	_update_uniforms()
