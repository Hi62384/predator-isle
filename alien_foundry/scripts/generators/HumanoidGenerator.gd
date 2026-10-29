extends RefCounted
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Distribution = preload("res://alien_foundry/scripts/anatomy/TissueDistribution.gd")
const Growth = preload("res://alien_foundry/scripts/anatomy/TissueGrowth.gd")

func generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var g := Graph.new(); g.initialize("Humanoid",seed_value,options)
	var p := Distribution.humanoid(g)
	var irr := float(g.settings["irregularity"])
	var density := float(g.settings["growth_density"])
	var uncanny := float(g.settings["uncanny_features"])
	var bulk := float(p["bulk"])
	var leg_length := float(p["leg_length"])
	var torso_length := float(p["torso_length"])
	var width := float(p["chest_width"])
	var depth := float(p["chest_depth"])
	var lean := float(p["lateral_bend"])
	var hunch := float(p["hunch"])
	var pelvis_pos := Vector3(0,leg_length,0.08)
	var chest_pos := pelvis_pos+Vector3(lean,torso_length*0.76,-hunch)
	var lumbar := pelvis_pos.lerp(chest_pos,0.42)+Vector3(-lean*0.32,0,0.06)
	# Articulated carriers and surrounding tissue share one anatomy graph. All
	# major outer masses participate in the same continuous implicit surface.
	var pelvis := g.mass("","pelvis",pelvis_pos,Vector3(float(p["pelvis_width"]),0.27+bulk*0.045,depth*0.89),"flesh")
	_tissue(g,pelvis,0.12,0.045)
	g.node(pelvis)["shape"]={"sculpt_strength":0.58}
	var spine := g.curve(pelvis,"body_chain",[pelvis_pos,lumbar,chest_pos],[depth*0.69,depth*0.64,depth*0.79],"flesh")
	_tissue(g,spine,0.10,0.035)
	var abdomen_pos := pelvis_pos.lerp(chest_pos,0.43)+Vector3(g.randf_range(-0.06,0.06)*irr,0,-0.025)
	var abdomen := g.mass(spine,"abdomen",abdomen_pos,Vector3(float(p["abdomen_width"]),torso_length*0.43,float(p["abdomen_depth"])),"flesh",false)
	_tissue(g,abdomen,0.11,0.045)
	var chest := g.mass(spine,"torso",chest_pos,Vector3(width,torso_length*0.51,depth),"flesh")
	_tissue(g,chest,0.11,0.04)
	g.node(chest)["rotation"]=Graph.arr(Vector3(-hunch*0.22,0,-lean*0.22))
	var shoulders: Dictionary={}; var positions: Dictionary={}; var limb_metrics: Array=[]
	for side in [-1.0,1.0]:
		var asym := 1.0+g.randf_range(-1.0,1.0)*float(p["asymmetry"])
		var shoulder_pos := chest_pos+Vector3(side*width*0.89,torso_length*0.27+g.randf_range(-0.14,0.14)*float(p["asymmetry"]),depth*0.04)
		var shoulder_radius := (0.13+bulk*0.095)*asym
		var shoulder := g.mass(chest,"shoulder",shoulder_pos,Vector3(shoulder_radius,shoulder_radius*1.12,shoulder_radius*0.96),"flesh",false)
		_tissue(g,shoulder,shoulder_radius*0.48,0.045)
		shoulders[side]=shoulder; positions[side]=shoulder_pos
		# Broad pectoral/latissimus transitions are partly buried flesh volumes,
		# never freestanding leaves placed around a narrow bone tube.
		var pectoral := g.mass(chest,"muscle_fan",chest_pos+Vector3(side*width*0.36,torso_length*0.17,-depth*0.48),Vector3(width*0.56,torso_length*0.24,depth*0.63),"flesh",false)
		_tissue(g,pectoral,0.075,0.035)
		g.node(pectoral)["rotation"]=Graph.arr(Vector3(0,side*0.10,-side*g.randf_range(0.10,0.23)))
		# Rib supports lie inside the thoracic envelope; no exposed hoop ladder.
		for rib in range(2+int(float(g.settings["surface_detail"])*2.0)):
			var height := torso_length*(0.15-float(rib)*0.14)
			var section := sqrt(maxf(0.45,1.0-pow(height/(torso_length*0.51),2)))
			var r := width*section*0.55
			var id := g.curve(chest,"rib",[chest_pos+Vector3(side*0.04,height,-depth*0.41),chest_pos+Vector3(side*r*0.65,height-0.03,-depth*0.44),chest_pos+Vector3(side*r,height+0.025,0),chest_pos+Vector3(side*r*0.5,height+0.08,depth*0.42)],[0.026,0.032,0.030,0.025],"flesh",false)
			_tissue(g,id,0.025,0.005)
		var hip := pelvis_pos+Vector3(side*float(p["pelvis_width"])*0.63,-0.08,0)
		var knee := hip+Vector3(side*g.randf_range(0.04,0.18),-leg_length*g.randf_range(0.45,0.53),-g.randf_range(0.12,0.30)-hunch*0.13)
		var ankle := Vector3(side*float(p["stance"])*g.randf_range(0.80,1.12),0.18,0.08+g.randf_range(-0.10,0.16))
		var thigh := float(p["thigh_radius"])*asym
		var calf := float(p["calf_radius"])*asym
		var leg := _limb_envelope(g,pelvis,hip,knee,ankle,thigh,calf,side,true)
		var foot_scale := clampf(0.87+bulk*0.13,0.88,1.22)
		var foot := g.mass(leg,"foot",ankle+Vector3(0,-0.07,-0.10*foot_scale),Vector3(0.12,0.105,0.22)*foot_scale,"flesh")
		_tissue(g,foot,0.055,0.018)
		g.module("foot_plantigrade",foot,g.center(foot)+Vector3(0,0.074,-0.045)*foot_scale,Vector3.UP,Vector3(0.30,0.30,0.18)*foot_scale,{},"flesh",Vector3.FORWARD)
		_digits(g,foot,g.center(foot)+Vector3(0,0,-0.15)*foot_scale,Vector3.FORWARD,g.rng.randi_range(2,4),0.21*foot_scale,0.19*foot_scale,0.0,foot_scale,g.randf_range(0.65,1.0))
		var arm_length := float(p["arm_length"])*g.randf_range(0.93,1.07)*asym
		var elbow := shoulder_pos+Vector3(side*(0.27+bulk*0.09),-arm_length*g.randf_range(0.43,0.52),g.randf_range(-0.10,0.10))
		var wrist := shoulder_pos+Vector3(side*(0.32+bulk*0.13),-arm_length,-g.randf_range(0.10,0.29))
		var upper := float(p["upper_arm_radius"])*asym
		var fore := float(p["forearm_radius"])*asym
		var arm := _limb_envelope(g,shoulder,shoulder_pos,elbow,wrist,upper,fore,side,false)
		var hand_scale := clampf(g.randf_range(0.88,1.11)*(0.90+bulk*0.11),0.82,1.30)
		var palm := g.mass(arm,"palm",wrist+Vector3(0,-0.10*hand_scale,0),Vector3(0.11,0.15,0.037)*hand_scale,"flesh")
		g.node(palm)["shape"]={"squareness":1.0}
		g.module("palm_humanoid",palm,g.center(palm),Vector3.FORWARD,Vector3(0.38,0.36,0.32)*hand_scale,{},"flesh",Vector3.DOWN)
		var palm_module: Dictionary=g.dna["modules"][-1]
		palm_module["full_shell"]=true; palm_module["surface_mount"]=false; palm_module["mounting"]="palm_volume"
		var digits := clampi(g.rng.randi_range(3,5)+int(float(g.settings["appendage_density"])*2),3,7)
		var finger_length := g.randf_range(0.27,0.55)*(1.0+float(p["tendency_weights"]["lean_stalker"])*0.25)
		_digits(g,palm,g.center(palm)+Vector3(0,-0.10,0)*hand_scale,Vector3.DOWN,digits,0.34*hand_scale,finger_length,side,hand_scale*g.randf_range(0.85,1.22),g.randf_range(0.42,1.2))
		limb_metrics.append({"side":side,"asymmetry_scale":asym,"arm_length":arm_length,"thigh_radius":thigh,"calf_radius":calf,"upper_arm_radius":upper,"forearm_radius":fore,"hand_scale":hand_scale,"digit_count":digits,"finger_length":finger_length})
	var neck_start := chest_pos+Vector3(0,torso_length*0.31,0.02)
	var neck_end := neck_start+Vector3(lean*0.32,float(p["neck_length"]),-hunch*0.42)
	var neck_radius := float(p["neck_radius"])
	var neck := g.curve(chest,"neck",[neck_start,neck_start.lerp(neck_end,0.32)+Vector3(0,0,0.035),neck_start.lerp(neck_end,0.72),neck_end],[neck_radius*1.40,neck_radius*1.16,neck_radius,neck_radius*1.12],"flesh")
	_tissue(g,neck,neck_radius*0.55,0.018)
	var head := g.mass(neck,"head",neck_end+Vector3(0,float(p["head_height"])*0.56,-0.018),Vector3(float(p["head_width"]),float(p["head_height"]),0.235),"flesh")
	g.face(head)
	for module in g.dna["modules"]:
		if module["parent"]==head:
			module["deformation"]["mouth_open"]=g.randf_range(0.08,0.30+uncanny*0.55)
			module["deformation"]["eye_open"]=g.randf_range(0.03,0.23)
			if module["asset"]=="face_neutral": module["deformation"]["strain"]=g.randf_range(0.08,0.25+uncanny*0.60)
	# Localized growth shares its origin and direction across a family of volumes.
	# This is intentionally unlike the old clearance-maximizing scatter of balls.
	var hosts: Array=[chest,abdomen,pelvis,shoulders[-1.0],shoulders[1.0]]
	Growth.clusters(g,hosts,density*(0.65+float(p["growth_bias"])))
	if uncanny>0.25 and g.rng.randf()<uncanny*0.72:
		var side := -1.0 if g.rng.randf()<0.5 else 1.0
		var host := str(shoulders[side]); var shoulder_pos: Vector3=positions[side]
		var growth := g.mass(host,"growth",shoulder_pos+Vector3(side*0.035,0.08,-0.10),Vector3(0.25,0.27,0.22),"flesh",false)
		_tissue(g,growth,0.12,0.035)
		g.face(growth,false,Vector3(side*0.15,-0.03,-1).normalized(),true)
	var appendages := int(round(float(g.settings["appendage_density"])*(1.0+float(p["tendency_weights"]["distorted_humanoid"])*4.0)))
	for i in range(appendages):
		var side := -1.0 if i%2==0 else 1.0
		var start := chest_pos+Vector3(side*width*0.45,torso_length*g.randf_range(-0.13,0.24),depth*0.48)
		var reach := g.randf_range(0.55,1.10)
		var radii: Array=[0.105,0.08,0.045,0.025]
		var path: Array=[start,start+Vector3(side*reach*0.45,0.18,0.35),start+Vector3(side*reach*0.7,-0.20,0.47),start+Vector3(side*reach*0.57,-reach*0.65,0.39)]
		path=Growth.route_free_appendage(g,chest,path,radii,Vector3.BACK)
		var id := g.curve(chest,"tendril",path,radii,"root")
		_tissue(g,id,0.07,0.025)
	p["limbs"]=limb_metrics
	g.dna["metadata"]["realized_anatomy"]=p
	g.dna["metadata"]["body_plan"]="continuous variable-thickness biped tissue; blended structural tendencies; embedded thoracic support"
	return g.finish()

func _tissue(g: RefCounted, id: String, blend: float, noise: float) -> void:
	g.node(id)["blend"]=blend
	g.node(id)["noise"]=noise*(0.55+float(g.settings["surface_detail"])*0.8)
	if g.node(id)["kind"]=="curve":
		g.node(id)["shape"]={"swelling":0.018+float(g.settings["irregularity"])*0.035,"twist":0.0,"taper":0.0}

func _limb_envelope(g: RefCounted, parent: String, root: Vector3, joint: Vector3, end: Vector3, upper: float, lower: float, side: float, leg: bool) -> String:
	var offset := Vector3(side*upper*0.15,0,upper*(-0.16 if leg else 0.12))
	var path: Array=[root,root.lerp(joint,0.22)+offset,root.lerp(joint,0.50)+offset*0.7,root.lerp(joint,0.83),joint,joint.lerp(end,0.27)+Vector3(0,0,lower*0.20),joint.lerp(end,0.61),joint.lerp(end,0.87),end]
	var radii: Array=[upper*0.87,upper,upper*0.96,upper*0.72,upper*0.61,lower,lower*0.79,lower*0.55,lower*0.43]
	var id: String=g.curve(parent,"limb",path,radii,"flesh")
	_tissue(g,id,upper*0.40,0.025)
	g.node(id)["shape"].merge({"width":1.07 if leg else 1.04,"depth":0.94 if leg else 0.91,"width_profile":[1.0,1.06,1.08,1.0,0.97,1.08,1.0,0.93,1.0],"depth_profile":[1.0,1.02,0.98,0.97,1.0,1.02,0.95,0.94,1.0]},true)
	var joint_mass: String=g.mass(id,"knee" if leg else "elbow",joint+Vector3(0,0,-upper*0.12 if leg else upper*0.10),Vector3(upper*0.61,upper*0.61,upper*0.55),"flesh",false)
	_tissue(g,joint_mass,upper*0.23,0.012)
	g.node(joint_mass)["shape"]={"sculpt_strength":0.60}
	return id

func _detail(g: RefCounted, parent: String, role: String, points: Array, radii: Array, material: String, bone: bool = false) -> String:
	var id: String=g.curve(parent,role,points,radii,material,bone)
	if str(g.node(id).get("role",""))!=role: return id
	g.node(id)["radius"]=float(radii[0]); g.node(id)["radii"]=radii.duplicate()
	g.node(id)["noise"]=0.0; g.node(id)["blend"]=0.012
	g.node(id)["shape"]={"geometry":"detail","profile":role,"surface_follow":false,"width":1.45,"depth":0.75,"ribbing":0.55,"swelling":0.0}
	return id


func _digits(g: RefCounted, parent: String, origin: Vector3, direction: Vector3, count: int, spread_width: float, length: float, hand_side: float = 0.0, thickness: float = 1.0, curl: float = 1.0) -> void:
	var across := Vector3.RIGHT
	var is_hand := absf(hand_side)>0.5
	var bend := (Vector3.FORWARD if is_hand else Vector3.DOWN*0.25)*curl
	var long_count := count-1 if is_hand else count
	for i in count:
		var thumb := is_hand and i==count-1
		var spread := (float(i)/maxf(float(long_count-1),1.0)-0.5)*spread_width*(0.80 if is_hand else 1.0)
		var root := origin+across*spread*0.70+direction*(float(i%2)*0.014 if is_hand else 0.0)
		var axis := direction
		var reach: float = length*g.randf_range(0.84,1.18)
		if thumb:
			root=g.center(parent)-across*hand_side*Graph.vec(g.node(parent)["size"]).x*0.864+direction*0.005
			axis=(direction*0.55-across*hand_side*0.70).normalized()
			reach*=0.55; spread=0.0
		var path: Array=[root,root+axis*reach*0.30+across*spread*0.27,root+axis*reach*0.52+across*spread*0.50+bend*0.018,root+axis*reach*0.76+across*spread*0.65+bend*0.060,root+axis*reach*0.93+across*spread*0.55+bend*0.125,root+axis*reach*0.96+across*spread*0.40+bend*0.19]
		var id := _detail(g,parent,"digit",path,[0.034*thickness,0.030*thickness,0.039*thickness,0.023*thickness,0.013*thickness,0.004],"flesh",true)
		g.node(id)["shape"].merge({"attachment":"root","width":1.0,"depth":0.85,"ribbing":0.20},true)
		if thumb: g.node(id)["digit_role"]="opposable_thumb"
