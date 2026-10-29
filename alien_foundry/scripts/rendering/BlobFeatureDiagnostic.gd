extends RefCounted
## Scene-only diagnostic adapter. It consumes construction-time feature IDs and
## retained influence buffers. It never infers biological identities from shape,
## regenerates a surface, or writes into the final material arrays.
const Direct = preload("res://alien_foundry/scripts/pipeline/BlobDirectSurfacePipeline.gd")
const Modules = preload("res://alien_foundry/scripts/assets/ModuleLibrary.gd")
const CATEGORY_COLORS := {
	"body": Color("dfc76d"), "sac": Color("d96b87"), "tendril": Color("68ca82"),
	"membrane": Color("65bce0"), "porous": Color("b771dc"), "cavity": Color("f39455"),
	"face": Color("e58da0"), "growth": Color("47b5a1"), "limb": Color("969fe8")
}
const CATEGORY_LABELS := {
	"body": "Main body", "sac": "Swollen sac", "tendril": "Tendril / vine",
	"membrane": "Membrane", "porous": "Porous structure", "cavity": "Cavity / hole",
	"face": "Face / head", "growth": "Hardened growth", "limb": "Leg / limb"
}
const UNCOVERED_COLOR := Color("454b55")
const INFLUENCE_NOTE := "Up to four retained component influences per vertex. Total overlap is unknown; these are heuristic anatomical weights, not exact SDF derivatives."
const DIAGNOSTIC_SHADER := """shader_type spatial;
render_mode unshaded, cull_back;
uniform bool influence_mode = false;
uniform float selected_feature_mask[512];
uniform vec4 selected_color : source_color = vec4(1.0);
varying float selected_weight;
float membership(float feature_index) {
	int i = int(feature_index);
	return i >= 0 && i < 512 ? selected_feature_mask[i] : 0.0;
}
void vertex() {
	vec4 selected = vec4(membership(CUSTOM0.x), membership(CUSTOM0.y), membership(CUSTOM0.z), membership(CUSTOM0.w));
	selected_weight = clamp(dot(selected, CUSTOM1), 0.0, 1.0);
}
void fragment() {
	ALBEDO = influence_mode ? mix(vec3(0.055, 0.065, 0.085), selected_color.rgb, selected_weight) : COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

static func registry(stage: Dictionary) -> Array:
	return stage.get("dna", {}).get("biological_blueprint", {}).get("features", [])

static func feature_lookup(stage: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for feature: Dictionary in registry(stage):
		result[str(feature.get("id", ""))] = feature
	return result

static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, UNCOVERED_COLOR)

static func category_label(category: String) -> String:
	return str(CATEGORY_LABELS.get(category, "Unknown category: " + category))

static func feature_label(feature: Dictionary) -> String:
	return "Surface vascular fiber" if feature.get("tissue") == "vascular_fibrous" else category_label(str(feature.get("type", "")))

static func feature_color(feature: Dictionary) -> Color:
	return Color("b75263") if feature.get("tissue") == "vascular_fibrous" else category_color(str(feature.get("type", "")))

static func influence_note(stage: Dictionary) -> String:
	return INFLUENCE_NOTE + (" Dark-rose vascular fibers instead carry authoritative branch ownership; their host attachment weights are separate." if Direct.enabled(stage.get("dna", {})) else "")

static func realization(stage: Dictionary, feature_id: String) -> Dictionary:
	return Direct.runtime_realization(stage, feature_id)

static func build(stage: Dictionary) -> Dictionary:
	var features: Dictionary = feature_lookup(stage)
	if features.is_empty():
		return {"error": "Biological feature metadata is unavailable. No identities were inferred from the finished mesh."}
	var root := Node3D.new()
	root.name = "BiologicalFeatureMap"
	var report := {"surfaces": 0, "vertices": 0, "uncovered_vertices": 0, "overlap_vertices": 0, "max_retained_influences": 0, "influence_note": influence_note(stage)}
	var entries: Array = []
	var shader := Shader.new()
	shader.code = DIAGNOSTIC_SHADER
	var geometry: Dictionary = stage.get("mesh_data", {})
	var problem: String = _append_diagnostic(root, geometry, features, shader, entries, report)
	if problem.is_empty():
		for detail: Dictionary in geometry.get("detail_meshes", []):
			problem = _append_diagnostic(root, detail, features, shader, entries, report)
			if not problem.is_empty(): break
	if problem.is_empty():
		problem = append_modules(root, stage, null, features, shader, entries, report)
	if not problem.is_empty():
		root.free()
		return {"error": problem}
	if int(report.vertices) == 0:
		root.free()
		return {"error": "This feature map has no retained surface geometry."}
	root.set_meta("diagnostic_entries", entries)
	root.set_meta("diagnostic_report", report)
	root.set_meta("feature_registry", features)
	return {"root": root, "report": report}

static func selected_feature_ids(features: Dictionary, selected_id: String, descendants: bool) -> Dictionary:
	var selected: Dictionary = {}
	if not features.has(selected_id): return selected
	var pending: Array = [selected_id]
	while not pending.is_empty():
		var id: String = str(pending.pop_back())
		if selected.has(id) or not features.has(id): continue
		selected[id] = true
		if descendants: pending.append_array(features[id].get("children", []))
	return selected

static func set_selection(root: Node3D, mode: String, selected_id: String, descendants: bool = false) -> void:
	var features: Dictionary = root.get_meta("feature_registry", {})
	var feature: Dictionary = features.get(selected_id, {})
	var tint: Color = feature_color(feature)
	var selection: Dictionary = selected_feature_ids(features, selected_id, descendants)
	for entry: Dictionary in root.get_meta("diagnostic_entries", []):
		var material: ShaderMaterial = entry.material
		var ids: PackedStringArray = entry.feature_ids
		var mask := PackedFloat32Array()
		mask.resize(512)
		for i: int in range(mini(ids.size(), 512)):
			if selection.has(ids[i]): mask[i] = 1.0
		material.set_shader_parameter("influence_mode", mode == "influence")
		material.set_shader_parameter("selected_feature_mask", mask)
		material.set_shader_parameter("selected_color", tint)
	root.set_meta("diagnostic_mode", mode)
	root.set_meta("selected_feature_id", selected_id)
	root.set_meta("include_descendants", descendants)
	root.set_meta("selected_feature_ids", selection.keys())

static func _append_diagnostic(parent: Node3D, geometry: Dictionary, features: Dictionary, shader: Shader, entries: Array, report: Dictionary, shape_names: Array = [], morphs: Array = []) -> String:
	var vertices: PackedVector3Array = geometry.get("vertices", PackedVector3Array())
	if vertices.is_empty(): return ""
	var ids: PackedStringArray = geometry.get("feature_ids", PackedStringArray())
	var indices: PackedInt32Array = geometry.get("feature_indices", PackedInt32Array())
	var weights: PackedFloat32Array = geometry.get("feature_weights", PackedFloat32Array())
	var stride: int = int(geometry.get("feature_influence_stride", geometry.get("feature_influence_slots", 4)))
	if stride != 4 or ids.is_empty() or ids.size() > 512 or indices.size() != vertices.size() * 4 or weights.size() != indices.size():
		return "A retained surface is missing its four-slot feature provenance. No replacement identities were guessed."
	for id: String in ids:
		if not features.has(id): return "A retained surface refers to an unknown biological feature: " + id
	var colors := PackedColorArray()
	var float_ids := PackedFloat32Array()
	colors.resize(vertices.size())
	float_ids.resize(indices.size())
	var uncovered := 0
	var overlaps := 0
	var maximum := 0
	for vertex: int in range(vertices.size()):
		var best_weight := 0.0
		var best_id := -1
		var count := 0
		for slot: int in range(4):
			var offset: int = vertex * 4 + slot
			var feature_index: int = indices[offset]
			var weight: float = weights[offset]
			if not is_finite(weight) or weight < 0.0 or weight > 1.00001:
				return "A retained biological influence has an invalid weight."
			if weight > 0.0 and (feature_index < 0 or feature_index >= ids.size()):
				return "A retained biological influence has an invalid feature index."
			float_ids[offset] = float(feature_index)
			if weight > 0.000001:
				count += 1
				if weight > best_weight:
					best_weight = weight
					best_id = feature_index
		maximum = maxi(maximum, count)
		if count == 0: uncovered += 1
		if count > 1: overlaps += 1
		colors[vertex] = feature_color(features[ids[best_id]]) if best_id >= 0 else UNCOVERED_COLOR
	var arrays: Array = geometry_arrays(geometry)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_CUSTOM0] = float_ids
	arrays[Mesh.ARRAY_CUSTOM1] = weights
	var flags: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	for shape_name: String in shape_names: mesh.add_blend_shape(shape_name)
	var typed_morphs: Array[Array] = []
	for morph: Array in morphs: typed_morphs.append(morph)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, typed_morphs, {}, flags)
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "FeatureProvenanceSurface"
	instance.mesh = mesh
	parent.add_child(instance)
	entries.append({"material": material, "feature_ids": ids, "mesh": instance})
	report.surfaces = int(report.surfaces) + 1
	report.vertices = int(report.vertices) + vertices.size()
	report.uncovered_vertices = int(report.uncovered_vertices) + uncovered
	report.overlap_vertices = int(report.overlap_vertices) + overlaps
	report.max_retained_influences = maxi(int(report.max_retained_influences), maximum)
	return ""

static func geometry_arrays(geometry: Dictionary) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry.get("vertices", PackedVector3Array())
	arrays[Mesh.ARRAY_NORMAL] = geometry.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_INDEX] = geometry.get("indices", PackedInt32Array())
	return arrays

static func append_clay(parent: Node3D, geometry: Dictionary, material: Material, shape_names: Array = [], morphs: Array = []) -> void:
	if geometry.get("vertices", PackedVector3Array()).is_empty(): return
	var mesh := ArrayMesh.new()
	for shape_name: String in shape_names: mesh.add_blend_shape(shape_name)
	var typed_morphs: Array[Array] = []
	for morph: Array in morphs: typed_morphs.append(morph)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, geometry_arrays(geometry), typed_morphs)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "PreservedUnriggedGeometry"
	instance.mesh = mesh
	parent.add_child(instance)

static func append_modules(root: Node3D, stage: Dictionary, material: Material, features: Dictionary = {}, shader: Shader = null, entries: Array = [], report: Dictionary = {}) -> String:
	var prepared: Dictionary = stage.get("module_meshes", {})
	for spec: Dictionary in stage.get("module_specs", []):
		var module_id: String = str(spec.get("id", ""))
		var data: Dictionary = prepared.get(module_id, {})
		if data.is_empty() or not bool(data.get("accessories_prepared", false)):
			return "Retained module geometry is incomplete: " + module_id
		var module := Node3D.new()
		module.name = module_id.replace(":", "_").replace("/", "_")
		module.transform = module_transform(spec)
		module.set_meta("module_asset", str(spec.get("asset", "")))
		root.add_child(module)
		var parts: Array = [data]
		parts.append_array(data.get("accessories", []))
		for part: Dictionary in parts:
			for surface: Dictionary in part.get("surfaces", []):
				var arrays: Array = surface.get("arrays", [])
				if arrays.size() != Mesh.ARRAY_MAX: return "A retained module surface is unavailable: " + module_id
				var geometry: Dictionary = surface.duplicate()
				geometry["vertices"] = arrays[Mesh.ARRAY_VERTEX]
				geometry["normals"] = arrays[Mesh.ARRAY_NORMAL]
				geometry["indices"] = arrays[Mesh.ARRAY_INDEX]
				if shader != null:
					var problem: String = _append_diagnostic(module, geometry, features, shader, entries, report, part.get("shape_names", []), surface.get("morphs", []))
					if not problem.is_empty(): return problem
				else:
					append_clay(module, geometry, material, part.get("shape_names", []), surface.get("morphs", []))
		Modules.set_deformation(module, spec.get("deformation", {}))
	return ""

static func module_transform(spec: Dictionary) -> Transform3D:
	# Mirrors the retained renderer's coordinate convention, without invoking
	# loading, conformation or procedural accessory generation.
	var normal: Vector3 = Modules._vector(spec.get("normal", [0, 0, 1]), Vector3(0, 0, 1)).normalized()
	if normal.length_squared() < 0.01: normal = Vector3(0, 0, 1)
	var up: Vector3 = Modules._vector(spec.get("up", [0, 1, 0]), Vector3.UP).normalized()
	up -= normal * up.dot(normal)
	if up.length_squared() < 0.01:
		up = Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
		up -= normal * up.dot(normal)
	up = up.normalized()
	var right: Vector3 = up.cross(normal).normalized()
	var size_value: Vector3 = Modules._vector(spec.get("scale", [1, 1, 1]), Vector3.ONE)
	size_value = Vector3(maxf(0.005, absf(size_value.x)), maxf(0.005, absf(size_value.y)), maxf(0.005, absf(size_value.z)))
	return Transform3D(Basis(right * size_value.x, up * size_value.y, normal * size_value.z), Modules._vector(spec.get("position", [0, 0, 0]), Vector3.ZERO))
