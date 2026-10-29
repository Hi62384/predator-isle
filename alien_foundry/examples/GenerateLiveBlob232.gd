extends SceneTree
## Portable example only. The production API and all six232 scripts are exact.
## Explicit --generate runs one real fixed-field build, not a retained replay.
const Pipeline = preload("res://alien_foundry/scripts/pipeline/BlobLiveQuadPipeline232.gd")
const Policy = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadPolicy232.gd")
const Artifact229 = preload("res://alien_foundry/scripts/geometry/BlobQuadArtifact229.gd")
const RAW_CAP: int = 67108864
const USAGE: String = "GenerateLiveBlob232.gd -- --validate-only | --generate --output-dir <new-folder> [--recipe <path>] [--source224-raw <path>]. Relative paths start at the checkpoint folder, not the shell working directory."

class Controls extends RefCounted:
	var directory: String
	var start_ms: int
	var last_progress_ms: int = -1000
	func _init(path: String) -> void:
		directory = path
		start_ms = Time.get_ticks_msec()
	func is_cancelled() -> bool:
		return Time.get_ticks_msec() - start_ms >= 900000 or FileAccess.file_exists(directory.path_join("cancel_requested"))
	func set_progress(value: float, message: String) -> void:
		var now: int = Time.get_ticks_msec()
		if now - last_progress_ms < 1000: return
		last_progress_ms = now
		print(JSON.stringify({"progress":value,"message":message,"elapsed_ms":now-start_ms}))

func _initialize() -> void:
	call_deferred("_run")

func _resolve(path: String) -> String:
	if path.is_absolute_path(): return ProjectSettings.globalize_path(path).simplify_path()
	return ProjectSettings.globalize_path("res://alien_foundry/").path_join("..").path_join(path).simplify_path()

func _stop(message: String) -> void:
	push_error(message)
	quit(1)

func _write_json(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data,"\t",true,true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK

func _save_result(path: String, result: Dictionary) -> Dictionary:
	var encoded: PackedByteArray = var_to_bytes(result)
	if encoded.size() + 4 > RAW_CAP: return {"ok":false,"error":"Result exceeds the explicit64MiB persistence ceiling; no truncated packet was written."}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"ok":false,"error":"Cannot open result file."}
	file.store_var(result)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK: return {"ok":false,"error":"Result writer failed; preserve the partial file for diagnosis."}
	file = FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false,"error":"Cannot read back result."}
	var restored: Variant = file.get_var(false)
	var complete: bool = file.get_position() == file.get_length()
	file.close()
	if not complete or not restored is Dictionary or var_to_bytes(restored) != encoded: return {"ok":false,"error":"Result typed readback differs; preserve the file for diagnosis."}
	return {"ok":true,"bytes":encoded.size()+4,"sha256":FileAccess.get_sha256(path),"typed_readback_exact":true}

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 1 and args[0] == "--help": print(USAGE); quit(0); return
	var values: Dictionary = {}
	var index: int = 0
	while index < args.size():
		var option: String = args[index]
		if values.has(option): _stop("Duplicate option: " + option); return
		if option == "--generate" or option == "--validate-only":
			values[option] = true
		elif option in ["--output-dir","--recipe","--source224-raw"]:
			if index + 1 >= args.size() or args[index+1].is_empty() or args[index+1].begins_with("--"): _stop("Missing value for " + option); return
			index += 1
			values[option] = args[index]
		else: _stop("Unknown option: " + option + "\n" + USAGE); return
		index += 1
	if values.has("--generate") == values.has("--validate-only"): _stop("Choose exactly one explicit mode.\n" + USAGE); return
	if values.has("--generate") != values.has("--output-dir"): _stop("Only --generate requires --output-dir <new-folder>."); return
	var recipe_path: String = _resolve(str(values.get("--recipe","recipes/live_recipe232.json")))
	var source_path: String = _resolve(str(values.get("--source224-raw","evidence/field224_rejected_raw.bin")))
	var loaded: Dictionary = Policy.load_recipe(recipe_path)
	if not loaded.ok: _stop(str(loaded.error)); return
	if FileAccess.get_sha256(source_path) != Policy.Quad.SOURCE_RAW_SHA: _stop("Exact authenticated224 source packet is missing or changed. Extract all three229 archives first."); return
	var request: Dictionary = Pipeline.request(source_path,loaded.recipe)
	var checked: Dictionary = Pipeline.validate_request(request)
	if not checked.ok: _stop(str(checked.error)); return
	if values.has("--validate-only"):
		var authenticated: Dictionary = Artifact229.load_source(source_path)
		if not authenticated.ok: _stop(str(authenticated.error)); return
		print(JSON.stringify({"status":"portable_live232_inputs_valid_no_build","source_authentications":1,"successful_live_builds":0,"complete_field_values":0,"lattice_samples":0,"edge_solves":0,"retained_replays":0,"artifact_geometry_key":Policy.ARTIFACT_KEY,"source_sha256":Policy.Quad.SOURCE_RAW_SHA,"recipe_sha256":FileAccess.get_sha256(recipe_path)}))
		quit(0)
		return
	var output: String = _resolve(str(values["--output-dir"]))
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output): _stop("Output must be a nonexistent directory; no existing results are overwritten."); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _stop("Cannot create output directory."); return
	var controls: Controls = Controls.new(output)
	print("Starting one live232 build. Create cancel_requested in the output folder to request cooperative cancellation.")
	var result: Dictionary = Pipeline.new().build(request,null,controls)
	# Persist the untouched API response first, including a rejected/partial result.
	var saved: Dictionary = _save_result(output.path_join("live232_result.bin"),result)
	var success: bool = saved.get("ok",false) and result.get("format") == Pipeline.ARTIFACT_FORMAT and not result.has("error") and not result.get("cancelled",false)
	var mesh: Dictionary = result.get("mesh_data",result)
	var summary: Dictionary = {"schema":"portable_live232_generation_example_v1","status":"generated_not_independently_qualified" if success else "generation_or_persistence_failed","build_attempts":1,"automatic_retries":0,"raw_file":"live232_result.bin","persistence":saved,"native_status":result.get("status",""),"error":result.get("error",""),"cancelled":result.get("cancelled",false),"elapsed_ms":Time.get_ticks_msec()-controls.start_ms,"geometry_key":result.get("geometry_key",""),"field_geometry_key":result.get("field_geometry_key",""),"scope232":mesh.get("live_quad232",{}),"independent_qualification_performed":false,"historical_reference_run_is_not_this_run":true,"native_status_flags_modified":false,"materials_preview_generated":false,"rig_generated":false,"ordinary_UI_changed":false,"general_seed_claim":false}
	if not _write_json(output.path_join("generation_summary.json"),summary): _stop("Could not save generation summary; preserve the output directory."); return
	print(JSON.stringify({"status":summary.status,"build_attempts":1,"output_directory":output,"raw_sha256":saved.get("sha256","")}))
	quit(0 if success else 1)
