extends RefCounted
## New fully supported cartilage layer. The scalar is evaluated directly at
## world positions against retained triangles. No extracted vertex is fitted,
## sheared, relaxed, or moved. A rigid orthonormal frame only addresses the grid.
const Plan = preload("res://alien_foundry/scripts/anatomy/BlobPorousCartilage.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Support = preload("res://alien_foundry/scripts/geometry/BlobMembraneSurface.gd")
const Profile = preload("res://alien_foundry/scripts/geometry/BlobLocalLatticeSurface.gd")
const Extractor = preload("res://alien_foundry/scripts/geometry/CartilageSparseTetrahedra.gd")
const MAX_SAMPLES := 300000
const MAX_TRIANGLES := 30000
const MAX_CELLS := 300000
const CORNERS := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]

static func has_plan(dna: Dictionary) -> bool:
	for node: Dictionary in dna.get("nodes", []):
		if node.has(Plan.SPEC_KEY): return true
	return false

static func _error(message: String) -> Dictionary:
	return {"error": message, "error_code": "invalid_porous_cartilage_plan"}

static func validate_spec(spec: Dictionary, host: Dictionary, dna: Dictionary) -> Dictionary:
	if str(dna.get("type", "")) != "Blob" or str(host.get("kind", "")) != "mass": return _error("Cartilage requires a retained Blob mass host.")
	# One bounded design, not a parameter search. Exact versioned geometry data
	# is validated against the authoring contract; JSON integers/floats compare.
	var copy := dna.duplicate(true)
	for node: Dictionary in copy.get("nodes", []): node.erase(Plan.SPEC_KEY)
	var installed := Plan.install(copy, str(host.get("id", "")))
	if installed.has("error"): return installed
	for node: Dictionary in copy.nodes:
		if node.has(Plan.SPEC_KEY):
			if node[Plan.SPEC_KEY] != spec: return _error("Unsupported or altered porous-cartilage v1 descriptor.")
	return {}

static func append_geometry(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null) -> Dictionary:
	var host := {}; var spec := {}
	for node: Dictionary in dna.get("nodes", []):
		if not node.has(Plan.SPEC_KEY): continue
		if not spec.is_empty() or not node[Plan.SPEC_KEY] is Dictionary: return _error("Exactly one cartilage descriptor is supported.")
		host = node; spec = node[Plan.SPEC_KEY]
	if spec.is_empty(): return {}
	var valid := validate_spec(spec, host, dna)
	if valid.has("error"): return valid
	if geometry.get("stats", {}).has(Plan.SPEC_KEY): return {}
	var result := build(dna, geometry, host, spec, controls)
	if result.has("error") or bool(result.get("cancelled", false)): return result
	var report: Dictionary = result.get("report", {})
	if result.has("mesh") and str(report.get("status", "")) == "realized_pending_visual_review":
		var details: Array = geometry.get("detail_meshes", []).duplicate()
		var count := 0
		for detail: Dictionary in details: count += detail.indices.size() / 3
		var limit := mini(int(dna.budget.get("max_detail_triangles", 35000)), int(geometry.stats.get("max_detail_triangles", 35000)))
		if count + int(result.mesh.stats.triangles) > limit:
			report.status = "rejected_detail_budget"; report.realized_count = 0
		else:
			details.append(result.mesh); geometry["detail_meshes"] = details
			geometry.bounds = geometry.bounds.merge(result.mesh.bounds)
			geometry.stats["detail_triangles"] = count + int(result.mesh.stats.triangles)
			geometry.stats["generated_triangles"] = geometry.indices.size() / 3 + int(geometry.stats.detail_triangles)
	geometry.stats[Plan.SPEC_KEY] = report
	return {}

static func build(dna: Dictionary, body: Dictionary, host: Dictionary, spec: Dictionary, controls: RefCounted = null) -> Dictionary:
	var started := Time.get_ticks_usec()
	var report := {"version": 1, "geometry_path": Plan.GEOMETRY_PATH, "pipeline_stage": 2, "realized_count": 0,
		"status": "pending", "primary_mesh_mutated": false, "welded_to_primary": false, "visual_validated": false,
		"new_bones": 0, "expected_openings": 4, "expected_euler": -6, "placement_attempts": 1, "support_source": "retained_body_triangles",
		"suspended_bridge": false, "post_extraction_warp": false, "max_samples": MAX_SAMPLES, "max_triangles": MAX_TRIANGLES}
	var body_step := float(body.get("stats", {}).get("cell_size", 0.0))
	if body_step <= 0.0 or body.get("vertices", PackedVector3Array()).is_empty(): return _error("Cartilage requires retained primary triangles and sampling scale.")
	var scale := minf(Graph.vec(host.size).x, Graph.vec(host.size).y) * float(spec.scale_ratio)
	var step := body_step / float(spec.refinement)
	var atlas := Support._project_triangles(body, Graph.vec(spec.direction).normalized())
	var origin := Graph.vec(host.position) + Vector3(atlas.x) * scale * float(spec.center_offset[0]) + Vector3(atlas.y) * scale * float(spec.center_offset[1])
	var basis := Basis(Vector3(atlas.x), Vector3(atlas.y), Vector3(atlas.normal))
	var contour := Profile._contour(spec.outer)
	var enclosure := _opening_enclosure(spec, contour)
	report["opening_enclosure"] = enclosure
	if not bool(enclosure.valid): report.status = "rejected_opening_enclosure"; return {"report": report}
	var preflight := _support_preflight(atlas, origin, basis, scale, contour, controls)
	if bool(preflight.get("cancelled", false)): return preflight
	report["fixed_region_support"] = preflight
	if not bool(preflight.qualified): report.status = "rejected_fixed_region_support"; return {"report": report}
	# All tissue lies within this finite distance of the retained surface.
	var reach := scale * (2.0 * float(spec.round_radius) + float(spec.root_burial_ratio)) + 3.0 * step
	var index := _support_index(body, atlas, origin, basis, scale, contour, reach, step, controls)
	if bool(index.get("cancelled", false)): return index
	if index.has("error"): report.status = str(index.error); return {"report": report}
	report.merge({"support_triangles": index.triangles.size(), "support_bins": index.bins.size(), "index_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"body_cell_size": body_step, "cell_size": step, "refinement": body_step / step, "scale": scale})
	var sparse := _sparse_domain(index, scale, contour, step, reach, controls)
	if bool(sparse.get("cancelled", false)): return sparse
	report.merge(sparse.get("report", {}))
	if not sparse.has("values"): report.status = "rejected_sample_budget"; return {"report": report}
	var values: Dictionary = sparse.values
	var field_start := Time.get_ticks_usec()
	var count := 0; var missing := 0; var max_queries := 0
	for coord: Vector3i in values:
		if count % 1024 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		count += 1
		var grid_point := Vector3(coord) * step
		var hit := _closest(index, grid_point)
		max_queries = maxi(max_queries, int(hit.get("tested", 0)))
		if hit.is_empty() or not hit.has("point"):
			values[coord] = reach; missing += 1; continue
		# Position and closest witness are rigid transforms of actual world data.
		# The scalar distance is Euclidean distance with oriented host sign.
		var delta: Vector3 = grid_point - Vector3(hit.point)
		var signed_distance := delta.length() * (-1.0 if delta.dot(Vector3(hit.normal)) < 0.0 else 1.0)
		var uv := Vector2(grid_point.x, grid_point.y) / scale
		var outer := Profile._polygon_distance(uv, contour)
		var planar := outer
		for hole: Dictionary in spec.holes: planar = maxf(planar, -Profile._hole_distance(uv, hole))
		var root := 1.0 - smoothstep(0.04, float(spec.root_band_width), -outer)
		var radius := float(spec.round_radius) * scale * (0.94 + 0.06 * sin(uv.x * 3.7 + uv.y * 2.1))
		var offset := lerpf(float(spec.interior_offset) * scale, -radius - float(spec.root_burial_ratio) * scale, root)
		values[coord] = Vector2(maxf(planar * scale + radius, 0.0), signed_distance - offset).length() - radius
	report.merge({"field_ms": (Time.get_ticks_usec() - field_start) / 1000.0, "unsupported_positive_samples": missing,
		"maximum_triangles_tested_per_sample": max_queries, "field_coordinates": "world_space_retained_triangle_signed_distance"})
	var extract_start := Time.get_ticks_usec()
	var mesh := Extractor.extract(values, sparse.cells, Vector3.ZERO, step, controls)
	values.clear(); sparse.clear()
	if bool(mesh.get("cancelled", false)): return mesh
	report["extract_ms"] = (Time.get_ticks_usec() - extract_start) / 1000.0
	report["missing_extraction_samples"] = mesh.get("missing_samples", 0)
	report["zero_area_skipped"] = mesh.get("zero_area_skipped", 0)
	if mesh.get("vertices", PackedVector3Array()).is_empty(): report.status = "rejected_empty_surface"; return {"report": report}
	# Only a rigid change of basis. There is deliberately no support fitting.
	for i in range(mesh.vertices.size()):
		mesh.vertices[i] = origin + basis * Vector3(mesh.vertices[i])
		mesh.normals[i] = basis * Vector3(mesh.normals[i])
	var topology := Profile.topology_audit(mesh)
	var normals := normal_audit(mesh)
	var triangles: int = mesh.indices.size() / 3
	report.merge({"triangles": triangles, "vertices": mesh.vertices.size(), "topology": topology, "normal_audit": normals,
		"production_cap_exceeded_by": maxi(triangles - MAX_TRIANGLES, 0)})
	if int(topology.components) != 1 or int(topology.bad_edges) != 0 or int(mesh.get("missing_samples", 0)) != 0 or int(normals.nonfinite) > 0 or int(normals.zero_area) > 0:
		report.status = "rejected_unsafe_surface"; return {"report": report}
	var decorated := _decorate(body, mesh, index, atlas, origin, basis, scale, step, spec, contour, controls)
	if bool(decorated.get("cancelled", false)): return decorated
	if decorated.has("error"):
		report.status = str(decorated.error); return {"report": report}
	report.merge(decorated.report)
	mesh = decorated.mesh
	mesh.stats["grid_samples"] = int(report.grid_samples)
	var failures: Array = []
	if triangles > MAX_TRIANGLES: failures.append("triangle_budget")
	if int(topology.euler) != -6: failures.append("opening_topology")
	if int(normals.reversed_normals) != 0: failures.append("normal_disagreements")
	if not bool(report.root_band_fully_buried): failures.append("exposed_outer_root")
	report["acceptance_failures"] = failures
	report["geometry_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	if not failures.is_empty():
		report.status = "rejected_" + str(failures[0])
		# Not appendable production geometry. QA can inspect this finite, closed
		# raw candidate with an explicit NOT ACCEPTED label, without cap changes.
		return {"diagnostic_mesh": mesh, "report": report}
	report.status = "realized_pending_visual_review"; report.realized_count = 1
	return {"mesh": mesh, "report": report}

static func _opening_enclosure(spec: Dictionary, contour: PackedVector2Array) -> Dictionary:
	var margin := INF
	for hi in range(spec.holes.size()):
		var hole: Dictionary = spec.holes[hi]
		for j in range(128):
			var angle := TAU * float(j) / 128.0
			var r := 1.0 + 0.065 * sin(angle * 3.0 + float(hole.phase)) + 0.035 * cos(angle * 2.0 - float(hole.phase))
			var p := (Vector2(cos(angle) * float(hole.radii[0]), sin(angle) * float(hole.radii[1])) * r).rotated(float(hole.angle)) + Vector2(float(hole.center[0]), float(hole.center[1]))
			margin = minf(margin, -Profile._polygon_distance(p, contour))
			for other in range(spec.holes.size()):
				if other != hi: margin = minf(margin, Profile._hole_distance(p, spec.holes[other]))
	return {"valid": margin > 0.045, "minimum_dimensionless_clearance": margin, "samples_per_opening": 128, "opening_count": 4}

static func _support_preflight(atlas: Dictionary, origin: Vector3, basis: Basis, scale: float, contour: PackedVector2Array, controls: RefCounted) -> Dictionary:
	var queries := 0; var missing := 0; var facing := 1.0
	for y in range(-24, 25):
		if controls != null and controls.is_cancelled(): return {"cancelled": true}
		for x in range(-25, 26):
			var uv := Vector2(x, y) * 0.04
			if Profile._polygon_distance(uv, contour) > 0.02: continue
			var hit := Support._hit(atlas, origin + basis * Vector3(uv.x * scale, uv.y * scale, 0.0))
			queries += 1
			if hit.is_empty(): missing += 1; continue
			facing = minf(facing, Vector3(hit.normal).dot(Vector3(atlas.normal)))
	return {"qualified": missing == 0 and facing > 0.08, "queries": queries, "missing": missing, "minimum_support_facing": facing,
		"placement_search": false, "required_cleft": false}

static func _support_index(body: Dictionary, atlas: Dictionary, origin: Vector3, basis: Basis, scale: float, contour: PackedVector2Array, reach: float, step: float, controls: RefCounted) -> Dictionary:
	var triangles: Array = []; var bins := {}; var bin_step := maxf(float(body.stats.cell_size) * 1.25, step * 3.0)
	var inverse := basis.transposed()
	for offset in range(0, body.indices.size(), 3):
		if offset % 3072 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		var ids := Vector3i(body.indices[offset], body.indices[offset + 1], body.indices[offset + 2])
		var a: Vector3 = inverse * (Vector3(body.vertices[ids.x]) - origin)
		var b: Vector3 = inverse * (Vector3(body.vertices[ids.y]) - origin)
		var c: Vector3 = inverse * (Vector3(body.vertices[ids.z]) - origin)
		var center := (a + b + c) / 3.0
		if Profile._polygon_distance(Vector2(center.x, center.y) / scale, contour) > reach / scale + 0.10: continue
		var n := (c - a).cross(b - a).normalized()
		if n.z < 0.05: continue
		var visible := Support._hit(atlas, origin + basis * center)
		if visible.is_empty() or Vector3(visible.point).distance_to(origin + basis * center) > float(body.stats.cell_size) * 0.25: continue
		var low := a.min(b).min(c); var high := a.max(b).max(c)
		var tri := {"a": a, "b": b, "c": c, "normal": n, "indices": ids, "triangle": offset / 3, "low": low, "high": high}
		var ti := triangles.size(); triangles.append(tri)
		var first := Vector3i(((low - Vector3.ONE * reach) / bin_step).floor())
		var last := Vector3i(((high + Vector3.ONE * reach) / bin_step).floor())
		for z in range(first.z, last.z + 1):
			for y in range(first.y, last.y + 1):
				for x in range(first.x, last.x + 1):
					var key := Vector3i(x,y,z)
					if not bins.has(key): bins[key] = PackedInt32Array()
					bins[key].append(ti)
	if triangles.is_empty(): return {"error": "rejected_empty_support_index"}
	return {"triangles": triangles, "bins": bins, "bin_step": bin_step, "reach": reach}

static func _sparse_domain(index: Dictionary, scale: float, contour: PackedVector2Array, step: float, reach: float, controls: RefCounted) -> Dictionary:
	var cells := {}; var values := {}; var ti := 0
	for tri: Dictionary in index.triangles:
		ti += 1
		if ti % 64 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		# Conservative near-triangle regular-grid band, not a warped chart grid.
		var first := Vector3i(((Vector3(tri.low) - Vector3.ONE * reach) / step).floor())
		var last := Vector3i(((Vector3(tri.high) + Vector3.ONE * reach) / step).ceil())
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var uv := Vector2(x + 0.5, y + 0.5) * step / scale
				if Profile._polygon_distance(uv, contour) > 2.0 * step / scale: continue
				for z in range(first.z, last.z + 1):
					var cell := Vector3i(x,y,z)
					if cells.has(cell): continue
					var center := (Vector3(cell) + Vector3.ONE * 0.5) * step
					var closest := _triangle_point(center, tri.a, tri.b, tri.c)
					if center.distance_squared_to(closest.point) > pow(reach - step, 2.0): continue
					cells[cell] = true
					for corner: Vector3i in CORNERS: values[cell + corner] = 0.0
					if values.size() > MAX_SAMPLES or cells.size() > MAX_CELLS:
						return {"report": {"grid_samples": values.size(), "sparse_cells": cells.size(), "max_samples": MAX_SAMPLES}}
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.z < b.z if a.z != b.z else (a.y < b.y if a.y != b.y else a.x < b.x))
	return {"values": values, "cells": ordered, "report": {"grid_samples": values.size(), "sparse_cells": cells.size(), "sampling": "sparse_regular_world_grid"}}

static func _closest(index: Dictionary, p: Vector3) -> Dictionary:
	var cell := Vector3i((p / float(index.bin_step)).floor())
	var found := {}; var distance := INF; var tested := 0
	for ti: int in index.bins.get(cell, PackedInt32Array()):
		var tri: Dictionary = index.triangles[ti]
		var clamp_point := p.clamp(Vector3(tri.low), Vector3(tri.high))
		if p.distance_squared_to(clamp_point) > distance: continue
		var result := _triangle_point(p, tri.a, tri.b, tri.c)
		tested += 1
		var d := p.distance_squared_to(Vector3(result.point))
		if d >= distance: continue
		distance = d
		found = {"point": result.point, "barycentric": result.barycentric, "normal": tri.normal, "triangle": tri.triangle, "indices": tri.indices}
	if not found.is_empty(): found["tested"] = tested
	return found

static func _triangle_point(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	# Closest point with exact barycentric witness (Ericson region tests).
	var ab := b-a; var ac := c-a; var ap := p-a
	var d1 := ab.dot(ap); var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0: return {"point": a, "barycentric": Vector3(1,0,0)}
	var bp := p-b; var d3 := ab.dot(bp); var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3: return {"point": b, "barycentric": Vector3(0,1,0)}
	var vc := d1*d4-d3*d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v := d1/(d1-d3); return {"point": a+ab*v, "barycentric": Vector3(1-v,v,0)}
	var cp := p-c; var d5 := ab.dot(cp); var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6: return {"point": c, "barycentric": Vector3(0,0,1)}
	var vb := d5*d2-d1*d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w := d2/(d2-d6); return {"point": a+ac*w, "barycentric": Vector3(1-w,0,w)}
	var va := d3*d6-d5*d4
	if va <= 0.0 and d4-d3 >= 0.0 and d5-d6 >= 0.0:
		var w := (d4-d3)/((d4-d3)+(d5-d6)); return {"point": b+(c-b)*w, "barycentric": Vector3(0,1-w,w)}
	var inverse := 1.0 / maxf(va+vb+vc, 1e-30)
	var v := vb*inverse; var w := vc*inverse
	return {"point": a+ab*v+ac*w, "barycentric": Vector3(1-v-w,v,w)}

static func _decorate(body: Dictionary, mesh: Dictionary, index: Dictionary, atlas: Dictionary, origin: Vector3, basis: Basis, scale: float, step: float, spec: Dictionary, contour: PackedVector2Array, controls: RefCounted) -> Dictionary:
	var colors := PackedColorArray(); var uvs := PackedVector2Array(); var uvs2 := PackedVector2Array()
	var dominant := PackedInt32Array(); var owners := PackedInt32Array(); var weights := PackedFloat32Array(); var context := PackedFloat32Array()
	var roots: Array = []; var counts := [0,0,0,0,0,0,0,0]; var min_burial := INF; var max_height := -INF
	var inverse := basis.transposed()
	var bounds := AABB(mesh.vertices[0], Vector3.ZERO)
	for vi in range(mesh.vertices.size()):
		if vi % 1024 == 0 and controls != null and controls.is_cancelled(): return {"cancelled": true}
		var world: Vector3 = mesh.vertices[vi]
		var local := inverse * (world - origin)
		var hit := _closest(index, local)
		if hit.is_empty(): return {"error": "rejected_missing_vertex_support"}
		var uv := Vector2(local.x, local.y) / scale
		var outer := Profile._polygon_distance(uv, contour)
		var root := 1.0 - smoothstep(0.04, float(spec.root_band_width), -outer)
		var height := (local - Vector3(hit.point)).dot(Vector3(hit.normal))
		max_height = maxf(max_height, height)
		var influence := Support._hit_influences(body, hit)
		dominant.append(int(influence.owners[0])); owners.append_array(influence.owners); weights.append_array(influence.weights)
		colors.append(Color(0.0,0.5,0.0,1.0)); uvs.append((uv+Vector2.ONE)*0.5); uvs2.append(Vector2(float(spec.round_radius)*scale*2.0,root))
		context.append_array(PackedFloat32Array([root,0.65,0.85-root*0.5,0.2+root*0.7]))
		# Bind the entire supported layer, not just a few isolated roots.
		var sector := clampi(floori((atan2(uv.y,uv.x)+PI)/TAU*8.0),0,7)
		roots.append({"vertex_id":vi,"triangle":hit.triangle,"barycentric":Graph.arr(hit.barycentric),"point":Graph.arr(origin+basis*Vector3(hit.point)),
			"root_index":sector,"outer_root":root > 0.999,"host_id":str(body.node_ids[influence.owners[0]]),"burial":-height})
		if root > 0.999: counts[sector] += 1; min_burial = minf(min_burial,-height)
		bounds = bounds.expand(world)
	var fully_buried := min_burial > 0.0
	for count: int in counts:
		if count < 8: fully_buried = false
	var openings: Array = []
	for hole: Dictionary in spec.holes:
		var uv := Vector2(float(hole.center[0]),float(hole.center[1]))
		var point := origin+basis*Vector3(uv.x*scale,uv.y*scale,0.0)
		openings.append({"center":Graph.arr(point),"normal":Graph.arr(atlas.normal),"probe_radius":minf(float(hole.radii[0]),float(hole.radii[1]))*scale*0.25})
	mesh.merge({"name":"BodyConformingPorousCartilage","role":"flesh","porous_cartilage_id":spec.id,"geometry_path":Plan.GEOMETRY_PATH,"pipeline_stage":2,
		"colors":colors,"uvs":uvs,"uvs2":uvs2,"fibre_uv_mode":"authored","authored_surface_context":context,
		"component_ids":dominant,"component_indices":owners,"component_weights":weights,"node_ids":body.node_ids,
		"surface_root_samples":roots,"opening_witnesses":openings,"bounds":bounds,
		"stats":{"triangles":mesh.indices.size()/3,"vertices":mesh.vertices.size(),"cell_size":step,"welded_to_primary":false}},true)
	return {"mesh":mesh,"report":{"root_band_sector_counts":counts,"root_band_fully_buried":fully_buried,"minimum_root_burial":min_burial,
		"maximum_surface_height":max_height,"bound_support_vertices":roots.size(),"root_count":8,"binding_scope":"all_layer_vertices"}}

static func normal_audit(mesh: Dictionary) -> Dictionary:
	var nonfinite := 0; var small := 0; var zero := 0; var reversed := 0
	for point: Vector3 in mesh.vertices:
		if not point.is_finite(): nonfinite += 1
	for normal: Vector3 in mesh.normals:
		if not normal.is_finite() or normal.length_squared() < 0.1: nonfinite += 1
	for i in range(0,mesh.indices.size(),3):
		var a: int = mesh.indices[i]; var b: int = mesh.indices[i+1]; var c: int = mesh.indices[i+2]
		var face: Vector3 = (mesh.vertices[c]-mesh.vertices[a]).cross(mesh.vertices[b]-mesh.vertices[a])
		if face.length_squared() == 0.0: zero += 1
		if face.length_squared() <= 1e-14: small += 1
		if face.dot(mesh.normals[a]+mesh.normals[b]+mesh.normals[c]) <= 0.0: reversed += 1
	return {"nonfinite":nonfinite,"small_area":small,"zero_area":zero,"reversed_normals":reversed,"small_area_threshold":5e-8}

static func topology_audit(mesh: Dictionary) -> Dictionary: return Profile.topology_audit(mesh)
static func _recompute_normals(mesh: Dictionary) -> void: Profile._recompute_normals(mesh)
