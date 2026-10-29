extends SceneTree
## Cheap ownership/scope gate. All extractor calls below fail before a lattice
## is traversed or a solver is invoked. Actual extraction is a later release.
const OwnershipContract = preload("res://alien_foundry/tests/BlobQuadOwnership229Contract.gd")
const Extractor = preload("res://alien_foundry/scripts/geometry/BlobQuadExtractor229.gd")
const Policy = preload("res://alien_foundry/scripts/geometry/BlobQuadPolicy229.gd")
const EXPECTED_CHECKS: int = 474
var output: String = ""
var report: Dictionary = {"suite": "quad229_ownership_and_entry_guards", "checks": 0, "failures": [], "complete_field_calls": 0, "lattice_samples": 0, "edge_solves": 0, "mesh_builds": 0, "guard_only_extractor_calls": 8}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	report.checks += 1
	if not ok:
		report.failures.append(label); push_error(label)

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--output-dir": output = args[i + 1]
	if output.is_empty() or FileAccess.file_exists(output.path_join("contract_report.json")):
		push_error("229 ownership contract requires fresh --output-dir"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var owned: Dictionary = OwnershipContract.run()
	report["ownership"] = owned
	report.checks = int(owned.checks)
	report.failures.append_array(owned.failures)
	check(owned.ok, "All ownership cases pass")
	check(int(owned.checks) == 460, "All460 ownership assertions execute")
	check(owned.exact_assertion_count, "Ownership schedule is exact")
	check(owned.field_queries == 0 and owned.mesh_builds == 0, "Ownership has no field or extraction work")
	var extractor: RefCounted = Extractor.new()
	var axes: Array = Policy.axes()
	var before: PackedByteArray = var_to_bytes(axes)
	var step: float = Policy.CELL_BITS.hex_decode().decode_double(0)
	var origin_bytes: PackedByteArray = Policy.ORIGIN_BITS.hex_decode()
	var origin: Vector3 = Vector3(origin_bytes.decode_float(0), origin_bytes.decode_float(4), origin_bytes.decode_float(8))
	var values: PackedFloat32Array = PackedFloat32Array()
	check(extractor.extract(values, Policy.SOURCE_GRID, origin, step).has("error"), "Direct uniform route cannot enable229")
	check(extractor.extract_rectilinear(values, axes, origin, step).has("error"), "Inherited-looking rectilinear route cannot enable229")
	check(extractor.extract_rectilinear229(values, axes, origin, step, null).has("error"), "Missing recipe cannot enable229")
	check(extractor.extract_rectilinear229(values, [], origin, step, Policy.recipe()).has("error"), "Missing canonical axes rejected before traversal")
	check(extractor.extract_rectilinear229(values, axes, origin, step + 1e-9, Policy.recipe()).has("error"), "Exact binary64 reference identity is mandatory")
	check(extractor.extract_rectilinear229(values, axes, origin + Vector3(0.1, 0.0, 0.0), step, Policy.recipe()).has("error"), "Changed origin rejected before traversal")
	check(extractor.extract_rectilinear229(values, axes, origin, step, Policy.recipe()).has("error"), "Missing bounded solver rejected before traversal")
	check(extractor.extract_rectilinear229(values, axes, origin, step, Policy.recipe(), null, RefCounted.new()).has("error"), "Arbitrary solver rejected before traversal")
	check(extractor.vertices.is_empty() and extractor.normals.is_empty() and extractor.indices.is_empty(), "Guard calls emitted no geometry")
	check(var_to_bytes(axes) == before, "Guard calls preserve exact input axes")
	report["expected_checks"] = EXPECTED_CHECKS
	report["exact_expected_check_count"] = int(report.checks) == EXPECTED_CHECKS
	if not report.exact_expected_check_count: report.failures.append("Unexpected229 ownership/guard check count")
	report["status"] = "PASS" if report.failures.is_empty() else "FAIL"
	var file: FileAccess = FileAccess.open(output.path_join("contract_report.json"), FileAccess.WRITE)
	if file == null: push_error("Cannot persist229 ownership report"); quit(1); return
	file.store_string(JSON.stringify(report, "\t", true, true)); file.close()
	print(JSON.stringify(report)); quit(0 if report.failures.is_empty() else 1)
