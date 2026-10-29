extends "res://alien_foundry/scripts/geometry/OrganicVolume.gd"
## Additive live extraction. All inherited field/root/normal/attribution math is
## called unchanged. No old loader, old extractor, planner or retained reselection.
const Live232 = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadPolicy232.gd")
const Quad232 = preload("res://alien_foundry/scripts/geometry/BlobQuadPolicy229.gd")
const LiveExtractor232 = preload("res://alien_foundry/scripts/geometry/BlobQuadExtractor229.gd")
const Source232 = preload("res://alien_foundry/scripts/geometry/BlobQuadArtifact229.gd")
var _armed232: bool = false
var _used232: bool = false
var _source232: Dictionary = {}
var _extraction_return232: Dictionary = {}
var _recipe232: Dictionary = {}
var _phase232: String = "inactive"
var _failure232: String = ""
var _cancellation_observed232: bool = false
var _rejected_by_phase232: Dictionary = {}
var _rejected_by_reason232: Dictionary = {}
var _qualification_accounting232: Dictionary = {"available":true,"selected_F0_and_F1_complete_values":0,"selected_F1_is_overlapping_subset":true,"complete_values_total_new":0}
var _counts232: Dictionary = {"source_authentications":0,"parent_build_entries":0,"conforming_dispatches":0,"extractor_entries":0,"completed_extractions":0,"selected_F1_complete_values":0,"independent_sac_complete_values":0,"lattice_complete_values":0,"solver_complete_values":0,"post_complete_values":0,"rejected_complete_requests":0,"attribution_passes":0,"attribution_vertices_planned":0,"attribution_vertices_written":0,"attribution_vertices_with_complete_AO":0,"attribution_lattice_requests":0,"partition_calls":0}

func build(_dna: Dictionary, _quality: int = 1, _job: RefCounted = null, _limits: Dictionary = {}) -> Dictionary:
	return {"error":"232 ordinary build entry is disabled; use the explicit live recipe entry."}

func scope232() -> Dictionary:
	return {"armed":_armed232,"used":_used232,"phase":_phase232,"failure":_failure232,"cancellation_observed":_cancellation_observed232,"rejected_by_phase":_rejected_by_phase232.duplicate(true),"rejected_by_reason":_rejected_by_reason232.duplicate(true),"counts":_counts232.duplicate(true),"qualification_accounting":_qualification_accounting232.duplicate(true),"source_proven_exclusions":{"coarse_extraction":true,"slab_planner":true,"retained_reselection":true,"legacy223_loader":true,"not_dynamic_call_counters":true}}

func _reject232(message: String) -> Dictionary:
	if _failure232.is_empty(): _failure232 = "232 " + message
	return {"error":_failure232,"live_quad232":scope232()}

func build_selected_stage5(source_path: Variant, recipe_value: Variant, job: RefCounted = null, options: Dictionary = {}) -> Dictionary:
	var declared: Dictionary = Live232.validate_recipe(recipe_value)
	if not declared.ok: return {"error":declared.error,"live_quad232":scope232()}
	if not options.is_empty(): return _reject232("unknown live build options; field/budget overrides are forbidden.")
	if not source_path is String or source_path.is_empty(): return _reject232("source path must identify exact retained224 bytes.")
	if job != null and (not job.has_method("is_cancelled") or not job.has_method("set_progress")): return _reject232("invalid progress/cancellation interface.")
	if job != null and job.is_cancelled():
		_cancellation_observed232 = true
		return {"cancelled":true,"live_quad232":scope232()}
	if _used232: return _reject232("one live build attempt per instance; no retry.")
	_used232 = true
	_counts232.source_authentications += 1
	var loaded: Dictionary = Source232.load_source(source_path)
	if not loaded.ok: return _reject232(str(loaded.error))
	_source232 = loaded.packet
	_recipe232 = declared.recipe
	var dna: Dictionary = _source232.dna.duplicate(true)
	var dna_before: PackedByteArray = var_to_bytes(dna)
	if job != null and job.is_cancelled():
		_cancellation_observed232 = true
		return {"cancelled":true,"live_quad232":scope232()}
	_armed232 = true; _phase232 = "selected223"
	_counts232.parent_build_entries += 1
	# The inherited224 preflight validates this nonempty string, then virtual
	# dispatch enters our override. The inherited223 pilot loader is never used.
	# This key is INTERNAL ONLY: callers cannot provide arbitrary build options.
	var limits: Dictionary = {"high_preview_pilot_path":source_path,"max_body_triangles":100000,"max_detail_triangles":0,"module_attachment_fields":false}
	var result: Dictionary = super.build(dna,1,job,limits)
	_finalize_qualification_accounting232(result)
	_normalize_cancellation232(result)
	_armed232 = false; _phase232 = "finished"
	if var_to_bytes(dna) != dna_before or FileAccess.get_sha256(source_path) != Quad232.SOURCE_RAW_SHA:
		if int(_counts232.completed_extractions) == 1: return _complete_rejection232(result,"source DNA or retained224 file changed during live generation.","input_immutability")
		return _reject232("source DNA or retained224 file changed during live generation.")
	if not _failure232.is_empty(): result["error"] = _failure232
	if not result.has("error") and not result.get("cancelled",false):
		var closed: Dictionary = _close_success232(result)
		if not closed.ok:
			result = _complete_rejection232(result,str(closed.error),"completion_validation")
	result["live_quad232"] = scope232()
	result.live_quad232["source_field_key"] = Quad232.SOURCE_KEY
	result.live_quad232["live_artifact_key"] = Live232.ARTIFACT_KEY
	result.live_quad232["historical224_reference"] = {"raw_sha256":Quad232.SOURCE_RAW_SHA,"error":Quad232.SOURCE_FACE_ERROR,"cumulative_edges":31888,"cumulative_queries":1141122,"cumulative_lattice_visits":977816,"historical_only":true}
	if result.get("stats") is Dictionary: result.stats["live_quad232"] = result.live_quad232.duplicate(true)
	return result

func _prepared_context232() -> String:
	if not _armed232 or _source232.is_empty(): return "live entry is not armed."
	if not preparation_errors.is_empty() or thin_features_preserved != 0 or attachment_repairs != 0 or not lattice_collars.is_empty() or not contained_lips.is_empty() or not attachment_lattice.is_empty(): return "prepared field has errors, repairs, lips, collars or a borrowed lattice."
	if geometry_adjustments != {"thin_features":[],"attachment_collars":[],"lattice_collars":[]}: return "actual geometry adjustments must be empty."
	if var_to_bytes(source_dna) != var_to_bytes(_source232.dna): return "prepared field DNA differs from authenticated224."
	if node_ids.size() != 14 or influences.size() != 28 or not source_dna.modules.is_empty(): return "fixed node/influence/module shape differs."
	if budget_spacing_scale != 1.0 or regional_noise_gain != REGIONAL_NOISE_GAINS or grid_dimensions != Vector3i(76,73,82): return "field spacing/gains/base grid differs."
	if SlabPolicy.scalar_bits(step) != Quad232.CELL_BITS or PackedVector3Array([bounds.position]).to_byte_array().hex_encode() != Quad232.ORIGIN_BITS: return "field reference bits differ."
	if not slab_high_preview or slab_high_preview2 or tile_dimensions != Vector3i(16,15,17) or tiles.size() != 4080: return "selector or tile grid differs."
	var positive: int = 0; var cutters: int = 0; var bodies: int = 0; var supports: int = 0; var sacs: int = 0
	for item: Influence in influences:
		if item.amplitude != 0.0 or item.lip_radius != 0.0 or item.contained_lip_radius != 0.0 or item.surface_parent >= 0: return "undeclared noise/lip/fold primitive."
		if item.subtract:
			cutters += 1
			if node_ids[item.node_index] != "n013": return "undeclared cutter."
		else: positive += 1
		if item.body_envelope != null:
			bodies += 1
			if item.body_envelope.member_ids.size() != 5 or item.body_envelope.branches.size() != 3: return "body carrier bound differs."
		if item.is_curve:
			supports += 1
			if node_ids[item.node_index] not in ["n005","n006"]: return "undeclared support."
		if item.sac_group != null:
			sacs += 1
			if node_ids[item.node_index] not in ["n007","n008","n009","n010","n011","n012"]: return "undeclared sac carrier."
	if positive != 27 or cutters != 1 or bodies != 1 or supports != 20 or sacs != 6: return "compiled influence categories differ."
	for node: Dictionary in source_dna.nodes:
		if Tendons._is_detail_curve(node): return "detail tendon work is not declared."
	for bucket: PackedInt32Array in tiles:
		if bucket.size() > 28: return "tile influence bound exceeded."
		var previous: int = -1
		for id: int in bucket:
			if id <= previous or id >= 28: return "noncanonical tile influence ordering."
			previous = id
	return ""

func _extract_conforming_slabs210(job: RefCounted) -> Dictionary:
	if _cancelled(): return {"cancelled":true}
	_counts232.conforming_dispatches += 1
	if _counts232.conforming_dispatches != 1: return _reject232("only one live conforming pass is permitted.")
	var context_error: String = _prepared_context232()
	if not context_error.is_empty(): return _reject232(context_error)
	var old_slabs: Dictionary = _source232.mesh_data.conforming_slabs210
	slab_axes = Quad232.axes(); slab_dimensions = Quad232.SOURCE_GRID
	slab_report = {"mode":SlabPolicy.MODE,"pin":SlabPolicy.PIN,"retained_coarse":true,"retained_grid_reference224":true,"coarse_extractions_new":0,"refined_extractions_new":0,"lattice_visits_new":0,"lattice_queries_new":0,"lattice_skips_new":0,"coarse_lattice_visits_new":0,"coarse_lattice_queries_new":0,"coarse_lattice_skips_new":0,"refined_lattice_visits_new":0,"refined_lattice_queries_new":0,"refined_lattice_skips_new":0,"historical_lattice_visits":Live232.PRIOR_LATTICE,"historical_edge_queries":Live232.PRIOR_QUERIES,"historical_edges":Live232.PRIOR_EDGES,"base_grid":[grid_dimensions.x,grid_dimensions.y,grid_dimensions.z],"base_origin_f32_le":Quad232.ORIGIN_BITS,"reference_cell_f64_le":Quad232.CELL_BITS,"field_normal_reference_unchanged":true,"connectivity_repairs":0,"refinement_pass_cap":1,"plan":old_slabs.plan.duplicate(true),"canonical_plan_sha256":old_slabs.canonical_plan_sha256,"retained_reference_raw_sha256":Quad232.SOURCE_RAW_SHA,"live_workflow232":Live232.MODE}
	_phase232 = "lattice"
	var phase_started: int = Time.get_ticks_msec()
	var sampled: PackedFloat32Array = _sample_rectilinear210()
	if _cancelled(): return {"cancelled":true,"conforming_slabs210":slab_report}
	if sampled.size() != Live232.LATTICE_CAP or int(slab_report.lattice_visits_new) != Live232.LATTICE_CAP: return _reject232("incomplete fixed rectilinear sampling.")
	var audit: Dictionary = SlabGrid.audit_connectivity(sampled,slab_dimensions,job,true)
	if not audit.get("ok",false) or audit.get("cancelled",false): audit["conforming_slabs210"] = slab_report; return audit
	var sample_time: int = Time.get_ticks_msec(); slab_report["refined_sampling_and_audit_ms"] = sample_time - phase_started
	var solver: RefCounted = SlabEdge.create_cumulative(_continuous_extraction_value,step,Live232.PRIOR_EDGES,Live232.PRIOR_QUERIES)
	if not solver.error.is_empty(): return _reject232(solver.error)
	_phase232 = "solver"; slab_report.refined_extractions_new = 1
	var mesh: Dictionary = _dispatch_extractor232(sampled,job,solver)
	slab_report["refined_extraction_ms"] = Time.get_ticks_msec() - sample_time
	var edge: Dictionary = mesh.get("edge_refinement204",solver.snapshot())
	slab_report["final_edges"] = int(edge.get("unique_edges",0)); slab_report["final_edge_queries"] = int(edge.get("continuous_queries",0))
	slab_report["cumulative_edges"] = Live232.PRIOR_EDGES + slab_report.final_edges
	slab_report["cumulative_edge_queries"] = Live232.PRIOR_QUERIES + slab_report.final_edge_queries
	slab_report["actual_new_edge_queries"] = slab_report.final_edge_queries
	slab_report["cumulative_lattice_visits"] = Live232.PRIOR_LATTICE + int(slab_report.lattice_visits_new)
	mesh["conforming_slabs210"] = slab_report.duplicate(true)
	if mesh.has("error") or mesh.get("cancelled",false): return mesh
	if mesh.vertices.to_byte_array() != _source232.mesh_data.vertices.to_byte_array() or mesh.normals.to_byte_array() != _source232.mesh_data.normals.to_byte_array(): return _complete_rejection232(mesh,"fresh fixed-field root/normal parity differs from224; no attribution or repair.","root_normal_parity")
	if mesh.indices.size() != Quad232.SOURCE_FACES * 3: return _complete_rejection232(mesh,"fresh fixed-field face count differs.","face_count_parity")
	_counts232.completed_extractions += 1; _phase232 = "post"
	# Parent adds its actual local selected qualification to this shared return
	# dictionary before unpacking mesh. Retain that reference so post-extraction
	# cancellation cannot accidentally discard the authoritative F0 ledger.
	_extraction_return232 = {"mesh":mesh,"field":sampled,"sample_time":sample_time}
	return _extraction_return232

func _dispatch_extractor232(sampled: PackedFloat32Array, job: RefCounted, solver: RefCounted) -> Dictionary:
	if not _armed232: return _reject232("extractor dispatch is not armed.")
	_counts232.extractor_entries += 1
	if _counts232.extractor_entries != 1: return _reject232("only one live extractor entry is permitted.")
	return LiveExtractor232.new().extract_rectilinear229(sampled,Quad232.axes(),bounds.position,step,_recipe232.recipe229,job,solver)

func sac_group_qualification() -> Dictionary:
	if _cancelled(): return {"ok":false,"cancelled":true,"error":"232 cancelled before independent sac qualification."}
	var saved_phase: String = _phase232; _phase232 = "sac"
	var result: Dictionary = super.sac_group_qualification()
	_phase232 = saved_phase
	return result

func _field_value(point: Vector3, bucket: PackedInt32Array, apply_noise: bool = true, apply_cavities: bool = true, apply_contained_lips: bool = true) -> float:
	var key: String = "post_complete_values"; var cap: int = 0
	match _phase232:
		"selected223": key = "selected_F1_complete_values"; cap = Live232.SELECTED_QUALIFICATION_CAP
		"sac": key = "independent_sac_complete_values"; cap = Live232.SAC_QUALIFICATION_CAP
		"lattice": key = "lattice_complete_values"; cap = Live232.LATTICE_CAP
		"solver": key = "solver_complete_values"; cap = Live232.NEW_EDGE_QUERY_CAP
	var reason: String = ""
	if not _armed232: reason = "unarmed"
	elif super._cancelled() or _cancellation_observed232: reason = "cancelled"
	elif not _failure232.is_empty(): reason = "prior_failure"
	elif int(_counts232[key]) >= cap: reason = "phase_quota"
	if not reason.is_empty():
		_counts232.rejected_complete_requests += 1
		_rejected_by_phase232[_phase232] = int(_rejected_by_phase232.get(_phase232,0))+1
		_rejected_by_reason232[reason] = int(_rejected_by_reason232.get(reason,0))+1
		if reason == "cancelled": _cancellation_observed232 = true
		elif _failure232.is_empty(): _failure232 = "232 rejected complete-field request ("+reason+") in " + _phase232
		return NAN
	_counts232[key] += 1
	return super._field_value(point,bucket,apply_noise,apply_cavities,apply_contained_lips)

func _cancelled() -> bool:
	if super._cancelled(): _cancellation_observed232 = true
	return _cancellation_observed232 or not _failure232.is_empty()

func _normalize_cancellation232(result: Dictionary) -> void:
	if super._cancelled(): _cancellation_observed232 = true
	if _cancellation_observed232:
		result["cancelled"] = true
	elif not _failure232.is_empty() and result.get("cancelled",false):
		# Parent uses _cancelled as a stop predicate. A quota/contract abort is
		# not a user cancellation even when that inherited stop path labels it so.
		result["cancelled"] = false
		result["stopped_by_live_contract232"] = true

func _attribute_vertices(mesh: Dictionary, sampled: PackedFloat32Array) -> void:
	_counts232.attribution_passes += 1
	if _counts232.attribution_passes != 1 or mesh.vertices.size() != Quad232.SOURCE_VERTICES or sampled.size() != Live232.LATTICE_CAP or not contained_lips.is_empty() or not lattice_collars.is_empty():
		_failure232 = "232 real attribution fixed-shape preconditions failed."; return
	_phase232 = "post"
	_counts232.attribution_vertices_planned = mesh.vertices.size()
	# Inherited exact ownership, material, AO and UV math. Fixed28-influence
	# premises bound analytic ownership to27+26 distances and2 body calls/vertex.
	super._attribute_vertices(mesh,sampled)
	_counts232.attribution_vertices_with_complete_AO = int(_counts232.attribution_lattice_requests) / 3
	if mesh.get("component_ids") is PackedInt32Array and mesh.component_ids.size() == Quad232.SOURCE_VERTICES and mesh.get("uvs2") is PackedVector2Array and mesh.uvs2.size() == Quad232.SOURCE_VERTICES:
		_counts232.attribution_vertices_written = Quad232.SOURCE_VERTICES

func _lattice_value(point: Vector3, sampled: PackedFloat32Array) -> float:
	if _phase232 == "post":
		if int(_counts232.attribution_lattice_requests) >= Live232.ATTRIBUTION_LATTICE_CAP:
			_failure232 = "232 attribution lattice-request budget exceeded."; return NAN
		_counts232.attribution_lattice_requests += 1
	return super._lattice_value(point,sampled)

func _body_group_component_partition(point: Vector3, relevant: PackedInt32Array, group_item: Influence) -> Dictionary:
	_counts232.partition_calls += 1
	return super._body_group_component_partition(point,relevant,group_item)

func _close_success232(result: Dictionary) -> Dictionary:
	if _counts232.completed_extractions != 1 or _counts232.attribution_passes != 1 or _counts232.attribution_vertices_written != Quad232.SOURCE_VERTICES or _counts232.attribution_lattice_requests != Live232.ATTRIBUTION_LATTICE_CAP or _counts232.post_complete_values != 0: return {"ok":false,"error":"232 incomplete live extraction/attribution work ledger."}
	var attributes: Dictionary = _validate_attributes232(result)
	if not attributes.ok: return attributes
	if int(_counts232.partition_calls) > Quad232.SOURCE_VERTICES: return {"ok":false,"error":"232 body partition count exceeded."}
	if int(_counts232.solver_complete_values) != int(result.get("edge_refinement204",{}).get("continuous_queries",-1)) or int(_counts232.lattice_complete_values) != int(slab_report.get("lattice_queries_new",-1)): return {"ok":false,"error":"232 solver/lattice counter reconciliation failed."}
	var qualification: Variant = result.get("mantle_cavity_qualification217")
	if not qualification is Dictionary or not qualification.get("ok",false) or qualification.get("qualification_cache_reused",true) or not _qualification_accounting232.available:
		return {"ok":false,"error":"232 requires the fresh complete selected223 qualification ledger."}
	return {"ok":true,"error":""}

func _finalize_qualification_accounting232(result: Dictionary) -> void:
	# Runs on success AND every ordinary error/cancellation return. F0 executes
	# inside the unchanged223 author, so its authoritative ledger is reconciled,
	# never incorrectly inferred from the overlapping counted F1 instance.
	if not result.has("mantle_cavity_qualification217") and _extraction_return232.get("mantle_cavity_qualification217") is Dictionary:
		result["mantle_cavity_qualification217"] = _extraction_return232.mantle_cavity_qualification217.duplicate(true)
	var qualification: Variant = result.get("mantle_cavity_qualification217")
	var dispatches: int = 0; var f0: int = 0; var f1_dispatches: int = 0; var available: bool = true
	var f1_executed: int = int(_counts232.selected_F1_complete_values)
	var f1_rejected: int = int(_rejected_by_phase232.get("selected223",0))
	if qualification is Dictionary and qualification.get("accounting") is Dictionary and qualification.get("complete_values") is Array:
		for row: Dictionary in qualification.complete_values:
			if row.get("complete_value_executed",false):
				dispatches += 1
				if row.get("field") == "F1": f1_dispatches += 1
				elif row.get("field") == "F0": f0 += 1
				else: available = false
		available = available and dispatches == int(qualification.accounting.get("executed_complete_values",-1)) and dispatches <= Live232.SELECTED_QUALIFICATION_CAP and f1_dispatches == f1_executed+f1_rejected
	elif f1_executed != 0 or f1_rejected != 0:
		available = false
	# The unchanged author's "executed" F1 rows mean callback dispatches. A
	# rejected232 callback returns NAN without executing super._field_value.
	# F0 is plain OrganicVolume and therefore has no232 callback guard.
	var executed: int = f0+f1_executed
	_qualification_accounting232 = {"available":available,"author_callback_dispatches":dispatches,"author_F1_callback_dispatches":f1_dispatches,"selected_F0_complete_values":f0 if available else -1,"selected_F1_complete_values":f1_executed,"selected_F1_rejected_callbacks":f1_rejected,"selected_F0_and_F1_complete_values":executed if available else -1,"selected_F1_is_overlapping_subset":true,"complete_values_total_new":executed+int(_counts232.independent_sac_complete_values)+int(_counts232.lattice_complete_values)+int(_counts232.solver_complete_values)+int(_counts232.post_complete_values) if available else -1}
	if not available and _failure232.is_empty(): _failure232 = "232 selected F0/F1 accounting unavailable or inconsistent."

func _validate_attributes232(mesh: Dictionary) -> Dictionary:
	var n: int = Quad232.SOURCE_VERTICES
	if not mesh.get("component_ids") is PackedInt32Array or not mesh.get("component_indices") is PackedInt32Array or not mesh.get("component_weights") is PackedFloat32Array or not mesh.get("ambient_occlusion") is PackedFloat32Array or not mesh.get("colors") is PackedColorArray or not mesh.get("uvs") is PackedVector2Array or not mesh.get("uvs2") is PackedVector2Array:
		return {"ok":false,"error":"232 missing actual native attribution buffers."}
	if mesh.component_ids.size()!=n or mesh.component_indices.size()!=n*4 or mesh.component_weights.size()!=n*4 or mesh.ambient_occlusion.size()!=n or mesh.colors.size()!=n or mesh.uvs.size()!=n or mesh.uvs2.size()!=n:
		return {"ok":false,"error":"232 real attribution buffer lengths differ."}
	for i in range(n):
		if mesh.component_ids[i]<0 or mesh.component_ids[i]>=13: return {"ok":false,"error":"232 invalid primary component."}
		var total: float = 0.0
		for slot in range(4):
			var j: int = 4*i+slot; var weight: float = mesh.component_weights[j]
			if mesh.component_indices[j]<0 or mesh.component_indices[j]>=13 or not is_finite(weight) or weight<0.0 or weight>1.0: return {"ok":false,"error":"232 invalid native component slot."}
			total += weight
		if absf(total-1.0)>0.00001: return {"ok":false,"error":"232 native four-slot normalization failed."}
		var color: Color = mesh.colors[i]; var ao: float = mesh.ambient_occlusion[i]
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a) or not is_finite(ao) or ao<0.0 or ao>1.0 or not mesh.uvs[i].is_finite() or not mesh.uvs2[i].is_finite(): return {"ok":false,"error":"232 nonfinite actual shading/UV attributes."}
	return {"ok":true,"error":""}

func _complete_rejection232(mesh: Dictionary, message: String, stage_name: String) -> Dictionary:
	# Only callers downstream of the extractor's complete finite/index-safe gate
	# may use this. Preserve physical buffers and quarantine semantic attributes.
	var partial: Dictionary = {}
	for key: String in ["component_ids","component_indices","component_weights","colors","uvs","uvs2","ambient_occlusion"]:
		if mesh.has(key): partial[key] = mesh[key]; mesh.erase(key)
	if not partial.is_empty(): mesh["diagnostic_attribution232"] = partial
	if mesh.has("stats"): mesh["diagnostic_statistics232"] = mesh.stats; mesh.erase("stats")
	if _failure232.is_empty(): _failure232 = message if message.begins_with("232 ") else "232 " + message
	mesh.merge({"error":_failure232,"rejected":true,"raw_snapshot_complete":true,"raw_snapshot_status":"completed_finite_index_safe_rejected232","attribution_complete":false,"failure_stage232":stage_name,"geometry_qualified":false,"conforming_slabs210":slab_report.duplicate(true),"live_quad232":scope232()},true)
	return mesh
