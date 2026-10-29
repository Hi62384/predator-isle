extends RefCounted
##208: one bounded extra level; no local patch, field change or fallback.
const Legacy=preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal207.gd")
const SETTING="blob_isosurface_normal_mode"
const MODE="adaptive_field_gradient_v2"
const OFF="off"
const PIN="5eb7722334a080e7fdd428f17f732877ac15b7c41defb2604d2c9fe95cc1ac00"
const START_FRACTION=0.05
const LEVELS=9
const ANGLE_DEGREES=0.25
const REQUIRED_CONSECUTIVE=2
const MAX_QUERIES=4380000
const MAX_QUERIES_PER_EDGE=73
static func selection(options: Dictionary)->Dictionary:
	var mode: Variant=options.get(SETTING,OFF)
	if not mode is String:return Legacy.selection(options)
	if mode!=MODE:return Legacy.selection(options)
	if options.get("blob_isosurface_refinement_mode")!="bracketed_field_edges_v1":return {"error":"208 requires the explicit204 bracketed edge mode."}
	return {"mode":MODE}
static func validate(dna: Dictionary)->Dictionary:
	if not dna.get("settings",{}) is Dictionary:return Legacy.validate(dna)
	var mode: Variant=dna.settings.get(SETTING,OFF)
	if not mode is String:return Legacy.validate(dna)
	if mode!=MODE:return Legacy.validate(dna)
	var selected: Dictionary=selection(dna.settings)
	if selected.has("error"):return {"ok":false,"error":selected.error}
	if not dna.get("metadata",{}) is Dictionary or dna.get("type")!="Blob" or int(dna.metadata.get("iteration_index",0))<2:return {"ok":false,"error":"208 applies only to developed Blob stages."}
	return {"ok":true}
static func angle(a: Vector3,b: Vector3)->float:return Legacy.angle(a,b)
static func spacing(point: Vector3,epsilon: float)->Dictionary:
	var result: Dictionary={"ok":false,"epsilon_m":epsilon,"axes":[]}
	if not point.is_finite() or not is_finite(epsilon) or epsilon<=0.0:return result
	for axis in range(3):
		var delta: Vector3=Vector3.ZERO;delta[axis]=epsilon
		var plus: Vector3=point+delta;var minus: Vector3=point-delta
		var hp: float=float(plus[axis])-float(point[axis]);var hm: float=float(point[axis])-float(minus[axis])
		result.axes.append({"axis":axis,"plus":plus,"minus":minus,"actual_plus_m":hp,"actual_minus_m":hm})
		if not plus.is_finite() or not minus.is_finite() or not is_finite(hp) or not is_finite(hm) or hp<=0.0 or hm<=0.0:return result
	result.ok=true;return result
static func sample_record(point: Vector3,value: Variant)->Dictionary:
	var numeric: bool=value is int or value is float
	var finite: bool=numeric and is_finite(float(value))
	var bytes: PackedByteArray=PackedByteArray()
	if numeric:bytes.resize(8);bytes.encode_double(0,float(value))
	return {"point":point,"point_f32_le":PackedVector3Array([point]).to_byte_array().hex_encode(),"type":typeof(value),"finite":finite,"value":float(value) if finite else null,"numeric_f64_le":bytes.hex_encode()}
static func refine(point: Vector3,cell: float,initial_gradient: Vector3,query: Callable,initial_samples: Array=[])->Dictionary:
	var result: Dictionary={"ok":false,"error":"","levels":1,"additional_queries":0,"angles":[],"consecutive":0,"diagnostics":{"point":point,"point_f32_le":PackedVector3Array([point]).to_byte_array().hex_encode(),"cell_m":cell,"initial_samples":initial_samples.duplicate(true),"steps":[],"global_accuracy_claimed":false}}
	var epsilon: float=START_FRACTION*cell
	var represented: Dictionary=spacing(point,epsilon)
	result.diagnostics.steps.append({"level":0,"spacing":represented,"gradient":initial_gradient,"gradient_length":initial_gradient.length()})
	if not query.is_valid() or not represented.ok or not initial_gradient.is_finite() or not is_finite(initial_gradient.length()) or initial_gradient.length()<=0.0:
		result.error="208 degenerate initial complete-field gradient or unrepresentable offsets.";return result
	var previous: Vector3=initial_gradient.normalized()
	for level in range(1,LEVELS):
		epsilon*=0.5;represented=spacing(point,epsilon)
		var row: Dictionary={"level":level,"spacing":represented,"samples":[]}
		result.diagnostics.steps.append(row)
		if not represented.ok:result.error="208 binary32 offset stagnation; no fallback.";return result
		var gradient: Vector3=Vector3.ZERO
		for axis in range(3):
			var offsets: Dictionary=represented.axes[axis]
			var plus: Variant=query.call(offsets.plus);result.additional_queries+=1
			var minus: Variant=query.call(offsets.minus);result.additional_queries+=1
			row.samples.append(sample_record(offsets.plus,plus));row.samples.append(sample_record(offsets.minus,minus))
			if not (plus is float or plus is int) or not (minus is float or minus is int) or not is_finite(float(plus)) or not is_finite(float(minus)):
				result.error="208 nonfinite complete-field normal query; no fallback.";return result
			# Same nominal formula as207. Actual-spacing diagnostics do not silently change it.
			gradient[axis]=(float(plus)-float(minus))/(2.0*epsilon)
		result.levels=level+1
		var length: float=gradient.length();row["gradient"]=gradient;row["gradient_length"]=length
		if not gradient.is_finite() or not is_finite(length) or length<=0.0:result.error="208 degenerate complete-field gradient; no fallback.";return result
		var normal: Vector3=gradient/length;var change: float=angle(previous,normal)
		row["normal"]=normal;row["change_degrees"]=change
		if not is_finite(change):result.error="208 nonfinite normal convergence angle.";return result
		result.angles.append(change)
		result.consecutive=int(result.consecutive)+1 if change<=ANGLE_DEGREES else 0
		if int(result.consecutive)>=REQUIRED_CONSECUTIVE:
			result.merge({"ok":true,"normal":normal,"selected_level":level,"epsilon_m":epsilon,"final_angle_degrees":change,"preceding_angle_degrees":result.angles[-2]},true);return result
		previous=normal
	result.error="208 fixed nine-level convergence cap failed; no fallback."
	return result
