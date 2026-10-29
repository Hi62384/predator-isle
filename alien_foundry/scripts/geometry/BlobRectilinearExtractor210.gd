extends "res://alien_foundry/scripts/geometry/MeshExtractor.gd"
## Keep traversal, tetrahedra, shared-edge ownership, solver and face rejection
## inherited verbatim. Only the point lookup differs from the original class.
const Grid210 = preload("res://alien_foundry/scripts/geometry/BlobRectilinearGrid210.gd")
var canonical_axes: Array[PackedFloat32Array] = []

func extract_rectilinear(values: PackedFloat32Array, axes: Array, minimum: Vector3, reference_step: float, job: RefCounted = null, refinement: RefCounted = null, high_preview: bool = false) -> Dictionary:
	var validated: Dictionary = Grid210.validate_axes(axes, high_preview)
	if not bool(validated.ok):
		return {"error": str(validated.error)}
	var dims: Vector3i = validated.dimensions
	if values.size() != int(validated.samples):
		return {"error": "210 rectilinear sample count does not match its canonical axes."}
	if not minimum.is_finite() or not is_finite(reference_step) or reference_step <= 0.0:
		return {"error": "210 requires the original finite minimum and positive normal-reference step."}
	var x_axis: PackedFloat32Array = axes[0]
	var y_axis: PackedFloat32Array = axes[1]
	var z_axis: PackedFloat32Array = axes[2]
	if minimum != Vector3(x_axis[0], y_axis[0], z_axis[0]):
		return {"error": "210 canonical axis origins do not match the original grid minimum."}
	for value: float in values:
		if not is_finite(value):
			return {"error": "210 rectilinear extraction rejects nonfinite field samples."}
	# Never allow the inherited uniform-gradient / normal-reconciliation path.
	if refinement == null or not refinement.has_method("solve") or not refinement.has_method("reject") or not refinement.has_method("snapshot"):
		return {"error": "210 rectilinear extraction requires an explicit complete-field edge/normal solver."}
	var snapshot_value: Variant = refinement.call("snapshot")
	if not snapshot_value is Dictionary:
		return {"error": "210 refinement solver snapshot is malformed."}
	var snapshot: Dictionary = snapshot_value
	if snapshot.get("error", "") != "" or int(snapshot.get("unique_edges", -1)) != 0 or int(snapshot.get("continuous_queries", -1)) != 0 or int(snapshot.get("endpoint_cache_entries", -1)) != 0:
		return {"error": "210 requires a fresh error-free per-pass solver and endpoint cache."}
	canonical_axes = [x_axis.duplicate(), y_axis.duplicate(), z_axis.duplicate()]
	# _point is dynamically dispatched by the inherited traversal and _edge.
	# reference_step remains the ORIGINAL step, not an inserted interval width.
	return super.extract(values, dims, minimum, reference_step, job, refinement)

func _point(index: int) -> Vector3:
	@warning_ignore("integer_division")
	var z: int = index / plane
	var remainder: int = index - z * plane
	@warning_ignore("integer_division")
	var y: int = remainder / dimensions.x
	var x: int = remainder - y * dimensions.x
	var x_axis: PackedFloat32Array = canonical_axes[0]
	var y_axis: PackedFloat32Array = canonical_axes[1]
	var z_axis: PackedFloat32Array = canonical_axes[2]
	return Vector3(x_axis[x], y_axis[y], z_axis[z])
