extends RefCounted
## Reusable anatomical operators. Compatibility is evaluated against the
## biological blueprint and actual parent tissue, never a universal feature list.
const COMPATIBILITY = {"sac":["nodule","vein","fold","lattice"],"face":["fold","fiber","membrane"],"sponge":["cavity","lattice","fiber"],"root":["branch","membrane","vein"],"leg":["muscle","digit","fold"],"stalk":["sensory_bulb","lattice"],"flesh":["sac","face","stalk","limb","fold"]}

static func blockout(g: RefCounted) -> void:
	var d: Dictionary = g.dna
	var r: Vector3 = d.core_radii
	var rng: RandomNumberGenerator = g.rng
	var count: int = d.mass_count
	var plan: String = d.body_plan
	var central := Vector3(.72,.72,.72)
	if plan == "compact": central = Vector3(.94,.94,.94)
	if plan == "cluster": central = Vector3(.6,.65,.65)
	g._feature("core",-1,1,Vector3.ZERO,r*central,"flesh")
	for i in range(1,count):
		var t := float(i)/float(maxi(count-1,1))
		var angle := rng.randf()*TAU
		var p := Vector3.ZERO
		var proportions := Vector3.ONE * rng.randf_range(.48,.78)
		match plan:
			"compact": p = Vector3(cos(angle),rng.randf_range(-.3,.4),sin(angle)) * r * .3
			"flattened": p = Vector3(cos(angle),-.12,sin(angle)) * r * .6; proportions.y = rng.randf_range(.6,.9)
			"tower": p = Vector3(sin(t*4.0)*.25,t*1.1-.25,cos(t*5.0)*.24)*r; proportions.y = rng.randf_range(.45,.7)
			"elongated": p = Vector3(sin(t*5.0)*.4,-.06,t*1.7-.8)*r; proportions.z = rng.randf_range(.42,.62)
			"lopsided": p = Vector3(t*.92,t*.45-.2,sin(t*4.0)*.3)*r; proportions *= lerpf(.8,1.05,t)
			"sagging": p = Vector3(cos(angle)*.6,-absf(sin(angle))*.36,sin(angle)*.7)*r; proportions.y = rng.randf_range(.4,.7)
			"muscular": p = Vector3(cos(angle)*.55,-.18,sin(angle)*.5)*r; proportions.y = .8
			_: p = Vector3(cos(angle)*.65,rng.randf_range(-.22,.65),sin(angle)*.65)*r
		p.x += sin(t*9.0) * r.x * float(d.asymmetry) * .18
		var variance := lerpf(1.0,rng.randf_range(.7,1.2),float(d.controls.mass_variation)*.6)
		g._feature("primary_mass",0,1,p,r*proportions*variance,"flesh")
	# Center the composed volume rather than assuming that the first primitive
	# describes either its dimensions or its ground relationship.
	var bounds: AABB = g.features[0].bounds
	for f: Dictionary in g.features: bounds = bounds.merge(f.bounds)
	var offset := bounds.get_center()
	for f: Dictionary in g.features:
		f.center -= offset
		f.bounds.position -= offset
	d.core_radii = bounds.size * .5
	d.ground_contact = Vector3(0,-d.core_radii.y,0)

static func development(g: RefCounted) -> void:
	var d: Dictionary = g.dna
	var r: Vector3 = d.core_radii
	# Ground-contact tissue follows mass distribution; tall organisms develop
	# buttresses, long organisms a sequence of independent belly contact zones.
	var contacts := 3 if d.body_plan in ["elongated","sagging"] else 1
	for i in contacts:
		var z := (float(i)/float(maxi(contacts-1,1))-.5)*r.z*1.1 if contacts > 1 else 0.0
		g._feature("belly_contact",0,2,Vector3(0,-r.y*.72,z),Vector3(r.x*.68,r.y*.28,r.z*(.35 if contacts>1 else .68)),"belly")
	if d.body_plan in ["tower","muscular"]:
		for side in [-1.0,1.0]:
			g._feature("weight_buttress",0,2,Vector3(r.x*.55*side,-r.y*.5,0),Vector3(r.x*.48,r.y*.6,r.z*.65),"leg")

static func primary(g: RefCounted) -> void:
	var d: Dictionary = g.dna
	var rng: RandomNumberGenerator = g.rng
	var size: float = d.size
	var weights: Dictionary = d.weights
	for i in _count(g,"sac",9):
		var n: Vector3 = _normal(rng,.0,.9)
		var site: Vector3 = g._surface(n)
		var radius := size*rng.randf_range(.3,.58)
		var shape := Vector3(radius*rng.randf_range(.7,1.2),radius*rng.randf_range(.7,1.8),radius*rng.randf_range(.65,1.0))
		var id: int = g._feature("inflated_sac",0,3,site+n*radius*.08,shape,"sac")
		g.features[id].direction = n
		g.features[id]["exposure"] = rng.randf_range(.4,.95)
		g._orient(id,n)
	for i in _count(g,"nodule",10):
		var n: Vector3 = _normal(rng,-.3,.8)
		var site: Vector3 = g._surface(n)
		var radius := size*rng.randf_range(.12,.3)
		var id: int = g._feature("growth_nodule",0,3,site-n*radius*.5,Vector3(radius,radius*rng.randf_range(.7,1.5),radius),"sac" if rng.randf()<.6 else "cartilage")
		g.features[id].direction = n
	var faces := _count(g,"face",3)
	if float(weights.face) > .75: faces = maxi(faces,1)
	for i in faces:
		# Bias toward the visible front hemisphere but vary tilt, depth and scale.
		var angle: float = [.65,2.45,1.55][i%3]+rng.randf_range(-.14,.14)
		var n := Vector3(cos(angle)*.7,rng.randf_range(-.1,.45),sin(angle)).normalized()
		var site: Vector3 = g._surface(n)
		var radius := size*rng.randf_range(.32,.56)
		var id: int = g._feature("embedded_face",0,3,site-n*radius*.18,Vector3(radius*.76,radius*rng.randf_range(1.2,1.65),radius*.9),"face")
		g.features[id].direction = n
		g.features[id]["exposure"] = rng.randf_range(.45,.9)
		g._orient(id,n)
	for i in _count(g,"lattice",4):
		var n: Vector3 = _normal(rng,.2,1.5)
		var site: Vector3 = g._surface(n)
		var radius := size*rng.randf_range(.45,.75)
		var id: int = g._feature("porous_mantle",0,3,site-n*radius*.62,Vector3(radius,radius*.8,radius*.75),"sponge")
		g.features[id].direction = n
		g._orient(id,n)
	for i in _count(g,"cavity",3):
		var n: Vector3 = _normal(rng,-.05,.9)
		var site: Vector3 = g._surface(n)
		var radius := size*rng.randf_range(.2,.42)
		var id: int = g._feature("recess",0,3,site-n*radius*.1,Vector3(radius*rng.randf_range(.65,1.5),radius*rng.randf_range(.6,1.3),radius*.75),"cavity",true)
		g.features[id].direction = n
		g._orient(id,n)
	# No universal leg set. Roots, muscular limbs and a legless rolling shell
	# are genuinely different anatomical outcomes.
	var soft_roller:bool=d.locomotion=="roll" and d.profile in ["swollen","porous","clustered","hollow"] and d.body_plan in ["compact","multilobe","cluster"]
	d["soft_roller"]=soft_roller
	var limb_count := 0 if soft_roller else _count(g,"limb",6)
	if d.locomotion == "limb": limb_count = maxi(2,limb_count)
	for i in limb_count:
		var angle := TAU*float(i)/float(limb_count)+rng.randf_range(-.2,.2)
		var n := Vector3(cos(angle),-.6,sin(angle)).normalized()
		var start: Vector3 = g._surface(n)*.92
		var thick: bool = d.profile == "muscular" or rng.randf()<.4
		var radius := size * (rng.randf_range(.17,.27) if thick else rng.randf_range(.055,.1))
		var end := Vector3(start.x+n.x*size*.65,-float(d.core_radii.y)*.97,start.z+n.z*size*.7)
		var joint := start.lerp(end,.5)+Vector3.UP*size*.25+n*size*.18
		var limb: int = path(g,"muscular_limb" if thick else "jointed_limb",0,[start,joint,end],radius,"leg","active",3)
		g.features[limb]["radii_profile"] = [radius,radius*.7,radius*.38]
		g._feature("limb_socket",0,3,start,Vector3.ONE*radius*1.65,"leg")
		# Fused knuckle/attachment volume plus distinct terminal digits.
		if thick: g._feature("muscle_shoulder",0,3,start-n*radius*.3,Vector3(radius*1.7,radius*1.3,radius*1.5),"leg")
		for digit in 3 if thick else 2:
			var tip := end + Vector3((float(digit)-1.0)*radius*.7,-.02,-radius*1.3)
			path(g,"gripping_digit",limb,[end,end.lerp(tip,.5)+Vector3.UP*radius*.15,tip],radius*.32,"leg","active",3)
	for i in (0 if soft_roller else _count(g,"stalk",5)): _stalk(g)
	for i in (0 if soft_roller else _count(g,"tendril",7)):
		var n: Vector3 = _normal(rng,-.3,.8)
		var start: Vector3 = g._surface(n)*.94
		var radius := size*rng.randf_range(.06,.18)
		var end := start+n*size*rng.randf_range(.5,1.1)+Vector3.DOWN*size*rng.randf_range(.5,1.1)
		end.y = maxf(end.y,-float(d.core_radii.y)*.9)
		var middle := start.lerp(end,.55)+Vector3.UP*size*.35
		var id := path(g,"major_vine",0,[start,middle,end,end+Vector3(-n.z,.2,n.x)*size*.25],radius,"root","drag",3)
		g._feature("vine_socket",0,3,start,Vector3.ONE*radius*1.8,"root")
		g.features[id]["ribbon"] = rng.randf()<.18

static func integrate(g: RefCounted) -> void:
	var rng: RandomNumberGenerator = g.rng
	var hosts: Array = g.features.duplicate()
	for host: Dictionary in hosts:
		if host.feature_type == "embedded_face": _face(g,host)
		if host.feature_type == "inflated_sac" and rng.randf()<.5:
			for j in rng.randi_range(1,3):
				var r: float = host.radii.x*rng.randf_range(.2,.4)
				var p: Vector3 = host.center + _normal(rng,-.3,.7)*host.radii*.8
				g._feature("satellite_sac",host.id,4,p,Vector3.ONE*r,"sac")
		if host.feature_type in ["muscular_limb","jointed_limb"]:
			var p: Vector3 = host.points[0]
			var r: float = host.radii.x
			path(g,"attachment_fiber",host.id,[p+Vector3.RIGHT*r,p+Vector3.UP*r*1.2,p-Vector3.RIGHT*r],r*.18,"root","coupled",4)

static func detail(g: RefCounted) -> void:
	var rng: RandomNumberGenerator = g.rng
	var d: Dictionary = g.dna
	var hosts: Array = g.features.duplicate()
	for host: Dictionary in hosts:
		if host.feature_type == "porous_mantle": lattice(g,host)
		if host.feature_type in ["inflated_sac","embedded_face","weight_buttress"]:
			var allowed: Array=COMPATIBILITY.get(host.tissue,[])
			if "vein" in allowed and float(d.controls.veins)>.05: _vascular(g,host)
			if "fold" in allowed and rng.randf()<float(d.weights.fold): _folds(g,host)
			if "lattice" in allowed and float(d.weights.lattice)>.4 and rng.randf()<float(d.controls.combinations)*.5:
				lattice(g,host,false)
		if host.feature_type == "recess":
			var r: float = host.radii.x
			var n: Vector3 = host.direction
			# Internal nodules and fibrous bridges give recesses real depth.
			g._feature("cavity_organ",host.parent,5,host.center-n*r*.65,Vector3.ONE*r*.27,"sac")
		if host.feature_type in ["major_vine","sensory_stalk"]: _branches(g,host)

static func additional(g: RefCounted) -> void:
	var d: Dictionary = g.dna
	var rng: RandomNumberGenerator = g.rng
	var hosts: Array = g.features.duplicate()
	var vines: Array[Dictionary] = []
	# Regional operators add integrated anatomy before the final extraction.
	for host: Dictionary in hosts:
		if host.feature_type!="primary_mass" or host.id%2!=0: continue
		if float(d.weights.stalk)>.25:
			var n:=Vector3(.35,.9,.2).normalized()
			var start: Vector3=host.center+n*host.radii*.8
			var tip:=start+n*float(d.size)*.55
			path(g,"sensory_sprout",host.id,[start,start.lerp(tip,.5)+Vector3.RIGHT*float(d.size)*.12,tip],float(d.size)*.055,"root","drag",6)
		if float(d.weights.lattice)>.3:
			for plate in 3:
				var n:=Vector3(float(plate-1)*.45,.65,.7).normalized()
				var center: Vector3=host.center+n*host.radii*.87
				var id: int=g._feature("cartilage_plate",host.id,6,center,Vector3(float(d.size)*.23,float(d.size)*.08,float(d.size)*.3),"cartilage")
				g.features[id].direction=n
				g._orient(id,n)
	for host: Dictionary in hosts:
		if host.feature_type in ["major_vine","sensory_stalk"]: vines.append(host)
		if host.feature_type in ["embedded_face","porous_mantle"] and rng.randf()<maxf(float(d.weights.tendril),.25):
			var count := int(lerpf(2,8,float(d.controls.fibers)*float(d.weights.tendril))) if float(d.controls.fibers)>.001 else 0
			for j in count:
				var start: Vector3 = host.center + host.direction*host.radii.z*.75 + Vector3.RIGHT*(float(j)/maxf(count-1,1)-.5)*host.radii.x*1.7
				var end := start+Vector3(rng.randf_range(-.2,.2),-float(d.size)*rng.randf_range(.5,1.2),.25)
				end.y = maxf(end.y,-float(d.core_radii.y)*.95)
				path(g,"facial_drape" if host.tissue=="face" else "root_curtain",host.id,[start,start.lerp(end,.5)+Vector3.FORWARD*.12,end],float(d.size)*rng.randf_range(.018,.035),"root","drag",6)
	if float(d.weights.membrane)>.25 and not d.get("soft_roller",false):
		# A short local web between compatible passive support ribs. Locomotor
		# vines deliberately remain independent; no full-length tarp spans them.
		var n:=Vector3(.25,.9,.2).normalized();var frame:=_frame(n)
		var base:Vector3=g._surface(n)*.96
		var supports:Array[int]=[]
		for side in [-1.0,1.0]:
			var root:Vector3=base+frame.x*float(d.size)*.17*side
			var tip:Vector3=root+n*float(d.size)*.72+frame.x*float(d.size)*.12*side
			var id:=path(g,"membrane_support",0,[root,root.lerp(tip,.5)+frame.y*float(d.size)*.08,tip],float(d.size)*.045,"cartilage","coupled",6)
			supports.append(id)
		var id:int=g._feature("supported_membrane",supports[0],6,base,Vector3.ONE*float(d.size)*.4,"membrane")
		g.features[id]["sheet"]=true;g.features[id]["points"]=[g.features[supports[0]].points[0],g.features[supports[1]].points[0]]
		g.features[id]["support_ids"]=supports

static func path(g: RefCounted, kind: String, parent: int, points: Array, radius: float, tissue: String, coupling: String, pass_id: int) -> int:
	var start: Vector3 = points[0]
	var id: int = g._feature(kind,parent,pass_id,start,Vector3.ONE*radius,tissue)
	var f: Dictionary = g.features[id]
	f["points"] = points
	f["radii_profile"] = []
	for i in points.size(): f.radii_profile.append(radius*lerpf(1.0,.22,float(i)/float(maxi(points.size()-1,1))))
	f["flexibility"] = .8 if coupling=="drag" else .0
	f.roll_coupling = "drag" if coupling=="drag" else "coupled"
	f.slide_coupling = coupling
	f.locomotion_relevance = "locomotor" if coupling=="active" else "passive"
	f.influence = {"shape":"anatomical_sweep","radius":radius}
	f.bounds = AABB(start,Vector3.ZERO)
	for p: Vector3 in points: f.bounds = f.bounds.expand(p)
	f.bounds = f.bounds.grow(radius)
	return id

static func _face(g: RefCounted, host: Dictionary) -> void:
	var rng: RandomNumberGenerator = g.rng
	var n: Vector3 = host.direction
	var frame: Basis = host.inverse_basis.transposed()
	var r: float = host.radii.x
	var p: Vector3 = host.center + n*host.radii.z*.92
	var eye_spacing := rng.randf_range(.32,.46)
	var nose_length := rng.randf_range(.4,.64)
	var parts := [["forehead",Vector3(0,.65,-.04),Vector3(.78,.72,.23)],
		["nose_bridge",Vector3(0,.12,.14),Vector3(.14,nose_length,.22)],
		["nose_tip",Vector3(0,-.13,.29),Vector3(.22,.16,.2)],
		["chin",Vector3(0,-.95,-.02),Vector3(.5,.28,.23)],
		["upper_lip",Vector3(0,-.58,.1),Vector3(.43,.095,.14)],
		["lower_lip",Vector3(0,-.72,.12),Vector3(.4,.095,.15)]]
	for sign_value in [-1.0,1.0]:
		parts.append(["cheek",Vector3(sign_value*.5,-.15,-.02),Vector3(.35,.44,.21)])
		parts.append(["brow",Vector3(sign_value*eye_spacing,.36,.03),Vector3(.36,.14,.18)])
	for part: Array in parts:
		var id: int = g._feature(part[0],host.id,4,p+frame*(part[1]*r),part[2]*r,"face")
		g._orient(id,n)
	for sign_value in [-1.0,1.0]:
		var eye := Vector3(sign_value*eye_spacing,.18,.15)
		var id: int = g._feature("eye_recess",host.id,4,p+frame*(eye*r),Vector3(.27,.12,.16)*r,"cavity",true)
		g._orient(id,n)
		# Closed eyelid ridge prevents an empty skull-like socket.
		path(g,"eyelid",host.id,[p+frame*((eye+Vector3(-.24,0,.0))*r),p+frame*((eye+Vector3(0,-.03,.08))*r),p+frame*((eye+Vector3(.24,0,0))*r)],r*.035,"face","coupled",4)
	var mouth: int = g._feature("mouth_slit",host.id,4,p+frame*Vector3(0,-.65*r,.18*r),Vector3(.35,.035,.12)*r,"cavity",true)
	g._orient(mouth,n)
	# Fused tissue shoulders, rather than a floating mask boundary.
	for side in [-1.0,1.0]:
		path(g,"face_transition",host.id,[p+frame*Vector3(side*r*.7,r*.65,-r*.13),p+frame*Vector3(side*r*.92,-r*.3,-r*.1),p+frame*Vector3(side*r*.5,-r*1.2,-r*.2)],r*.09,"flesh","coupled",4)
	host["face_relief"]=true
	host["eye_spacing"]=eye_spacing
	host["nose_length"]=nose_length

static func lattice(g:RefCounted,host:Dictionary,perforate:bool=true)->void:
	var rng:RandomNumberGenerator=g.rng
	var frame:Basis=host.get("inverse_basis",Basis.IDENTITY).transposed()
	var r:Vector3=host.radii
	var count:=clampi(int(15*float(g.dna.controls.detail)),6,24)
	if perforate:
		for i in count:
			var angle:=float(i)*2.399963+float(host.id)*.37
			var spread:=sqrt((float(i)+.5)/count)*.84
			var u:=cos(angle)*spread;var v:=sin(angle)*spread
			var z:=sqrt(maxf(.05,1-u*u-v*v))
			var direction:Vector3=(frame*Vector3(u*.4,v*.4,1)).normalized()
			var center:Vector3=host.center+frame*Vector3(u*r.x,v*r.y,z*r.z)
			var radius:float=minf(r.x,r.y)*rng.randf_range(.12,.20)
			var id:int=g._feature("lattice_opening",host.id,5,center,Vector3(radius,radius*rng.randf_range(.7,1.25),r.z*.65),"cavity",true)
			g._orient(id,direction)
	for i in 7:
		var a:=float(i)*TAU/7;var b:=float(i+1)*TAU/7
		var start:Vector3=host.center+frame*(Vector3(cos(a)*.8,sin(a)*.7,.4)*r)
		var end:Vector3=host.center+frame*(Vector3(cos(b)*.8,sin(b)*.7,.4)*r)
		var mid:Vector3=host.center+frame*(Vector3(cos((a+b)*.5)*.82,sin((a+b)*.5)*.75,.7)*r)
		var id:=path(g,"lattice_bridge",host.id,[start,mid,end],minf(r.x,r.y)*.1,"sponge","coupled",5)
		g.features[id]["fused_path"]=true

static func prepare_integrated(g:RefCounted)->void:
	for f:Dictionary in g.features:
		if not f.has("points") or f.feature_type not in ["vascular_trunk","vascular_branch","capillary","anatomical_fold","eyelid","face_transition","lattice_bridge","lattice_arch"]:continue
		if not f.get("fused_path",false):
			var host:Dictionary=g.features[maxi(f.parent,0)]
			while host.has("points") and host.parent>=0:host=g.features[host.parent]
			var outward:Vector3=host.direction
			for i in f.points.size():
				var original:Vector3=f.points[i];var shift:=.0;var e:float=g.dna.size*.004
				for iteration in 5:
					var p:=original+outward*shift
					var distance:float=g._positive_field(p)
					var gradient:float=(g._positive_field(p+outward*e)-g._positive_field(p-outward*e))/(2*e)
					if absf(gradient)<.15:break
					shift=clampf(shift-distance/gradient,-g.dna.size*.35,g.dna.size*.5)
				f.points[i]=original+outward*(shift+float(f.radii_profile[i])*.15)
			for i in f.radii_profile.size():f.radii_profile[i]=maxf(float(f.radii_profile[i])*1.6,float(g.dna.size)*.016)
		f["fused_path"]=true
		f.bounds=AABB(f.points[0],Vector3.ZERO)
		for p:Vector3 in f.points:f.bounds=f.bounds.expand(p)
		f.bounds=f.bounds.grow(float(f.radii_profile.max())*1.5)

static func _stalk(g: RefCounted) -> void:
	var rng: RandomNumberGenerator = g.rng
	var d: Dictionary = g.dna
	var n: Vector3 = _normal(rng,.6,1.5)
	var start: Vector3 = g._surface(n)*.96
	var length := float(d.size)*rng.randf_range(.8,1.7)
	var end := start+Vector3(n.x*.6,1,n.z*.6)*length
	var mid := start.lerp(end,.55)+Vector3(rng.randf_range(-.3,.3),.15,.15)*length
	var radius := float(d.size)*rng.randf_range(.055,.095)
	var id := path(g,"sensory_stalk",0,[start,mid,end],radius,"root","coupled",3)
	g.features[id].radii_profile = [radius*1.4,radius,radius*.85]
	g._feature("stalk_socket",0,3,start,Vector3.ONE*radius*2.2,"flesh")
	# Bulb surface is a second parametric volume anchored to the stalk, not a
	# remote SDF island; shell perforations and ribs are generated directly.
	var bulb := path(g,"sensory_bulb",id,[end,end+Vector3.UP*radius*3.5],radius*3.3,"sponge","coupled",3)
	g.features[bulb]["bulb"] = true
	g.features[bulb]["bulb_radii"] = Vector3(radius*3.3,radius*3.8,radius*3.0)
	g.features[bulb]["flexibility"] = 0.0

static func _branches(g: RefCounted, host: Dictionary) -> void:
	var rng: RandomNumberGenerator = g.rng
	if host.feature_type == "sensory_stalk" and rng.randf()>.3: return
	var count := maxi(1,int(float(g.dna.controls.branches)*rng.randi_range(2,4)))
	for i in count:
		var t := rng.randf_range(.45,.95)
		var start: Vector3 = host.points[1].lerp(host.points[-1],t)
		var r: float = host.radii.x*.4
		var curl := Vector3(rng.randf_range(-.4,.4),rng.randf_range(-.5,.2),rng.randf_range(-.4,.4))*float(g.dna.size)
		path(g,"vine_branch",host.id,[start,start+curl*.55+Vector3.UP*.1,start+curl,start+curl+Vector3(curl.z,.07,-curl.x)*.4],r,"root","drag",5)

static func _vascular(g: RefCounted, host: Dictionary) -> void:
	var n: Vector3 = host.direction
	var frame: Basis = host.get("inverse_basis",Basis.IDENTITY).transposed()
	var r: Vector3 = host.radii
	var root: Vector3 = host.center+frame*Vector3(0,-r.y*.7,r.z*.7)
	var fork: Vector3 = host.center+frame*Vector3(.05*r.x,.05*r.y,r.z*.99)
	var tip: Vector3 = host.center+frame*Vector3(.12*r.x,r.y*.8,r.z*.65)
	var radius := r.x*.018*float(g.dna.controls.veins)
	var trunk := path(g,"vascular_trunk",host.id,[root,fork,tip],radius,"vein","coupled",5)
	for side in [-1.0,1.0]:
		var end: Vector3 = host.center+frame*Vector3(side*r.x*.7,r.y*.48,r.z*.68)
		var child := path(g,"vascular_branch",trunk,[fork,fork.lerp(end,.5)+n*r.x*.08,end],radius*.6,"vein","coupled",5)
		for j in 2:
			var start: Vector3 = fork.lerp(end,.45+float(j)*.25)
			path(g,"capillary",child,[start,start+frame*Vector3(side*r.x*.15,r.y*.17,-r.z*.03),start+frame*Vector3(side*r.x*.2,r.y*.26,-r.z*.09)],radius*.3,"vein","coupled",5)

static func _folds(g: RefCounted, host: Dictionary) -> void:
	var frame: Basis = host.get("inverse_basis",_frame(host.direction).transposed()).transposed()
	var r: Vector3 = host.radii
	var count := maxi(2,int(float(g.dna.weights.fold)*5.0))
	for j in count:
		var y := (float(j)/float(maxi(count-1,1))-.5)*r.y*1.5
		var points: Array = []
		for i in 5:
			var t := float(i)/4.0*PI
			var local := Vector3(cos(t)*r.x*.92,y+sin(t*2.0)*r.y*.07,sin(t)*r.z*.95)
			points.append(host.center+frame*local)
		var id := path(g,"anatomical_fold",host.id,points,r.x*.045,"flesh","coupled",5)
		g.features[id].radii_profile = [r.x*.025,r.x*.05,r.x*.06,r.x*.05,r.x*.025]

static func _count(g: RefCounted, family: String, maximum: int) -> int:
	var weight: float = g.dna.weights[family]
	if weight < .16: return 0
	return clampi(roundi(weight*float(maximum)*g.rng.randf_range(.55,1.1)),0,maximum*2)

static func _normal(rng: RandomNumberGenerator, low: float, high: float) -> Vector3:
	var a := rng.randf()*TAU
	return Vector3(cos(a),rng.randf_range(low,high),sin(a)).normalized()

static func _frame(n: Vector3) -> Basis:
	var side := Vector3.UP.cross(n).normalized()
	if side.length_squared()<.1: side=Vector3.RIGHT
	return Basis(side,n.cross(side).normalized(),n)
