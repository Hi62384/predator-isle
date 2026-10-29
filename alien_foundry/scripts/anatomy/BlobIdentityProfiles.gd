extends RefCounted
## Bounded procedural choices, not meshes or a replacement body generator.
## All lanes are stateless. No anatomy RNG, quality, material or detail setting
## is read. Descriptors request only carrier types implemented by this project.
const SCHEMA := "blob-identity-profile"
const VERSION := 1
const SETTING := "blob_identity_profile"
const FOUNDATION := "foundation_171"
const SEEDED := "seeded_v1"
const POSITIVE := "positive_sacs_v1"
const FAMILIES := ["simple", "sacs_only", "tendrils_only", "ostial_sacs", "sparse_mixed", "elaborate"]
const MAX_SACS := 3
const MAX_CAVITIES := 2
const MAX_TENDRILS := 5
const REGIONS := ["mantle", "pouch", "left", "right"]

static func lane(seed_value: int, name: String) -> int:
	return ("0x" + ("blob_identity_profile_v1|%s|%s" % [seed_value, name]).sha256_text().substr(0, 13)).hex_to_int()

static func _unit(seed_value: int, name: String) -> float:
	return float(lane(seed_value, name) % 1000001) / 1000000.0

static func _range(seed_value: int, name: String, low: float, high: float) -> float:
	return low + (high - low) * _unit(seed_value, name)

static func describe(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var requested: Variant = options.get(SETTING, FOUNDATION)
	if not requested is String or requested not in [FOUNDATION, SEEDED, POSITIVE]:
		return {"error": "Unsupported Blob identity profile; use foundation_171 or seeded_v1."}
	if requested==POSITIVE:
		if options.get("blob_positive_growth_mode")!="positive_sacs_only_v1" or seed_value!=22 or options.get("secondary_enabled",true)!=false:return {"error":"206 positive profile requires its explicit seed22 staged scope."}
		var inherited_options:=options.duplicate(true);inherited_options[SETTING]=SEEDED
		var inherited:=describe(seed_value,inherited_options);var selected: Array=[]
		for feature: Dictionary in inherited.features:
			if feature.type=="sac":selected.append(feature.duplicate(true))
		if selected.size()!=3:return {"error":"206 fixed specimen requires its three original sac identities."}
		var positive:=_descriptor(seed_value,POSITIVE,"positive_sacs_only",false,selected)
		positive["cavity_scope"]="unsupported_in_positive_growth206";return positive
	var enabled: bool = bool(options.get("secondary_enabled", true))
	if requested == FOUNDATION: return _foundation(seed_value, enabled)
	var family: String = FAMILIES[lane(seed_value, "family") % FAMILIES.size()]
	var sacs := 0
	var cavities := 0
	var primary := 0
	var secondary := 0
	match family:
		"sacs_only": sacs = 1 + lane(seed_value, "sac_count") % 3
		"tendrils_only":
			var total := 1 + lane(seed_value, "tendril_count") % 4
			primary = mini(total, 2)
			secondary = total - primary
		"ostial_sacs":
			sacs = 1 + lane(seed_value, "sac_count") % 3
			cavities = 1 + lane(seed_value, "cavity_count") % mini(2, sacs)
		"sparse_mixed":
			sacs = 1
			primary = 1
			secondary = lane(seed_value, "secondary_count") % 2
		"elaborate":
			sacs = 2 + lane(seed_value, "sac_count") % 2
			cavities = 1 + lane(seed_value, "cavity_count") % 2
			primary = 2 + lane(seed_value, "primary_count") % 2
			secondary = 1 + lane(seed_value, "secondary_count") % 2
	var features: Array = []
	var hosts := ["mantle", "pouch", "left"]
	var directions := [[-0.55, 0.65, -0.85], [0.75, 0.20, -0.85], [-0.85, 0.28, 0.12]]
	for i in range(sacs):
		var id := "blob.sac.primary.%s" % i
		var direction: Array = _direction(seed_value, id, directions[i], 0.15)
		features.append({"id": id, "type": "sac", "stage": 3, "host_region": hosts[i], "direction": direction,
			"scale_multiplier": _range(seed_value, id + ".scale", 0.80, 1.08)})
		if i < cavities:
			features.append({"id": "blob.cavity.sac_ostium.%s" % i, "type": "cavity", "stage": 3,
				"host_feature_id": id, "direction": direction.duplicate(), "scale_multiplier": _range(seed_value, id + ".ostium_scale", 0.78, 1.0)})
	var tendril_hosts := ["mantle", "right", "left"]
	var tendril_directions := [[0.48, 0.80, 0.12], [0.90, 0.42, 0.15], [-0.86, 0.52, -0.20]]
	for i in range(primary):
		features.append(_tendril(seed_value, "primary", i, 3, tendril_hosts[i], tendril_directions[i]))
	if enabled:
		for i in range(secondary):
			features.append(_tendril(seed_value, "secondary", i, 6, ["right", "left"][i], [[0.94, 0.16, -0.32], [-0.78, 0.35, 0.42]][i]))
	return _descriptor(seed_value, SEEDED, family, enabled, features)

static func _direction(seed_value: int, id: String, center: Array, spread: float) -> Array:
	var result: Array = []
	for axis in range(3):
		result.append(float(center[axis]) + _range(seed_value, id + ".direction.%s" % axis, -spread, spread))
	return result

static func _tendril(seed_value: int, group: String, index: int, stage: int, host: String, direction: Array) -> Dictionary:
	var id := "blob.tendril.%s.%s" % [group, index]
	return {"id": id, "type": "tendril", "stage": stage, "host_region": host,
		"direction": _direction(seed_value, id, direction, 0.13),
		"length_multiplier": _range(seed_value, id + ".length", 0.68, 1.16)}

static func _foundation(seed_value: int, enabled: bool) -> Dictionary:
	# Describes the unchanged171 route. The integration retains the original
	# authoring functions, preserving their exact floating math and RNG order.
	var features: Array = [
		{"id": "blob.sac.primary.0", "type": "sac", "stage": 3, "host_region": "mantle", "direction": [-0.55, 0.65, -0.85], "scale_multiplier": 1.0},
		{"id": "blob.sac.primary.1", "type": "sac", "stage": 3, "host_region": "pouch", "direction": [0.75, 0.20, -0.85], "scale_multiplier": 1.0},
		{"id": "blob.cavity.sac_ostium.0", "type": "cavity", "stage": 3, "host_feature_id": "blob.sac.primary.1", "direction": [0.75, 0.20, -0.85], "scale_multiplier": 1.0},
		{"id": "blob.tendril.primary.0", "type": "tendril", "stage": 3, "host_region": "mantle", "direction": [0.48, 0.80, 0.12], "length_multiplier": 1.05}]
	if enabled:
		features.append({"id": "blob.tendril.secondary.0", "type": "tendril", "stage": 6, "host_region": "right", "direction": [0.94, 0.16, -0.32], "length_multiplier": 0.95})
	return _descriptor(seed_value, FOUNDATION, FOUNDATION, enabled, features)

static func _descriptor(seed_value: int, profile: String, family: String, enabled: bool, features: Array) -> Dictionary:
	var counts := {"sac": 0, "cavity": 0, "tendril": 0, "primary_tendril": 0, "secondary_tendril": 0}
	for item: Dictionary in features:
		counts[item.type] += 1
		if item.type == "tendril": counts["primary_tendril" if item.stage == 3 else "secondary_tendril"] += 1
	return {"schema": SCHEMA, "version": VERSION, "profile": profile, "family": family, "seed": seed_value,
		"stream": "SHA256 first52bits: blob_identity_profile_v1|seed|lane", "secondary_enabled": enabled,
		"features": features, "counts": counts, "unsupported_types": ["face", "membrane", "porous", "growth"],
		"cavity_scope": "outward_sac_ostia_only; direct_body_cavities_deferred"}

static func validate_descriptor(profile: Dictionary) -> Dictionary:
	if profile.get("schema") != SCHEMA or profile.get("version") != VERSION or profile.get("profile") not in [FOUNDATION, SEEDED, POSITIVE]:
		return {"error": "Invalid Blob identity descriptor."}
	if not profile.get("features") is Array or not profile.get("counts") is Dictionary:
		return {"error": "Missing Blob identity feature plan."}
	var seen := {}
	var actual := {"sac": 0, "cavity": 0, "tendril": 0, "primary_tendril": 0, "secondary_tendril": 0}
	for item in profile.features:
		if not item is Dictionary or item.get("type") not in ["sac", "cavity", "tendril"] or item.get("stage") not in [3, 6]:
			return {"error": "Unimplemented Blob identity feature requested."}
		var id := str(item.get("id", ""))
		if not id.begins_with("blob." + str(item.type) + ".") or seen.has(id):
			return {"error": "Invalid or duplicate Blob identity slot."}
		if not item.get("direction") is Array or item.direction.size() != 3:
			return {"error": "Invalid Blob identity direction."}
		var length_squared := 0.0
		for axis in item.direction:
			if not (axis is int or axis is float) or not is_finite(float(axis)):
				return {"error": "Non-finite Blob identity direction."}
			length_squared += float(axis) * float(axis)
		if length_squared < 0.01: return {"error": "Zero Blob identity direction."}
		if item.type == "cavity":
			var parent: String = str(item.get("host_feature_id", ""))
			if not seen.has(parent) or seen[parent] != "sac" or item.stage != 3:
				return {"error": "A cavity must follow its present parent sac; body cavities are unsupported."}
		elif item.get("host_region") not in REGIONS:
			return {"error": "Unknown Blob identity attachment region."}
		if item.type != "tendril" and item.stage != 3:
			return {"error": "Only tendrils may be added at stage6."}
		var factor: Variant = item.get("length_multiplier") if item.type == "tendril" else item.get("scale_multiplier")
		if not (factor is int or factor is float) or not is_finite(float(factor)) or float(factor) < 0.65 or float(factor) > 1.2:
			return {"error": "Blob identity scale exceeds bounded authoring range."}
		seen[id] = item.type
		actual[item.type] += 1
		if item.type == "tendril": actual["primary_tendril" if item.stage == 3 else "secondary_tendril"] += 1
	if actual != profile.counts or actual.sac > MAX_SACS or actual.cavity > MAX_CAVITIES or actual.tendril > MAX_TENDRILS or actual.primary_tendril > 3 or actual.secondary_tendril > 2:
		return {"error": "Blob identity counts are false or outside the bounded feature budget."}
	if profile.profile==POSITIVE and (actual.sac!=3 or actual.cavity!=0 or actual.tendril!=0 or profile.get("seed")!=22 or profile.get("secondary_enabled")!=false):return {"error":"206 positive identity cannot include unsupported features."}
	return {"ok": true}
