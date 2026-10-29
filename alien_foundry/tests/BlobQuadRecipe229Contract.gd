extends SceneTree
## Pure declaration plus actual versioned public recipe save/load. No field,
## anatomy qualification, lattice, edge solve, mesh extraction or legacy edits.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobQuadPolicy229.gd")
const Grid = preload("res://alien_foundry/scripts/geometry/BlobRectilinearGrid210.gd")
const LegacySerializer = preload("res://alien_foundry/scripts/persistence/CreatureSerializer.gd")
const EXPECTED_CHECKS: int = 108
var output: String = ""
var report: Dictionary = {"suite": "quad229_recipe_public_contract", "checks": 0, "failures": [], "complete_field_calls": 0, "lattice_samples": 0, "edge_solves": 0, "mesh_builds": 0, "public_negative_cases": 20, "public_enabled_filename": "enabled229_recipe.json"}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	report.checks += 1
	if not ok:
		report.failures.append(label)
		push_error(label)

func _write(path: String, value: Variant) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "", true, true)); file.flush()
	var result: Error = file.get_error(); file.close()
	return result == OK

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--output-dir": output = args[i + 1]
	if output.is_empty() or FileAccess.file_exists(output.path_join("contract_report.json")):
		push_error("229 recipe contract requires fresh --output-dir"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var canonical: Dictionary = Policy.recipe()
	check(Policy.validate_recipe(canonical).ok, "Canonical recipe validates")
	check(Policy.ARTIFACT_KEY != Policy.SOURCE_KEY, "New architecture has a distinct identity")
	check(("quad_alignment229:v1|" + Policy.SOURCE_KEY + "|" + Policy.SOURCE_RAW_SHA + "|" + Policy.PIN).sha256_text() == Policy.ARTIFACT_KEY, "Identity binds source and policy")
	var axes: Array = Policy.axes()
	check(Grid.validate_axes(axes, true).ok, "Pinned224 canonical axes remain valid")
	for axis in range(3):
		check(axes[axis] is PackedFloat32Array and axes[axis].to_byte_array().hex_encode() == Policy.SOURCE_AXES_HEX[axis], "Exact packed axis bytes " + str(axis))
		check(axes[axis].size() == Policy.SOURCE_GRID[axis], "Exact axis length " + str(axis))
	var malformed: Array = []
	for name: String in canonical:
		var missing: Dictionary = canonical.duplicate(true); missing.erase(name)
		check(not Policy.validate_recipe(missing).ok, "Missing field rejected " + name)
		var wrong: Dictionary = canonical.duplicate(true)
		wrong[name] = [] if canonical[name] is String or canonical[name] is int else "invalid"
		check(not Policy.validate_recipe(wrong).ok, "Wrong type rejected " + name)
		malformed.append(wrong)
	check(not Policy.validate_recipe(null).ok, "Null declaration rejected")
	check(not Policy.validate_recipe([]).ok, "Array declaration rejected")
	var unknown: Dictionary = canonical.duplicate(true); unknown["unknown_policy"] = true
	check(not Policy.validate_recipe(unknown).ok, "Unknown declaration field rejected"); malformed.append(unknown)
	var missing_format: Dictionary = canonical.duplicate(true); missing_format.erase("format"); malformed.append(missing_format)
	var bad_hash: Dictionary = canonical.duplicate(true); bad_hash.source_raw_sha256 = "0".repeat(64); malformed.append(bad_hash)
	var bad_grid: Dictionary = canonical.duplicate(true); bad_grid.source_grid[0] += 1; malformed.append(bad_grid)
	var bad_axes: Dictionary = canonical.duplicate(true); bad_axes.source_axes_f32_le[0] = "00"; malformed.append(bad_axes)
	var fractional: Dictionary = canonical.duplicate(true); fractional.format_version = 1.25; malformed.append(fractional)
	check(malformed.size() == 20, "All20 predeclared public negatives retained")
	var enabled_path: String = output.path_join("enabled229_recipe.json")
	check(not FileAccess.file_exists(enabled_path), "Fresh enabled recipe path")
	check(Policy.save_recipe(enabled_path, canonical).ok, "Actual public229 save")
	var loaded: Dictionary = Policy.load_recipe(enabled_path)
	check(loaded.ok, "Actual public229 load")
	check(loaded.ok and var_to_bytes(loaded.recipe) == var_to_bytes(canonical), "Public JSON shadows restore canonical recipe types")
	# Legacy serializer rejects the distinct envelope at its initial version
	# check, before iterative field-bearing qualification can be entered.
	check(not LegacySerializer.load_dna(enabled_path).ok, "Legacy serializer cannot silently accept229")
	for i in range(malformed.size()):
		var bad_path: String = output.path_join("malformed229_%02d.json" % i)
		check(not Policy.save_recipe(bad_path, malformed[i]).ok, "Public save rejects negative " + str(i))
		check(_write(bad_path, malformed[i]), "Persist malformed public fixture " + str(i))
		check(not Policy.load_recipe(bad_path).ok, "Public load rejects negative " + str(i))
	check(var_to_bytes(canonical) == var_to_bytes(Policy.recipe()), "Input recipe remains unchanged")
	report["expected_checks"] = EXPECTED_CHECKS
	report["exact_expected_check_count"] = int(report.checks) == EXPECTED_CHECKS
	if not report.exact_expected_check_count: report.failures.append("Unexpected229 recipe check count")
	report["status"] = "PASS" if report.failures.is_empty() else "FAIL"
	var file: FileAccess = FileAccess.open(output.path_join("contract_report.json"), FileAccess.WRITE)
	if file == null: push_error("Cannot persist229 recipe report"); quit(1); return
	file.store_string(JSON.stringify(report, "\t", true, true)); file.close()
	print(JSON.stringify(report)); quit(0 if report.failures.is_empty() else 1)
