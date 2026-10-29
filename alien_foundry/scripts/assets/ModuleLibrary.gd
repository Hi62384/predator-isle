class_name ModuleLibrary
extends RefCounted
## Reusable anatomical modules: worker-safe numerical preparation below, with
## scene/resource construction on main. Coordinates: +X right, +Y up, +Z outward.
## Full-shell faces preserve authored skull anchors; other modules conform to
## sampled carrier tissue. See the manifest mounting profile and library README.
const MANIFEST_PATH: String = "res://alien_foundry/assets/modular_anatomy/manifest.json"
static var _manifest: Dictionary = {}
static var _scenes: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if value is Dictionary:
			_manifest = value
	return _manifest

static func available_assets() -> Array:
	return manifest().get("modules", {}).keys()

static func asset_info(asset: String) -> Dictionary:
	return manifest().get("modules", {}).get(asset, {})

static func attachment_transition(asset: String) -> Dictionary:
	## Authored mesh-local insertion mask, independent of runtime scale/bones.
	var profile: Dictionary = asset_info(asset).get("attachment", {}).get("transition", {})
	var mode: String = str(profile.get("mode", ""))
	if mode not in ["posterior_z", "wrist_y"]:
		return {}
	return {"axis": 2 if mode == "posterior_z" else 1,
		"range": [float(profile.host_weight_one), float(profile.host_weight_zero)],
		"toward_low": true}

static func _vector(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is float or value is int:
		return Vector3.ONE * float(value)
	return fallback

static func _load_scene(asset: String) -> PackedScene:
	if _scenes.has(asset):
		return _scenes[asset]
	var info: Dictionary = asset_info(asset)
	if info.is_empty():
		push_error("Unknown anatomical module: " + asset)
		return null
	var path: String = str(info.get("path", ""))
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is PackedScene:
			_scenes[asset] = resource
			return resource
	# Runtime GLTF parsing also supports command-line tests before an editor import.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error: Error = document.append_from_file(path, state)
	if error != OK:
		push_error("Cannot load anatomical GLB %s (error %s)" % [path, error])
		return null
	var scene: Node = document.generate_scene(state)
	if scene == null:
		return null
	var packed := PackedScene.new()
	var packed_error: Error = packed.pack(scene)
	scene.free()
	if packed_error != OK:
		return null
	_scenes[asset] = packed
	return packed

static func instantiate_module(spec: Dictionary) -> Node3D:
	var asset: String = str(spec.get("asset", spec.get("module", "")))
	var packed: PackedScene = _load_scene(asset)
	if packed == null:
		return null
	var root := Node3D.new()
	root.name = str(spec.get("id", asset)).replace(":", "_").replace("/", "_")
	var child: Node = packed.instantiate()
	root.add_child(child)
	var prepared: Dictionary = spec.get("prepared_surfaces", {})
	var grid: Dictionary = spec.get("surface_grid", {}).duplicate()
	if bool(spec.get("full_shell", false)) or str(spec.get("mounting", "")) == "craniofacial": grid = {}
	if not grid.is_empty():
		grid["module_asset"] = asset
	if not prepared.is_empty():
		_apply_prepared_tree(child, prepared)
		root.set_meta("carrier_conformed", true)
	elif not grid.is_empty():
		_conform_tree(child, Transform3D.IDENTITY, grid)
		root.set_meta("carrier_conformed", true)
	# Strict staged geometry is complete before the armature. Upload the retained
	# accessory arrays without rebuilding, morphing or conforming them here.
	if bool(prepared.get("accessories_prepared", false)):
		for accessory: Dictionary in prepared.get("accessories", []):
			child.add_child(_upload_prepared_accessory(accessory))
		root.set_meta("accessories_prepared", true)
		root.set_meta("prepared_accessory_geometry", true)
		root.set_meta("prepared_accessory_triangles", prepared_accessory_triangles(prepared))
	else:
		# Legacy direct instantiation remains available to non-staged callers.
		if asset in ["mouth_animal", "mouth_radial"] and bool(spec.get("teeth", true)):
			var teeth: MeshInstance3D = _procedural_teeth(asset, spec)
			child.add_child(teeth)
			if not grid.is_empty():
				_conform_tree(teeth, Transform3D.IDENTITY, grid)
		if asset == "face_neutral" and bool(spec.get("oral_anatomy", true)):
			for oral: MeshInstance3D in _procedural_facial_oral(spec): child.add_child(oral)
		if asset.begins_with("face_") and bool(spec.get("lens", true)):
			var eyes: MeshInstance3D = _procedural_face_eyes(asset)
			child.add_child(eyes)
			if not grid.is_empty():
				var optical_grid: Dictionary = grid.duplicate()
				optical_grid["skip_normal_feather"] = true
				_conform_tree(eyes, Transform3D.IDENTITY, optical_grid)
		if asset.begins_with("eye_") and bool(spec.get("lens", true)):
			var lens: MeshInstance3D = _procedural_lens(asset)
			child.add_child(lens)
			if not grid.is_empty():
				_conform_tree(lens, Transform3D.IDENTITY, grid)
	var normal: Vector3 = _vector(spec.get("normal", [0, 0, 1]), Vector3.FORWARD * -1.0).normalized()
	if normal.length_squared() < 0.01:
		normal = Vector3(0, 0, 1)
	var up: Vector3 = _vector(spec.get("up", [0, 1, 0]), Vector3.UP).normalized()
	up = up - normal * up.dot(normal)
	if up.length_squared() < 0.01:
		up = Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
		up = up - normal * up.dot(normal)
	up = up.normalized()
	var right: Vector3 = up.cross(normal).normalized()
	var scale_value: Vector3 = _vector(spec.get("scale", [1, 1, 1]), Vector3.ONE)
	# Avoid mirrored or singular attachment bases, while allowing nonuniform scale.
	scale_value = Vector3(maxf(0.005, absf(scale_value.x)), maxf(0.005, absf(scale_value.y)), maxf(0.005, absf(scale_value.z)))
	root.transform = Transform3D(Basis(right * scale_value.x, up * scale_value.y, normal * scale_value.z), _vector(spec.get("position", [0, 0, 0]), Vector3.ZERO))
	root.set_meta("module_asset", asset)
	root.set_meta("module_spec", spec.duplicate(true))
	root.set_meta("attachment", asset_info(asset).get("attachment", {}))
	if bool(spec.get("full_shell", false)) or str(spec.get("mounting", "")) == "craniofacial":
		root.set_meta("attachment_transition", attachment_transition(asset))
	root.set_meta("deformation", spec.get("deformation", {}).duplicate(true))
	set_deformation(root, spec.get("deformation", {}))
	return root

static func mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(mesh_instances(child))
	return result

static func set_deformation(node: Node, values: Dictionary) -> void:
	var normalized: Dictionary = values.duplicate()
	var asset: String = str(node.get_meta("module_asset", ""))
	var ranges: Dictionary = asset_info(asset).get("deformations", {})
	if normalized.has("opening"):
		normalized["eye_open" if asset.begins_with("eye_") else "mouth_open"] = normalized["opening"]
	if normalized.has("nose") and not normalized.has("nose_projection"):
		normalized["nose_projection"] = normalized["nose"]
	for instance: MeshInstance3D in mesh_instances(node):
		if instance.mesh == null:
			continue
		for i in range(instance.mesh.get_blend_shape_count()):
			var shape_name: String = str(instance.mesh.get_blend_shape_name(i))
			if normalized.has(shape_name):
				var limits: Dictionary = ranges.get(shape_name, {"min": -1.0, "max": 1.0})
				instance.set_blend_shape_value(i, clampf(float(normalized[shape_name]), float(limits.get("min", -1.0)), float(limits.get("max", 1.0))))

static func set_open_amount(node: Node, amount: float) -> void:
	set_deformation(node, {"mouth_open": clampf(amount, 0.0, 1.0)})

static func apply_tissue_material(node: Node, material: Material) -> void:
	for instance: MeshInstance3D in mesh_instances(node):
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var authored: Material = instance.mesh.surface_get_material(surface)
			# Keep cavities visually recessed; tissue changes share the body palette.
			if authored == null or not (authored.resource_name.to_lower().contains("cavity") or authored.resource_name.to_lower().contains("lens") or authored.resource_name.to_lower().contains("teeth")):
				instance.set_surface_override_material(surface, material)

static func socket_world(node: Node3D, socket_id: String) -> Vector3:
	var asset: String = str(node.get_meta("module_asset", ""))
	for entry: Dictionary in asset_info(asset).get("sockets", []):
		if str(entry.get("id", "")) == socket_id:
			return node.global_transform * _vector(entry.get("position", []), Vector3.ZERO)
	return node.global_position

static func _monotone_cubic(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	# C1 Hermite interpolation with harmonic slopes. Unlike plain Catmull-Rom,
	# this cannot overshoot a carrier peak or create a raised perimeter ridge.
	var d0: float = p1 - p0
	var d1: float = p2 - p1
	var d2: float = p3 - p2
	var m1: float = 2.0 * d0 * d1 / (d0 + d1) if d0 * d1 > 0.0000000001 else 0.0
	var m2: float = 2.0 * d1 * d2 / (d1 + d2) if d1 * d2 > 0.0000000001 else 0.0
	var t2: float = t * t
	var t3: float = t2 * t
	return (2.0*t3-3.0*t2+1.0)*p1 + (t3-2.0*t2+t)*m1 + (-2.0*t3+3.0*t2)*p2 + (t3-t2)*m2

static func _sample_surface_grid(grid: Dictionary, x: float, y: float) -> float:
	var resolution: int = int(grid.get("resolution", 0))
	var heights: Variant = grid.get("heights", [])
	if resolution < 2 or heights.size() != resolution * resolution:
		return 0.0
	var width: float = maxf(float(grid.get("width", 1.6)), 0.01)
	var height: float = maxf(float(grid.get("height", 2.2)), 0.01)
	var u: float = clampf(x / width + 0.5, 0.0, 1.0) * float(resolution - 1)
	var v: float = clampf(y / height + 0.5, 0.0, 1.0) * float(resolution - 1)
	var ix: int = mini(int(floor(u)), resolution - 2)
	var iy: int = mini(int(floor(v)), resolution - 2)
	var rows: Vector4 = Vector4.ZERO
	for row in range(4):
		var offset: int = clampi(iy + row - 1, 0, resolution - 1) * resolution
		rows[row] = _monotone_cubic(float(heights[offset + maxi(ix-1,0)]), float(heights[offset + ix]), float(heights[offset + ix+1]), float(heights[offset + mini(ix+2,resolution-1)]), u-ix)
	return _monotone_cubic(rows.x,rows.y,rows.z,rows.w,v-iy)

static func _face_carrier_offset(p: Vector3, asset: String, burial: float) -> float:
	# A standalone face includes a convex cranial foundation. The carrier already
	# supplies that volume: adding both creates an oval mask above another skull.
	# Remove only the redundant broad foundation when wrapping, leaving the
	# nose, orbital rims, cheek/jaw planes and folds as true anatomical relief.
	var height: float = 1.65 if asset == "face_elongated" else 1.35
	var v: float = p.y / (0.5 * height)
	var shape: float = 1.0 - 0.19 * smoothstep(0.0,1.0,(-v-0.10)/0.75) + 0.035 * exp(-pow((v+0.12)/0.24,2.0))
	var u: float = p.x / (0.5 * shape)
	var r: float = sqrt(u*u+v*v)
	var edge: float = smoothstep(0.0,1.0,(1.0-r)/0.25)
	var foundation: float = 0.012 + 0.230 * pow(maxf(0.0,1.0-r*r),0.65)
	if asset == "face_mask": foundation = 0.0434 + 0.38 * foundation
	var perimeter: float = smoothstep(0.64,0.98,r)
	return -0.78 * foundation * edge - maxf(0.0,burial-0.046) * perimeter

static func _conformed_positions(vertices: PackedVector3Array, frame: Transform3D, grid: Dictionary) -> PackedVector3Array:
	var inverse: Transform3D = frame.affine_inverse()
	var out := PackedVector3Array()
	out.resize(vertices.size())
	var asset: String = str(grid.get("module_asset", ""))
	var face: bool = asset.begins_with("face_")
	var burial: float = float(grid.get("recommended_perimeter_burial", 0.046))
	for i in range(vertices.size()):
		var p: Vector3 = frame * vertices[i]
		# The same carrier displacement applies to all shell layers. This preserves
		# thickness and folds rather than pushing only the visible front surface.
		p.z += _sample_surface_grid(grid, p.x, p.y) - 0.018
		if face: p.z += _face_carrier_offset(p, asset, burial)
		out[i] = inverse * p
	return out

static func _carrier_feather_normals(positions: PackedVector3Array, normals: PackedVector3Array, reference: PackedVector3Array, frame: Transform3D, grid: Dictionary) -> PackedVector3Array:
	var asset: String = str(grid.get("module_asset", ""))
	if not asset.begins_with("face_") or bool(grid.get("skip_normal_feather", false)):
		return normals
	var result: PackedVector3Array = normals.duplicate()
	var height: float = 1.65 if asset == "face_elongated" else 1.35
	for i in range(positions.size()):
		if reference[i].z < 0.10: continue
		var p: Vector3 = frame * positions[i]
		var r: float = sqrt(pow(p.x/0.5,2.0)+pow(p.y/(0.5*height),2.0))
		var weight: float = smoothstep(0.73,0.96,r)
		if weight <= 0.0001: continue
		var dx: float = (_sample_surface_grid(grid,p.x+0.003,p.y)-_sample_surface_grid(grid,p.x-0.003,p.y))/0.006
		var dy: float = (_sample_surface_grid(grid,p.x,p.y+0.003)-_sample_surface_grid(grid,p.x,p.y-0.003))/0.006
		var carrier: Vector3 = (frame.basis.transposed()*Vector3(-dx,-dy,1.0)).normalized()
		result[i] = normals[i].lerp(carrier,weight).normalized()
	return result

static func _recompute_normals(vertices: PackedVector3Array, indices: PackedInt32Array, reference: PackedVector3Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for t in range(0, indices.size(), 3):
		var a: int = indices[t]
		var b: int = indices[t + 1]
		var c: int = indices[t + 2]
		var n: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if reference.size() == vertices.size() and n.dot(reference[a] + reference[b] + reference[c]) < 0.0:
			n = -n
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i in range(normals.size()):
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.000000000001 else (reference[i] if reference.size() == normals.size() else Vector3.FORWARD)
	return normals

static func _conform_mesh(source: ArrayMesh, frame: Transform3D, grid: Dictionary) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.resource_name = source.resource_name + "_CarrierConformed"
	result.blend_shape_mode = source.blend_shape_mode
	for shape in range(source.get_blend_shape_count()):
		result.add_blend_shape(source.get_blend_shape_name(shape))
	for surface in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface).duplicate(true)
		var original: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var reference: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var conformed: PackedVector3Array = _conformed_positions(original, frame, grid)
		var normals: PackedVector3Array = _carrier_feather_normals(conformed, _recompute_normals(conformed, indices, reference), reference, frame, grid)
		arrays[Mesh.ARRAY_VERTEX] = conformed
		arrays[Mesh.ARRAY_NORMAL] = normals
		# Imported tangents describe the unbent UV surface; shared tissue uses
		# procedural coordinates and does not require stale tangent attributes.
		arrays[Mesh.ARRAY_TANGENT] = null
		var shapes: Array = source.surface_get_blend_shape_arrays(surface)
		var morphed: Array[Array] = []
		for shape_arrays: Array in shapes:
			var target: Array = shape_arrays.duplicate(true)
			var positions: PackedVector3Array = target[Mesh.ARRAY_VERTEX]
			var absolute: PackedVector3Array = positions.duplicate()
			if source.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
				for i in range(absolute.size()):
					absolute[i] += original[i]
			var target_positions: PackedVector3Array = _conformed_positions(absolute, frame, grid)
			var target_normals: PackedVector3Array = _carrier_feather_normals(target_positions, _recompute_normals(target_positions, indices, reference), reference, frame, grid)
			if source.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
				for i in range(target_positions.size()):
					target_positions[i] -= conformed[i]
					target_normals[i] -= normals[i]
			target[Mesh.ARRAY_VERTEX] = target_positions
			target[Mesh.ARRAY_NORMAL] = target_normals
			target[Mesh.ARRAY_TANGENT] = null
			morphed.append(target)
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, morphed)
		result.surface_set_material(surface, source.surface_get_material(surface))
	return result

static func _conform_tree(node: Node, parent_frame: Transform3D, grid: Dictionary) -> void:
	var frame: Transform3D = parent_frame
	if node is Node3D:
		frame = parent_frame * node.transform
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		node.mesh = _conform_mesh(node.mesh, frame, grid)
		node.set_meta("carrier_conformed", true)
	for child in node.get_children():
		_conform_tree(child, frame, grid)

static func _accessory_material(name_value: String, color: Color, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name_value
	material.albedo_color = color
	material.roughness = roughness_value
	return material

static func _packed_accessory(label: String, arrays: Array, morphs: Array[Array], names: Array[String], material: Dictionary) -> Dictionary:
	# A resource-free, lossless recipe for the main-thread upload. Keep this same
	# shape as authored prepared surfaces so conformation and auditing are shared.
	return {"name": label, "shape_names": names, "blend_shape_mode": Mesh.BLEND_SHAPE_MODE_NORMALIZED,
		"material": material, "surfaces": [{"arrays": arrays, "morphs": morphs, "material_index": 0}]}

static func _upload_prepared_accessory(data: Dictionary) -> MeshInstance3D:
	# Main-thread boundary only. Never generate or conform geometry during upload.
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = int(data.get("blend_shape_mode", Mesh.BLEND_SHAPE_MODE_NORMALIZED))
	for shape_name in data.get("shape_names", []):
		mesh.add_blend_shape(str(shape_name))
	var description: Dictionary = data.get("material", {})
	var material: StandardMaterial3D = _accessory_material(str(description.get("name", "")), description.get("color", Color.WHITE), float(description.get("roughness", 1.0)))
	material.vertex_color_use_as_albedo = bool(description.get("vertex_color_use_as_albedo", false))
	material.clearcoat_enabled = bool(description.get("clearcoat_enabled", false))
	if description.has("clearcoat"): material.clearcoat = float(description.clearcoat)
	if description.has("clearcoat_roughness"): material.clearcoat_roughness = float(description.clearcoat_roughness)
	for surface: Dictionary in data.get("surfaces", []):
		var morphs: Array[Array] = []
		for target: Array in surface.get("morphs", []): morphs.append(target)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.arrays, morphs)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var instance := MeshInstance3D.new()
	instance.name = str(data.get("name", "PreparedAccessory"))
	instance.mesh = mesh
	instance.set_meta("prepared_accessory", true)
	if bool(data.get("carrier_conformed", false)): instance.set_meta("carrier_conformed", true)
	return instance

static func _clockwise_indices(vertices: PackedVector3Array, indices: PackedInt32Array, outward: PackedVector3Array) -> PackedInt32Array:
	# Godot front faces are clockwise. All accessory faces, including the
	# hemisphere bands and end caps, use the same outward orientation.
	var result: PackedInt32Array = indices.duplicate()
	for t in range(0, result.size(), 3):
		var a: int = result[t]
		var b: int = result[t + 1]
		var c: int = result[t + 2]
		if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(outward[a] + outward[b] + outward[c]) > 0.0:
			result[t + 1] = c
			result[t + 2] = b
	return result

static func _accessory_deformed(vertices: PackedVector3Array, shape_name: String) -> PackedVector3Array:
	# Same additive authoring deformation as the surrounding source module.
	var result: PackedVector3Array = vertices.duplicate()
	for i in range(result.size()):
		var p: Vector3 = result[i]
		match shape_name:
			"width": p.x *= 1.35
			"height": p.y *= 1.35
			"curvature": p.z += 0.22 * (p.x * p.x + p.y * p.y)
			"mouth_width": p.x *= 1.0 + 0.35 * exp(-pow(p.x / 0.35, 2.0) - pow(p.y / 0.12, 2.0))
			"asymmetry":
				var x: float = p.x
				p.x += 0.07 * exp(-pow((x - 0.05) / 0.55, 2.0) - pow((p.y - 0.05) / 0.60, 2.0))
				p.y += 0.035 * exp(-pow((p.x + 0.20) / 0.18, 2.0) - pow((p.y - 0.05) / 0.4, 2.0))
		result[i] = p
	return result

static func _accessory_morphs(vertices: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array, names: Array[String], opening: PackedVector3Array = PackedVector3Array()) -> Array[Array]:
	var result: Array[Array] = []
	for shape_name: String in names:
		var positions: PackedVector3Array = opening if shape_name == "mouth_open" else _accessory_deformed(vertices, shape_name)
		var target: Array = []
		target.resize(Mesh.ARRAY_MAX)
		target[Mesh.ARRAY_VERTEX] = positions
		target[Mesh.ARRAY_NORMAL] = _recompute_normals(positions, indices, normals)
		result.append(target)
	return result

static func _procedural_teeth(asset: String, spec: Dictionary) -> MeshInstance3D:
	return _upload_prepared_accessory(_packed_teeth(asset, spec))

static func _packed_teeth(asset: String, spec: Dictionary) -> Dictionary:
	var radial: bool = asset == "mouth_radial"
	var count: int = clampi(int(spec.get("tooth_count", 14 if radial else 12)), 4, 24)
	var vertices := PackedVector3Array()
	var opened := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var sides: int = 7
	var rings: int = 5
	for tooth in range(count):
		var start := Vector3.ZERO
		var direction := Vector3.DOWN
		var variation: float = 0.88 + 0.22 * sin(float(tooth * 7 + count) * 1.17)
		if radial:
			var angle: float = TAU * float(tooth) / count + 0.13
			var lobe: float = 1.0 + 0.035 * cos(angle * 7.0) + 0.022 * sin(angle * 3.0)
			# Roots follow ring 5, beneath its wet lip surface, never on the flange.
			start = Vector3(0.238 * cos(angle) * lobe, 0.238 * 0.87 * sin(angle) * lobe, 0.112 + 0.009 * cos(angle * 3.0) + 0.004 * sin(angle * 5.0))
			direction = Vector3(-cos(angle), -sin(angle), 0.24).normalized()
		else:
			var per_row: int = int(ceil(count / 2.0))
			var row: int = tooth / per_row
			var index: int = tooth % per_row
			var x: float = lerpf(-0.185, 0.185, float(index) / maxf(1.0, per_row - 1.0))
			var sign_value: float = 1.0 if row == 0 else -1.0
			var angle: float = acos(x / 0.24) * sign_value
			start = Vector3(x, 0.051 * 1.12 * sin(angle) + 0.025 * cos(angle * 2.0), 0.13 * 1.15 - 0.018 + 0.009 * cos(angle * 3.0) + 0.004 * sin(angle * 5.0))
			direction = Vector3(-x * 0.6, -sign_value, 0.24).normalized()
		# A tooth translates with its root during opening rather than stretching.
		var opening_offset := Vector3(start.x * (0.27 if radial else 0.0), start.y * (0.27 if radial else 2.2), -0.020)
		var right: Vector3 = direction.cross(Vector3.FORWARD).normalized()
		var up: Vector3 = direction.cross(right).normalized()
		var radius: float = 0.009 * variation
		var length: float = (0.082 if radial else 0.058) * variation
		var offset: int = vertices.size()
		for ring in range(rings):
			var t: float = float(ring) / float(rings)
			var center: Vector3 = start + direction * length * t + Vector3(0,0,0.012) * t * t
			for side in range(sides):
				var angle: float = TAU * float(side) / sides
				var normal: Vector3 = right * cos(angle) + up * sin(angle)
				var p: Vector3 = center + normal * radius * pow(1.0 - t, 0.7)
				vertices.append(p)
				opened.append(p + opening_offset)
				normals.append(normal)
				uvs.append(Vector2(float(side)/sides,t))
		for ring in range(rings - 1):
			for side in range(sides):
				var a: int = offset + ring * sides + side
				var b: int = offset + ring * sides + (side + 1) % sides
				indices.append_array(PackedInt32Array([a,b,a+sides,b,b+sides,a+sides]))
		var tip: int = vertices.size()
		var ptip: Vector3 = start + direction * length + Vector3(0,0,0.012)
		vertices.append(ptip)
		opened.append(ptip + opening_offset)
		normals.append(direction)
		uvs.append(Vector2(0.5,1.0))
		var base: int = vertices.size()
		vertices.append(start)
		opened.append(start + opening_offset)
		normals.append(-direction)
		uvs.append(Vector2(0.5,0.0))
		for side in range(sides):
			var last: int = offset + (rings - 1) * sides
			indices.append_array(PackedInt32Array([last+side,last+(side+1)%sides,tip,offset+(side+1)%sides,offset+side,base]))
	indices = _clockwise_indices(vertices, indices, normals)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _recompute_normals(vertices,indices,normals)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var names: Array[String] = ["width", "height", "asymmetry", "curvature", "mouth_width", "mouth_open"]
	var morphs: Array[Array] = _accessory_morphs(vertices, indices, normals, names, opened)
	return _packed_accessory("ProceduralTeeth", arrays, morphs, names,
		{"name": "CartilageTeeth", "color": Color(0.62,0.61,0.47), "roughness": 0.32})

static func _procedural_lens(asset: String, sides: int = 48, rings: int = 12) -> MeshInstance3D:
	return _upload_prepared_accessory(_packed_lens(asset, sides, rings))

static func _packed_lens(asset: String, sides: int = 48, rings: int = 12) -> Dictionary:
	# A full biconvex globe extends behind the lids. Opening exposes more of the
	# same globe; it does not flatten or scale the eyeball with the eyelid gap.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var recessed: bool = asset == "eye_recessed"
	var radius := Vector3(0.236, 0.151 if not recessed else 0.132, 0.10 if not recessed else 0.066)
	var center_z: float = 0.020 if not recessed else -0.008
	for hemisphere in range(2):
		var sign_value: float = 1.0 if hemisphere == 0 else -1.0
		var center: int = vertices.size()
		vertices.append(Vector3(0, 0, center_z + sign_value * radius.z))
		normals.append(Vector3(0, 0, sign_value))
		uvs.append(Vector2(0.5, 0.5))
		colors.append(Color(0.025, 0.035, 0.028))
		for ring in range(1, rings + 1):
			var r: float = float(ring) / rings
			for side in range(sides):
				var a: float = TAU * float(side) / sides
				var depth: float = sqrt(maxf(0.0, 1.0 - r * r))
				var p := Vector3(radius.x * r * cos(a), radius.y * r * sin(a), center_z + sign_value * radius.z * depth)
				vertices.append(p)
				normals.append(Vector3(p.x / (radius.x * radius.x), p.y / (radius.y * radius.y), sign_value * depth / radius.z).normalized())
				uvs.append(Vector2(0.5 + 0.5 * r * cos(a), 0.5 + 0.5 * r * sin(a)))
				var iris: float = (0.60 + 0.20 * sin(a * 19.0 + r * 7.0) + 0.12 * sin(a * 31.0)) * smoothstep(0.22, 0.32, r) * (1.0 - 0.65 * smoothstep(0.76, 1.0, r))
				colors.append(Color(0.025, 0.035, 0.028).lerp(Color(0.40, 0.29, 0.18), iris))
		for side in range(sides):
			indices.append_array(PackedInt32Array([center, center + 1 + (side + 1) % sides, center + 1 + side]))
		for ring in range(rings - 1):
			for side in range(sides):
				var a: int = center + 1 + ring * sides + side
				var b: int = center + 1 + ring * sides + (side + 1) % sides
				indices.append_array(PackedInt32Array([a, b, a + sides, b, b + sides, a + sides]))
	indices = _clockwise_indices(vertices, indices, normals)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _recompute_normals(vertices, indices, normals)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var names: Array[String] = ["width", "height", "asymmetry", "curvature"]
	var morphs: Array[Array] = _accessory_morphs(vertices, indices, normals, names)
	return _packed_accessory("ProceduralSensoryLens", arrays, morphs, names,
		{"name": "EyeLens", "color": Color.WHITE, "roughness": 0.19,
		"vertex_color_use_as_albedo": true, "clearcoat_enabled": true,
		"clearcoat": 0.7, "clearcoat_roughness": 0.13})

static func _face_accessory_target(vertices: PackedVector3Array, name_value: String, asset: String) -> PackedVector3Array:
	var out: PackedVector3Array = _accessory_deformed(vertices, name_value)
	for i in range(vertices.size()):
		var p: Vector3 = vertices[i]
		var x: float = p.x
		var y: float = p.y
		match name_value:
			"forehead":
				out[i].z += 0.09 * exp(-pow(x / 0.35, 2) - pow((y - 0.36) / 0.23, 2))
				out[i].y += 0.08 * exp(-pow(x / 0.4, 2) - pow((y - 0.40) / 0.20, 2))
			"mouth_width": out[i].x=p.x*(1.0+.35*exp(-pow(x/.35,2)-pow((y+.29)/.12,2)))
			"jaw": out[i].x *= 1.0 + 0.28 * exp(-pow(x / 0.5, 2) - pow((y + 0.43) / 0.23, 2))
			"eye_spacing": out[i].x += (0.065 if x >= 0 else -0.065) * exp(-pow((x - (0.2 if x >= 0 else -0.2)) / 0.17, 2) - pow((y - 0.155) / 0.13, 2))
			"eye_size":
				var cx: float = 0.205 if x >= 0 else -0.205
				var w: float = exp(-pow((x - cx) / 0.17, 2) - pow((y - 0.155) / 0.13, 2))
				out[i].x += (x - cx) * w * 0.28
				out[i].y += (y - 0.155) * w * 0.7
			"strain":
				var side: float=-1.0 if x<0 else 1.0
				var brow: float=exp(-pow((x-side*.145)/.145,2)-pow((y-.265)/.115,2))
				var mouth: float=exp(-pow((x-side*.16)/.10,2)-pow((y+.29)/.15,2))
				out[i].y+=(.060 if side<0 else .032)*brow+(.016 if side<0 else -.010)*mouth
				out[i].x+=side*.025*mouth
				out[i].z+=.018*brow+.023*exp(-pow((x-side*.25)/.11,2)-pow((y+.11)/.21,2))-.018*exp(-pow((x-side*.30)/.08,2)-pow((y+.28)/.15,2))
			"nose_projection": out[i].z += 0.16 * exp(-pow(x / 0.10, 2) - pow((y - 0.015) / 0.23, 2))
	return out

static func _procedural_face_eyes(asset: String) -> MeshInstance3D:
	return _upload_prepared_accessory(_packed_face_eyes(asset))

static func _template_color_readback(color: Color) -> Color:
	# Facial templates previously passed through ArrayMesh before their colors
	# were sampled. Preserve that RGB8 truncation numerically, without uploading
	# a Resource in the geometry worker (Godot 4.x ARRAY_COLOR storage).
	return Color(float(int(clampf(color.r * 255.0, 0.0, 255.0))) / 255.0,
		float(int(clampf(color.g * 255.0, 0.0, 255.0))) / 255.0,
		float(int(clampf(color.b * 255.0, 0.0, 255.0))) / 255.0,
		float(int(clampf(color.a * 255.0, 0.0, 255.0))) / 255.0)

static func _packed_face_eyes(asset: String) -> Dictionary:
	var template: Dictionary = _packed_lens("eye_socket", 24, 6)
	var source: Array = template.surfaces[0].arrays
	var source_positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var y_scale: float = 1.65 / 1.35 if asset == "face_elongated" else 1.0
	var mask: bool = asset == "face_mask"
	for side in [-1.0, 1.0]:
		var offset: int = positions.size()
		var center := Vector3(side * (0.222 if mask else 0.205), 0.155 * y_scale, 0.040 if mask else 0.064)
		var size_value := Vector3(0.39, (0.28 if mask else 0.39) * y_scale, 0.50 if mask else 0.80)
		for i in range(source_positions.size()):
			positions.append(source_positions[i] * size_value + center)
			normals.append((source_normals[i] / size_value).normalized())
			uvs.append(source[Mesh.ARRAY_TEX_UV][i])
			# Facial optics have a small circular iris within actual sclera,
			# unlike the full-surface pigmentation of an alien sensory lens.
			var local: Vector3 = source_positions[i] * size_value
			var optical_radius: float = Vector2(local.x,local.y).length()
			var iris_radius: float = 0.035 if not mask else 0.030
			var sclera := Color(0.48,0.43,0.34)
			var pigment: Color = _template_color_readback(source[Mesh.ARRAY_COLOR][i])
			var edge: float = smoothstep(iris_radius-0.004,iris_radius+0.003,optical_radius)
			colors.append(pigment.lerp(sclera,edge))
		for index_value in source_indices: indices.append(index_value + offset)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = _recompute_normals(positions, indices, normals)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var names: Array[String] = ["width", "height", "asymmetry", "curvature", "forehead", "jaw", "eye_spacing", "eye_size", "nose_projection"]
	if asset=="face_neutral": names.append("strain")
	var morphs: Array[Array] = []
	for name_value: String in names:
		var target: Array = []
		target.resize(Mesh.ARRAY_MAX)
		var changed: PackedVector3Array = _face_accessory_target(positions, name_value, asset)
		target[Mesh.ARRAY_VERTEX] = changed
		target[Mesh.ARRAY_NORMAL] = _recompute_normals(changed, indices, normals)
		morphs.append(target)
	return _packed_accessory("EmbeddedFacialEyes", arrays, morphs, names, template.material)

static func _mandibular_target(p: Vector3, jaw_weight: float = -1.0) -> Vector3:
	var weight: float = 1.0 - smoothstep(0.0,1.0,(p.y + .307)/.061) if jaw_weight < 0.0 else jaw_weight
	var angle: float = .70 * weight
	var y: float = p.y + .105
	var z: float = p.z + .14
	return Vector3(p.x,-.105+y*cos(angle)-z*sin(angle),-.14+y*sin(angle)+z*cos(angle))

static func _packed_facial_oral_surface(vertices: PackedVector3Array, indices: PackedInt32Array, uvs: PackedVector2Array, opening: PackedVector3Array, material: Dictionary, label: String) -> Dictionary:
	var normals: PackedVector3Array = _recompute_normals(vertices,indices,PackedVector3Array())
	for i in range(normals.size()): normals[i] = -normals[i] # Godot clockwise face order
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_INDEX]=indices
	var names: Array[String] = ["width","height","asymmetry","curvature","jaw","mouth_width","mouth_open","strain"]
	var morphs: Array[Array] = []
	for name_value: String in names:
		var points: PackedVector3Array = opening if name_value=="mouth_open" else _face_accessory_target(vertices,name_value,"face_neutral")
		var target: Array = []; target.resize(Mesh.ARRAY_MAX)
		target[Mesh.ARRAY_VERTEX]=points; target[Mesh.ARRAY_NORMAL]=_recompute_normals(points,indices,normals)
		morphs.append(target)
	return _packed_accessory(label, arrays, morphs, names, material)

static func _procedural_facial_oral(spec: Dictionary) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for accessory: Dictionary in _packed_facial_oral(spec):
		result.append(_upload_prepared_accessory(accessory))
	return result

static func _packed_facial_oral(spec: Dictionary) -> Array[Dictionary]:
	# Real closed gingival and tongue volumes, deliberately small and recessed.
	# They move with the mandible; no external pointed teeth on facial skin.
	var result: Array[Dictionary] = []
	var template: Dictionary = _packed_lens("eye_socket",16,6)
	var source: Array = template.surfaces[0].arrays
	var centers: Array[Vector3] = [Vector3(0,-.253,.075),Vector3(0,-.308,.075),Vector3(0,-.326,-.015)]
	var sizes: Array[Vector3] = [Vector3(.55,.080,.29),Vector3(.55,.085,.30),Vector3(.38,.095,.70)]
	for part in range(3):
		var vertices := PackedVector3Array(); var opening := PackedVector3Array()
		for original: Vector3 in source[Mesh.ARRAY_VERTEX]:
			var point: Vector3=(original-Vector3(0,0,.020))*sizes[part]+centers[part]
			vertices.append(point); opening.append(_mandibular_target(point,0.02 if part==0 else (0.97 if part==1 else .88)))
		var material := {"name": "CavityGingiva" if part<2 else "CavityTongue", "color": Color(.12,.050,.037) if part<2 else Color(.15,.065,.055), "roughness": .47}
		result.append(_packed_facial_oral_surface(vertices,source[Mesh.ARRAY_INDEX],source[Mesh.ARRAY_TEX_UV],opening,material,"UpperGingiva" if part==0 else ("LowerGingiva" if part==1 else "Tongue")))
	if bool(spec.get("teeth",true)):
		var tooth_spec: Dictionary=spec.duplicate(); tooth_spec.tooth_count=clampi(int(spec.get("tooth_count",8)),4,24)
		var teeth: Dictionary=_packed_teeth("mouth_animal",tooth_spec)
		var data: Array=teeth.surfaces[0].arrays
		var vertices := PackedVector3Array(); var opening := PackedVector3Array()
		var per_row: int=ceili(float(tooth_spec.tooth_count)/2.0)
		var vertex_index: int=0
		for original: Vector3 in data[Mesh.ARRAY_VERTEX]:
			var point:=Vector3(original.x*.66,original.y*.48-.278,original.z-.015)
			var tooth: int=vertex_index/37
			vertices.append(point); opening.append(_mandibular_target(point,.02 if tooth<per_row else .97))
			vertex_index+=1
		result.append(_packed_facial_oral_surface(vertices,data[Mesh.ARRAY_INDEX],data[Mesh.ARRAY_TEX_UV],opening,teeth.material,"EmbeddedFacialTeeth"))
	return result

static func _accessor_floats(document: Dictionary, binary: PackedByteArray, accessor_index: int, components: int) -> PackedFloat32Array:
	var accessor: Dictionary = document.accessors[accessor_index]
	var count: int = int(accessor.count)
	var result := PackedFloat32Array()
	result.resize(count * components)
	if accessor.has("bufferView"):
		var view: Dictionary = document.bufferViews[int(accessor.bufferView)]
		var start: int = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
		var stride: int = int(view.get("byteStride", components * 4))
		if stride == components * 4:
			result = binary.slice(start, start + count * stride).to_float32_array()
		else:
			for i in range(count):
				for c in range(components):
					result[i * components + c] = binary.decode_float(start + i * stride + c * 4)
	if accessor.has("sparse"):
		var sparse: Dictionary = accessor.sparse
		var indices: Dictionary = sparse.indices
		var values: Dictionary = sparse.values
		var iview: Dictionary = document.bufferViews[int(indices.bufferView)]
		var vview: Dictionary = document.bufferViews[int(values.bufferView)]
		var istart: int = int(iview.get("byteOffset", 0)) + int(indices.get("byteOffset", 0))
		var vstart: int = int(vview.get("byteOffset", 0)) + int(values.get("byteOffset", 0))
		var component: int = int(indices.componentType)
		var step: int = 2 if component == 5123 else (4 if component == 5125 else 1)
		for i in range(int(sparse.count)):
			var offset: int = istart + i * step
			var index: int = binary.decode_u16(offset) if step == 2 else (binary.decode_u32(offset) if step == 4 else int(binary[offset]))
			for c in range(components):
				result[index * components + c] = binary.decode_float(vstart + (i * components + c) * 4)
	return result

static func _accessor_vectors3(document: Dictionary, binary: PackedByteArray, accessor_index: int) -> PackedVector3Array:
	var floats: PackedFloat32Array = _accessor_floats(document, binary, accessor_index, 3)
	var result := PackedVector3Array()
	result.resize(floats.size() / 3)
	for i in range(result.size()):
		result[i] = Vector3(floats[i*3], floats[i*3+1], floats[i*3+2])
	return result

static func _accessor_vectors2(document: Dictionary, binary: PackedByteArray, accessor_index: int) -> PackedVector2Array:
	var floats: PackedFloat32Array = _accessor_floats(document, binary, accessor_index, 2)
	var result := PackedVector2Array()
	result.resize(floats.size() / 2)
	for i in range(result.size()):
		result[i] = Vector2(floats[i*2], floats[i*2+1])
	return result

static func _accessor_indices(document: Dictionary, binary: PackedByteArray, accessor_index: int) -> PackedInt32Array:
	var accessor: Dictionary = document.accessors[accessor_index]
	var view: Dictionary = document.bufferViews[int(accessor.bufferView)]
	var count: int = int(accessor.count)
	var component: int = int(accessor.componentType)
	var bytes: int = 2 if component == 5123 else (4 if component == 5125 else 1)
	var start: int = int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
	var result := PackedInt32Array()
	result.resize(count)
	for i in range(count):
		var offset: int = start + i * bytes
		result[i] = binary.decode_u16(offset) if bytes == 2 else (binary.decode_u32(offset) if bytes == 4 else int(binary[offset]))
	# glTF front faces are counter-clockwise; Godot ArrayMesh fronts clockwise.
	for i in range(0, result.size(), 3):
		var swap: int = result[i+1]
		result[i+1] = result[i+2]
		result[i+2] = swap
	return result

static func _read_module_surface_data(asset: String) -> Dictionary:
	# This intentionally reads our bounded, documented GLB subset without loading
	# any Resources or Nodes. It is safe inside the generation worker. Each source
	# has one identity-transform mesh, float attributes and dense, sparse or implicit-zero morph accessors.
	if asset.contains("/") or asset.contains("\\") or asset.contains(".."):
		return {}
	var path: String = "res://alien_foundry/assets/modular_anatomy/" + asset + ".glb"
	if not FileAccess.file_exists(path):
		return {}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 28 or bytes.decode_u32(0) != 0x46546C67:
		return {}
	var json_size: int = bytes.decode_u32(12)
	var parsed: Variant = JSON.parse_string(bytes.slice(20, 20 + json_size).get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var document: Dictionary = parsed
	var binary: PackedByteArray = bytes.slice(28 + json_size)
	var mesh: Dictionary = document.meshes[0]
	var shape_names: Array = mesh.get("extras", {}).get("targetNames", [])
	var surfaces: Array = []
	for primitive: Dictionary in mesh.primitives:
		var attributes: Dictionary = primitive.attributes
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _accessor_vectors3(document, binary, int(attributes.POSITION))
		arrays[Mesh.ARRAY_NORMAL] = _accessor_vectors3(document, binary, int(attributes.NORMAL))
		arrays[Mesh.ARRAY_TEX_UV] = _accessor_vectors2(document, binary, int(attributes.TEXCOORD_0))
		arrays[Mesh.ARRAY_INDEX] = _accessor_indices(document, binary, int(primitive.indices))
		var shapes: Array[Array] = []
		for target: Dictionary in primitive.get("targets", []):
			var positions: PackedVector3Array = _accessor_vectors3(document, binary, int(target.POSITION))
			var normals: PackedVector3Array = _accessor_vectors3(document, binary, int(target.NORMAL))
			for i in range(positions.size()):
				positions[i] += arrays[Mesh.ARRAY_VERTEX][i]
				normals[i] += arrays[Mesh.ARRAY_NORMAL][i]
			var shape: Array = []
			shape.resize(Mesh.ARRAY_MAX)
			shape[Mesh.ARRAY_VERTEX] = positions
			shape[Mesh.ARRAY_NORMAL] = normals
			shapes.append(shape)
		surfaces.append({"arrays": arrays, "morphs": shapes, "material_index": int(primitive.get("material", 0))})
	return {"shape_names": shape_names, "surfaces": surfaces, "asset": asset}

static func _prepare_conformed_data(source: Dictionary, grid: Dictionary, controls: RefCounted = null) -> Dictionary:
	var output: Dictionary = source.duplicate()
	output["surfaces"] = []
	for surface: Dictionary in source.get("surfaces", []):
		if controls != null and controls.is_cancelled(): return {}
		var arrays: Array = surface.arrays.duplicate(true)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var reference: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if not grid.is_empty():
			positions = _conformed_positions(positions, Transform3D.IDENTITY, grid)
			arrays[Mesh.ARRAY_VERTEX] = positions
			arrays[Mesh.ARRAY_NORMAL] = _carrier_feather_normals(positions, _recompute_normals(positions, indices, reference), reference, Transform3D.IDENTITY, grid)
		var morphs: Array[Array] = []
		for source_shape: Array in surface.morphs:
			if controls != null and controls.is_cancelled():
				return {}
			var shape: Array = source_shape.duplicate(true)
			if not grid.is_empty():
				var target: PackedVector3Array = _conformed_positions(shape[Mesh.ARRAY_VERTEX], Transform3D.IDENTITY, grid)
				shape[Mesh.ARRAY_VERTEX] = target
				shape[Mesh.ARRAY_NORMAL] = _carrier_feather_normals(target, _recompute_normals(target, indices, reference), reference, Transform3D.IDENTITY, grid)
			morphs.append(shape)
		var prepared_surface: Dictionary = surface.duplicate()
		prepared_surface["arrays"] = arrays
		prepared_surface["morphs"] = morphs
		output.surfaces.append(prepared_surface)
	if not grid.is_empty(): output["carrier_conformed"] = true
	return output

static func prepare_module_accessories(spec: Dictionary, grid: Dictionary = {}, controls: RefCounted = null) -> Array[Dictionary]:
	## Worker-safe procedural geometry, including every absolute morph target.
	## Mirrors legacy placement order and conformation rules exactly. The facial
	## oral volumes intentionally remain in authored skull coordinates.
	var result: Array[Dictionary] = []
	var asset: String = str(spec.get("asset", spec.get("module", "")))
	var carrier: Dictionary = grid.duplicate()
	if bool(spec.get("full_shell", false)) or str(spec.get("mounting", "")) == "craniofacial": carrier = {}
	if not carrier.is_empty(): carrier["module_asset"] = asset
	if controls != null and controls.is_cancelled(): return []
	if asset in ["mouth_animal", "mouth_radial"] and bool(spec.get("teeth", true)):
		result.append(_prepare_conformed_data(_packed_teeth(asset, spec), carrier, controls))
	if asset == "face_neutral" and bool(spec.get("oral_anatomy", true)):
		result.append_array(_packed_facial_oral(spec))
	if controls != null and controls.is_cancelled(): return []
	if asset.begins_with("face_") and bool(spec.get("lens", true)):
		var optical_grid: Dictionary = carrier.duplicate()
		if not optical_grid.is_empty(): optical_grid["skip_normal_feather"] = true
		result.append(_prepare_conformed_data(_packed_face_eyes(asset), optical_grid, controls))
	if asset.begins_with("eye_") and bool(spec.get("lens", true)):
		result.append(_prepare_conformed_data(_packed_lens(asset), carrier, controls))
	if controls != null and controls.is_cancelled(): return []
	return result

static func prepare_modules(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null) -> Dictionary:
	## Worker-safe: only FileAccess, JSON and packed numerical arrays. No Resource
	## uploads, scene construction, mutable global cache or active scene access.
	var anchor_map: Dictionary = {}
	for anchor: Dictionary in geometry.get("module_anchors", []):
		anchor_map[str(anchor.get("id", ""))] = anchor
	var sources: Dictionary = {}
	var result: Dictionary = {}
	var module_count: int = dna.get("modules", []).size()
	var module_index: int = 0
	for spec: Dictionary in dna.get("modules", []):
		if controls != null:
			if controls.is_cancelled():
				return {}
			controls.set_progress(0.94 + 0.04 * float(module_index) / maxf(1.0, module_count), "Conforming reusable anatomical tissue")
		module_index += 1
		var asset: String = str(spec.get("asset", ""))
		if not sources.has(asset):
			sources[asset] = _read_module_surface_data(asset)
		var source: Dictionary = sources[asset]
		if source.is_empty():
			continue
		var id: String = str(spec.get("id", ""))
		var grid: Dictionary = anchor_map.get(id, {}).get("surface_grid", {}).duplicate()
		if bool(spec.get("full_shell", false)) or str(spec.get("mounting", "")) == "craniofacial": grid = {}
		if not grid.is_empty():
			grid["module_asset"] = asset
		var prepared: Dictionary = _prepare_conformed_data(source, grid, controls)
		if controls != null and controls.is_cancelled(): return {}
		if prepared.is_empty(): return {}
		prepared["accessories"] = prepare_module_accessories(spec, grid, controls)
		if controls != null and controls.is_cancelled(): return {}
		# Set only after every requested base surface, accessory and morph exists.
		# An empty prepared array is authoritative, not a request for fallback.
		prepared["accessories_prepared"] = true
		result[id] = prepared
	return result

static func _apply_prepared_tree(node: Node, data: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var authored: ArrayMesh = node.mesh
		var mesh := ArrayMesh.new()
		mesh.resource_name = authored.resource_name + "_PreparedCarrier"
		mesh.blend_shape_mode = authored.blend_shape_mode
		for name_value in data.get("shape_names", []):
			mesh.add_blend_shape(str(name_value))
		var surfaces: Array = data.get("surfaces", [])
		for i in range(surfaces.size()):
			var surface: Dictionary = surfaces[i]
			var morphs: Array[Array] = []
			for shape: Array in surface.morphs:
				morphs.append(shape)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.arrays, morphs)
			mesh.surface_set_material(i, authored.surface_get_material(mini(i, authored.get_surface_count()-1)))
		node.mesh = mesh
		node.set_meta("carrier_conformed", true)
		return
	for child in node.get_children():
		_apply_prepared_tree(child, data)

static func count_prepared_triangles(data: Dictionary, include_accessories: bool = true) -> int:
	var result: int = 0
	for surface: Dictionary in data.get("surfaces", []):
		var arrays: Array = surface.get("arrays", [])
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			result += arrays[Mesh.ARRAY_INDEX].size() / 3
	if include_accessories: result += prepared_accessory_triangles(data)
	return result

static func prepared_accessory_triangles(data: Dictionary) -> int:
	var result: int = 0
	for accessory: Dictionary in data.get("accessories", []):
		result += count_prepared_triangles(accessory, false)
	return result

static func procedural_accessory_triangles(spec: Dictionary) -> int:
	var asset: String = str(spec.get("asset", ""))
	var result: int = 0
	if asset == "face_neutral" and bool(spec.get("oral_anatomy",true)):
		result += 1056
		if bool(spec.get("teeth",true)): result += 70 * clampi(int(spec.get("tooth_count",8)),4,24)
	if asset in ["mouth_animal", "mouth_radial"] and bool(spec.get("teeth", true)):
		result += 70 * clampi(int(spec.get("tooth_count", 14 if asset == "mouth_radial" else 12)), 4, 24)
	if bool(spec.get("lens", true)):
		if asset.begins_with("face_"): result += 1056
		elif asset.begins_with("eye_"): result += 2208
	return result

static func fit_prepared_lods(dna: Dictionary, prepared: Dictionary, module_triangle_budget: int) -> Dictionary:
	# Offline simplification only: this worker function selects immutable index
	# arrays. Vertex ordering, conformed surfaces, normals, UVs and every absolute
	# morph target stay untouched. Missing/stale sidecars safely retain LOD 0.
	var cache: Dictionary = {}
	var choices: Array = []
	var total: int = 0
	var accessories: int = 0
	var minimum: int = 0
	for spec: Dictionary in dna.get("modules", []):
		var id: String = str(spec.get("id", ""))
		var asset: String = str(spec.get("asset", ""))
		if not prepared.has(id): continue
		var source_count: int = 0
		for surface: Dictionary in prepared[id].get("surfaces", []): source_count += surface.arrays[Mesh.ARRAY_INDEX].size() / 3
		if not cache.has(asset):
			var sidecar: String = "res://alien_foundry/assets/modular_anatomy/%s.lods.json" % asset
			var glb: String = "res://alien_foundry/assets/modular_anatomy/%s.glb" % asset
			var loaded: Dictionary = {}
			if FileAccess.file_exists(sidecar):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sidecar))
				if parsed is Dictionary and str(parsed.get("source_sha256", "")) == FileAccess.get_sha256(glb): loaded = parsed
			cache[asset] = loaded
		var data: Dictionary = cache[asset]
		var levels: Array = data.get("levels", [{"triangles":source_count,"surfaces":[]}])
		var extra: int = prepared_accessory_triangles(prepared[id]) if bool(prepared[id].get("accessories_prepared", false)) else procedural_accessory_triangles(spec)
		accessories += extra
		total += source_count + extra
		minimum += int(levels[-1].triangles) + extra
		choices.append({"id":id,"asset":asset,"lod":0,"levels":levels,"source_triangles":source_count,"accessory_triangles":extra,"source_sha256":data.get("source_sha256", ""),"priority":1.6 if asset.begins_with("face_") else 1.0})
	while total > module_triangle_budget:
		var best: int = -1
		var best_cost: float = INF
		var best_next: int = -1
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			var current: int = int(choice.levels[int(choice.lod)].triangles)
			for next_level in range(int(choice.lod)+1,choice.levels.size()):
				var saving: int = current - int(choice.levels[next_level].triangles)
				if saving <= 0: continue
				var cost: float = float(next_level) * float(choice.priority) * float(choice.source_triangles) / saving
				if cost < best_cost:
					best = i
					best_next = next_level
					best_cost = cost
				break
		if best < 0: break
		var selected: Dictionary = choices[best]
		total -= int(selected.levels[int(selected.lod)].triangles) - int(selected.levels[best_next].triangles)
		selected.lod = best_next
	var modules: Dictionary = prepared.duplicate()
	var selections: Array = []
	for choice: Dictionary in choices:
		var level: Dictionary = choice.levels[int(choice.lod)]
		if int(choice.lod) > 0:
			var module_data: Dictionary = prepared[choice.id].duplicate()
			var surfaces: Array = []
			for i in range(module_data.surfaces.size()):
				var surface: Dictionary = module_data.surfaces[i].duplicate()
				var arrays: Array = surface.arrays.duplicate()
				arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(level.surfaces[i])
				surface.arrays = arrays
				surfaces.append(surface)
			module_data.surfaces = surfaces
			module_data["selected_lod"] = choice.lod
			modules[choice.id] = module_data
		selections.append({"id":choice.id,"asset":choice.asset,"lod":choice.lod,"triangles":int(level.triangles)+int(choice.accessory_triangles),"accessory_triangles":choice.accessory_triangles,"source_triangles":choice.source_triangles,"source_sha256":choice.source_sha256})
	return {"modules":modules,"triangles":total,"accessory_triangles":accessories,"minimum_triangles":minimum,"over_budget":total>module_triangle_budget,"selections":selections}
