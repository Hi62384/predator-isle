extends RefCounted
## Descriptor-v2 only. A continuous shell with fitted foundation/contact
## bands, not a second collar mesh or a shading-normal approximation.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Legacy = preload("res://alien_foundry/scripts/geometry/BlobMembraneLegacySurface.gd")
const REVISION80_PATH := "surface_following_tangent_cuff_v2"
const PATH := "surface_following_tangent_cuff_v2_fixed_lattice"
const AUDIT_ROWS := 16
const AUDIT_DEPTH := 32
const MAX_CUFF_SPAN := 0.12

static func build_pair(dna: Dictionary, body: Dictionary, atlas: Dictionary, first: Dictionary, second: Dictionary, spec: Dictionary, placement: Dictionary) -> Dictionary:
	var normal: Vector3 = atlas.normal
	var a: Vector3 = placement.a; var b: Vector3 = placement.b
	var line := b - a; line -= normal * line.dot(normal)
	var span := line.length(); var across := line / span
	var along := normal.cross(across).normalized()
	if along.dot(Vector3.UP) < 0.0: along = -along
	var width := minf(Graph.surface_radius(Graph.vec(first.size), Graph.node_basis(first).inverse() * along), Graph.surface_radius(Graph.vec(second.size), Graph.node_basis(second).inverse() * along)) * float(spec.width_ratio)
	if width < span * 0.10 or width > span * 0.85: return {"reason": "unsuitable_span_width"}
	var ids: PackedStringArray = body.node_ids
	var owner_a := ids.find(str(first.id)); var owner_b := ids.find(str(second.id))
	if owner_a < 0 or owner_b < 0: return {"reason": "missing_extracted_owner"}
	var quality := clampi(int(dna.settings.quality), 0, 2)
	var fixed_lattice := str(spec.geometry_path) == PATH
	var columns: int = [24, 32, 40][quality]; var rows: int = [12, 16, 20][quality]
	var frame := {"a": a, "b": b, "normal": normal, "along": along, "span": span, "half_width": width,
		"owner_a": owner_a, "owner_b": owner_b, "spec": spec, "thickness": minf(span, width * 2.0) * float(spec.thickness_ratio)}
	var fitting := _fit_foundations(body, atlas, frame)
	if fitting.has("reason"): return fitting
	var parameters := PackedFloat32Array(); var halves := PackedFloat32Array(); var target_mids := PackedVector3Array()
	var row_data: Array = []; var hits: Array = []
	for y in range(rows + 1):
		var v := float(y) / rows
		var row := _row(atlas, frame, v)
		if row.is_empty(): return {"reason": "root_crosses_silhouette", "cuff_audit": fitting.audit}
		if Legacy._owner_weight(body, row.left, owner_a) < 0.30 or Legacy._owner_weight(body, row.right, owner_b) < 0.30:
			return {"reason": "root_not_owned_by_selected_support", "cuff_audit": fitting.audit}
		row["left_depth"] = _depth_at(fitting.left, v)
		row["right_depth"] = _depth_at(fitting.right, v)
		row["left_ring"] = ceili(columns * float(row.band))
		# Preserve frozen80's row-dependent construction for its saved path.
		# New plans keep contact and cuff roles in fixed columns across rows;
		# only their physical fitted depth varies with the anatomical curve.
		if fixed_lattice: row["left_ring"] = ceili(columns * (float(spec.root_band) + 0.045))
		row["right_ring"] = columns - int(row.left_ring)
		row["left_end"] = mini(columns / 2 - 1, maxi(int(row.left_ring) + 2, ceili(columns * (maxf(float(row.left_depth), float(row.right_depth)) + MAX_CUFF_SPAN))))
		if fixed_lattice: row["left_end"] = mini(columns / 2 - 1, maxi(int(row.left_ring) + 2, ceili(columns * (float(spec.root_band) + 0.045 + MAX_CUFF_SPAN))))
		row["right_end"] = columns - int(row.left_end)
		row_data.append(row)
		for x in range(columns + 1):
			var u := _parameter(x, columns, row)
			var center := _footprint(u, v, row, frame)
			var support := Legacy._hit(atlas, center)
			var half := _half(u, v, frame)
			parameters.append(u); halves.append(half); hits.append(support)
			var fraction := minf(u, 1.0 - u)
			if fraction <= float(row.band):
				if support.is_empty(): return {"reason": "root_has_no_broad_outward_tissue", "cuff_audit": fitting.audit}
				center = support.point - normal * half * 3.8
			else:
				var envelope := sin(PI * u)
				var transition := smoothstep(float(row.band), float(row.band) + 0.16, fraction)
				var height := center.dot(normal) + span * float(spec.lift_ratio) * 0.25 * envelope * (0.48 + 0.52 * sin(PI * v))
				height -= span * 0.025 * envelope * envelope * (0.25 + 0.75 * sin(PI * v))
				height += span * 0.025 * sin(u * PI * 2.0 + v * 2.1 + float(spec.phase)) * envelope * sin(PI * v)
				if not support.is_empty():
					var clearance := lerpf(-half * 3.8, half * 1.7, transition)
					height = maxf(height, float(support.height) + half * 2.4)
					height = lerpf(float(support.height) + clearance, height, transition)
				center += normal * (height - center.dot(normal))
			target_mids.append(center)
	if fixed_lattice and not _audit_output_footprints(body, atlas, frame, row_data, fitting.audit):
		return {"reason": "cuff_output_band_exceeds_fit_limits", "cuff_audit": fitting.audit}
	var fronts := PackedVector3Array(); var mids := PackedVector3Array()
	var influences := {}; var samples: Array = []; var root_vertices := PackedInt32Array(); var root_owners := PackedStringArray()
	var zones := PackedInt32Array(); var exposed := 0; var maximum_gap := 0.0
	for y in range(rows + 1):
		var row: Dictionary = row_data[y]; var v := float(y) / rows
		for x in range(columns + 1):
			var index := y * (columns + 1) + x; var u := float(parameters[index]); var half := float(halves[index])
			var tangent := _grid_normal(target_mids, columns, rows, x, y, normal)
			var target := target_mids[index] + tangent * half
			var is_left := x <= columns / 2
			var distance := u if is_left else 1.0 - u
			var depth := float(row.left_depth if is_left else row.right_depth)
			var ring := int(row.left_ring if is_left else row.right_ring)
			var foundation := x < ring if is_left else x > ring
			var contact := x == ring
			var in_cuff := x <= int(row.left_end) if is_left else x >= int(row.right_end)
			var support: Dictionary = hits[index]
			var front := target
			var zone := 0
			if foundation or contact:
				var owner := owner_a if is_left else owner_b
				if not _valid_support(body, support, owner, half, normal):
					return {"reason": "fitted_root_band_lost_support", "cuff_audit": fitting.audit}
				var burial := 2.8 * half * pow(maxf(0.0, 1.0 - distance / depth), 3.0)
				if fixed_lattice:
					# A constant anchor endpoint makes clearance monotonic even
					# while the independent tissue thickness varies along a row.
					var anchor_half := _half(0.0 if is_left else 1.0, v, frame)
					burial = 2.8 * anchor_half * _foundation_profile(distance / depth)
				front = support.point - normal * burial
				if contact: front = support.point
				zone = 2 if contact else 1
				influences[index] = Legacy._hit_influences(body, support)
				var host := str(first.id) if is_left else str(second.id)
				root_vertices.append(index * 2); root_vertices.append(index * 2 + 1)
				root_owners.append(host); root_owners.append(host)
				samples.append({"mid_index": index, "host_id": host, "triangle": support.triangle,
					"barycentric": Graph.arr(support.barycentric), "point": Graph.arr(support.point),
					"burial": burial, "half_thickness": half, "support_inside_depth": support.inside_depth,
					"owner_weight": Legacy._owner_weight(body, support, owner), "attachment_zone": "contact" if contact else "foundation"})
			elif in_cuff:
				var t := clampf((distance - depth) / MAX_CUFF_SPAN, 0.0, 1.0)
				var blend := t * t * t * (10.0 + t * (-15.0 + 6.0 * t))
				var footprint := _footprint(u, v, row, frame)
				var projection := footprint.lerp(target, blend)
				var fitted_hit := Legacy._hit(atlas, projection)
				if fitted_hit.is_empty(): return {"reason": "cuff_has_no_support_surface", "cuff_audit": fitting.audit}
				var gap := maxf(half * 0.25, target.dot(normal) - float(fitted_hit.height))
				front = fitted_hit.point + normal * gap * blend
				if t >= 0.999:
					if target.dot(normal) - float(fitted_hit.height) <= 0.0:
						return {"reason": "cuff_join_not_exposed", "cuff_audit": fitting.audit}
					front = target
				zone = 3
			if not foundation and not contact:
				if Legacy._module_collision(dna, front, half * 2.0): return {"reason": "covering_intersects_secondary_module", "cuff_audit": fitting.audit}
				var under := Legacy._hit(atlas, front)
				if under.is_empty(): exposed += 1
				else:
					var gap := front.dot(normal) - float(under.height)
					if gap > half: exposed += 1; maximum_gap = maxf(maximum_gap, gap)
			fronts.append(front); zones.append(zone)
	# Outer-surface-first: a midsurface normal extrusion must not move the
	# authored contact ring away from its actual support triangles.
	for y in range(rows + 1):
		for x in range(columns + 1):
			var index := y * (columns + 1) + x
			mids.append(fronts[index] - _grid_normal(fronts, columns, rows, x, y, normal) * halves[index])
	if exposed < rows * columns / 4 or maximum_gap < float(frame.thickness) * 3.0:
		return {"reason": "sheet_has_no_real_exposed_span", "cuff_audit": fitting.audit}
	var mesh := Legacy._close_sheet(mids, halves, columns, rows, normal, ids, owner_a, owner_b, spec, influences)
	for index in range(fronts.size()):
		mesh.vertices[index * 2] = fronts[index]
		mesh.vertices[index * 2 + 1] = mids[index] * 2.0 - fronts[index]
		var v := float(index / (columns + 1)) / rows
		var u := float(parameters[index]); var row: Dictionary = row_data[index / (columns + 1)]
		var depth := float(row.left_depth if u <= 0.5 else row.right_depth)
		var insertion := 1.0 - smoothstep(depth, depth + MAX_CUFF_SPAN, minf(u, 1.0 - u))
		for side in range(2):
			var vertex := index * 2 + side
			mesh.uvs[vertex] = Vector2(u, v)
			mesh.uvs2[vertex] = Vector2(halves[index], insertion)
			mesh.authored_surface_context[vertex * 4] = insertion
			mesh.authored_surface_context[vertex * 4 + 2] = 1.0 - insertion * 0.60
			mesh.authored_surface_context[vertex * 4 + 3] = 0.14 + insertion * 0.72 + absf(v * 2.0 - 1.0) * 0.10
	_recompute_geometry(mesh)
	mesh["geometry_path"] = str(spec.geometry_path); mesh["attachment_samples"] = samples
	mesh["root_vertex_indices"] = root_vertices; mesh["root_owner_ids"] = root_owners
	mesh["support_hosts"] = [str(first.id), str(second.id)]
	mesh["support_direction"] = Graph.arr(normal)
	mesh["cuff_vertex_zones"] = zones
	mesh["margin_profile"] = "concave_asymmetric_v1"
	mesh["root_band"] = spec.root_band
	mesh["cuff_fit"] = fitting.audit
	var physical := _foundation_clearance(mesh, atlas)
	if not bool(physical.valid): return {"reason": "cuff_foundation_clearance_failed", "cuff_audit": fitting.audit, "physical_audit": physical}
	mesh["cuff_clearance"] = physical
	mesh.stats["root_samples"] = samples.size()
	mesh.stats["minimum_root_burial"] = physical.minimum_foundation_burial
	mesh.stats["maximum_under_sheet_gap"] = maximum_gap
	var emergence := measure_emergence(mesh, atlas)
	mesh["cuff_emergence"] = emergence
	var targets := float(emergence.percentile95_angle_degrees) <= 20.0 and float(emergence.maximum_angle_degrees) <= 35.0 and int(emergence.unresolved_crossings) == 0
	return {"mesh": mesh, "report": {"status": "realized_geometry_candidate_unvalidated", "realized_count": 1,
		"host_ids": [str(first.id), str(second.id)], "direction": Graph.arr(normal), "span": span, "width": width * 2.0,
		"triangles": mesh.indices.size() / 3, "vertices": mesh.vertices.size(), "root_samples": samples.size(),
		"maximum_under_sheet_gap": maximum_gap, "minimum_root_burial": physical.minimum_foundation_burial,
		"cuff_fit": fitting.audit, "cuff_clearance": physical, "cuff_targets_met": targets, "emergence_audit": emergence,
		"support_source": "retained_extracted_triangles", "visual_validated": false, "new_bones": 0}}

static func _row(atlas: Dictionary, frame: Dictionary, v: float) -> Dictionary:
	var lateral := (v * 2.0 - 1.0) * float(frame.half_width)
	var left := Legacy._hit(atlas, frame.a + frame.along * lateral)
	var right := Legacy._hit(atlas, frame.b + frame.along * lateral)
	if left.is_empty() or right.is_empty(): return {}
	return {"left": left, "right": right, "lateral": lateral, "band": Legacy._curved_root_band(float(frame.spec.root_band), v)}

static func _footprint(u: float, v: float, row: Dictionary, frame: Dictionary) -> Vector3:
	var center: Vector3 = row.left.point.lerp(row.right.point, u)
	var envelope := sin(PI * u)
	var neck := smoothstep(float(row.band) + 0.025, 0.5, minf(u, 1.0 - u))
	var narrowing := (0.36 + 0.18 * v) * neck
	var edge_shape := sin(u * PI * 1.35 + float(frame.spec.phase)) * 0.055 + sin(u * PI * 2.7 + float(frame.spec.phase) * 0.7) * 0.025
	return center + Vector3(frame.along) * (float(row.lateral) * (envelope * edge_shape - narrowing) - float(frame.span) * float(frame.spec.sag_ratio) * envelope * (0.35 + 0.65 * sin(PI * v)))

static func _half(u: float, v: float, frame: Dictionary) -> float:
	var band := Legacy._curved_root_band(float(frame.spec.root_band), v)
	var insertion := 1.0 - smoothstep(band, band + 0.13, minf(u, 1.0 - u))
	return float(frame.thickness) * (0.48 + 0.52 * insertion + 0.18 * absf(v * 2.0 - 1.0)) * (0.92 + 0.08 * sin(u * 5.1 + v * 2.8 + float(frame.spec.phase)))

static func _foundation_profile(value: float) -> float:
	# Derivative is -30*t^2*(1-t)^2: nonpositive throughout [0,1],
	# with zero slope at both ends and no possible interior overshoot.
	var t := clampf(value, 0.0, 1.0)
	return clampf(1.0 - t * t * t * (10.0 + t * (-15.0 + 6.0 * t)), 0.0, 1.0)

static func _valid_support(body: Dictionary, hit: Dictionary, owner: int, half: float, normal: Vector3) -> bool:
	return not hit.is_empty() and hit.normal.dot(normal) >= 0.18 and Legacy._owner_weight(body, hit, owner) >= 0.15 and float(hit.inside_depth) >= half * 5.8

static func _valid_band(body: Dictionary, atlas: Dictionary, frame: Dictionary, row: Dictionary, v: float, depth: float, side: int) -> bool:
	var owner := int(frame.owner_a if side == 0 else frame.owner_b)
	for step in range(AUDIT_DEPTH + 1):
		var u := depth * float(step) / AUDIT_DEPTH
		if side == 1: u = 1.0 - u
		var hit := Legacy._hit(atlas, _footprint(u, v, row, frame))
		if not _valid_support(body, hit, owner, _half(u, v, frame), frame.normal): return false
	return true

static func _fit_foundations(body: Dictionary, atlas: Dictionary, frame: Dictionary) -> Dictionary:
	var depths := [PackedFloat32Array(), PackedFloat32Array()]
	var audit := {"maximum_span_displacement_ratio": 0.0, "maximum_band_depth_displacement_ratio": 0.0,
		"minimum_depth_ratio": 1.0, "minimum_area_ratio": 1.0, "minimum_width_ratio": 1.0,
		"audit_rows": AUDIT_ROWS, "audit_depth_samples": AUDIT_DEPTH, "minimum_owner_weight": 1.0,
		"bisection_steps": 6, "smoothing_passes": 2}
	for side in range(2):
		for y in range(AUDIT_ROWS + 1):
			var v := float(y) / AUDIT_ROWS; var row := _row(atlas, frame, v)
			if row.is_empty(): return {"reason": "root_crosses_silhouette", "cuff_audit": audit}
			var original := float(row.band); var fitted := original
			if not _valid_band(body, atlas, frame, row, v, original, side):
				var low := original * 0.85; var high := original
				if not _valid_band(body, atlas, frame, row, v, low, side):
					return {"reason": "cuff_fit_exceeds_band_limit", "cuff_audit": audit}
				for iteration in range(6):
					var middle := (low + high) * 0.5
					if _valid_band(body, atlas, frame, row, v, middle, side): low = middle
					else: high = middle
				fitted = low
			depths[side].append(fitted)
		for iteration in range(2):
			var smoothed: PackedFloat32Array = depths[side].duplicate()
			for y in range(1, AUDIT_ROWS):
				# Smooth fractional shrinkage, never expand back into invalid tissue.
				var a: float = depths[side][y - 1] / Legacy._curved_root_band(float(frame.spec.root_band), float(y - 1) / AUDIT_ROWS)
				var b: float = depths[side][y] / Legacy._curved_root_band(float(frame.spec.root_band), float(y) / AUDIT_ROWS)
				var c: float = depths[side][y + 1] / Legacy._curved_root_band(float(frame.spec.root_band), float(y + 1) / AUDIT_ROWS)
				smoothed[y] = minf(b, (a + b * 2.0 + c) * 0.25) * Legacy._curved_root_band(float(frame.spec.root_band), float(y) / AUDIT_ROWS)
			depths[side] = smoothed
		var before_grid := PackedVector3Array(); var after_grid := PackedVector3Array()
		for y in range(AUDIT_ROWS + 1):
			var v := float(y) / AUDIT_ROWS; var row := _row(atlas, frame, v)
			var depth := float(depths[side][y]); var original := float(row.band)
			if not _valid_band(body, atlas, frame, row, v, depth, side): return {"reason": "cuff_smoothed_band_lost_support", "cuff_audit": audit}
			audit.minimum_depth_ratio = minf(float(audit.minimum_depth_ratio), depth / original)
			var old_points := PackedVector3Array(); var new_points := PackedVector3Array(); var arc_length := 0.0
			for step in range(AUDIT_DEPTH + 1):
				var t := float(step) / AUDIT_DEPTH
				var before_u := original * t if side == 0 else 1.0 - original * t
				var after_u := depth * t if side == 0 else 1.0 - depth * t
				var old_hit := Legacy._hit(atlas, _footprint(before_u, v, row, frame))
				var new_hit := Legacy._hit(atlas, _footprint(after_u, v, row, frame))
				if old_hit.is_empty() or new_hit.is_empty(): return {"reason": "cuff_fit_missing_comparison_surface", "cuff_audit": audit}
				old_points.append(old_hit.point); new_points.append(new_hit.point)
				if step > 0: arc_length += old_points[step].distance_to(old_points[step - 1])
				audit.minimum_owner_weight = minf(float(audit.minimum_owner_weight), Legacy._owner_weight(body, new_hit, int(frame.owner_a if side == 0 else frame.owner_b)))
			for step in range(AUDIT_DEPTH + 1):
				var movement := old_points[step].distance_to(new_points[step])
				audit.maximum_span_displacement_ratio = maxf(float(audit.maximum_span_displacement_ratio), movement / float(frame.span))
				audit.maximum_band_depth_displacement_ratio = maxf(float(audit.maximum_band_depth_displacement_ratio), movement / maxf(arc_length, 0.000001))
			before_grid.append_array(old_points); after_grid.append_array(new_points)
		# The legacy transverse axis is forced upward and can reverse the
		# parameter-frame handedness. Reject folds relative to that actual
		# frame, rather than rejecting an otherwise coherent whole band.
		var audit_normal: Vector3 = Vector3(frame.normal) * signf((Vector3(frame.b) - Vector3(frame.a)).cross(Vector3(frame.along)).dot(Vector3(frame.normal)))
		var before_area := _projected_area(before_grid, audit_normal, side)
		var after_area := _projected_area(after_grid, audit_normal, side)
		if before_area <= 0.0 or after_area <= 0.0: return {"reason": "cuff_fit_folded_footprint", "cuff_audit": audit}
		audit.minimum_area_ratio = minf(float(audit.minimum_area_ratio), _surface_area(after_grid) / _surface_area(before_grid))
		for step in range(AUDIT_DEPTH + 1):
			var end := AUDIT_ROWS * (AUDIT_DEPTH + 1) + step
			var old_width := (before_grid[end] - before_grid[step]).dot(Vector3(frame.along))
			var new_width := (after_grid[end] - after_grid[step]).dot(Vector3(frame.along))
			if old_width <= 0.0 or new_width <= 0.0: return {"reason": "cuff_fit_folded_width", "cuff_audit": audit}
			audit.minimum_width_ratio = minf(float(audit.minimum_width_ratio), new_width / old_width)
	if float(audit.maximum_span_displacement_ratio) > 0.03 or float(audit.maximum_band_depth_displacement_ratio) > 0.15 or float(audit.minimum_area_ratio) < 0.85 or float(audit.minimum_depth_ratio) < 0.849999 or float(audit.minimum_width_ratio) < 0.90:
		return {"reason": "cuff_fit_exceeds_geometric_limits", "cuff_audit": audit}
	return {"left": depths[0], "right": depths[1], "audit": audit}

static func _projected_area(grid: PackedVector3Array, normal: Vector3, side: int, row_count: int = AUDIT_ROWS) -> float:
	var area := 0.0
	for y in range(row_count):
		for x in range(AUDIT_DEPTH):
			var a := grid[y * (AUDIT_DEPTH + 1) + x]; var b := grid[y * (AUDIT_DEPTH + 1) + x + 1]
			var c := grid[(y + 1) * (AUDIT_DEPTH + 1) + x]; var d := grid[(y + 1) * (AUDIT_DEPTH + 1) + x + 1]
			for value: float in [(b - a).cross(c - a).dot(normal), (d - b).cross(c - b).dot(normal)]:
				var signed := value if side == 0 else -value
				if signed <= 0.0: return -1.0
				area += signed * 0.5
	return area

static func _surface_area(grid: PackedVector3Array, row_count: int = AUDIT_ROWS) -> float:
	var area := 0.0
	for y in range(row_count):
		for x in range(AUDIT_DEPTH):
			var a := grid[y * (AUDIT_DEPTH + 1) + x]; var b := grid[y * (AUDIT_DEPTH + 1) + x + 1]
			var c := grid[(y + 1) * (AUDIT_DEPTH + 1) + x]; var d := grid[(y + 1) * (AUDIT_DEPTH + 1) + x + 1]
			area += ((b - a).cross(c - a).length() + (d - b).cross(c - b).length()) * 0.5
	return area

static func _audit_output_footprints(body: Dictionary, atlas: Dictionary, frame: Dictionary, rows: Array, audit: Dictionary) -> bool:
	# Controls fit the continuous band. Independently audit the actual output
	# rows as well, so interpolation cannot hide an over-limit outer corner.
	var count := rows.size() - 1
	var audit_normal: Vector3 = Vector3(frame.normal) * signf((Vector3(frame.b) - Vector3(frame.a)).cross(Vector3(frame.along)).dot(Vector3(frame.normal)))
	audit["actual_output_rows"] = count + 1
	for side in range(2):
		var before_grid := PackedVector3Array(); var after_grid := PackedVector3Array()
		for y in range(count + 1):
			var row: Dictionary = rows[y]; var v := float(y) / count
			var depth := float(row.left_depth if side == 0 else row.right_depth)
			var original := float(row.band); var owner := int(frame.owner_a if side == 0 else frame.owner_b)
			if not _valid_band(body, atlas, frame, row, v, depth, side): return false
			audit.minimum_depth_ratio = minf(float(audit.minimum_depth_ratio), depth / original)
			var before := PackedVector3Array(); var after := PackedVector3Array(); var arc := 0.0
			for step in range(AUDIT_DEPTH + 1):
				var t := float(step) / AUDIT_DEPTH
				var u0 := original * t if side == 0 else 1.0 - original * t
				var u1 := depth * t if side == 0 else 1.0 - depth * t
				var old_hit := Legacy._hit(atlas, _footprint(u0, v, row, frame))
				var new_hit := Legacy._hit(atlas, _footprint(u1, v, row, frame))
				if old_hit.is_empty() or new_hit.is_empty(): return false
				before.append(old_hit.point); after.append(new_hit.point)
				if step > 0: arc += before[step].distance_to(before[step - 1])
				audit.minimum_owner_weight = minf(float(audit.minimum_owner_weight), Legacy._owner_weight(body, new_hit, owner))
			for step in range(AUDIT_DEPTH + 1):
				var movement := before[step].distance_to(after[step])
				audit.maximum_span_displacement_ratio = maxf(float(audit.maximum_span_displacement_ratio), movement / float(frame.span))
				audit.maximum_band_depth_displacement_ratio = maxf(float(audit.maximum_band_depth_displacement_ratio), movement / maxf(arc, 0.000001))
			before_grid.append_array(before); after_grid.append_array(after)
		if _projected_area(before_grid, audit_normal, side, count) <= 0.0 or _projected_area(after_grid, audit_normal, side, count) <= 0.0: return false
		audit.minimum_area_ratio = minf(float(audit.minimum_area_ratio), _surface_area(after_grid, count) / _surface_area(before_grid, count))
		for step in range(AUDIT_DEPTH + 1):
			var end := count * (AUDIT_DEPTH + 1) + step
			var old_width := (before_grid[end] - before_grid[step]).dot(Vector3(frame.along))
			var new_width := (after_grid[end] - after_grid[step]).dot(Vector3(frame.along))
			if old_width <= 0.0 or new_width <= 0.0: return false
			audit.minimum_width_ratio = minf(float(audit.minimum_width_ratio), new_width / old_width)
	return float(audit.maximum_span_displacement_ratio) <= 0.03 and float(audit.maximum_band_depth_displacement_ratio) <= 0.15 and float(audit.minimum_area_ratio) >= 0.85 and float(audit.minimum_depth_ratio) >= 0.849999 and float(audit.minimum_width_ratio) >= 0.90

static func _depth_at(values: PackedFloat32Array, v: float) -> float:
	var p := v * AUDIT_ROWS; var first := mini(floori(p), AUDIT_ROWS - 1)
	return lerpf(values[first], values[first + 1], p - first)

static func _parameter(x: int, columns: int, row: Dictionary) -> float:
	var left := x <= columns / 2; var ix := x if left else columns - x
	var ring := int(row.left_ring); var end := int(row.left_end)
	var depth := float(row.left_depth if left else row.right_depth)
	var u := float(ix) / columns
	if ix <= ring: u = depth * float(ix) / ring
	elif ix <= end: u = depth + MAX_CUFF_SPAN * float(ix - ring) / (end - ring)
	return u if left else 1.0 - u

static func _grid_normal(points: PackedVector3Array, columns: int, rows: int, x: int, y: int, outward: Vector3) -> Vector3:
	var tangent := points[y * (columns + 1) + mini(x + 1, columns)] - points[y * (columns + 1) + maxi(x - 1, 0)]
	var vertical := points[mini(y + 1, rows) * (columns + 1) + x] - points[maxi(y - 1, 0) * (columns + 1) + x]
	var normal := tangent.cross(vertical).normalized()
	return normal if normal.dot(outward) >= 0.0 else -normal

static func _recompute_geometry(mesh: Dictionary) -> void:
	mesh.normals.fill(Vector3.ZERO)
	for i in range(0, mesh.indices.size(), 3):
		var a: int = mesh.indices[i]; var b: int = mesh.indices[i + 1]; var c: int = mesh.indices[i + 2]
		var normal: Vector3 = (mesh.vertices[c] - mesh.vertices[a]).cross(mesh.vertices[b] - mesh.vertices[a])
		mesh.normals[a] += normal; mesh.normals[b] += normal; mesh.normals[c] += normal
	for i in range(mesh.normals.size()): mesh.normals[i] = mesh.normals[i].normalized()
	mesh.bounds = AABB(mesh.vertices[0], Vector3.ZERO)
	for point: Vector3 in mesh.vertices: mesh.bounds = mesh.bounds.expand(point)

static func _foundation_clearance(mesh: Dictionary, atlas: Dictionary) -> Dictionary:
	var normal: Vector3 = atlas.normal
	var report := {"valid": true, "minimum_foundation_burial": INF, "maximum_contact_gap": 0.0, "foundation_samples": 0, "contact_samples": 0}
	for sample: Dictionary in mesh.attachment_samples:
		var index := int(sample.mid_index) * 2; var contact := str(sample.attachment_zone) == "contact"
		if contact: report.contact_samples += 1
		else: report.foundation_samples += 1
		for side in range(2):
			var point: Vector3 = mesh.vertices[index + side]; var hit := Legacy._hit(atlas, point)
			if hit.is_empty(): report.valid = false; continue
			var gap := (point - Vector3(hit.point)).dot(normal)
			if contact and side == 0:
				report.maximum_contact_gap = maxf(float(report.maximum_contact_gap), absf(gap))
				if absf(gap) > float(sample.half_thickness) * 0.10: report.valid = false
			elif gap >= 0.0: report.valid = false
			elif not contact: report.minimum_foundation_burial = minf(float(report.minimum_foundation_burial), -gap)
	return report

static func measure_emergence(mesh: Dictionary, atlas: Dictionary) -> Dictionary:
	var report := Legacy._measure_emergence(mesh, atlas)
	# Legacy stores at most96 diagnostic witnesses. Recompute all crossing
	# angles for the percentile; do not infer a full statistic from that sample.
	var vertices: PackedVector3Array = mesh.vertices; var indices: PackedInt32Array = mesh.indices
	var view_normal: Vector3 = atlas.normal; var angles: Array[float] = []
	var gaps := PackedFloat32Array(); gaps.resize(vertices.size())
	for i in range(0, vertices.size(), 2):
		var hit := Legacy._hit(atlas, vertices[i])
		gaps[i] = INF if hit.is_empty() else (vertices[i] - Vector3(hit.point)).dot(view_normal)
	for offset in range(0, int(mesh.stats.columns) * int(mesh.stats.rows) * 12, 6):
		var ia := indices[offset]; var ib := indices[offset + 1]; var ic := indices[offset + 2]
		var face := (vertices[ic] - vertices[ia]).cross(vertices[ib] - vertices[ia]).normalized()
		for edge: Vector2i in [Vector2i(ia, ib), Vector2i(ib, ic), Vector2i(ic, ia)]:
			if (gaps[edge.x] <= 0.0) == (gaps[edge.y] <= 0.0): continue
			var buried := vertices[edge.x] if gaps[edge.x] <= 0.0 else vertices[edge.y]
			var exposed := vertices[edge.y] if gaps[edge.x] <= 0.0 else vertices[edge.x]
			var support := {}
			for iteration in range(8):
				var point := buried.lerp(exposed, 0.5); var hit := Legacy._hit(atlas, point)
				if hit.is_empty(): exposed = point; continue
				support = hit
				if (point - Vector3(hit.point)).dot(view_normal) > 0.0: exposed = point
				else: buried = point
			if not support.is_empty(): angles.append(rad_to_deg(acos(clampf(absf(face.dot(support.normal)), 0.0, 1.0))))
	angles.sort()
	report["percentile95_angle_degrees"] = angles[mini(angles.size() - 1, ceili(angles.size() * 0.95) - 1)] if not angles.is_empty() else 90.0
	report["targets"] = {"percentile95_maximum": 20.0, "maximum": 35.0, "measurement": "all_geometric_front_crossings_including_corners"}
	return report
