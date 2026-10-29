class_name OrganicMembraneGeometry
extends RefCounted
## Paired-boundary fascia with explicit smooth pore loops and closed sidewalls.
## Coarse cell omission is never used to approximate a visible membrane opening.
static func build(strands: Array, quality: int, node_ids: PackedStringArray, job: RefCounted = null, sampling: Dictionary = {}) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
	var owners := PackedInt32Array()
	var component_indices := PackedInt32Array()
	var component_weights := PackedFloat32Array()
	var attachment_samples := PackedVector3Array()
	var support_strand_ids := PackedStringArray()
	var attachment_radii := PackedFloat32Array()
	var patches := 0
	var used: Dictionary = {}
	var rows: int = sampling.get("rows", [8, 12, 16][quality])
	var columns: int = sampling.get("columns", [4, 6, 8][quality])
	for si in range(strands.size()):
		var a: Dictionary = strands[si]
		var explicit_target := str(a.get("membrane_to", ""))
		if float(a.get("webbing", 0.0)) <= 0.0 and explicit_target.is_empty(): continue
		if str(a.get("profile", "")) == "fascia" and explicit_target.is_empty(): continue
		if job != null and job.is_cancelled(): return {"cancelled": true}
		var target := -1
		for sj in range(0 if not explicit_target.is_empty() else si + 1, strands.size()):
			if sj == si: continue
			var candidate: Dictionary = strands[sj]
			if (not explicit_target.is_empty() and str(candidate.id) == explicit_target) or (explicit_target.is_empty() and str(candidate.parent) == str(a.parent)):
				target = sj; break
		if target < 0: continue
		var b: Dictionary = strands[target]
		var key := Vector2i(mini(si, target), maxi(si, target))
		if used.has(key): continue
		used[key] = true
		var span := _sample(a.points, 0.5).distance_to(_sample(b.points, 0.5))
		if span < 0.025 or span > 1.0: continue
		var phase := float(int(a.node_index) % 13) * 0.47
		var start := clampf(float(a.get("web_start", 0.16)), 0.0, 0.9)
		var finish := clampf(float(a.get("web_end", 0.79)), start + 0.05, 1.0)
		var height_grid := _height_controls(a.get("web_height_grid", []))
		var bulge := clampf(float(a.get("web_bulge", 0.18)), 0.0, 0.6)
		var opening := clampf(float(a.get("web_opening", 0.20)), 0.0, 0.38) if span > 0.075 else 0.0
		var topology := _patch_topology(rows, columns, opening, phase)
		var parameters: PackedVector2Array = topology.parameters
		var faces: PackedInt32Array = topology.faces
		var grid := PackedVector3Array()
		var hints := PackedVector3Array()
		var thickness := clampf(span * 0.035, 0.0025, 0.009)
		var first_vertex := vertices.size()
		for parameter in parameters:
			var u := parameter.x; var v := parameter.y
			var t := lerpf(start, finish, v)
			var left := _sample(a.points, t)
			var right := _sample(b.points, t)
			var hint := (_sample(a.hints, t) + _sample(b.hints, t)).normalized()
			if hint.length_squared() < 0.1: hint = Vector3.FORWARD
			var sag := sin(u * PI) * sin(v * PI) * span * bulge * (0.90 + 0.10 * sin(t * 5.0 + phase))
			var fold := sin(u * PI * 3.0 + v * 2.0 + phase) * sin(u * PI) * sin(v * PI) * span * 0.018
			if not height_grid.is_empty():
				# Authored C1 tissue relief replaces the uniform fabric bulge.
				# Only the boundary rails follow the host; interiors bridge it.
				sag = span * _height_at(height_grid, u, v)
				fold = 0.0
			var point := left.lerp(right, u) + hint * (sag + fold)
			grid.append(point); hints.append(hint)
			for side in [1.0, -1.0]:
				vertices.append(point + hint * thickness * side)
				normals.append(hint * side)
				colors.append(Color(5.0 / 7.0, 0.45 + 0.12 * sin(v * 5.0 + phase), 0.0, 1.0))
				uvs.append(parameter); uvs2.append(Vector2.ZERO)
				owners.append(int(a.node_index) if u < 0.5 else int(b.node_index))
				component_indices.append_array(PackedInt32Array([int(a.node_index), int(b.node_index), int(a.node_index), int(b.node_index)]))
				component_weights.append_array(PackedFloat32Array([1.0 - u, u, 0.0, 0.0]))
			if u < 0.000001 or u > 0.999999:
				var support: Dictionary = a if u < 0.5 else b
				attachment_samples.append(point + hint * thickness)
				support_strand_ids.append(str(support.id))
				var radii: PackedFloat32Array = support.get("support_radii", support.radii)
				var f := t * float(radii.size() - 1)
				var ri := mini(floori(f), radii.size() - 2)
				var radius := lerpf(radii[ri], radii[ri + 1], f - ri)
				attachment_radii.append(radius if support.has("support_radii") else radius * float(support.width_ratio))
		var orientation := 0.0
		for i in range(0, faces.size(), 3):
			var aa := faces[i]; var bb := faces[i + 1]; var cc := faces[i + 2]
			orientation += (grid[bb] - grid[aa]).cross(grid[cc] - grid[aa]).dot(hints[aa])
		var flip := orientation > 0.0
		var edges: Dictionary = {}
		for i in range(0, faces.size(), 3):
			_front(indices, edges, first_vertex + faces[i] * 2, first_vertex + faces[i + 1] * 2, first_vertex + faces[i + 2] * 2, flip)
		for edge in edges.values():
			if int(edge.count) != 1: continue
			var aa := int(edge.a); var bb := int(edge.b)
			indices.append_array(PackedInt32Array([aa, aa + 1, bb, bb, aa + 1, bb + 1]))
		patches += 1
		if vertices.size() > 90000: return {"error": "Membrane detail exceeds its bounded vertex budget."}
	if vertices.is_empty(): return {}
	normals.fill(Vector3.ZERO)
	for i in range(0, indices.size(), 3):
		var a := indices[i]; var b := indices[i + 1]; var c := indices[i + 2]
		var normal := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		normals[a] += normal; normals[b] += normal; normals[c] += normal
	for i in range(normals.size()): normals[i] = normals[i].normalized()
	for _pass in range(20):
		var corrected := 0
		for i in range(0, indices.size(), 3):
			var a := indices[i]; var b := indices[i + 1]; var c := indices[i + 2]
			var normal := -(vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
			var alignment := (normals[a] + normals[b] + normals[c]).dot(normal) / 3.0
			if alignment < 0.025:
				var correction := normal * (0.035 - alignment) * 1.25
				normals[a] = (normals[a] + correction).normalized(); normals[b] = (normals[b] + correction).normalized(); normals[c] = (normals[c] + correction).normalized()
				corrected += 1
		if corrected == 0: break
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices: bounds = bounds.expand(vertex)
	return {"attachment_samples": attachment_samples, "support_strand_ids": support_strand_ids, "attachment_radii": attachment_radii, "name": "TissueMembranes", "role": "membrane", "vertices": vertices, "normals": normals, "indices": indices, "colors": colors, "uvs": uvs, "uvs2": uvs2, "component_ids": owners, "component_indices": component_indices, "component_weights": component_weights, "node_ids": node_ids, "bounds": bounds, "quality": quality, "stats": {"patches": patches, "rows": rows, "columns": columns, "vertices": vertices.size(), "triangles": indices.size() / 3}}

static func triangle_bound(rows: int, columns: int) -> int:
	var angular := 2 * (rows + columns)
	var bands := maxi(2, rows / 4)
	return maxi(4 * rows * columns + 4 * (rows + columns), 4 * angular * (bands + 1))

static func _patch_topology(rows: int, columns: int, opening: float, phase: float) -> Dictionary:
	var parameters := PackedVector2Array()
	var faces := PackedInt32Array()
	if opening <= 0.001:
		for y in range(rows + 1):
			for x in range(columns + 1): parameters.append(Vector2(float(x) / columns, float(y) / rows))
		for y in range(rows):
			for x in range(columns):
				var a := x + y * (columns + 1); var b := a + 1; var c := a + columns + 1; var d := c + 1
				faces.append_array(PackedInt32Array([a, b, c, b, d, c]))
	else:
		# The outer loop follows exact authored attachment boundaries. An
		# explicit smooth asymmetric inner loop creates the real pore rim.
		var boundary := PackedVector2Array()
		for x in range(columns): boundary.append(Vector2(float(x) / columns, 0.0))
		for y in range(rows): boundary.append(Vector2(1.0, float(y) / rows))
		for x in range(columns, 0, -1): boundary.append(Vector2(float(x) / columns, 1.0))
		for y in range(rows, 0, -1): boundary.append(Vector2(0.0, float(y) / rows))
		var center := Vector2(0.50 + 0.025 * sin(phase), 0.52 + 0.025 * cos(phase))
		var bands := maxi(2, rows / 4)
		for ring in range(bands + 1):
			var blend := float(ring) / float(bands)
			for outer in boundary:
				var delta := outer - center
				var angle := atan2(delta.y, delta.x)
				var q := Vector2(delta.x / opening, delta.y / (opening * 0.80))
				var radial := (1.0 + 0.10 * sin(angle * 3.0 + phase) + 0.055 * cos(angle * 5.0 - phase)) / q.length()
				var inner := center + delta * minf(radial, 0.80)
				parameters.append(inner.lerp(outer, blend))
		var count := boundary.size()
		for ring in range(bands):
			for k in range(count):
				var a := ring * count + k; var b := ring * count + (k + 1) % count
				var c := a + count; var d := b + count
				faces.append_array(PackedInt32Array([a, b, c, b, d, c]))
	return {"parameters": parameters, "faces": faces}

static func _sample(points: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var i := mini(floori(f), points.size() - 2)
	return points[i].lerp(points[i + 1], f - float(i))

static func _front(indices: PackedInt32Array, edges: Dictionary, a: int, b: int, c: int, flip: bool) -> void:
	if flip:
		var temp := b; b = c; c = temp
	indices.append_array(PackedInt32Array([a, b, c, a + 1, c + 1, b + 1]))
	for pair in [Vector2i(a, b), Vector2i(b, c), Vector2i(c, a)]:
		var key := Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))
		if edges.has(key): edges[key].count += 1
		else: edges[key] = {"a": pair.x, "b": pair.y, "count": 1}


static func _height_controls(source: Array) -> Array:
	if source.size() != 5: return []
	var result: Array = []
	for y in range(5):
		if not source[y] is Array or source[y].size() != 5: return []
		var row := PackedFloat32Array()
		for x in range(5):
			row.append(0.0 if x == 0 or y == 0 or x == 4 or y == 4 else clampf(float(source[y][x]), -0.25, 0.35))
		result.append(row)
	return result

static func _height_at(grid: Array, u: float, v: float) -> float:
	# Average two directional bicubics. Each uses fixed-data monotone
	# Hermite tangents on one axis and zero-knot-slope smoothstep on the
	# other. Unlike sequential data-dependent slope limiting, both share
	# first derivatives across every grid edge, and stay in cell extrema.
	var fx := clampf(u, 0.0, 1.0) * 4.0
	var fy := clampf(v, 0.0, 1.0) * 4.0
	var x := mini(floori(fx), 3); var y := mini(floori(fy), 3)
	var first_column := PackedFloat32Array()
	var second_column := PackedFloat32Array()
	for row: PackedFloat32Array in grid:
		first_column.append(row[x]); second_column.append(row[x + 1])
	var horizontal := lerpf(_cubic_height(grid[y], u), _cubic_height(grid[y + 1], u), smoothstep(0.0, 1.0, fy - y))
	var vertical := lerpf(_cubic_height(first_column, v), _cubic_height(second_column, v), smoothstep(0.0, 1.0, fx - x))
	return (horizontal + vertical) * 0.5

static func _cubic_height(values: PackedFloat32Array, t: float) -> float:
	var f := clampf(t, 0.0, 1.0) * 4.0
	var i := mini(floori(f), 3)
	var a := values[i]; var b := values[i + 1]
	var delta := b - a
	var left := values[i] - values[maxi(i - 1, 0)]
	var right := values[mini(i + 2, 4)] - values[i + 1]
	var m0 := 2.0 * left * delta / (left + delta) if left * delta > 0.0 else 0.0
	var m1 := 2.0 * delta * right / (delta + right) if delta * right > 0.0 else 0.0
	var x := f - float(i); var x2 := x * x; var x3 := x2 * x
	return (2.0*x3-3.0*x2+1.0)*a + (x3-2.0*x2+x)*m0 + (-2.0*x3+3.0*x2)*b + (x3-x2)*m1
