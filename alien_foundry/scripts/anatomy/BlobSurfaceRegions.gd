extends RefCounted
## Reusable surface domains authored AFTER the immutable Stage 1 snapshot.
## Coordinates in these records remain explicitly unscaled authoring coordinates.
## Rendering consumes node.material/node.surface, not guessed labels in this report.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const VERSION := 1
const DETAIL_TYPES := ["normal_lumpy", "cavities", "bumps", "sacs", "webbing", "fibers", "messy_tissue"]
const IMPLEMENTED_ADDITIONS := ["normal_lumpy", "bumps", "sacs"]
const SUPPORTED_TISSUES := ["flesh", "muscle", "membrane", "slime"]

static func stream_seed(seed_value: int, stream: String) -> int:
	return ("0x" + ("blob_surface_regions_01|%s|%s" % [stream, seed_value]).sha256_text().substr(0, 13)).hex_to_int()

static func canonical_operations(requested: Array) -> Array:
	# Legacy nodules stays a distinct, unchanged compatibility path. It is NOT
	# silently converted to any of the three new operations when loading DNA.
	var result: Array = []
	for operation in ["nodules", "sacs", "normal_lumpy", "bumps", "grooves", "cavities", "webbing", "fibers", "messy_tissue"]:
		if operation in requested: result.append(operation)
	return result

static func build(g: RefCounted, anatomy: Dictionary, morphology: Dictionary, operations: Array, stage: int = 2) -> Dictionary:
	var domain := str(morphology.get("domain_id", "primary_body"))
	var out := {"version": VERSION, "domain_id": domain, "pipeline_stage": stage,
		"coordinate_space": "unscaled_authoring", "records": [], "compatibility_version": 1,
		"operation_order": canonical_operations(operations), "unsupported_detail_types": [], "unvalidated_candidate_detail_types": ["fibers", "messy_tissue"]}
	if str(g.dna.get("type", "")) != "Blob" or stage not in [2, 3]: return out
	var root := str(anatomy.get("root", ""))
	var root_center: Vector3 = g.center(root)
	var enabled: Array = []
	for operation in DETAIL_TYPES:
		if operation in operations: enabled.append(operation)
	var overrides: Variant = g.settings.get("surface_region_overrides", {})
	if not overrides is Dictionary: overrides = {}
	var cell := estimated_cell(g, morphology)
	for host_value in anatomy.get("hosts", []):
		var host_id := str(host_value)
		var host: Dictionary = g.node(host_id)
		if host.is_empty() or str(host.get("kind", "")) != "mass": continue
		var id := domain + ".surface." + host_id
		var seed_value := stream_seed(int(g.dna.seed), id)
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value
		var size := Graph.vec(host.size)
		var direction: Vector3 = (g.center(host_id) - root_center).normalized()
		if host_id == root: direction = Vector3(0.0, 0.25, -1.0).normalized()
		else: direction = (direction + Vector3(0.0, 0.30, -0.26)).normalized()
		var density := clampf(float(g.settings.get("growth_density", 0.4)) * rng.randf_range(0.85, 1.2), 0.0, 1.0)
		var record := {"id": id, "host_id": host_id, "host_ids": [host_id], "domain_id": domain,
			"coordinate_space": "unscaled_authoring", "pipeline_stage": stage,
			"primary_detail_type": "normal_lumpy", "secondary_detail_types": [],
			"allowed_detail_types": enabled.duplicate(), "density": density,
			"scale": rng.randf_range(0.86, 1.15), "intensity": clampf(0.40 + float(g.settings.get("surface_detail", 0.55)) * 0.60, 0.0, 1.0),
			"growth_direction": Graph.arr(direction), "blend_distance": maxf(cell * 0.8, minf(size.x, minf(size.y, size.z)) * 0.11),
			"tissue_identity": "flesh", "stable_seed": seed_value, "seed_stream": id,
			"region_origin": host.position.duplicate(), "region_normal": Graph.arr(direction),
			"region_extent": Graph.arr(Vector3(size.x * 0.94, size.y * 0.94, size.z)),
			"minimum_wall": maxf(cell * 1.4, minf(size.x, minf(size.y, size.z)) * 0.12),
			"minimum_exposure": 0.18, "support_ids": anatomy.get("support_ids", []).duplicate(),
			"feature_nodes": [], "reservations": [], "realized_detail_types": []}
		if host_id == root:
			# A common anterior domain spans the connected carrier union. Small
			# additions still have one explicit root host; web/cavity operators
			# can use all underlying masses without inventing a covering pad.
			record.host_ids = anatomy.get("hosts", [root]).duplicate()
			record.region_origin = Graph.arr(root_center + Vector3.UP * float(morphology.get("height", 1.0)) * 0.12)
			record.region_extent = Graph.arr(Vector3(float(morphology.get("width", 1.0)) * 0.80, float(morphology.get("height", 1.0)) * 0.70, float(morphology.get("depth", 1.0))))
		var override: Variant = overrides.get(id, overrides.get(host_id, {}))
		if override is Dictionary: _apply_override(record, override)
		if not enabled.is_empty():
			var preferred: String = str(enabled[posmod(seed_value, enabled.size())])
			if override is Dictionary and str(override.get("primary_detail_type", "")) in enabled: preferred = str(override.primary_detail_type)
			if "webbing" in enabled and host_id == root and not (override is Dictionary and override.has("primary_detail_type")): preferred = "webbing"
			record.primary_detail_type = preferred
			record.secondary_detail_types = enabled.duplicate()
			record.secondary_detail_types.erase(preferred)
		else:
			record.primary_detail_type = "none"
		out.records.append(record)
	return out

static func _apply_override(record: Dictionary, override: Dictionary) -> void:
	for key in ["density", "intensity"]:
		if override.has(key): record[key] = clampf(float(override[key]), 0.0, 1.0)
	if override.has("scale"): record.scale = clampf(float(override.scale), 0.55, 1.65)
	if override.has("blend_distance"): record.blend_distance = clampf(float(override.blend_distance), 0.005, 0.4)
	if str(override.get("tissue_identity", "")) in SUPPORTED_TISSUES: record.tissue_identity = str(override.tissue_identity)
	if str(override.get("primary_detail_type", "")) in DETAIL_TYPES: record.primary_detail_type = str(override.primary_detail_type)
	if override.has("growth_direction"):
		var direction := Graph.vec(override.growth_direction)
		if direction.is_finite() and direction.length_squared() > 0.0001:
			record.growth_direction = Graph.arr(direction.normalized()); record.region_normal = record.growth_direction.duplicate()

static func estimated_cell(g: RefCounted, morphology: Dictionary) -> float:
	return maxf(float(morphology.get("width", 1.0)), maxf(float(morphology.get("height", 1.0)), float(morphology.get("depth", 1.0)))) * 2.8 / float([48, 94, 132][clampi(int(g.settings.get("quality", 1)), 0, 2)])

static func compatible(first: String, second: String) -> bool:
	# Compatibility permits multiple types within a region, not unchecked
	# coincident solids. Each operator must still validate its actual footprint.
	return first in DETAIL_TYPES and second in DETAIL_TYPES

static func conflicts(point: Vector3, radius: float, reservations: Array, padding: float = 0.0, operation: String = "") -> bool:
	for item: Dictionary in reservations:
		var other := str(item.get("operation", ""))
		# Broad low relief may share tissue with other additions. Destructive or
		# hollow features always reserve their actual geometric envelope.
		if operation == "normal_lumpy" and other in IMPLEMENTED_ADDITIONS: continue
		var multiplier := 0.58 if other in IMPLEMENTED_ADDITIONS and operation in IMPLEMENTED_ADDITIONS else 1.0
		if point.distance_to(Graph.vec(item.get("position", item.get("center", [])))) < (radius + float(item.get("radius", 0.0))) * multiplier + padding: return true
	return false

static func surface_sample(node: Dictionary, index: int, count: int = 40) -> Vector3:
	if Graph.MantleField.marked(node): return Graph.mantle_surface(node,1.0-(float(index)+0.5)/float(count),float(index)*2.39996323)
	var y := 1.0 - (float(index) + 0.5) * 2.0 / float(count)
	var radius := sqrt(maxf(0.0, 1.0 - y * y)); var angle := float(index) * 2.39996323
	return Graph.vec(node.position) + Graph.node_basis(node) * (Vector3(cos(angle) * radius, y, sin(angle) * radius) * Graph.vec(node.size))

static func exposure(node: Dictionary, existing: Array, field: RefCounted = null, first_new_node: int = 0) -> Dictionary:
	var exposed := 0; var protrusion := 0.0
	for index in range(40):
		var point := surface_sample(node, index)
		var distance: float = field.sample_signed_distance(point) if field != null else INF
		for node_index in range(first_new_node if field != null else 0, existing.size()):
			var other: Dictionary = existing[node_index]
			if str(other.get("kind", "")) == "cavity": continue
			distance = minf(distance, Graph.distance_to_tissue(other, point) - float(other.get("blend", 0.0)) * 0.30)
		if distance > 0.0: exposed += 1
		protrusion = maxf(protrusion, distance)
	return {"fraction": float(exposed) / 40.0, "protrusion": protrusion}

static func support_clear(g: RefCounted, record: Dictionary, point: Vector3, radius: float) -> bool:
	for id in record.get("support_ids", []):
		var node: Dictionary = g.node(str(id))
		if not node.is_empty() and Graph.distance_to_tissue(node, point) < radius * 0.60 + float(record.minimum_wall): return false
	return true

static func host_thickness(host: Dictionary, surface: Vector3, normal: Vector3) -> float:
	if Graph.MantleField.marked(host):
		var field: RefCounted = Graph.MantleField.create(host.shape.mantle_envelope,Graph.vec(host.size))
		var inverse := Graph.node_basis(host).inverse()
		var point := inverse*(surface-Graph.vec(host.position)); var inward := inverse*(-normal.normalized())
		var increment: float = minf(field.radii.x,minf(field.radii.y,field.radii.z))/128.0
		if field.distance(point+inward*increment)>=0.0: return 0.0
		var previous := 0.0
		for i in range(1,1025):
			var along := float(i)*increment
			if field.distance(point+inward*along)>0.0:
				var high := along; var low := previous
				for j in range(24):
					var mid := (low+high)*0.5
					if field.distance(point+inward*mid)>0.0: high=mid
					else: low=mid
				return (low+high)*0.5
			previous = along
		return 0.0
	# Exact inward chord of a rotated ellipsoid. This protects thin host edges
	# before an added mass is accepted, independent of sampling density.
	var inverse := Graph.node_basis(host).inverse()
	var size := Graph.vec(host.size)
	var p := (inverse * (surface - Graph.vec(host.position))) / size
	var d := (inverse * (-normal)) / size
	var discriminant := pow(p.dot(d), 2.0) - d.length_squared() * (p.length_squared() - 1.0)
	if discriminant < 0.0 or d.length_squared() < 0.000001: return 0.0
	return maxf(0.0, (-p.dot(d) + sqrt(discriminant)) / d.length_squared())

static func reserve(record: Dictionary, operation: String, node: Dictionary) -> void:
	var size := Graph.vec(node.size)
	var center := Graph.vec(node.position)
	var radius := maxf(size.x, maxf(size.y, size.z))
	if str(node.get("kind", "")) == "curve" and not node.get("points", []).is_empty():
		var low := Graph.vec(node.points[0]); var high := low
		for point in node.points:
			low = low.min(Graph.vec(point)); high = high.max(Graph.vec(point))
		center = low.lerp(high, 0.5); radius = 0.0
		for i in range(node.points.size()):
			var local_radius := float(node.radii[i]) if i < node.get("radii", []).size() else float(node.get("radius", 0.0))
			radius = maxf(radius, center.distance_to(Graph.vec(node.points[i])) + local_radius)
	record.feature_nodes.append(str(node.id))
	if operation not in record.realized_detail_types: record.realized_detail_types.append(operation)
	record.reservations.append({"operation": operation, "node_ids": [str(node.id)], "position": Graph.arr(center),
		"radius": radius, "blend_distance": float(node.blend)})
