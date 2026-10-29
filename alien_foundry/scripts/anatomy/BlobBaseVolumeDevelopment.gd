extends RefCounted
## 195: opt-in Stage2 redistribution of already-authored compact body identities.
## Fixed pinned recipe. No extra carriers, random draws, mesh transforms or retries.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Compact = preload("res://alien_foundry/scripts/anatomy/BlobCompactBody.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const SETTING := "blob_base_volume_mode"
const OFF := "off"
const MODE := "unequal_compartments_v1"
const VERSION := 1
const CORE_SHARE := 0.54
const LOBE_SHARE := 0.46
const RANK_WEIGHTS := [1.0, 0.52, 0.29, 0.16]
const AXIS_RATIOS := [[1.0, 1.08, 1.12], [1.08, 0.98, 1.0], [0.98, 1.03, 1.06], [1.06, 0.96, 1.0]]
const OVERLAP := 0.40
const BLEND := 0.14
const SCULPT := 0.12
const CLEARANCE := 0.012
const BISECTIONS := 24
const ROOT_LIMIT := 0.90
const MIN_AXIS_RATIO := 0.65
const VOLUME_TOLERANCE := 0.00001
const NATIVE_ROOT_BURIAL := 0.20
const PIN_SHA256 := "a17c2ede37990513ff274df840c9e3337fc36a066426e22ab8d558f9fd68b21c"

static func selection(options: Dictionary) -> Dictionary:
	var mode: Variant = options.get(SETTING, OFF)
	if not mode is String or mode not in [OFF, MODE]: return {"error": "Unsupported explicit Blob base-volume mode."}
	if mode == MODE and (options.get("blob_pipeline_mode", "") != "iterative_v2" or options.get(Compact.SETTING, Compact.FOUNDATION) != Compact.COMPACT):
		return {"error": "unequal_compartments_v1 requires iterative Blob compact_body_v1."}
	return {"mode": mode}

static func validate_declaration(dna: Dictionary) -> Dictionary:
	var chosen: Dictionary = selection(dna.get("settings", {}))
	if chosen.has("error"): return {"ok": false, "error": chosen.error}
	if chosen.mode == MODE:
		if dna.get("type") != "Blob" or int(dna.get("metadata", {}).get("realized_anatomy", {}).get("grammar_index", -1)) != 2:
			return {"ok": false, "error": "195 development only supports compact Blob grammar2."}
		if int(dna.get("metadata", {}).get("iteration_index", 0)) < 2 or not dna.get("metadata", {}).get("base_volume_development") is Dictionary:
			return {"ok": false, "error": "195 development requires its actual Stage2 recipe report."}
		return _validate_report(dna, dna.metadata.base_volume_development)
	return {"ok": true}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _vector(value: Variant, positive: bool = false) -> bool:
	if not value is Array or value.size() != 3: return false
	for component: Variant in value:
		if not _number(component) or (positive and float(component) <= 0.0): return false
	return true

static func _validate_report(dna: Dictionary, report: Dictionary) -> Dictionary:
	var bad := {"ok": false, "error": "Malformed or inconsistent195 development trace; metadata is not geometric qualification."}
	if not _number(report.get("version")) or float(report.version) != float(VERSION) or report.get("mode") != MODE or not _number(report.get("stage")) or float(report.stage) != 2.0 or report.get("pinned_spec_sha256") != PIN_SHA256: return bad
	for key: String in ["supports_unchanged", "native_surface_burial_pending", "no_new_carriers"]:
		if not report.get(key) is bool or not report[key]: return bad
	if not report.get("anatomical_acceptance") is bool or report.anatomical_acceptance: return bad
	if not _number(report.get("nominal_volume_ratio")) or absf(float(report.nominal_volume_ratio) - 1.0) > VOLUME_TOLERANCE: return bad
	if not _number(report.get("core_nominal_volume_share")) or absf(float(report.core_nominal_volume_share) - CORE_SHARE) > VOLUME_TOLERANCE: return bad
	for key: String in ["source_bounds", "developed_bounds"]:
		if not report.get(key) is Dictionary or not _vector(report[key].get("position")) or not _vector(report[key].get("size"), true): return bad
	var compact: Variant = dna.get("metadata", {}).get("compact_body_anatomy")
	if not compact is Dictionary or not dna.get("nodes") is Array: return bad
	var nodes := {}; var occupied := {}
	for n: Variant in dna.nodes:
		if not n is Dictionary or not n.get("id") is String: return bad
		nodes[n.id] = n
	for key: String in ["body_node_ids", "support_node_ids"]:
		var ids: Variant = report.get(key)
		if not ids is Array or ids != compact.get(key) or ids.size() < (3 if key == "body_node_ids" else 2) or ids.size() > (5 if key == "body_node_ids" else 4): return bad
		for id: Variant in ids:
			if not id is String or occupied.has(id) or not nodes.has(id): return bad
			occupied[id] = true
			var node: Dictionary = nodes[id]
			if node.get("kind") != ("mass" if key == "body_node_ids" else "curve"): return bad
			if not node.get("feature_id") is String: return bad
	var allocations: Variant = report.get("allocations")
	if not allocations is Array or allocations.size() != report.body_node_ids.size() - 1: return bad
	var allocated := {}; var rank_sum := 0.0
	for i in range(allocations.size()): rank_sum += float(RANK_WEIGHTS[i])
	for rank in range(allocations.size()):
		var item: Variant = allocations[rank]
		if not item is Dictionary or not item.get("node_id") is String or not item.get("feature_id") is String or not _number(item.get("rank")) or float(item.rank) != float(rank): return bad
		var id: String = item.node_id
		if id == report.body_node_ids[0] or id not in report.body_node_ids or allocated.has(id) or item.feature_id != nodes[id].feature_id: return bad
		if nodes[id].get("parent") != report.body_node_ids[0]: return bad
		allocated[id] = true
		if not _vector(item.get("position")) or not _vector(item.get("size"), true): return bad
		if not _number(item.get("nominal_volume_share")) or absf(float(item.nominal_volume_share) - LOBE_SHARE * float(RANK_WEIGHTS[rank]) / rank_sum) > VOLUME_TOLERANCE: return bad
		if not _number(item.get("overlap_fraction")) or absf(float(item.overlap_fraction) - OVERLAP) > VOLUME_TOLERANCE: return bad
	var roots: Variant = report.get("support_roots")
	if not roots is Array or roots.size() != report.support_node_ids.size(): return bad
	var checked := {}
	for item: Variant in roots:
		if not item is Dictionary or not item.get("support_id") is String or not item.get("host_id") is String: return bad
		var id: String = item.support_id
		if id not in report.support_node_ids or checked.has(id) or item.host_id != nodes[id].get("parent") or item.host_id not in report.body_node_ids: return bad
		checked[id] = true
		if not _number(item.get("normalized_root_radius")) or float(item.normalized_root_radius) < 0.0 or float(item.normalized_root_radius) > ROOT_LIMIT: return bad
	if report.get("witness_pair") != [str(nodes[report.body_node_ids[0]].feature_id), str(allocations[0].feature_id)]: return bad
	return {"ok": true}

static func _volume(n: Dictionary) -> float:
	var s: Vector3 = Graph.vec(n.size)
	return s.x * s.y * s.z # Common 4PI/3 cancels in every allocation.

static func _radius(n: Dictionary, direction: Vector3) -> float:
	return Graph.surface_radius(Graph.vec(n.size), Graph.node_basis(n).inverse() * direction)

static func _residual(horizontal: float, vertical: float, azimuth: Vector3, core: Dictionary, lobe: Dictionary) -> float:
	var offset := azimuth * horizontal + Vector3.UP * vertical
	if offset.length_squared() < 0.000000001: return -1.0
	var direction := offset.normalized()
	var a := _radius(core, direction)
	var b := _radius(lobe, -direction)
	return offset.length() - (a + b - OVERLAP * minf(a, b))

static func _bounds(nodes: Array) -> Dictionary:
	var box: AABB = Compact.ellipsoid_bounds(nodes)
	return {"position": Graph.arr(box.position), "size": Graph.arr(box.size)}

static func describe(dna: Dictionary, morphology: Dictionary) -> Dictionary:
	if dna.get("type") != "Blob" or int(morphology.get("grammar_index", -1)) != 2:
		return {"error": "195 cannot develop a non-Blob or non-compact grammar."}
	var compact: Dictionary = dna.get("metadata", {}).get("compact_body_anatomy", {})
	var ids: Array = compact.get("body_node_ids", [])
	var supports: Array = compact.get("support_node_ids", [])
	if ids.size() < 3 or ids.size() > 5 or supports.size() < 2 or supports.size() > 4:
		return {"error": "195 requires the existing compact two-to-four body lobes and supports."}
	var all_nodes := {}
	for n: Dictionary in dna.nodes: all_nodes[str(n.id)] = n
	var body: Array = []
	var original: Array = []
	var total := 0.0
	for id: String in ids:
		if not all_nodes.has(id) or all_nodes[id].kind != "mass": return {"error": "195 is missing an original body carrier."}
		var n: Dictionary = all_nodes[id].duplicate(true)
		body.append(n); original.append(n.duplicate(true)); total += _volume(n)
	var core: Dictionary = body[0]
	var center: Vector3 = Graph.vec(core.position)
	var root_size: Vector3 = Graph.vec(core.size) * pow(total * CORE_SHARE / _volume(core), 1.0 / 3.0)
	core.size = Graph.arr(root_size)
	var ranked: Array = []
	for i in range(1, body.size()):
		var n: Dictionary = body[i]
		if n.parent != core.id: return {"error": "195 only develops existing core-owned lobes."}
		var delta: Vector3 = Graph.vec(n.position) - center
		var horizontal := Vector2(delta.x, delta.z).length()
		if horizontal < 0.000001: return {"error": "195 lobe has no stable authored azimuth."}
		ranked.append({"node": n, "forward": -delta.z / horizontal})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.forward) == float(b.forward): return str(a.node.feature_id) < str(b.node.feature_id)
		return float(a.forward) > float(b.forward))
	var weight_sum := 0.0
	for i in range(ranked.size()): weight_sum += float(RANK_WEIGHTS[i])
	var allocations: Array = []
	for rank in range(ranked.size()):
		var n: Dictionary = ranked[rank].node
		var target: float = total * LOBE_SHARE * float(RANK_WEIGHTS[rank]) / weight_sum
		var ratio: Vector3 = Graph.vec(AXIS_RATIOS[rank])
		var s: Vector3 = ratio * pow(target / (ratio.x * ratio.y * ratio.z), 1.0 / 3.0)
		n.size = Graph.arr(s)
		var basis: Basis = Graph.node_basis(n)
		var extent_y := sqrt(pow(basis.x.y * s.x, 2.0) + pow(basis.y.y * s.y, 2.0) + pow(basis.z.y * s.z, 2.0))
		var vertical: float = extent_y + CLEARANCE * float(morphology.width) - center.y
		var azimuth: Vector3 = Graph.vec(n.position) - center
		azimuth.y = 0.0; azimuth = azimuth.normalized()
		var low := 0.0
		var high := 2.0 * (maxf(root_size.x, maxf(root_size.y, root_size.z)) + maxf(s.x, maxf(s.y, s.z)))
		if _residual(low, vertical, azimuth, core, n) >= 0.0 or _residual(high, vertical, azimuth, core, n) <= 0.0:
			return {"error": "195 fixed shoulder equation has no bracket; no fallback or parameter search.", "feature_id": n.feature_id}
		for iteration in range(BISECTIONS):
			var middle := (low + high) * 0.5
			if _residual(middle, vertical, azimuth, core, n) > 0.0: high = middle
			else: low = middle
		n.position = Graph.arr(center + azimuth * ((low + high) * 0.5) + Vector3.UP * vertical)
		var offset: Vector3 = Graph.vec(n.position) - center
		var direction := offset.normalized()
		var a := _radius(core, direction); var b := _radius(n, -direction)
		allocations.append({"node_id": n.id, "feature_id": n.feature_id, "rank": rank, "nominal_volume_share": target / total,
			"position": n.position.duplicate(), "size": n.size.duplicate(), "overlap_fraction": (a + b - offset.length()) / minf(a, b)})
	var after := 0.0
	var changed := {}
	for n: Dictionary in body:
		var s: Vector3 = Graph.vec(n.size)
		var minimum := minf(s.x, minf(s.y, s.z))
		if not s.is_finite() or minimum / maxf(s.x, maxf(s.y, s.z)) < MIN_AXIS_RATIO: return {"error": "195 axis-ratio qualification failed."}
		n.radius = minimum; n.blend = minimum * BLEND; n.shape = {"sculpt_strength": SCULPT}
		after += _volume(n); changed[str(n.id)] = n
	if absf(after / total - 1.0) > VOLUME_TOLERANCE: return {"error": "195 nominal base volume allocation drifted."}
	var root_checks: Array = []
	for id: String in supports:
		if not all_nodes.has(id): return {"error": "195 missing original support."}
		var support: Dictionary = all_nodes[id]
		if support.kind != "curve" or not changed.has(str(support.parent)): return {"error": "195 support lost its existing body host."}
		var host: Dictionary = changed[str(support.parent)]
		var local: Vector3 = Graph.node_basis(host).inverse() * (Graph.vec(support.points[0]) - Graph.vec(host.position))
		var normalized := (local / Graph.vec(host.size)).length()
		root_checks.append({"support_id": id, "host_id": support.parent, "normalized_root_radius": normalized})
		if normalized > ROOT_LIMIT: return {"error": "195 unchanged support root is not sufficiently buried; no support movement fallback.", "support_id": id, "normalized_root_radius": normalized}
	return {"version": VERSION, "mode": MODE, "pinned_spec_sha256": PIN_SHA256, "stage": 2, "body_nodes": body,
		"body_node_ids": ids.duplicate(), "support_node_ids": supports.duplicate(), "allocations": allocations,
		"nominal_volume_ratio": after / total, "core_nominal_volume_share": _volume(core) / total,
		"source_bounds": _bounds(original), "developed_bounds": _bounds(body), "support_roots": root_checks,
		"supports_unchanged": true, "native_surface_burial_pending": true, "no_new_carriers": true,
		"witness_pair": [str(core.feature_id), str(ranked[0].node.feature_id)], "anatomical_acceptance": false}

static func apply(g: RefCounted, morphology: Dictionary) -> Dictionary:
	var report: Dictionary = describe(g.dna, morphology)
	if report.has("error"): return report
	for developed: Dictionary in report.body_nodes:
		var n: Dictionary = g.node(str(developed.id))
		var feature: Dictionary = Blueprint.feature(g.biological_blueprint, str(n.feature_id))
		if feature.is_empty() or feature.type != "body": return {"error": "195 refuses to retype an existing body carrier."}
		feature.geometry_recipe["anatomical_development"] = {"stage": 2, "mode": MODE, "position": developed.position.duplicate(), "size": developed.size.duplicate(), "blend": developed.blend, "sculpt_strength": SCULPT}
		for key: String in ["position", "size", "radius", "blend", "shape"]: n[key] = developed[key]
		for connection: Dictionary in g.dna.connections:
			if str(connection.get("to", "")) == str(n.id): connection["blend"] = n.blend
		# Semantic roles will be recomputed from actual developed carrier centers.
		n.erase("semantic_roles")
	report.erase("body_nodes")
	g.dna.settings[SETTING] = MODE
	g.dna.metadata["base_volume_development"] = report.duplicate(true)
	g.dna.metadata["iteration_operation"] = "195_unequal_body_compartment_development_existing_ids_fixed_supports"
	return report
