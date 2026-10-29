extends RefCounted
## Fixed203 qualification, not an evaluator, profile search, mesher or art gate.
## Requalifies the complete old geometric proximal closures in the CHANGED host.
## The 1,632 closure and 15 valley points are generated only by exact202 fields.
## Neither a full-H proximal halo nor global smooth-union regularity is claimed.
const C = preload("res://alien_foundry/scripts/geometry/BlobEnvelope201Certificate.gd")
const Q202 = preload("res://alien_foundry/scripts/geometry/BlobBodyGroup202Qualification.gd")
const SLICES := 64
const CLOSURE_COUNT := 1632
const VALLEY_COUNT := 15

static func _same_coordinates(a: RefCounted,b: RefCounted) -> bool:
	return a.origin==b.origin and a.frame==b.frame and a.inverse_frame==b.inverse_frame and a.length_scale==b.length_scale and a.caps==b.caps

static func geometric_closure(host: RefCounted,branch: RefCounted) -> Dictionary:
	if not host.valid or not branch.valid or not _same_coordinates(branch,branch.base):
		return {"ok":false,"reason":"Unqualified203 carrier or changed protected closure coordinates."}
	var root: float=branch.base.caps[0][0]
	# Exactly the202 local hemisphere box, spatial allowance and binary32
	# preimage/forward transforms. This is NOT a positive raw-sublevel enclosure.
	var margin: float=32.0*C.U32*maxf(1.0,root)
	var preimage: Dictionary=C.preimage_box(branch.base,[-root-margin,-root-margin,-root-margin],[root+margin,root+margin,margin])
	if not preimage.ok: return {"ok":false,"reason":"Original root preimage enclosure failed."}
	var local: Dictionary=Q202._forward_local_box(host,preimage.box)
	if not local.ok: return {"ok":false,"reason":"Changed host local enclosure failed."}
	var low: Array=local.low; var high: Array=local.high
	for axis in range(3):
		if low[axis]<float(host.support_low[axis]) or high[axis]>float(host.support_high[axis]):
			return {"ok":false,"reason":"Complete closure enclosure exceeds changed host bounded support.","host_local_low":low,"host_local_high":high}
	# Split at the old0/.5/1 sections AND every new cut, belly and pole. The
	# wrapper also splits directed endpoints that straddle a join by rounding.
	var divisions: Array=[float(low[2]),float(high[2])]
	var breaks: Array=host.axial_breakpoints()
	for z_value: Variant in [0.0,0.5,1.0]+breaks:
		var z: float=float(z_value)
		if not is_finite(z): return {"ok":false,"reason":"Nonfinite203 profile breakpoint."}
		if z>float(low[2]) and z<float(high[2]) and z not in divisions: divisions.append(z)
	divisions.sort()
	var upper: float=-INF; var intervals:=0
	for piece in range(divisions.size()-1):
		var za: float=divisions[piece]; var zb: float=divisions[piece+1]
		if zb<=za: continue
		for j in range(SLICES):
			var z0: Array=C.add(C.point(za),C.mul(C.sub(C.point(zb),C.point(za)),C.point(float(j)/float(SLICES))))
			var z1: Array=C.add(C.point(za),C.mul(C.sub(C.point(zb),C.point(za)),C.point(float(j+1)/float(SLICES))))
			var result: Array=host.raw_local_interval(low,high,[z0[0],z1[1]])
			if not C.finite(result):
				return {"ok":false,"reason":"Changed host fixed raw interval inconclusive.","z_interval":[z0[0],z1[1]],"host_local_low":low,"host_local_high":high}
			upper=maxf(upper,float(result[1])); intervals+=1
	return {"ok":intervals>0 and upper<0.0,"host_raw_upper":upper,"fixed_axial_intervals":intervals,"axial_subdivisions_per_piece":SLICES,"axial_piece_boundaries":divisions,"root_normalized_radius":root,"root_spatial_margin":margin,"host_local_low":low,"host_local_high":high,"changed_host_evaluator":true,"scope":"Entire original geometric proximal hemisphere plus unchanged numerical allowance; not the full-H halo."}

static func _weights_ok(weights: Variant,count: int) -> bool:
	if not weights is Array or weights.size()!=count: return false
	var total:=0.0
	for weight: Variant in weights:
		if not is_finite(float(weight)) or float(weight)<0.0 or float(weight)>1.0: return false
		total+=float(weight)
	return absf(total-1.0)<0.00001

static func _composition(group: RefCounted,point: Vector3,sample: Dictionary,host_value: float,branch_values: Array) -> Dictionary:
	# Recompute actual ordered202 smooth-min coefficients, not invented
	# per-member distances. The host regional split is the original201 law.
	var coefficients: Array=[1.0,0.0,0.0,0.0]
	var value: float=host_value
	if not is_finite(value) or branch_values.size()!=3:
		return {"ok":false,"ordered_weights_match":false,"host_partition_unchanged":false,"ordered_value_match":false}
	for i in range(3):
		var other: float=branch_values[i]
		var k: float=group.branches[i].blend
		if not is_finite(other) or not is_finite(k) or k<=0.0:
			return {"ok":false,"ordered_weights_match":false,"host_partition_unchanged":false,"ordered_value_match":false}
		var h: float=clampf(0.5+0.5*(other-value)/k,0.0,1.0)
		value=lerpf(other,value,h)-k*h*(1.0-h)
		for j in range(i+1): coefficients[j]=float(coefficients[j])*h
		coefficients[i+1]=1.0-h
	var regional: Vector2=group.host.weights(point)
	var old_regional: Vector2=group.baseline.host.weights(point)
	var expected: Array=[coefficients[0]*regional.x,coefficients[0]*regional.y,coefficients[1],coefficients[2],coefficients[3]]
	var partition_ok: bool=regional.is_finite() and old_regional.is_finite() and regional==old_regional
	var weights_ok: bool=_weights_ok(sample.get("weights"),5) and _weights_ok(sample.get("carrier_weights"),4) and sample.weights==expected and sample.carrier_weights==coefficients
	var value_ok: bool=is_finite(float(sample.get("distance",NAN))) and float(sample.distance)==value
	return {"ok":partition_ok and weights_ok and value_ok,"ordered_weights_match":weights_ok,"host_partition_unchanged":partition_ok,"ordered_value_match":value_ok}

static func _historical_full_halo(baseline: RefCounted) -> Dictionary:
	# Preserve the exact rejected202 witness using baseline fields only. A
	# changed203 evaluation here would erase the meaning of this historical test.
	var point: Vector3=baseline.host.surface(0.375,PI/2.0)+baseline.host.frame.y*0.0001
	var branch: RefCounted=baseline.branches[1]
	var local: Vector3=branch.inverse_frame*(point-branch.origin)/branch.length_scale
	var raw: float=branch.raw_value_gradient(point).w
	var host_value: float=baseline.host.distance(point)
	return {"required":false,"historical_baseline":"exact202","point":[point.x,point.y,point.z],"branch_id":branch.owner_id,"branch_local_z":local.z,"branch_raw":raw,"branch_value":branch.distance(point),"inside_branch_support":not branch._outside_support(point),"halo":baseline.halo,"host_value":host_value,"strict_counterexample":local.z<=0.0 and raw<baseline.halo and host_value>0.0,"claim":"Historical202 full-H proximal halo failure only; not a203 geometry or visual-seam gate."}

static func evaluate(group: RefCounted) -> Dictionary:
	var failures: Array=[]; var closures: Array=[]; var closure_witnesses: Array=[]; var valley: Array=[]
	var baseline: RefCounted=group.baseline
	if baseline==null or not baseline.valid or group.branches.size()!=3 or baseline.branches.size()!=3 or group.member_ids.size()!=5 or group.member_ids!=baseline.member_ids:
		return {"ok":false,"error":"203 qualification requires exact202 baseline, three branches and the same five identities.","failures":["Missing exact baseline or carrier identities."]}
	if not group.host.valid or not _same_coordinates(group.host,baseline.host) or group.host.base!=baseline.host or group.halo!=baseline.halo or group.blend!=baseline.blend:
		return {"ok":false,"error":"203 changed protected host coordinates, baseline reference or actual union context.","failures":["Protected host or actual union context changed."]}
	if group.CLOSURE_AXIAL_STEPS!=16 or group.CLOSURE_ANGLE_STEPS!=32 or group.VALLEY_Z!=baseline.VALLEY_Z or group.VALLEY_ANGLES!=baseline.VALLEY_ANGLES:
		return {"ok":false,"error":"203 fixed202 witness stencil changed.","failures":["Original closure/valley stencil changed."]}
	var components: Array=[{"carrier":"host","qualification":group.host.qualification}]
	var crown_pass: bool=bool(group.host.qualification.get("crown_heuristic_pass",false))
	for branch_index in range(3):
		var branch: RefCounted=group.branches[branch_index]
		var original: RefCounted=baseline.branches[branch_index]
		if not branch.valid or not _same_coordinates(branch,original) or branch.base!=original or branch.owner_id!=original.owner_id or branch.blend!=original.blend or branch.halo!=original.halo:
			return {"ok":false,"error":"203 changed protected branch coordinates, baseline reference or ordered union blend.","failures":["Protected branch or actual union context changed: "+str(original.owner_id)]}
		components.append({"carrier":branch.owner_id,"qualification":branch.qualification})
		crown_pass=crown_pass and bool(branch.qualification.get("crown_heuristic_pass",false))
		var certificate: Dictionary=geometric_closure(group.host,branch)
		certificate["id"]=branch.owner_id; closures.append(certificate)
		if not certificate.ok: failures.append("Entire geometric proximal closure enclosure failed in changed host: "+str(branch.owner_id))
		var root: float=original.caps[0][0]
		for axial in range(17):
			var z: float=-root+root*float(axial)/16.0
			for angular in range(32):
				var angle: float=TAU*float(angular)/32.0
				var point: Vector3=original.surface(z,angle)
				var sample: Dictionary=group.sample(point,true)
				var host_value: float=group.host.distance(point)
				var values: Array=[]
				for other: RefCounted in group.branches: values.append(other.distance(point))
				var branch_value: float=values[branch_index]
				var original_value: float=original.distance(point)
				var unchanged: bool=point==branch.surface(z,angle) and is_finite(original_value) and branch_value==original_value and branch.raw_value_gradient(point)==original.raw_value_gradient(point)
				var composition: Dictionary=_composition(group,point,sample,host_value,values)
				var okay: bool=point.is_finite() and is_finite(host_value) and host_value<0.0 and is_finite(branch_value) and is_finite(float(sample.get("distance",NAN))) and float(sample.distance)<0.0 and unchanged and composition.ok
				if not okay: failures.append("Original fixed actual-composition closure witness failed: %s/%s/%s" % [branch.owner_id,axial,angular])
				closure_witnesses.append({"id":branch.owner_id,"axial":axial,"angular":angular,"point":[point.x,point.y,point.z],"host_value":host_value,"branch_value":branch_value,"baseline_branch_value":original_value,"protected_branch_unchanged":unchanged,"group_value":sample.get("distance",NAN),"regional_weights":sample.get("weights",[]),"carrier_weights":sample.get("carrier_weights",[]),"composition":composition,"ok":okay})
	var tolerance: float=baseline.host.ROUNDING*baseline.host.length_scale*8.0
	for z_value: Variant in baseline.VALLEY_Z:
		for angle_value: Variant in baseline.VALLEY_ANGLES:
			var point: Vector3=baseline.host.surface(float(z_value),float(angle_value))
			var original_value: float=baseline.host.distance(point)
			var host_value: float=group.host.distance(point)
			var sample: Dictionary=group.sample(point,true)
			var values: Array=[]; var excluded: bool=_weights_ok(sample.get("carrier_weights"),4) and _weights_ok(sample.get("weights"),5)
			for i in range(3):
				var branch_value: float=group.branches[i].distance(point)
				values.append(branch_value)
				if not is_finite(branch_value) or not excluded: excluded=false
				elif float(sample.carrier_weights[i+1])!=0.0 or float(sample.weights[i+2])!=0.0: excluded=false
			var local: Vector3=baseline.host.inverse_frame*(point-baseline.host.origin)/baseline.host.length_scale
			var protected: bool=local.z>=0.25 and local.z<=0.75
			var nominal_endpoint: bool=float(z_value)==0.25 or float(z_value)==0.75
			var endpoint_rounding: bool=not protected and nominal_endpoint and absf(float(local.z)-float(z_value))*baseline.host.length_scale<=tolerance
			var exact_value: bool=is_finite(original_value) and host_value==original_value
			# The ORIGINAL world-space endpoint can round outside the protected
			# local interval. Do not move the point or widen the evaluator cut.
			# Reuse only the existing201 spatial residual in that explicit case.
			var unchanged: bool=exact_value if protected else endpoint_rounding and is_finite(original_value) and is_finite(host_value) and absf(host_value-original_value)<=tolerance
			var composition: Dictionary=_composition(group,point,sample,host_value,values)
			var okay: bool=point.is_finite() and is_finite(host_value) and absf(host_value)<=tolerance and unchanged and is_finite(float(sample.get("distance",NAN))) and absf(float(sample.distance)-host_value)<=tolerance and excluded and composition.ok
			if not okay: failures.append("Original fixed upper-valley witness changed: %s/%s" % [z_value,angle_value])
			valley.append({"z":z_value,"angle":angle_value,"point":[point.x,point.y,point.z],"actual_host_local_z":local.z,"actual_local_protected":protected,"endpoint_outside_by_rounding":endpoint_rounding,"host_comparison_disposition":"exact_protected_value" if protected else ("original_endpoint_existing201_spatial_residual" if endpoint_rounding else "outside_protected_domain_rejected"),"existing201_spatial_tolerance":tolerance,"baseline_host_value":original_value,"host_value":host_value,"host_value_exactly_equal":exact_value,"protected_host_value_unchanged":protected and exact_value,"host_preservation_check_pass":unchanged,"host_value_residual":host_value-original_value,"branch_values":values,"group_value":sample.get("distance",NAN),"regional_weights":sample.get("weights",[]),"carrier_weights":sample.get("carrier_weights",[]),"all_branches_excluded":excluded,"composition":composition,"ok":okay})
	if closure_witnesses.size()!=CLOSURE_COUNT or valley.size()!=VALLEY_COUNT: failures.append("Fixed202 witness counts changed.")
	return {"ok":failures.is_empty(),"error":"Fixed203 changed-host geometric closure or original finite actual-composition/valley qualification failed; no fallback." if not failures.is_empty() else "","failures":failures,"component_qualifications":components,"geometric_closure_certificates":closures,"closure_actual_composition_witnesses":closure_witnesses,"closure_witness_count":closure_witnesses.size(),"valley_witnesses":valley,"valley_witness_count":valley.size(),"witness_point_source":"exact202 baseline evaluators","full_halo_counterexample":_historical_full_halo(baseline),"crown_heuristic_pass":crown_pass,"crown_heuristic_required_for_geometry":false,"closure_valley_qualification_ok":failures.is_empty(),"support_root_checks_included":false,"finite_witnesses_only":true,"positive_halo_burial_proved":false,"global_C2_union_claimed":false,"visual_seam_acceptance":false,"anatomical_acceptance":false,"host_evaluator_unchanged":false,"protected_calls_checked_at_original_witnesses":true}
