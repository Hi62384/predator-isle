extends RefCounted
## Explicit223 SINGLE-primary selector: thirteen immutable sites, at most three trials.
## Only a full finite-qualified winner is published. No secondary, pair or bridge.
## Geometry kernels below retain221 arithmetic; accounting is local to223.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityPolicy223.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const NodeData = preload("res://alien_foundry/scripts/anatomy/AnatomyNode.gd")
const ConnectionData = preload("res://alien_foundry/scripts/anatomy/AnatomyConnection.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const SacQualification = preload("res://alien_foundry/scripts/geometry/BlobSacGroupQualification.gd")
const SDF = preload("res://alien_foundry/scripts/geometry/SDFOperations.gd")
const Exact = preload("res://alien_foundry/scripts/geometry/BlobMassOuterProfile203.gd")
const MassCounters = preload("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd")
const GroupCounters = preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
static var _preparation_records: Dictionary = {}
const H: float = 0.06132264835698207
const COMPLETE_CAP: int = 17500
const LOGICAL_CAP: int = 17352
const SCREEN_CAP: int = 318
const TRIAL_CAP: int = 4406
const CAVITY_CAP: int = 2165
const OWNER_DISPATCH_CAP: int = 1404
const SHELL_DEPTHS: Array = [0.12,0.0,-0.25,-0.5,-0.75,-0.9,-1.0]

## One aggregate owns the immutable F0 cache and all screen/trial accounting.
## The full typed positive input identity and exact Vector3 bytes are required.
## No mutable F1 value is cached, including SacCounter's amplitude contrast.
class Budget extends RefCounted:
	var logical_requests: int = 0
	var executed_values: int = 0
	var cache_hits: int = 0
	var logical_cap: int = 17352
	var complete_cap: int = 17500
	var owner_dispatch_cap: int = 1404
	var owner_location_cap: int = 52
	var owner_dispatches: int = 0
	var owner_locations: int = 0
	var overflow: bool = false
	var f0: RefCounted = null
	var positive_identity: String = ""
	var positive_input: Dictionary = {}
	var f0_values: Dictionary = {}
	static func cache_key(positive_identity: String, point: Vector3, field_name: String) -> String:
		if field_name != "F0" or positive_identity.is_empty(): return ""
		return positive_identity+"|continuous_extraction_v1|"+var_to_bytes(point).hex_encode()
	func accounting() -> Dictionary:
		return {"logical_requests":logical_requests,"logical_request_cap":logical_cap,"cache_hits":cache_hits,"executed_complete_values":executed_values,"complete_field_calls":executed_values,"complete_field_cap":complete_cap,"owner_locations":owner_locations,"owner_location_cap":owner_location_cap,"owner_influence_dispatches":owner_dispatches,"owner_dispatch_cap":owner_dispatch_cap,"overflow":overflow,"F0_cache_key":"canonical_full_positive_input_and_exact_Vector3_bytes_and_query_semantics","F1_point_cache":false}

class Ledger extends RefCounted:
	var budget: Budget
	var records: Array = []
	# calls remains the logical-request counter expected by the unchanged kernels.
	var calls: int = 0
	var cap: int = 4406
	var executed_values: int = 0
	var cache_hits: int = 0
	var overflow: bool = false
	var by_phase: Dictionary = {}
	var executed_by_phase: Dictionary = {}
	var cache_hits_by_phase: Dictionary = {}
	var owner_dispatch_cap: int = 351
	var owner_location_cap: int = 13
	var owner_influence_dispatches: int = 0
	var owner_body_component_reads: int = 0
	var query_body_component_reads: int = 0
	var analytic_support_component_reads: int = 0
	var analytic_support_control_ball_reads: int = 0
	var owner_locations: int = 0
	func _init(shared: Budget) -> void: budget = shared
	func value(field: RefCounted, point: Vector3, field_name: String, phase: String) -> float:
		if calls >= cap or budget.logical_requests >= budget.logical_cap:
			overflow = true; budget.overflow = true
			return NAN
		calls += 1; budget.logical_requests += 1
		by_phase[phase] = int(by_phase.get(phase,0))+1
		var cacheable: bool = field_name == "F0" and field == budget.f0 and not budget.positive_identity.is_empty()
		var key: String = ""
		if cacheable: key = Budget.cache_key(budget.positive_identity,point,field_name)
		if cacheable and budget.f0_values.has(key):
			var retained: float = float(budget.f0_values[key])
			cache_hits += 1; budget.cache_hits += 1
			cache_hits_by_phase[phase] = int(cache_hits_by_phase.get(phase,0))+1
			records.append({"field":field_name,"phase":phase,"point":[point.x,point.y,point.z],"value":retained,"cache_hit":true,"complete_value_executed":false})
			return retained
		if budget.executed_values >= budget.complete_cap:
			overflow = true; budget.overflow = true
			records.append({"field":field_name,"phase":phase,"point":[point.x,point.y,point.z],"value":NAN,"cache_hit":false,"complete_value_executed":false,"rejected_by_complete_cap":true})
			return NAN
		var body: RefCounted = null
		for item: RefCounted in field.influences:
			if item.body_envelope != null: body = item.body_envelope; break
		var before: int = int(body.geometry_evaluations) if body != null else 0
		var result: float = field._continuous_extraction_value(point)
		if body != null: query_body_component_reads += int(body.geometry_evaluations)-before
		executed_values += 1; budget.executed_values += 1
		executed_by_phase[phase] = int(executed_by_phase.get(phase,0))+1
		if cacheable: budget.f0_values[key] = result
		records.append({"field":field_name,"phase":phase,"point":[point.x,point.y,point.z],"value":result,"cache_hit":false,"complete_value_executed":true})
		return result
	func accounting() -> Dictionary:
		return {"logical_requests":calls,"logical_request_cap":cap,"cache_hits":cache_hits,"executed_complete_values":executed_values,"complete_field_calls":executed_values,"complete_field_cap":cap,"overflow":overflow,"by_phase":by_phase.duplicate(true),"executed_by_phase":executed_by_phase.duplicate(true),"cache_hits_by_phase":cache_hits_by_phase.duplicate(true),"owner_influence_dispatches":owner_influence_dispatches,"owner_dispatch_cap":owner_dispatch_cap,"owner_body_component_reads":owner_body_component_reads,"query_body_component_reads":query_body_component_reads,"analytic_support_component_reads":analytic_support_component_reads,"analytic_support_control_ball_reads":analytic_support_control_ball_reads,"owner_locations":owner_locations,"owner_location_cap":owner_location_cap,"component_reads_are_not_complete_field_values":true}

class SacCounter extends RefCounted:
	var source: RefCounted
	var influences: Array
	var source_dna: Dictionary
	var step: float
	var ledger: RefCounted
	var calls: int = 0
	var overflow: bool = false
	func _init(field: RefCounted, counter: RefCounted) -> void:
		source = field; ledger = counter; influences = field.influences; source_dna = field.source_dna; step = field.step
	func _field_value(point: Vector3, _bucket: PackedInt32Array, apply_noise: bool = true, apply_cavities: bool = true, apply_contained_lips: bool = true) -> float:
		# SacQualification temporarily changes amplitude for the macro contrast.
		# This routes every request through the actual production tile, NEVER F0 cache.
		if calls >= 2190 or not apply_noise or not apply_cavities or not apply_contained_lips:
			overflow = true
			return NAN
		calls += 1
		return ledger.value(source,point,"F1","existing_sac_root_sections")

static func _arr(p: Vector3) -> Array: return [p.x,p.y,p.z]

static func _node(dna: Dictionary, id: String) -> Dictionary:
	for value: Dictionary in dna.get("nodes", []):
		if value.get("id") == id: return value
	return {}

static func _number(v: Variant) -> bool: return (v is float or v is int) and is_finite(float(v))

static func _vec_ok(v: Variant) -> bool:
	if not v is Array or v.size() != 3: return false
	for x: Variant in v:
		if not _number(x): return false
	return true

static func _basis_ok(b: Basis) -> bool:
	return b.is_finite() and b.x.length_squared() > 0.0 and b.y.length_squared() > 0.0 and b.z.length_squared() > 0.0 and b.determinant() > 0.0 and b.is_equal_approx(b.orthonormalized())

static func _cache_payload(dna: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["type","seed","nodes","connections","settings","modules","biological_blueprint","active_feature_ids","feature_realization"]: result[key] = dna.get(key)
	result["stage_ground_translation"] = dna.get("metadata", {}).get("stage_ground_translation")
	return result
##219b: dictionary order is not identity; array order and typed scalar bits are.
## Keys sort by their own canonical typed bytes, never mixed-Variant comparison.

static func _typed_tree(value: Variant) -> Array:
	if value is Dictionary:
		var entries: Array = []
		for key: Variant in value:
			var key_tree: Array = _typed_tree(key)
			entries.append([var_to_bytes(key_tree).hex_encode(),key_tree,_typed_tree(value[key])])
		entries.sort_custom(func(a: Array,b: Array)->bool: return str(a[0])<str(b[0]))
		var ordered: Array = []
		for entry: Array in entries: ordered.append([entry[1],entry[2]])
		return ["dictionary",ordered]
	if value is Array:
		var ordered: Array = []
		for item: Variant in value: ordered.append(_typed_tree(item))
		return ["array",ordered]
	if value is float:
		var bytes: PackedByteArray = PackedByteArray(); bytes.resize(8); bytes.encode_double(0,value)
		return ["scalar",typeof(value),bytes.hex_encode()]
	return ["scalar",typeof(value),var_to_bytes(value).hex_encode()]

static func _typed_digest(value: Variant) -> String:
	return var_to_bytes(_typed_tree(value)).hex_encode().sha256_text()

static func _fingerprint(dna: Dictionary) -> String: return _typed_digest(_cache_payload(dna))

static func _raw_fingerprint(dna: Dictionary) -> String:
	return var_to_bytes(_cache_payload(dna)).hex_encode().sha256_text()

static func _body(field: RefCounted) -> RefCounted:
	for item: RefCounted in field.influences:
		if item.body_envelope != null: return item.body_envelope
	return null

## Pure source arithmetic. Policy owns canonical frame/table scalars so saved
## declarations and authoring cannot diverge through arithmetic reordering.

static func actual_domain(plan: Dictionary, row: Dictionary) -> Dictionary:
	var origin: Vector3 = Graph.vec(plan.frame.origin)
	var tangent: Vector3 = Graph.vec(plan.frame.tangent); var bitangent: Vector3 = Graph.vec(plan.frame.bitangent)
	var extent: Vector2 = Vector2(float(plan.territory_half_extents_m[0]),float(plan.territory_half_extents_m[1]))
	var wall: float = float(plan.wall_m)
	var center: Vector3 = Graph.vec(row.center); var basis: Basis = Graph.node_basis({"rotation":row.rotation})
	var radii: Vector3 = Graph.vec(row.radii_m)+Vector3(wall,wall,wall)
	var rows: Array = []; var valid: bool = true
	for index: int in range(12):
		var angle: float = TAU*float(index)/12.0
		var direction: Vector3 = tangent*cos(angle)+bitangent*sin(angle)
		var point: Vector3 = center+_support_vector(basis,radii,direction)
		var projected: Vector2 = Vector2((point-origin).dot(tangent),(point-origin).dot(bitangent))
		var ratio: float = (projected/extent).length_squared()
		rows.append({"index":index,"direction":_arr(direction),"point":_arr(point),"projected_point":[projected.x,projected.y],"normalized_radius_squared":ratio})
		valid = valid and direction.is_finite() and point.is_finite() and projected.is_finite() and is_finite(ratio) and ratio<=1.0
	return {"node_id":row.node_id,"ok":valid,"sample_count":rows.size(),"finite_sampling_only":true,"additional_field_calls":0,"rows":rows}

## Same direct geometry-input preparation as cheap215: no repair/ground/scale.
## Dynamic loading prevents an OrganicVolume -> policy -> author preload cycle.

static func prepare(dna: Dictionary) -> RefCounted:
	var counters_before: Dictionary = _component_counters()
	var script: Variant = load("res://alien_foundry/scripts/geometry/OrganicVolume.gd")
	var field: RefCounted = script.new()
	field.source_dna = dna
	field.geometry_adjustments = {"thin_features":[],"attachment_collars":[],"lattice_collars":[]}
	field._prepare(dna.nodes,1)
	if not field.preparation_errors.is_empty(): _save_preparation(field,counters_before); return field
	field._conform_surface_folds(); field._configure_grid(1); field._preserve_thin_features(); field._ensure_growth_attachments(dna.nodes)
	if field.thin_features_preserved > 0 or field.attachment_repairs > 0: field.preparation_errors.append("221 direct preparation forbids geometry repairs.")
	if not field.preparation_errors.is_empty(): _save_preparation(field,counters_before); return field
	field._build_tiles()
	field.noise.configure(int(dna.seed),1.0,float(dna.settings.get("surface_detail",0.55)))
	field._prepare_masks(dna.modules); field._expose_surface_cavities(dna.nodes); field._prepare_module_seats(dna.modules)
	_save_preparation(field,counters_before)
	return field

static func _component_counters() -> Dictionary:
	var result: Dictionary = {"mass_component_reads":0,"mass_host_reads":0,"base_group_component_reads":0,"base_group_host_reads":0}
	for body: RefCounted in MassCounters._fields.values():
		result.mass_component_reads += int(body.geometry_evaluations); result.mass_host_reads += int(body.host_evaluations)
	for body: RefCounted in GroupCounters._fields.values():
		result.base_group_component_reads += int(body.geometry_evaluations); result.base_group_host_reads += int(body.host_evaluations)
	return result

static func _save_preparation(field: RefCounted, before: Dictionary) -> void:
	var after: Dictionary = _component_counters(); var delta: Dictionary = {}
	for key: String in before: delta[key] = int(after[key])-int(before[key])
	_preparation_records[field.get_instance_id()] = {"analytic_component_read_deltas":delta,"primitive_evaluations":int(field.primitive_evaluations),"measurement":"existing_mass_and_base_group_counters_before_after_preparation","complete_field_calls":0,"lattice_samples":0}

static func _projection(field: RefCounted, ledger: Ledger, nominal: Vector3, axis: Vector3, length: float, phase: String) -> Dictionary:
	var before: int = ledger.calls
	var previous: Vector3 = nominal + axis * (2.0 * length)
	var previous_value: float = ledger.value(field,previous,"F0",phase)
	var result: Dictionary = {"ok":false,"nominal":_arr(nominal),"axis":_arr(axis),"scan_intervals":64,"bisections_max":14,"first_crossing_only":true}
	if not is_finite(previous_value) or previous_value <= 0.0:
		result.merge({"error":"F0 ray does not start in finite exterior.","point":_arr(previous),"value":previous_value,"calls":ledger.calls-before},true); return result
	for i: int in range(1,65):
		var current: Vector3 = nominal + axis * lerpf(2.0 * length,-2.0 * length,float(i)/64.0)
		var current_value: float = ledger.value(field,current,"F0",phase)
		if not is_finite(current_value): result.merge({"error":"Nonfinite F0 scan value.","point":_arr(current),"value":current_value,"calls":ledger.calls-before},true); return result
		if current_value <= 0.0:
			var outside: Vector3 = previous; var inside: Vector3 = current
			var outside_value: float = previous_value; var inside_value: float = current_value
			var exact: bool = current_value == 0.0; var performed: int = 0
			for j: int in range(14):
				if exact: break
				var middle: Vector3 = outside.lerp(inside,0.5)
				if middle == outside or middle == inside: result.merge({"error":"F0 projection midpoint is not representably distinct.","outside":_arr(outside),"inside":_arr(inside),"calls":ledger.calls-before},true); return result
				var value: float = ledger.value(field,middle,"F0",phase)
				performed += 1
				if not is_finite(value): result.merge({"error":"Nonfinite F0 bisection.","point":_arr(middle),"value":value,"calls":ledger.calls-before},true); return result
				if value <= 0.0: inside = middle; inside_value = value; exact = value == 0.0
				else: outside = middle; outside_value = value
			var hit: Vector3 = inside if exact else outside.lerp(inside,0.5)
			result.merge({"ok":true,"point":_arr(hit),"outside":_arr(outside),"inside":_arr(inside),"outside_value":outside_value,"inside_value":inside_value,"bracket_width_m":outside.distance_to(inside),"exact_zero_terminal":exact,"bisections_performed":performed,"scan_interval":i,"calls":ledger.calls-before},true); return result
		previous = current; previous_value = current_value
	result.merge({"error":"No first F0 exterior-to-tissue crossing in fixed reach.","calls":ledger.calls-before},true); return result

static func _field_summary(field: RefCounted) -> Dictionary:
	var positive: int = 0; var cutters: int = 0; var body: RefCounted = _body(field)
	for item: RefCounted in field.influences:
		if item.subtract: cutters += 1
		else: positive += 1
	return {"bounds":{"position":_arr(field.bounds.position),"size":_arr(field.bounds.size)},"h":float(field.step),"grid":[field.grid_dimensions.x,field.grid_dimensions.y,field.grid_dimensions.z],"positive_influences":positive,"cavity_influences":cutters,"body_halo":float(body.halo) if body != null else NAN,"body_exterior":float(body.host.exterior) if body != null else NAN,"preparation":_preparation_records.get(field.get_instance_id(),{"externally_prepared":true,"component_delta_not_owned_by_qualifier":true}),"primitive_evaluations_at_summary":int(field.primitive_evaluations),"lattice_sampled":false}

static func _check(report: Dictionary, ok: bool, name: String, detail: Dictionary = {}) -> bool:
	report.checks.append({"name":name,"ok":ok,"detail":detail})
	if not ok and not report.has("first_failure"): report["first_failure"] = {"check":name,"witness":detail.duplicate(true)}
	return ok

static func _ownership(field: RefCounted, ledger: Ledger, point: Vector3) -> Dictionary:
	var body_item: RefCounted = null; var relevant: PackedInt32Array = PackedInt32Array()
	for item: RefCounted in field.influences:
		if item.subtract: continue
		if item.node_index not in relevant: relevant.append(item.node_index)
		if item.body_envelope != null:
			if body_item != null: return {"ok":false,"error":"Ownership needs one exact body group."}
			body_item = item
			for index: int in item.member_indices:
				if index not in relevant: relevant.append(index)
	if body_item == null: return {"ok":false,"error":"Missing ordered positive body owner."}
	var dispatches: int = 1
	var tile: PackedInt32Array = field._tile_at(point)
	if field.influences.find(body_item) not in tile: return {"ok":false,"error":"Actual F0 owner group is absent from the queried tile."}
	for index: int in tile:
		var item: RefCounted = field.influences[index]
		if not item.subtract and item != body_item and item.node_index in relevant: dispatches += 1
	if ledger.owner_influence_dispatches + dispatches > ledger.owner_dispatch_cap or ledger.owner_locations >= ledger.owner_location_cap or ledger.budget.owner_dispatches + dispatches > ledger.budget.owner_dispatch_cap or ledger.budget.owner_locations >= ledger.budget.owner_location_cap:
		ledger.overflow = true; ledger.budget.overflow = true
		return {"ok":false,"error":"223 ownership influence dispatch/location cap exceeded."}
	var before: int = int(body_item.body_envelope.geometry_evaluations)
	var actual: Dictionary = field._body_group_component_partition(point,relevant,body_item)
	var component_reads: int = int(body_item.body_envelope.geometry_evaluations) - before
	ledger.owner_influence_dispatches += dispatches; ledger.owner_body_component_reads += component_reads; ledger.owner_locations += 1
	ledger.budget.owner_dispatches += dispatches; ledger.budget.owner_locations += 1
	var weights: Dictionary = actual.get("exact_ordered_carrier_weights", {})
	var core_index: int = field.node_ids.find("n000")
	var weight: float = float(weights.get(core_index,NAN))
	var serial: Dictionary = {}
	for index: int in weights: serial[str(field.node_ids[index])] = float(weights[index])
	return {"ok":is_finite(weight) and weight >= 0.70,"point":_arr(point),"n000_weight":weight,"required_minimum":0.70,"exact_ordered_carrier_weights":serial,"composed_positive_distance":actual.get("composed_distance"),"influence_dispatches":dispatches,"body_component_reads":component_reads,"four_slot_reduction_used":false}

static func _normal(field: RefCounted, ledger: Ledger, point: Vector3, axis: Vector3, phase: String) -> Dictionary:
	var e: float = maxf(0.35*H,0.001)
	var values: Array = []
	for direction: Vector3 in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
		values.append(ledger.value(field,point+direction*e,"F0",phase)); values.append(ledger.value(field,point-direction*e,"F0",phase))
	return _normal_from_values(values,axis)

static func _normal_from_values(values: Array, axis: Vector3) -> Dictionary:
	var e: float = maxf(0.35*H,0.001)
	if not Policy.vector(values,6): return {"ok":false,"values":values,"epsilon_m":e,"error":"Malformed/nonfinite F0 normal witness."}
	for value: float in values:
		if not is_finite(value): return {"ok":false,"values":values,"epsilon_m":e,"error":"Nonfinite F0 normal witness."}
	var gradient: Vector3 = Vector3(float(values[0])-float(values[1]),float(values[2])-float(values[3]),float(values[4])-float(values[5]))
	if not gradient.is_finite() or gradient.length_squared() <= 0.0: return {"ok":false,"values":values,"epsilon_m":e,"error":"Zero/nonfinite F0 finite-difference gradient."}
	var normal: Vector3 = gradient.normalized(); var dot_axis: float = normal.dot(axis)
	return {"ok":is_finite(dot_axis) and dot_axis >= 0.72,"normal":_arr(normal),"axis_dot":dot_axis,"required_minimum":0.72,"epsilon_m":e,"values":values}

static func _inward(field: RefCounted, ledger: Ledger, hit: Vector3, axis: Vector3, depth: float, phase: String) -> Dictionary:
	var before: int = ledger.calls
	var air: float = ledger.value(field,hit,"F1",phase)
	var result: Dictionary = {"ok":false,"air_start_value":air,"air_start_minimum":0.1*H,"scan_intervals":32,"bisections_max":16,"reach_m":2.0*depth,"scalar_residual_is_metric_distance":false}
	if not is_finite(air) or air < 0.1*H: result["error"] = "F1 mouth does not start in required air."; result["calls"] = ledger.calls-before; return result
	var outside: Vector3 = hit; var outside_value: float = air
	for i: int in range(1,33):
		var inside: Vector3 = hit-axis*(2.0*depth*float(i)/32.0)
		var inside_value: float = ledger.value(field,inside,"F1",phase)
		if not is_finite(inside_value): result.merge({"error":"Nonfinite F1 inward march.","point":_arr(inside),"value":inside_value,"calls":ledger.calls-before},true); return result
		if inside_value <= 0.0:
			var exact: bool = inside_value == 0.0; var performed: int = 0
			for j: int in range(16):
				if exact: break
				var midpoint: Vector3 = outside.lerp(inside,0.5)
				if midpoint == outside or midpoint == inside: result.merge({"error":"F1 midpoint is not representably distinct.","outside":_arr(outside),"inside":_arr(inside),"outside_value":outside_value,"inside_value":inside_value,"calls":ledger.calls-before},true); return result
				var value: float = ledger.value(field,midpoint,"F1",phase)
				performed += 1
				if not is_finite(value): result.merge({"error":"Nonfinite F1 inward bisection.","point":_arr(midpoint),"value":value,"calls":ledger.calls-before},true); return result
				if value <= 0.0: inside = midpoint; inside_value = value; exact = value == 0.0
				else: outside = midpoint; outside_value = value
			var point: Vector3 = inside if exact else outside.lerp(inside,0.5)
			var residual: float = ledger.value(field,point,"F1",phase)
			var bracket: float = 0.0 if exact else outside.distance_to(inside)
			var signs: bool = outside_value > 0.0 and inside_value <= 0.0 and is_finite(outside_value) and is_finite(inside_value)
			var representable: bool = exact or (outside != inside and point != outside and point != inside)
			result.merge({"ok":signs and representable and is_finite(residual) and bracket <= H/1024.0,"point":_arr(point),"outside":_arr(outside),"inside":_arr(inside),"outside_value":outside_value,"inside_value":inside_value,"finite_opposite_signs":signs,"representably_distinct":representable,"exact_zero_terminal":exact,"bisections_performed":performed,"bracket_width_m":bracket,"bracket_maximum_m":H/1024.0,"scalar_residual":residual,"depth_m":(hit-point).dot(axis),"scan_interval":i,"calls":ledger.calls-before},true); return result
		outside = inside; outside_value = inside_value
	result.merge({"error":"No first inward tissue entry within2D.","calls":ledger.calls-before},true); return result

static func _thickness(field: RefCounted, ledger: Ledger, hit: Vector3, axis: Vector3, length: float, depth: float, wall: float, phase: String) -> Dictionary:
	var reach: float = 2.0*length
	var stride: float = reach/56.0
	var samples: Array = []
	var thickness: float = reach
	var entered: bool = false
	var first_exit: bool = false
	for i: int in range(1,57):
		var distance: float = float(i)*stride
		var point: Vector3 = hit-axis*distance
		var value: float = ledger.value(field,point,"F0",phase)
		samples.append({"index":i,"point":_arr(point),"depth_m":distance,"value":value})
		if not is_finite(value): return {"ok":false,"error":"Nonfinite first-exit thickness witness.","samples":samples}
		if value < 0.0: entered = true
		else:
			thickness = maxf(distance-stride,0.0) if entered else 0.0
			first_exit = true
			break
	if not entered: thickness = 0.0
	var required: float = 1.48*depth+2.0*wall
	return {"ok":entered and thickness >= required,"conservative_thickness_m":thickness,"required_contiguous_thickness_m":required,"samples":samples,"step_count_max":56,"reach_m":reach,"stride_m":stride,"first_exit_found":first_exit,"first_exit_only":true,"finite_sampling_only":true}

static func _shell(field: RefCounted, ledger: Ledger, center: Vector3, basis: Basis, radii: Vector3, wall: float, field_name: String, phase: String) -> Dictionary:
	var rows: Array = []
	var unique: Array = []
	var first: Dictionary = {}
	var maximum: float = -INF
	for fraction: float in SHELL_DEPTHS:
		var radial: float = sqrt(maxf(0.0,1.0-fraction*fraction))
		for j: int in range(24):
			var angle: float = TAU*float(j)/24.0
			var local: Vector3 = Vector3(cos(angle)*(radii.x+wall)*radial,sin(angle)*(radii.y+wall)*radial,(radii.z+wall)*fraction)
			var point: Vector3 = center+basis*local
			var value: float = ledger.value(field,point,field_name,phase)
			var row: Dictionary = {"kind":"inward_shell","depth_fraction":fraction,"angular_sample":j,"local":_arr(local),"point":_arr(point),"value":value,"required_maximum":-0.35*wall}
			rows.append(row)
			if point not in unique: unique.append(point)
			if is_finite(value): maximum = maxf(maximum,value)
			if (not is_finite(value) or value > -0.35*wall) and first.is_empty(): first = row.duplicate(true)
	for j: int in range(9):
		var angle: float = TAU*float(j)/8.0
		var radial: float = 0.0 if j == 8 else 0.40
		var local: Vector3 = Vector3(cos(angle)*radii.x*radial,sin(angle)*radii.y*radial,-radii.z-wall)
		var point: Vector3 = center+basis*local
		var value: float = ledger.value(field,point,field_name,phase)
		var row: Dictionary = {"kind":"back_disk","angular_sample":j,"local":_arr(local),"point":_arr(point),"value":value,"required_maximum":-0.35*wall}
		rows.append(row)
		if point not in unique: unique.append(point)
		if is_finite(value): maximum = maxf(maximum,value)
		if (not is_finite(value) or value > -0.35*wall) and first.is_empty(): first = row.duplicate(true)
	return {"ok":first.is_empty(),"rows":rows,"sample_count":rows.size(),"unique_positions":unique.size(),"expected_unique_positions":153,"maximum_value":maximum,"required_maximum":-0.35*wall,"first_failure":first,"complete_finite_set":true,"finite_sampling_only":true}

static func _support_vector(basis: Basis, radii: Vector3, direction: Vector3) -> Vector3:
	# Actual3D ellipsoid support, including consumed depth-axis projection.
	var local: Vector3 = basis.transposed()*direction
	var scaled: Vector3 = Vector3(radii.x*local.x,radii.y*local.y,radii.z*local.z)
	var denominator: float = scaled.length()
	if not is_finite(denominator) or denominator <= 0.0: return Vector3(NAN,NAN,NAN)
	return basis*Vector3(radii.x*radii.x*local.x,radii.y*radii.y*local.y,radii.z*radii.z*local.z)/denominator

static func _plain(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2: return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _plain(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_plain(item))
		return result
	return value

## Public pure helpers used by the cheap contract, never field evaluation.
static func immutable_f0_cache_key(positive_identity: String, point: Vector3, field_name: String) -> String:
	return Budget.cache_key(positive_identity,point,field_name)

static func ranked_shortlist(candidates: Array) -> Array:
	var ranked: Array = []
	for value: Variant in candidates:
		if not value is Dictionary or not value.get("ok") is bool or not value.ok or not value.get("site_id") is int or int(value.site_id)<0 or int(value.site_id)>=13 or not _number(value.get("score")) or float(value.score)<0.0: continue
		ranked.append({"site_id":int(value.site_id),"score":float(value.score)})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if float(a.score) == float(b.score): return int(a.site_id)<int(b.site_id)
		return float(a.score)>float(b.score))
	return ranked.slice(0,mini(3,ranked.size()))

static func placement(dna: Dictionary) -> Dictionary:
	var plan: Dictionary = Policy.frame_table(dna)
	if not plan.get("ok",false): return plan
	var territory: Basis = Basis(Graph.vec(plan.frame.tangent),Graph.vec(plan.frame.bitangent),Graph.vec(plan.frame.normal))
	if not _basis_ok(territory): return {"ok":false,"error":"223 invalid canonical territory basis."}
	var length: float = float(plan.frame.length)
	for row: Dictionary in plan.sites:
		var radii: Vector3 = Graph.vec(row.radii_m)
		var basis: Basis = Graph.node_basis({"rotation":row.rotation})
		var intended: Basis = territory*Basis(Vector3.BACK,float(row.roll_radians))
		if not _basis_ok(basis) or not basis.is_equal_approx(intended): return {"ok":false,"error":"223 invalid consumed planning Euler reconstruction; no alternate axis."}
		if minf(radii.x,radii.y)<float(plan.feature_radius_m) or radii.z<1.3*minf(radii.x,radii.y) or radii.z>0.64*length: return {"ok":false,"error":"223 fixed primary violates inherited feature/depth floors."}
	return plan

static func _budget(positive: Dictionary, f0: RefCounted, selection: bool) -> Budget:
	var result: Budget = Budget.new()
	result.f0 = f0; result.positive_input = positive.duplicate(true); result.positive_identity = _typed_digest(positive)
	if not selection:
		result.logical_cap = TRIAL_CAP; result.complete_cap = TRIAL_CAP
		result.owner_dispatch_cap = 351; result.owner_location_cap = 13
	return result

static func _finish(report: Dictionary, ledger: Ledger) -> Dictionary:
	report["accounting"] = ledger.accounting(); report["complete_values"] = ledger.records
	if (ledger.overflow or ledger.budget.overflow) and not report.has("first_failure"):
		report["first_failure"] = {"check":"logical_complete_or_owner_budget","witness":ledger.accounting()}
	report["ok"] = not report.has("first_failure") and not ledger.overflow and not ledger.budget.overflow
	if not report.ok: report["error"] = "223 finite single-primary qualification rejected; no fallback."
	return report

static func _support_balls(dna: Dictionary, row: Dictionary, wall: float, ledger: Ledger) -> Dictionary:
	var inverse: Basis = Graph.node_basis({"rotation":row.rotation}).inverse()
	var center: Vector3 = Graph.vec(row.center); var radii: Vector3 = Graph.vec(row.radii_m)
	var rows: Array = []; var valid: bool = true; var first: Dictionary = {}
	for support_id: String in ["n005","n006"]:
		var support: Dictionary = _node(dna,support_id)
		if not support.get("points") is Array or not support.get("radii") is Array or support.points.size() != 3 or support.radii.size() != 3:
			return {"ok":false,"rows":rows,"error":"223 requires the six unchanged support control balls."}
		for index: int in range(support.points.size()):
			var point: Vector3 = Graph.vec(support.points[index]); var radius: float = float(support.radii[index])
			var value: float = SDF.ellipsoid(inverse*(point-center),radii)
			ledger.analytic_support_control_ball_reads += 1
			var witness: Dictionary = {"cutter_id":"n013","support_id":support_id,"control_index":index,"point":_arr(point),"analytic_cutter_distance":value,"control_radius":radius,"required_minimum":radius+wall,"finite_control_ball_only":true}
			rows.append(witness)
			if not is_finite(value) or value < radius+wall:
				valid = false
				if first.is_empty(): first = witness.duplicate(true)
	return {"ok":valid and rows.size()==6,"rows":rows,"first_failure":first,"additional_field_calls":0}

static func _screen(dna: Dictionary, plan: Dictionary, row: Dictionary, budget: Budget) -> Dictionary:
	var ledger: Ledger = Ledger.new(budget); ledger.cap = SCREEN_CAP; ledger.owner_dispatch_cap = 27; ledger.owner_location_cap = 1
	var report: Dictionary = {"ok":false,"site_id":row.site_id,"checks":[],"planned_site":row.duplicate(true),"finite_sampling_only":true}
	var f0: RefCounted = budget.f0; var length: float = float(plan.frame.length); var wall: float = float(plan.wall_m)
	var axis: Vector3 = Graph.vec(plan.frame.normal)
	var crossing: Dictionary = _projection(f0,ledger,Graph.vec(row.nominal),axis,length,"screen_center_projection")
	report["projection"] = crossing
	if not _check(report,bool(crossing.ok),"center_first_crossing",crossing): return _finish(report,ledger)
	var normal: Dictionary = _normal(f0,ledger,Graph.vec(crossing.point),axis,"screen_center_normal")
	report["normal"] = normal
	if not _check(report,bool(normal.ok),"actual_chart_axis_center_normal",normal): return _finish(report,ledger)
	var reconstruction: Dictionary = Policy.local_frame(plan.frame,row,crossing.point,normal.values)
	if not _check(report,bool(reconstruction.get("ok",false)),"fixed_local_host_normal_pose",reconstruction): return _finish(report,ledger)
	var local_frame: Dictionary = reconstruction.local_frame
	report["local_frame"] = local_frame.duplicate(true)
	var saved: Dictionary = row.duplicate(true)
	saved["rotation"] = local_frame.rotation.duplicate(); saved["center"] = local_frame.center.duplicate(); saved["surface_hit"] = crossing.point.duplicate(); saved["local_frame"] = local_frame.duplicate(true)
	report["saved_row"] = saved
	var owner: Dictionary = _ownership(f0,ledger,Graph.vec(crossing.point)); report["owner"] = owner
	if not _check(report,bool(owner.ok),"center_exact_n000_ownership",owner): return _finish(report,ledger)
	var domain: Dictionary = actual_domain(plan,saved); report["domain"] = domain
	if not _check(report,bool(domain.ok) and int(domain.sample_count)==12,"actual_padded_territory",domain): return _finish(report,ledger)
	var balls: Dictionary = _support_balls(dna,saved,wall,ledger); report["support_control_balls"] = balls.rows
	if not _check(report,bool(balls.ok),"six_support_control_balls",balls): return _finish(report,ledger)
	var basis: Basis = Graph.node_basis({"rotation":saved.rotation})
	var thickness: Dictionary = _thickness(f0,ledger,Graph.vec(crossing.point),basis.z,length,float(saved.radii_m[2]),wall,"screen_actual_axis_thickness")
	report["thickness"] = thickness
	if not _check(report,bool(thickness.ok),"actual_axis_first_exit_thickness",thickness): return _finish(report,ledger)
	var shell: Dictionary = _shell(f0,ledger,Graph.vec(saved.center),basis,Graph.vec(saved.radii_m),wall,"F0","screen_complete_shell_F0")
	report["shell_f0"] = shell
	if not _check(report,bool(shell.ok) and int(shell.sample_count)==177 and int(shell.unique_positions)==153,"complete_F0_shell_back_disk",shell): return _finish(report,ledger)
	var scored: Dictionary = Policy.preliminary_score(float(owner.n000_weight),float(thickness.conservative_thickness_m),float(thickness.required_contiguous_thickness_m),float(shell.maximum_value),wall)
	if not _check(report,bool(scored.get("ok",false)),"finite_preliminary_score",scored): return _finish(report,ledger)
	report["score"] = float(scored.score)
	return _finish(report,ledger)

## Work only on a private copy. Pending metadata never claims qualification.
static func _candidate_dna(source: Dictionary, plan: Dictionary, row: Dictionary, screened: Dictionary, decision: Dictionary) -> Dictionary:
	var made: Dictionary = Policy.make_context(plan,row,screened.local_frame,decision,int(screened.projection.calls))
	if not made.get("ok",false): return {"ok":false,"error":made.get("error","223 context construction failed.")}
	var context: Dictionary = made.context
	var dna: Dictionary = source.duplicate(true); var blueprint: Dictionary = dna.biological_blueprint
	var saved: Dictionary = context.cavities[0]
	var recipe: Dictionary = {"version":4,"mode":Policy.MODE,"spec_sha256":Policy.PIN,"role":"primary","parent_node_id":"n000","carrier_feature_id":"blob.body.core","radii_over_L":[0.185,0.3,0.52],"roll_radians":1.15,"site_id":int(row.site_id)}
	Blueprint.declare(blueprint,str(saved.feature_id),"cavity","blob.body.core",5,Graph.vec(saved.local_frame.consumed_normal).normalized(),recipe)
	var node: Dictionary = NodeData.make("n013","n000","cavity","cavity",saved.center.duplicate(),saved.radii_m.duplicate(),"muscle")
	node.merge({"rotation":saved.rotation.duplicate(),"bone":false,"operation":"subtract","blend":0.025*float(plan.frame.length),"noise":0.0,"surface_opening":false,"normal":_arr(Basis.from_euler(Graph.vec(saved.rotation)).z),"blob_region":"mantle_blind_chamber","source":"fixed223_territory_primary_blind_chamber_v1"},true)
	node["porous_growth"] = {"minimum_wall":plan.wall_m,"host_thickness":0.0,"complete_rim":false,"back_wall":false,"containment_method":"fixed223_finite_pending","burial_ratio":0.48,"metrics_space":"grounded_geometry_input"}
	node[Policy.KEY] = context.duplicate(true)
	Blueprint.bind_node(blueprint,str(saved.feature_id),node,5); dna.nodes.append(node)
	dna.connections.append(ConnectionData.make("n000","n013","growth",float(node.blend)))
	dna.metadata[Policy.KEY] = context.duplicate(true); dna.metadata["node_count"] = 14
	Blueprint.annotate_snapshot(dna,blueprint,5)
	var artifacts: GDScript = load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	artifacts.seal_geometry_recipe(dna)
	return {"ok":true,"dna":dna}

static func _qualification_payload(dna: Dictionary) -> Dictionary:
	var result: Dictionary = _cache_payload(dna)
	# Keep the old canonical typed helpers and add the consumed budget explicitly.
	result["budget"] = dna.get("budget")
	return result

static func _qualification_report() -> Dictionary:
	return {"ok":false,"method":"fixed223_actual_tiled_single_qualification_v1","spec_sha256":Policy.PIN,"finite_sampling_only":true,"global_clearance_proof":false,"global_self_intersection_proof":false,"continuous_mouth_outline_proof":false,"candidate_authorized":false,"lattice_samples":0,"mesh_builds":0,"search_attempts":0,"shrink_steps":0,"depth_fit_steps":0,"fallback_hosts":0,"cutter_count":1,"secondary_present":false,"pair_goal_satisfied":false,"bridge":{},"checks":[],"cavities":[],"mapped_root_paths":[],"supports":[],"support_control_balls":[],"complete_values":[]}

static func _run_trial(dna: Dictionary, budget: Budget, prepared_field: RefCounted = null) -> Dictionary:
	var report: Dictionary = _qualification_report(); var ledger: Ledger = Ledger.new(budget)
	if not _check(report,Policy.enabled(dna),"explicit223_single_qualification_mode"): return _finish(report,ledger)
	var declared: Dictionary = Policy.validate_restored(dna)
	if not _check(report,bool(declared.get("ok",false)),"restored_declaration",declared): return _finish(report,ledger)
	var artifacts: GDScript = load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	report["geometry_key217"] = artifacts.geometry_key(dna,5,Policy.DEPENDENCY4)
	if not _check(report,not str(report.geometry_key217).begins_with("invalid_recipe:"),"valid_consumed_geometry_key",{"key":report.geometry_key217}): return _finish(report,ledger)
	var plan: Dictionary = placement(dna)
	if not _check(report,bool(plan.get("ok",false)),"fixed_thirteen_site_table",plan): return _finish(report,ledger)
	var context: Dictionary = dna.nodes[13][Policy.KEY]; var declaration: Dictionary = context.cavities[0]
	report["selected_site_id"] = int(declaration.site_id); report["selected_rank"] = int(context.selection_decision.selected_rank)
	var selected: Dictionary = Policy.selected_site(plan,int(declaration.site_id))
	if not _check(report,not selected.has("error"),"declared_selected_site",selected): return _finish(report,ledger)
	var f0: RefCounted = budget.f0
	if not _check(report,f0 != null and _typed_digest(f0.source_dna)==budget.positive_identity and Policy.same(f0.source_dna,budget.positive_input),"immutable_F0_full_input_identity"): return _finish(report,ledger)
	if not _check(report,f0.preparation_errors.is_empty(),"F0_direct_grounded_preparation",{"errors":f0.preparation_errors.duplicate(),"adjustments":f0.geometry_adjustments.duplicate(true),"thin_features_preserved":int(f0.thin_features_preserved),"attachment_repairs":int(f0.attachment_repairs)}): return _finish(report,ledger)
	var f1: RefCounted = prepared_field
	if f1 == null: f1 = prepare(dna)
	elif not _check(report,Policy.same(_qualification_payload(f1.source_dna),_qualification_payload(dna)),"externally_prepared_F1_source_identity"): return _finish(report,ledger)
	report["externally_prepared_F1_reused"] = prepared_field != null
	if not _check(report,f1.preparation_errors.is_empty(),"F1_direct_grounded_preparation",{"errors":f1.preparation_errors.duplicate(),"adjustments":f1.geometry_adjustments.duplicate(true),"thin_features_preserved":int(f1.thin_features_preserved),"attachment_repairs":int(f1.attachment_repairs)}): return _finish(report,ledger)
	report["fields"] = {"F0":_field_summary(f0),"F1":_field_summary(f1)}
	var s0: Dictionary = report.fields.F0; var s1: Dictionary = report.fields.F1
	var unchanged: bool = Exact.typed_equal(s0.h,H) and Exact.typed_equal(s0.bounds,s1.bounds) and Exact.typed_equal(s0.h,s1.h) and Exact.typed_equal(s0.grid,s1.grid) and Exact.typed_equal(s0.body_halo,s1.body_halo) and Exact.typed_equal(s0.body_exterior,s1.body_exterior)
	if not _check(report,unchanged,"positive_bounds_H_grid_unchanged",{"F0":s0,"F1":s1}): return _finish(report,ledger)
	if not _check(report,int(s0.cavity_influences)==0 and int(s1.cavity_influences)==1 and int(s0.positive_influences)==int(s1.positive_influences) and int(s0.positive_influences)<=27,"actual_positive_and_one_cutter_operation",{"F0_positive":s0.positive_influences,"F1_positive":s1.positive_influences,"F1_cutters":s1.cavity_influences}): return _finish(report,ledger)
	var operations_ok: bool = true; var actual_cutters: Array = []
	for item: RefCounted in f1.influences:
		operations_ok = operations_ok and item.amplitude==0.0 and item.lip_radius==0.0 and item.contained_lip_radius==0.0
		if item.subtract:
			var id: String = str(f1.node_ids[item.node_index]); var cutter: Dictionary = _node(dna,id)
			actual_cutters.append(id)
			operations_ok = operations_ok and id=="n013" and not item.is_curve and item.position==Graph.vec(cutter.position) and item.radii==Graph.vec(cutter.size) and item.inverse_basis==Graph.node_basis(cutter).inverse() and float(item.blend)==float(cutter.blend)
	if not _check(report,operations_ok and actual_cutters==["n013"] and f1.lattice_collars.is_empty(),"no_noise_lips_direct_layers_or_repairs",{"actual_cutters":actual_cutters}): return _finish(report,ledger)
	var length: float = float(plan.frame.length); var wall: float = float(plan.wall_m)
	var center_crossing: Dictionary = _projection(f0,ledger,Graph.vec(selected.nominal),Graph.vec(plan.frame.normal),length,"selected_center_projection")
	if not _check(report,bool(center_crossing.ok),"selected_center_first_crossing",center_crossing): return _finish(report,ledger)
	var center_normal: Dictionary = _normal(f0,ledger,Graph.vec(center_crossing.point),Graph.vec(plan.frame.normal),"selected_center_normal")
	if not _check(report,bool(center_normal.ok),"selected_actual_chart_axis_normal",center_normal): return _finish(report,ledger)
	var reconstruction: Dictionary = Policy.local_frame(plan.frame,selected,center_crossing.point,center_normal.values)
	if not _check(report,bool(reconstruction.get("ok",false)) and Policy.same(reconstruction.get("local_frame"),declaration.local_frame),"exact_replayed_local_frame",reconstruction): return _finish(report,ledger)
	if not _check(report,int(center_crossing.calls)==int(context.author_projection_field_calls) and int(center_crossing.calls)<=79 and int(context.author_normal_field_calls)==6 and int(context.author_complete_field_calls)==int(center_crossing.calls)+6,"exact_selected_center_request_counts",{"projection":center_crossing.calls,"normal":6,"total":ledger.calls}): return _finish(report,ledger)
	report["center_crossings"] = [center_crossing]; report["center_normals"] = [center_normal]; report["local_frames"] = [reconstruction.local_frame]
	report["author_projection_field_calls"] = int(center_crossing.calls); report["author_normal_field_calls"] = 6; report["author_complete_field_calls"] = int(center_crossing.calls)+6
	var node: Dictionary = _node(dna,"n013")
	var basis: Basis = Graph.node_basis(node); var axis: Vector3 = basis.z
	var center: Vector3 = Graph.vec(node.position); var radii: Vector3 = Graph.vec(node.size)
	var domain: Dictionary = actual_domain(plan,declaration)
	if not _check(report,bool(domain.ok) and int(domain.sample_count)==12,"n013_actual_padded_ellipsoid_territory",domain): return _finish(report,ledger)
	var projected_hit: Vector3 = Graph.vec(center_crossing.point)
	var expected_center: Vector3 = projected_hit-0.48*float(declaration.radii_m[2])*axis
	if not _check(report,center==expected_center and Exact.typed_equal(declaration.surface_hit,center_crossing.point),"exact_projected_center_n013",{"center":_arr(center),"expected":_arr(expected_center),"crossing":center_crossing}): return _finish(report,ledger)
	var cavity: Dictionary = {"node_id":node.id,"feature_id":node.feature_id,"center":_arr(center),"radii":_arr(radii),"axis":_arr(axis),"mouths":[]}
	report.cavities.append(cavity)
	for ray_index: int in range(13):
		var phase: String = "n013_mouth_"+str(ray_index)
		var projection: Dictionary = center_crossing
		if ray_index > 0:
			var angle: float = TAU*float(ray_index-1)/12.0
			var nominal: Vector3 = projected_hit+basis*Vector3(0.75*radii.x*cos(angle),0.75*radii.y*sin(angle),0.0)
			projection = _projection(f0,ledger,nominal,axis,length,phase+"_projection")
		var mouth: Dictionary = {"index":ray_index,"baseline_crossing":projection,"required_depth_m":2.0*H if ray_index==0 else H}
		cavity.mouths.append(mouth)
		if not _check(report,bool(projection.ok),phase+"_first_F0_crossing",projection): return _finish(report,ledger)
		var hit: Vector3 = Graph.vec(projection.point)
		var normal: Dictionary = _normal_from_values(center_normal.values,axis) if ray_index==0 else _normal(f0,ledger,hit,axis,phase+"_normal")
		if ray_index==0:
			normal["reused_author_center_normal"] = true; normal["additional_field_calls"] = 0
			mouth["center_projection_role"] = "first_crossing_along_actual_chart_axis"
		mouth["normal"] = normal
		if not _check(report,bool(normal.ok),phase+"_baseline_axis_alignment",normal): return _finish(report,ledger)
		var owner: Dictionary = _ownership(f0,ledger,hit); mouth["owner"] = owner
		if not _check(report,bool(owner.ok),phase+"_exact_n000_ownership",owner): return _finish(report,ledger)
		var inward: Dictionary = _inward(f1,ledger,hit,axis,float(declaration.radii_m[2]),phase+"_inward"); mouth["inward_crossing"] = inward
		if not _check(report,bool(inward.ok),phase+"_first_F1_tissue_entry",inward): return _finish(report,ledger)
		mouth["depth_m"] = inward.depth_m
		if not _check(report,is_finite(float(inward.depth_m)) and float(inward.depth_m)>=float(mouth.required_depth_m),phase+"_blind_depth",mouth): return _finish(report,ledger)
	var minor_a: Vector3 = Graph.vec(cavity.mouths[1].baseline_crossing.point)
	var minor_b: Vector3 = Graph.vec(cavity.mouths[7].baseline_crossing.point)
	var delta: Vector3 = minor_a-minor_b
	var span: float = (delta-axis*delta.dot(axis)).length()
	cavity["minor_open_span_m"] = span; cavity["minor_open_span_required_m"] = 3.0*H
	if not _check(report,is_finite(span) and span>=3.0*H,"n013_actual_transverse_open_span",{"span_m":span,"required_m":3.0*H,"opposite_ray_indices":[1,7]}): return _finish(report,ledger)
	var thickness: Dictionary = _thickness(f0,ledger,projected_hit,axis,length,float(declaration.radii_m[2]),wall,"n013_thickness"); cavity["thickness"] = thickness
	if not _check(report,bool(thickness.ok),"n013_conservative_first_exit_thickness",thickness): return _finish(report,ledger)
	# Always retain BOTH complete177-row sets, even if the first shell fails.
	var shell0: Dictionary = _shell(f0,ledger,center,basis,radii,wall,"F0","n013_shell_F0")
	var shell1: Dictionary = _shell(f1,ledger,center,basis,radii,wall,"F1","n013_shell_F1")
	cavity["shell_f0"] = shell0; cavity["shell_f1"] = shell1
	# Existing material consumer calls its cut-field shell_f2; this is one cutter.
	cavity["shell_f2"] = shell1
	var shell0_ok: bool = _check(report,bool(shell0.ok) and int(shell0.sample_count)==177 and int(shell0.unique_positions)==153,"n013_complete_F0_shell_back_disk",shell0)
	var shell1_ok: bool = _check(report,bool(shell1.ok) and int(shell1.sample_count)==177 and int(shell1.unique_positions)==153,"n013_complete_F1_shell_back_disk",shell1)
	cavity["logical_requests"] = ledger.calls; cavity["complete_field_calls"] = ledger.executed_values; cavity["complete_field_cap"] = CAVITY_CAP
	if not shell0_ok or not shell1_ok: return _finish(report,ledger)
	if not _check(report,ledger.calls<=CAVITY_CAP,"n013_complete_field_budget",{"logical_requests":ledger.calls,"executed_complete_values":ledger.executed_values,"cap":CAVITY_CAP}): return _finish(report,ledger)
	var counter: SacCounter = SacCounter.new(f1,ledger)
	var sac: Dictionary = SacQualification.evaluate(counter); var plain_sac: Dictionary = _plain(sac); report["existing_sac_qualification"] = plain_sac
	report["existing_sac_complete_field_calls"] = counter.calls
	if not _check(report,not counter.overflow and counter.calls <= 2190,"existing_sac_field_budget",{"calls":counter.calls,"cap":2190,"overflow":counter.overflow}): return _finish(report,ledger)
	if not _check(report,bool(sac.get("ok",false)),"unchanged_sac_root_and_six_fold_sections",plain_sac): return _finish(report,ledger)
	var root_samples: int = 0; var sections: int = 0; var active_sections: int = 0; var layout: bool = sac.roots.size() == 3 and sac.features.size() == 3 and sac.cavity_channels.is_empty()
	for root: Dictionary in sac.roots: root_samples += int(root.sample_count)
	for feature: Dictionary in sac.features:
		sections += feature.sections.size(); active_sections += int(feature.active_sections)
		layout = layout and feature.owner_id in ["n007","n008","n009"] and feature.sections.size() == (0 if feature.owner_id == "n009" else 3)
		for index: int in range(feature.sections.size()):
			var section: Dictionary = feature.sections[index]
			layout = layout and int(section.crease) == 0 and float(section.station) == [-0.20,0.10,0.40][index]
	if not _check(report,layout and root_samples == 78 and sections == 6 and active_sections == 6,"unchanged_complete_sac_witness_layout",{"root_samples":root_samples,"sections":sections,"active_sections":active_sections}): return _finish(report,ledger)
	# Separate inherited51 mapped-root witnesses, even though the same17-path
	# positions also occur in the2190-call retained root/section evaluator.
	for id: String in ["n007","n008","n009"]:
		var path_node: Dictionary = _node(dna,id); var parent: Dictionary = _node(dna,str(path_node.parent)); var group: RefCounted = null
		for item: RefCounted in f1.influences:
			if f1.node_ids[item.node_index] == id: group = item.sac_group; break
		if not _check(report,group != null,"mapped_root_group_"+id): return _finish(report,ledger)
		var samples: Array = []; var maximum: float = -INF; var valid: bool = true
		for index: int in range(17):
			var rest: Vector3 = Graph.vec(parent.position).lerp(Graph.vec(path_node.position),float(index)/16.0)
			var point: Vector3 = group.forward(rest); var value: float = ledger.value(f1,point,"F1","mapped_root_paths")
			samples.append({"index":index,"rest":_arr(rest),"point":_arr(point),"value":value})
			valid = valid and is_finite(value) and value <= -0.12*float(f1.step)
			if is_finite(value): maximum = maxf(maximum,value)
		var row: Dictionary = {"node_id":id,"feature_id":path_node.feature_id,"samples":samples,"maximum_field":maximum,"required_maximum":-0.12*float(f1.step),"ok":valid}; report.mapped_root_paths.append(row)
		if not _check(report,valid,"mapped_root_path_"+id,row): return _finish(report,ledger)
	var body: RefCounted = _body(f1)
	for id: String in ["n005","n006"]:
		var support: Dictionary = _node(dna,id); var root: Vector3 = Graph.vec(support.points[0]); var before: int = int(body.geometry_evaluations)
		var value: float = body.distance(root); var weights: Array = body.weights(root)
		ledger.analytic_support_component_reads += int(body.geometry_evaluations)-before
		var index: int = body.member_ids.find(str(support.parent)); var required: float = 0.20*float(support.radii[0])
		var weight: float = float(weights[index]) if index >= 0 and index < weights.size() else NAN
		var row: Dictionary = {"node_id":id,"parent_id":support.parent,"point":_arr(root),"distance":value,"required_burial_m":required,"named_parent_weight":weight}; report.supports.append(row)
		if not _check(report,index >= 0 and is_finite(value) and value <= -required and is_finite(weight) and weight > 0.0,"original_support_burial_"+id,row): return _finish(report,ledger)
	var balls: Dictionary = _support_balls(dna,declaration,wall,ledger)
	report.support_control_balls = balls.rows
	for witness: Dictionary in balls.rows:
		var valid_ball: bool = is_finite(float(witness.analytic_cutter_distance)) and float(witness.analytic_cutter_distance)>=float(witness.required_minimum)
		if not _check(report,valid_ball,"support_control_ball_n013_"+str(witness.support_id)+"_"+str(witness.control_index),witness): return _finish(report,ledger)
	if not _check(report,bool(balls.ok) and report.support_control_balls.size()==6 and ledger.owner_locations==13 and not ledger.overflow and ledger.calls<=TRIAL_CAP,"fixed_single_complete_accounting",{"support_control_balls":report.support_control_balls.size(),"owner_locations":ledger.owner_locations,"logical_requests":ledger.calls,"executed_complete_values":ledger.executed_values,"cap":TRIAL_CAP}): return _finish(report,ledger)
	return _finish(report,ledger)

static func _failure_count(report: Dictionary, outcome: Dictionary, phase: String) -> void:
	if not outcome.has("first_failure"): return
	var key: String = phase+":"+str(outcome.first_failure.get("check","unknown"))
	report.first_failure_counts[key] = int(report.first_failure_counts.get(key,0))+1

static func _selection_finish(report: Dictionary, budget: Budget) -> Dictionary:
	report["accounting"] = budget.accounting()
	var screen_requests: int = 0; var trial_requests: int = 0
	var screen_executed: int = 0; var trial_executed: int = 0
	var component_reads: int = 0; var support_reads: int = 0; var ball_reads: int = 0
	for phase: String in ["candidates","trials"]:
		for row: Dictionary in report[phase]:
			var accounting: Dictionary = row.get("accounting",{})
			if phase=="candidates":
				screen_requests += int(accounting.get("logical_requests",0)); screen_executed += int(accounting.get("executed_complete_values",0))
			else:
				trial_requests += int(accounting.get("logical_requests",0)); trial_executed += int(accounting.get("executed_complete_values",0))
			component_reads += int(accounting.get("query_body_component_reads",0))+int(accounting.get("owner_body_component_reads",0))
			support_reads += int(accounting.get("analytic_support_component_reads",0)); ball_reads += int(accounting.get("analytic_support_control_ball_reads",0))
	report.accounting["screens_logical_requests"] = screen_requests; report.accounting["screens_logical_cap"] = 4134
	report.accounting["trials_logical_requests"] = trial_requests; report.accounting["trials_logical_cap"] = 13218
	report.accounting["screens_executed_complete_values"] = screen_executed; report.accounting["trials_executed_complete_values"] = trial_executed
	report.accounting["query_and_owner_body_component_reads"] = component_reads; report.accounting["analytic_support_component_reads"] = support_reads; report.accounting["analytic_support_control_ball_reads"] = ball_reads
	report.accounting["component_reads_are_not_complete_field_values"] = true
	if budget.overflow or screen_requests>4134 or trial_requests>13218 or budget.logical_requests>LOGICAL_CAP or budget.executed_values>COMPLETE_CAP:
		report["ok"] = false; report["first_failure"] = {"check":"aggregate_budget","witness":report.accounting.duplicate(true)}
	return report

static func _selection_failure(report: Dictionary, error: String, budget: Budget = null) -> Dictionary:
	report["ok"] = false; report["selection_failure"] = true; report["error"] = error
	if not report.has("first_failure"):
		report["first_failure"] = {"check":"selection_failure","witness":{"reason":error,"screened_sites":report.candidates.size(),"shortlisted_sites":report.shortlist.size(),"attempted_trials":report.trials.size()}}
	if budget != null: _selection_finish(report,budget)
	return {"ok":false,"error":error,"report":report,"cache":{}}

## Publication is the final operation, after all required finite witnesses pass.
static func author(dna: Dictionary) -> Dictionary:
	var report: Dictionary = {"ok":false,"method":"fixed223_primary_selection_v1","spec_sha256":Policy.PIN,"finite_sampling_only":true,"candidate_authorized":false,"global_optimum":false,"secondary_present":false,"bridge_present":false,"pair_goal_satisfied":false,"candidates":[],"shortlist":[],"trials":[],"first_failure_counts":{},"selected_site_id":-1,"selected_rank":0,"radius_fit_steps":0,"depth_fit_steps":0,"fallback_hosts":0}
	if not Policy.enabled(dna) or not dna.get("nodes") is Array or dna.nodes.size()!=13 or not dna.get("connections") is Array or dna.connections.size()!=12 or not dna.get("biological_blueprint") is Dictionary:
		return _selection_failure(report,"223 author requires explicit single-primary mode and untouched grounded13-node215 Stage5.")
	if not Blueprint.feature(dna.biological_blueprint,"blob.cavity.mantle_rear.primary").is_empty() or not Blueprint.feature(dna.biological_blueprint,"blob.cavity.mantle_rear.secondary").is_empty():
		return _selection_failure(report,"223 refuses pre-existing cavity intentions; selection is fresh authoring only.")
	var plan: Dictionary = placement(dna)
	if not plan.get("ok",false): return _selection_failure(report,str(plan.get("error","223 invalid fixed planning frame.")))
	var artifacts: GDScript = load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	var positive: Dictionary = Policy.positive_projection(dna)
	# This is newly authored, exact in-memory input, never a loaded JSON shadow.
	artifacts.seal_geometry_recipe(positive)
	var positive_key: String = artifacts.geometry_key(positive,5,Policy.DEPENDENCY4)
	if positive_key!=Policy.BASELINE_KEY:
		report["first_failure"] = {"check":"exact_positive215_key","witness":{"actual":positive_key,"expected":Policy.BASELINE_KEY}}
		return _selection_failure(report,"223 positive input is not the pinned exact215 baseline.")
	var f0: RefCounted = prepare(positive)
	var budget: Budget = _budget(positive,f0,true)
	report["preparation"] = _preparation_records.get(f0.get_instance_id(),{})
	if not f0.preparation_errors.is_empty():
		report["first_failure"] = {"check":"F0_direct_preparation","witness":{"errors":f0.preparation_errors.duplicate()}}
		return _selection_failure(report,"223 immutable F0 preparation rejected.",budget)
	var eligible: int = 0
	for site: Dictionary in plan.sites:
		var screened: Dictionary = _screen(dna,plan,site,budget)
		screened["status"] = "passed_screen" if bool(screened.ok) else "rejected_screen"
		report.candidates.append(screened); _failure_count(report,screened,"screen")
		if bool(screened.ok): eligible += 1
	if report.candidates.size()!=13: return _selection_failure(report,"223 requires exactly thirteen fixed site records.",budget)
	var shortlist: Array = ranked_shortlist(report.candidates)
	report.shortlist = shortlist.duplicate(true); report["eligible_count"] = eligible
	var ids: Array = []; var scores: Array = []
	for entry: Dictionary in shortlist: ids.append(int(entry.site_id)); scores.append(float(entry.score))
	for index: int in range(shortlist.size()):
		var site_id: int = int(shortlist[index].site_id)
		var decision: Dictionary = Policy.selection_decision(ids,scores,eligible,index+1)
		if not decision.get("ok",false): return _selection_failure(report,str(decision.get("error","223 invalid closed selection decision.")),budget)
		var selected: Dictionary = Policy.selected_site(plan,site_id)
		var screened: Dictionary = report.candidates[site_id]
		var candidate: Dictionary = _candidate_dna(dna,plan,selected,screened,decision.decision)
		if not candidate.get("ok",false): return _selection_failure(report,str(candidate.get("error","223 temporary candidate construction failed.")),budget)
		var trial: Dictionary = _run_trial(candidate.dna,budget)
		trial["trial_rank"] = index+1; trial["site_id"] = site_id
		report.trials.append(trial); _failure_count(report,trial,"trial")
		if not bool(trial.ok): continue
		report["ok"] = true; report["selected_site_id"] = site_id; report["selected_rank"] = index+1
		report["selected_qualification"] = trial.duplicate(true)
		_selection_finish(report,budget)
		if not report.ok: return _selection_failure(report,"223 aggregate accounting rejected the provisional winner.",budget)
		var published: Dictionary = candidate.dna
		var payload: Dictionary = _qualification_payload(published).duplicate(true)
		var cache: Dictionary = {"qualification":trial.duplicate(true),"qualification_digest":_typed_digest(trial),"geometry_key217":trial.geometry_key217,"fingerprint":_typed_digest(payload),"raw_order_fingerprint_diagnostic":_raw_fingerprint(published),"authored_payload":payload,"positive_dna":positive,"f0":f0,"f0_instance_id":f0.get_instance_id(),"selection_report":report.duplicate(true)}
		# Assign only after the exact selected single-void field is fully qualified.
		dna.clear(); dna.merge(published,true)
		return {"ok":true,"report":report,"cache":cache}
	return _selection_failure(report,"223 selection_failure: no fully valid candidate among the fixed top three; no fourth promotion or smooth fallback.",budget)

static func _cached_success(dna: Dictionary, cache: Dictionary, geometry_key: String) -> Dictionary:
	var payload: Dictionary = _qualification_payload(dna)
	var receipt: Variant = cache.get("qualification")
	var predicates: Dictionary = {"authored_payload_typed_exact":Policy.same(cache.get("authored_payload"),payload),"canonical_fingerprint_exact":Policy.same(cache.get("fingerprint"),_typed_digest(payload)),"geometry_key_exact":Policy.same(cache.get("geometry_key217"),geometry_key),"receipt_dictionary":receipt is Dictionary}
	if receipt is Dictionary:
		predicates["receipt_digest_exact"] = Policy.same(cache.get("qualification_digest"),_typed_digest(receipt))
		predicates["receipt_key_exact"] = Policy.same(receipt.get("geometry_key217"),geometry_key)
		predicates["receipt_success"] = receipt.get("ok") is bool and receipt.ok and not receipt.has("first_failure")
		predicates["receipt_method"] = Policy.text_is(receipt.get("method"),"fixed223_actual_tiled_single_qualification_v1") and Policy.text_is(receipt.get("spec_sha256"),Policy.PIN)
		predicates["receipt_selected_identity"] = receipt.get("selected_site_id") is int and receipt.get("selected_rank") is int and Policy.same(receipt.selected_site_id,dna.nodes[13][Policy.KEY].selection_decision.selected_site_id) and Policy.same(receipt.selected_rank,dna.nodes[13][Policy.KEY].selection_decision.selected_rank)
		var counts: Variant = receipt.get("accounting")
		predicates["receipt_budget"] = counts is Dictionary and counts.get("logical_requests") is int and counts.get("executed_complete_values") is int and counts.get("cache_hits") is int and counts.get("owner_locations") is int and counts.get("owner_influence_dispatches") is int and int(counts.logical_requests)>=0 and int(counts.cache_hits)>=0 and int(counts.executed_complete_values)>=0 and int(counts.owner_influence_dispatches)>=0 and int(counts.logical_requests)<=TRIAL_CAP and int(counts.executed_complete_values)<=TRIAL_CAP and int(counts.logical_requests)==int(counts.executed_complete_values)+int(counts.cache_hits) and int(counts.owner_locations)==13 and int(counts.owner_influence_dispatches)<=351 and not bool(counts.get("overflow",true))
		predicates["receipt_one_cavity"] = receipt.get("cavities") is Array and receipt.cavities.size()==1 and receipt.cavities[0] is Dictionary and Policy.text_is(receipt.cavities[0].get("node_id"),"n013") and receipt.cavities[0].get("mouths") is Array and receipt.cavities[0].mouths.size()==13
	var valid: bool = true
	for name: String in predicates: valid = valid and bool(predicates[name])
	return {"ok":valid,"predicates":predicates,"dictionary_order_is_semantic_identity":false,"additional_field_calls":0}

## Loaded/built selected DNA takes exactly one selected-candidate qualification.
## An exact runtime receipt returns directly without preparation or field reads.
static func qualify(dna: Dictionary, cache: Dictionary = {}, prepared_field: RefCounted = null) -> Dictionary:
	var report: Dictionary = _qualification_report()
	var declared: Dictionary = Policy.validate_restored(dna)
	if not _check(report,Policy.enabled(dna) and bool(declared.get("ok",false)),"restored_selected_declaration",declared):
		report["error"] = "223 selected declaration rejected."; return report
	var artifacts: GDScript = load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	var geometry_key: String = artifacts.geometry_key(dna,5,Policy.DEPENDENCY4)
	if not _check(report,not geometry_key.begins_with("invalid_recipe:"),"valid_selected_geometry_key",{"key":geometry_key}):
		report["error"] = "223 selected geometry key is invalid."; return report
	if not cache.is_empty():
		var identity: Dictionary = _cached_success(dna,cache,geometry_key)
		if not _check(report,bool(identity.ok),"runtime_successful_selected_receipt",identity):
			report["error"] = "223 runtime qualification cache identity mismatch; no hidden search."; return report
		var retained: Dictionary = cache.qualification.duplicate(true)
		retained["qualification_cache_reused"] = true; retained["cache_identity"] = identity
		retained["additional_field_calls"] = 0; retained["additional_logical_requests"] = 0
		return retained
	var positive: Dictionary = Policy.positive_projection(dna)
	var f0: RefCounted = prepare(positive)
	var budget: Budget = _budget(positive,f0,false)
	var selected_report: Dictionary = _run_trial(dna,budget,prepared_field)
	selected_report["qualification_cache_reused"] = false; selected_report["selection_repeated"] = false
	selected_report["aggregate_accounting"] = budget.accounting()
	return selected_report
