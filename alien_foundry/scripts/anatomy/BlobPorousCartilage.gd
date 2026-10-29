extends RefCounted
## Independent default-off Stage 2 experiment. The previous local-lattice
## descriptors and rejected bridge are preserved, not migrated or reinterpreted.
const SPEC_KEY := "surface_porous_cartilage"
const SETTING := "blob_porous_cartilage_candidate"
const GEOMETRY_PATH := "retained_triangle_world_cartilage_sparse_tetra_v1"
const ID := "primary_body.porous_cartilage.0"

static func plan(g: RefCounted, regions: Dictionary) -> Dictionary:
	if not bool(g.settings.get(SETTING, false)): return {}
	return install(g.dna, str(regions.get("root", "")))

static func install(dna: Dictionary, host_id: String = "") -> Dictionary:
	if str(dna.get("type", "")) != "Blob": return {"error": "Porous cartilage requires Blob anatomy."}
	if dna.get("metadata", {}).has("mantle_anatomy") or dna.get("metadata", {}).has("grown_envelope_anatomy"):
		return {"error": "Body-only experiments do not receive cartilage layers."}
	var host: Dictionary = {}
	for node: Dictionary in dna.get("nodes", []):
		if (str(node.get("id", "")) == host_id or (host_id.is_empty() and str(node.get("role", "")) == "core")) and str(node.get("kind", "")) == "mass":
			host = node; break
	if host.is_empty(): return {"error": "Porous cartilage host was not found."}
	# The fixed host frame/region is the rejected experiment's original one.
	# Four NEW intentionally enclosed openings, not a correction of its five.
	var spec := {"version": 1, "geometry_path": GEOMETRY_PATH, "id": ID, "pipeline_stage": 2,
		"host_id": str(host.id), "coordinate_space": "host_node_dimensionless", "direction": [0.0, 0.12, -1.0],
		"center_offset": [-0.04, -0.08], "scale_ratio": 0.96, "refinement": 3.5,
		"round_radius": 0.065, "interior_offset": -0.008, "root_burial_ratio": 0.025, "root_band_width": 0.28,
		"outer": [[-0.94,0.10],[-0.77,-0.42],[-0.52,-0.84],[-0.10,-0.91],[0.30,-0.71],[0.74,-0.41],[0.83,0.08],[0.61,0.56],[0.12,0.86],[-0.42,0.68]],
		"holes": [
			{"center":[-0.43,0.23],"radii":[0.19,0.245],"angle":-0.25,"phase":0.7},
			{"center":[0.13,0.43],"radii":[0.18,0.205],"angle":0.45,"phase":2.1},
			{"center":[0.43,-0.13],"radii":[0.18,0.26],"angle":-0.20,"phase":4.0},
			{"center":[-0.22,-0.38],"radii":[0.23,0.27],"angle":0.36,"phase":1.5}],
		"max_samples": 300000, "max_triangles": 30000, "material": "flesh"}
	if host.has(SPEC_KEY) and host[SPEC_KEY] != spec: return {"error": "Conflicting porous-cartilage descriptor."}
	host[SPEC_KEY] = spec
	return {"requested": true, "planned_count": 1, "realized_count": 0, "pipeline_stage": 2,
		"status": "planned_pending_retained_support", "spec_id": ID, "visual_validated": false}
