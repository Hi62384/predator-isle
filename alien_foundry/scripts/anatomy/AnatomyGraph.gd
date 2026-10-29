extends RefCounted
const MassReprofileField = preload("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd")
const BodyGroupField = preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const EnvelopeField = preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
## Anatomy-first connected growth. The mutable builder is never shared between jobs.
const DNA = preload("res://alien_foundry/scripts/anatomy/CreatureDNA.gd")
const Component = preload("res://alien_foundry/scripts/anatomy/AnatomyNode.gd")
const Connection = preload("res://alien_foundry/scripts/anatomy/AnatomyConnection.gd")
const HangingTissue = preload("res://alien_foundry/scripts/geometry/BlobHangingTissueField.gd")
const HangingRoot = preload("res://alien_foundry/scripts/geometry/BlobHangingRootField.gd")
const GrownContact = preload("res://alien_foundry/scripts/geometry/BlobGrownContactField.gd")
const GrownField = preload("res://alien_foundry/scripts/geometry/BlobGrownEnvelopeField.gd")
const MantleField = preload("res://alien_foundry/scripts/geometry/BlobMantleField.gd")
const MantleButtress = preload("res://alien_foundry/scripts/geometry/BlobMantleButtressField.gd")
var dna: Dictionary = {}
var settings: Dictionary = {}
var rng := RandomNumberGenerator.new()
var index: Dictionary = {}

func initialize(creature_type: String, seed_value: int, options: Dictionary) -> void:
	dna = DNA.create(creature_type, seed_value, options)
	settings = dna["settings"]
	rng.seed = seed_value

static func vec(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Array and value.size() >= 3: return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

static func node_basis(n: Dictionary) -> Basis:
	var rotation: Variant = n.get("rotation",[0,0,0])
	if rotation is Array and rotation.size() == 4:
		return Basis(Quaternion(float(rotation[0]),float(rotation[1]),float(rotation[2]),float(rotation[3])).normalized())
	return Basis.from_euler(vec(rotation))

static func arr(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func randf_range(a: float, b: float) -> float:
	return rng.randf_range(a,b)

func jitter(amplitude: float = 1.0) -> Vector3:
	return Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-0.7,0.7),rng.randf_range(-1.0,1.0)) * amplitude * float(settings["irregularity"])

func node(id: String) -> Dictionary:
	return index.get(id,{})

func center(id: String) -> Vector3:
	return vec(node(id).get("position",[0,0,0]))

func tip(id: String) -> Vector3:
	var n := node(id)
	var p: Array = n.get("points",[])
	return vec(p[-1]) if not p.is_empty() else vec(n.get("position",[0,0,0]))

func _add(n: Dictionary) -> String:
	if dna["nodes"].size() >= int(dna["budget"]["nodes"]): return str(n.get("parent",""))
	n["id"] = "n%03d" % dna["nodes"].size()
	n["source"] = str(dna["type"]) + ":" + str(dna["seed"])
	n["noise"] = (0.0 if n["kind"] == "cavity" else (0.018 + float(settings["surface_detail"]) * 0.105)) * (0.65 if n["role"] in ["head","digit","joint"] else 1.0)
	n["deformation"] = {"phase":rng.randf_range(0.0,100.0), "warp":0.1+0.35*float(settings["irregularity"]), "fold_frequency":rng.randf_range(1.8,4.2)}
	dna["nodes"].append(n)
	index[n["id"]] = n
	if not str(n["parent"]).is_empty(): dna["connections"].append(Connection.make(n["parent"],n["id"],"growth",n["blend"]))
	return n["id"]

func mass(parent: String, role: String, position: Vector3, radii: Vector3, material: String = "flesh", bone: bool = true) -> String:
	var n := Component.make("",parent,"mass",role,arr(position),arr(radii),material)
	n["radius"] = minf(radii.x,minf(radii.y,radii.z))
	n["blend"] = maxf(0.08,float(n["radius"])*0.38)
	n["bone"] = bone
	n["joints"]["motion"] = "breathe" if role in ["core","torso","pelvis","lobe","abdomen"] else "sway"
	return _add(n)

func curve(parent: String, role: String, positions: Array, radii: Array, material: String = "muscle", bone: bool = true) -> String:
	var points: Array = []
	for p in positions: points.append(arr(vec(p)))
	var r := maxf(float(radii[0]),0.035)
	var n := Component.make("",parent,"curve",role,points[0],[r,r,r],material)
	n["points"] = points
	n["radii"] = radii.duplicate()
	n["radius"] = r
	n["blend"] = maxf(0.055,r*0.58)
	n["bone"] = bone
	n["joints"] = {"motion":"flex" if role in ["limb","digit","body_chain"] else "sway", "limits":[-0.55,0.55]}
	n["shape"] = {"swelling":0.025+float(settings["irregularity"])*0.10, "twist":float(settings["irregularity"])*0.16 if role in ["tail","tendril","trunk"] else 0.0, "taper":0.0}
	return _add(n)

func cavity(parent: String, position: Vector3, radii: Vector3) -> String:
	var n := Component.make("",parent,"cavity","cavity",arr(position),arr(radii),"muscle")
	n["bone"] = false
	n["blend"] = 0.035
	n["noise"] = 0.0
	return _add(n)

func module(asset: String, parent: String, position: Vector3, normal: Vector3, scale: Vector3, deformation: Dictionary = {}, material: String = "flesh", up: Vector3 = Vector3.UP) -> void:
	if dna["modules"].size() >= int(dna["budget"]["modules"]): return
	var n := normal.normalized()
	if absf(n.dot(up)) > 0.95: up = Vector3.FORWARD
	dna["modules"].append({"id":"m%03d" % dna["modules"].size(), "asset":asset, "parent":parent,
		"position":arr(position),"normal":arr(n),"up":arr(up),"scale":arr(scale),
		"deformation":deformation.duplicate(true),"material":material})

func face(parent: String, animal: bool = false, normal: Vector3 = Vector3.FORWARD, front_only: bool = false) -> void:
	var n := node(parent)
	if n.is_empty(): return
	var s := vec(n["size"])
	var outward := normal.normalized()
	var anchor := vec(n["position"]) + outward * surface_radius(s,outward) * 0.94
	var uncanny := float(settings["uncanny_features"])
	var choices := ["face_neutral","face_mask","face_elongated"]
	var asset := str(choices[rng.randi_range(0,2)])
	if animal: asset = "muzzle_long" if rng.randf() > 0.5 else "muzzle_short"
	var width := minf(s.x*1.72,s.y*1.25)
	# Embedded faces need an exposed surface sector. Do not place a face under
	# another body lobe simply because its parent mass has a front direction.
	var clearance := _growth_clearance(parent,anchor+outward*width*0.12,width*0.32)
	if clearance < 0.0 and not front_only and str(n.get("role",""))!="head":
		for angle in [0.55,-0.55,1.1,-1.1,1.8,-1.8,PI]:
			var candidate_normal := normal.rotated(Vector3.UP,float(angle)).normalized()
			var candidate_anchor := vec(n["position"])+candidate_normal*surface_radius(s,candidate_normal)*0.94
			var candidate_clearance := _growth_clearance(parent,candidate_anchor+candidate_normal*width*0.12,width*0.32)
			if candidate_clearance > clearance:
				outward=candidate_normal; anchor=candidate_anchor; clearance=candidate_clearance
	var is_cranial_head:=not animal and str(n.get("role",""))=="head"
	if not animal:
		if is_cranial_head:
			anchor=vec(n["position"])+outward*width*0.20
			var support_shape:Dictionary=n.get("shape",{}).duplicate(true)
			support_shape["carrier_scale"]=0.5
			n["shape"]=support_shape
		else:
			anchor=vec(n["position"])+outward*(surface_radius(s,outward)*0.94+width*0.25)
	var height := width * rng.randf_range(0.87,1.08)
	var deform := {"width":rng.randf_range(-0.4,0.35),"height":uncanny*0.55+rng.randf_range(-0.15,0.1),"forehead":rng.randf_range(-0.3,0.4),
		"jaw":rng.randf_range(-0.55,0.35),"eye_spacing":rng.randf_range(-0.35,0.2+uncanny*0.35),"eye_size":rng.randf_range(-0.3,0.35),
		"nose_projection":rng.randf_range(-0.35,0.25),"mouth_width":rng.randf_range(-0.3,uncanny*0.4),"asymmetry":uncanny*float(settings["irregularity"])*0.65,
		"curvature":0.15+uncanny*0.15,"mouth_open":rng.randf_range(0.35,0.70),"eye_open":rng.randf_range(0.0,0.28)}
	var prior_modules: int = dna["modules"].size()
	var module_scale := Vector3(width,height,width)
	if animal:
		# Muzzles are not humanoid masks: their authored width and projection
		# differ markedly. Normalize each axis to the measured source spans so
		# a long muzzle is a broad snout, not a thin horn on a large skull.
		var source_span := Vector3(0.6794,0.60,0.974) if asset=="muzzle_long" else Vector3(0.871,0.68,0.538)
		var target_span := Vector3(s.x*lerpf(1.5,1.7,clampf((float(deform["width"])+0.4)/0.75,0.0,1.0)),s.y*lerpf(1.0,1.2,clampf((height/width-0.87)/0.21,0.0,1.0)),s.z*lerpf(0.65,0.90,clampf((float(deform["nose_projection"])+0.35)/0.60,0.0,1.0)))
		module_scale=target_span/source_span
		anchor-=Vector3.UP*s.y*0.15
		deform["width"]=float(deform["width"])*0.4
		deform["height"]=float(deform["height"])*0.4
	module(asset,parent,anchor,outward,module_scale,deform)
	if not animal and dna["modules"].size()>prior_modules:
		var spec:Dictionary=dna["modules"][-1]
		spec["full_shell"]=true
		spec["surface_mount"]=not is_cranial_head
		spec["shell_surface_offset"]=0.0 if is_cranial_head else 0.25
		spec["mounting"]="craniofacial" if is_cranial_head else "embedded_cranial"
	# Recess underlying tissue behind the real module's mouth. This is subtraction,
	# not a floating black disk, and remains local to the supporting head.
	if not animal and width > 0.25:
		cavity(parent,anchor-Vector3.UP*height*0.22-outward*width*0.035,Vector3(width*0.2,width*0.09,width*0.22))

func sensory(parent: String, count: int = 1) -> void:
	var n := node(parent)
	var s := vec(n.get("size",[0.5,0.5,0.5]))
	for i in range(count):
		var angle := rng.randf_range(-1.1,1.1)
		var outward := Vector3(sin(angle),rng.randf_range(0.05,0.5),-cos(angle)).normalized()
		var p := center(parent)+outward*surface_radius(s,outward)*0.98
		var width := rng.randf_range(0.17,0.28)*minf(1.2,s.length())
		module("eye_recessed" if rng.randf()>0.5 else "eye_socket",parent,p,outward,Vector3(width,width,width),{"eye_open":0.5,"eye_size":rng.randf_range(-0.2,0.2)},"slime")

func paired_sensory(parent: String) -> void:
	# One orbital level and a shared spread produce a recognizable paired sensory
	# arrangement. Bounded per-side changes retain organic asymmetry, never stack.
	var host := node(parent)
	var size := vec(host.get("size",[0.4,0.4,0.4]))
	var spread := rng.randf_range(0.65,0.82)
	var elevation := rng.randf_range(0.22,0.34)
	var irregularity := float(settings["irregularity"])
	for side in [-1.0,1.0]:
		var outward := Vector3(side*(spread+rng.randf_range(-0.04,0.04)*irregularity),elevation+rng.randf_range(-0.035,0.035)*irregularity,-0.76).normalized()
		var position := center(parent)+outward*surface_radius(size,outward)*0.98
		var width := clampf(size.x*rng.randf_range(0.58,0.70),0.16,0.34)
		module("eye_socket",parent,position,outward,Vector3.ONE*width,{"eye_open":rng.randf_range(0.02,0.22),"eye_size":rng.randf_range(-0.10,0.14)},"slime")

static func surface_radius(size: Vector3, direction: Vector3) -> float:
	if direction.length_squared() < 0.00000001: return minf(size.x,minf(size.y,size.z))
	var d := direction.normalized()
	return 1.0/sqrt(pow(d.x/maxf(size.x,0.01),2)+pow(d.y/maxf(size.y,0.01),2)+pow(d.z/maxf(size.z,0.01),2))

func digits(parent: String, tip_position: Vector3, direction: Vector3, width: float, count: int, claws: bool = false) -> void:
	var forward := direction.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared()<0.1: side = Vector3.RIGHT
	for i in range(count):
		var spread := (float(i)-float(count-1)*0.5)*width*0.42
		var start := tip_position+side*spread*0.5
		var length := width*rng.randf_range(0.85,1.6)
		var mid := start+forward*length*0.55+side*spread*0.5
		var end := start+forward*length+side*spread+Vector3.UP*length*0.12
		curve(parent,"digit",[start,mid,end],[width*0.14,width*0.1,0.035],"bone" if claws else "flesh",true)

func growths(hosts: Array, amount_multiplier: float = 1.0) -> void:
	if hosts.is_empty(): return
	var density := float(settings["growth_density"])
	var count := mini(int(dna["budget"]["growths"]),int(round(density*rng.randf_range(5.0,11.0)*amount_multiplier)))
	for i in range(count):
		var parent := str(hosts[rng.randi_range(0,hosts.size()-1)])
		var host := node(parent)
		if host.is_empty(): continue
		var s := vec(host["size"])
		var dir := Vector3(rng.randf_range(-1,1),rng.randf_range(0.15,1),rng.randf_range(-1,1)).normalized()
		var radius := clampf(s.length()*rng.randf_range(0.12,0.24),0.12,0.52)
		var p := center(parent)+dir*surface_radius(s,dir)*rng.randf_range(0.68,0.88)
		# Grow into an unoccupied surface sector. Several bounded candidates are
		# scored against existing tissue instead of independent random placement.
		var clearance := _growth_clearance(parent,p,radius)
		for attempt in range(5):
			var candidate_dir := Vector3(rng.randf_range(-1,1),rng.randf_range(0.15,1),rng.randf_range(-1,1)).normalized()
			var candidate := center(parent)+candidate_dir*surface_radius(s,candidate_dir)*0.86
			var score := _growth_clearance(parent,candidate,radius)
			if score > clearance:
				dir=candidate_dir; p=candidate; clearance=score
		var material := "membrane" if rng.randf()<0.22 else ("chitin" if rng.randf()<0.16 else "flesh")
		var lobe := mass(parent,"growth",p,Vector3(radius*rng.randf_range(0.8,1.3),radius*rng.randf_range(0.6,1.4),radius),material,false)
		if density > 0.7 and rng.randf() < 0.12:
			curve(lobe,"mineral_growth",[p,p+dir*radius*1.3,p+dir*radius*2.0],[radius*0.55,radius*0.28,0.025],"crystal",false)
		if i==0 and density>0.65:
			module("sensory_fold",lobe,p+dir*radius*0.8,dir,Vector3.ONE*radius*0.8,{},material)

func landmark(parent: String, positions: Array, radii: Array, material: String = "flesh") -> String:
	var id := curve(parent,"fold",positions,radii,material,false)
	if index.has(id):
		index[id]["blend"]=maxf(0.025,float(radii[0])*0.42)
		index[id]["noise"]=0.018
		index[id]["shape"]={"swelling":0.0,"twist":0.0,"taper":0.0}
	return id

func tendon(parent: String, positions: Array, radii: Array, material: String = "muscle") -> String:
	# Fine anatomical strands are a separately sampled, parent-owned tissue layer.
	# The fused primary body does not rely on these thin strands for connectivity.
	var id := curve(parent,"tendon",positions,radii,material,false)
	if index.has(id) and str(index[id].get("role",""))=="tendon":
		index[id]["noise"]=0.0
		index[id]["blend"]=0.012
		index[id]["shape"]={"swelling":rng.randf_range(0.08,0.28),"twist":0.0,"taper":0.0,"width":rng.randf_range(1.5,2.8),"depth":rng.randf_range(0.27,0.46),"ribbing":rng.randf_range(0.45,0.85),"surface_follow":str(node(parent).get("role","")) not in ["ligament","aperture_rim"],"webbing":0.0}
	return id

func fiber_bundle(parent: String, count: int, radius: float = 0.035, material: String = "muscle") -> void:
	var host := node(parent)
	var points: Array=host.get("points",[])
	var radii: Array=host.get("radii",[])
	if points.size()<2: return
	for strand in range(count):
		var phase := TAU*pow(float(strand)/maxf(1.0,float(count)),1.13)+rng.randf_range(-0.26,0.26)
		var path: Array=[]; var widths: Array=[]
		var thickness:=rng.randf_range(0.65,1.35)
		for j in range(points.size()):
			var axis := (vec(points[mini(j+1,points.size()-1)])-vec(points[maxi(j-1,0)])).normalized()
			var across := axis.cross(Vector3.FORWARD).normalized()
			if across.length_squared()<0.1: across=axis.cross(Vector3.UP).normalized()
			var around := axis.cross(across).normalized()
			var t:=float(j)/maxf(float(points.size()-1),1.0)
			var converged:=roundf(phase/PI)*PI
			var roll := lerpf(converged,phase,sin(t*PI)*0.83)+sin(float(j)*1.1+phase)*0.23
			var embedding := 0.48 if j==0 or j==points.size()-1 else 0.96
			path.append(vec(points[j])+(across*cos(roll)+around*sin(roll))*float(radii[j])*embedding)
			widths.append(minf(radius*thickness,float(radii[j])*0.23)*(0.62 if j==0 or j==points.size()-1 else rng.randf_range(0.72,1.25)))
		var id:=tendon(parent,path,widths,material)
		if strand%3==1 and index.has(id) and str(index[id].get("role",""))=="tendon":
			index[id]["shape"]["webbing"]=0.38

func surface_fibers(parent: String, count: int, material: String = "muscle", radius: float = 0.035) -> void:
	var host := node(parent)
	var s := vec(host.get("size",[0.5,0.5,0.5])); var c:=center(parent)
	for strand in range(count):
		var phase := TAU*float(strand)/maxf(float(count),1.0)+rng.randf_range(-0.1,0.1)
		var path: Array=[]; var widths: Array=[]
		for j in range(5):
			var h:=lerpf(-0.88,0.88,float(j)/4.0)
			var section:=sqrt(maxf(0.0,1.0-h*h))
			var bend:=phase+sin(h*2.8+phase)*0.38+h*0.22
			var embedding:=0.68 if j==0 or j==4 else 0.99
			path.append(c+Vector3(cos(bend)*s.x*section*embedding,h*s.y,sin(bend)*s.z*section*embedding))
			widths.append(radius*(0.65 if j==0 or j==4 else rng.randf_range(0.8,1.25)))
		tendon(parent,path,widths,material)

func aperture(parent: String, position: Vector3, radii: Vector3) -> void:
	# A deep frontal tissue pocket with an anatomically grown, asymmetric lip.
	var cavity_id:=cavity(parent,position,radii)
	if index.has(cavity_id) and index[cavity_id].get("kind","")=="cavity":
		index[cavity_id]["surface_opening"]=true
		index[cavity_id]["normal"]=[0,0,-1]
	var path: Array=[]; var widths: Array=[]
	for j in range(9):
		var angle:=TAU*float(j)/8.0
		path.append(position+Vector3(cos(angle)*radii.x*1.08,sin(angle)*radii.y*1.06,radii.z*0.20))
		widths.append(clampf(minf(radii.x,radii.y)*0.24,0.045,0.095))
	var id:=curve(parent,"aperture_rim",path,widths,"flesh",false)
	if index.has(id) and str(index[id].get("role",""))=="aperture_rim":
		index[id]["blend"]=0.025
		index[id]["noise"]=0.01
		index[id]["cavity_id"]=cavity_id

func surface_folds(parent: String, count: int, longitudinal: bool = false, material: String = "flesh") -> void:
	# Anatomically oriented folds follow the host's cross-section, rather than
	# uniform noise or unrelated attachments. Their outer arcs form rib/scute
	# landmarks while the inner half remains continuously embedded in tissue.
	var host := node(parent)
	if host.is_empty(): return
	var size := vec(host["size"])
	var origin := center(parent)
	for i in range(count):
		var along := lerpf(-0.48,0.50,float(i)/maxf(float(count-1),1.0))
		var section := sqrt(maxf(0.1,1.0-along*along))
		var points: Array=[]
		for j in range(5):
			var angle := lerpf(-1.25,1.25,float(j)/4.0)
			var point := Vector3(sin(angle)*size.x*section*0.94,along*size.y,-cos(angle)*size.z*section*0.94)
			if longitudinal: point=Vector3(sin(angle)*size.x*section*0.94,cos(angle)*size.y*section*0.94,along*size.z)
			else: point.y-=absf(sin(angle))*size.y*0.07
			points.append(origin+point)
		var radius := clampf(minf(size.x,size.y)*0.115,0.04,0.085)
		var id := curve(parent,"fold",points,[radius*0.55,radius,radius*0.82,radius,radius*0.55],material,false)
		if index.has(id):
			index[id]["blend"]=radius*0.5
			index[id]["noise"]=0.02
			index[id]["shape"]={"swelling":0.0,"twist":0.0,"taper":0.0}

func _growth_clearance(parent: String, position: Vector3, radius: float) -> float:
	var clearance := 10.0
	for existing in dna["nodes"]:
		if str(existing["id"]) == parent or existing.get("kind","") == "cavity": continue
		clearance = minf(clearance,distance_to_tissue(existing,position)-radius)
	return minf(clearance,_module_clearance(position,radius))

func _module_clearance(position: Vector3, radius: float) -> float:
	var clearance := 10.0
	for feature in dna["modules"]:
		var extent := vec(feature.get("scale",[0.2,0.2,0.2]))
		clearance=minf(clearance,position.distance_to(vec(feature["position"]))-radius-maxf(extent.x,extent.y)*0.55)
	return clearance

func tendrils(hosts: Array, count: int, length_scale: float = 1.0) -> void:
	for i in range(count):
		if hosts.is_empty(): return
		var parent := str(hosts[rng.randi_range(0,hosts.size()-1)])
		var host := node(parent)
		var s := vec(host.get("size",[0.4,0.4,0.4]))
		var dir := Vector3(rng.randf_range(-1,1),rng.randf_range(0.2,0.9),rng.randf_range(-1,1)).normalized()
		var start := center(parent)+dir*surface_radius(s,dir)*0.6
		var length := rng.randf_range(0.65,1.55)*length_scale
		var clearance := minf(_growth_clearance(parent,start+dir*length,0.12),_module_clearance(start+dir*length*0.45,0.15))
		for attempt in range(4):
			var candidate_dir := Vector3(rng.randf_range(-1,1),rng.randf_range(0.2,0.9),rng.randf_range(-1,1)).normalized()
			var candidate_start := center(parent)+candidate_dir*surface_radius(s,candidate_dir)*0.6
			var score := minf(_growth_clearance(parent,candidate_start+candidate_dir*length,0.12),_module_clearance(candidate_start+candidate_dir*length*0.45,0.15))
			if score > clearance: dir=candidate_dir; start=candidate_start; clearance=score
		var bend := dir.cross(Vector3.UP)*rng.randf_range(-0.5,0.5)
		var pts := [start,start+dir*length*0.35,start+dir*length*0.7+bend*length*0.3,start+dir*length*0.93+bend*length*0.6-Vector3.UP*length*0.15]
		var radius := rng.randf_range(0.10,0.18)
		curve(parent,"tendril",pts,[radius,radius*0.84,radius*0.53,0.035],"root",true)

func finish() -> Dictionary:
	dna = repair(dna)
	var size := float(settings["size"])
	scale_graph(dna,size)
	ground_graph(dna)
	dna["validation"] = validate(dna)
	dna["metadata"]["node_count"] = dna["nodes"].size()
	dna["metadata"]["module_count"] = dna["modules"].size()
	return dna

static func scale_graph(graph: Dictionary, scale_factor: float) -> void:
	if is_equal_approx(scale_factor,1.0): return
	for n in graph.get("nodes",[]):
		EnvelopeField.scale_descriptor(n,scale_factor)
		BodyGroupField.scale_descriptor(n,scale_factor)
		MassReprofileField.scale_descriptor(n,scale_factor)
		n["position"] = arr(vec(n["position"])*scale_factor)
		if n.has("growth_origin"): n["growth_origin"]=arr(vec(n["growth_origin"])*scale_factor)
		n["size"] = arr(vec(n["size"])*scale_factor)
		n["radius"] = float(n.get("radius",0.1))*scale_factor
		n["blend"] = float(n.get("blend",0.1))*scale_factor
		var points: Array = n.get("points",[])
		for i in range(points.size()): points[i]=arr(vec(points[i])*scale_factor)
		var radii: Array = n.get("radii",[])
		for i in range(radii.size()): radii[i]=float(radii[i])*scale_factor
	for m in graph.get("modules",[]):
		m["position"]=arr(vec(m["position"])*scale_factor)
		m["scale"]=arr(vec(m.get("scale",[1,1,1]))*scale_factor)
	for c in graph.get("connections",[]): c["blend"]=float(c.get("blend",0.1))*scale_factor

static func translate_graph(graph: Dictionary, translation: Vector3) -> void:
	for n in graph.get("nodes",[]):
		EnvelopeField.translate_descriptor(n,translation)
		BodyGroupField.translate_descriptor(n,translation)
		MassReprofileField.translate_descriptor(n,translation)
		n["position"]=arr(vec(n["position"])+translation)
		if n.has("growth_origin"): n["growth_origin"]=arr(vec(n["growth_origin"])+translation)
		var points: Array = n.get("points",[])
		for i in range(points.size()): points[i]=arr(vec(points[i])+translation)
	for m in graph.get("modules",[]): m["position"]=arr(vec(m["position"])+translation)

static func ground_graph(graph: Dictionary) -> void:
	var bottom := INF
	for n in graph.get("nodes",[]):
		if n.get("kind","")=="cavity": continue
		if GrownField.marked(n):
			var field: RefCounted = GrownField.create(n.shape.grown_envelope,vec(n.size))
			bottom=minf(bottom,vec(n.position).y+float(field.minimum_surface_y(node_basis(n)).minimum_y))
		elif GrownContact.marked(n): bottom=minf(bottom,float(GrownContact.minimum(n).minimum_y))
		elif mantle_marked(n): bottom=minf(bottom,mantle_bounds(n).position.y)
		elif n.get("kind","")=="curve":
			var points: Array=n.get("points",[])
			var radii: Array=n.get("radii",[])
			for i in range(points.size()): bottom=minf(bottom,vec(points[i]).y-float(radii[i]))
		else: bottom=minf(bottom,vec(n["position"]).y-vec(n["size"]).y)
	if is_finite(bottom): translate_graph(graph,Vector3(0,-bottom+0.035,0))

static func distance_to_tissue(n: Dictionary, point: Vector3) -> float:
	if MassReprofileField.marked(n):
		var field: RefCounted = MassReprofileField.create(n)
		return field.distance(point) if field.valid else NAN
	if BodyGroupField.marked(n):
		var field: RefCounted = BodyGroupField.create(n)
		return field.distance(point) if field.valid else NAN
	if EnvelopeField.marked(n):
		var field: RefCounted = EnvelopeField.create(n)
		return field.distance(point) if field.valid else NAN
	if HangingTissue.marked(n):
		var field: RefCounted = HangingTissue.create(n.shape.hanging_tissue, vec(n.size))
		return field.distance(node_basis(n).inverse() * (point - vec(n.position))) if field.valid else INF
	if HangingRoot.marked(n): return HangingRoot.create(n).distance(point)
	if GrownField.marked(n):
		var field: RefCounted = GrownField.create(n.shape.grown_envelope, vec(n.size))
		return field.distance(node_basis(n).inverse()*(point-vec(n.position))) if field.valid else INF
	if MantleField.marked(n):
		var field: RefCounted = MantleField.create(n.shape.mantle_envelope, vec(n.size))
		return field.distance(node_basis(n).inverse()*(point-vec(n.position))) if field.valid else INF
	if GrownContact.marked(n): return GrownContact.create(n).distance(point)
	if MantleButtress.marked(n): return MantleButtress.create(n).distance(point)
	if n.get("kind","")=="curve":
		var pts: Array=n.get("points",[])
		var radii: Array=n.get("radii",[])
		var distance := INF
		for i in range(pts.size()-1):
			var a := vec(pts[i]); var b := vec(pts[i+1]); var ab := b-a
			var t := clampf((point-a).dot(ab)/maxf(ab.length_squared(),0.000001),0.0,1.0)
			distance=minf(distance,point.distance_to(a+ab*t)-lerpf(float(radii[i]),float(radii[i+1]),t))
		return distance
	var size := vec(n.get("size",[1,1,1]))
	var d := node_basis(n).inverse()*(point-vec(n.get("position",[0,0,0])))
	if d.length_squared()<0.000001: return -minf(size.x,minf(size.y,size.z))
	return d.length()-surface_radius(size,d)

static func hanging_surface(n: Dictionary, direction: Vector3) -> Vector3:
	var field: RefCounted = HangingTissue.create(n.shape.hanging_tissue, vec(n.size))
	return vec(n.position) + node_basis(n) * field.surface(direction)

static func hanging_bounds(n: Dictionary) -> AABB:
	if HangingRoot.marked(n): return HangingRoot.create(n).bounds
	var field: RefCounted = HangingTissue.create(n.shape.hanging_tissue, vec(n.size))
	var box: AABB = field.local_bounds; var basis := node_basis(n)
	var world := AABB(vec(n.position) + basis * box.position, Vector3.ZERO)
	for i in range(8):
		world = world.expand(vec(n.position) + basis * (box.position + Vector3(box.size.x if i & 1 else 0.0, box.size.y if i & 2 else 0.0, box.size.z if i & 4 else 0.0)))
	return world

static func grown_surface(n: Dictionary, direction: Vector3) -> Vector3:
	var field: RefCounted = GrownField.create(n.shape.grown_envelope, vec(n.size))
	return vec(n.position)+node_basis(n)*field.surface(direction)

static func grown_bounds(n: Dictionary) -> AABB:
	var field: RefCounted = GrownField.create(n.shape.grown_envelope, vec(n.size))
	var box: AABB = field.local_bounds; var basis := node_basis(n)
	var world := AABB(vec(n.position)+basis*box.position,Vector3.ZERO)
	for i in range(8):
		world = world.expand(vec(n.position)+basis*(box.position+Vector3(box.size.x if i&1 else 0.0,box.size.y if i&2 else 0.0,box.size.z if i&4 else 0.0)))
	return world

static func mantle_marked(n: Dictionary) -> bool:
	return MantleField.marked(n) or MantleButtress.marked(n)

static func mantle_surface(n: Dictionary, t: float, angle: float) -> Vector3:
	var field: RefCounted = MantleField.create(n.shape.mantle_envelope, vec(n.size))
	return vec(n.position)+node_basis(n)*field.surface(t,angle)

static func mantle_ray_surface(n: Dictionary, outward: Vector3, fraction: float = 1.0) -> Vector3:
	var field: RefCounted = MantleField.create(n.shape.mantle_envelope,vec(n.size))
	var direction := node_basis(n).inverse()*outward.normalized()
	var origin: Vector3 = field.centerline(0.5)
	var low := 0.0; var high: float = field.local_bounds.size.length()*1.1
	for i in range(40):
		var mid := (low+high)*0.5
		if field.distance(origin+direction*mid)>0.0: high=mid
		else: low=mid
	return vec(n.position)+node_basis(n)*(origin+direction*((low+high)*0.5)*fraction)

static func mantle_bounds(n: Dictionary) -> AABB:
	if MantleButtress.marked(n): return MantleButtress.create(n).bounds
	var field: RefCounted = MantleField.create(n.shape.mantle_envelope, vec(n.size))
	var box: AABB = field.local_bounds; var basis := node_basis(n)
	var world := AABB(vec(n.position)+basis*box.position,Vector3.ZERO)
	for i in range(8):
		world = world.expand(vec(n.position)+basis*(box.position+Vector3(box.size.x if i&1 else 0.0,box.size.y if i&2 else 0.0,box.size.z if i&4 else 0.0)))
	return world

static func validate(graph: Dictionary) -> Dictionary:
	var errors: Array=[]; var warnings: Array=[]; var seen: Dictionary={}; var roots:=0
	for n in graph.get("nodes",[]):
		var id := str(n.get("id","")); var parent := str(n.get("parent","")); var kind := str(n.get("kind","mass"))
		if id.is_empty() or seen.has(id): errors.append("Empty or duplicate node ID: "+id)
		if parent.is_empty():
			if kind!="cavity": roots+=1
		elif not seen.has(parent): errors.append("Missing or non-topological parent for "+id)
		var size := vec(n.get("size",[0,0,0]))
		var pos := vec(n.get("position",[0,0,0]))
		if not pos.is_finite() or not size.is_finite() or minf(size.x,minf(size.y,size.z))<=0.0: errors.append("Invalid component dimensions: "+id)
		if kind=="curve":
			var points: Array=n.get("points",[]); var radii: Array=n.get("radii",[])
			if points.size()<2 or radii.size()!=points.size(): errors.append("Invalid curve arrays: "+id)
			else:
				for i in range(points.size()):
					if not vec(points[i]).is_finite() or not is_finite(float(radii[i])) or float(radii[i])<=0: errors.append("Invalid curve point: "+id)
					if i>0 and vec(points[i]).distance_squared_to(vec(points[i-1]))<0.000001: errors.append("Zero-length curve segment: "+id)
		if not parent.is_empty() and seen.has(parent) and kind!="cavity":
			var support: Dictionary=seen[parent]
			var own_radius := float(n.get("radius",0.1))
			if kind=="mass": own_radius=surface_radius(size,node_basis(n).inverse()*(vec(support["position"])-pos))
			if distance_to_tissue(support,pos)>own_radius+float(n.get("blend",0.1))*0.8: errors.append("Disconnected attachment: "+id)
		seen[id]=n
	if roots!=1: errors.append("Expected one connected anatomical root, got "+str(roots))
	var linked: Dictionary={}
	for connection in graph.get("connections",[]):
		var child := str(connection.get("to","")); var parent := str(connection.get("from",""))
		if not seen.has(child) or not seen.has(parent): errors.append("Invalid anatomical connection")
		elif str(seen[child].get("parent","")) != parent: errors.append("Connection disagrees with parent: "+child)
		if linked.has(child): errors.append("Duplicate parent connection: "+child)
		linked[child]=true
	for id in seen:
		if not str(seen[id].get("parent","")).is_empty() and not linked.has(id): errors.append("Missing anatomical connection: "+str(id))
	for m in graph.get("modules",[]):
		if not seen.has(str(m.get("parent",""))): errors.append("Missing module parent: "+str(m.get("id","")))
		if not vec(m.get("position",[])).is_finite() or vec(m.get("normal",[])).length_squared()<0.5: errors.append("Invalid module attachment")
		var module_scale := vec(m.get("scale",[1,1,1]))
		if not module_scale.is_finite() or minf(module_scale.x,minf(module_scale.y,module_scale.z)) <= 0.0: errors.append("Invalid module scale")
		if seen.has(str(m.get("parent",""))):
			var seat_depth := distance_to_tissue(seen[m["parent"]],vec(m["position"]))
			if absf(seat_depth) > maxf(module_scale.x,module_scale.y)*0.8: warnings.append("Module seat requires field projection: "+str(m.get("id","")))
	var budget_data: Dictionary=graph.get("budget",DNA.budget(1))
	if seen.size()>int(budget_data["nodes"]): errors.append("Anatomy node budget exceeded")
	if graph.get("modules",[]).size()>int(budget_data["modules"]): errors.append("Module budget exceeded")
	return {"valid":errors.is_empty(),"errors":errors,"warnings":warnings,"node_count":seen.size(),"root_count":roots}

static func repair(source: Dictionary) -> Dictionary:
	var graph := source.duplicate(true)
	var nodes: Array=graph.get("nodes",[])
	var budget_data: Dictionary=graph.get("budget",DNA.budget(1))
	var seen: Dictionary={}; var repaired: Array=[]; var report: Array=[]; var root_id:=""
	# Parent-first generated order lets pruning discard optional descendants safely.
	for original in nodes:
		if repaired.size()>=int(budget_data["nodes"]): break
		var n: Dictionary=original
		var id:=str(n.get("id","n%03d"%repaired.size()))
		if seen.has(id): id+="_"+str(repaired.size()); n["id"]=id
		var parent:=str(n.get("parent",""))
		if repaired.is_empty(): n["parent"]=""; root_id=id
		elif parent.is_empty() or not seen.has(parent):
			n["parent"]=root_id; parent=root_id; report.append("Reattached orphan "+id)
		var s:=vec(n.get("size",[0.1,0.1,0.1]))
		s=Vector3(maxf(absf(s.x),0.035),maxf(absf(s.y),0.035),maxf(absf(s.z),0.035)); n["size"]=arr(s)
		if n.get("kind","")=="curve":
			var points: Array=n.get("points",[]); var radii: Array=n.get("radii",[])
			if points.size()<2: points=[n.get("position",[0,0,0]),arr(vec(n.get("position",[]))+Vector3(0,0.1,0))]
			while radii.size()<points.size(): radii.append(maxf(float(n.get("radius",0.1)),0.035))
			radii.resize(points.size())
			for i in range(points.size()):
				radii[i]=maxf(float(radii[i]),0.004 if n.get("shape",{}).get("geometry","")=="detail" else (0.012 if n.get("role","")=="tendon" else 0.025))
				if i>0 and vec(points[i]).distance_squared_to(vec(points[i-1]))<0.000001: points[i]=arr(vec(points[i-1])+Vector3(0,0.035,0))
			n["points"]=points; n["radii"]=radii; n["position"]=points[0]
		if not str(n["parent"]).is_empty() and n.get("kind","")!="cavity":
			var support: Dictionary=seen.get(n["parent"],{})
			if not support.is_empty():
				var pos:=vec(n["position"]); var own_radius:=float(n.get("radius",0.1))
				if n.get("kind","")=="mass": own_radius=surface_radius(s,node_basis(n).inverse()*(vec(support["position"])-pos))
				if distance_to_tissue(support,pos)>own_radius+float(n.get("blend",0.1))*0.8:
					# Preserve the morphology, connect its attachment with a tendon instead of replacing it.
					if repaired.size()+1<int(budget_data["nodes"]):
						var anchor:=vec(support["position"])
						if support.get("kind","")=="curve": anchor=vec(support["points"][-1])
						var radius:=clampf(own_radius*0.8,0.07,0.35)
						var connector:=Component.make("bridge_"+id,str(n["parent"]),"curve","connection",arr(anchor),[radius,radius,radius],str(n.get("material","flesh")))
						connector["points"]=[arr(anchor),arr(anchor.lerp(pos,0.5)),arr(pos)]; connector["radii"]=[radius,radius*0.85,radius]; connector["radius"]=radius
						repaired.append(connector); seen[connector["id"]]=connector; n["parent"]=connector["id"]
						report.append("Grew connective tissue for "+id)
		seen[id]=n; repaired.append(n)
	graph["nodes"]=repaired
	# Optional secondary-layer links cannot outlive their pruned counterpart.
	for n in repaired:
		for reference_key in ["cavity_id","membrane_to"]:
			if n.has(reference_key) and not seen.has(str(n[reference_key])):
				n.erase(reference_key)
	var modules: Array=[]
	for m in graph.get("modules",[]):
		if modules.size()>=int(budget_data["modules"]): break
		if seen.has(str(m.get("parent",""))): modules.append(m)
	graph["modules"]=modules
	var links: Array=[]
	for n in repaired:
		if not str(n.get("parent","")).is_empty(): links.append(Connection.make(n["parent"],n["id"],str(n.get("connection_kind","growth")),float(n.get("blend",0.1))))
	graph["connections"]=links
	graph["metadata"]["repairs"]=report
	return graph

static func envelope_ray_surface(n: Dictionary, outward: Vector3, fraction: float = 1.0) -> Vector3:
	var field: RefCounted = MassReprofileField.create(n) if MassReprofileField.marked(n) else (BodyGroupField.create(n) if BodyGroupField.marked(n) else EnvelopeField.create(n))
	return field.ray_surface(vec(n.position),outward,fraction) if field.valid else Vector3(NAN,NAN,NAN)

static func envelope_normal(n: Dictionary, point: Vector3) -> Vector3:
	var field: RefCounted = MassReprofileField.create(n) if MassReprofileField.marked(n) else (BodyGroupField.create(n) if BodyGroupField.marked(n) else EnvelopeField.create(n))
	return field.normal(point) if field.valid else Vector3(NAN,NAN,NAN)
