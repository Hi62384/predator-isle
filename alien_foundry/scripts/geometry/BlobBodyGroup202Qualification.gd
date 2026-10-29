extends RefCounted
## Fixed202 qualification only. No scalar field evaluator, mesher, search, or profile change.
## Certifies a finite box enclosing the complete literal proximal hemisphere.
## Does NOT certify the rejected full-H positive halo or final smooth-union seams.
const C = preload("res://alien_foundry/scripts/geometry/BlobEnvelope201Certificate.gd")
const SLICES := 64

static func _forward_local_box(host: RefCounted, box: AABB) -> Dictionary:
	var delta: Array=[]
	for k in range(3): delta.append(C.round32(C.sub([float(box.position[k]),float(box.end[k])],C.point(float(host.origin[k])))))
	var g5: float=C.div(C.point(5.0*C.U32),C.sub(C.point(1.0),C.point(5.0*C.U32)))[1]
	var g2: float=C.div(C.point(2.0*C.U32),C.sub(C.point(1.0),C.point(2.0*C.U32)))[1]
	var length32:=float(PackedFloat32Array([host.length_scale])[0])
	if length32<=0.0: return {"ok":false}
	var lo: Array=[]; var hi: Array=[]
	for row in range(3):
		var exact:=C.point(0.0); var magnitude:=C.point(0.0)
		for col in range(3):
			var term:=C.mul(C.point(float(host.inverse_frame[col][row])),delta[col])
			exact=C.add(exact,term); magnitude=C.add(magnitude,C.point(C.maximum_abs(term)))
		var error: float=C.add(C.mul(C.point(g5),magnitude),C.point(8.0*C.TINY32))[1]
		var scaled:=C.div(C.add(exact,[-error,error]),C.point(length32))
		# Covers direct division and reciprocal-multiply Vector3 implementations.
		var division_error: float=C.add(C.mul(C.point(g2),C.point(C.maximum_abs(scaled))),C.point(4.0*C.TINY32))[1]
		var interval:=C.add(scaled,[-division_error,division_error])
		if not C.finite(interval): return {"ok":false}
		lo.append(interval[0]); hi.append(interval[1])
	return {"ok":true,"low":lo,"high":hi}

static func _raw_interval(host: RefCounted,low: Array,high: Array,z: Array,piece: int) -> Array:
	var t:=C.div(C.sub(z,C.point(host.midpoint)),C.point(host.half_span))
	var px: Array; var py: Array; var cx:=C.point(0.0); var cy:=C.point(0.0)
	if piece==0 or piece==3:
		var index:=0 if piece==0 else 1
		var r: float=host.caps[index][0]
		var numerator:=C.sub(C.point(1.0+float(host.caps[1][0])),z) if piece==0 else C.add(z,C.point(float(host.caps[0][0])))
		var denominator:=C.sub(C.point(r),z) if piece==0 else C.add(C.sub(z,C.point(1.0)),C.point(r))
		var factor: float=r*r/(host.half_span*host.half_span)
		px=C.div(C.mul(C.point(factor/pow(float(host.caps[index][2]),2.0)),numerator),denominator)
		py=C.div(C.mul(C.point(factor/pow(float(host.caps[index][1]),2.0)),numerator),denominator)
	else:
		var span:=piece-1
		var tt:=C.mul(C.sub(z,C.point(float(span)*0.5)),C.point(2.0))
		tt=[maxf(tt[0],0.0),minf(tt[1],1.0)]
		var values: Array=[]
		for i in range(4): values.append(C.round32(C.poly(host.profiles[i][span],tt)))
		var a:=C.mul(C.add(values[0],values[1]),C.point(0.5)); var b:=C.mul(C.add(values[2],values[3]),C.point(0.5))
		cx=C.mul(C.sub(values[2],values[3]),C.point(0.5)); cy=C.mul(C.sub(values[0],values[1]),C.point(0.5))
		var q:=C.sub(C.point(1.0),C.square(t))
		px=C.div(q,C.square(b)); py=C.div(q,C.square(a))
	if not C.finite(px) or not C.finite(py) or px[0]<=0.0 or py[0]<=0.0: return [-INF,INF]
	var x:=C.sub([low[0],high[0]],cx); var y:=C.sub([low[1],high[1]],cy)
	return C.round32(C.mul(C.point(host.raw_scale*0.5),C.sub(C.add(C.add(C.square(t),C.mul(C.mul(px,x),x)),C.mul(C.mul(py,y),y)),C.point(1.0))))

static func geometric_closure(host: RefCounted,branch: RefCounted) -> Dictionary:
	if not host.valid: return {"ok":false,"reason":"Unqualified unchanged host."}
	var root: float=branch.caps[0][0]
	# Contains literal proximal hemisphere, not only its equator/center.
	# Small outward spatial allowance is explicit, not a positive-halo claim.
	var margin: float=32.0*C.U32*maxf(1.0,root)
	var preimage:=C.preimage_box(branch,[-root-margin,-root-margin,-root-margin],[root+margin,root+margin,margin])
	if not preimage.ok: return {"ok":false,"reason":"Root preimage enclosure failed."}
	var local:=_forward_local_box(host,preimage.box)
	if not local.ok: return {"ok":false,"reason":"Host local enclosure failed."}
	var low: Array=local.low; var high: Array=local.high
	for k in range(3):
		if low[k]<host.support_low[k] or high[k]>host.support_high[k]: return {"ok":false,"reason":"Complete closure enclosure exceeds actual bounded host support."}
	for axis in range(3):
		if low[axis]<float(host.support_low[axis]) or high[axis]>float(host.support_high[axis]): return {"ok":false,"reason":"Closure enclosure leaves unchanged host bounded support."}
	var domains := [[low[2],minf(high[2],0.0)],[maxf(low[2],0.0),minf(high[2],0.5)],[maxf(low[2],0.5),minf(high[2],1.0)],[maxf(low[2],1.0),high[2]]]
	var upper: float=-INF; var intervals:=0
	for piece in range(4):
		var za: float=domains[piece][0]; var zb: float=domains[piece][1]
		if zb<=za: continue
		for j in range(SLICES):
			var z0:=C.add(C.point(za),C.mul(C.sub(C.point(zb),C.point(za)),C.point(float(j)/SLICES)))
			var z1:=C.add(C.point(za),C.mul(C.sub(C.point(zb),C.point(za)),C.point(float(j+1)/SLICES)))
			var result:=_raw_interval(host,low,high,[z0[0],z1[1]],piece)
			if not C.finite(result): return {"ok":false,"reason":"Fixed host interval inconclusive."}
			upper=maxf(upper,result[1]); intervals+=1
	return {"ok":intervals>0 and upper<0.0,"host_raw_upper":upper,"fixed_axial_intervals":intervals,"root_normalized_radius":root,"root_spatial_margin":margin,"host_local_low":low,"host_local_high":high,"scope":"Entire geometric proximal hemisphere plus numerical allowance only; no full-H halo claim."}


static func _weights_ok(weights: Array) -> bool:
	var total:=0.0
	for weight: Variant in weights:
		if not is_finite(float(weight)) or float(weight)<0.0 or float(weight)>1.0: return false
		total+=float(weight)
	return absf(total-1.0)<0.00001

static func evaluate(group: RefCounted) -> Dictionary:
	var closures: Array=[]; var closure_witnesses: Array=[]; var valley: Array=[]
	var failures: Array=[]
	for branch_index in range(group.branches.size()):
		var branch: RefCounted=group.branches[branch_index]
		var certificate:=geometric_closure(group.host,branch)
		certificate["id"]=branch.owner_id; closures.append(certificate)
		if not certificate.ok: failures.append("Entire geometric proximal closure enclosure failed: "+str(branch.owner_id))
		var root: float=branch.caps[0][0]
		for axial in range(group.CLOSURE_AXIAL_STEPS+1):
			var z: float=-root+root*float(axial)/float(group.CLOSURE_AXIAL_STEPS)
			for angular in range(group.CLOSURE_ANGLE_STEPS):
				var angle: float=TAU*float(angular)/float(group.CLOSURE_ANGLE_STEPS)
				var point: Vector3=branch.surface(z,angle)
				var sample: Dictionary=group.sample(point,true)
				var host_value: float=group.host.distance(point)
				var branch_value: float=branch.distance(point)
				var okay:=point.is_finite() and is_finite(host_value) and host_value<0.0 and is_finite(branch_value) and is_finite(float(sample.distance)) and float(sample.distance)<0.0 and _weights_ok(sample.weights)
				if not okay: failures.append("Fixed actual-composition closure witness failed: %s/%s/%s" % [branch.owner_id,axial,angular])
				closure_witnesses.append({"id":branch.owner_id,"axial":axial,"angular":angular,"point":[point.x,point.y,point.z],"host_value":host_value,"branch_value":branch_value,"group_value":sample.distance,"regional_weights":sample.weights,"carrier_weights":sample.carrier_weights,"ok":okay})
	var tolerance: float=group.host.ROUNDING*group.host.length_scale*8.0
	for z_value: Variant in group.VALLEY_Z:
		for angle_value: Variant in group.VALLEY_ANGLES:
			var point: Vector3=group.host.surface(float(z_value),float(angle_value))
			var host_value: float=group.host.distance(point)
			var sample: Dictionary=group.sample(point,true)
			var values: Array=[]; var excluded:=true
			for i in range(group.branches.size()):
				var branch_value: float=group.branches[i].distance(point)
				values.append(branch_value)
				if not is_finite(branch_value) or float(sample.carrier_weights[i+1])!=0.0: excluded=false
			var okay:=point.is_finite() and is_finite(host_value) and absf(host_value)<=tolerance and is_finite(float(sample.distance)) and absf(float(sample.distance)-host_value)<=tolerance and _weights_ok(sample.weights) and excluded
			if not okay: failures.append("Fixed upper-valley witness changed: %s/%s" % [z_value,angle_value])
			valley.append({"z":z_value,"angle":angle_value,"point":[point.x,point.y,point.z],"host_value":host_value,"branch_values":values,"group_value":sample.distance,"regional_weights":sample.weights,"carrier_weights":sample.carrier_weights,"all_branches_excluded":excluded,"ok":okay})
	# Preserve, but do not turn into an approved gate, the rejected stronger
	# full-H proximal-sublevel requirement. This does not prove a visible seam.
	var rejected_point: Vector3=group.host.surface(0.375,PI/2.0)+group.host.frame.y*0.0001
	var rejected_branch: RefCounted=group.branches[1]
	var rejected_local: Vector3=rejected_branch.inverse_frame*(rejected_point-rejected_branch.origin)/rejected_branch.length_scale
	var rejected_raw: float=rejected_branch.raw_value_gradient(rejected_point).w
	var rejected_host: float=group.host.distance(rejected_point)
	var full_halo_diagnostic: Dictionary={"required":false,"point":[rejected_point.x,rejected_point.y,rejected_point.z],"branch_id":rejected_branch.owner_id,"branch_local_z":rejected_local.z,"branch_raw":rejected_raw,"branch_value":rejected_branch.distance(rejected_point),"inside_branch_support":not rejected_branch._outside_support(rejected_point),"halo":group.halo,"host_value":rejected_host,"strict_counterexample":rejected_local.z<=0.0 and rejected_raw<group.halo and rejected_host>0.0,"claim":"Full-H proximal halo burial is not claimed or required by this approved finite-witness gate."}
	return {"ok":failures.is_empty(),"error":"Fixed202 geometric closure or finite actual-composition/valley qualification failed; no fallback." if not failures.is_empty() else "","failures":failures,"geometric_closure_certificates":closures,"closure_actual_composition_witnesses":closure_witnesses,"valley_witnesses":valley,"full_halo_counterexample":full_halo_diagnostic,"finite_witnesses_only":true,"positive_halo_burial_proved":false,"global_C2_union_claimed":false,"visual_seam_acceptance":false,"host_evaluator_unchanged":true}
