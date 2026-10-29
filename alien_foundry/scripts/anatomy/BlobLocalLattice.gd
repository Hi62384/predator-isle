extends RefCounted
## Stage 2, default-off local-resolution experiment. The versioned descriptor
## lives on an existing host, so geometry cache identity and saved replay include
## its actual dimensions. It adds no primary field primitive or skeletal node.
const SPEC_KEY := "surface_local_lattice"
const SETTING := "blob_local_lattice_candidate"
const GEOMETRY_PATH := "rounded_local_porosity_surface_nets_v1"
const ID := "primary_body.local_lattice.0"

static func plan(g: RefCounted, regions: Dictionary) -> Dictionary:
	if not bool(g.settings.get(SETTING, false)): return {}
	return install(g.dna, str(regions.get("root", "")))

static func install(dna: Dictionary, host_id: String = "") -> Dictionary:
	if str(dna.get("type", "")) != "Blob": return {"error": "Local lattice requires Blob anatomy."}
	if dna.get("metadata", {}).has("mantle_anatomy"): return {"error": "Mantle remains a Stage 1-only experiment."}
	var host: Dictionary = {}
	for node: Dictionary in dna.get("nodes", []):
		if (str(node.get("id", "")) == host_id or (host_id.is_empty() and str(node.get("role", "")) == "core")) and str(node.get("kind", "")) == "mass": host = node; break
	if host.is_empty(): return {"error": "Local lattice host was not found."}
	# Five deliberately unequal, skewed voids. This is one curved, rounded
	# tissue field, not independent bars, a repeated honeycomb or a two-hole plate.
	var spec := {"version": 1, "geometry_path": GEOMETRY_PATH, "id": ID, "pipeline_stage": 2,
		"host_id": str(host.id), "coordinate_space": "host_node_dimensionless", "direction": [0.0, 0.12, -1.0],
		"center_offset": [-0.04, -0.08], "scale_ratio": 0.96, "refinement": 3.5,
		"round_radius": 0.082, "lift_ratio": 0.23, "root_burial_ratio": 0.145,
		"outer": [[-0.94,0.10],[-0.77,-0.42],[-0.52,-0.84],[-0.10,-0.91],[0.30,-0.71],[0.74,-0.41],[0.83,0.08],[0.61,0.56],[0.12,0.86],[-0.42,0.68]],
		"roots": [[-0.83,0.08,0.25],[0.49,0.53,0.24],[-0.08,-0.78,0.23]],
		"holes": [
			{"center":[-0.50,0.27],"radii":[0.2565,0.3477],"angle":-0.25,"phase":0.7},
			{"center":[0.12,0.45],"radii":[0.2337,0.2679],"angle":0.45,"phase":2.1},
			{"center":[0.49,-0.10],"radii":[0.215,0.3249],"angle":-0.20,"phase":4.0},
			{"center":[-0.10,-0.28],"radii":[0.245,0.3021],"angle":0.36,"phase":1.5},
			{"center":[-0.50,-0.50],"radii":[0.1425,0.1938],"angle":-0.45,"phase":3.0}],
		"max_samples": 300000, "max_triangles": 30000, "material": "flesh"}
	if host.has(SPEC_KEY) and host[SPEC_KEY] != spec: return {"error": "Conflicting local lattice descriptor."}
	host[SPEC_KEY] = spec
	return {"requested": true, "planned_count": 1, "realized_count": 0, "pipeline_stage": 2,
		"status": "planned_pending_retained_support", "spec_id": ID, "visual_validated": false}
