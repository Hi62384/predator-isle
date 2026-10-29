extends RefCounted
## V3 authoring-only placement on the unchanged exact buttress tissue field.
## No renderer, extraction quality, camera, or comparison floor is consulted.
const Buttress = preload("res://alien_foundry/scripts/geometry/BlobMantleButtressField.gd")

static func _vec(a: Array) -> Vector3: return Vector3(float(a[0]),float(a[1]),float(a[2]))
static func _arr(p: Vector3) -> Array: return [p.x,p.y,p.z]

static func support_minimum(node: Dictionary) -> Dictionary:
	var field: RefCounted=Buttress.create(node)
	var seeds: Array=[]
	# Each zero must belong to one of these transported ellipsoid sections.
	# Their exact downward support points seed the numerical surface search.
	for s: Dictionary in field.segments:
		for t: float in [0.0,0.5,1.0]:
			var w:=lerpf(float(s.wa),float(s.wb),t)
			var d:=lerpf(float(s.da),float(s.db),t)
			var r:=lerpf(float(s.ra),float(s.rb),t)
			var a: Vector3=s.across;var b: Vector3=s.depth_axis;var c: Vector3=s.axial
			var q:=a*(a.y*w*w)+b*(b.y*d*d)+c*c.y
			var center: Vector3=s.position+s.axis*t
			var low:=center-q*(r/sqrt(maxf(q.y,0.0000001)))
			seeds.append(low)
	seeds.sort_custom(func(a: Vector3,b: Vector3) -> bool:return a.y<b.y)
	var best:=Vector3(0.0,INF,0.0)
	for i in range(mini(6,seeds.size())):
		var p: Vector3=_vertical_surface(field,seeds[i])
		if p.y<best.y:best=p
	var step: float=minf(field.bounds.size.x,field.bounds.size.z)*0.125
	for iteration in range(28):
		var next:=best
		for dx: float in [-1.0,0.0,1.0]:
			for dz: float in [-1.0,0.0,1.0]:
				if dx==0.0 and dz==0.0:continue
				var p:=_vertical_surface(field,best+Vector3(dx*step,0.0,dz*step))
				if p.y<next.y:next=p
		if next.y<best.y-0.0000001:best=next
		else:step*=0.5
		if step<0.00001:break
	return {"minimum_y":best.y,"point":_arr(best),"field_residual":field.distance(best),"horizontal_search_step":step,"method":"exact_field_vertical_roots_then_bounded_horizontal_refinement"}

static func _vertical_surface(field: RefCounted, seed: Vector3) -> Vector3:
	var lower: float=field.bounds.position.y-0.00001
	var upper: float=field.bounds.end.y
	var last:=lower
	var bracket:=INF
	# Scan the full vertical interval: no assumption that a center ray hits.
	for i in range(1,33):
		var y:=lerpf(lower,upper,float(i)/32.0)
		if field.distance(Vector3(seed.x,y,seed.z))<=0.0:bracket=y;break
		last=y
	if not is_finite(bracket):return Vector3(seed.x,INF,seed.z)
	for i in range(25):
		var y: float=(last+bracket)*0.5
		if field.distance(Vector3(seed.x,y,seed.z))<=0.0:bracket=y
		else:last=y
	return Vector3(seed.x,(last+bracket)*0.5,seed.z)

static func seat_contact(node: Dictionary) -> Dictionary:
	var measurement: Dictionary={}
	var shifts: Array=[]
	# Move only the two basal authored controls; root and descending shoulder
	# remain where the actual mantle meridian placed them. This is not a body
	# display offset. Changed control points are authoritative saved geometry.
	for iteration in range(4):
		measurement=support_minimum(node)
		var shift: float=-float(measurement.minimum_y)
		if not is_finite(shift):break
		if absf(shift)<0.00002:break
		for i in [2,3]:node.points[i][1]=float(node.points[i][1])+shift
		shifts.append(shift)
	measurement=support_minimum(node)
	measurement["basal_control_shifts"]=shifts
	return measurement

static func graph_minimum(dna: Dictionary) -> Dictionary:
	var records: Array=[]
	var main: Dictionary=dna.nodes[0]
	var minimum: float=float(main.position[1])-float(main.size[1])
	for node: Dictionary in dna.nodes:
		if not Buttress.marked(node):continue
		var record:=support_minimum(node)
		record["id"]=node.id;records.append(record)
		minimum=minf(minimum,float(record.minimum_y))
	return {"minimum_y":minimum,"support_contacts":records,"target_clearance":0.035,"method":"authoritative_tissue_minimum_not_conservative_AABB","numerical_not_global_distance_proof":true}
