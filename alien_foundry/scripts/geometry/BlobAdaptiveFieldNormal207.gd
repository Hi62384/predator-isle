extends RefCounted
##207 bounded complete-field convergence; never a local normal patch or projection.
const SETTING:="blob_isosurface_normal_mode"
const MODE:="adaptive_field_gradient_v1"
const OFF:="off"
const PIN:="0f46bcdbc7e1e445ac5516447a1dce6bd81ee4ed0ac507eaaeb2def62349a10f"
const START_FRACTION:=0.05
const LEVELS:=8
const ANGLE_DEGREES:=0.25
const REQUIRED_CONSECUTIVE:=2
const MAX_QUERIES:=4020000
const MAX_QUERIES_PER_EDGE:=67
static func selection(options: Dictionary)->Dictionary:
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String or mode not in [OFF,MODE]:return {"error":"Invalid explicit207 normal policy."}
	if mode==MODE and options.get("blob_isosurface_refinement_mode")!="bracketed_field_edges_v1":return {"error":"207 requires the explicit204 bracketed edge mode."}
	return {"mode":mode}
static func validate(dna: Dictionary)->Dictionary:
	if not dna.get("settings",{}) is Dictionary:return {"ok":false,"error":"207 requires dictionary settings."}
	var selected:=selection(dna.get("settings",{}))
	if selected.has("error"):return {"ok":false,"error":selected.error}
	if selected.mode==OFF:return {"ok":true}
	if not dna.get("metadata",{}) is Dictionary or dna.get("type")!="Blob" or int(dna.metadata.get("iteration_index",0))<2:return {"ok":false,"error":"207 applies only to developed Blob stages."}
	return {"ok":true}
static func angle(a: Vector3,b: Vector3)->float:
	return rad_to_deg(acos(clampf(a.normalized().dot(b.normalized()),-1.0,1.0)))
static func offsets_valid(point: Vector3,epsilon: float)->bool:
	if not point.is_finite() or not is_finite(epsilon) or epsilon<=0.0:return false
	for axis in range(3):
		var delta:=Vector3.ZERO;delta[axis]=epsilon
		var plus:=point+delta;var minus:=point-delta
		if not plus.is_finite() or not minus.is_finite() or plus[axis]<=point[axis] or minus[axis]>=point[axis]:return false
	return true
static func refine(point: Vector3,cell: float,initial_gradient: Vector3,query: Callable)->Dictionary:
	var result:={"ok":false,"error":"","levels":1,"additional_queries":0,"angles":[],"consecutive":0}
	var epsilon: float=START_FRACTION*cell
	if not query.is_valid() or not offsets_valid(point,epsilon) or not initial_gradient.is_finite() or not is_finite(initial_gradient.length()) or initial_gradient.length()<=0.0:
		result.error="207 degenerate initial complete-field gradient or unrepresentable offsets.";return result
	var previous:=initial_gradient.normalized()
	for level in range(1,LEVELS):
		epsilon*=0.5
		if not offsets_valid(point,epsilon):result.error="207 binary32 offset stagnation; no fallback.";return result
		var gradient:=Vector3.ZERO
		for axis in range(3):
			var delta:=Vector3.ZERO;delta[axis]=epsilon
			var plus: Variant=query.call(point+delta);result.additional_queries+=1
			var minus: Variant=query.call(point-delta);result.additional_queries+=1
			if not (plus is float or plus is int) or not (minus is float or minus is int) or not is_finite(float(plus)) or not is_finite(float(minus)):
				result.error="207 nonfinite complete-field normal query; no fallback.";return result
			gradient[axis]=(float(plus)-float(minus))/(2.0*epsilon)
		result.levels=level+1
		var length: float=gradient.length()
		if not gradient.is_finite() or not is_finite(length) or length<=0.0:result.error="207 degenerate complete-field gradient; no fallback.";return result
		var normal:=gradient/length;var change:=angle(previous,normal)
		if not is_finite(change):result.error="207 nonfinite normal convergence angle.";return result
		result.angles.append(change)
		result.consecutive=int(result.consecutive)+1 if change<=ANGLE_DEGREES else 0
		if int(result.consecutive)>=REQUIRED_CONSECUTIVE:
			result.merge({"ok":true,"normal":normal,"selected_level":level,"epsilon_m":epsilon,"final_angle_degrees":change,"preceding_angle_degrees":result.angles[-2]},true);return result
		previous=normal
	result.error="207 fixed eight-level convergence cap failed; no fallback."
	return result
