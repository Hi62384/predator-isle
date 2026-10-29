extends RefCounted
## Fixed217 declaration, direct grounded preparation, and bounded finite witnesses.
## No search, alternative host, shrink, depth fitting, lattice, mesh, or renderer.
## Runtime Objects live only in the returned cache, never the DNA or report.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobMantleCavityPolicy217.gd")
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
const COMPLETE_CAP: int = 6971
const AUTHOR_CAP: int = 158
const OWNER_DISPATCH_CAP: int = 837
const TABLE: Array = [
	{"role":"primary", "node_id":"n013", "feature_id":"blob.cavity.mantle_rear.primary", "radii_over_L":[0.185,0.3,0.52], "roll_radians":1.15},
	{"role":"secondary", "node_id":"n014", "feature_id":"blob.cavity.mantle_rear.secondary", "radii_over_L":[0.17,0.235,0.45], "roll_radians":1.85}
]
const SHELL_DEPTHS: Array = [0.12,0.0,-0.25,-0.5,-0.75,-0.9,-1.0]
const BRIDGE_FRACTIONS: Array = [0.1,0.3,0.5,0.7,0.9]

class Ledger extends RefCounted:
	var records: Array = []
	var calls: int = 0
	var cap: int = 6971
	var overflow: bool = false
	var by_phase: Dictionary = {}
	var owner_influence_dispatches: int = 0
	var owner_body_component_reads: int = 0
	var query_body_component_reads: int = 0
	var analytic_support_component_reads: int = 0
	var analytic_support_control_ball_reads: int = 0
	var owner_locations: int = 0
	func value(field: RefCounted, point: Vector3, field_name: String, phase: String) -> float:
		if calls >= cap:
			overflow = true
			return NAN
		var body: RefCounted = null
		for item: RefCounted in field.influences:
			if item.body_envelope != null: body = item.body_envelope; break
		var before: int = int(body.geometry_evaluations) if body != null else 0
		var result: float = field._continuous_extraction_value(point)
		if body != null: query_body_component_reads += int(body.geometry_evaluations) - before
		calls += 1
		by_phase[phase] = int(by_phase.get(phase, 0)) + 1
		records.append({"field":field_name,"phase":phase,"point":[point.x,point.y,point.z],"value":result})
		return result
	func accounting() -> Dictionary:
		return {"complete_field_calls":calls,"complete_field_cap":cap,"overflow":overflow,"by_phase":by_phase.duplicate(true),"owner_influence_dispatches":owner_influence_dispatches,"owner_dispatch_cap":837,"owner_body_component_reads":owner_body_component_reads,"query_body_component_reads":query_body_component_reads,"analytic_support_component_reads":analytic_support_component_reads,"analytic_support_control_ball_reads":analytic_support_control_ball_reads,"owner_locations":owner_locations,"component_reads_are_not_complete_field_values":true}

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
		# Existing evaluator chooses the exact positions and temporarily zeroes a
		# sac amplitude for contrast. The actual production tile is authoritative.
		if calls >= 2190 or not apply_noise or not apply_cavities or not apply_contained_lips:
			overflow = true
			return NAN
		calls += 1
		return ledger.value(source, point, "F2", "existing_sac_root_sections")

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
static func _fingerprint(dna: Dictionary) -> String: return var_to_bytes(_cache_payload(dna)).hex_encode().sha256_text()
static func _body(field: RefCounted) -> RefCounted:
	for item: RefCounted in field.influences:
		if item.body_envelope != null: return item.body_envelope
	return null

## Pure source arithmetic. Policy owns canonical frame/table scalars so saved
## declarations and authoring cannot diverge through arithmetic reordering.
static func placement(dna: Dictionary) -> Dictionary:
	var result: Dictionary = Policy.frame_table(dna)
	if result.has("error"): result["ok"] = false; return result
	var frame: Dictionary = result.frame
	var origin: Vector3 = Graph.vec(frame.origin); var tangent: Vector3 = Graph.vec(frame.tangent); var bitangent: Vector3 = Graph.vec(frame.bitangent)
	var length: float = float(frame.length); var wall: float = float(result.wall_m)
	var extent: Vector2 = Vector2(float(result.territory_half_extents_m[0]),float(result.territory_half_extents_m[1]))
	var territory: Basis = Basis(tangent,bitangent,Graph.vec(frame.normal))
	if not _basis_ok(territory): return {"ok":false,"error":"217 degenerate canonical territory basis."}
	for row: Dictionary in result.cavities:
		var offset: Vector2 = Vector2(float(row.offset_m[0]),float(row.offset_m[1]))
		var radii: Vector3 = Graph.vec(row.radii_m)
		var basis: Basis = Graph.node_basis({"rotation":row.rotation})
		var intended: Basis = territory * Basis(Vector3.BACK,float(row.roll_radians))
		if not _basis_ok(basis) or not basis.is_equal_approx(intended): return {"ok":false,"error":"217 invalid consumed Euler reconstruction; no alternate axis."}
		if minf(radii.x,radii.y) < float(result.feature_radius_m) or radii.z < 1.3*minf(radii.x,radii.y) or radii.z > 0.64*length: return {"ok":false,"error":"217 fixed table violates feature/depth floors."}
		row["nominal"] = _arr(origin+tangent*offset.x+bitangent*offset.y)
		var domain: Array = []
		for j: int in range(12):
			var angle: float = TAU*float(j)/12.0
			var rim: Vector2 = offset+Vector2(cos(angle)*(radii.x+wall),sin(angle)*(radii.y+wall)).rotated(float(row.roll_radians))
			var ratio: float = (rim/extent).length_squared()
			domain.append({"index":j,"point":[rim.x,rim.y],"normalized_radius_squared":ratio})
			if not is_finite(ratio) or ratio > 1.0: return {"ok":false,"error":"217 fixed table fails inherited twelve-point territory test.","node_id":row.node_id,"domain":domain}
		row["domain"] = domain
	return result

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
	if field.thin_features_preserved > 0 or field.attachment_repairs > 0: field.preparation_errors.append("217 direct preparation forbids geometry repairs.")
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

static func author(dna: Dictionary) -> Dictionary:
	var report: Dictionary = {"ok":false,"method":"fixed217_authoring_v1","finite_sampling_only":true,"search_attempts":0,"shrink_steps":0,"depth_fit_steps":0,"fallback_hosts":0,"candidate_authorized":false,"center_crossings":[],"complete_values":[]}
	if not Policy.enabled(dna) or not dna.get("nodes") is Array or dna.nodes.size() != 13 or not dna.get("biological_blueprint") is Dictionary: return {"ok":false,"error":"217 author requires explicit mode and fully grounded annotated13-node215 Stage5.","report":report,"cache":{}}
	var plan: Dictionary = placement(dna)
	if not plan.ok: return {"ok":false,"error":plan.error,"report":plan,"cache":{}}
	var blueprint: Dictionary = dna.biological_blueprint
	for index: int in range(2):
		var row: Dictionary = plan.cavities[index]
		if not Blueprint.feature(blueprint,str(row.feature_id)).is_empty(): return {"ok":false,"error":"217 refuses duplicate cavity declaration.","report":report,"cache":{}}
		var recipe: Dictionary = {"version":1,"mode":Policy.MODE,"spec_sha256":Policy.PIN,"role":row.role,"parent_node_id":"n000","carrier_feature_id":"blob.body.core","radii_over_L":TABLE[index].radii_over_L.duplicate(),"roll_radians":row.roll_radians}
		Blueprint.declare(blueprint,str(row.feature_id),"cavity","blob.body.core",5,Basis.from_euler(Graph.vec(row.rotation)).z,recipe)
	# Both intentions exist before the first crossing. Projection strips them
	# from F0, including the core's children, rather than changing215 inputs.
	var positive: Dictionary = Policy.positive_projection(dna)
	var f0: RefCounted = prepare(positive)
	report["preparation"] = _preparation_records.get(f0.get_instance_id(), {})
	var ledger: Ledger = Ledger.new(); ledger.cap = AUTHOR_CAP
	if not f0.preparation_errors.is_empty(): report["preparation_errors"] = f0.preparation_errors.duplicate(); return {"ok":false,"error":"217 F0 preparation rejected.","report":report,"cache":{}}
	var context: Dictionary = {"version":1,"mode":Policy.MODE,"spec_sha256":Policy.PIN,"coordinate_space":"grounded_geometry_input","partial_stage":5,"positive_node_ids":[],"cavity_node_ids":["n013","n014"],"carrier_feature_id":"blob.body.core","frame":plan.frame.duplicate(true),"reference_cell_m":H,"feature_radius_m":plan.feature_radius_m,"wall_m":plan.wall_m,"territory_half_extents_m":plan.territory_half_extents_m.duplicate(),"pair_separation_m":plan.pair_separation_m,"cavities":[],"author_complete_field_calls":0}
	for node: Dictionary in positive.nodes: context.positive_node_ids.append(node.id)
	var centers: Array = []
	for row: Dictionary in plan.cavities:
		var axis: Vector3 = Basis.from_euler(Graph.vec(row.rotation)).z
		var crossing: Dictionary = _projection(f0,ledger,Graph.vec(row.nominal),axis,float(plan.frame.length),"author_center_projection")
		centers.append(crossing); report.center_crossings.append(crossing.duplicate(true))
		if not crossing.ok:
			report["complete_values"] = ledger.records; report["accounting"] = ledger.accounting(); report["first_failure"] = {"check":"center_first_crossing","node_id":row.node_id,"witness":crossing}
			return {"ok":false,"error":"217 fixed center projection failed; no retry.","report":report,"cache":{}}
		var center: Vector3 = Graph.vec(crossing.point) - 0.48 * float(row.radii_m[2]) * axis
		var saved: Dictionary = {"role":row.role,"node_id":row.node_id,"feature_id":row.feature_id,"offset_m":row.offset_m.duplicate(),"radii_m":row.radii_m.duplicate(),"roll_radians":row.roll_radians,"rotation":row.rotation.duplicate(),"surface_hit":crossing.point.duplicate(),"center":_arr(center)}
		context.cavities.append(saved)
	context.author_complete_field_calls = ledger.calls
	# Append only after BOTH fixed crossings have succeeded.
	for row: Dictionary in context.cavities:
		var node: Dictionary = NodeData.make(str(row.node_id),"n000","cavity","cavity",row.center.duplicate(),row.radii_m.duplicate(),"muscle")
		node.merge({"rotation":row.rotation.duplicate(),"bone":false,"operation":"subtract","blend":0.025*float(plan.frame.length),"noise":0.0,"surface_opening":false,"normal":_arr(Basis.from_euler(Graph.vec(row.rotation)).z),"blob_region":"mantle_blind_chamber","source":"fixed217_mantle_blind_chambers_v1"},true)
		node["porous_growth"] = {"minimum_wall":plan.wall_m,"host_thickness":0.0,"complete_rim":false,"back_wall":false,"containment_method":"fixed217_finite_pending","burial_ratio":0.48,"metrics_space":"grounded_geometry_input"}
		node[Policy.KEY] = context.duplicate(true)
		Blueprint.bind_node(blueprint,str(row.feature_id),node,5); dna.nodes.append(node)
		dna.connections.append(ConnectionData.make("n000",str(row.node_id),"growth",float(node.blend)))
	dna.metadata[Policy.KEY] = context.duplicate(true)
	Blueprint.annotate_snapshot(dna,blueprint,5)
	report.merge({"ok":true,"context":context.duplicate(true),"complete_values":ledger.records.duplicate(true),"accounting":ledger.accounting()},true)
	var cache: Dictionary = {"positive_dna":positive,"f0":f0,"centers":centers,"author_records":ledger.records.duplicate(true),"author_complete_field_calls":ledger.calls,"author_component_reads":ledger.query_body_component_reads,"fingerprint":_fingerprint(dna),"authored_payload":_cache_payload(dna).duplicate(true)}
	return {"ok":true,"report":report,"cache":cache}

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
static func _finish(report: Dictionary, ledger: Ledger) -> Dictionary:
	report["accounting"] = ledger.accounting(); report["complete_values"] = ledger.records
	report["ok"] = not report.has("first_failure") and not ledger.overflow
	report["error"] = "Fixed217 finite qualification failed; no search, nudge or fallback." if not report.ok else ""
	return report

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
	if ledger.owner_influence_dispatches + dispatches > OWNER_DISPATCH_CAP: return {"ok":false,"error":"217 ownership influence dispatch cap exceeded."}
	var before: int = int(body_item.body_envelope.geometry_evaluations)
	var actual: Dictionary = field._body_group_component_partition(point,relevant,body_item)
	var component_reads: int = int(body_item.body_envelope.geometry_evaluations) - before
	ledger.owner_influence_dispatches += dispatches; ledger.owner_body_component_reads += component_reads; ledger.owner_locations += 1
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
	for value: float in values:
		if not is_finite(value): return {"ok":false,"values":values,"epsilon_m":e,"error":"Nonfinite F0 normal witness."}
	var gradient: Vector3 = Vector3(float(values[0])-float(values[1]),float(values[2])-float(values[3]),float(values[4])-float(values[5]))
	if not gradient.is_finite() or gradient.length_squared() <= 0.0: return {"ok":false,"values":values,"epsilon_m":e,"error":"Zero/nonfinite F0 finite-difference gradient."}
	var normal: Vector3 = gradient.normalized(); var dot_axis: float = normal.dot(axis)
	return {"ok":is_finite(dot_axis) and dot_axis >= 0.72,"normal":_arr(normal),"axis_dot":dot_axis,"required_minimum":0.72,"epsilon_m":e,"values":values}

static func _inward(field: RefCounted, ledger: Ledger, hit: Vector3, axis: Vector3, depth: float, phase: String) -> Dictionary:
	var before: int = ledger.calls
	var air: float = ledger.value(field,hit,"F2",phase)
	var result: Dictionary = {"ok":false,"air_start_value":air,"air_start_minimum":0.1*H,"scan_intervals":32,"bisections_max":16,"reach_m":2.0*depth,"scalar_residual_is_metric_distance":false}
	if not is_finite(air) or air < 0.1*H: result["error"] = "F2 mouth does not start in required air."; result["calls"] = ledger.calls-before; return result
	var outside: Vector3 = hit; var outside_value: float = air
	for i: int in range(1,33):
		var inside: Vector3 = hit-axis*(2.0*depth*float(i)/32.0)
		var inside_value: float = ledger.value(field,inside,"F2",phase)
		if not is_finite(inside_value): result.merge({"error":"Nonfinite F2 inward march.","point":_arr(inside),"value":inside_value,"calls":ledger.calls-before},true); return result
		if inside_value <= 0.0:
			var exact: bool = inside_value == 0.0; var performed: int = 0
			for j: int in range(16):
				if exact: break
				var midpoint: Vector3 = outside.lerp(inside,0.5)
				if midpoint == outside or midpoint == inside: result.merge({"error":"F2 midpoint is not representably distinct.","outside":_arr(outside),"inside":_arr(inside),"outside_value":outside_value,"inside_value":inside_value,"calls":ledger.calls-before},true); return result
				var value: float = ledger.value(field,midpoint,"F2",phase)
				performed += 1
				if not is_finite(value): result.merge({"error":"Nonfinite F2 inward bisection.","point":_arr(midpoint),"value":value,"calls":ledger.calls-before},true); return result
				if value <= 0.0: inside = midpoint; inside_value = value; exact = value == 0.0
				else: outside = midpoint; outside_value = value
			var point: Vector3 = inside if exact else outside.lerp(inside,0.5)
			var residual: float = ledger.value(field,point,"F2",phase)
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

static func qualify(dna: Dictionary, cache: Dictionary = {}, prepared_f2: RefCounted = null) -> Dictionary:
	var report: Dictionary = {"ok":false,"method":"fixed217_actual_tiled_finite_qualification_v1","finite_sampling_only":true,"global_clearance_proof":false,"global_self_intersection_proof":false,"continuous_mouth_outline_proof":false,"candidate_authorized":false,"lattice_samples":0,"mesh_builds":0,"search_attempts":0,"shrink_steps":0,"depth_fit_steps":0,"fallback_hosts":0,"checks":[],"cavities":[],"bridge":{},"mapped_root_paths":[],"supports":[],"support_control_balls":[],"complete_values":[]}
	var ledger: Ledger = Ledger.new()
	report["spec_sha256"] = Policy.PIN
	if not _check(report,Policy.enabled(dna),"explicit217_qualification_mode"): return _finish(report,ledger)
	var declared: Dictionary = Policy.validate_restored(dna)
	if not _check(report,bool(declared.get("ok",false)),"restored_declaration",declared): return _finish(report,ledger)
	var artifacts: Variant = load("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
	report["geometry_key217"] = artifacts.geometry_key(dna,5,Policy.DEPENDENCY4)
	if not _check(report,not str(report.geometry_key217).begins_with("invalid_recipe:"),"valid_consumed_geometry_key",{"key":report.geometry_key217}): return _finish(report,ledger)
	var positive: Dictionary = Policy.positive_projection(dna)
	var plan: Dictionary = placement(dna)
	if not _check(report,bool(plan.get("ok",false)),"fixed_parameter_table",plan): return _finish(report,ledger)
	var context: Dictionary = dna.nodes[13][Policy.KEY]
	var f0: RefCounted = null
	var centers: Array = []
	var reused: bool = not cache.is_empty()
	if reused:
		var valid_cache: bool = cache.get("f0") is RefCounted and cache.get("centers") is Array and cache.centers.size() == 2 and cache.get("author_records") is Array and cache.get("author_complete_field_calls") is int and int(cache.author_complete_field_calls) <= AUTHOR_CAP and Policy.same(cache.get("authored_payload"),_cache_payload(dna)) and Policy.same(_cache_payload(cache.get("positive_dna", {})),_cache_payload(positive))
		if not _check(report,valid_cache,"runtime_author_cache_identity",{"reused":true,"valid":valid_cache}): return _finish(report,ledger)
		f0 = cache.f0; centers = cache.centers.duplicate(true)
		ledger.calls = int(cache.author_complete_field_calls); ledger.records = cache.author_records.duplicate(true); ledger.by_phase["author_center_projection"] = ledger.calls; ledger.query_body_component_reads = int(cache.get("author_component_reads",0))
		if not _check(report,ledger.records.size() == ledger.calls,"runtime_author_cache_call_records",{"calls":ledger.calls,"records":ledger.records.size()}): return _finish(report,ledger)
	else:
		f0 = prepare(positive)
	if not _check(report,f0.preparation_errors.is_empty(),"F0_direct_grounded_preparation",{"errors":f0.preparation_errors.duplicate(),"adjustments":f0.geometry_adjustments.duplicate(true),"thin_features_preserved":int(f0.thin_features_preserved),"attachment_repairs":int(f0.attachment_repairs)}): return _finish(report,ledger)
	var f2: RefCounted = prepared_f2
	if f2 == null: f2 = prepare(dna)
	elif not _check(report,Policy.same(_cache_payload(f2.source_dna),_cache_payload(dna)),"externally_prepared_F2_source_identity"): return _finish(report,ledger)
	report["externally_prepared_F2_reused"] = prepared_f2 != null
	if not _check(report,f2.preparation_errors.is_empty(),"F2_direct_grounded_preparation",{"errors":f2.preparation_errors.duplicate(),"adjustments":f2.geometry_adjustments.duplicate(true),"thin_features_preserved":int(f2.thin_features_preserved),"attachment_repairs":int(f2.attachment_repairs)}): return _finish(report,ledger)
	report["fields"] = {"F0":_field_summary(f0),"F2":_field_summary(f2)}
	var s0: Dictionary = report.fields.F0; var s2: Dictionary = report.fields.F2
	var unchanged: bool = Exact.typed_equal(s0.h,H) and Exact.typed_equal(s0.bounds,s2.bounds) and Exact.typed_equal(s0.h,s2.h) and Exact.typed_equal(s0.grid,s2.grid) and Exact.typed_equal(s0.body_halo,s2.body_halo) and Exact.typed_equal(s0.body_exterior,s2.body_exterior)
	if not _check(report,unchanged,"positive_bounds_H_grid_unchanged",{"F0":s0,"F2":s2}): return _finish(report,ledger)
	if not _check(report,int(s0.cavity_influences) == 0 and int(s2.cavity_influences) == 2 and int(s0.positive_influences) == int(s2.positive_influences) and int(s0.positive_influences) <= 27,"actual_positive_and_two_cutter_operations",{"F0_positive":s0.positive_influences,"F2_positive":s2.positive_influences,"F2_cutters":s2.cavity_influences}): return _finish(report,ledger)
	var operations_ok: bool = true; var actual_cutters: Array = []
	for item: RefCounted in f2.influences:
		operations_ok = operations_ok and item.amplitude == 0.0 and item.lip_radius == 0.0 and item.contained_lip_radius == 0.0
		if item.subtract:
			var id: String = str(f2.node_ids[item.node_index]); var cutter: Dictionary = _node(dna,id)
			actual_cutters.append(id)
			operations_ok = operations_ok and id in ["n013","n014"] and not item.is_curve and item.position == Graph.vec(cutter.position) and item.radii == Graph.vec(cutter.size) and item.inverse_basis == Graph.node_basis(cutter).inverse() and float(item.blend) == float(cutter.blend)
	if not _check(report,operations_ok and actual_cutters == ["n013","n014"] and f2.lattice_collars.is_empty(),"no_noise_lips_direct_layers_or_repairs",{"actual_cutters":actual_cutters}): return _finish(report,ledger)
	var length: float = float(plan.frame.length); var wall: float = float(plan.wall_m)
	if not reused:
		for row: Dictionary in plan.cavities:
			var crossing: Dictionary = _projection(f0,ledger,Graph.vec(row.nominal),Graph.node_basis(_node(dna,str(row.node_id))).z,length,"author_center_projection")
			centers.append(crossing)
			if not _check(report,bool(crossing.ok),"independent_center_first_crossing_"+str(row.node_id),crossing): return _finish(report,ledger)
	report["author_cache_reused"] = reused
	report["author_complete_field_calls"] = int(ledger.by_phase.get("author_center_projection",0))
	if not _check(report,int(report.author_complete_field_calls) == int(context.author_complete_field_calls) and int(report.author_complete_field_calls) <= AUTHOR_CAP,"exact_retained_center_projection_count",{"actual":report.author_complete_field_calls,"declared":context.author_complete_field_calls,"cap":AUTHOR_CAP}): return _finish(report,ledger)
	for cavity_index: int in range(2):
		var cavity_before: int = ledger.calls
		var declaration: Dictionary = context.cavities[cavity_index]
		var node: Dictionary = _node(dna,str(declaration.node_id))
		var basis: Basis = Graph.node_basis(node); var axis: Vector3 = basis.z
		var center: Vector3 = Graph.vec(node.position); var radii: Vector3 = Graph.vec(node.size)
		var center_crossing: Dictionary = centers[cavity_index]
		var projected_hit: Vector3 = Graph.vec(center_crossing.point)
		var expected_center: Vector3 = projected_hit-0.48*float(declaration.radii_m[2])*axis
		if not _check(report,center == expected_center and Exact.typed_equal(declaration.surface_hit,center_crossing.point),"exact_projected_center_"+str(node.id),{"center":_arr(center),"expected":_arr(expected_center),"crossing":center_crossing}): return _finish(report,ledger)
		var cavity: Dictionary = {"node_id":node.id,"feature_id":node.feature_id,"center":_arr(center),"radii":_arr(radii),"axis":_arr(axis),"mouths":[]}
		report.cavities.append(cavity)
		for ray_index: int in range(13):
			var phase: String = str(node.id)+"_mouth_"+str(ray_index)
			var projection: Dictionary = center_crossing
			if ray_index > 0:
				var angle: float = TAU*float(ray_index-1)/12.0
				var nominal: Vector3 = projected_hit+basis*Vector3(0.75*radii.x*cos(angle),0.75*radii.y*sin(angle),0.0)
				projection = _projection(f0,ledger,nominal,axis,length,phase+"_projection")
			var mouth: Dictionary = {"index":ray_index,"baseline_crossing":projection,"required_depth_m":2.0*H if ray_index == 0 else H}
			cavity.mouths.append(mouth)
			if not _check(report,bool(projection.ok),phase+"_first_F0_crossing",projection): return _finish(report,ledger)
			var hit: Vector3 = Graph.vec(projection.point)
			var normal: Dictionary = _normal(f0,ledger,hit,axis,phase+"_normal"); mouth["normal"] = normal
			if not _check(report,bool(normal.ok),phase+"_baseline_axis_alignment",normal): return _finish(report,ledger)
			var owner: Dictionary = _ownership(f0,ledger,hit); mouth["owner"] = owner
			if not _check(report,bool(owner.ok),phase+"_exact_n000_ownership",owner): return _finish(report,ledger)
			var inward: Dictionary = _inward(f2,ledger,hit,axis,float(declaration.radii_m[2]),phase+"_inward"); mouth["inward_crossing"] = inward
			if not _check(report,bool(inward.ok),phase+"_first_F2_tissue_entry",inward): return _finish(report,ledger)
			mouth["depth_m"] = inward.depth_m
			if not _check(report,is_finite(float(inward.depth_m)) and float(inward.depth_m) >= float(mouth.required_depth_m),phase+"_blind_depth",mouth): return _finish(report,ledger)
		var minor_a: Vector3 = Graph.vec(cavity.mouths[1].baseline_crossing.point)
		var minor_b: Vector3 = Graph.vec(cavity.mouths[7].baseline_crossing.point)
		var delta: Vector3 = minor_a-minor_b
		var span: float = (delta-axis*delta.dot(axis)).length()
		cavity["minor_open_span_m"] = span; cavity["minor_open_span_required_m"] = 3.0*H
		if not _check(report,is_finite(span) and span >= 3.0*H,str(node.id)+"_actual_transverse_open_span",{"span_m":span,"required_m":3.0*H,"opposite_ray_indices":[1,7]}): return _finish(report,ledger)
		var thickness: Dictionary = _thickness(f0,ledger,projected_hit,axis,length,float(declaration.radii_m[2]),wall,str(node.id)+"_thickness"); cavity["thickness"] = thickness
		if not _check(report,bool(thickness.ok),str(node.id)+"_conservative_first_exit_thickness",thickness): return _finish(report,ledger)
		# Keep complete177-value sets for BOTH fields, even if the first set
		# contains a failure. A sibling cutter cannot escape the retained recheck.
		var shell0: Dictionary = _shell(f0,ledger,center,basis,radii,wall,"F0",str(node.id)+"_shell_F0")
		var shell2: Dictionary = _shell(f2,ledger,center,basis,radii,wall,"F2",str(node.id)+"_shell_F2")
		cavity["shell_f0"] = shell0; cavity["shell_f2"] = shell2
		var shell0_ok: bool = _check(report,bool(shell0.ok) and int(shell0.sample_count) == 177 and int(shell0.unique_positions) == 153,str(node.id)+"_complete_F0_shell_back_disk",shell0)
		var shell2_ok: bool = _check(report,bool(shell2.ok) and int(shell2.sample_count) == 177 and int(shell2.unique_positions) == 153,str(node.id)+"_complete_F2_shell_back_disk",shell2)
		cavity["complete_field_calls"] = ledger.calls-cavity_before+int(center_crossing.calls)
		cavity["complete_field_cap"] = 2165
		if not shell0_ok or not shell2_ok: return _finish(report,ledger)
		if not _check(report,int(cavity.complete_field_calls) <= 2165,str(node.id)+"_complete_field_budget",{"calls":cavity.complete_field_calls,"cap":2165}): return _finish(report,ledger)
	# Facing actual support points projected into the fixed territory plane.
	var territory_origin: Vector3 = Graph.vec(plan.frame.origin); var t: Vector3 = Graph.vec(plan.frame.tangent); var b: Vector3 = Graph.vec(plan.frame.bitangent); var n: Vector3 = Graph.vec(plan.frame.normal)
	var first_node: Dictionary = _node(dna,"n013"); var second_node: Dictionary = _node(dna,"n014")
	var first_center: Vector3 = Graph.vec(first_node.position); var second_center: Vector3 = Graph.vec(second_node.position)
	var center_delta: Vector3 = second_center-first_center
	var projected_delta: Vector3 = t*center_delta.dot(t)+b*center_delta.dot(b)
	if not _check(report,projected_delta.is_finite() and projected_delta.length_squared() > 0.0,"bridge_projected_center_direction",{"delta":_arr(projected_delta)}): return _finish(report,ledger)
	var direction: Vector3 = projected_delta.normalized()
	var a: Vector3 = first_center+_support_vector(Graph.node_basis(first_node),Graph.vec(first_node.size),direction)
	var z: Vector3 = second_center+_support_vector(Graph.node_basis(second_node),Graph.vec(second_node.size),-direction)
	var uv_a: Vector2 = Vector2((a-territory_origin).dot(t),(a-territory_origin).dot(b))
	var uv_z: Vector2 = Vector2((z-territory_origin).dot(t),(z-territory_origin).dot(b))
	var projected_a: Vector3 = territory_origin+t*uv_a.x+b*uv_a.y; var projected_z: Vector3 = territory_origin+t*uv_z.x+b*uv_z.y
	var gap: float = (projected_z-projected_a).dot(direction)
	var bridge: Dictionary = {"gap_m":gap,"required_gap_m":wall,"facing_support_points":[_arr(a),_arr(z)],"projected_endpoints":[_arr(projected_a),_arr(projected_z)],"columns":[],"finite_sampling_only":true}; report.bridge = bridge
	if not _check(report,is_finite(gap) and gap >= wall,"actual_consumed_projected_support_gap",bridge): return _finish(report,ledger)
	var bridge_before: int = ledger.calls
	for fraction: float in BRIDGE_FRACTIONS:
		var phase: String = "bridge_"+str(fraction)
		var projection: Dictionary = _projection(f0,ledger,projected_a.lerp(projected_z,fraction),n,length,phase+"_projection")
		var row: Dictionary = {"fraction":fraction,"baseline_crossing":projection}; bridge.columns.append(row)
		if not _check(report,bool(projection.ok),phase+"_first_F0_crossing",projection): return _finish(report,ledger)
		var hit: Vector3 = Graph.vec(projection.point)
		var owner: Dictionary = _ownership(f0,ledger,hit); row["owner"] = owner
		if not _check(report,bool(owner.ok),phase+"_exact_n000_ownership",owner): return _finish(report,ledger)
		var point: Vector3 = hit-wall*n
		var value: float = ledger.value(f2,point,"F2",phase+"_burial")
		row.merge({"point":_arr(point),"value":value,"required_maximum":-0.35*wall},true)
		if not _check(report,is_finite(value) and value <= -0.35*wall,phase+"_retained_tissue",row): return _finish(report,ledger)
	bridge["complete_field_calls"] = ledger.calls-bridge_before; bridge["complete_field_cap"] = 400
	if not _check(report,int(bridge.complete_field_calls) <= 400,"bridge_complete_field_budget",{"calls":bridge.complete_field_calls,"cap":400}): return _finish(report,ledger)
	var counter: SacCounter = SacCounter.new(f2,ledger)
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
		var node: Dictionary = _node(dna,id); var parent: Dictionary = _node(dna,str(node.parent)); var group: RefCounted = null
		for item: RefCounted in f2.influences:
			if f2.node_ids[item.node_index] == id: group = item.sac_group; break
		if not _check(report,group != null,"mapped_root_group_"+id): return _finish(report,ledger)
		var samples: Array = []; var maximum: float = -INF; var valid: bool = true
		for index: int in range(17):
			var rest: Vector3 = Graph.vec(parent.position).lerp(Graph.vec(node.position),float(index)/16.0)
			var point: Vector3 = group.forward(rest); var value: float = ledger.value(f2,point,"F2","mapped_root_paths")
			samples.append({"index":index,"rest":_arr(rest),"point":_arr(point),"value":value})
			valid = valid and is_finite(value) and value <= -0.12*float(f2.step)
			if is_finite(value): maximum = maxf(maximum,value)
		var row: Dictionary = {"node_id":id,"feature_id":node.feature_id,"samples":samples,"maximum_field":maximum,"required_maximum":-0.12*float(f2.step),"ok":valid}; report.mapped_root_paths.append(row)
		if not _check(report,valid,"mapped_root_path_"+id,row): return _finish(report,ledger)
	var body: RefCounted = _body(f2)
	for id: String in ["n005","n006"]:
		var support: Dictionary = _node(dna,id); var root: Vector3 = Graph.vec(support.points[0]); var before: int = int(body.geometry_evaluations)
		var value: float = body.distance(root); var weights: Array = body.weights(root)
		ledger.analytic_support_component_reads += int(body.geometry_evaluations)-before
		var index: int = body.member_ids.find(str(support.parent)); var required: float = 0.20*float(support.radii[0])
		var weight: float = float(weights[index]) if index >= 0 and index < weights.size() else NAN
		var row: Dictionary = {"node_id":id,"parent_id":support.parent,"point":_arr(root),"distance":value,"required_burial_m":required,"named_parent_weight":weight}; report.supports.append(row)
		if not _check(report,index >= 0 and is_finite(value) and value <= -required and is_finite(weight) and weight > 0.0,"original_support_burial_"+id,row): return _finish(report,ledger)
	for cutter_id: String in ["n013","n014"]:
		var cutter: Dictionary = _node(dna,cutter_id); var inverse: Basis = Graph.node_basis(cutter).inverse(); var center: Vector3 = Graph.vec(cutter.position); var radii: Vector3 = Graph.vec(cutter.size)
		for support_id: String in ["n005","n006"]:
			var support: Dictionary = _node(dna,support_id)
			for index: int in range(support.points.size()):
				var point: Vector3 = Graph.vec(support.points[index]); var radius: float = float(support.radii[index])
				var value: float = SDF.ellipsoid(inverse*(point-center),radii)
				ledger.analytic_support_control_ball_reads += 1
				var row: Dictionary = {"cutter_id":cutter_id,"support_id":support_id,"control_index":index,"point":_arr(point),"analytic_cutter_distance":value,"control_radius":radius,"required_minimum":radius+wall,"finite_control_ball_only":true}; report.support_control_balls.append(row)
				if not _check(report,is_finite(value) and value >= radius+wall,"support_control_ball_"+cutter_id+"_"+support_id+"_"+str(index),row): return _finish(report,ledger)
	if not _check(report,report.support_control_balls.size() == 12 and ledger.owner_locations == 31 and not ledger.overflow and ledger.calls <= COMPLETE_CAP,"fixed_complete_accounting",{"support_control_balls":report.support_control_balls.size(),"owner_locations":ledger.owner_locations,"calls":ledger.calls,"cap":COMPLETE_CAP}): return _finish(report,ledger)
	return _finish(report,ledger)

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
