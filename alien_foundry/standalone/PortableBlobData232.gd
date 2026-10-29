extends RefCounted
## Fixed artifact I/O and pure worker entry. Does not construct render resources.
const Pipeline = preload("res://alien_foundry/scripts/pipeline/BlobLiveQuadPipeline232.gd")
const Policy = preload("res://alien_foundry/scripts/geometry/BlobLiveQuadPolicy232.gd")
const PREVIEW_PATH: String = "res://alien_foundry/standalone/data/retained229_raw.bin"
const SOURCE_PATH: String = "res://alien_foundry/standalone/data/field224_rejected_raw.bin"
const RECIPE_PATH: String = "res://alien_foundry/standalone/data/live_recipe232.json"
const PREVIEW_SHA: String = "c8262763f42eaa76468f3467baff2a007307006a7b6cd32323949272bf2bb4ae"
const PREVIEW_BYTES: int = 13599720
const POSITIONS_SHA: String = "8ddb4fb663bb6a7bc8161fe64844670788c16dfa64233afe8c85ea32e0d8102c"
const NORMALS_SHA: String = "004135154db06bcf8d6edbc42ee4a0c622095803476aefafeba992a3a308464f"
const INDICES_SHA: String = "225369d67d6f4837b7d106b69dc6d8cf27332509c2dfc3b7cfcaa03195052486"
const RAW_CAP: int = 67108864

static func fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func digest(bytes: PackedByteArray) -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): hash.update(bytes)
	return hash.finish().hex_encode()

static func validate_mesh(value: Variant) -> Dictionary:
	if not value is Dictionary: return fail("Missing mesh data.")
	if not value.get("vertices") is PackedVector3Array or not value.get("normals") is PackedVector3Array or not value.get("indices") is PackedInt32Array: return fail("Mesh channels have invalid native types.")
	var vertices: PackedVector3Array = value.vertices
	var normals: PackedVector3Array = value.normals
	var indices: PackedInt32Array = value.indices
	if vertices.size() != 17958 or normals.size() != 17958 or indices.size() != 107736: return fail("Not the supported fixed blob geometry.")
	for vertex: Vector3 in vertices:
		if not vertex.is_finite(): return fail("Nonfinite position.")
	for normal: Vector3 in normals:
		if not normal.is_finite() or normal.length_squared() < 0.9 or normal.length_squared() > 1.1: return fail("Invalid source normal.")
	for index: int in indices:
		if index < 0 or index >= vertices.size(): return fail("Out-of-range face index.")
	if digest(vertices.to_byte_array()) != POSITIONS_SHA or digest(normals.to_byte_array()) != NORMALS_SHA or digest(indices.to_byte_array()) != INDICES_SHA: return fail("Geometry differs from the fixed 229/232 reference; keeping the last good preview.")
	var bounds: AABB = AABB(vertices[0],Vector3.ZERO)
	for vertex: Vector3 in vertices: bounds = bounds.expand(vertex)
	return {"ok":true,"error":"","mesh":value,"bounds":bounds}

static func load_preview() -> Dictionary:
	var file: FileAccess = FileAccess.open(PREVIEW_PATH,FileAccess.READ)
	if file == null: return fail("Bundled preview is missing.")
	if file.get_length() != PREVIEW_BYTES or FileAccess.get_sha256(PREVIEW_PATH) != PREVIEW_SHA:
		file.close(); return fail("Bundled preview integrity check failed.")
	var value: Variant = file.get_var(false)
	var complete: bool = file.get_position() == file.get_length(); file.close()
	if not complete or not value is Dictionary: return fail("Invalid preview packet.")
	if value.get("format") != "predator-isle-quad-artifact229" or value.get("status") != "retained_retriangulation229_unqualified" or value.get("seed") != 22: return fail("Unexpected preview identity.")
	return validate_mesh(value.get("mesh_data"))

static func generation_request() -> Dictionary:
	if FileAccess.get_sha256(SOURCE_PATH) != Policy.Quad.SOURCE_RAW_SHA: return fail("Bundled generation input is missing or changed.")
	var loaded: Dictionary = Policy.load_recipe(RECIPE_PATH)
	if not loaded.ok: return fail(str(loaded.error))
	var request: Dictionary = Pipeline.request(SOURCE_PATH,loaded.recipe)
	var valid: Dictionary = Pipeline.validate_request(request)
	if not valid.ok: return fail(str(valid.error))
	return {"ok":true,"request":request}

static func _save_result(result: Dictionary) -> Dictionary:
	var directory: String = "user://blob232_runs/" + str(int(Time.get_unix_time_from_system())) + "_" + str(Time.get_ticks_usec())
	if DirAccess.dir_exists_absolute(directory) or DirAccess.make_dir_recursive_absolute(directory) != OK: return fail("Could not create a fresh results directory.")
	var bytes: PackedByteArray = var_to_bytes(result)
	if bytes.size()+4 > RAW_CAP: return fail("Result exceeds the 64 MiB save limit.")
	var path: String = directory.path_join("live232_result.bin")
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file == null: return fail("Could not save generated result.")
	file.store_var(result); file.flush(); var error: Error = file.get_error(); file.close()
	if error != OK: return fail("Result write failed; partial data retained at " + ProjectSettings.globalize_path(directory))
	file = FileAccess.open(path,FileAccess.READ)
	if file == null: return fail("Could not verify saved result.")
	var restored: Variant = file.get_var(false)
	var complete: bool = file.get_position() == file.get_length(); file.close()
	if not complete or var_to_bytes(restored) != bytes: return fail("Saved result verification failed.")
	return {"ok":true,"path":ProjectSettings.globalize_path(path),"sha256":FileAccess.get_sha256(path),"bytes":bytes.size()+4}

static func run_build(request: Dictionary, controls: RefCounted) -> Dictionary:
	var result: Dictionary = Pipeline.new().build(request,null,controls)
	# Preserve original native flags and rejected/cancelled results too.
	var saved: Dictionary = _save_result(result)
	return {"artifact":result,"persistence":saved}
