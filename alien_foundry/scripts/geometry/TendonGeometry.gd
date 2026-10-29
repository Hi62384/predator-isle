class_name OrganicTendonGeometry
extends RefCounted
## Secondary anatomical strands: capped, indexed and independently skinnable.
## These bridge genuine holes without expanding fine fibres to voxel diameter.
## Required end caps embed into primary tissue; declared digit/tendril tips stay free.
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Membranes = preload("res://alien_foundry/scripts/geometry/MembraneGeometry.gd")
const MATERIALS: Array[String] = ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]
const MAX_VERTICES := 180000

static func build(dna: Dictionary, quality: int, embed_endpoint: Callable, surface_sample: Callable, job: RefCounted = null, triangle_limit: int = 120000) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	var owners := PackedInt32Array()
	var component_indices := PackedInt32Array()
	var component_weights := PackedFloat32Array()
	var nodes: Array = dna.get("nodes", [])
	var embedded_endpoints := PackedVector3Array()
	var endpoint_radii := PackedFloat32Array()
	var cap_endpoints := PackedVector3Array()
	var cap_strand_ids := PackedStringArray()
	var cap_vertex_indices := PackedInt32Array()
	var cap_vertex_offsets := PackedInt32Array()
	var attachment_required := PackedByteArray()
	var attachment_strand_ids := PackedStringArray()
	var surface_attachment_samples := PackedVector3Array()
	var surface_attachment_ids := PackedStringArray()
	var strand_profiles := PackedStringArray()
	var strand_data: Array = []
	var strands := 0
	var endpoint_adjustments := 0
	var sampling := _budget_sampling(nodes, quality, triangle_limit)
	if sampling.has("error"): return sampling
	var sides: int = sampling.sides
	var divisions: int = sampling.divisions
	for ni in range(nodes.size()):
		var node: Dictionary = nodes[ni]
		if not _is_detail_curve(node):
			continue
		if job != null and job.is_cancelled():
			return {"cancelled": true}
		var sampled: Dictionary = Curves.sample(node, divisions)
		var points: PackedVector3Array = sampled.points
		var radii: PackedFloat32Array = sampled.radii
		if points.size() < 2:
			continue
		if vertices.size() + points.size() * sides + 2 > MAX_VERTICES:
			return {"error": "The anatomical strand layer exceeds its bounded vertex budget."}
		var shape: Dictionary = node.get("shape", {})
		var profile := str(shape.get("profile", "fascicle"))
		var direct_branch := profile in ["branch", "tendril"]
		var authored_profile := direct_branch or profile in ["muscle_belly", "fascia", "digit"]
		if authored_profile:
			radii = _authored_radii(node, points.size())
		var root_only := str(shape.get("attachment", "both")) == "root" and profile in ["digit", "tendril"]
		var phase := float((int(dna.get("seed", 1)) + ni * 137) % 6283) * 0.001
		var width_ratio := clampf(float(shape.get("width", 1.0 if profile == "digit" or direct_branch else (1.6 if profile == "muscle_belly" else 1.9 + 0.35 * sin(phase)))), 0.25, 4.0)
		var depth_ratio := clampf(float(shape.get("depth", 1.0 if profile == "digit" or direct_branch else (0.82 if profile == "muscle_belly" else 0.38 + 0.09 * cos(phase * 1.7)))), 0.10, 2.0)
		var ribbing := clampf(float(shape.get("ribbing", 0.28)), 0.0, 1.0)
		var follow := bool(shape.get("surface_follow", false))
		var outward_hints := PackedVector3Array()
		outward_hints.resize(points.size())
		for pi in range(points.size()):
			var sampled_surface: Dictionary = surface_sample.call(points[pi], radii[pi], follow and pi > 0 and pi < points.size() - 1, clampf(float(shape.get("surface_burial", 0.20)), 0.0, 1.5))
			points[pi] = sampled_surface.position
			outward_hints[pi] = sampled_surface.normal
		# Reprojection can inherit abrupt field-gradient changes at a fusion
		# seam. Smooth the centerline and orientation field, not the anatomy.
		for _pass in range(3 if follow or profile == "fascicle" else 0):
			var smooth_points := points.duplicate()
			var smooth_hints := outward_hints.duplicate()
			for pi in range(1, points.size() - 1):
				smooth_points[pi] = points[pi] * 0.60 + (points[pi - 1] + points[pi + 1]) * 0.20
				smooth_hints[pi] = (outward_hints[pi] * 0.50 + (outward_hints[pi - 1] + outward_hints[pi + 1]) * 0.25).normalized()
			points = smooth_points
			outward_hints = smooth_hints
		var first: Vector3 = embed_endpoint.call(points[0], radii[0] * width_ratio * _profile_value(shape.get("width_profile", []), 0.0))
		var last: Vector3 = points[-1] if root_only else embed_endpoint.call(points[-1], radii[-1] * width_ratio * _profile_value(shape.get("width_profile", []), 1.0))
		cap_endpoints.append_array(PackedVector3Array([first, last]))
		cap_strand_ids.append_array(PackedStringArray([str(node.get("id", "")), str(node.get("id", ""))]))
		attachment_required.append_array(PackedByteArray([1, 0 if root_only else 1]))
		strand_profiles.append(profile)
		embedded_endpoints.append(first)
		endpoint_radii.append(radii[0])
		attachment_strand_ids.append(str(node.get("id", "")))
		if not root_only:
			embedded_endpoints.append(last)
			endpoint_radii.append(radii[-1])
			attachment_strand_ids.append(str(node.get("id", "")))
		var first_delta := first - points[0]
		var last_delta := last - points[-1]
		if first_delta.length_squared() > 0.000001:
			endpoint_adjustments += 1
		if last_delta.length_squared() > 0.000001:
			endpoint_adjustments += 1
		for pi in range(points.size()):
			var t := float(pi) / float(points.size() - 1)
			points[pi] += first_delta * (1.0 - smoothstep(0.0, 0.22, t)) + last_delta * smoothstep(0.78, 1.0, t)
		if follow and profile == "fascia" and float(shape.get("surface_burial", 0.20)) >= 0.50:
			# Explicitly buried fascia boundaries must meet the final extracted
			# host all along their edges, not merely converge partway toward it.
			# Reuse the exact-tetrahedron embedding oracle after path smoothing.
			# The sheet interior is never projected into sparse underlying ribs.
			for pi in range(1, points.size() - 1):
				points[pi] = embed_endpoint.call(points[pi], radii[pi] * float(shape.get("surface_burial", 0.8)) / 0.75)
				var surface: Dictionary = surface_sample.call(points[pi], radii[pi], false, 0.20)
				outward_hints[pi] = surface.normal
			for point in points:
				surface_attachment_samples.append(point)
				surface_attachment_ids.append(str(node.get("id", "")))
		var material := maxi(MATERIALS.find(str(node.get("material", "muscle"))), 0)
		var first_vertex := vertices.size()
		var transported := Vector3.ZERO
		var length_along := 0.0
		var support_radii := PackedFloat32Array()
		for pi in range(points.size()):
			var tangent := (points[mini(pi + 1, points.size() - 1)] - points[maxi(pi - 1, 0)]).normalized()
			if tangent.length_squared() < 0.1:
				tangent = Vector3.UP
			if transported.length_squared() < 0.1:
				transported = tangent.cross(Vector3.FORWARD)
				if transported.length_squared() < 0.1:
					transported = tangent.cross(Vector3.RIGHT)
			transported = (transported - tangent * transported.dot(tangent)).normalized()
			if transported.length_squared() < 0.1:
				transported = tangent.cross(Vector3.RIGHT).normalized()
			var desired_width := outward_hints[pi].cross(tangent).normalized()
			if desired_width.length_squared() > 0.1:
				if desired_width.dot(transported) < 0.0:
					desired_width = -desired_width
				transported = (transported * 0.65 + desired_width * 0.35).normalized()
			var across := tangent.cross(transported).normalized()
			var t := float(pi) / float(points.size() - 1)
			var taper := 1.0 if authored_profile else 0.58 + 0.42 * pow(sin(t * PI), 0.45)
			var radius := radii[pi] * taper
			var width := width_ratio * _profile_value(shape.get("width_profile", []), t) * (1.0 if direct_branch else (1.0 + 0.035 * sin(t * PI * 3.0 + phase) if authored_profile else 0.78 + 0.28 * sin(t * PI) + 0.16 * sin(t * TAU * 2.3 + phase)))
			var depth := depth_ratio * _profile_value(shape.get("depth_profile", []), t) * (1.0 if authored_profile else 0.80 + 0.35 * sin(t * PI * 1.3 + phase * 0.3))
			support_radii.append(radius * maxf(width, depth) * 1.12)
			if pi > 0:
				length_along += points[pi].distance_to(points[pi - 1])
			var twist := (0.025 if profile == "digit" else (0.04 if direct_branch else 0.10)) * sin(t * TAU * 0.65 + phase)
			for si in range(sides):
				var angle := TAU * float(si) / float(sides) + twist
				var ripple := 1.0 + (ribbing * 0.06 if direct_branch else (0.025 if profile == "digit" else 0.11)) * sin(angle * 3.0 + t * 7.0 + phase)
				# Longitudinal fascicle grooves and asymmetric swollen lamellae.
				# Relief is actual geometry, not merely a painted normal texture.
				var transverse := cos(angle)
				var relief := 1.0 + ribbing * 0.20 * sin(transverse * PI * 2.0 + t * 2.5 + phase) * sin(angle) * sin(angle)
				var offset := (transported * transverse * width + across * sin(angle) * depth * relief) * radius * ripple
				vertices.append(points[pi] + offset)
				normals.append((transported * cos(angle) / width + across * sin(angle) / maxf(depth, 0.05)).normalized())
				colors.append(Color(float(material) / 7.0, clampf(0.48 + 0.14 * sin(t * 4.0 + phase), 0.0, 1.0), 0.0, 1.0))
				uvs.append(Vector2(float(si) / float(sides), length_along))
				uvs2.append(Vector2(float(material) / 7.0, 0.0))
				owners.append(ni)
				component_indices.append_array(PackedInt32Array([ni, ni, ni, ni]))
				component_weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			if pi > 0:
				for si in range(sides):
					var a := first_vertex + (pi - 1) * sides + si
					var b := first_vertex + (pi - 1) * sides + (si + 1) % sides
					var c := first_vertex + pi * sides + si
					var d := first_vertex + pi * sides + (si + 1) % sides
					# The ring parameterization has one consistent orientation.
					# Never infer individual face winding from averaged normals.
					indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
		for endpoint in range(2):
			var pi := 0 if endpoint == 0 else points.size() - 1
			var outward := (points[0] - points[1]).normalized() if endpoint == 0 else (points[-1] - points[-2]).normalized()
			var center := vertices.size()
			cap_vertex_offsets.append(cap_vertex_indices.size())
			cap_vertex_indices.append(center)
			vertices.append(points[pi])
			normals.append(outward)
			colors.append(colors[first_vertex])
			uvs.append(Vector2(0.5, float(endpoint)))
			uvs2.append(Vector2(float(material) / 7.0, 0.0))
			owners.append(ni)
			component_indices.append_array(PackedInt32Array([ni, ni, ni, ni]))
			component_weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			for si in range(sides):
				var a := first_vertex + pi * sides + si
				cap_vertex_indices.append(a)
				var b := first_vertex + pi * sides + (si + 1) % sides
				indices.append_array(PackedInt32Array([center, a, b] if endpoint == 0 else [center, b, a]))
		strand_data.append({"id": str(node.get("id", "")), "node_index": ni, "parent": str(node.get("parent", "")), "points": points, "hints": outward_hints, "radii": radii, "support_radii": support_radii, "width_ratio": width_ratio, "webbing": float(shape.get("webbing", 0.0)), "membrane_to": str(node.get("membrane_to", "")), "profile": profile, "web_height_grid": shape.get("web_height_grid", []), "web_bulge": float(shape.get("web_bulge", 0.18)), "web_opening": float(shape.get("web_opening", 0.20)), "web_start": float(shape.get("web_start", 0.16)), "web_end": float(shape.get("web_end", 0.79))})
		strands += 1
	cap_vertex_offsets.append(cap_vertex_indices.size())
	if vertices.is_empty():
		return {}
	# Smooth normals derived from the actual variable-radius curved sweep.
	normals.fill(Vector3.ZERO)
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		var normal := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	# At strongly curved fascicles and buried caps, a narrow face can have
	# its averaged tangent normal overwhelmed by a much larger neighbor.
	# Correct only inconsistent shading hemispheres; preserve tube winding.
	for _pass in range(10):
		var corrected := 0
		for i in range(0, indices.size(), 3):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			var outward := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
			var alignment := (normals[a] + normals[b] + normals[c]).dot(outward) / 3.0
			if alignment < 0.025:
				var correction := outward * (0.035 - alignment) * 1.25
				normals[a] = (normals[a] + correction).normalized()
				normals[b] = (normals[b] + correction).normalized()
				normals[c] = (normals[c] + correction).normalized()
				corrected += 1
		if corrected == 0:
			break
	var node_ids := PackedStringArray()
	for node in nodes:
		node_ids.append(str(node.get("id", "")))
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		bounds = bounds.expand(vertex)
	var membrane_layer: Dictionary = Membranes.build(strand_data, quality, node_ids, job, sampling)
	if membrane_layer.has("error") or membrane_layer.get("cancelled", false): return membrane_layer
	var membrane_triangles := int(membrane_layer.get("indices", PackedInt32Array()).size() / 3)
	if indices.size() / 3 + membrane_triangles > triangle_limit:
		return {"error": "The complete tendon and membrane layer exceeds its enforced %s-triangle budget." % triangle_limit, "budget_exceeded": true}
	return {"surface_attachment_samples": surface_attachment_samples, "surface_attachment_ids": surface_attachment_ids, "membrane_mesh": membrane_layer, "name": "TendonBundles", "role": "tendon", "embedded_endpoints": embedded_endpoints, "endpoint_radii": endpoint_radii, "cap_endpoints": cap_endpoints, "cap_strand_ids": cap_strand_ids, "cap_vertex_indices": cap_vertex_indices, "cap_vertex_offsets": cap_vertex_offsets, "attachment_required": attachment_required, "attachment_strand_ids": attachment_strand_ids, "strand_profiles": strand_profiles, "vertices": vertices, "normals": normals, "indices": indices, "colors": colors, "uvs": uvs, "uvs2": uvs2, "component_ids": owners, "component_indices": component_indices, "component_weights": component_weights, "node_ids": node_ids, "bounds": bounds, "quality": quality, "stats": {"strands": strands, "attachment_count": embedded_endpoints.size(), "endpoint_adjustments": endpoint_adjustments, "ring_sides": sides, "curve_divisions": divisions, "budget_adaptations": sampling.adaptations, "vertices": vertices.size(), "triangles": indices.size() / 3}}


static func _budget_sampling(nodes: Array, quality: int, triangle_limit: int) -> Dictionary:
	var segments := 0
	var strand_count := 0
	var possible_patches := 0
	var has_height_grid := false
	for node in nodes:
		if not _is_detail_curve(node): continue
		var count: int = node.get("points", []).size()
		if count < 2: continue
		has_height_grid = has_height_grid or not node.get("shape", {}).get("web_height_grid", []).is_empty()
		segments += count - 1
		strand_count += 1
		if float(node.get("shape", {}).get("webbing", 0.0)) > 0.0 or not str(node.get("membrane_to", "")).is_empty():
			possible_patches += 1
	var sides: int = [10, 16, 22][quality]
	var divisions: int = [4, 7, 10][quality]
	var rows: int = [8, 12, 16][quality]
	var columns: int = [8, 10, 12][quality] if has_height_grid else [4, 6, 8][quality]
	var minimum_columns := 8 if has_height_grid else 4
	var minimum_rows := 8 if has_height_grid else 6
	var adaptations: Array[String] = []
	for attempt in range(24):
		# Exact tube count plus a conservative closed-sheet/pore-wall bound.
		var estimate := 2 * sides * (segments * divisions + strand_count) + possible_patches * Membranes.triangle_bound(rows, columns)
		if estimate <= triangle_limit:
			if attempt > 0:
				adaptations.append("Anatomical detail tessellation adapted to %s ring sides, %s curve divisions and %sx%s membrane cells for the %s-triangle cap." % [sides, divisions, rows, columns, triangle_limit])
			return {"sides": sides, "divisions": divisions, "rows": rows, "columns": columns, "adaptations": adaptations}
		if sides <= 8 and divisions <= 2 and rows <= minimum_rows and columns <= minimum_columns:
			return {"error": "All anatomical strands and membrane patches cannot fit the requested %s-triangle budget at minimum safe tessellation." % triangle_limit, "budget_exceeded": true}
		var ratio := sqrt(float(maxi(triangle_limit, 1)) / float(estimate)) * 0.98
		sides = maxi(8, mini(sides - 2, floori(float(sides) * ratio / 2.0) * 2))
		divisions = maxi(2, mini(divisions - 1, floori(float(divisions) * ratio)))
		rows = maxi(minimum_rows, mini(rows - 2, floori(float(rows) * ratio / 2.0) * 2))
		columns = maxi(minimum_columns, mini(columns - 2, floori(float(columns) * ratio / 2.0) * 2))
	return {"error": "Detail sampling budget did not converge.", "budget_exceeded": true}

static func _is_detail_curve(node: Dictionary) -> bool:
	return str(node.get("kind", "")) == "curve" and (str(node.get("role", "")) == "tendon" or str(node.get("shape", {}).get("geometry", "")) == "detail")

static func _profile_value(values: Array, t: float) -> float:
	return Curves.profile_value(values, t)


static func _authored_radii(node: Dictionary, sample_count: int) -> PackedFloat32Array:
	return Curves.smooth_radii(node, sample_count)
