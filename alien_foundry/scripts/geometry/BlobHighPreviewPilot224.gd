extends RefCounted
## Authenticate the retained223b coarse rejection. No caller plan, selection,
## field evaluation, coarse rebuild or wrong-artifact fallback is permitted.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const Exact = preload("res://alien_foundry/scripts/geometry/BlobMassOuterProfile203.gd")
const MAX_RAW_BYTES: int = 64 * 1024 * 1024
const POSITIONS_SHA: String = "273b7f22758d935531f67b04f6b64321538f9e995b2f1972da3fff1c4bed209e"
const NORMALS_SHA: String = "91435704f937bb4b6a2be0a506efd8fd8181aa564b5e5afbf62f3a933af7bf03"
const INDICES_SHA: String = "3cc68d2088472bde4ee2f1708b3de895b025aeaed0e1aeba26a2f8d70cc4ee85"
const COMPLETE_STATUS: String = "completed_finite_index_safe_rejected_before_attribution"
const WRAPPER_COUNTS: Dictionary = {
	"coarse_edges": Policy.RETAINED_EDGES,
	"coarse_edge_queries": Policy.RETAINED_QUERIES,
	"actual_new_edge_queries": Policy.RETAINED_QUERIES,
	"coarse_lattice_planned_visits": Policy.RETAINED_LATTICE_VISITS,
	"coarse_lattice_queries_new": Policy.RETAINED_LATTICE_VISITS,
	"coarse_lattice_visits_new": Policy.RETAINED_LATTICE_VISITS,
	"lattice_queries_new": Policy.RETAINED_LATTICE_VISITS,
	"lattice_visits_new": Policy.RETAINED_LATTICE_VISITS,
	"coarse_extractions_new": 1,
	"refinement_pass_cap": 1,
	"refined_extractions_new": 0,
	"refined_lattice_queries_new": 0,
	"refined_lattice_skips_new": 0,
	"refined_lattice_visits_new": 0,
	"coarse_lattice_skips_new": 0,
	"lattice_skips_new": 0,
	"historical_lattice_visits": 0,
	"historical_edges": 0,
	"historical_edge_queries": 0,
	"connectivity_repairs": 0
}

static func digest(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _error(message: String) -> Dictionary:
	return {"error": "224 retained pilot " + message}

static func _int_is(value: Variant, expected: int) -> bool:
	return value is int and value == expected

static func _bool_is(value: Variant, expected: bool) -> bool:
	return value is bool and value == expected

static func load_retained(path: String, dna: Dictionary, dims: Vector3i, origin: Vector3, cell: float) -> Dictionary:
	if path.is_empty():
		return _error("path is empty; no coarse rebuild fallback.")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("cannot be read; no coarse rebuild fallback.")
	var length: int = file.get_length()
	if length < 4 or length > MAX_RAW_BYTES:
		file.close()
		return _error("is outside the bounded raw size.")
	var raw: PackedByteArray = file.get_buffer(length)
	file.close()
	if raw.size() != length or digest(raw) != Policy.RETAINED_SHA:
		return _error("raw hash mismatch; no alternate artifact or rebuild.")
	# FileAccess.store_var writes a four-byte payload length. Decode exactly the
	# same bounded bytes whose digest was verified, never a second file read.
	if int(raw.decode_u32(0)) != raw.size() - 4:
		return _error("has an invalid typed-packet envelope.")
	var packet_value: Variant = bytes_to_var(raw.slice(4))
	if not packet_value is Dictionary:
		return _error("is not a typed packet.")
	var packet: Dictionary = packet_value
	var checked: Dictionary = verify_packet(packet, dna, dims, origin, cell)
	if checked.has("error"):
		return checked
	checked["raw_sha256"] = Policy.RETAINED_SHA
	return checked

static func verify_packet(packet: Dictionary, dna: Dictionary, dims: Vector3i, origin: Vector3, cell: float) -> Dictionary:
	var declaration: Dictionary = Policy.validate(dna)
	if not declaration.ok:
		return {"error": declaration.error}
	if not Policy.enabled(dna):
		return _error("requires the explicit bounded HighPreview selector.")
	if dims != Policy.RETAINED_GRID or not origin.is_finite() or not is_finite(cell) or PackedVector3Array([origin]).to_byte_array().hex_encode() != Policy.RETAINED_ORIGIN_BITS or Policy.scalar_bits(cell) != Policy.RETAINED_CELL_BITS:
		return _error("base grid/origin/reference-cell bytes mismatch.")
	if not _int_is(packet.get("seed"), 22) or not _int_is(packet.get("stage"), 5) or not Policy.text_is(packet.get("geometry_key"), Policy.RETAINED_KEY):
		return _error("identity/header mismatch.")
	if not Policy.text_is(packet.get("pinned_spec_sha256"), Policy.RETAINED_SPEC_PIN) or not Policy.text_is(packet.get("normal_policy_sha256"), Policy.NORMAL_PIN) or not Policy.text_is(packet.get("slab_policy_sha256"), Policy.SLAB_PIN):
		return _error("source-spec, normal or slab-policy pin mismatch.")
	var source_value: Variant = packet.get("dna")
	var wrapper_value: Variant = packet.get("mesh_data")
	if not source_value is Dictionary or not wrapper_value is Dictionary:
		return _error("requires typed source DNA and the original mesh wrapper.")
	var source_dna: Dictionary = source_value
	var wrapper: Dictionary = wrapper_value
	var base: Dictionary = Policy.field_projection(dna)
	if base.has("error"):
		return base
	if not _recipe_shape_ok(base) or not _recipe_shape_ok(source_dna):
		return _error("consumed recipe containers are malformed.")
	var source_settings: Dictionary = source_dna.settings
	if source_settings.has(Policy.SETTING) or source_settings.has(Policy.PIN_SETTING):
		return _error("source is not the original223 recipe.")
	var source: Dictionary = Artifacts.decode_geometry_recipe(source_dna)
	if source.has("error") or not source.get("inputs") is Dictionary:
		return _error("source exact numeric recipe is invalid.")
	var consumed: Dictionary = Artifacts._consumed_inputs(base)
	if not Exact.typed_equal(consumed, source.inputs):
		return _error("full typed consumed inputs differ from the candidate field.")
	if Artifacts.geometry_key(base, 5, Policy.RETAINED_DEPENDENCY) != Policy.RETAINED_KEY or Artifacts.geometry_key(source_dna, 5, Policy.RETAINED_DEPENDENCY) != Policy.RETAINED_KEY:
		return _error("original223 stage/dependency/organism key mismatch.")
	if not Policy.text_is(wrapper.get("error"), Policy.OUTER_ERROR):
		return _error("outer complete-plan rejection does not match223b.")
	if wrapper.has("cancelled") and not _bool_is(wrapper.get("cancelled"), false):
		return _error("outer cancellation metadata is malformed or active.")
	var slab_check: Dictionary = _verify_wrapper(wrapper.get("conforming_slabs210"))
	if slab_check.has("error"):
		return slab_check
	var mesh_value: Variant = wrapper.get("coarse_artifact210")
	if not mesh_value is Dictionary:
		return _error("must contain mesh_data.coarse_artifact210, not an accepted outer mesh.")
	var mesh: Dictionary = mesh_value
	var mesh_check: Dictionary = _verify_coarse(mesh)
	if mesh_check.has("error"):
		return mesh_check
	return {"mesh": mesh, "historical_edges": Policy.RETAINED_EDGES,
		"historical_queries": Policy.RETAINED_QUERIES,
		"historical_lattice_visits": Policy.RETAINED_LATTICE_VISITS,
		"geometry_key": Policy.RETAINED_KEY, "dependency": Policy.RETAINED_DEPENDENCY}

static func _recipe_shape_ok(dna: Dictionary) -> bool:
	# Guard legacy typed iteration/casts before invoking its exact codec.
	for key: String in ["settings", "budget", "metadata", "biological_blueprint"]:
		if not dna.get(key) is Dictionary:
			return false
	var blueprint: Dictionary = dna.biological_blueprint
	if not blueprint.get("organism_id") is String:
		return false
	for key: String in ["nodes", "connections", "modules"]:
		if not dna.get(key) is Array:
			return false
	var nodes: Array = dna.nodes
	for node_value: Variant in nodes:
		if not node_value is Dictionary:
			return false
		var node: Dictionary = node_value
		if not Policy.number(node.get("noise", 0.0)):
			return false
	return true

static func _verify_wrapper(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _error("has no typed original210 budget ledger.")
	var slab: Dictionary = value
	if not Policy.text_is(slab.get("mode"), "conflict_slabs_v1") or not Policy.text_is(slab.get("pin"), Policy.SLAB_PIN):
		return _error("original210 ledger policy mismatch.")
	if not _bool_is(slab.get("retained_coarse"), false) or not _bool_is(slab.get("field_normal_reference_unchanged"), true):
		return _error("original coarse provenance flags mismatch.")
	if not Exact.typed_equal(slab.get("base_grid"), [76, 73, 82]) or not Policy.text_is(slab.get("base_origin_f32_le"), Policy.RETAINED_ORIGIN_BITS) or not Policy.text_is(slab.get("reference_cell_f64_le"), Policy.RETAINED_CELL_BITS):
		return _error("original210 ledger base grid/reference bytes mismatch.")
	for key: String in WRAPPER_COUNTS:
		var expected: int = WRAPPER_COUNTS[key]
		if not _int_is(slab.get(key), expected):
			return _error("original210 ledger counter mismatch: " + key)
	return {"ok": true}

static func _verify_coarse(mesh: Dictionary) -> Dictionary:
	if not Policy.text_is(mesh.get("error"), Policy.FACE_ERROR) or not Policy.text_is(mesh.get("raw_snapshot_status"), COMPLETE_STATUS):
		return _error("nested coarse artifact is not the completed face rejection.")
	for key: String in ["rejected", "raw_snapshot_complete", "finite_index_safe"]:
		if not _bool_is(mesh.get(key), true):
			return _error("nested coarse completion flag mismatch: " + key)
	if mesh.has("cancelled") and not _bool_is(mesh.get("cancelled"), false):
		return _error("nested coarse cancellation is malformed or active.")
	var vertices_value: Variant = mesh.get("vertices")
	var normals_value: Variant = mesh.get("normals")
	var indices_value: Variant = mesh.get("indices")
	if not vertices_value is PackedVector3Array or not normals_value is PackedVector3Array or not indices_value is PackedInt32Array:
		return _error("nested physical buffers require their original packed types.")
	var vertices: PackedVector3Array = vertices_value
	var normals: PackedVector3Array = normals_value
	var indices: PackedInt32Array = indices_value
	if vertices.size() != Policy.RETAINED_EDGES or normals.size() != vertices.size() or indices.size() != 27856 * 3:
		return _error("nested physical buffer lengths mismatch.")
	if digest(vertices.to_byte_array()) != POSITIONS_SHA or digest(normals.to_byte_array()) != NORMALS_SHA or digest(indices.to_byte_array()) != INDICES_SHA:
		return _error("nested physical buffer bytes mismatch.")
	var edge_value: Variant = mesh.get("edge_refinement204")
	if not edge_value is Dictionary:
		return _error("requires the original typed edge provenance.")
	var edge: Dictionary = edge_value
	if not _int_is(edge.get("unique_edges"), Policy.RETAINED_EDGES) or not _int_is(edge.get("continuous_queries"), Policy.RETAINED_QUERIES):
		return _error("historical edge/query counts mismatch.")
	for key: String in ["fallbacks", "repairs", "normal_replacements"]:
		if not _int_is(edge.get(key), 0):
			return _error("must preserve zero repairs/fallbacks/replacements.")
	if not Policy.text_is(edge.get("error"), Policy.FACE_ERROR) or not Policy.text_is(edge.get("mode"), "bracketed_field_edges_v1") or not Policy.text_is(edge.get("pin"), Policy.ROOT_PIN):
		return _error("root-policy evidence mismatch.")
	if not _int_is(edge.get("edge_quota"), Policy.EDGE_CAP) or not _int_is(edge.get("query_quota"), Policy.QUERY_CAP) or not _int_is(edge.get("per_edge_query_quota"), Policy.PER_EDGE_QUERY_CAP):
		return _error("root-query budget evidence mismatch.")
	var cumulative_value: Variant = edge.get("cumulative210")
	if not cumulative_value is Dictionary:
		return _error("requires the original cumulative210 edge ledger.")
	var cumulative: Dictionary = cumulative_value
	for pair_value: Array in [["prior_edges", 0], ["prior_queries", 0], ["edges", Policy.RETAINED_EDGES], ["queries", Policy.RETAINED_QUERIES], ["edge_cap", Policy.EDGE_CAP], ["query_cap", Policy.QUERY_CAP]]:
		var counter: String = pair_value[0]
		var expected: int = pair_value[1]
		if not _int_is(cumulative.get(counter), expected):
			return _error("original cumulative210 ledger mismatch: " + counter)
	var normal_value: Variant = edge.get("adaptive_normal207")
	if not normal_value is Dictionary:
		return _error("requires typed208v2 normal provenance.")
	var normal: Dictionary = normal_value
	if not Policy.text_is(normal.get("mode"), "adaptive_field_gradient_v2") or not Policy.text_is(normal.get("pin"), Policy.NORMAL_PIN) or not _int_is(normal.get("converged_edges"), Policy.RETAINED_EDGES) or not _int_is(normal.get("rejected_edges"), 0):
		return _error("normal-policy evidence/count mismatch.")
	var records_value: Variant = normal.get("edge_records")
	if not records_value is Array or records_value.size() != Policy.RETAINED_EDGES:
		return _error("requires all 13930 original successful edge records.")
	var records: Array = records_value
	var ordinals: Dictionary = {}
	var endpoints: Dictionary = {}
	var complete_queries: int = 0
	for record_value: Variant in records:
		if not record_value is Dictionary:
			return _error("contains a malformed edge record.")
		var record: Dictionary = record_value
		if not _bool_is(record.get("ok"), true) or not Policy.text_is(record.get("error"), ""):
			return _error("contains a failed or malformed edge/normal record.")
		var queries_value: Variant = record.get("complete_queries")
		if not queries_value is int or queries_value <= 0 or queries_value > Policy.PER_EDGE_QUERY_CAP:
			return _error("contains a malformed or over-budget edge query count.")
		var queries: int = queries_value
		complete_queries += queries
		var ordinal_value: Variant = record.get("edge_ordinal")
		var first_value: Variant = record.get("first")
		var second_value: Variant = record.get("second")
		if not ordinal_value is int or not first_value is int or not second_value is int:
			return _error("edge ordinals/endpoints must remain exact integers.")
		var ordinal: int = ordinal_value
		var first: int = first_value
		var second: int = second_value
		if ordinal < 0 or ordinal >= Policy.RETAINED_EDGES or ordinals.has(ordinal) or first < 0 or first >= second or second >= Policy.RETAINED_LATTICE_VISITS:
			return _error("edge ordinals/endpoints are missing, duplicate or out of bounds.")
		var pair: int = first * Policy.RETAINED_LATTICE_VISITS + second
		if endpoints.has(pair):
			return _error("duplicates an original shared edge.")
		ordinals[ordinal] = true
		endpoints[pair] = true
	if complete_queries != Policy.RETAINED_QUERIES:
		return _error("complete edge records disagree with the historical query total.")
	# Native Grid.plan subsequently checks every edge's tetrahedral ownership
	# and every face, and derives the complete split set. No plan is accepted here.
	return {"ok": true}

static func plan_digest(plan: Dictionary, reference_cell: float) -> String:
	# Exact axes and224 pin identify this tier. The old210 digest stays untouched.
	var canonical: Dictionary = {"pin": Policy.PIN, "reference_cell": reference_cell,
		"base_dimensions": plan.get("base_dimensions"), "base_axes": plan.get("base_axes"),
		"split_intervals": plan.get("split_intervals"), "dimensions": plan.get("dimensions"),
		"axes": plan.get("axes")}
	return digest(var_to_bytes(canonical))
