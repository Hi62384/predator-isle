extends RefCounted
## A locally sampled rounded tissue remnant with five irregular voids. A single
## implicit field creates all bridges/junctions together. The extracted closed
## shell is supported on, but NOT welded into, the retained primary body.
const Plan = preload("res://alien_foundry/scripts/anatomy/BlobLocalLattice.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Support = preload("res://alien_foundry/scripts/geometry/BlobMembraneSurface.gd")
const Extractor = preload("res://alien_foundry/scripts/geometry/LocalSurfaceNets.gd")
const MAX_SAMPLES := 300000
const MAX_TRIANGLES := 30000

static func has_plan(dna: Dictionary) -> bool:
	for node: Dictionary in dna.get("nodes", []):
		if node.has(Plan.SPEC_KEY): return true
	return false

static func append_geometry(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null) -> Dictionary:
	var spec := {}; var host := {}
	for node: Dictionary in dna.get("nodes", []):
		if not node.has(Plan.SPEC_KEY): continue
		if not spec.is_empty() or not node[Plan.SPEC_KEY] is Dictionary: return _error("Exactly one local lattice specification is supported.")
		spec = node[Plan.SPEC_KEY]; host = node
	if spec.is_empty(): return {}
	var valid := validate_spec(spec, host, dna)
	if valid.has("error"): return valid
	for detail: Dictionary in geometry.get("detail_meshes", []):
		if str(detail.get("local_lattice_id", "")) == str(spec.id): return {}
	# A recorded safe rejection is idempotent within this retained mesh too.
	if geometry.get("stats", {}).has("surface_local_lattice"): return {}
	var result := build(dna, geometry, host, spec, controls)
	if result.has("error") or bool(result.get("cancelled", false)): return result
	var report: Dictionary = result.get("report", {})
	if result.has("mesh"):
		var details: Array = geometry.get("detail_meshes", []).duplicate()
		var existing := 0
		for detail: Dictionary in details: existing += detail.indices.size() / 3
		var limit := mini(int(dna.budget.get("max_detail_triangles", 35000)), int(geometry.get("stats", {}).get("max_detail_triangles", 35000)))
		if existing + int(result.mesh.stats.triangles) > limit:
			report.status = "rejected_detail_budget"; report.realized_count = 0
		else:
			details.append(result.mesh); geometry["detail_meshes"] = details
			geometry["bounds"] = geometry.bounds.merge(result.mesh.bounds)
			geometry.stats["detail_triangles"] = existing + int(result.mesh.stats.triangles)
			geometry.stats["generated_triangles"] = geometry.indices.size() / 3 + int(geometry.stats.detail_triangles)
	geometry.stats["surface_local_lattice"] = report
	return {}

static func _error(message: String) -> Dictionary:
	return {"error": message, "error_code": "invalid_local_lattice_plan"}

static func validate_spec(spec: Dictionary, host: Dictionary, dna: Dictionary) -> Dictionary:
	if str(dna.get("type", "")) != "Blob" or str(host.get("kind", "")) != "mass": return _error("Local lattice requires an existing Blob mass host.")
	if spec.get("version") not in [1, 1.0] or str(spec.get("geometry_path", "")) != Plan.GEOMETRY_PATH or str(spec.get("id", "")) != Plan.ID: return _error("Unsupported local lattice version or algorithm.")
	if str(spec.get("host_id", "")) != str(host.id) or spec.get("pipeline_stage") not in [2, 2.0]: return _error("Local lattice is Stage 2 surface geometry.")
	for key: String in ["direction", "center_offset", "outer", "roots", "holes"]:
		if not spec.get(key) is Array: return _error("Invalid local lattice array: " + key)
	if spec.direction.size() != 3 or spec.center_offset.size() != 2 or spec.outer.size() < 8 or spec.outer.size() > 16 or spec.roots.size() != 3 or spec.holes.size() != 5: return _error("Local lattice topology exceeds the bounded contract.")
	var ranges := {"scale_ratio": Vector2(0.6, 1.0), "refinement": Vector2(3.0, 4.0), "round_radius": Vector2(0.06, 0.12), "lift_ratio": Vector2(0.12, 0.3), "root_burial_ratio": Vector2(0.08, 0.15)}
	for key: String in ranges:
		var v: Variant = spec.get(key)
		if not (v is float or v is int) or not is_finite(float(v)) or float(v) < ranges[key].x or float(v) > ranges[key].y: return _error("Local lattice profile outside bounded range: " + key)
	for value: Variant in spec.direction + spec.center_offset:
		if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value)) > 1.0: return _error("Invalid dimensionless local frame.")
	if Graph.vec(spec.direction).length() < 0.9: return _error("Invalid local support direction.")
	for values: Array in [spec.outer, spec.roots]:
		for p: Variant in values:
			if not p is Array or p.size() not in [2, 3]: return _error("Invalid local contour or root.")
			for v: Variant in p:
				if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v)) > 1.1: return _error("Unbounded local contour or root.")
	for root: Array in spec.roots:
		if root.size() != 3 or float(root[2]) < 0.15 or float(root[2]) > 0.35: return _error("Invalid root footprint.")
	for hole: Variant in spec.holes:
		if not hole is Dictionary: return _error("Invalid opening descriptor.")
		for key: String in ["center", "radii"]:
			if not hole.get(key) is Array or hole[key].size() != 2: return _error("Invalid opening dimensions.")
			for v: Variant in hole[key]:
				if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v)) > 0.8: return _error("Unbounded opening dimensions.")
		if minf(float(hole.radii[0]), float(hole.radii[1])) < 0.08: return _error("Opening smaller than supported local profile.")
		for key: String in ["angle", "phase"]:
			var v: Variant = hole.get(key)
			if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v)) > TAU: return _error("Invalid opening orientation.")
	for key: String in ["max_samples", "max_triangles"]:
		var v: Variant = spec.get(key)
		if not (v is float or v is int) or not is_finite(float(v)) or float(v) < 1.0: return _error("Invalid local resource budget.")
	return {}

static func build(dna: Dictionary, body: Dictionary, host: Dictionary, spec: Dictionary, controls: RefCounted = null) -> Dictionary:
	var started := Time.get_ticks_usec()
	var report := {"version": 1, "geometry_path": Plan.GEOMETRY_PATH, "pipeline_stage": 2, "realized_count": 0,
		"status": "pending", "primary_mesh_mutated": false, "welded_to_primary": false, "visual_validated": false,
		"new_bones": 0, "expected_openings": 5, "support_source": "retained_body_triangles", "placement_attempts": 1}
	if body.get("vertices", PackedVector3Array()).is_empty(): return _error("Local lattice needs retained body triangles.")
	var body_step := float(body.get("stats", {}).get("cell_size", 0.0))
	if body_step <= 0.0: return _error("Local lattice needs the retained body sampling scale.")
	var scale := minf(Graph.vec(host.size).x, Graph.vec(host.size).y) * float(spec.scale_ratio)
	var step := body_step / float(spec.refinement)
	var local_step := step / scale
	var minimum := Vector3(-1.10, -1.08, -0.20)
	var extent := Vector3(2.20, 2.16, 0.40)
	var dims := Vector3i((extent / local_step).ceil()) + Vector3i.ONE
	var samples := dims.x * dims.y * dims.z
	report.merge({"body_cell_size": body_step, "cell_size": step, "refinement": body_step / step, "grid": [dims.x, dims.y, dims.z], "grid_samples": samples, "scale": scale,
		"max_samples": mini(MAX_SAMPLES, int(spec.max_samples)), "max_triangles": mini(MAX_TRIANGLES, int(spec.max_triangles))})
	if samples > int(report.max_samples): report.status = "rejected_sample_budget"; return {"report": report}
	var atlas := Support._project_triangles(body, Graph.vec(spec.direction).normalized())
	var origin := Graph.vec(host.position) + Vector3(atlas.x) * scale * float(spec.center_offset[0]) + Vector3(atlas.y) * scale * float(spec.center_offset[1])
	var center_hit := Support._hit(atlas, origin)
	if center_hit.is_empty(): report.status = "rejected_missing_center_support"; return {"report": report}
	var roots: Array = []
	for r: Array in spec.roots:
		var point := origin + Vector3(atlas.x) * scale * float(r[0]) + Vector3(atlas.y) * scale * float(r[1])
		var hit := Support._hit(atlas, point)
		if hit.is_empty() or Vector3(hit.normal).dot(Vector3(atlas.normal)) < 0.20:
			report.status = "rejected_missing_root_support"; return {"report": report}
		roots.append(hit)
	var contour := _contour(spec.outer)
	var values := PackedFloat32Array(); values.resize(samples)
	var planar := PackedFloat32Array(); planar.resize(dims.x * dims.y)
	var radii := PackedFloat32Array(); radii.resize(planar.size())
	var covered := 0; var voids := 0
	for y in range(dims.y):
		if controls != null and controls.is_cancelled(): return {"cancelled": true}
		for x in range(dims.x):
			var uv := Vector2(minimum.x + x * local_step, minimum.y + y * local_step)
			var outer := _polygon_distance(uv, contour)
			var q := outer
			for hole: Dictionary in spec.holes: q = maxf(q, -_hole_distance(uv, hole))
			var idx := x + y * dims.x
			planar[idx] = q
			var insertion := _root_amount(uv, spec.roots)
			radii[idx] = float(spec.round_radius) * (0.85 + 0.18 * sin(uv.x * 4.1 + uv.y * 2.3) + 0.48 * insertion)
			if outer < 0.0:
				covered += 1
				if q > 0.0: voids += 1
	for z in range(dims.z):
		if controls != null and controls.is_cancelled(): return {"cancelled": true}
		var height := minimum.z + z * local_step
		for i in range(planar.size()):
			# Rounded extrusion of a nonuniform tissue remnant. Narrow bridges
			# round completely; broader multi-way junctions retain a fleshy core.
			var radius := float(radii[i])
			values[z * planar.size() + i] = sqrt(pow(maxf(float(planar[i]) + radius, 0.0), 2.0) + height * height) - radius
	report["field_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	report["projected_open_fraction"] = float(voids) / maxi(covered, 1)
	report["openness_note"] = "Measured local contour projection, not an art acceptance threshold."
	var mesh := Extractor.extract(values, dims, minimum, local_step, controls)
	values.clear(); planar.clear(); radii.clear()
	if bool(mesh.get("cancelled", false)): return mesh
	if bool(mesh.get("rejected", false)):
		report.merge(mesh, true); report.status = "rejected_ambiguous_local_cells"; return {"report": report}
	var triangle_count: int = mesh.indices.size() / 3
	report["triangles"] = triangle_count
	report["active_cells"] = mesh.get("active_cells", 0)
	report["unresolved_dual_edges"] = mesh.get("unresolved_dual_edges", 0)
	report["ambiguous_cells"] = mesh.get("ambiguous_cells", 0)
	if triangle_count > int(report.max_triangles): report.status = "rejected_triangle_budget"; return {"report": report}
	var topology := topology_audit(mesh)
	report["topology"] = topology
	if int(topology.components) != 1 or int(topology.bad_edges) != 0 or int(topology.euler) != -8 or int(mesh.get("unresolved_dual_edges", 0)) != 0:
		report.status = "rejected_local_topology"; return {"report": report}
	var colors := PackedColorArray(); var uvs := PackedVector2Array(); var uvs2 := PackedVector2Array()
	var dominant := PackedInt32Array(); var owners := PackedInt32Array(); var weights := PackedFloat32Array(); var context := PackedFloat32Array()
	var attachment_samples: Array = []; var root_counts := [0, 0, 0]
	var ids: PackedStringArray = body.node_ids
	var min_burial := INF
	for vi in range(mesh.vertices.size()):
		if vi % 1024 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		var local: Vector3 = mesh.vertices[vi]
		var uv := Vector2(local.x, local.y)
		var base := origin + Vector3(atlas.x) * local.x * scale + Vector3(atlas.y) * local.y * scale
		var hit := Support._hit(atlas, base)
		var root_id := _nearest_root(uv, spec.roots)
		var insertion := _root_amount(uv, spec.roots)
		if hit.is_empty() and insertion > 0.001: report.status = "rejected_root_crosses_silhouette"; return {"report": report}
		var surface: Dictionary = hit if not hit.is_empty() else roots[root_id]
		var support_height := Vector3(surface.point).dot(Vector3(atlas.normal))
		var clearance := float(spec.lift_ratio) * (0.82 + 0.18 * sin(local.x * 2.1 - local.y * 3.2))
		var offset := lerpf(clearance, -float(spec.root_burial_ratio), insertion)
		var height := support_height + (offset + local.z) * scale
		mesh.vertices[vi] = base + Vector3(atlas.normal) * (height - base.dot(Vector3(atlas.normal)))
		var influence := Support._hit_influences(body, surface)
		dominant.append(int(influence.owners[0])); owners.append_array(influence.owners); weights.append_array(influence.weights)
		colors.append(Color(0.0, 0.5, 0.0, 1.0)); uvs.append((uv + Vector2.ONE) * 0.5); uvs2.append(Vector2(scale * float(spec.round_radius) * 2.0, insertion))
		context.append_array(PackedFloat32Array([insertion, 0.65, 0.85 - insertion * 0.5, 0.2 + insertion * 0.7]))
		if insertion > 0.999:
			var burial := (Vector3(hit.point) - Vector3(mesh.vertices[vi])).dot(Vector3(hit.normal))
			min_burial = minf(min_burial, burial)
			attachment_samples.append({"vertex_id": vi, "triangle": hit.triangle, "barycentric": Graph.arr(hit.barycentric), "point": Graph.arr(hit.point),
				"root_index": root_id, "host_id": str(ids[influence.owners[0]]), "burial": burial})
			root_counts[root_id] += 1
	for count: int in root_counts:
		if count < 12: report.status = "rejected_insufficient_root_area"; report["root_counts"] = root_counts; return {"report": report}
	if min_burial <= 0.0: report.status = "rejected_exposed_foundation"; report["minimum_burial"] = min_burial; return {"report": report}
	_recompute_normals(mesh)
	var bounds := AABB(mesh.vertices[0], Vector3.ZERO)
	for point: Vector3 in mesh.vertices: bounds = bounds.expand(point)
	var openings: Array = []
	for hole: Dictionary in spec.holes:
		var uv := Vector2(float(hole.center[0]), float(hole.center[1]))
		var base := origin + Vector3(atlas.x) * uv.x * scale + Vector3(atlas.y) * uv.y * scale
		openings.append({"center": Graph.arr(base), "normal": Graph.arr(atlas.normal), "probe_radius": minf(float(hole.radii[0]), float(hole.radii[1])) * scale * 0.25})
	mesh.merge({"name": "LocalPorousTissue", "role": "flesh", "local_lattice_id": spec.id, "geometry_path": Plan.GEOMETRY_PATH, "pipeline_stage": 2,
		"colors": colors, "uvs": uvs, "uvs2": uvs2, "fibre_uv_mode": "authored", "authored_surface_context": context,
		"component_ids": dominant, "component_indices": owners, "component_weights": weights, "node_ids": ids,
		"surface_root_samples": attachment_samples, "opening_witnesses": openings, "bounds": bounds,
		"stats": {"triangles": triangle_count, "vertices": mesh.vertices.size(), "cell_size": step, "grid_samples": samples, "welded_to_primary": false}}, true)
	report.merge({"status": "realized_pending_visual_review", "realized_count": 1, "vertices": mesh.vertices.size(), "root_counts": root_counts,
		"minimum_root_burial": min_burial, "geometry_ms": (Time.get_ticks_usec() - started) / 1000.0, "root_count": 3}, true)
	return {"mesh": mesh, "report": report}

static func _root_amount(p: Vector2, roots: Array) -> float:
	var result := 0.0
	for root: Array in roots:
		var distance := p.distance_to(Vector2(float(root[0]), float(root[1]))) / float(root[2])
		result = maxf(result, 1.0 - smoothstep(0.50, 1.70, distance))
	return result

static func _nearest_root(p: Vector2, roots: Array) -> int:
	var result := 0; var closest := INF
	for i in range(roots.size()):
		var r: Array = roots[i]
		var distance := p.distance_squared_to(Vector2(float(r[0]), float(r[1])))
		if distance < closest: closest = distance; result = i
	return result

static func _contour(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(raw.size()):
		var a: Array = raw[(i + raw.size() - 1) % raw.size()]; var b: Array = raw[i]
		var c: Array = raw[(i + 1) % raw.size()]; var d: Array = raw[(i + 2) % raw.size()]
		var p0 := Vector2(float(a[0]), float(a[1])); var p1 := Vector2(float(b[0]), float(b[1]))
		var p2 := Vector2(float(c[0]), float(c[1])); var p3 := Vector2(float(d[0]), float(d[1]))
		for j in range(6): points.append(p1.cubic_interpolate(p2, p0, p3, float(j) / 6.0))
	return points

static func _polygon_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var distance := INF; var inside := false
	var j := poly.size() - 1
	for i in range(poly.size()):
		var a := poly[j]; var b := poly[i]; var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0000001), 0.0, 1.0)
		distance = minf(distance, p.distance_squared_to(a + ab * t))
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x: inside = not inside
		j = i
	return sqrt(distance) * (-1.0 if inside else 1.0)

static func _hole_distance(p: Vector2, hole: Dictionary) -> float:
	var q := (p - Vector2(float(hole.center[0]), float(hole.center[1]))).rotated(-float(hole.angle))
	var radius := Vector2(float(hole.radii[0]), float(hole.radii[1]))
	var normalized := q / radius
	var theta := atan2(normalized.y, normalized.x)
	var modulation := 1.0 + 0.065 * sin(theta * 3.0 + float(hole.phase)) + 0.035 * cos(theta * 2.0 - float(hole.phase))
	return (normalized.length() - modulation) * minf(radius.x, radius.y)

static func _recompute_normals(mesh: Dictionary) -> void:
	mesh.normals.fill(Vector3.ZERO)
	for i in range(0, mesh.indices.size(), 3):
		var a: int = mesh.indices[i]; var b: int = mesh.indices[i + 1]; var c: int = mesh.indices[i + 2]
		var normal: Vector3 = (mesh.vertices[c] - mesh.vertices[a]).cross(mesh.vertices[b] - mesh.vertices[a])
		mesh.normals[a] += normal; mesh.normals[b] += normal; mesh.normals[c] += normal
	for i in range(mesh.normals.size()): mesh.normals[i] = mesh.normals[i].normalized()

static func topology_audit(mesh: Dictionary) -> Dictionary:
	var edges := {}; var parent := PackedInt32Array(); parent.resize(mesh.vertices.size())
	for i in range(parent.size()): parent[i] = i
	for i in range(0, mesh.indices.size(), 3):
		for j in range(3):
			var a: int = mesh.indices[i + j]; var b: int = mesh.indices[i + (j + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not edges.has(key): edges[key] = Vector2i.ZERO
			edges[key] += Vector2i(1, 1 if a < b else -1)
			while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
			while parent[b] != b: parent[b] = parent[parent[b]]; b = parent[b]
			if a != b: parent[b] = a
	var components := {}; var bad := 0
	for i in range(parent.size()):
		var a := i
		while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
		components[a] = true
	for edge: Vector2i in edges.values():
		if edge.x != 2 or edge.y != 0: bad += 1
	return {"components": components.size(), "bad_edges": bad, "euler": mesh.vertices.size() - edges.size() + mesh.indices.size() / 3}
