extends RefCounted
## One bounded explicit biological covering. No volume sampling, extra field
## nodes, bones, cloth simulation or post-bind geometry is introduced here.
## Root witnesses refer to the actual retained host triangles, not ellipsoids.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Plan = preload("res://alien_foundry/scripts/anatomy/BlobMembraneCovering.gd")
const MAX_TRIANGLES := 3600
const DIRECTIONS := [Vector3(0, 0.18, -1), Vector3(-0.55, 0.20, -1), Vector3(0.55, 0.20, -1), Vector3(0, 1, -0.30)]

static func append_geometry(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null) -> Dictionary:
	var spec: Dictionary = {}
	for node: Dictionary in dna.get("nodes", []):
		if node.has(Plan.SPEC_KEY):
			if not spec.is_empty() or not node[Plan.SPEC_KEY] is Dictionary:
				return {"error": "A secondary membrane requires exactly one bounded specification.", "error_code": "invalid_membrane_plan"}
			spec = node[Plan.SPEC_KEY]
	if spec.is_empty(): return {}
	var validation := _validate_spec(spec, dna)
	if validation.has("error"): return validation
	for detail: Dictionary in geometry.get("detail_meshes", []):
		if str(detail.get("covering_id", "")) == str(spec.id): return {}
	var report := {"version": 1, "requested": true, "realized_count": 0, "status": "skipped_no_supported_pair",
		"pipeline_stage": 3, "spec_id": spec.id, "candidate_attempts": 0, "skip_reasons": [],
		"visual_validated": false, "support_source": "retained_extracted_triangles", "new_bones": 0}
	var result := build(dna, geometry, spec, controls)
	if result.has("error") or bool(result.get("cancelled", false)): return result
	report.merge(result.get("report", {}), true)
	if result.has("mesh"):
		var details: Array = geometry.get("detail_meshes", []).duplicate()
		var existing_triangles := 0
		for detail: Dictionary in details: existing_triangles += detail.get("indices", PackedInt32Array()).size() / 3
		var limit := int(dna.get("budget", {}).get("max_detail_triangles", 35000))
		# A bounded body rebuild may reduce the available detail allowance.
		limit = mini(limit, int(geometry.get("stats", {}).get("max_detail_triangles", limit)))
		if existing_triangles + int(result.mesh.stats.triangles) > limit:
			report.status = "skipped_detail_budget"
			report.realized_count = 0
			report["candidate_triangles"] = int(result.mesh.stats.triangles)
			report["triangles"] = 0
			report["vertices"] = 0
		else:
			details.append(result.mesh)
			geometry["detail_meshes"] = details
			geometry["bounds"] = geometry.get("bounds", result.mesh.bounds).merge(result.mesh.bounds)
	if not geometry.has("stats"): geometry["stats"] = {}
	geometry.stats["secondary_membrane"] = report
	if int(report.realized_count) == 1:
		var detail_triangles := 0
		for detail: Dictionary in geometry.get("detail_meshes", []): detail_triangles += detail.indices.size() / 3
		geometry.stats["detail_triangles"] = detail_triangles
		geometry.stats["generated_triangles"] = geometry.indices.size() / 3 + detail_triangles
	return {}

static func _validate_spec(spec: Dictionary, dna: Dictionary) -> Dictionary:
	var version: Variant = spec.get("version", 0)
	var valid := (version is int or version is float) and float(version) == 1.0 and str(spec.get("id", "")) == "primary_body.secondary_membrane.0"
	valid = valid and str(dna.get("type", "")) == "Blob" and spec.get("host_ids") is Array
	if not valid: return {"error": "Invalid or unsupported secondary membrane plan.", "error_code": "invalid_membrane_plan"}
	if spec.host_ids.size() < 2 or spec.host_ids.size() > 12: valid = false
	var ranges := {"phase": Vector2(0, TAU), "width_ratio": Vector2(0.3, 0.8), "sag_ratio": Vector2(0.0, 0.15),
		"lift_ratio": Vector2(0.05, 0.3), "thickness_ratio": Vector2(0.004, 0.025), "root_band": Vector2(0.10, 0.20)}
	for key: String in ranges:
		var value: Variant = spec.get(key)
		if not (value is float or value is int) or not is_finite(float(value)): valid = false
		elif float(value) < ranges[key].x or float(value) > ranges[key].y: valid = false
	var known := {}
	for node: Dictionary in dna.get("nodes", []): known[str(node.id)] = str(node.get("kind", ""))
	var seen := {}
	for id: Variant in spec.host_ids:
		if not id is String or known.get(str(id), "") != "mass" or seen.has(str(id)): valid = false
		seen[str(id)] = true
	return {} if valid else {"error": "Secondary membrane supports or profile exceed the bounded contract.", "error_code": "invalid_membrane_plan"}

static func build(dna: Dictionary, geometry: Dictionary, spec: Dictionary, controls: RefCounted = null) -> Dictionary:
	var validation := _validate_spec(spec, dna)
	if validation.has("error"): return validation
	var vertices: PackedVector3Array = geometry.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = geometry.get("indices", PackedInt32Array())
	if vertices.is_empty() or indices.is_empty(): return {"error": "Membrane fitting requires completed host triangles.", "error_code": "missing_membrane_support"}
	var nodes := {}
	for node: Dictionary in dna.nodes: nodes[str(node.id)] = node
	var attempts := 0
	var reasons: Array = []
	var cleft_rejections: Array = []
	for raw_direction: Vector3 in DIRECTIONS:
		if controls != null and controls.is_cancelled(): return {"cancelled": true}
		var direction := raw_direction.normalized()
		var atlas := _project_triangles(geometry, direction)
		var pairs: Array = []
		for ai in range(spec.host_ids.size()):
			for bi in range(ai + 1, spec.host_ids.size()):
				var a: Dictionary = nodes[str(spec.host_ids[ai])]
				var b: Dictionary = nodes[str(spec.host_ids[bi])]
				var delta := Graph.vec(b.position) - Graph.vec(a.position)
				var projected := delta - direction * delta.dot(direction)
				var size_a := Graph.vec(a.size); var size_b := Graph.vec(b.size)
				var radius := minf(size_a.length(), size_b.length()) / sqrt(3.0)
				var span := projected.length()
				if span < radius * 0.60 or span > radius * 3.3: continue
				var score := span / radius - absf(delta.dot(direction)) / radius * 0.6
				if str(a.get("role", "")) == "core" or str(b.get("role", "")) == "core": score -= 0.6
				pairs.append({"a": a, "b": b, "score": score})
		pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
		var qualified: Array = []
		for pair: Dictionary in pairs.slice(0, 12):
			if controls != null and controls.is_cancelled(): return {"cancelled": true}
			attempts += 1
			var selection := _qualify_cleft(geometry, atlas, pair.a, pair.b, spec)
			if selection.has("placement"):
				qualified.append({"pair": pair, "placement": selection.placement, "audit": selection.audit, "score": selection.score})
			else:
				var reason := str(selection.get("reason", "no_anatomical_cleft"))
				if reason not in reasons: reasons.append(reason)
				if cleft_rejections.size() < 8: cleft_rejections.append(selection.audit)
		# The center-distance ordering bounds the shortlist only. Real fitted
		# shoulders and a measured pre-lift cleft determine placement priority.
		qualified.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
		for selected: Dictionary in qualified:
			if controls != null and controls.is_cancelled(): return {"cancelled": true}
			var pair: Dictionary = selected.pair
			var candidate := _build_pair(dna, geometry, atlas, pair.a, pair.b, spec, selected.placement)
			if candidate.has("mesh"):
				candidate.report["candidate_attempts"] = attempts
				candidate.report["skip_reasons"] = reasons
				candidate.report["cleft_selection"] = selected.audit
				candidate.report["cleft_rejections"] = cleft_rejections
				candidate.report["emergence_audit"] = _measure_emergence(candidate.mesh, atlas)
				return candidate
			var reason := str(candidate.get("reason", "unsupported_pair"))
			if reason not in reasons: reasons.append(reason)
	return {"report": {"candidate_attempts": attempts, "skip_reasons": reasons, "cleft_rejections": cleft_rejections,
		"realized_count": 0, "status": "skipped_no_supported_pair"}}

static func _qualify_cleft(geometry: Dictionary, atlas: Dictionary, first: Dictionary, second: Dictionary, spec: Dictionary) -> Dictionary:
	var normal: Vector3 = atlas.normal
	var a := Graph.vec(first.position); var b := Graph.vec(second.position)
	var line := b - a; line -= normal * line.dot(normal)
	var span := line.length(); var across := line / span
	var along := normal.cross(across).normalized()
	if along.dot(Vector3.UP) < 0.0: along = -along
	var width_a := Graph.surface_radius(Graph.vec(first.size), Graph.node_basis(first).inverse() * along)
	var width_b := Graph.surface_radius(Graph.vec(second.size), Graph.node_basis(second).inverse() * along)
	var half_width := minf(width_a, width_b) * float(spec.width_ratio)
	var radius_a := Graph.surface_radius(Graph.vec(first.size), Graph.node_basis(first).inverse() * across)
	var radius_b := Graph.surface_radius(Graph.vec(second.size), Graph.node_basis(second).inverse() * across)
	var ids: PackedStringArray = geometry.get("node_ids", PackedStringArray())
	var owner_a := ids.find(str(first.id)); var owner_b := ids.find(str(second.id))
	var trials: Array = []; var best := {}; var best_score := -INF
	# Fit the unchanged sheet window to the measured anatomy. These three
	# declared centers are the whole search, not an adaptive success hunt.
	for transverse_center: float in [0.0, -0.5, 0.5]:
		var window_offset := along * half_width * transverse_center
		for inset: float in [0.0, 0.18, 0.32]:
			var left_origin := a + across * radius_a * inset + window_offset
			var right_origin := b - across * radius_b * inset + window_offset
			var trial := _measure_cleft(geometry, atlas, left_origin, right_origin, along, across, half_width, owner_a, owner_b, spec)
			trial["shoulder_inset_ratio"] = inset
			trial["transverse_center_ratio"] = transverse_center
			trials.append(trial)
			if bool(trial.qualified) and float(trial.score) > best_score:
				best_score = float(trial.score)
				best = {"placement": {"a": left_origin, "b": right_origin}, "score": best_score, "selected": trial}
	var audit := {"method": "retained_triangle_cleft_before_authored_lift_v1", "host_ids": [str(first.id), str(second.id)],
		"direction": Graph.arr(normal), "shoulder_trials": trials, "qualified": not best.is_empty(),
		"transverse_centers": [0.0, -0.5, 0.5], "maximum_trial_count": 9}
	if best.is_empty(): return {"reason": "no_genuine_supported_cleft", "audit": audit}
	audit["selected_trial"] = best.selected
	return {"placement": best.placement, "score": best_score, "audit": audit}

static func _measure_cleft(geometry: Dictionary, atlas: Dictionary, a: Vector3, b: Vector3, along: Vector3, across: Vector3, half_width: float, owner_a: int, owner_b: int, spec: Dictionary) -> Dictionary:
	var normal: Vector3 = atlas.normal
	var span := (b - a - normal * (b - a).dot(normal)).length()
	var threshold := maxf(minf(span, half_width * 2.0) * float(spec.thickness_ratio) * 4.0, span * 0.08)
	var audit := {"qualified": false, "score": 0.0, "span": span, "required_natural_depth": threshold,
		"qualified_rails": 0, "minimum_shoulder_facing": 1.0, "rails": [], "authored_lift_applied": false}
	if span <= 0.001 or half_width < span * 0.10 or half_width > span * 0.85 or owner_a < 0 or owner_b < 0:
		audit["reason"] = "unsuitable_shoulders"; return audit
	var all_supported := true; var depth_sum := 0.0
	for lateral_ratio: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		var left := _hit(atlas, a + along * half_width * lateral_ratio)
		var right := _hit(atlas, b + along * half_width * lateral_ratio)
		var rail := {"lateral_ratio": lateral_ratio, "supported": false, "qualified": false, "samples": []}
		if left.is_empty() or right.is_empty():
			all_supported = false; audit.rails.append(rail); continue
		var facing := minf(left.normal.dot(across), -right.normal.dot(across))
		var left_weight := _owner_weight(geometry, left, owner_a); var right_weight := _owner_weight(geometry, right, owner_b)
		rail.merge({"left_point": Graph.arr(left.point), "right_point": Graph.arr(right.point),
			"left_triangle": left.triangle, "right_triangle": right.triangle, "left_owner_weight": left_weight,
			"right_owner_weight": right_weight, "opposing_inward_normal": facing}, true)
		rail.supported = left_weight >= 0.30 and right_weight >= 0.30 and left.normal.dot(atlas.normal) > 0.18 and right.normal.dot(atlas.normal) > 0.18
		if not rail.supported: all_supported = false
		var run := 0; var longest_run := 0; var relief := 0.0
		for step in range(9):
			var u := float(step) / 8.0
			var chord: Vector3 = left.point.lerp(right.point, u)
			var body_hit := _hit(atlas, chord)
			var sample := {"u": u, "chord_point": Graph.arr(chord), "open_gap": body_hit.is_empty()}
			var clear := body_hit.is_empty()
			if not body_hit.is_empty():
				var depression := chord.dot(atlas.normal) - float(body_hit.height)
				sample["body_point"] = Graph.arr(body_hit.point); sample["depression"] = depression
				clear = depression >= threshold
				if step >= 2 and step <= 6: relief = maxf(relief, depression)
			if step >= 2 and step <= 6:
				run = run + 1 if clear else 0
				longest_run = maxi(longest_run, run)
			rail.samples.append(sample)
		rail["longest_clear_run"] = longest_run
		rail.qualified = bool(rail.supported) and facing >= 0.08 and longest_run >= 3
		if rail.qualified:
			audit.qualified_rails += 1
			audit.minimum_shoulder_facing = minf(float(audit.minimum_shoulder_facing), facing)
			depth_sum += maxf(relief, threshold)
		audit.rails.append(rail)
	# A single deep point is not a cleft. The central three rails must each
	# sustain the gap across at least three of five middle chord samples.
	audit.qualified = all_supported and bool(audit.rails[1].qualified) and bool(audit.rails[2].qualified) and bool(audit.rails[3].qualified)
	if audit.qualified: audit.score = float(audit.qualified_rails) / 5.0 + depth_sum / (5.0 * span) + float(audit.minimum_shoulder_facing)
	return audit

static func _project_triangles(geometry: Dictionary, direction: Vector3) -> Dictionary:
	var x_axis := Vector3.UP.cross(direction).normalized()
	if x_axis.length_squared() < 0.5: x_axis = Vector3.RIGHT
	var y_axis := direction.cross(x_axis).normalized()
	var vertices: PackedVector3Array = geometry.vertices
	var projected := PackedVector3Array(); projected.resize(vertices.size())
	var minimum := Vector2(INF, INF); var maximum := Vector2(-INF, -INF)
	for i in range(vertices.size()):
		var point := Vector3(vertices[i].dot(x_axis), vertices[i].dot(y_axis), vertices[i].dot(direction))
		projected[i] = point
		minimum = minimum.min(Vector2(point.x, point.y)); maximum = maximum.max(Vector2(point.x, point.y))
	var step := maxf((maximum - minimum).length() / 42.0, 0.005)
	var bins := {}
	var indices: PackedInt32Array = geometry.indices
	for offset in range(0, indices.size(), 3):
		var a: Vector3 = projected[indices[offset]]; var b: Vector3 = projected[indices[offset + 1]]; var c: Vector3 = projected[indices[offset + 2]]
		var low := Vector2(a.x, a.y).min(Vector2(b.x, b.y)).min(Vector2(c.x, c.y))
		var high := Vector2(a.x, a.y).max(Vector2(b.x, b.y)).max(Vector2(c.x, c.y))
		var first := Vector2i(floori((low.x - minimum.x) / step), floori((low.y - minimum.y) / step))
		var last := Vector2i(floori((high.x - minimum.x) / step), floori((high.y - minimum.y) / step))
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if not bins.has(cell): bins[cell] = []
				bins[cell].append(offset)
	return {"x": x_axis, "y": y_axis, "normal": direction, "vertices": projected, "bins": bins, "minimum": minimum, "step": step, "geometry": geometry}

static func _hit(atlas: Dictionary, position: Vector3) -> Dictionary:
	var p := Vector2(position.dot(atlas.x), position.dot(atlas.y))
	var cell := Vector2i(floori((p.x - atlas.minimum.x) / atlas.step), floori((p.y - atlas.minimum.y) / atlas.step))
	var geometry: Dictionary = atlas.geometry
	var indices: PackedInt32Array = geometry.indices
	var projected: PackedVector3Array = atlas.vertices
	var found := {}; var height := -INF; var next_height := -INF
	for offset: int in atlas.bins.get(cell, []):
		var ia := indices[offset]; var ib := indices[offset + 1]; var ic := indices[offset + 2]
		var a := Vector2(projected[ia].x, projected[ia].y)
		var b := Vector2(projected[ib].x, projected[ib].y)
		var c := Vector2(projected[ic].x, projected[ic].y)
		var ab := b - a; var ac := c - a; var ap := p - a
		var det := ab.cross(ac)
		if absf(det) < 0.0000000001: continue
		var v := ap.cross(ac) / det; var w := ab.cross(ap) / det; var u := 1.0 - v - w
		if minf(u, minf(v, w)) < -0.00001: continue
		var z := projected[ia].z * u + projected[ib].z * v + projected[ic].z * w
		if z <= height:
			if z < height - 0.00001: next_height = maxf(next_height, z)
			continue
		if height < z - 0.00001: next_height = height
		height = z
		var normal: Vector3 = (geometry.vertices[ic] - geometry.vertices[ia]).cross(geometry.vertices[ib] - geometry.vertices[ia]).normalized()
		found = {"point": atlas.x * p.x + atlas.y * p.y + atlas.normal * z, "normal": normal,
			"triangle": offset / 3, "indices": Vector3i(ia, ib, ic), "barycentric": Vector3(u, v, w), "height": z}
	if not found.is_empty(): found["inside_depth"] = height - next_height if is_finite(next_height) else 0.0
	return found

static func _owner_weight(geometry: Dictionary, hit: Dictionary, owner: int) -> float:
	var weights: PackedFloat32Array = geometry.get("component_weights", PackedFloat32Array())
	var owners: PackedInt32Array = geometry.get("component_indices", PackedInt32Array())
	var dominant: PackedInt32Array = geometry.get("component_ids", PackedInt32Array())
	var weight := 0.0
	for corner in range(3):
		var index: int = hit.indices[corner]
		if weights.size() >= (index + 1) * 4 and owners.size() >= (index + 1) * 4:
			for slot in range(4):
				if owners[index * 4 + slot] == owner: weight += weights[index * 4 + slot] * hit.barycentric[corner]
		elif dominant.size() > index and dominant[index] == owner: weight += hit.barycentric[corner]
	return weight

static func _hit_influences(geometry: Dictionary, hit: Dictionary) -> Dictionary:
	var combined := {}
	var weights: PackedFloat32Array = geometry.get("component_weights", PackedFloat32Array())
	var owners: PackedInt32Array = geometry.get("component_indices", PackedInt32Array())
	var dominant: PackedInt32Array = geometry.get("component_ids", PackedInt32Array())
	for corner in range(3):
		var index: int = hit.indices[corner]
		if weights.size() >= (index + 1) * 4 and owners.size() >= (index + 1) * 4:
			for slot in range(4):
				var owner := owners[index * 4 + slot]
				var amount: float = weights[index * 4 + slot] * hit.barycentric[corner]
				if amount > 0.00001: combined[owner] = float(combined.get(owner, 0.0)) + amount
		elif dominant.size() > index: combined[dominant[index]] = float(combined.get(dominant[index], 0.0)) + hit.barycentric[corner]
	var ordered: Array = combined.keys()
	ordered.sort_custom(func(a: int, b: int) -> bool: return float(combined[a]) > float(combined[b]) if combined[a] != combined[b] else a < b)
	var result := {"owners": PackedInt32Array(), "weights": PackedFloat32Array()}
	var total := 0.0
	for owner: int in ordered.slice(0, 4): total += float(combined[owner])
	for slot in range(4):
		result.owners.append(int(ordered[slot]) if slot < ordered.size() else 0)
		result.weights.append(float(combined[ordered[slot]]) / maxf(total, 0.000001) if slot < ordered.size() else 0.0)
	return result

static func _build_pair(dna: Dictionary, geometry: Dictionary, atlas: Dictionary, first: Dictionary, second: Dictionary, spec: Dictionary, placement: Dictionary = {}) -> Dictionary:
	var normal: Vector3 = atlas.normal
	# The35 surface/thickness/binding equations below are deliberately kept:
	# this experiment changes only which actual shoulders anchor the patch.
	var a: Vector3 = placement.get("a", Graph.vec(first.position))
	var b: Vector3 = placement.get("b", Graph.vec(second.position))
	var line := b - a; line -= normal * line.dot(normal)
	var span := line.length(); var across := line / span
	var along := normal.cross(across).normalized()
	if along.dot(Vector3.UP) < 0.0: along = -along
	var width_a := Graph.surface_radius(Graph.vec(first.size), Graph.node_basis(first).inverse() * along)
	var width_b := Graph.surface_radius(Graph.vec(second.size), Graph.node_basis(second).inverse() * along)
	var half_width := minf(width_a, width_b) * float(spec.width_ratio)
	if half_width < span * 0.10 or half_width > span * 0.85: return {"reason": "unsuitable_span_width"}
	var ids: PackedStringArray = geometry.get("node_ids", PackedStringArray())
	var owner_a := ids.find(str(first.id)); var owner_b := ids.find(str(second.id))
	if owner_a < 0 or owner_b < 0: return {"reason": "missing_extracted_owner"}
	var quality := clampi(int(dna.settings.quality), 0, 2)
	var columns: int = [24, 32, 40][quality]
	var rows: int = [12, 16, 20][quality]
	var thickness := minf(span, half_width * 2.0) * float(spec.thickness_ratio)
	var phase := float(spec.phase)
	var band := float(spec.root_band)
	var mids := PackedVector3Array(); var half_thickness := PackedFloat32Array()
	var root_influences := {}
	var samples: Array = []; var exposed := 0; var max_gap := 0.0; var min_burial := INF
	var root_vertices := PackedInt32Array(); var root_owners := PackedStringArray()
	for y in range(rows + 1):
		var v := float(y) / float(rows)
		var row_band := _curved_root_band(band, v)
		var lateral := (v * 2.0 - 1.0) * half_width
		var anchor_a := _hit(atlas, a + along * lateral)
		var anchor_b := _hit(atlas, b + along * lateral)
		if anchor_a.is_empty() or anchor_b.is_empty(): return {"reason": "root_crosses_silhouette"}
		if _owner_weight(geometry, anchor_a, owner_a) < 0.30 or _owner_weight(geometry, anchor_b, owner_b) < 0.30:
			return {"reason": "root_not_owned_by_selected_support"}
		for x in range(columns + 1):
			var u := float(x) / float(columns)
			var center: Vector3 = anchor_a.point.lerp(anchor_b.point, u)
			var envelope := sin(PI * u)
			var root_fraction := minf(u, 1.0 - u)
			# A biological web flares into broad roots instead of maintaining a
			# rectangular strip. Unequal concave margins leave a lower drape;
			# the smooth neck vanishes inside the supported attachment bands.
			var neck := smoothstep(row_band + 0.025, 0.5, root_fraction)
			var narrowing := (0.36 + 0.18 * v) * neck
			var edge_shape := sin(u * PI * 1.35 + phase) * 0.055 + sin(u * PI * 2.7 + phase * 0.7) * 0.025
			center += along * (lateral * (envelope * edge_shape - narrowing) - span * float(spec.sag_ratio) * envelope * (0.35 + 0.65 * sin(PI * v)))
			var support := _hit(atlas, center)
			var insertion := 1.0 - smoothstep(row_band, row_band + 0.13, root_fraction)
			var half := thickness * (0.48 + 0.52 * insertion + 0.18 * absf(v * 2.0 - 1.0)) * (0.92 + 0.08 * sin(u * 5.1 + v * 2.8 + phase))
			if root_fraction <= row_band:
				if support.is_empty() or support.normal.dot(normal) < 0.18: return {"reason": "root_has_no_broad_outward_tissue"}
				var owner := owner_a if u < 0.5 else owner_b
				if _owner_weight(geometry, support, owner) < 0.15: return {"reason": "root_band_leaves_host"}
				var burial := half * 3.8
				if float(support.inside_depth) < burial + half * 2.0: return {"reason": "root_support_too_thin"}
				center = support.point - normal * burial
				min_burial = minf(min_burial, burial - half)
				var index := mids.size()
				root_influences[index] = _hit_influences(geometry, support)
				root_vertices.append(index * 2); root_vertices.append(index * 2 + 1)
				root_owners.append(str(first.id) if u < 0.5 else str(second.id)); root_owners.append(root_owners[-1])
				samples.append({"mid_index": index, "host_id": str(first.id) if u < 0.5 else str(second.id),
					"triangle": support.triangle, "barycentric": Graph.arr(support.barycentric), "point": Graph.arr(support.point),
					"burial": burial, "half_thickness": half, "support_inside_depth": support.inside_depth,
					"owner_weight": _owner_weight(geometry, support, owner)})
			else:
				var transition := smoothstep(row_band, row_band + 0.16, root_fraction)
				# The exposed span hangs near its support chord, rather than
				# inflating into a raised patch. Collision clearance still follows
				# the real body surface and takes priority over the desired sag.
				var lift := span * float(spec.lift_ratio) * 0.25 * envelope * (0.48 + 0.52 * sin(PI * v))
				var inward_sag := span * 0.025 * envelope * envelope * (0.25 + 0.75 * sin(PI * v))
				var asymmetric_fold := span * 0.025 * sin(u * PI * 2.0 + v * 2.1 + phase) * envelope * sin(PI * v)
				var height := center.dot(normal) + lift - inward_sag + asymmetric_fold
				if not support.is_empty():
					var clearance := lerpf(-half * 3.8, half * 1.7, transition)
					height = maxf(height, float(support.height) + half * 2.4)
					height = lerpf(float(support.height) + clearance, height, transition)
					var gap := height - float(support.height) - half
					if gap > half: exposed += 1; max_gap = maxf(max_gap, gap)
				else:
					exposed += 1; max_gap = maxf(max_gap, lift)
				center += normal * (height - center.dot(normal))
				if _module_collision(dna, center, half * 2.0): return {"reason": "covering_intersects_secondary_module"}
			mids.append(center); half_thickness.append(half)
	if exposed < rows * columns / 4 or max_gap < thickness * 3.0: return {"reason": "sheet_has_no_real_exposed_span"}
	var mesh := _close_sheet(mids, half_thickness, columns, rows, normal, ids, owner_a, owner_b, spec, root_influences)
	mesh["root_vertex_indices"] = root_vertices
	mesh["root_owner_ids"] = root_owners
	mesh["attachment_samples"] = samples
	mesh["root_band"] = band
	mesh["margin_profile"] = "concave_asymmetric_v1"
	mesh.stats["root_samples"] = samples.size()
	mesh.stats["minimum_root_burial"] = min_burial
	mesh.stats["maximum_under_sheet_gap"] = max_gap
	return {"mesh": mesh, "report": {"status": "realized_geometry_candidate_unvalidated", "realized_count": 1,
		"host_ids": [str(first.id), str(second.id)], "root_samples": samples.size(), "minimum_root_burial": min_burial,
		"maximum_under_sheet_gap": max_gap, "triangles": mesh.stats.triangles, "vertices": mesh.vertices.size(),
		"support_source": "retained_extracted_triangles", "visual_validated": false, "new_bones": 0,
		"direction": Graph.arr(normal), "span": span, "width": half_width * 2.0}}

static func _curved_root_band(base: float, v: float) -> float:
	# Curved emergence avoids the straight vertical seam of a pasted strip.
	# The center of each broad band remains attached a little farther inboard.
	return base + 0.045 * pow(sin(PI * v), 2.0)

static func _measure_emergence(mesh: Dictionary, atlas: Dictionary) -> Dictionary:
	# Observe the geometric front-shell/body crossing, not just deeply buried
	# root samples or lighting normals. This diagnostic changes no buffers.
	var vertices: PackedVector3Array = mesh.vertices
	var indices: PackedInt32Array = mesh.indices
	var view_normal: Vector3 = atlas.normal
	var gaps := PackedFloat32Array(); gaps.resize(vertices.size())
	for i in range(0, vertices.size(), 2):
		var hit := _hit(atlas, vertices[i])
		gaps[i] = INF if hit.is_empty() else (vertices[i] - Vector3(hit.point)).dot(view_normal)
	var samples: Array = []; var crossings := 0; var unresolved := 0
	var maximum_angle := 0.0; var total_angle := 0.0
	var front_end := int(mesh.stats.columns) * int(mesh.stats.rows) * 12
	for offset in range(0, front_end, 6):
		var ia := indices[offset]; var ib := indices[offset + 1]; var ic := indices[offset + 2]
		var sheet_normal := (vertices[ic] - vertices[ia]).cross(vertices[ib] - vertices[ia]).normalized()
		for edge: Vector2i in [Vector2i(ia, ib), Vector2i(ib, ic), Vector2i(ic, ia)]:
			var first_gap := gaps[edge.x]; var second_gap := gaps[edge.y]
			if (first_gap <= 0.0) == (second_gap <= 0.0): continue
			var buried: Vector3 = vertices[edge.x] if first_gap <= 0.0 else vertices[edge.y]
			var exposed: Vector3 = vertices[edge.y] if first_gap <= 0.0 else vertices[edge.x]
			var support := {}
			for iteration in range(8):
				var point := buried.lerp(exposed, 0.5)
				var hit := _hit(atlas, point)
				if hit.is_empty(): exposed = point; continue
				support = hit
				if (point - Vector3(hit.point)).dot(view_normal) > 0.0: exposed = point
				else: buried = point
			if support.is_empty(): unresolved += 1; continue
			var angle := rad_to_deg(acos(clampf(absf(sheet_normal.dot(support.normal)), 0.0, 1.0)))
			crossings += 1; maximum_angle = maxf(maximum_angle, angle); total_angle += angle
			if samples.size() < 96:
				samples.append({"point": Graph.arr(buried.lerp(exposed, 0.5)), "support_triangle": support.triangle,
					"geometric_angle_degrees": angle, "bisection_interval": buried.distance_to(exposed)})
	return {"method": "outer_shell_geometric_triangle_crossing_v1", "crossings": crossings, "unresolved_crossings": unresolved,
		"maximum_angle_degrees": maximum_angle, "mean_angle_degrees": total_angle / maxf(float(crossings), 1.0),
		"samples": samples, "acceptance": "diagnostic_only_not_a_smooth_root_claim"}

static func _module_collision(dna: Dictionary, point: Vector3, margin: float) -> bool:
	for module: Dictionary in dna.get("modules", []):
		var size := Graph.vec(module.get("scale", [0, 0, 0]))
		if point.distance_to(Graph.vec(module.position)) < maxf(size.x, size.y) * 0.70 + margin: return true
	return false

static func _close_sheet(mids: PackedVector3Array, thicknesses: PackedFloat32Array, columns: int, rows: int, outward: Vector3, ids: PackedStringArray, owner_a: int, owner_b: int, spec: Dictionary, root_influences: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var indices := PackedInt32Array()
	var colors := PackedColorArray(); var uvs := PackedVector2Array(); var uvs2 := PackedVector2Array()
	var ownership := PackedInt32Array(); var components := PackedInt32Array(); var weights := PackedFloat32Array(); var context := PackedFloat32Array()
	var band := float(spec.root_band)
	for y in range(rows + 1):
		var row_band := _curved_root_band(band, float(y) / rows)
		for x in range(columns + 1):
			var index := y * (columns + 1) + x
			var tangent := mids[y * (columns + 1) + mini(x + 1, columns)] - mids[y * (columns + 1) + maxi(x - 1, 0)]
			var vertical := mids[mini(y + 1, rows) * (columns + 1) + x] - mids[maxi(y - 1, 0) * (columns + 1) + x]
			var normal := tangent.cross(vertical).normalized()
			if normal.dot(outward) < 0.0: normal = -normal
			var u := float(x) / columns; var v := float(y) / rows
			var blend := smoothstep(row_band, 1.0 - row_band, u)
			var insertion := 1.0 - smoothstep(row_band, row_band + 0.16, minf(u, 1.0 - u))
			var left_index := y * (columns + 1) + floori(float(columns) * row_band)
			var right_index := y * (columns + 1) + ceili(float(columns) * (1.0 - row_band))
			var surface_influence: Dictionary = root_influences.get(index, {})
			if surface_influence.is_empty():
				var edge_blend := smoothstep(float(left_index % (columns + 1)) / columns, float(right_index % (columns + 1)) / columns, u)
				surface_influence = _blend_influences(root_influences[left_index], root_influences[right_index], edge_blend)
			for side: float in [1.0, -1.0]:
				vertices.append(mids[index] + normal * thicknesses[index] * side)
				normals.append(normal * side); colors.append(Color(5.0 / 7.0, 0.48, 0.0, 1.0))
				uvs.append(Vector2(u, v)); uvs2.append(Vector2(thicknesses[index], insertion))
				ownership.append(owner_a if blend < 0.5 else owner_b)
				# Buried root bands inherit the actual supporting triangle's
				# provenance; the exposed span blends the two support owners.
				components.append_array(surface_influence.owners)
				weights.append_array(surface_influence.weights)
				context.append_array(PackedFloat32Array([insertion, 0.62, 1.0 - insertion * 0.60, 0.14 + insertion * 0.72 + absf(v * 2.0 - 1.0) * 0.10]))
	var edges := {}
	for y in range(rows):
		for x in range(columns):
			var a := (y * (columns + 1) + x) * 2; var b := a + 2; var c := a + (columns + 1) * 2; var d := c + 2
			_front_triangle(indices, edges, vertices, a, b, c, outward)
			_front_triangle(indices, edges, vertices, b, d, c, outward)
	for edge: Dictionary in edges.values():
		if int(edge.count) != 1: continue
		var a := int(edge.a); var b := int(edge.b)
		indices.append_array(PackedInt32Array([b, a, a + 1, b, a + 1, b + 1]))
	# Recompute actual shell normals, including the nonuniform thin sidewalls.
	normals.fill(Vector3.ZERO)
	for i in range(0, indices.size(), 3):
		var a := indices[i]; var b := indices[i + 1]; var c := indices[i + 2]
		var n := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += n; normals[b] += n; normals[c] += n
	for i in range(normals.size()): normals[i] = normals[i].normalized()
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for point: Vector3 in vertices: bounds = bounds.expand(point)
	return {"name": "GrownBiologicalCovering", "role": "membrane", "covering_id": spec.id, "pipeline_stage": 3,
		"vertices": vertices, "normals": normals, "indices": indices, "colors": colors, "uvs": uvs, "uvs2": uvs2,
		"fibre_uv_mode": "authored", "authored_surface_context": context,
		"component_ids": ownership, "component_indices": components, "component_weights": weights, "node_ids": ids,
		"bounds": bounds, "stats": {"triangles": indices.size() / 3, "vertices": vertices.size(), "patches": 1, "rows": rows, "columns": columns}}

static func _blend_influences(first: Dictionary, second: Dictionary, blend: float) -> Dictionary:
	var combined := {}
	for slot in range(4):
		var a: int = first.owners[slot]; var b: int = second.owners[slot]
		combined[a] = float(combined.get(a, 0.0)) + float(first.weights[slot]) * (1.0 - blend)
		combined[b] = float(combined.get(b, 0.0)) + float(second.weights[slot]) * blend
	var ordered: Array = combined.keys()
	ordered.sort_custom(func(a: int, b: int) -> bool: return float(combined[a]) > float(combined[b]) if combined[a] != combined[b] else a < b)
	var result := {"owners": PackedInt32Array(), "weights": PackedFloat32Array()}; var total := 0.0
	for owner: int in ordered.slice(0, 4): total += float(combined[owner])
	for slot in range(4):
		result.owners.append(int(ordered[slot]) if slot < ordered.size() else 0)
		result.weights.append(float(combined[ordered[slot]]) / maxf(total, 0.000001) if slot < ordered.size() else 0.0)
	return result

static func _front_triangle(indices: PackedInt32Array, edges: Dictionary, vertices: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> void:
	if (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a]).dot(outward) < 0.0:
		var old := b; b = c; c = old
	indices.append_array(PackedInt32Array([a, b, c, a + 1, c + 1, b + 1]))
	for pair: Vector2i in [Vector2i(a, b), Vector2i(b, c), Vector2i(c, a)]:
		var key := Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))
		if not edges.has(key): edges[key] = {"a": pair.x, "b": pair.y, "count": 0}
		edges[key].count += 1

static func bind_roots(detail: Dictionary, skin: Dictionary, body: Dictionary, body_skin: Dictionary) -> Dictionary:
	# This is FINAL binding only. It never creates or changes geometry. Root
	# weights use the finalized support skin, including its influence reduction.
	# A differential-pose test measures interpolation error; this is not a claim
	# of exact equality to three separately skinned support vertices.
	if str(detail.get("covering_id", "")) != "primary_body.secondary_membrane.0": return {}
	var triangles: PackedInt32Array = body.get("indices", PackedInt32Array())
	var root_count := 0
	for sample: Dictionary in detail.get("attachment_samples", []):
		var offset := int(sample.get("triangle", -1)) * 3
		var first_vertex := int(sample.get("mid_index", -1)) * 2
		if offset < 0 or offset + 2 >= triangles.size() or first_vertex < 0 or (first_vertex + 2) * 4 > skin.weights.size():
			return {"error": "The membrane lost its retained support triangle before final binding.", "error_code": "invalid_membrane_binding"}
		var bary := Graph.vec(sample.get("barycentric"))
		var combined := {}
		for corner in range(3):
			var vertex := triangles[offset + corner]
			for slot in range(4):
				var index := vertex * 4 + slot
				if index >= body_skin.weights.size(): return {"error": "Membrane support has no finalized body weights.", "error_code": "invalid_membrane_binding"}
				var amount: float = body_skin.weights[index] * bary[corner]
				if amount <= 0.000001: continue
				var bone: int = body_skin.bones[index]
				combined[bone] = float(combined.get(bone, 0.0)) + amount
		var ordered: Array = combined.keys()
		ordered.sort_custom(func(a: int, b: int) -> bool: return float(combined[a]) > float(combined[b]) if combined[a] != combined[b] else a < b)
		if ordered.is_empty(): return {"error": "A membrane root has no final support influence.", "error_code": "invalid_membrane_binding"}
		var total := 0.0
		for bone: int in ordered.slice(0, 4): total += float(combined[bone])
		for vertex in [first_vertex, first_vertex + 1]:
			for slot in range(4):
				skin.bones[vertex * 4 + slot] = int(ordered[slot]) if slot < ordered.size() else 0
				skin.weights[vertex * 4 + slot] = float(combined[ordered[slot]]) / total if slot < ordered.size() else 0.0
			root_count += 1
	skin["membrane_root_binding"] = {"root_vertices": root_count, "source": "final_body_triangle_barycentric_weights", "pose_exactness": "measured_not_assumed"}
	return {}
