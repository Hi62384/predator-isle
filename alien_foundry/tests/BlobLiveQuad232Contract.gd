extends SceneTree
const Policy = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadPolicy232.gd")
const Volume232 = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadVolume232.gd")
const Pipeline232 = preload("res://alien_foundry/scripts/pipeline/BlobLiveQuadPipeline232.gd")
const Spy = preload("res://alien_foundry/tests/BlobLiveQuadDispatchSpy232.gd")
class CancelledJob extends RefCounted:
	func is_cancelled() -> bool: return true
	func set_progress(_value: float, _text: String) -> void: pass

var output: String = ""
var source_raw: String = ""
var report: Dictionary = {"suite":"live_quad232_entry_and_dispatch_contract","checks":0,"failures":[],"complete_field_values":0,"lattice_samples":0,"edge_solves":0,"mesh_builds":0,"retained_replays":0,"source_authentications":0,"successful_live_builds":0}
# Fixed source-counted schedule. Authentication reads the exact raw metadata only.
const EXPECTED_CHECKS: int = 111
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	report.checks += 1
	if not ok: report.failures.append(label); push_error(label)
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "--output-dir": output = args[i+1]
		if args[i] == "--source224-raw": source_raw = args[i+1]
	if output.is_empty() or source_raw.is_empty() or FileAccess.file_exists(output.path_join("contract_report.json")):
		push_error("232 requires fresh output and exact --source224-raw"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var recipe: Dictionary = Policy.recipe()
	check(Policy.validate_recipe(recipe).ok,"Canonical232 recipe")
	check(Policy.ARTIFACT_KEY != Policy.Quad.ARTIFACT_KEY and Policy.ARTIFACT_KEY != Policy.Quad.SOURCE_KEY,"Three artifact identities are distinct")
	check(("quad_live232:v1|"+Policy.Quad.SOURCE_KEY+"|"+Policy.Quad.SOURCE_RAW_SHA+"|"+Policy.Quad.PIN+"|"+Policy.PIN).sha256_text()==Policy.ARTIFACT_KEY,"Live key binds exact field source chooser and workflow")
	for key: String in recipe:
		var missing: Dictionary = recipe.duplicate(true); missing.erase(key)
		check(not Policy.validate_recipe(missing).ok,"Missing recipe field "+key)
		var wrong: Dictionary = recipe.duplicate(true); wrong[key] = []
		check(not Policy.validate_recipe(wrong).ok,"Wrong recipe type "+key)
	for invalid: Variant in [null,[],{},"232"]:
		check(not Policy.validate_recipe(invalid).ok,"Malformed recipe container "+str(typeof(invalid)))
	var extra: Dictionary = recipe.duplicate(true); extra["unknown"] = true
	check(not Policy.validate_recipe(extra).ok,"Unknown recipe field")
	var floating: Dictionary = recipe.duplicate(true); floating.stage = 5.0
	check(Policy.validate_recipe(floating).ok,"JSON integral stage restores canonical type")
	floating.stage = 5.25
	check(not Policy.validate_recipe(floating).ok,"Fractional stage rejects")
	var direct: RefCounted = Volume232.new()
	check(direct.build({}).has("error"),"Ordinary volume build cannot arm232")
	check(direct._dispatch_extractor232(PackedFloat32Array(),null,null).has("error"),"Unarmed extractor dispatch rejects")
	check(direct.scope232().counts.extractor_entries==0,"Unarmed dispatch made no extractor entry")
	for path: Variant in [null,22,true,""]:
		check(Volume232.new().build_selected_stage5(path,recipe).has("error"),"Malformed source path rejected "+str(typeof(path)))
	check(Volume232.new().build_selected_stage5(source_raw,recipe,null,{"quality":2}).has("error"),"Unknown field override rejected before authentication")
	var cancelled: RefCounted = Volume232.new()
	check(cancelled.build_selected_stage5(source_raw,recipe,CancelledJob.new()).get("cancelled",false),"Pre-cancelled entry stops before authentication")
	check(cancelled.scope232().counts.source_authentications==0 and cancelled.scope232().counts.parent_build_entries==0,"Pre-cancelled entry performs no preparation")
	check(Volume232.new().build_selected_stage5(source_raw,recipe,RefCounted.new()).has("error"),"Invalid controls interface rejected before authentication")
	var requested: Dictionary = Pipeline232.request(source_raw,recipe)
	check(Pipeline232.validate_request(requested).ok,"Canonical live request")
	for invalid: Variant in [null,[],{},"232"]:
		check(not Pipeline232.validate_request(invalid).ok,"Malformed request container "+str(typeof(invalid)))
	for key: String in requested:
		var missing: Dictionary = requested.duplicate(true); missing.erase(key)
		check(not Pipeline232.validate_request(missing).ok,"Missing request field "+key)
	var wrong_request: Dictionary = requested.duplicate(true); wrong_request.format = Policy.Quad.FORMAT
	check(not Pipeline232.validate_request(wrong_request).ok,"Retained request cannot enable live route")
	check(Pipeline232.new().build(requested,RefCounted.new()).has("error"),"Cache injection rejected before any field")
	_attribute_cases()
	_accounting_cases()
	var raw_before: String = FileAccess.get_sha256(source_raw)
	for kind: String in ["conforming","extractor"]:
		var spy: RefCounted = Spy.new(); spy.spy_kind = kind
		var result: Dictionary = spy.build_selected_stage5(source_raw,recipe)
		var scope: Dictionary = spy.scope232(); var counts: Dictionary = scope.counts
		check(result.has("error"),"Cheap spy never fabricates successful geometry "+kind)
		check(spy.spy_build_once_calls==1 and counts.parent_build_entries==1,"Real parent preflight dispatches once "+kind)
		check(spy.spy_old_recipe_path==source_raw and result.error==("232 actual geometry adjustments must be empty." if kind=="conforming" else "210 rectilinear sample count does not match its canonical axes."),"Exact new override/229 guard rejection instead of legacy223 loader "+kind)
		check(not scope.armed and scope.used,"One-shot entry disarmed "+kind)
		check(counts.selected_F1_complete_values+counts.independent_sac_complete_values+counts.lattice_complete_values+counts.solver_complete_values+counts.post_complete_values==0,"No complete-field requests "+kind)
		check(counts.completed_extractions==0 and counts.attribution_passes==0,"No extraction or attribution "+kind)
		check(spy.spy_callback_calls==0,"No solver callback even on error "+kind)
		check(counts.conforming_dispatches==(1 if kind=="conforming" else 0) and counts.extractor_entries==(1 if kind=="extractor" else 0),"Exact new dispatch seam "+kind)
		check(spy.build_selected_stage5(source_raw,recipe).has("error") and spy.scope232().counts.source_authentications==1,"No second attempt or raw authentication "+kind)
		report.source_authentications += counts.source_authentications
	check(raw_before==Policy.Quad.SOURCE_RAW_SHA and FileAccess.get_sha256(source_raw)==raw_before,"Exact224 raw unchanged")
	report["expected_checks"] = EXPECTED_CHECKS; report["exact_check_count"] = report.checks==EXPECTED_CHECKS
	if not report.exact_check_count: report.failures.append("232 declared check count differs")
	report["status"] = "PASS" if report.failures.is_empty() else "FAIL"
	var file: FileAccess = FileAccess.open(output.path_join("contract_report.json"),FileAccess.WRITE)
	if file==null: push_error("Cannot persist232 contract report"); quit(1); return
	file.store_string(JSON.stringify(report,"\t",true,true)); file.close(); print(JSON.stringify(report)); quit(0 if report.failures.is_empty() else 1)

func _attribute_cases() -> void:
	# Synthetic buffers only. No field, root, source reconstruction or extraction.
	var n: int = Policy.Quad.SOURCE_VERTICES
	var owner: PackedInt32Array = PackedInt32Array(); owner.resize(n)
	var ids: PackedInt32Array = PackedInt32Array(); ids.resize(n*4)
	var weights: PackedFloat32Array = PackedFloat32Array(); weights.resize(n*4)
	for i in range(n): weights[i*4] = 1.0
	var ao: PackedFloat32Array = PackedFloat32Array(); ao.resize(n); ao.fill(1.0)
	var colors: PackedColorArray = PackedColorArray(); colors.resize(n); colors.fill(Color.BLACK)
	var uv: PackedVector2Array = PackedVector2Array(); uv.resize(n)
	var valid: Dictionary = {"component_ids":owner,"component_indices":ids,"component_weights":weights,"ambient_occlusion":ao,"colors":colors,"uvs":uv,"uvs2":uv.duplicate()}
	var volume: RefCounted = Volume232.new()
	check(volume._validate_attributes232(valid).ok,"Actual native attribute schema accepts finite normalized synthetic buffers")
	var bad_values: Array = [["component_ids",-1],["component_ids",13],["component_ids",14],["component_indices",-1],["component_indices",13],["component_indices",14],["component_weights",NAN],["component_weights",-0.1],["component_weights",1.1],["component_weights",0.0],["ambient_occlusion",NAN],["ambient_occlusion",-0.1],["ambient_occlusion",1.1],["colors",Color(NAN,0,0,1)],["uvs",Vector2(INF,0)],["uvs2",Vector2(0,NAN)]]
	for i in range(bad_values.size()):
		var bad: Dictionary = valid.duplicate(true); bad[bad_values[i][0]][0] = bad_values[i][1]
		check(not volume._validate_attributes232(bad).ok,"Native attribute scalar negative "+str(i))
	var missing: Dictionary = valid.duplicate(true); missing.erase("uvs2")
	check(not volume._validate_attributes232(missing).ok,"Missing actual attribute buffer")
	var wrong: Dictionary = valid.duplicate(true); wrong.component_ids = PackedFloat32Array()
	check(not volume._validate_attributes232(wrong).ok,"Wrong packed attribute type")
	var short_buffer: Dictionary = valid.duplicate(true); short_buffer.component_weights = PackedFloat32Array([1.0])
	check(not volume._validate_attributes232(short_buffer).ok,"Incomplete actual attribute buffer")
	report["synthetic_attribute_vertices"] = n
	report["synthetic_attribute_cases"] = 20
	var physical: Dictionary = {"vertices":PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]),"normals":PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK]),"indices":PackedInt32Array([0,1,2]),"component_ids":PackedInt32Array([0]),"stats":{"partial":true}}
	var before: PackedByteArray = var_to_bytes([physical.vertices,physical.normals,physical.indices])
	var rejected: Dictionary = volume._complete_rejection232(physical,"synthetic completion failure","synthetic")
	check(rejected.rejected and rejected.raw_snapshot_complete and not rejected.attribution_complete and rejected.failure_stage232=="synthetic","Completed extraction rejection status remains explicit")
	check(var_to_bytes([rejected.vertices,rejected.normals,rejected.indices])==before and not rejected.has("component_ids") and not rejected.has("stats") and rejected.diagnostic_attribution232.component_ids==PackedInt32Array([0]) and rejected.diagnostic_statistics232.partial,"Physical bytes preserved and partial semantic output quarantined")

func _accounting_cases() -> void:
	# Synthetic callback rows only. The two real callback entries below stop
	# before super._field_value, so neither evaluates a field or a primitive.
	var cancelled: RefCounted = Volume232.new()
	cancelled._armed232 = true; cancelled._phase232 = "selected223"; cancelled.controls = CancelledJob.new()
	check(is_nan(cancelled._field_value(Vector3.ZERO,PackedInt32Array())),"Cancelled callback rejects before field evaluation")
	check(cancelled.scope232().counts.selected_F1_complete_values==0 and cancelled.scope232().rejected_by_phase.selected223==1,"Cancelled dispatch is not counted as an executed field")
	check(cancelled.scope232().cancellation_observed and cancelled.scope232().failure.is_empty() and cancelled.scope232().rejected_by_reason.cancelled==1,"Cancellation remains distinct from quota failure")
	var quota: RefCounted = Volume232.new(); quota._armed232 = true; quota._phase232 = "post"
	check(is_nan(quota._field_value(Vector3.ZERO,PackedInt32Array())),"Zero-quota post callback rejects before field evaluation")
	check(quota.scope232().counts.post_complete_values==0 and quota.scope232().rejected_by_phase.post==1,"Quota dispatch is not counted as an executed field")
	check(not quota.scope232().cancellation_observed and quota.scope232().rejected_by_reason.phase_quota==1 and not quota.scope232().failure.is_empty(),"Quota failure is not mislabeled as cancellation")
	var rows: Dictionary = {"mantle_cavity_qualification217":{"accounting":{"executed_complete_values":2},"complete_values":[{"field":"F0","complete_value_executed":true},{"field":"F1","complete_value_executed":true}]}}
	cancelled._finalize_qualification_accounting232(rows)
	var cancelled_counts: Dictionary = cancelled.scope232().qualification_accounting
	check(cancelled_counts.available and cancelled_counts.author_callback_dispatches==2 and cancelled_counts.author_F1_callback_dispatches==1,"Author callback dispatch rows reconcile including one cancelled callback")
	check(cancelled_counts.selected_F0_complete_values==1 and cancelled_counts.selected_F1_complete_values==0 and cancelled_counts.selected_F1_rejected_callbacks==1 and cancelled_counts.complete_values_total_new==1,"Synthetic cancelled schedule counts only actually executed F0")
	var success: RefCounted = Volume232.new(); success._counts232.selected_F1_complete_values = 1
	success._finalize_qualification_accounting232(rows)
	check(success.scope232().qualification_accounting.available and success.scope232().qualification_accounting.complete_values_total_new==2,"Synthetic normal F0 plus F1 schedule reconciles without double count")
	var absent: RefCounted = Volume232.new(); absent._counts232.selected_F1_complete_values = 1; absent._finalize_qualification_accounting232({})
	check(not absent.scope232().qualification_accounting.available and absent.scope232().qualification_accounting.complete_values_total_new==-1,"Missing authoritative selected ledger is unknown not zero")
	var unknown_rows: Dictionary = rows.duplicate(true); unknown_rows.mantle_cavity_qualification217.complete_values[0].field = "unknown"
	var unknown: RefCounted = Volume232.new(); unknown._counts232.selected_F1_complete_values = 1; unknown._finalize_qualification_accounting232(unknown_rows)
	check(not unknown.scope232().qualification_accounting.available,"Unknown selected ledger field label rejects")
	var mismatch: RefCounted = Volume232.new(); mismatch._finalize_qualification_accounting232(rows)
	check(not mismatch.scope232().qualification_accounting.available,"Unreconciled F1 callback dispatch is not accepted as executed")
	var boundary: RefCounted = Volume232.new(); boundary.controls = CancelledJob.new()
	check(boundary.sac_group_qualification().get("cancelled",false) and boundary.scope232().cancellation_observed and boundary.scope232().counts.independent_sac_complete_values==0,"Independent sac boundary latches cancellation without any callback")
	var retained: RefCounted = Volume232.new(); retained._counts232.selected_F1_complete_values = 1
	retained._extraction_return232 = rows.duplicate(true)
	var cancelled_result: Dictionary = {"cancelled":true}
	retained._finalize_qualification_accounting232(cancelled_result)
	check(var_to_bytes(cancelled_result.get("mantle_cavity_qualification217"))==var_to_bytes(rows.mantle_cavity_qualification217),"Post-extraction cancellation retains actual shared-return author ledger")
	check(retained.scope232().qualification_accounting.available and retained.scope232().qualification_accounting.complete_values_total_new==2,"Retained post-extraction author ledger preserves full synthetic F0 plus F1 count")
	var quota_result: Dictionary = {"cancelled":true}; quota._normalize_cancellation232(quota_result)
	check(not quota_result.cancelled and quota_result.stopped_by_live_contract232,"Inherited stop flag from quota is not returned as user cancellation")
	var real_cancel_result: Dictionary = {"error":"inherited boundary error"}; boundary._normalize_cancellation232(real_cancel_result)
	check(real_cancel_result.cancelled and real_cancel_result.error=="inherited boundary error","Real cancellation survives inherited error wrapper without erasing its evidence")
	report["synthetic_accounting_cases"] = 17
	report["guarded_nonexecuted_callback_requests"] = 2
