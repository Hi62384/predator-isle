extends RefCounted
## Stage 3 opt-in plan only. The actual sheet is fitted to preserved triangles
## before final materials and rigging; a planned sheet is not a realized sheet.
const VERSION := 2
const GEOMETRY_PATH := "surface_following_tangent_cuff_v2_fixed_lattice"
const SPEC_KEY := "secondary_membrane_covering"
const STREAM := "secondary.membrane_covering.v1"

static func plan(g: RefCounted, regions: Dictionary, _morphology: Dictionary = {}) -> Dictionary:
	var report := {"version": VERSION, "requested": bool(g.settings.get("blob_membrane_candidate", false)),
		"enabled": false, "status": "disabled", "planned_count": 0, "realized_count": 0,
		"pipeline_stage": 3, "stream_id": STREAM, "visual_validated": false}
	if not report.requested or not bool(g.settings.get("secondary_enabled", true)):
		return report
	if str(g.dna.get("type", "")) != "Blob":
		report.status = "unsupported_family"
		return report
	var root_id := str(regions.get("root", ""))
	var root: Dictionary = g.node(root_id)
	var hosts: Array = []
	for value: Variant in regions.get("hosts", []):
		var node: Dictionary = g.node(str(value))
		if not node.is_empty() and str(node.get("kind", "")) == "mass" and str(value) not in hosts:
			hosts.append(str(value))
		if hosts.size() >= 12: break
	if root.is_empty() or hosts.size() < 2:
		report.status = "skipped_insufficient_mass_supports"
		return report
	var rng := RandomNumberGenerator.new()
	rng.seed = ("0x" + ("blob_membrane_01|%s|%s" % [STREAM, int(g.dna.seed)]).sha256_text().substr(0, 13)).hex_to_int()
	var spec := {"version": VERSION, "id": "primary_body.secondary_membrane.0", "pipeline_stage": 3,
		"geometry_path": GEOMETRY_PATH,
		"host_ids": hosts, "coordinate_space": "host_ids_and_dimensionless_profile",
		"stream_id": STREAM, "stable_seed": rng.seed, "phase": rng.randf_range(0.0, TAU),
		"width_ratio": rng.randf_range(0.46, 0.61), "sag_ratio": rng.randf_range(0.045, 0.085),
		"lift_ratio": rng.randf_range(0.11, 0.17), "thickness_ratio": rng.randf_range(0.008, 0.012),
		"root_band": 0.14, "material": "membrane", "max_patches": 1}
	if root.has(SPEC_KEY) and root[SPEC_KEY] != spec:
		report.status = "conflicting_existing_plan"
		return report
	root[SPEC_KEY] = spec
	report.merge({"enabled": true, "status": "planned_pending_extracted_support", "planned_count": 1,
		"host_ids": hosts.duplicate(), "spec_owner": root_id, "spec_id": spec.id,
		"realization_source": "mesh_data.stats.secondary_membrane", "no_new_bones": true}, true)
	return report
