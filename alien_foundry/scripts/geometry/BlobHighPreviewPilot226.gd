extends RefCounted
## Authenticate the exact completed224 rejection and its original223 history.
## No field call, extraction, selector rescan, alternate artifact or rebuild.
const Policy = preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const Previous = preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const Pilot224 = preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPilot224.gd")
const Grid210 = preload("res://alien_foundry/scripts/geometry/BlobRectilinearGrid210.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const Exact = preload("res://alien_foundry/scripts/geometry/BlobMassOuterProfile203.gd")
const MAX_RAW_BYTES: int = 64 * 1024 * 1024
const RETAINED_SHA: String = "6140ac5eb9b49eebc67f78f521fc60dfb6655d1e1de05766b87abf944f82e572"
const RETAINED_KEY: String = "c62a719694d5c35573b4d0b4e5154f39e3b7e7f77b744310f3d5b5a9d0c0c236"
const RETAINED_DEPENDENCY: String = "cf33780f55a7d8b0f8a6aa98f7eefdcc573cfe076bedd250e2ebda5cffadb464"
const POSITIONS_SHA: String = "8ddb4fb663bb6a7bc8161fe64844670788c16dfa64233afe8c85ea32e0d8102c"
const NORMALS_SHA: String = "004135154db06bcf8d6edbc42ee4a0c622095803476aefafeba992a3a308464f"
const INDICES_SHA: String = "6efdc7ad96d5c5a05f7dca45a5c977b9a0c8dd166223ccdd1782ecc73680bb60"
# Original224 export_report hashes var_to_bytes of this complete native Array.
const CURRENT_RECORDS_SHA: String = "b19f9ce1143d63ad2f8566e3a2493f6f8ac4f4dd8e8871710694fa1ddc7713e6"
const FIRST_PLAN_SHA: String = "865c155287103ea873c933d4a5c14edb53d9b1a71b173776865b90ed31fc7a95"
const INITIAL_GRID: Vector3i = Vector3i(76, 73, 82)
const CURRENT_GRID: Vector3i = Vector3i(80, 76, 86)
const CURRENT_EDGES: int = 17958
const CURRENT_QUERIES: int = 642694
const CURRENT_SAMPLES: int = 522880
const HISTORICAL_EDGES: int = 31888
const HISTORICAL_QUERIES: int = 1141122
const HISTORICAL_LATTICE_VISITS: int = 977816
const COMPLETE_STATUS: String = "completed_finite_index_safe_rejected_before_attribution"
const WRAPPER_COUNTS: Dictionary = {
	"coarse_edges": 13930, "coarse_edge_queries": 498428,
	"coarse_extractions_new": 0, "coarse_lattice_queries_new": 0,
	"coarse_lattice_skips_new": 0, "coarse_lattice_visits_new": 0,
	"historical_edges": 13930, "historical_edge_queries": 498428,
	"historical_lattice_visits": 454936, "refinement_pass_cap": 1,
	"refined_extractions_new": 1, "refined_lattice_planned_visits": CURRENT_SAMPLES,
	"refined_lattice_queries_new": CURRENT_SAMPLES, "refined_lattice_skips_new": 0,
	"refined_lattice_visits_new": CURRENT_SAMPLES, "lattice_queries_new": CURRENT_SAMPLES,
	"lattice_skips_new": 0, "lattice_visits_new": CURRENT_SAMPLES,
	"actual_new_edge_queries": CURRENT_QUERIES, "final_edge_queries": CURRENT_QUERIES,
	"final_edges": CURRENT_EDGES, "cumulative_edges": HISTORICAL_EDGES,
	"cumulative_edge_queries": HISTORICAL_QUERIES, "connectivity_repairs": 0
}

static func digest(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _error(message: String) -> Dictionary:
	return {"error": "226 retained pilot " + message}

static func _int_is(value: Variant, expected: int) -> bool:
	return value is int and value == expected

static func _bool_is(value: Variant, expected: bool) -> bool:
	return value is bool and value == expected

static func load_retained(path: String, dna: Dictionary, dims: Vector3i, origin: Vector3, cell: float) -> Dictionary:
	if path.is_empty():
		return _error("path is empty; no prior-pass rebuild fallback.")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("cannot be read; no prior-pass rebuild fallback.")
	var length: int = file.get_length()
	if length < 4 or length > MAX_RAW_BYTES:
		file.close()
		return _error("is outside the bounded raw size.")
	var raw: PackedByteArray = file.get_buffer(length)
	file.close()
	if raw.size() != length or digest(raw) != RETAINED_SHA:
		return _error("raw hash mismatch; no alternate artifact or rebuild.")
	# Decode only the same bounded bytes just authenticated, never another read.
	if int(raw.decode_u32(0)) != raw.size() - 4:
		return _error("has an invalid typed-packet envelope.")
	var packet_value: Variant = bytes_to_var(raw.slice(4))
	if not packet_value is Dictionary:
		return _error("is not a typed packet.")
	var packet: Dictionary = packet_value
	var checked: Dictionary = verify_packet(packet, dna, dims, origin, cell)
	if checked.has("error"):
		return checked
	checked["raw_sha256"] = RETAINED_SHA
	return checked

static func verify_packet(packet: Dictionary, dna: Dictionary, dims: Vector3i, origin: Vector3, cell: float) -> Dictionary:
	if not _recipe_shape_ok(dna):
		return _error("candidate consumed recipe containers are malformed.")
	var declaration: Dictionary = Policy.validate(dna)
	if not declaration.ok:
		return {"error": declaration.error}
	if not Policy.enabled(dna):
		return _error("requires the explicit bounded HighPreview2 selector.")
	if dims != INITIAL_GRID or not origin.is_finite() or not is_finite(cell) or PackedVector3Array([origin]).to_byte_array().hex_encode() != Previous.RETAINED_ORIGIN_BITS or Previous.scalar_bits(cell) != Previous.RETAINED_CELL_BITS:
		return _error("initial grid/origin/reference-cell bytes mismatch.")
	if not _int_is(packet.get("seed"), 22) or not _int_is(packet.get("stage"), 5) or not Previous.text_is(packet.get("geometry_key"), RETAINED_KEY):
		return _error("identity/header mismatch.")
	if not Previous.text_is(packet.get("pinned_spec_sha256"), Previous.PIN) or not Previous.text_is(packet.get("cavity_policy_sha256"), Previous.RETAINED_SPEC_PIN) or not Previous.text_is(packet.get("normal_policy_sha256"), Previous.NORMAL_PIN) or not Previous.text_is(packet.get("slab_policy_sha256"), Previous.SLAB_PIN):
		return _error("source-spec, cavity, normal or slab-policy pin mismatch.")
	if not _bool_is(packet.get("late_gates_pending"), true) or not _bool_is(packet.get("artistic_acceptance"), false):
		return _error("must preserve the original pending gates and nonacceptance.")
	var source_value: Variant = packet.get("dna")
	var mesh_value: Variant = packet.get("mesh_data")
	if not source_value is Dictionary or not mesh_value is Dictionary:
		return _error("requires typed source DNA and the original mesh_data subtree.")
	var source_dna: Dictionary = source_value
	var mesh: Dictionary = mesh_value
	if not _recipe_shape_ok(source_dna):
		return _error("retained consumed recipe containers are malformed.")
	var source_settings: Dictionary = source_dna.settings
	if source_settings.has(Policy.SETTING) or source_settings.has(Policy.PIN_SETTING):
		return _error("source is not the original224 recipe.")
	var original_declaration: Dictionary = Previous.validate(source_dna)
	if not original_declaration.ok or not Previous.enabled(source_dna):
		return _error("source must preserve the exact enabled224 declaration.")
	# Validate the candidate before stripping anything, so projection cannot hide
	# an extra/stale numeric-recipe entry at either newly declared selector path.
	var candidate: Dictionary = Artifacts.decode_geometry_recipe(dna)
	if candidate.has("error") or not candidate.get("inputs") is Dictionary:
		return _error("candidate exact numeric recipe is invalid before projection.")
	var base: Dictionary = Policy.field_projection(dna)
	if base.has("error"):
		return base
	if not _recipe_shape_ok(base):
		return _error("projected224 recipe containers are malformed.")
	var source: Dictionary = Artifacts.decode_geometry_recipe(source_dna)
	var projected: Dictionary = Artifacts.decode_geometry_recipe(base)
	if source.has("error") or projected.has("error") or not source.get("inputs") is Dictionary or not projected.get("inputs") is Dictionary:
		return _error("source or projected exact numeric recipe is invalid.")
	# Compare the entire typed consumed field, not just a rounded JSON/key subset.
	# Geometry input must already be restored before the volume receives it.
	var consumed: Dictionary = Artifacts._consumed_inputs(base)
	if not Exact.typed_equal(consumed, source.inputs) or not Exact.typed_equal(projected.inputs, source.inputs):
		return _error("full typed consumed inputs differ from the retained224 field.")
	if Artifacts.geometry_key(base, 5, RETAINED_DEPENDENCY) != RETAINED_KEY or Artifacts.geometry_key(source_dna, 5, RETAINED_DEPENDENCY) != RETAINED_KEY:
		return _error("original224 stage/dependency/organism key mismatch.")
	var mesh_check: Dictionary = _verify_refined(mesh)
	if mesh_check.has("error"):
		return mesh_check
	var wrapper_value: Variant = mesh.get("conforming_slabs210")
	var wrapper_check: Dictionary = _verify_wrapper(wrapper_value)
	if wrapper_check.has("error"):
		return wrapper_check
	var wrapper: Dictionary = wrapper_value
	var coarse_value: Variant = mesh.get("coarse_artifact210")
	if not coarse_value is Dictionary:
		return _error("requires the original nested223 coarse artifact.")
	var coarse: Dictionary = coarse_value
	var coarse_check: Dictionary = Pilot224._verify_coarse(coarse)
	if coarse_check.has("error"):
		return _error("original223 coarse authentication failed: " + str(coarse_check.error))
	# Replay only pure index/face/axis planning. No coarse sampling or extraction.
	var first_plan: Dictionary = Grid210.plan(coarse, dims, origin, cell, true)
	if not _bool_is(first_plan.get("ok"), true) or not _bool_is(first_plan.get("refine"), true):
		return _error("original first-pass plan cannot be reconstructed completely.")
	var retained_plan_value: Variant = wrapper.get("plan")
	if not retained_plan_value is Dictionary or not Exact.typed_equal(retained_plan_value, first_plan):
		return _error("retained first-pass plan differs from its complete original coarse replay.")
	if Pilot224.plan_digest(first_plan, cell) != FIRST_PLAN_SHA:
		return _error("reconstructed first-pass canonical plan hash mismatch.")
	var axes_value: Variant = first_plan.get("axes")
	var initial_axes_value: Variant = first_plan.get("base_axes")
	if not axes_value is Array or not initial_axes_value is Array:
		return _error("first-pass canonical axes are missing or malformed.")
	var axes: Array = axes_value
	var initial_axes: Array = initial_axes_value
	var current_shape: Dictionary = Grid210.validate_axes(axes, true)
	var initial_shape: Dictionary = Grid210.validate_axes(initial_axes, true)
	if not current_shape.ok or not initial_shape.ok or current_shape.dimensions != CURRENT_GRID or initial_shape.dimensions != INITIAL_GRID:
		return _error("first-pass canonical dimensions or packed axes mismatch.")
	return {"mesh": mesh, "axes": axes, "initial_axes": initial_axes,
		"prior_passes": 1, "historical_edges": HISTORICAL_EDGES,
		"historical_queries": HISTORICAL_QUERIES,
		"historical_lattice_visits": HISTORICAL_LATTICE_VISITS,
		"geometry_key": RETAINED_KEY, "dependency": RETAINED_DEPENDENCY,
		"first_plan": first_plan}

static func _recipe_shape_ok(dna: Dictionary) -> bool:
	if not Pilot224._recipe_shape_ok(dna):
		return false
	# Keep hostile dictionary keys/objects out of the unchanged exact codec.
	for key: String in ["settings", "budget", "nodes", "connections", "modules", "geometry_numeric_recipe"]:
		if not _recipe_tree_ok(dna.get(key), 0):
			return false
	return true

static func _recipe_tree_ok(value: Variant, depth: int) -> bool:
	if depth > 64:
		return false
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key: Variant in dictionary:
			if not key is String or not _recipe_tree_ok(dictionary[key], depth + 1):
				return false
		return true
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			if not _recipe_tree_ok(item, depth + 1):
				return false
		return true
	return value == null or value is String or value is bool or Previous.number(value)

static func _verify_wrapper(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _error("requires the typed first-refinement210 ledger.")
	var wrapper: Dictionary = value
	if not Previous.text_is(wrapper.get("mode"), "conflict_slabs_v1") or not Previous.text_is(wrapper.get("pin"), Previous.SLAB_PIN):
		return _error("first-refinement ledger policy mismatch.")
	if not _bool_is(wrapper.get("retained_coarse"), true) or not _bool_is(wrapper.get("field_normal_reference_unchanged"), true):
		return _error("retained-coarse or unchanged-normal-reference evidence mismatch.")
	if not Exact.typed_equal(wrapper.get("base_grid"), [76, 73, 82]) or not Previous.text_is(wrapper.get("base_origin_f32_le"), Previous.RETAINED_ORIGIN_BITS) or not Previous.text_is(wrapper.get("reference_cell_f64_le"), Previous.RETAINED_CELL_BITS):
		return _error("first-refinement initial grid/reference bytes mismatch.")
	if not Previous.text_is(wrapper.get("retained_raw_sha256"), Previous.RETAINED_SHA) or not Previous.text_is(wrapper.get("retained_geometry_key"), Previous.RETAINED_KEY) or not Previous.text_is(wrapper.get("canonical_plan_sha256"), FIRST_PLAN_SHA):
		return _error("original223 artifact identity or canonical first-plan hash mismatch.")
	for key: String in WRAPPER_COUNTS:
		var expected: int = WRAPPER_COUNTS[key]
		if not _int_is(wrapper.get(key), expected):
			return _error("first-refinement/historical ledger counter mismatch: " + key)
	var preview_value: Variant = wrapper.get("preview_budget224")
	if not preview_value is Dictionary:
		return _error("requires the original explicit224 budget ledger.")
	var preview: Dictionary = preview_value
	var expected_preview: Dictionary = {"mode": Previous.MODE, "pin": Previous.PIN,
		"maximum_planes": 12, "maximum_planes_per_axis": 4,
		"maximum_extra_samples": 80000, "maximum_total_samples": 560000,
		"same_base_field": true, "game_lod_claim": false}
	if not Exact.typed_equal(preview, expected_preview):
		return _error("original224 budget evidence is changed, incomplete or malformed.")
	return {"ok": true}

static func _verify_refined(mesh: Dictionary) -> Dictionary:
	if not Previous.text_is(mesh.get("error"), Previous.FACE_ERROR) or not Previous.text_is(mesh.get("raw_snapshot_status"), COMPLETE_STATUS):
		return _error("mesh_data is not the completed224 face rejection.")
	for key: String in ["rejected", "raw_snapshot_complete", "finite_index_safe"]:
		if not _bool_is(mesh.get(key), true):
			return _error("current completion flag mismatch: " + key)
	if mesh.has("cancelled") and not _bool_is(mesh.get("cancelled"), false):
		return _error("current cancellation metadata is malformed or active.")
	var vertices_value: Variant = mesh.get("vertices")
	var normals_value: Variant = mesh.get("normals")
	var indices_value: Variant = mesh.get("indices")
	if not vertices_value is PackedVector3Array or not normals_value is PackedVector3Array or not indices_value is PackedInt32Array:
		return _error("current physical buffers require original packed types.")
	var vertices: PackedVector3Array = vertices_value
	var normals: PackedVector3Array = normals_value
	var indices: PackedInt32Array = indices_value
	if vertices.size() != CURRENT_EDGES or normals.size() != CURRENT_EDGES or indices.size() != 35912 * 3:
		return _error("current physical buffer lengths mismatch.")
	if digest(vertices.to_byte_array()) != POSITIONS_SHA or digest(normals.to_byte_array()) != NORMALS_SHA or digest(indices.to_byte_array()) != INDICES_SHA:
		return _error("current physical buffer bytes mismatch.")
	var edge_value: Variant = mesh.get("edge_refinement204")
	if not edge_value is Dictionary:
		return _error("requires complete typed current edge provenance.")
	var edge: Dictionary = edge_value
	if not Previous.text_is(edge.get("error"), Previous.FACE_ERROR) or not Previous.text_is(edge.get("mode"), "bracketed_field_edges_v1") or not Previous.text_is(edge.get("pin"), Previous.ROOT_PIN):
		return _error("current root-policy evidence mismatch.")
	var counters: Dictionary = {"unique_edges": CURRENT_EDGES, "continuous_queries": CURRENT_QUERIES,
		"fallbacks": 0, "repairs": 0, "normal_replacements": 0,
		"edge_quota": Previous.EDGE_CAP, "query_quota": Previous.QUERY_CAP - Previous.RETAINED_QUERIES,
		"per_edge_query_quota": Previous.PER_EDGE_QUERY_CAP}
	for key: String in counters:
		var expected: int = counters[key]
		if not _int_is(edge.get(key), expected):
			return _error("current edge count/budget mismatch: " + key)
	var cumulative_value: Variant = edge.get("cumulative210")
	if not cumulative_value is Dictionary:
		return _error("requires the typed current cumulative210 edge ledger.")
	var cumulative: Dictionary = cumulative_value
	var expected_cumulative: Dictionary = {"prior_edges": Previous.RETAINED_EDGES,
		"prior_queries": Previous.RETAINED_QUERIES, "edges": HISTORICAL_EDGES,
		"queries": HISTORICAL_QUERIES, "edge_cap": Previous.EDGE_CAP, "query_cap": Previous.QUERY_CAP}
	if not Exact.typed_equal(cumulative, expected_cumulative):
		return _error("current cumulative210 ledger is changed or incomplete.")
	var normal_value: Variant = edge.get("adaptive_normal207")
	if not normal_value is Dictionary:
		return _error("requires typed current208v2 normal provenance.")
	var normal: Dictionary = normal_value
	if not Previous.text_is(normal.get("mode"), "adaptive_field_gradient_v2") or not Previous.text_is(normal.get("pin"), Previous.NORMAL_PIN) or not _int_is(normal.get("converged_edges"), CURRENT_EDGES) or not _int_is(normal.get("rejected_edges"), 0):
		return _error("current normal policy/evidence mismatch.")
	var records_value: Variant = normal.get("edge_records")
	if not records_value is Array or records_value.size() != CURRENT_EDGES:
		return _error("requires all 17958 original successful edge records.")
	var records: Array = records_value
	if digest(var_to_bytes(records)) != CURRENT_RECORDS_SHA:
		return _error("complete current edge-record typed bytes mismatch.")
	var complete_queries: int = 0
	for record_value: Variant in records:
		if not record_value is Dictionary:
			return _error("contains a malformed current edge record.")
		var record: Dictionary = record_value
		if not _bool_is(record.get("ok"), true) or not Previous.text_is(record.get("error"), ""):
			return _error("contains a failed or malformed current edge/normal record.")
		var queries_value: Variant = record.get("complete_queries")
		if not queries_value is int or queries_value <= 0 or queries_value > Previous.PER_EDGE_QUERY_CAP:
			return _error("contains a malformed or over-budget current edge query count.")
		var queries: int = queries_value
		complete_queries += queries
	if complete_queries != CURRENT_QUERIES:
		return _error("complete current edge records disagree with the query total.")
	# This unchanged pure helper checks all ordinals, shared edges, endpoint bounds
	# and exact fixed-tetrahedral edge membership in the current rectilinear grid.
	var record_check: Dictionary = Grid210._edge_records(mesh, CURRENT_EDGES, CURRENT_GRID, CURRENT_SAMPLES)
	if not record_check.ok:
		return _error("current edge ownership rejected: " + str(record_check.error))
	return _verify_faces(vertices, normals, indices)

static func _verify_faces(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	for vertex_id: int in range(vertices.size()):
		var normal_length_squared: float = normals[vertex_id].length_squared()
		if not vertices[vertex_id].is_finite() or not normals[vertex_id].is_finite() or not is_finite(normal_length_squared) or normal_length_squared <= 0.0:
			return _error("current vertex or normal is nonfinite or degenerate.")
	var conflicts: int = 0
	for offset: int in range(0, indices.size(), 3):
		var a: int = indices[offset]
		var b: int = indices[offset + 1]
		var c: int = indices[offset + 2]
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size() or a == b or b == c or c == a:
			return _error("current face index is out of bounds or repeated.")
		var outward: Vector3 = -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		var area_squared: float = outward.length_squared()
		var summed_normal: Vector3 = normals[a] + normals[b] + normals[c]
		var alignment: float = summed_normal.dot(outward)
		if not outward.is_finite() or not is_finite(area_squared) or area_squared == 0.0 or not summed_normal.is_finite() or not is_finite(alignment):
			return _error("current face is nonfinite or exactly degenerate; no repair.")
		if alignment <= 0.0:
			conflicts += 1
	if conflicts == 0:
		return _error("completed rejection disagrees with the full native face scan.")
	return {"ok": true}

static func plan_digest(plan: Dictionary, reference_cell: float) -> String:
	# Bind all deterministic226 plan evidence, not only the final axis arrays.
	var canonical: Dictionary = {"pin": Policy.PIN, "reference_cell": reference_cell, "plan": plan}
	return digest(var_to_bytes(canonical))
