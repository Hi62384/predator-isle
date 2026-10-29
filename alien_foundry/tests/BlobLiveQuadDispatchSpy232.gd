extends "res://alien_foundry/scripts/geometry/BlobLiveQuadVolume232.gd"
## Test-only substitute for _build_once, before any field preparation. The public
## armed entry still authenticates the actual224 file and calls the real parent
## build preflight. No successful mesh or preparation state is fabricated.
var spy_kind: String = "conforming"
var spy_build_once_calls: int = 0
var spy_callback_calls: int = 0
var spy_old_recipe_path: String = ""

func _build_once(_dna: Dictionary, _quality: int, _job: RefCounted) -> Dictionary:
	spy_build_once_calls += 1
	spy_old_recipe_path = slab_pilot_path
	if spy_kind == "conforming":
		# Reaches the real232 override and stops at its unprepared context gate.
		return _extract_conforming_slabs210(null)
	if spy_kind == "extractor":
		# Exact recipe/reference guard path, but EMPTY values reject before any
		# traversal or callback. The actual production dispatch constructs229.
		step = Quad232.CELL_BITS.hex_decode().decode_double(0)
		var origin_data: PackedByteArray = Quad232.ORIGIN_BITS.hex_decode()
		bounds = AABB(Vector3(origin_data.decode_float(0),origin_data.decode_float(4),origin_data.decode_float(8)),Vector3.ONE)
		var solver: RefCounted = SlabEdge.create_cumulative(_unexpected_query,step,Live232.PRIOR_EDGES,Live232.PRIOR_QUERIES)
		return _dispatch_extractor232(PackedFloat32Array(),null,solver)
	return {"error":"232 test spy unknown branch."}

func _unexpected_query(_point: Vector3) -> float:
	spy_callback_calls += 1
	push_error("232 cheap spy must never query a field")
	return NAN
