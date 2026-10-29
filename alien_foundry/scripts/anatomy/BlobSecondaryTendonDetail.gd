extends RefCounted
## Validated173 tendon operation shared by foundation and seeded stage6 carriers.
## Rules are installed immediately after feature declaration, before realization.
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const Curves = preload("res://alien_foundry/scripts/geometry/CurveGeometry.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const SETTING := "blob_secondary_detail_mode"
const OFF := "off"
const MODE := "tendon_ridges_v1"

static func validate(options: Dictionary) -> Dictionary:
	var selected: Variant = options.get(SETTING, OFF)
	if not selected is String or selected not in [OFF, MODE]:
		return {"error": "Unsupported iterative secondary detail mode."}
	return {"ok": true}

static func rules(options: Dictionary) -> Dictionary:
	if options.get(SETTING, OFF) != MODE: return {}
	return {"version": 1, "enabled": true, "operation": "longitudinal_tendon_ridges", "density": 2, "amplitude": 0.42, "amplitude_units": "fraction_of_local_host_radius"}

static func apply(g: RefCounted, feature_id: String) -> Dictionary:
	var feature: Dictionary = Blueprint.feature(g.biological_blueprint, feature_id)
	var rules: Dictionary = feature.get("detail_rules", {})
	var report := {"version": 1, "feature_id": feature_id, "operation": "longitudinal_tendon_ridges", "status": "skipped_disabled", "node_ids": [],
		"new_bones": 0, "carrier_feature_id": feature_id, "surface_mapping": "authoritative_feature_owner_not_vertex_inference"}
	if feature.get("type") != "tendril" or not bool(rules.get("enabled", false)) or rules.get("operation") != "longitudinal_tendon_ridges": return report
	var density := float(g.settings.surface_detail)
	var amplitude := clampf(float(rules.get("amplitude", 0.0)), 0.0, 0.65)
	if density <= 0.0 or amplitude <= 0.0 or float(rules.get("density", 0.0)) <= 0.0: return report
	if feature.geometry_refs.node_ids.is_empty(): return report
	var primary_id := str(feature.geometry_refs.node_ids[0])
	var primary: Dictionary = g.node(primary_id)
	if primary.get("kind") != "curve": return report
	var curve: Dictionary = Curves.sample(primary, 6, true)
	var centerline: PackedVector3Array = curve.points
	var host_radii: PackedFloat32Array = curve.radii
	if centerline.size() < 3: return report
	var count := clampi(int(round(float(rules.get("density", 2)) * density / 0.55)), 1, 4)
	if int(g.dna.budget.nodes) - g.dna.nodes.size() < count:
		report["status"] = "skipped_budget"
		return report
	var frames: Array = []
	var previous := Vector3.ZERO
	for j in range(centerline.size()):
		var tangent: Vector3 = (centerline[mini(j + 1, centerline.size() - 1)] - centerline[maxi(j - 1, 0)]).normalized()
		var across: Vector3 = previous - tangent * previous.dot(tangent)
		if across.length_squared() < 0.0001:
			across = tangent.cross(Vector3.UP)
			if across.length_squared() < 0.0001: across = tangent.cross(Vector3.RIGHT)
		across = across.normalized()
		frames.append([across, tangent.cross(across).normalized()])
		previous = across
	for strand in range(count):
		var points: Array = []
		var radii: Array = []
		for j in range(centerline.size()):
			var t := float(j) / float(centerline.size() - 1)
			var fade := pow(maxf(0.0, sin(PI * t)), 0.65)
			var angle := TAU * float(strand) / float(count) + 0.22 * sin(PI * t)
			var radial: Vector3 = frames[j][0] * cos(angle) + frames[j][1] * sin(angle)
			# Every authored center is inside its host cross-section; both
			# ends coincide with the host axis and have smaller buried caps.
			points.append(centerline[j] + radial * float(host_radii[j]) * 0.90 * fade)
			radii.append(maxf(0.0035, float(host_radii[j]) * amplitude * fade))
		g.owner_feature_id = feature_id
		g.owner_feature_id = feature_id
		g.rng.seed = Blueprint.stream_seed(int(g.dna.seed), feature_id, "tendon_ridge.%s" % strand)
		# Existing role=fold disables preview thickness inflation. It creates
		# actual additive SDF tissue, not a shader mark or detached accessory.
		var id: String = g.curve(primary_id, "fold", points, radii, str(primary.material), false)
		var ridge: Dictionary = g.node(id)
		ridge["noise"] = 0.0
		ridge["blend"] = float(primary.radii[0]) * 0.10
		ridge["shape"] = {"swelling": 0.0, "twist": 0.0, "taper": 0.0}
		ridge["detail_operation"] = "longitudinal_tendon_ridge"
		ridge["source_feature_id"] = feature_id
		report.node_ids.append(id)
	report["status"] = "realized_geometry" if not report.node_ids.is_empty() else "skipped_disabled"
	report["count"] = count
	report["amplitude"] = amplitude
	report["maximum_center_offset_fraction"] = 0.90
	report["end_caps"] = "buried_on_parent_axis"
	return report
