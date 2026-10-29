extends RefCounted
## Intrinsic organism-to-asset placement, independent of actor world placement.
## All source geometry, material coordinates and bind poses remain local.
const SETTING := "blob_ground_placement"
const PROFILE := "complete_mesh_min_y_v1"
const VERSION := 1
const Modules = preload("res://alien_foundry/scripts/assets/ModuleLibrary.gd")

static func enabled(dna: Dictionary) -> bool:
	return str(dna.get("settings", {}).get(SETTING, "")) == PROFILE

static func _hex(value: float) -> String:
	var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0, value)
	return bytes.hex_encode()

static func _number(value: Variant) -> Dictionary:
	if not value is String or value.length() != 16: return {"error": "Invalid exact placement number."}
	var bytes: PackedByteArray = value.hex_decode()
	if bytes.size() != 8 or bytes.hex_encode() != value: return {"error": "Non-canonical exact placement number."}
	var number: float = bytes.decode_double(0)
	if not is_finite(number) or absf(number) > 10000.0: return {"error": "Non-finite or unbounded placement number."}
	return {"value": number}

static func _digest(value: Dictionary) -> String:
	var payload := value.duplicate(true); payload.erase("placement_key")
	# JSON reload may type integral enum values as floats. These fields are
	# validated exact integers; physical quantities remain exact hex strings.
	for field: String in ["version", "reference_stage", "reference_quality"]:
		if payload.has(field): payload[field] = int(payload[field])
	return JSON.stringify(payload, "", true, true).sha256_text()

static func validate_declaration(dna: Dictionary) -> Dictionary:
	var mode: Variant = dna.get("settings", {}).get(SETTING, "")
	if not mode is String or mode not in ["", "off", PROFILE]: return {"ok": false, "error": "Unsupported explicit Blob ground placement profile."}
	if mode == PROFILE and (str(dna.get("type", "")) != "Blob" or str(dna.get("settings", {}).get("blob_pipeline_mode", "")) != "iterative_v2"):
		return {"ok": false, "error": "Complete-mesh ground placement requires iterative Blob anatomy."}
	if dna.has("asset_placement"):
		if mode != PROFILE: return {"ok": false, "error": "Saved placement conflicts with its explicit placement profile."}
		return validate_record(dna.asset_placement, int(dna.settings.get("quality", -1)))
	if mode == PROFILE and dna.has("pipeline"):
		return {"ok": false, "error": "A completed placed organism is missing its preserved placement record."}
	return {"ok": true}

static func validate_record(value: Variant, quality: int, reference_key: String = "") -> Dictionary:
	if not value is Dictionary: return {"ok": false, "error": "Placement record must be an object."}
	var expected := ["version", "profile", "reference_stage", "reference_quality", "reference_geometry_key", "reference_mesh_sha256", "minimum_y_f64_hex", "translation_y_f64_hex", "placement_key"]
	if value.size() != expected.size(): return {"ok": false, "error": "Unsupported placement record fields."}
	for field: String in expected:
		if not value.has(field): return {"ok": false, "error": "Missing placement record field: " + field}
	for field: String in ["version", "reference_stage", "reference_quality"]:
		if not (value[field] is int or value[field] is float) or not is_finite(float(value[field])) or float(value[field]) != float(int(value[field])):
			return {"ok": false, "error": "Placement enum must be an exact finite integer."}
	if value.version != VERSION or value.profile != PROFILE or value.reference_stage != 6 or value.reference_quality != quality or quality not in [0, 1, 2]:
		return {"ok": false, "error": "Unsupported placement version, reference stage or quality."}
	for field: String in ["reference_geometry_key", "reference_mesh_sha256", "placement_key"]:
		if not value[field] is String or value[field].length() != 64 or value[field].hex_decode().size() != 32 or value[field].hex_decode().hex_encode() != value[field]:
			return {"ok": false, "error": "Invalid placement identity: " + field}
	if not reference_key.is_empty() and value.reference_geometry_key != reference_key: return {"ok": false, "error": "Placement refers to different completed geometry."}
	var minimum := _number(value.minimum_y_f64_hex); var translation := _number(value.translation_y_f64_hex)
	if minimum.has("error") or translation.has("error"): return {"ok": false, "error": "Invalid exact placement minimum/translation."}
	if _hex(-float(minimum.value)) != value.translation_y_f64_hex: return {"ok": false, "error": "Placement translation does not cancel its exact reference minimum."}
	if _digest(value) != value.placement_key: return {"ok": false, "error": "Placement identity does not match its contents."}
	return {"ok": true}

static func transform_for(record: Dictionary) -> Transform3D:
	if record.is_empty(): return Transform3D.IDENTITY
	var decoded := _number(record.get("translation_y_f64_hex"))
	if decoded.has("error"): return Transform3D.IDENTITY
	return Transform3D(Basis.IDENTITY, Vector3(0.0, float(decoded.value), 0.0))

static func asset_point(record: Dictionary, organism_point: Vector3) -> Vector3:
	return transform_for(record) * organism_point

static func _module_transform(spec: Dictionary) -> Transform3D:
	var normal: Vector3 = Modules._vector(spec.get("normal", [0, 0, 1]), Vector3.BACK).normalized()
	if normal.length_squared() < 0.01: normal = Vector3.BACK
	var up: Vector3 = Modules._vector(spec.get("up", [0, 1, 0]), Vector3.UP).normalized()
	up -= normal * up.dot(normal)
	if up.length_squared() < 0.01:
		up = Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
		up -= normal * up.dot(normal)
	up = up.normalized()
	var scale_value: Vector3 = Modules._vector(spec.get("scale", [1, 1, 1]), Vector3.ONE)
	scale_value = Vector3(maxf(0.005, absf(scale_value.x)), maxf(0.005, absf(scale_value.y)), maxf(0.005, absf(scale_value.z)))
	return Transform3D(Basis(up.cross(normal).normalized() * scale_value.x, up * scale_value.y, normal * scale_value.z), Modules._vector(spec.get("position", [0, 0, 0]), Vector3.ZERO))

static func _module_weights(spec: Dictionary, data: Dictionary) -> Array:
	var values: Dictionary = spec.get("deformation", {}).duplicate(true)
	var asset := str(spec.get("asset", ""))
	if values.has("opening"): values["eye_open" if asset.begins_with("eye_") else "mouth_open"] = values.opening
	if values.has("nose") and not values.has("nose_projection"): values["nose_projection"] = values.nose
	var ranges: Dictionary = Modules.asset_info(asset).get("deformations", {})
	var result: Array = []
	for shape_name in data.get("shape_names", []):
		var limits: Dictionary = ranges.get(shape_name, {"min": -1.0, "max": 1.0})
		result.append(clampf(float(values.get(shape_name, 0.0)), float(limits.get("min", -1.0)), float(limits.get("max", 1.0))))
	return result

static func _consume(points: PackedVector3Array, indices: PackedInt32Array, frame: Transform3D, label: String, state: Dictionary) -> void:
	if points.is_empty(): state["error"] = "Missing complete placement surface: " + label; return
	var referenced := PackedByteArray(); referenced.resize(points.size())
	if indices.is_empty():
		if points.size() % 3 != 0: state["error"] = "Non-indexed placement surface is not complete triangles."; return
		referenced.fill(1)
	else:
		if indices.size() % 3 != 0: state["error"] = "Indexed placement surface is not complete triangles."; return
		for index: int in indices:
			if index < 0 or index >= points.size(): state["error"] = "Placement surface has invalid triangle indices."; return
			referenced[index] = 1
	var actual := PackedVector3Array(); actual.resize(points.size())
	for i in range(points.size()):
		var p: Vector3 = frame * points[i]
		if not p.is_finite(): state["error"] = "Non-finite complete placement vertex."; return
		actual[i] = p
		if referenced[i] != 0: state.minimum_y = minf(float(state.minimum_y), p.y)
	state.context.update(label.to_utf8_buffer())
	state.context.update(actual.to_byte_array())
	state.context.update(indices.to_byte_array())
	state.vertices += points.size()

static func _consume_module(data: Dictionary, spec: Dictionary, frame: Transform3D, label: String, state: Dictionary) -> void:
	var weights: Array = _module_weights(spec, data)
	var relative: bool = int(data.get("blend_shape_mode", Mesh.BLEND_SHAPE_MODE_NORMALIZED)) == Mesh.BLEND_SHAPE_MODE_RELATIVE
	for index in range(data.get("surfaces", []).size()):
		var surface: Dictionary = data.surfaces[index]
		var arrays: Array = surface.get("arrays", [])
		if arrays.size() <= Mesh.ARRAY_INDEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: state["error"] = "Incomplete prepared module surface."; return
		var base: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var points := base.duplicate()
		for morph in range(weights.size()):
			if float(weights[morph]) == 0.0: continue
			if morph >= surface.get("morphs", []).size(): state["error"] = "Missing prepared module rest morph."; return
			var target: PackedVector3Array = surface.morphs[morph][Mesh.ARRAY_VERTEX]
			if target.size() != points.size(): state["error"] = "Mismatched prepared module rest morph."; return
			for i in range(points.size()): points[i] += float(weights[morph]) * (target[i] if relative else target[i] - base[i])
		_consume(points, arrays[Mesh.ARRAY_INDEX], frame, label + "/surface" + str(index), state)
		if state.has("error"): return
	for index in range(data.get("accessories", []).size()):
		_consume_module(data.accessories[index], spec, frame, label + "/accessory" + str(index), state)
		if state.has("error"): return

static func inspect_complete(geometry: Dictionary, prepared: Dictionary = {}) -> Dictionary:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	var state := {"context": context, "minimum_y": INF, "vertices": 0}
	_consume(geometry.get("vertices", PackedVector3Array()), geometry.get("indices", PackedInt32Array()), Transform3D.IDENTITY, "body", state)
	if state.has("error"): return {"error": state.error}
	for i in range(geometry.get("detail_meshes", []).size()):
		var detail: Dictionary = geometry.detail_meshes[i]
		_consume(detail.get("vertices", PackedVector3Array()), detail.get("indices", PackedInt32Array()), Transform3D.IDENTITY, "detail" + str(i), state)
		if state.has("error"): return {"error": state.error}
	for spec: Dictionary in prepared.get("module_specs", []):
		var id := str(spec.get("id", ""))
		var module: Dictionary = prepared.get("module_meshes", {}).get(id, {})
		if module.get("surfaces", []).is_empty() or not bool(module.get("accessories_prepared", false)):
			return {"error": "Ground placement requires complete prepared module geometry: " + id}
		_consume_module(module, spec, _module_transform(spec), "module/" + id, state)
		if state.has("error"): return {"error": state.error}
	return {"minimum_y": state.minimum_y, "vertices": state.vertices, "mesh_sha256": context.finish().hex_encode()}

static func resolve(dna: Dictionary, geometry: Dictionary, prepared: Dictionary, reference_key: String) -> Dictionary:
	var declaration := validate_declaration(dna)
	if not bool(declaration.get("ok", false)): return {"error": declaration.error}
	if not enabled(dna): return {"record": {}}
	var measured := inspect_complete(geometry, prepared)
	if measured.has("error"): return measured
	var record := {"version": VERSION, "profile": PROFILE, "reference_stage": 6, "reference_quality": int(dna.settings.quality),
		"reference_geometry_key": reference_key, "reference_mesh_sha256": measured.mesh_sha256,
		"minimum_y_f64_hex": _hex(float(measured.minimum_y)), "translation_y_f64_hex": _hex(-float(measured.minimum_y))}
	record["placement_key"] = _digest(record)
	if dna.has("asset_placement") and dna.asset_placement.placement_key != record.placement_key:
		return {"error": "Saved intrinsic placement no longer matches its completed reference mesh. The saved frame was not changed.", "error_code": "stale_blob_ground_placement"}
	return {"record": record, "measurement": measured}

static func stage_report(stage: Dictionary, record: Dictionary) -> Dictionary:
	var measured := inspect_complete(stage.mesh_data, {"module_specs": stage.get("module_specs", []), "module_meshes": stage.get("module_meshes", {})})
	if measured.has("error"): return measured
	var shift: float = transform_for(record).origin.y
	return {"reference_stage": 6, "raw_min_y": measured.minimum_y, "placed_min_y": float(measured.minimum_y) + shift,
		"placement_key": record.get("placement_key", ""), "frame": "shared_organism_to_asset", "independently_regrounded": false}
