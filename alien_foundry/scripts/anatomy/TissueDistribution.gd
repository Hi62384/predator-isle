extends RefCounted
## Continuous parameter mixtures, not five meshes or mutually exclusive templates.
## The realized genome is stored by the generator; rendering never resamples it.

static func humanoid(g: RefCounted) -> Dictionary:
	var names := ["lean_stalker", "heavy_organism", "irregular_humanoid", "organic_mimic", "distorted_humanoid"]
	var weights: Dictionary = {}
	var total := 0.0
	for key in names:
		var value := 0.018 + pow(g.rng.randf(), 3.6)
		weights[key] = value
		total += value
	for key in names: weights[key] = float(weights[key]) / total
	# Leg, torso, chest width/depth, bulk, arm, neck, hunch, lateral bend,
	# supporting stance and propensity for asymmetric growth.
	var distributions := [
		[2.65,1.38,0.45,0.27,0.72,2.02,0.43,0.29,0.10,0.47,0.27],
		[1.90,1.48,0.78,0.47,1.65,1.62,0.24,0.12,0.05,0.72,0.30],
		[2.22,1.42,0.59,0.36,1.17,1.85,0.34,0.20,0.23,0.60,0.85],
		[2.18,1.37,0.52,0.31,1.00,1.48,0.25,0.04,0.03,0.49,0.17],
		[2.58,1.56,0.61,0.35,0.94,2.25,0.48,0.36,0.27,0.67,0.95]
	]
	var keys := ["leg_length","torso_length","chest_width","chest_depth","bulk","arm_length","neck_length","hunch","lateral_bend","stance","growth_bias"]
	var out: Dictionary = {"tendency_weights":weights}
	var irregularity := float(g.settings["irregularity"])
	for j in keys.size():
		var value := 0.0
		for i in names.size(): value += float(distributions[i][j]) * float(weights[names[i]])
		var variation := 0.06 + irregularity * (0.18 if j in [2,3,4,8,10] else 0.13)
		out[keys[j]] = value * g.randf_range(1.0-variation,1.0+variation)
	out["lateral_bend"] *= g.randf_range(-1.0,1.0) * (0.30 + irregularity)
	out["asymmetry"] = (0.07 + float(weights["irregular_humanoid"])*0.32 + float(weights["distorted_humanoid"])*0.30) * irregularity
	out["pelvis_width"] = float(out["chest_width"])*g.randf_range(0.61,0.83)
	out["abdomen_width"] = float(out["chest_width"])*g.randf_range(0.64,0.86)
	out["abdomen_depth"] = float(out["chest_depth"])*g.randf_range(0.78,1.05)
	out["head_width"] = g.randf_range(0.23,0.29)*(0.90+float(out["bulk"])*0.10)
	out["head_height"] = g.randf_range(0.31,0.39)
	out["neck_radius"] = 0.095+float(out["bulk"])*0.045
	out["thigh_radius"] = 0.105+float(out["bulk"])*0.105
	out["calf_radius"] = 0.075+float(out["bulk"])*0.075
	out["upper_arm_radius"] = 0.075+float(out["bulk"])*0.080
	out["forearm_radius"] = 0.060+float(out["bulk"])*0.062
	return out
