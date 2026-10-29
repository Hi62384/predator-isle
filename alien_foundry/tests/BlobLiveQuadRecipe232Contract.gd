extends SceneTree
## Portable declaration and actual public JSON I/O contract only. No source224
## packet, field, lattice, solver, extraction, retained replay or build is used.
## Run only when separately authorized, with a nonexistent --output-dir.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadPolicy232.gd")
const Pipeline232 = preload("res://alien_foundry/scripts/pipeline/BlobLiveQuadPipeline232.gd")
const LegacySerializer = preload("res://alien_foundry/scripts/persistence/CreatureSerializer.gd")
const ROOT_FIELDS: Array = ["format", "format_version", "experiment", "mode", "policy_pin232", "artifact_geometry_key", "cache_slot", "seed", "stage", "quality", "recipe229"]
const NESTED_FIELDS: Array = ["format", "format_version", "experiment", "mode", "policy_pin", "source_raw_sha256", "source_geometry_key", "artifact_geometry_key", "source_grid", "source_axes_f32_le", "reference_cell_f64_le", "reference_origin_f32_le", "source_vertices", "source_faces"]
const ROOT_INTEGER_FIELDS: Array = ["format_version", "seed", "stage", "quality"]
const NESTED_INTEGER_FIELDS: Array = ["format_version", "source_vertices", "source_faces"]
const PUBLIC_NEGATIVE_CASES: int = 80
# Source-counted schedule: schema6 + roundtrip5 + types10 + integral6 +
# envelope4 + matrix_count1 + public_negatives(80 * 5) + malformed_JSON2 +
# byte_boundary8 + final_invariants4 = 446. Never derive this from report.checks.
const EXPECTED_CHECKS: int = 446
var output: String = ""
var report: Dictionary = {
	"suite": "live_quad232_public_recipe_contract", "checks": 0, "expected_checks": EXPECTED_CHECKS,
	"failures": [], "status": "NOT_RUN", "public_negative_cases": PUBLIC_NEGATIVE_CASES,
	"public_negative_case_labels": [], "public_enabled_filename": "enabled232_recipe.json",
	"recipe_byte_cap": 65536, "complete_field_calls": 0, "complete_field_values": 0,
	"lattice_samples": 0, "edge_solves": 0, "mesh_builds": 0, "retained_replays": 0,
	"source_authentications": 0, "successful_live_builds": 0,
	"scope": "declaration_and_public_json_io_only"
}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	report.checks += 1
	if not ok:
		report.failures.append(label)
		push_error(label)

func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	return status == OK

func _write(path: String, value: Variant) -> bool:
	return _write_text(path, JSON.stringify(value, "", true, true))

func _same_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for name: String in fields:
		if not value.has(name):
			return false
	return true

func _changed(canonical: Dictionary, path: Array, value: Variant) -> Dictionary:
	var changed: Dictionary = canonical.duplicate(true)
	var cursor: Variant = changed
	for index in range(path.size() - 1):
		cursor = cursor[path[index]]
	cursor[path[path.size() - 1]] = value
	return changed

func _negative_cases(canonical: Dictionary) -> Array:
	var cases: Array = []
	# All11 live fields: each missing and each independently wrong-typed (22).
	for name: String in ROOT_FIELDS:
		var missing: Dictionary = canonical.duplicate(true)
		missing.erase(name)
		cases.append({"label": "missing232_" + name, "value": missing})
		var wrong: Dictionary = canonical.duplicate(true)
		wrong[name] = []
		cases.append({"label": "wrong_type232_" + name, "value": wrong})
	# All14 nested chooser fields, not merely the outer dictionary type (28).
	for name: String in NESTED_FIELDS:
		var missing: Dictionary = canonical.duplicate(true)
		missing.recipe229.erase(name)
		cases.append({"label": "missing229_" + name, "value": missing})
		var wrong: Dictionary = canonical.duplicate(true)
		wrong.recipe229[name] = [] if canonical.recipe229[name] is String or canonical.recipe229[name] is int else "wrong-type"
		cases.append({"label": "wrong_type229_" + name, "value": wrong})
	# Three non-object roots plus unknown fields at each schema level (5).
	cases.append({"label": "null_root", "value": null})
	cases.append({"label": "array_root", "value": []})
	cases.append({"label": "string_root", "value": "232"})
	var unknown_root: Dictionary = canonical.duplicate(true)
	unknown_root["unknown_live_policy"] = true
	cases.append({"label": "unknown232_field", "value": unknown_root})
	var unknown_nested: Dictionary = canonical.duplicate(true)
	unknown_nested.recipe229["unknown_chooser_policy"] = true
	cases.append({"label": "unknown229_field", "value": unknown_nested})
	# Nineteen typed changes: exact source/grid/pin/identity bindings, numeric
	# fractions, boolean-as-number coercion, and fixed live selection are strict.
	var mutations: Array = [
		["changed229_source_sha", ["recipe229", "source_raw_sha256"], "0".repeat(64)],
		["changed229_source_key", ["recipe229", "source_geometry_key"], "0".repeat(64)],
		["changed229_grid", ["recipe229", "source_grid", 0], int(canonical.recipe229.source_grid[0]) + 1],
		["fractional229_grid", ["recipe229", "source_grid", 1], float(canonical.recipe229.source_grid[1]) + 0.25],
		["boolean229_grid", ["recipe229", "source_grid", 2], true],
		["changed229_axes", ["recipe229", "source_axes_f32_le", 0], "00"],
		["changed229_pin", ["recipe229", "policy_pin"], "0".repeat(64)],
		["changed229_artifact_key", ["recipe229", "artifact_geometry_key"], Policy.ARTIFACT_KEY],
		["fractional232_version", ["format_version"], 1.25],
		["fractional232_seed", ["seed"], 22.25],
		["fractional232_stage", ["stage"], 5.25],
		["fractional232_quality", ["quality"], 1.25],
		["boolean232_stage", ["stage"], true],
		["changed232_pin", ["policy_pin232"], Policy.Quad.PIN],
		["changed232_mode", ["mode"], Policy.Quad.MODE],
		["changed232_artifact_key", ["artifact_geometry_key"], Policy.Quad.ARTIFACT_KEY],
		["changed232_cache_slot", ["cache_slot"], "blob.quad229.retained_stage5"],
		["short229_grid", ["recipe229", "source_grid"], canonical.recipe229.source_grid.slice(0, 2)],
		["changed232_seed", ["seed"], 23]
	]
	for mutation: Array in mutations:
		cases.append({"label": mutation[0], "value": _changed(canonical, mutation[1], mutation[2])})
	# Six foreign envelopes. The live request below is a declaration only; its
	# relative source string is never opened and no live/retained build is called.
	cases.append({"label": "retained229_recipe_envelope", "value": Policy.Quad.recipe()})
	cases.append({"label": "live232_request_envelope", "value": Pipeline232.request("source224.bin", canonical)})
	cases.append({"label": "live232_artifact_envelope", "value": {
		"format": Pipeline232.ARTIFACT_FORMAT, "artifact_version": 1,
		"recipe232": canonical.duplicate(true), "mesh_data": {}
	}})
	cases.append({"label": "retained229_artifact_envelope", "value": {
		"format": "predator-isle-quad-artifact229", "artifact_version": 1,
		"recipe229": canonical.recipe229.duplicate(true), "mesh_data": {}
	}})
	cases.append({"label": "legacy_dna_envelope", "value": {
		"format": LegacySerializer.FORMAT, "format_version": LegacySerializer.FORMAT_VERSION,
		"dna": {"version": 1}
	}})
	cases.append({"label": "legacy_direct_anatomy", "value": {
		"version": 1, "render_generation": 2, "type": "Blob", "seed": 22,
		"settings": {"blob_pipeline_mode": "iterative_v2"}
	}})
	return cases

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--output-dir" or args[1].is_empty():
		push_error("232 public recipe contract requires only --output-dir <fresh-directory>")
		quit(1)
		return
	output = ProjectSettings.globalize_path(args[1])
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		push_error("232 public recipe contract refuses an existing output path")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("232 public recipe contract cannot create its fresh output directory")
		quit(1)
		return

	# Schema and identity: 6 checks.
	var canonical: Dictionary = Policy.recipe()
	var canonical_before: PackedByteArray = var_to_bytes(canonical)
	check(Policy.validate_recipe(canonical).ok, "Canonical232 recipe validates")
	check(_same_fields(canonical, ROOT_FIELDS), "Exact11-field live schema")
	check(_same_fields(canonical.recipe229, NESTED_FIELDS), "Exact14-field nested chooser schema")
	check(Policy.ARTIFACT_KEY != Policy.Quad.ARTIFACT_KEY and Policy.ARTIFACT_KEY != Policy.Quad.SOURCE_KEY, "Live retained and field identities are distinct")
	check(("quad_live232:v1|" + Policy.Quad.SOURCE_KEY + "|" + Policy.Quad.SOURCE_RAW_SHA + "|" + Policy.Quad.PIN + "|" + Policy.PIN).sha256_text() == Policy.ARTIFACT_KEY, "Live identity binds exact field chooser and workflow")
	check(Policy.MAX_RECIPE_BYTES == 65536, "Public recipe byte cap is exactly65536")

	# Actual public save/load, not a validation-only substitute: 5 checks.
	var enabled_path: String = output.path_join("enabled232_recipe.json")
	check(not FileAccess.file_exists(enabled_path) and not FileAccess.file_exists(enabled_path + ".tmp"), "Fresh enabled recipe destination")
	check(Policy.save_recipe(enabled_path, canonical).ok, "Actual public232 save")
	check(FileAccess.file_exists(enabled_path) and not FileAccess.file_exists(enabled_path + ".tmp"), "Public save commits only the final recipe")
	var loaded: Dictionary = Policy.load_recipe(enabled_path)
	var restored: Dictionary = loaded.get("recipe", {})
	var restored_nested: Dictionary = restored.get("recipe229", {})
	var restored_grid: Variant = restored_nested.get("source_grid")
	check(loaded.ok, "Actual public232 load")
	check(loaded.ok and var_to_bytes(restored) == canonical_before, "Public JSON roundtrip restores byte-exact canonical types")
	var enabled_sha: String = FileAccess.get_sha256(enabled_path)

	# Every integer-bearing field, including all three grid components: 10.
	for name: String in ROOT_INTEGER_FIELDS:
		check(restored.get(name) is int, "Restored232 integer type " + name)
	for name: String in NESTED_INTEGER_FIELDS:
		check(restored_nested.get(name) is int, "Restored229 integer type " + name)
	for axis in range(3):
		check(restored_grid is Array and restored_grid.size() == 3 and restored_grid[axis] is int, "Restored229 integer grid axis " + str(axis))

	# Integral JSON numbers are permitted, normalized, and never mutate input: 6.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(enabled_path))
	check(parsed is Dictionary and parsed.get("stage") is float, "Actual saved JSON exposes an integral floating-number shadow")
	var floating: Dictionary = canonical.duplicate(true)
	for name: String in ROOT_INTEGER_FIELDS:
		floating[name] = float(floating[name])
	for name: String in NESTED_INTEGER_FIELDS:
		floating.recipe229[name] = float(floating.recipe229[name])
	for axis in range(3):
		floating.recipe229.source_grid[axis] = float(floating.recipe229.source_grid[axis])
	var floating_before: PackedByteArray = var_to_bytes(floating)
	var normalized: Dictionary = Policy.validate_recipe(floating)
	check(normalized.ok and var_to_bytes(normalized.get("recipe", {})) == canonical_before, "All integral float declarations restore canonical integer values")
	var integral_path: String = output.path_join("integral232_recipe.json")
	check(Policy.save_recipe(integral_path, floating).ok, "Public save accepts integral numeric shadows")
	var integral_loaded: Dictionary = Policy.load_recipe(integral_path)
	check(integral_loaded.ok, "Public load accepts saved integral numeric shadows")
	check(integral_loaded.ok and var_to_bytes(integral_loaded.get("recipe", {})) == canonical_before, "Integral public roundtrip restores every canonical type")
	check(var_to_bytes(floating) == floating_before, "Integral declaration input is not mutated")

	# Cross-envelope guards only; no dispatch, source authentication or field: 4.
	check(not Policy.Quad.load_recipe(enabled_path).ok, "Retained229 loader cannot accept live232 recipe")
	# Missing anatomy version rejects before legacy field-bearing qualification.
	var legacy_loaded: Dictionary = LegacySerializer.load_dna(enabled_path)
	check(not legacy_loaded.ok and legacy_loaded.get("error") == "Unsupported anatomy version; expected version 1.", "Legacy DNA loader rejects live232 at its initial anatomy-version guard")
	check(not Pipeline232.validate_request(canonical).ok, "Bare recipe is not an explicit live request")
	check(Pipeline232.validate_request(Pipeline232.request("source224.bin", restored)).ok, "Restored recipe works in the pure explicit live request validator")

	var malformed: Array = _negative_cases(canonical)
	check(malformed.size() == PUBLIC_NEGATIVE_CASES, "All80 predeclared public negative declarations retained")
	for index in range(malformed.size()):
		var entry: Dictionary = malformed[index]
		var label: String = entry.label
		var bad_path: String = output.path_join("malformed232_%02d.json" % index)
		report.public_negative_case_labels.append(label)
		check(not Policy.validate_recipe(entry.value).ok, "Declaration rejects " + label)
		check(not Policy.save_recipe(bad_path, entry.value).ok, "Public save rejects " + label)
		check(not FileAccess.file_exists(bad_path) and not FileAccess.file_exists(bad_path + ".tmp"), "Rejected public save creates no final or temporary file " + label)
		check(_write(bad_path, entry.value), "Persist malformed public fixture " + label)
		check(not Policy.load_recipe(bad_path).ok, "Public load rejects persisted " + label)

	# Malformed JSON syntax is distinct from schema rejection: 2 checks.
	var broken_json_path: String = output.path_join("malformed232_syntax.json")
	check(_write_text(broken_json_path, "{\"format\":"), "Persist explicitly malformed JSON syntax")
	var broken_json: Dictionary = Policy.load_recipe(broken_json_path)
	check(not broken_json.ok and broken_json.get("error") == "232 malformed recipe JSON.", "Public loader rejects malformed JSON at parser boundary")

	# Whitespace keeps both boundary fixtures valid JSON. Only their byte counts
	# differ: exactly65536 is allowed;65537 must hit the byte-cap guard (8 checks).
	var compact: String = JSON.stringify(canonical, "", true, true)
	var compact_bytes: int = compact.to_utf8_buffer().size()
	check(compact_bytes < 65536, "Canonical JSON leaves room for exact byte-boundary fixture")
	var boundary_text: String = compact + " ".repeat(maxi(0, 65536 - compact_bytes))
	check(boundary_text.to_utf8_buffer().size() == 65536, "Accepted boundary fixture is exactly65536 bytes")
	var boundary_path: String = output.path_join("boundary232_65536.json")
	check(_write_text(boundary_path, boundary_text), "Persist valid JSON at exact byte cap")
	var boundary_loaded: Dictionary = Policy.load_recipe(boundary_path)
	check(boundary_loaded.ok, "Exactly65536-byte valid recipe is accepted")
	check(boundary_loaded.ok and var_to_bytes(boundary_loaded.get("recipe", {})) == canonical_before, "Boundary JSON restores canonical recipe")
	var oversized_text: String = boundary_text + " "
	check(oversized_text.to_utf8_buffer().size() == 65537, "Oversize fixture exceeds the65536-byte cap by one")
	var oversized_path: String = output.path_join("oversized232_65537.json")
	check(_write_text(oversized_path, oversized_text), "Persist valid JSON above byte cap")
	var oversized: Dictionary = Policy.load_recipe(oversized_path)
	check(not oversized.ok and oversized.get("error") == "232 recipe byte cap.", "Public loader rejects oversize JSON before parsing")

	# Inputs, enabled artifact and zero-work scope remain unchanged: 4 checks.
	check(var_to_bytes(canonical) == canonical_before and var_to_bytes(Policy.recipe()) == canonical_before, "Canonical recipe remains unchanged after all public negatives")
	check(FileAccess.get_sha256(enabled_path) == enabled_sha, "Malformed and boundary fixtures never overwrite the enabled recipe")
	var reloaded: Dictionary = Policy.load_recipe(enabled_path)
	check(reloaded.ok and var_to_bytes(reloaded.get("recipe", {})) == canonical_before, "Enabled recipe still restores after the complete negative matrix")
	check(report.complete_field_calls == 0 and report.complete_field_values == 0 and report.lattice_samples == 0 and report.edge_solves == 0 and report.mesh_builds == 0 and report.retained_replays == 0 and report.source_authentications == 0 and report.successful_live_builds == 0, "Declaration-only contract retains zero geometry and replay counters")

	report["exact_expected_check_count"] = int(report.checks) == EXPECTED_CHECKS
	if not report.exact_expected_check_count:
		report.failures.append("Unexpected232 public recipe check count")
	report["status"] = "PASS" if report.failures.is_empty() else "FAIL"
	if not _write_text(output.path_join("contract_report.json"), JSON.stringify(report, "\t", true, true)):
		push_error("Cannot persist232 public recipe contract report")
		quit(1)
		return
	print(JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
