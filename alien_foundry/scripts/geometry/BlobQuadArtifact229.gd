extends RefCounted
## Additive explicit229 retained-artifact entry point. This is not a legacy DNA
## loader, a candidate acceptance gate, or permission to re-run any field.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobQuadPolicy229.gd")
const Ownership = preload("res://alien_foundry/scripts/geometry/BlobQuadOwnership229.gd")
const High224 = preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const High226 = preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const FORMAT: String = "predator-isle-quad-artifact229"
const STATUS: String = "retained_retriangulation229_unqualified"

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": "229 " + message}

static func load_source(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("cannot open exact224 source packet.")
	if file.get_length() > Policy.MAX_ARTIFACT_BYTES:
		file.close()
		return _fail("source packet exceeds its byte cap.")
	if FileAccess.get_sha256(path) != Policy.SOURCE_RAW_SHA:
		file.close()
		return _fail("source raw hash is not the retained rejected224 packet.")
	var packet_value: Variant = file.get_var(false)
	var complete: bool = file.get_position() == file.get_length()
	file.close()
	if not complete or not packet_value is Dictionary:
		return _fail("source packet has invalid/trailing encoded data.")
	var packet: Dictionary = packet_value
	var checked: Dictionary = validate_source(packet)
	if not checked.ok:
		return checked
	return {"ok": true, "error": "", "packet": packet, "axes": Policy.axes()}

static func validate_source(packet: Dictionary) -> Dictionary:
	# FileAccess.store_var is a little-endian byte length followed by variant
	# bytes. Bind callers of this in-memory API as tightly as the file loader.
	var native: PackedByteArray = var_to_bytes(packet)
	if native.size() + 4 > Policy.MAX_ARTIFACT_BYTES:
		return _fail("in-memory source exceeds its byte cap.")
	var header: PackedByteArray = PackedByteArray(); header.resize(4); header.encode_u32(0, native.size())
	var digest: HashingContext = HashingContext.new()
	if digest.start(HashingContext.HASH_SHA256) != OK or digest.update(header) != OK or digest.update(native) != OK or digest.finish().hex_encode() != Policy.SOURCE_RAW_SHA:
		return _fail("in-memory source is not byte-exact retained224.")
	if not packet.get("seed") is int or packet.seed != 22 or not packet.get("stage") is int or packet.stage != 5:
		return _fail("source must be exact seed22 partial Stage5.")
	if packet.get("geometry_key") != Policy.SOURCE_KEY or not packet.get("dna") is Dictionary or not packet.get("mesh_data") is Dictionary:
		return _fail("source identity or typed payload is malformed.")
	var dna: Dictionary = packet.dna
	var high: Dictionary = High224.validate(dna)
	var second: Dictionary = High226.validate(dna)
	if not high.ok or not High224.enabled(dna) or not second.ok or High226.enabled(dna):
		return _fail("source must use224, never226 or an unrecognized selector.")
	# Pure exact-recipe/cache restoration, not public serializer qualification.
	if Artifacts.geometry_key(dna, 5, Policy.DEPENDENCY_KEY) != Policy.SOURCE_KEY:
		return _fail("source DNA does not reproduce the exact224 geometry key.")
	var mesh: Dictionary = packet.mesh_data
	if mesh.get("rejected") != true or mesh.get("raw_snapshot_complete") != true or mesh.get("error") != Policy.SOURCE_FACE_ERROR:
		return _fail("source must preserve the complete original224 rejection.")
	if not mesh.get("vertices") is PackedVector3Array or not mesh.get("normals") is PackedVector3Array or not mesh.get("indices") is PackedInt32Array:
		return _fail("source buffers are not native packed arrays.")
	if mesh.vertices.size() != Policy.SOURCE_VERTICES or mesh.normals.size() != Policy.SOURCE_VERTICES or mesh.indices.size() != Policy.SOURCE_FACES * 3:
		return _fail("source mesh counts differ from224.")
	var slabs: Variant = mesh.get("conforming_slabs210")
	if not slabs is Dictionary or not slabs.get("plan") is Dictionary:
		return _fail("source lacks its complete slab plan and ledger.")
	var axes: Variant = slabs.plan.get("axes")
	if not axes is Array or axes.size() != 3:
		return _fail("source canonical axes are malformed.")
	for axis in range(3):
		if not axes[axis] is PackedFloat32Array or axes[axis].to_byte_array().hex_encode() != Policy.SOURCE_AXES_HEX[axis]:
			return _fail("source canonical axes differ from224.")
	if slabs.get("reference_cell_f64_le") != Policy.CELL_BITS or slabs.get("base_origin_f32_le") != Policy.ORIGIN_BITS:
		return _fail("source field reference differs from224.")
	if slabs.get("cumulative_edges") != 31888 or slabs.get("cumulative_edge_queries") != 1141122 or slabs.get("historical_lattice_visits") != 454936 or slabs.get("lattice_visits_new") != 522880:
		return _fail("source historical work ledger differs from224.")
	return {"ok": true, "error": ""}

static func from_retained(path: String, recipe_value: Variant) -> Dictionary:
	var declared: Dictionary = Policy.validate_recipe(recipe_value)
	if not declared.ok:
		return declared
	var loaded: Dictionary = load_source(path)
	if not loaded.ok:
		return loaded
	var source: Dictionary = loaded.packet
	var original_mesh: Dictionary = source.mesh_data
	var before: PackedByteArray = var_to_bytes(original_mesh)
	var replayed: Dictionary = Ownership.replay(original_mesh, loaded.axes)
	if not replayed.ok:
		return replayed
	var mesh: Dictionary = {
		"vertices": original_mesh.vertices.duplicate(), "normals": original_mesh.normals.duplicate(), "indices": replayed.indices.duplicate(),
		"edge_refinement204": original_mesh.edge_refinement204.duplicate(true),
		"edge_refinement204_is_unchanged_source_history": true,
		"active_cells": original_mesh.get("active_cells", 0), "quad_policy229": replayed.report.duplicate(true),
		"triangulation_architecture_changed": true, "root_positions_changed": false, "normals_changed": false,
		"candidate_acceptance": false, "late_gates_pending": true
	}
	var canonical: Dictionary = Ownership.validate_chosen(original_mesh, loaded.axes, mesh)
	if not canonical.ok:
		return canonical
	if var_to_bytes(original_mesh) != before or FileAccess.get_sha256(path) != Policy.SOURCE_RAW_SHA:
		return _fail("source was mutated during retained-only triangulation.")
	var artifact: Dictionary = {
		"format": FORMAT, "artifact_version": 1, "status": STATUS, "recipe229": declared.recipe,
		"geometry_key": Policy.ARTIFACT_KEY, "source_geometry_key": Policy.SOURCE_KEY, "source_raw_sha256": Policy.SOURCE_RAW_SHA,
		"seed": 22, "stage": 5, "dna": source.dna.duplicate(true), "mesh_data": mesh,
		"legacy_dna_geometry_key": Policy.SOURCE_KEY, "geometry_key_is_versioned_artifact_key": true,
		"original_rejection": {"error": original_mesh.error, "rejected": true, "raw_snapshot_complete": true, "authoritative_for": "224", "raw_sha256": Policy.SOURCE_RAW_SHA},
		"work229": {"field_requests": 0, "lattice_visits": 0, "edge_solves": 0, "native_mesh_extractions": 0, "new_sampling_planes": 0, "retained_triangle_reselection": true},
		"historical224_work": {"cumulative_edges": 31888, "cumulative_edge_queries": 1141122, "cumulative_lattice_visits": 977816},
		"artistic_acceptance": false, "late_gates_pending": true
	}
	return {"ok": true, "error": "", "artifact": artifact, "report": replayed.report}

static func validate_artifact(artifact: Dictionary, source: Dictionary) -> Dictionary:
	var checked: Dictionary = validate_source(source)
	if not checked.ok:
		return checked
	var declared: Dictionary = Policy.validate_recipe(artifact.get("recipe229"))
	if not declared.ok:
		return declared
	var fixed: Dictionary = {
		"format": FORMAT, "artifact_version": 1, "status": STATUS, "geometry_key": Policy.ARTIFACT_KEY,
		"source_geometry_key": Policy.SOURCE_KEY, "source_raw_sha256": Policy.SOURCE_RAW_SHA,
		"seed": 22, "stage": 5, "legacy_dna_geometry_key": Policy.SOURCE_KEY,
		"geometry_key_is_versioned_artifact_key": true, "artistic_acceptance": false, "late_gates_pending": true,
		"original_rejection": {"error": Policy.SOURCE_FACE_ERROR, "rejected": true, "raw_snapshot_complete": true, "authoritative_for": "224", "raw_sha256": Policy.SOURCE_RAW_SHA},
		"work229": {"field_requests": 0, "lattice_visits": 0, "edge_solves": 0, "native_mesh_extractions": 0, "new_sampling_planes": 0, "retained_triangle_reselection": true},
		"historical224_work": {"cumulative_edges": 31888, "cumulative_edge_queries": 1141122, "cumulative_lattice_visits": 977816}
	}
	if artifact.size() != fixed.size() + 3:
		return _fail("artifact has missing or unknown metadata.")
	for name: String in fixed:
		if not artifact.has(name) or var_to_bytes(artifact[name]) != var_to_bytes(fixed[name]):
			return _fail("artifact changed exact unqualified/history metadata: " + name)
	if not artifact.get("dna") is Dictionary or var_to_bytes(artifact.dna) != var_to_bytes(source.dna) or not artifact.get("mesh_data") is Dictionary:
		return _fail("artifact changed the source anatomy or lacks a mesh.")
	var mesh: Dictionary = artifact.mesh_data
	var mesh_fixed: Dictionary = {
		"edge_refinement204_is_unchanged_source_history": true, "active_cells": source.mesh_data.get("active_cells", 0),
		"triangulation_architecture_changed": true, "root_positions_changed": false, "normals_changed": false,
		"candidate_acceptance": false, "late_gates_pending": true
	}
	if mesh.size() != mesh_fixed.size() + 5:
		return _fail("mesh has missing or unknown229 metadata.")
	for name: String in mesh_fixed:
		if not mesh.has(name) or var_to_bytes(mesh[name]) != var_to_bytes(mesh_fixed[name]):
			return _fail("mesh changed exact unqualified/history metadata: " + name)
	var canonical: Dictionary = Ownership.validate_chosen(source.mesh_data, Policy.axes(), mesh)
	if not canonical.ok:
		return canonical
	if not mesh.get("quad_policy229") is Dictionary or var_to_bytes(mesh.quad_policy229) != var_to_bytes(canonical.report):
		return _fail("mesh choice ledger is not the complete canonical replay report.")
	return canonical
