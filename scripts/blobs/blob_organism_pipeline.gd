extends RefCounted
## Staged organism generator with final surface/animation binding. Uses the imported Foundry's indexed implicit
## surface extractor and Catmull-Rom anatomical curves, never its retained mesh.
const Extractor = preload("res://scripts/blobs/blob_stable_extractor.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Blueprint = preload("res://scripts/blobs/blob_blueprint.gd")
const Attachments=preload("res://scripts/blobs/blob_surface_attachments.gd")
const Integrity=preload("res://scripts/blobs/blob_mesh_integrity.gd")
const Frames=preload("res://scripts/blobs/blob_curve_frames.gd")
const Bindings=preload("res://scripts/blobs/blob_deformation_bindings.gd")
const Growth = preload("res://scripts/blobs/blob_anatomical_growth.gd")
const PASS_NAMES = ["Biological blueprint", "Mass composition", "Weight-bearing anatomy", "Primary biology", "Organic integration", "Regional geometry", "Connected anatomy", "Tissue materials"]
const TISSUES = ["flesh", "sac", "sponge", "root", "face", "membrane", "belly", "leg", "cavity", "cartilage", "vein"]
var rng := RandomNumberGenerator.new()
var dna: Dictionary
var features: Array[Dictionary] = []
var stages: Array[Dictionary] = []
var controls: RefCounted
var extraction_offset:=.0

func build(seed_value: int, quality: int = 1, mode: String = "auto", last_pass: int = 7, job: RefCounted = null, options: Dictionary = {}) -> Dictionary:
	controls = job
	extraction_offset=.0
	features.clear()
	stages.clear()
	last_pass = clampi(last_pass, 1, 7)
	dna = Blueprint.plan(seed_value, mode, options)
	rng.seed = ("blob_anatomy_v2:%d" % seed_value).hash()
	dna["quality"] = clampi(quality,0,2)
	_snapshot(0)
	Growth.blockout(self)
	_snapshot(1)
	if last_pass >= 2:
		Growth.development(self)
		_snapshot(2)
	_fit_envelope()
	if last_pass >= 3:
		Growth.primary(self)
		_snapshot(3)
	if last_pass >= 4:
		Growth.integrate(self)
		_snapshot(4)
	if last_pass >= 5:
		if float(dna.controls.detail)>.001: Growth.detail(self)
		_snapshot(5)
	if last_pass >= 6:
		Growth.additional(self)
		_snapshot(6)
	if _cancelled(): return {"cancelled":true}
	Growth.prepare_integrated(self)
	_progress(.2,"Extracting composed anatomy")
	var mesh := _extract(clampi(quality,0,2))
	if mesh.has("cancelled") or mesh.has("error"): return mesh
	_progress(.65,"Blending anatomical tissue fields")
	var body_integrity:=Integrity.clean(mesh,true)
	for attempt in 2:
		if body_integrity.boundary_edges==0 and body_integrity.nonmanifold_edges==0 and body_integrity.inconsistent_edges==0:break
		extraction_offset=float(attempt+1)*.173
		mesh=_extract(clampi(quality,0,2))
		if mesh.has("error") or mesh.get("cancelled",false):return mesh
		body_integrity=Integrity.clean(mesh,true)
	if body_integrity.boundary_edges>0 or body_integrity.nonmanifold_edges>0 or body_integrity.inconsistent_edges>0:return {"error":"Body topology could not be repaired safely","integrity":body_integrity}
	_attribute(mesh,last_pass>=7)
	if _cancelled(): return {"cancelled":true}
	var attachment_surface:=Attachments.new()
	attachment_surface.configure(mesh,float(dna.size))
	var attachment_report:=attachment_surface.finalize(features,float(dna.size))
	if not attachment_report.failures.is_empty(): return {"error":"Attachment validation failed", "attachment_report":attachment_report}
	for f in features:
		if f.has("points") and not f.has("root_color"):
			var seat:=attachment_surface.nearest(f.points[0])
			if not seat.is_empty(): f["root_color"]=seat.color; f["root_tissue"]=seat.tissue
	var appendages: Array[Dictionary] = []
	for f in features:
		if not f.has("points") or f.get("fused_path",false) or f.get("omitted",false): continue
		if _cancelled(): return {"cancelled":true}
		if f.has("parent_along") and features[f.parent].has("binding_curve"):
			var parent_curve:PackedVector3Array=features[f.parent].binding_curve
			var t:=Bindings.closest_parameter(f.points[0],parent_curve)
			var root:=Frames.point(parent_curve,t);var delta:Vector3=root-f.points[0]
			for i in f.points.size():f.points[i]+=delta
			f.center=root;f.parent_along=t
		var detail_mesh: Dictionary
		if f.get("bulb",false): detail_mesh = _bulb(f,last_pass>=7)
		elif f.get("sheet",false): detail_mesh = _sheet(f,last_pass>=7)
		else:
			var curve: Dictionary = Curves.sample({"points":_point_arrays(f.points),"radii":f.radii_profile,"shape":{"swelling":.08,"twist":.0}},5 if quality==0 else 7,true)
			if f.feature_type in ["major_vine","muscular_limb","jointed_limb","sensory_stalk","sensory_sprout","membrane_support"]:
				var source:=PackedVector3Array()
				var start:Vector3=f.points[0];var end:Vector3=f.points[-1]
				var middle:Vector3=f.points[f.points.size()/2]
				if f.points.size()>3:middle=f.points[1]
				for sample in 40:
					var t:=float(sample)/39;source.append(start*(1-t)*(1-t)+middle*(2*t*(1-t))+end*t*t)
				var rest:=Bindings.resample(source,8);f["binding_curve"]=rest
				var points:=PackedVector3Array();var radii:=PackedFloat32Array()
				for row in 50:
					var t:=float(row)/49;points.append(Frames.point(rest,t))
					var u:=t*float(f.radii_profile.size()-1);var index:=mini(int(u),f.radii_profile.size()-2)
					radii.append(lerpf(f.radii_profile[index],f.radii_profile[index+1],u-index))
				for row in points.size():
					var t:=float(row)/float(points.size()-1)
					var before:=Frames.tangent(rest,maxf(0,t-.01));var after:=Frames.tangent(rest,minf(1,t+.01))
					var distance:=Frames.point(rest,minf(1,t+.01)).distance_to(Frames.point(rest,maxf(0,t-.01)))
					var curvature:=before.distance_to(after)/maxf(distance,.00001)
					radii[row]=minf(radii[row],.42/maxf(curvature,.01))
				curve.points=points;curve.radii=radii
			detail_mesh = _tube(curve,f,last_pass>=7)
		if detail_mesh.vertices.is_empty(): continue
		_align_winding(detail_mesh)
		f["mesh_integrity"]=Integrity.clean(detail_mesh)
		if detail_mesh.indices.is_empty() or f.mesh_integrity.boundary_edges>0 or f.mesh_integrity.nonmanifold_edges>0 or f.mesh_integrity.inconsistent_edges>0:
			f["omitted"]=true;f["omission_reason"]="Appendage failed closed-manifold validation";continue
		var local_bounds:=AABB(detail_mesh.vertices[0],Vector3.ZERO)
		for point: Vector3 in detail_mesh.vertices: local_bounds=local_bounds.expand(point)
		f.bounds=local_bounds
		appendages.append({"feature":f,"mesh":detail_mesh})
	if last_pass>=7: _snapshot(7)
	var moment := Vector3.ZERO
	var total_mass := .0
	var rig := {"rolling_axis":Vector3.RIGHT,"contact_zones":[],"active_legs":[],"passive_trailing":[],"roll_coupled":[],"secondary_motion_groups":[],"squish_regions":[],"collision_proxies":[],"cage":dna.envelope,"bone_positions":[]}
	for f in features:
		if f.feature_type=="belly_contact": rig.contact_zones.append(f.id)
		if f.feature_type in ["muscular_limb","jointed_limb"]: rig.active_legs.append(f.id)
		if f.roll_coupling=="drag": rig.passive_trailing.append(f.id)
		if f.roll_coupling=="coupled": rig.roll_coupled.append(f.id)
		if f.tissue=="sac": rig.secondary_motion_groups.append(f.id)
		if f.subtract or f.has("points"): continue
		var mass: float = f.radii.x*f.radii.y*f.radii.z
		moment+=f.center*mass
		total_mass+=mass
		rig.squish_regions.append(f.id)
		if f.pass_created<=2 and f.feature_type!="belly_contact":
			rig.collision_proxies.append({"center":f.center,"radii":f.radii*.83})
			rig.bone_positions.append(f.center)
	dna.center_of_mass = moment/maxf(total_mass,.001)
	rig["center_of_mass"] = dna.center_of_mass
	dna["estimated_mass"] = total_mass*4.0*PI/3.0
	var result := {"dna":dna.duplicate(true),"features":features.duplicate(true),"stages":stages.duplicate(true),"body":mesh,"appendages":appendages,"rig":rig,"descriptor":Blueprint.descriptor(dna)}
	result.rig["obstacle_volumes"]=[]
	for f:Dictionary in features:
		if f.has("points") or f.subtract or f.radii[f.radii.max_axis_index()]<float(dna.size)*.18:continue
		result.rig.obstacle_volumes.append({"center":f.center,"radii":f.radii,"basis":f.get("inverse_basis",Basis.IDENTITY).transposed(),"feature_id":f.id})
	result.rig["attachment_validation"]=attachment_report
	result["finalization"]=Bindings.finalize(result)
	result["mesh_integrity"]=body_integrity
	_progress(.94,"Validating connected anatomy")
	if _cancelled(): return {"cancelled":true}
	result["statistics"] = _statistics(result)
	_progress(1.0,"Anatomy and deformation bindings ready")	
	return result

func build_collection(seeds: Array, quality: int = 0, options: Dictionary = {}, minimum_distance: float = .07) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var descriptors: Array[PackedFloat32Array] = []
	for requested_seed: int in seeds:
		var accepted := requested_seed
		var unique := false
		var attempts := 0
		for attempt in 12:
			attempts=attempt+1
			accepted = requested_seed+attempt*104729
			var candidate: Dictionary = Blueprint.plan(accepted,"auto",options)
			unique = true
			for previous in descriptors:
				if Blueprint.distance(candidate.descriptor,previous)<minimum_distance: unique=false; break
			if unique: break
		if not unique: continue
		var item := build(accepted,quality,"auto",7,null,options)
		item["requested_seed"] = requested_seed
		item["diversity_attempts"] = attempts
		result.append(item)
		descriptors.append(item.descriptor)
	return result

func _fit_envelope() -> void:
	# Fourier control cage sampled from the composed base field. The envelope
	# stays in the body frame while material coordinates circulate around it.
	var r: Vector3 = dna.core_radii
	var coefficients := PackedVector4Array()
	for slice in 9:
		var x := lerpf(-r.x*.98,r.x*.98,float(slice)/8.0)
		var c := Vector4.ZERO
		for ring in 20:
			var angle := TAU*float(ring)/20.0
			var low := .0
			var high := 2.5
			for iteration in 11:
				var mid := (low+high)*.5
				var p := Vector3(x,cos(angle)*r.y*mid,sin(angle)*r.z*mid)
				var distance := INF
				for f in features: distance=minf(distance,_distance(p,f))
				if distance<0: low=mid
				else: high=mid
			c+=Vector4(low,2.0*low*cos(angle),2.0*low*sin(angle),2.0*low*cos(angle*2.0))/20.0
		c.x=maxf(c.x,.12)
		coefficients.append(c)
	dna["envelope"] = coefficients

func _statistics(result: Dictionary) -> Dictionary:
	var triangles: int = result.body.indices.size()/3
	var vertices: int = result.body.vertices.size()
	var types: Dictionary = {}
	for f in features: types[f.feature_type]=int(types.get(f.feature_type,0))+1
	for a: Dictionary in result.appendages:
		triangles+=a.mesh.indices.size()/3
		vertices+=a.mesh.vertices.size()
	return {"triangles":triangles,"vertices":vertices,"features":features.size(),"feature_types":types,"packed_bytes":var_to_bytes(result.body).size()+var_to_bytes(result.appendages).size()}

func _feature(kind: String, parent: int, pass_id: int, center: Vector3, radii: Vector3, tissue: String, subtract: bool = false) -> int:
	var id := features.size()
	features.append({"id": id, "parent": parent, "pass_created": pass_id, "feature_type": kind,
		"center": center, "radii": radii, "bounds": AABB(center - radii, radii * 2.0),
		"influence": {"shape": "ellipsoid", "blend": 0.16 * float(dna.size)},
		"surface_mapping": "body_vertex_feature_ids", "material_category": tissue, "detail_category": tissue,
		"tissue": tissue, "subtract": subtract, "direction": Vector3.UP,
		"locomotion_relevance": "contact" if tissue == "belly" else "passive",
		"roll_coupling": "coupled", "slide_coupling": "deform"})
	return id

func _sheet(f:Dictionary,materials:bool)->Dictionary:
	var mesh:=_empty_mesh()
	mesh["sheet_params"]=PackedVector2Array()
	var left:Dictionary=Curves.sample({"points":_point_arrays(features[f.support_ids[0]].points),"radii":[.01,.01,.01]},8,true)
	var right:Dictionary=Curves.sample({"points":_point_arrays(features[f.support_ids[1]].points),"radii":[.01,.01,.01]},8,true)
	var a_curve:PackedVector3Array=features[f.support_ids[0]].binding_curve;var b_curve:PackedVector3Array=features[f.support_ids[1]].binding_curve
	var rows:=10;var columns:=8;f["sheet_rows"]=rows;f["sheet_columns"]=columns
	f["t_min"]=.15;f["t_max"]=.55;f["thickness"]=float(dna.size)*.008;f["sag"]=float(dna.size)*.025
	var reference:=Vector3.ZERO
	for row in rows+1:
		var t:=lerpf(f.t_min,f.t_max,float(row)/rows);var a:=Frames.point(a_curve,t);var b:=Frames.point(b_curve,t)
		var normal:Vector3=(b-a).cross(Frames.tangent(a_curve,t)+Frames.tangent(b_curve,t)).normalized()
		if row==0:reference=normal
		if a.distance_to(b)>float(dna.size)*1.1 or a.distance_to(b)<float(dna.size)*.06 or normal.dot(reference)<.5:
			f["omitted"]=true;f["omission_reason"]="Incompatible web supports";return mesh
	for layer in 2:
		for row in rows+1:
			var v:=float(row)/rows
			for column in columns+1:
				var u:=float(column)/columns
				var t:float=lerpf(f.t_min,f.t_max,v)-.13*v*4*u*(1-u)
				var a:=Frames.point(a_curve,t);var b:=Frames.point(b_curve,t)
				var n:Vector3=(b-a).cross(Frames.tangent(a_curve,t)+Frames.tangent(b_curve,t)).normalized()
				mesh.sheet_params.append(Vector2(t,u))
				var p:Vector3=a.lerp(b,u)+n*(f.thickness*(1 if layer==0 else -1)-f.sag*sin(v*PI)*4*u*(1-u))
				_append_vertex(mesh,p,n*(1 if layer==0 else -1),f,t,materials)
	var offset: int=(rows+1)*(columns+1)
	for row in rows:
		for column in columns:
			var a:=row*(columns+1)+column;var b:=a+1;var c:=a+columns+1;var d:=c+1
			mesh.indices.append_array(PackedInt32Array([a,c,b,b,c,d,a+offset,b+offset,c+offset,b+offset,d+offset,c+offset]))
	for row in rows:
		for col in [0,columns]:
			var a:int=row*(columns+1)+col;var b:int=a+columns+1
			mesh.indices.append_array(PackedInt32Array([a,b,a+offset,b,b+offset,a+offset]))
	for col in columns:
		for row in [0,rows]:
			var a:int=row*(columns+1)+col;var b:=a+1
			mesh.indices.append_array(PackedInt32Array([a,b,a+offset,b,b+offset,a+offset]))
	return mesh

func _curve_point(points: PackedVector3Array, t: float) -> Vector3:
	var value := t*float(points.size()-1)
	var index := mini(int(value),points.size()-2)
	return points[index].lerp(points[index+1],value-float(index))

func _gaussian(p: Vector2, width: Vector2) -> float:
	return exp(-(p/width).length_squared()*2.0)

func _bulb(f:Dictionary,materials:bool)->Dictionary:
	var mesh:=_empty_mesh();var rows:=12;var sides:=24
	var parent:Dictionary=features[f.parent]
	var axis:Vector3=(parent.points[-1]-parent.points[-2]).normalized()
	var frame:Basis=Growth._frame(axis)
	var base:float=parent.radii_profile[-1]
	var height:float=f.bulb_radii.y*1.8
	var variety:int=int(f.id)%3
	f["root_tissue"]=TISSUES.find(parent.tissue);f["root_color"]=_color(parent.tissue)
	for layer in 2:
		for row in rows+1:
			var t:=float(row)/rows
			var swelling:=sin(t*PI*.9)*(.7 if variety==0 else 1.0)
			var radius:float=base*(1+swelling*2.8)
			if layer==1:radius=maxf(base*.45,radius-base*.3)
			for side in sides:
				var angle:=float(side)/sides*TAU
				var ribs:=1+.08*t*sin(angle*5+t*3)+.035*t*sin(angle*9-t*4)
				var n:Vector3=frame.x*cos(angle)+frame.y*sin(angle)
				var center:Vector3=f.center+axis*height*t+frame.x*height*t*t*.15
				var p:=center+n*radius*ribs
				_append_vertex(mesh,p,n*(1 if layer==0 else -1),f,t,materials)
	var offset: int=(rows+1)*sides
	for row in rows:
		for side in sides:
			var a:=row*sides+side;var b:=row*sides+(side+1)%sides;var c:=a+sides;var d:=b+sides
			mesh.indices.append_array(PackedInt32Array([a,b,c,b,d,c,a+offset,c+offset,b+offset,b+offset,c+offset,d+offset]))
	for row in [0,rows]:
		for side in sides:
			var a:int=row*sides+side;var b:int=row*sides+(side+1)%sides
			mesh.indices.append_array(PackedInt32Array([a,a+offset,b,b,a+offset,b+offset]))
	return mesh

func _direction(angle: float, height: float) -> Vector3:
	return Vector3(cos(angle), height, sin(angle)).normalized()

func _distance(p: Vector3, f: Dictionary) -> float:
	if f.get("fused_path",false):
		var best:=INF
		for i in f.points.size()-1:
			var a:Vector3=f.points[i];var b:Vector3=f.points[i+1];var line:=b-a
			var t:=clampf((p-a).dot(line)/maxf(line.length_squared(),.000001),0,1)
			best=minf(best,p.distance_to(a+line*t)-lerpf(f.radii_profile[i],f.radii_profile[i+1],t))
		return best
	var delta: Vector3 = p - f.center
	if f.get("torus", false):
		var axial: float = delta.dot(f.direction)
		var radial: float = (delta - f.direction * axial).length()
		return Vector2(radial - f.radii.x, axial).length() - f.radii.y
	if f.has("inverse_basis"): delta = f.inverse_basis * delta
	var distance: float=(delta / f.radii).length() * minf(f.radii.x, minf(f.radii.y, f.radii.z)) - minf(f.radii.x, minf(f.radii.y, f.radii.z))
	if f.get("face_relief",false) and delta.z>0:
		var uv:=Vector2(delta.x/f.radii.x,delta.y/f.radii.y)
		var relief:=.0
		for side in [-1.0,1.0]:
			var eye:=Vector2(side*float(f.eye_spacing),.12)
			relief-=.15*_gaussian(uv-eye,Vector2(.25,.14))
			relief+=.11*_gaussian(uv-(eye+Vector2(0,.16)),Vector2(.35,.12))
			relief+=.05*_gaussian(uv-(eye+Vector2(0,-.05)),Vector2(.24,.055))
			relief+=.07*_gaussian(uv-Vector2(side*.52,-.2),Vector2(.3,.25))
			relief-=.055*_gaussian(uv-Vector2(side*.12,-.18),Vector2(.07,.06))
		relief+=.2*_gaussian(uv-Vector2(0,.03),Vector2(.18,float(f.nose_length)*.65))
		relief+=.22*_gaussian(uv-Vector2(0,-.16),Vector2(.23,.14))
		relief-=.11*_gaussian(uv-Vector2(0,-.44),Vector2(.4,.05))
		relief+=.10*_gaussian(uv-Vector2(0,-.51),Vector2(.4,.08))
		relief+=.08*_gaussian(uv-Vector2(0,-.36),Vector2(.39,.07))
		var boundary:=pow(maxf(0.0,1.0-uv.x*uv.x),2.0)*pow(maxf(0.0,1.0-uv.y*uv.y),2.0)
		distance-=relief*float(f.radii.x)*boundary*smoothstep(.0,.65,delta.z/f.radii.z)
	return distance

func _orient(id: int, normal: Vector3) -> void:
	var side := Vector3.UP.cross(normal).normalized()
	if side.length_squared() < 0.1: side = Vector3.RIGHT
	var frame := Basis(side, normal.cross(side).normalized(), normal)
	features[id]["inverse_basis"] = frame.transposed()
	var extent: Vector3 = frame.x.abs() * features[id].radii.x + frame.y.abs() * features[id].radii.y + frame.z.abs() * features[id].radii.z
	features[id].bounds = AABB(features[id].center - extent, extent * 2.0)

func _surface(n: Vector3) -> Vector3:
	var farthest := .0
	for f in features:
		if f.subtract or f.has("points") or f.get("torus",false): continue
		var inverse_frame: Basis = f.get("inverse_basis",Basis.IDENTITY)
		var origin: Vector3 = inverse_frame*(-f.center)/f.radii
		var ray: Vector3 = inverse_frame*n/f.radii
		var a := ray.dot(ray)
		var b := 2.0*origin.dot(ray)
		var c := origin.dot(origin)-1.0
		var discriminant := b*b-4.0*a*c
		if discriminant<0: continue
		farthest=maxf(farthest,(-b+sqrt(discriminant))/(2.0*a))
	return n*farthest

func _snapshot(pass_id: int) -> void:
	stages.append({"pass": pass_id, "label": PASS_NAMES[pass_id], "feature_count": features.size(), "features": features.duplicate(true)})

func _extract(quality: int) -> Dictionary:
	var bounds := AABB(Vector3.ZERO, Vector3.ONE * 0.001)
	for f in features:
		if (not f.has("points") or f.get("fused_path",false)) and not f.subtract: bounds = bounds.merge(f.bounds)
	bounds = bounds.grow(float(dna.size) * 0.3)
	var cell: float = bounds.size[bounds.size.max_axis_index()] / [40.0, 72.0, 108.0][quality]
	bounds.position+=Vector3(.73,.37,.91)*cell*extraction_offset
	var dims := Vector3i(ceil(bounds.size.x / cell), ceil(bounds.size.y / cell), ceil(bounds.size.z / cell)) + Vector3i.ONE
	var values := PackedFloat32Array()
	values.resize(dims.x * dims.y * dims.z)
	values.fill(100.0)
	# Local bounding-box rasterization keeps work proportional to anatomy size.
	# Positive smooth unions finish before subtraction, retaining open throats.
	for field_pass in 3:
		var subtract: bool=field_pass==1
		for f in features:
			if (f.has("points") and not f.get("fused_path",false)) or f.subtract != subtract: continue
			var lining: bool=f.feature_type=="cavity_organ"
			if field_pass==0 and lining: continue
			if field_pass==2 and not lining: continue
			if _cancelled(): return {"cancelled": true}
			var k := maxf(.001,float(dna.size) * (0.018 if subtract else (0.025 if f.get("torus", false) else 0.12*float(dna.controls.fusion))))
			if not subtract and int(f.pass_created)>=4:
				k=minf(k,minf(f.radii.x,minf(f.radii.y,f.radii.z))*.6)
			var box: AABB = f.bounds.grow(k + cell * 2.0)
			var lo := Vector3i((box.position - bounds.position) / cell).max(Vector3i.ZERO)
			var hi := (Vector3i((box.end - bounds.position) / cell) + Vector3i.ONE).min(dims - Vector3i.ONE)
			for z in range(lo.z, hi.z + 1):
				for y in range(lo.y, hi.y + 1):
					for x in range(lo.x, hi.x + 1):
						var p := bounds.position + Vector3(x, y, z) * cell
						var d := _distance(p, f)
						# Local wrinkles only on folded flesh; sacs remain inflated.
						if f.tissue == "flesh" and stages.size() >= 6:
							d += sin(p.y * 18.0 + sin(p.x * 9.0) * 1.8) * 0.007 * float(dna.irregularity)*float(dna.controls.folds)
						var index := x + dims.x * (y + dims.y * z)
						var a := -values[index] if subtract else values[index]
						var h := maxf(k - absf(a - d), 0.0) / k
						var result := minf(a, d) - h * h * k * 0.25
						values[index] = -result if subtract else result
	return Extractor.new().extract(values, dims, bounds.position, cell, controls)

func _attribute(mesh: Dictionary, materials: bool) -> void:
	mesh["colors"] = PackedColorArray()
	mesh["uvs"] = PackedVector2Array()
	mesh["uvs2"] = PackedVector2Array()
	mesh["anchors"] = PackedFloat32Array()
	mesh["mechanics"] = PackedFloat32Array()
	mesh["feature_ids"] = PackedInt32Array()
	var index := 0
	for p: Vector3 in mesh.vertices:
		if index%256==0 and _cancelled(): return
		index+=1
		var nearest := INF
		var second := INF
		var owner: Dictionary = features[0]
		var other: Dictionary = features[0]
		for f in features:
			if f.has("points") and not f.get("fused_path",false): continue
			var distance := absf(_distance(p,f))
			if f.subtract: distance*=.88
			if distance<nearest:
				second=nearest; other=owner; nearest=distance; owner=f
			elif distance<second: second=distance; other=f
		var blend := clampf(.5-(second-nearest)/maxf(float(dna.size)*.16,.001),0.0,.5)
		var color := _color(owner.tissue).lerp(_color(other.tissue),blend)
		mesh.colors.append(color if materials else Color(.36,.32,.26))
		mesh.uvs.append(Vector2(TISSUES.find(owner.tissue),dna.wetness))
		mesh.uvs2.append(Vector2(TISSUES.find(other.tissue),blend))
		mesh.feature_ids.append(owner.id)
		mesh.anchors.append_array(PackedFloat32Array([owner.center.x,owner.center.y,owner.center.z,0.0]))
		mesh.mechanics.append_array(PackedFloat32Array([_stiffness(owner.tissue),0.0,0.0,0.0]))

func _color(tissue: String) -> Color:
	var palettes := [Color(.24,.195,.12),Color(.22,.19,.155),Color(.19,.195,.13),Color(.24,.175,.16),Color(.195,.17,.18)]
	var base: Color = palettes[clampi(int(dna.palette),0,4)]
	match tissue:
		"sac": return base.lightened(.065)
		"sponge": return base.lightened(.025)
		"root": return base.lerp(Color(.16,.105,.075),.32)
		"cavity": return base.darkened(.52)
		"face": return base.lightened(.085)
		"membrane": return base.lerp(Color(.26,.17,.13),.22)
		"belly": return base.darkened(.12)
		"leg": return base.darkened(.04)
		"cartilage": return base.lightened(.12)
		"vein": return base.lerp(Color(.18,.1,.085),.38)
	return base

func _stiffness(tissue: String) -> float:
	return {"face":.85,"cartilage":.9,"sponge":.7,"leg":.6,"sac":.25,"membrane":.1}.get(tissue,.4)

func _empty_mesh() -> Dictionary:
	return {"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"indices":PackedInt32Array(),"colors":PackedColorArray(),"uvs":PackedVector2Array(),"uvs2":PackedVector2Array(),"anchors":PackedFloat32Array(),"mechanics":PackedFloat32Array(),"feature_ids":PackedInt32Array()}

func _append_vertex(mesh: Dictionary, p: Vector3, normal: Vector3, f: Dictionary, t: float, materials: bool) -> void:
	mesh.vertices.append(p)
	mesh.normals.append(normal)
	var blend:=1.0-smoothstep(.0,.32,t)
	var root_color: Color=f.get("root_color",_color(f.tissue))
	mesh.colors.append(root_color.lerp(_color(f.tissue),1.0-blend) if materials else Color(.36,.32,.26))
	mesh.uvs.append(Vector2(TISSUES.find(f.tissue),dna.wetness))
	mesh.uvs2.append(Vector2(float(f.get("root_tissue",TISSUES.find(f.tissue))),blend))
	mesh.feature_ids.append(f.id)
	var freedom: float = f.get("flexibility",0.0)*smoothstep(.0,.8,t)
	mesh.anchors.append_array(PackedFloat32Array([f.center.x,f.center.y,f.center.z,freedom]))
	mesh.mechanics.append_array(PackedFloat32Array([_stiffness(f.tissue),1.0 if f.slide_coupling=="active" else .0,float(f.id%2)*PI,t]))

func _point_arrays(points: Array) -> Array:
	var result: Array = []
	for p: Vector3 in points: result.append([p.x, p.y, p.z])
	return result

func _tube(curve: Dictionary, f: Dictionary, materials: bool) -> Dictionary:
	var mesh := _empty_mesh()
	var points: PackedVector3Array = curve.points
	if f.feature_type in ["vascular_trunk","vascular_branch","capillary","anatomical_fold"]:
		var parent: Dictionary=features[f.parent]
		while parent.has("points") and int(parent.parent)>=0: parent=features[parent.parent]
		var outward: Vector3=parent.direction
		for i in points.size():
			var original: Vector3=points[i]
			var shift:=.0
			var epsilon:=float(dna.size)*.006
			for iteration in 5:
				var point:=original+outward*shift
				var distance:=_positive_field(point)
				var gradient:=(_positive_field(point+outward*epsilon)-_positive_field(point-outward*epsilon))/(epsilon*2.0)
				if absf(gradient)<.15: break
				shift=clampf(shift-distance/gradient,-float(dna.size)*.25,float(dna.size)*.45)
			points[i]=original+outward*(shift+float(curve.radii[i])*.35+.008)
	var sides := 8 if int(dna.quality)==0 else 10
	mesh["centerline"]=points.duplicate()
	mesh["sides"]=sides
	var previous_axis := Vector3.ZERO
	for i in points.size():
		var tangent := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var axis := previous_axis-tangent*previous_axis.dot(tangent)
		if axis.length_squared()<.01:
			axis=tangent.cross(Vector3.UP)
			if axis.length_squared()<.01: axis=tangent.cross(Vector3.RIGHT)
		axis=axis.normalized()
		previous_axis=axis
		var t := float(i)/float(maxi(points.size()-1,1))
		if f.has("binding_curve"):
			var frame:=Frames.frame(f.binding_curve,Frames.normals(f.binding_curve),t)
			axis=frame.x;tangent=frame.z
		for j in sides:
			var angle := float(j)*TAU/float(sides)
			var normal := axis.rotated(tangent,angle)
			var radius:float=curve.radii[i]
			if f.feature_type in ["major_vine","vine_branch","root_curtain","facial_drape"]:radius*=1-.8*smoothstep(.78,1.0,t)
			var organic:=1+.055*sin(angle*3+t*8+float(f.id)) *sin(t*PI)+.035*sin(t*23+float(f.id)) *sin(t*PI)
			var radial := normal*radius*organic
			if f.get("ribbon",false): radial=axis*cos(angle)*float(curve.radii[i])*2.2+tangent.cross(axis)*sin(angle)*float(curve.radii[i])*.3
			_append_vertex(mesh,points[i]+radial,normal,f,t,materials)
			if i<points.size()-1:
				var a := i*sides+j
				var b := i*sides+(j+1)%sides
				mesh.indices.append_array(PackedInt32Array([a,b,a+sides,b,b+sides,a+sides]))
	# Close terminals; cap geometry prevents open black cones at branch tips.
	for end in 2:
		var ring := 0 if end==0 else points.size()-1
		var center_index: int = mesh.vertices.size()
		var tangent := (points[1]-points[0]).normalized() if end==0 else (points[-1]-points[-2]).normalized()
		_append_vertex(mesh,points[ring],-tangent if end==0 else tangent,f,float(end),materials)
		for j in sides:
			var a := ring*sides+j
			var b := ring*sides+(j+1)%sides
			mesh.indices.append_array(PackedInt32Array([center_index,b,a] if end==0 else [center_index,a,b]))
	return mesh

func _positive_field(point: Vector3) -> float:
	var distance:=100.0
	for f in features:
		if f.subtract or (f.has("points") and not f.get("fused_path",false)): continue
		var d:=_distance(point,f)
		var k:=maxf(.001,float(dna.size)*.12*float(dna.controls.fusion))
		if int(f.pass_created)>=4: k=minf(k,minf(f.radii.x,minf(f.radii.y,f.radii.z))*.6)
		var h:=maxf(k-absf(distance-d),0.0)/k
		distance=minf(distance,d)-h*h*k*.25
	return distance

func _cancelled() -> bool:
	return controls != null and controls.is_cancelled()

func _align_winding(mesh: Dictionary) -> void:
	for triangle in range(0,mesh.indices.size(),3):
		var a: int=mesh.indices[triangle]
		var b: int=mesh.indices[triangle+1]
		var c: int=mesh.indices[triangle+2]
		var cross: Vector3=(mesh.vertices[b]-mesh.vertices[a]).cross(mesh.vertices[c]-mesh.vertices[a])
		var normal: Vector3=mesh.normals[a]+mesh.normals[b]+mesh.normals[c]
		if cross.dot(normal)>0:
			mesh.indices[triangle+1]=c
			mesh.indices[triangle+2]=b

func _progress(value: float, message: String) -> void:
	if controls != null: controls.set_progress(value, message)
