extends RefCounted
## One fixed, default-off Stage1 envelope study. No secondary pods or supports.
const SETTING := "blob_grown_envelope_version"
const VERSION := 1

static func selected(settings: Dictionary) -> bool:
	var value: Variant = settings.get(SETTING, 0)
	return (value is int or value is float) and float(value) == 1.0

static func build(generator: RefCounted, g: RefCounted, m: Dictionary) -> Dictionary:
	var w := float(m.width); var h := float(m.height); var d := float(m.depth)
	var root: String = g.mass("", "core", Vector3.ZERO, Vector3(w*0.86,h*0.92,d*0.94), "flesh", true)
	var node: Dictionary = g.node(root)
	# Rows: axis xyz, long tangent xyz, across width, along width, amplitude.
	# All six patches modify the same radius, including the three broad folds.
	node["shape"] = {"grown_envelope": {"version": VERSION, "compression": 0.62, "patches": [
		[-0.56,0.76,0.24, 0.45,0.55,-0.55, 0.60,0.78,0.48],
		[0.68,-0.25,-0.69, 0.15,0.92,-0.25, 0.53,0.70,0.38],
		[0.42,0.12,0.90, -0.25,0.94,0.0, 0.45,0.62,0.27],
		[-0.34,0.10,-0.94, -0.30,0.90,0.20, 0.23,0.88,-0.33],
		[0.62,0.68,-0.38, 0.64,-0.64,0.25, 0.22,0.80,-0.27],
		[-0.68,-0.08,0.73, 0.15,0.96,0.25, 0.25,0.76,-0.20]]}}
	node.noise = 0.0; node.blend = w*0.065
	node["blob_region"] = "grown_primary_envelope"
	node["surface"] = {"exposure": 0.10, "growth": 0.0}
	g.dna.metadata["grown_envelope_anatomy"] = {"version": VERSION, "primary_envelopes": 1, "subordinate_sacs": 0, "supports": 0,
		"stage1_only": true, "construction": "six_angular_pressure_patches_in_one_positive_radial_envelope", "later_operations": "disabled_for_candidate",
		"anatomy": "dominant_high_left_rear_load_lower_forward_right_load_smaller_rear_counterload_and_three_oblique_recessions"}
	return generator._semantic_regions(g, root, [root])
