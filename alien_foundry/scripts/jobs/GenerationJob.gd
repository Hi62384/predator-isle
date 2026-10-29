class_name GenerationJob
extends RefCounted
## One cancellable job. The worker touches plain data/resources, never the live tree.

const Serializer = preload("res://alien_foundry/scripts/persistence/CreatureSerializer.gd")
const Lineage = preload("res://alien_foundry/scripts/anatomy/CreatureLineage.gd")
const Generator = preload("res://alien_foundry/scripts/generators/CreatureGenerator.gd")
const Volume = preload("res://alien_foundry/scripts/geometry/OrganicVolume.gd")
const Renderer = preload("res://alien_foundry/scripts/rendering/CreatureRenderer.gd")
const Pipeline = preload("res://alien_foundry/scripts/pipeline/BlobPipeline.gd")

var _thread := Thread.new()
var _mutex := Mutex.new()
var _cancelled := false
var _done := false
var _progress := 0.0
var _stage := "Preparing anatomy"
var _result: Dictionary = {}
var _started_usec: int = 0
var request: Dictionary = {}
var pipeline_cache: RefCounted = null

func start(input: Dictionary) -> Error:
	_started_usec = Time.get_ticks_usec()
	var checked := Lineage.validate_json(input)
	if not checked["ok"]:
		_complete(checked)
		return OK
	if input.has("dna"):
		if not input.dna is Dictionary:
			_complete({"error": "The reconstruction request must contain a DNA object."})
			return OK
		checked = Serializer.validate_dna(input.dna)
		if not bool(checked.get("ok", false)):
			_complete(checked)
			return OK
	elif not input.get("settings", {}) is Dictionary:
		_complete({"error": "Generation settings must be an object."})
		return OK
	if bool(input.get("materials_only", false)) and not (input.has("dna") and Pipeline.supports(input)):
		_complete({"error": "Material-only refresh requires a preserved staged Blob. The anatomy was not regenerated."})
		return OK
	request = input.duplicate(true)
	return _thread.start(_run)

func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_stage = "Cancelling safely…"
	_mutex.unlock()

func is_cancelled() -> bool:
	_mutex.lock()
	var value := _cancelled
	_mutex.unlock()
	return value

func set_progress(value: float, stage: String) -> void:
	_mutex.lock()
	if not _cancelled and is_finite(value):
		# A bounded detail/budget rebuild may re-enter an earlier compute stage.
		# Keep its new explanation without moving the progress bar backwards.
		_progress = maxf(_progress, clampf(value, 0.0, 1.0))
		_stage = stage
	_mutex.unlock()

func snapshot() -> Dictionary:
	_mutex.lock()
	var result := {"done": _done, "progress": _progress, "stage": _stage, "cancelled": _cancelled}
	_mutex.unlock()
	result["elapsed"] = (Time.get_ticks_usec() - _started_usec) / 1000000.0
	return result

func finish() -> Dictionary:
	if _thread.is_started():
		_thread.wait_to_finish()
	return _result

func shutdown() -> void:
	cancel()
	if _thread.is_started():
		_thread.wait_to_finish()

func _complete(result: Dictionary) -> void:
	_mutex.lock()
	_result = result
	_done = true
	_mutex.unlock()

func _run() -> void:
	if Pipeline.supports(request):
		var staged: Dictionary = Pipeline.new().build(request, pipeline_cache, self)
		if is_cancelled():
			staged = {"cancelled": true}
		_complete(staged)
		return
	set_progress(0.01, "Growing anatomical structure")
	var dna: Dictionary
	if request.has("dna"):
		dna = request["dna"].duplicate(true)
	else:
		dna = Generator.new().generate(str(request.get("type", "Humanoid")), int(request.get("seed", 1)), request.get("settings", {}))
	if is_cancelled():
		_complete({"cancelled": true})
		return
	if dna.is_empty() or dna.get("nodes", []).is_empty():
		_complete({"error": "The anatomy generator returned no anatomical structure."})
		return
	var graph_validation: Dictionary = Serializer.validate_dna(dna)
	if not graph_validation.get("ok", false):
		_complete(graph_validation)
		return
	var quality: int = int(dna.get("settings", {}).get("quality", request.get("settings", {}).get("quality", 1)))
	set_progress(0.05, "Sampling organic volume")
	var mesh_data: Dictionary = Volume.new().build(dna, quality, self)
	if is_cancelled() or mesh_data.get("cancelled", false):
		_complete({"cancelled": true})
		return
	if mesh_data.has("error"):
		_complete(mesh_data)
		return
	if mesh_data.get("vertices", PackedVector3Array()).is_empty():
		_complete({"error": "The organic volume contained no extractable surface. Try another seed or lower growth density."})
		return
	set_progress(0.94, "Building anatomical rig and skin weights")
	var rig_data: Dictionary = Renderer.new().prepare(dna, mesh_data, self)
	if is_cancelled() or bool(rig_data.get("cancelled", false)):
		_complete({"cancelled": true})
		return
	if rig_data.has("error"):
		_complete(rig_data)
		return
	set_progress(0.98, "Preparing finished organism for display")
	_complete({"dna": dna, "mesh_data": mesh_data, "rig_data": rig_data, "elapsed": (Time.get_ticks_usec() - _started_usec) / 1000000.0, "target": request.get("target", "creature")})
