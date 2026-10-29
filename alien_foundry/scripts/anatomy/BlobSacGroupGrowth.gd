extends RefCounted
const Field = preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
static func apply(g: RefCounted, stage: int, mode: String = Field.MODE) -> Dictionary:
	g.dna.settings[Field.SETTING] = mode
	var report := {"operation": mode,"stage": stage,"features": [],"status": "skipped_profile_absent","final_rig_supported": mode == Field.FINAL_MODE}
	var ordinal := 0
	for feature: Dictionary in g.biological_blueprint.features:
		if feature.type != "sac": continue
		var owner: Dictionary = g.node(feature.geometry_refs.node_ids[0])
		var rng := RandomNumberGenerator.new(); rng.seed = Blueprint.stream_seed(int(g.dna.seed),feature.id,Field.SEED_LANE)
		if stage == 4:
			var axial: Vector3 = Field.vec(feature.growth_direction).normalized()
			var across: Vector3 = axial.cross(Vector3.UP).normalized()
			if across.length_squared() < 0.1: across = Vector3.RIGHT
			across = across.rotated(axial,rng.randf_range(-0.25,0.25)); var depth: Vector3 = across.cross(axial).normalized()
			var members: Array = feature.geometry_refs.node_ids.duplicate()
			for n: Dictionary in g.dna.nodes:
				if n.get("kind") == "cavity" and n.get("parent") == owner.id: members.append(n.id)
			members.sort()
			var desc := {"version": 1,"owner_id": owner.id,"feature_id": feature.id,"members": members,"across": Field.arr(across),"axial": Field.arr(axial),"depth": Field.arr(depth),"swell_x": rng.randf_range(0.22,0.30),"swell_z": rng.randf_range(0.16,0.22),"waist_x": 0.10,"waist_z": 0.07,"bend_x": rng.randf_range(-0.14,0.14),"bend_z": rng.randf_range(-0.10,0.10),"phase": rng.randf_range(-1.0,1.0),"creases": [],"fold_amplitude": 0.0}
			if mode in [Field.MODE,Field.FINAL_MODE]: desc["bounds_version"] = 2
			owner.shape[Field.KEY] = desc
			for id: String in members: g.node(id)[Field.LINK] = owner.id
			feature.geometry_recipe[Field.KEY] = Field.digest(desc)
			var count: int = [2,1,0][ordinal%3]
			feature["detail_rules"] = {"version": 3,"operation": mode,"enabled": count > 0,"density": count,"amplitude": 0.065,"amplitude_units": "organism_scale","smooth_region_reason": "declared_smooth_tissue_profile" if count == 0 else ""}
		else:
			var rule: Dictionary = feature.detail_rules
			if rule.enabled and float(g.settings.get("surface_detail",0.55)) > 0.0:
				var creases: Array = []
				if int(rule.density) == 2:
					creases = [{"center": -0.48,"width": 0.47,"strength": 1.0},{"center": 0.46,"width": 0.40,"strength": 0.82}]
				elif int(rule.density) == 1: creases = [{"center": rng.randf_range(-0.16,0.16),"width": 0.78,"strength": 1.0}]
				owner.shape[Field.KEY]["creases"] = creases
				owner.shape[Field.KEY]["fold_amplitude"] = float(rule.amplitude)
				var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0,float(rule.amplitude))
				owner.shape[Field.KEY]["fold_amplitude_hex"] = bytes.hex_encode()
		report.features.append({"feature_id": feature.id,"member_ids": owner.shape[Field.KEY].members,"crease_count": owner.shape[Field.KEY].creases.size(),"detail_status": "declared_smooth_region" if not feature.detail_rules.enabled else ("authored_geometry" if stage == 5 else "planned")})
		ordinal += 1
	if ordinal > 0: report.status = "authored_geometry"
	return report
