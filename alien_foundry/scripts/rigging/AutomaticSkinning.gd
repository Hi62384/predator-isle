class_name AutomaticSkinning
extends RefCounted
## Surface provenance is authoritative: crossing limbs cannot steal each other's
## vertices. Distance is used only along that component's explicit joint chain.
const SkeletonBuilder = preload("res://alien_foundry/scripts/rigging/SkeletonGenerator.gd")
const SurfaceContext = preload("res://alien_foundry/scripts/rigging/AnatomicalSurfaceContext.gd")
const InfluenceReducer = preload("res://alien_foundry/scripts/rigging/AnatomicalInfluenceReducer.gd")

static func build(dna: Dictionary, mesh_data: Dictionary, rig: Dictionary, controls: RefCounted = null) -> Dictionary:
	var vertices: PackedVector3Array = mesh_data.get("vertices", PackedVector3Array())
	var normals: PackedVector3Array = mesh_data.get("normals", PackedVector3Array())
	var provenance: PackedInt32Array = mesh_data.get("component_indices", PackedInt32Array())
	var ownership: PackedInt32Array = mesh_data.get("component_ids", PackedInt32Array())
	var influence: PackedFloat32Array = mesh_data.get("component_weights", PackedFloat32Array())
	var node_ids: PackedStringArray = mesh_data.get("node_ids", PackedStringArray())
	if str(mesh_data.get("fibre_uv_mode", "")) == "authored":
		var authored_uv: Variant=mesh_data.get("uvs",null)
		if not authored_uv is PackedVector2Array or authored_uv.size()!=vertices.size():
			return {"error":"Authored fibre charts require one packed UV coordinate per vertex.","error_code":"invalid_fibre_uv"}
		for uv: Vector2 in authored_uv:
			if not is_finite(uv.x) or not is_finite(uv.y):
				return {"error":"Authored fibre chart coordinates must be finite.","error_code":"invalid_fibre_uv"}
	var authored_context := PackedFloat32Array()
	if mesh_data.has("authored_surface_context"):
		if not mesh_data.authored_surface_context is PackedFloat32Array:
			return {"error":"Authored tissue context must be a packed float array.","error_code":"invalid_surface_context"}
		authored_context=mesh_data.authored_surface_context
		if authored_context.size()!=vertices.size()*4:
			return {"error":"Authored tissue context must contain four semantic values per vertex.","error_code":"invalid_surface_context"}
		for value: float in authored_context:
			if not is_finite(value) or value<0.0 or value>1.0:
				return {"error":"Authored tissue context values must be finite and normalized.","error_code":"invalid_surface_context"}
	var attachments: Dictionary = _root_attachment_context(mesh_data, rig)
	if node_ids.is_empty():
		for node: Dictionary in dna.get("nodes", []):
			node_ids.append(str(node.get("id", "")))
	var context_cache: Array = SurfaceContext.cache(dna, node_ids)
	var surface_context := PackedFloat32Array()
	surface_context.resize(vertices.size()*4)
	var bone_indices: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var material_flows: PackedVector3Array = PackedVector3Array()
	var shading_colors: PackedColorArray = mesh_data.get("colors", PackedColorArray()).duplicate()
	if shading_colors.size() != vertices.size():
		shading_colors.resize(vertices.size())
		shading_colors.fill(Color(0.0, 0.5, 0.0, 0.0))
	bone_indices.resize(vertices.size() * 4)
	weights.resize(vertices.size() * 4)
	tangents.resize(vertices.size() * 4)
	material_flows.resize(vertices.size())
	var missing_provenance: int = 0
	var balanced_reductions: int = 0
	var exceptional_reductions: int = 0
	for i: int in range(vertices.size()):
		if controls != null and i % 1024 == 0:
			if controls.is_cancelled():
				return {"cancelled": true}
			controls.set_progress(0.94 + 0.01 * float(i) / maxf(float(vertices.size()), 1.0), "Calculating anatomical skin weights")
		var normal: Vector3 = normals[i] if i < normals.size() else Vector3.UP
		var context := Vector4.ZERO
		var context_total: float = 0.0
		if provenance.size() >= (i+1)*4 and influence.size() >= (i+1)*4:
			for j: int in range(4):
				var slot: int = i*4+j
				var owner: int = provenance[slot]
				if influence[slot] > 0.00001 and owner >= 0 and owner < context_cache.size():
					context += SurfaceContext.sample(vertices[i], normal, context_cache[owner])*influence[slot]
					context_total += influence[slot]
		if context_total < 0.00001 and i < ownership.size() and ownership[i] >= 0 and ownership[i] < context_cache.size():
			context = SurfaceContext.sample(vertices[i], normal, context_cache[ownership[i]])
			context_total = 1.0
		context = context/context_total if context_total > 0.00001 else Vector4(0,0,0,1)
		if not authored_context.is_empty():
			# Asset-derived tissue may supply the SAME insertion/growth/exposure/
			# relative-thickness meanings at finer resolution than its carrier.
			# This never modifies the authoritative skeletal owner influences.
			context=Vector4(authored_context[i*4],authored_context[i*4+1],authored_context[i*4+2],authored_context[i*4+3])
		for channel: int in range(4): surface_context[i*4+channel] = context[channel]
		var bone_weights: Dictionary = {}
		if attachments.owners.has(i):
			# Exact shared root cap follows the complete carrier chain. A newly
			# articulated digit must not peel off when its first control flexes.
			_add_component_weights(vertices[i], attachments.owners[i], 1.0, rig, bone_weights, attachments.origins)
		elif provenance.size() >= (i + 1) * 4 and influence.size() >= (i + 1) * 4:
			for j: int in range(4):
				var slot: int = i * 4 + j
				var component_index: int = provenance[slot]
				if influence[slot] > 0.00001 and component_index >= 0 and component_index < node_ids.size():
					_add_component_weights(vertices[i], node_ids[component_index], influence[slot], rig, bone_weights, attachments.origins)
		elif ownership.size() > i and ownership[i] >= 0 and ownership[i] < node_ids.size():
			_add_component_weights(vertices[i], node_ids[ownership[i]], 1.0, rig, bone_weights, attachments.origins)
		if bone_weights.is_empty():
			# Missing metadata is reported and remains attached to root, never to an
			# unrelated limb found by a global proximity heuristic.
			bone_weights[0] = 1.0
			missing_provenance += 1
		var sorted: Array = bone_weights.keys()
		sorted.sort_custom(func(a: int, b: int) -> bool:
			if float(bone_weights[a]) == float(bone_weights[b]):
				return a < b
			return float(bone_weights[a]) > float(bone_weights[b]))
		if sorted.size() > 4:
			var reduced: Dictionary = InfluenceReducer.reduce(bone_weights)
			bone_weights = reduced.weights
			sorted = bone_weights.keys()
			balanced_reductions += int(reduced.balanced)
			exceptional_reductions += int(reduced.fallback)
		var total: float = 0.0
		for j: int in range(mini(4, sorted.size())):
			total += float(bone_weights[sorted[j]])
		for j: int in range(4):
			if j < sorted.size():
				bone_indices[i * 4 + j] = int(sorted[j])
				weights[i * 4 + j] = float(bone_weights[sorted[j]]) / maxf(total, 0.000001)
			else:
				bone_indices[i * 4 + j] = 0
				weights[i * 4 + j] = 0.0
		var shaded: Color = shading_colors[i]
		shaded.a = _joint_crease(vertices[i], sorted, rig)
		shading_colors[i] = shaded
		# A material tangent follows the owned anatomical chain, rather than a
		# uniform world axis. The shader uses this to align folds and tendon grain.
		var tangent: Vector3 = rig.bones[int(sorted[0])].global_rest.basis.y
		var component_index: int = ownership[i] if ownership.size() > i else -1
		if component_index < 0 and provenance.size() > i * 4:
			component_index = provenance[i * 4]
		if component_index >= 0 and component_index < node_ids.size():
			tangent = _material_flow(vertices[i], node_ids[component_index], rig, tangent)
		# Procedural coordinates need the anatomical axis, not the tangent
		# projected onto each changing surface normal (which creates poles).
		material_flows[i] = tangent.normalized()
		tangent = tangent - normal * normal.dot(tangent)
		if tangent.length_squared() < 0.0001:
			tangent = normal.cross(Vector3.FORWARD if absf(normal.z) < 0.9 else Vector3.RIGHT)
		tangent = tangent.normalized()
		tangents[i * 4] = tangent.x
		tangents[i * 4 + 1] = tangent.y
		tangents[i * 4 + 2] = tangent.z
		tangents[i * 4 + 3] = 1.0
	# Custom attributes are not transformed by Godot's skinning pass. Preserve
	# material coordinates so pores/folds follow the tissue instead of swimming.
	return {"surface_context": surface_context, "bones": bone_indices, "weights": weights, "tangents": tangents, "material_positions": vertices.to_byte_array().to_float32_array(), "material_flows": material_flows.to_byte_array().to_float32_array(), "shading_colors": shading_colors, "missing_provenance": missing_provenance, "balanced_reductions": balanced_reductions, "exceptional_reductions": exceptional_reductions, "vertex_count": vertices.size()}

static func _material_flow(point: Vector3, component: String, rig: Dictionary, fallback: Vector3) -> Vector3:
	var node: Dictionary = rig.component_nodes.get(component, {})
	if str(node.get("role", "")) != "tendon" and str(node.get("shape", {}).get("geometry", "")) != "detail":
		return fallback
	var points: Array = node.get("points", [])
	var result: Vector3 = fallback
	var closest: float = INF
	for i: int in range(points.size() - 1):
		var a: Vector3 = SkeletonBuilder.vec(points[i])
		var axis: Vector3 = SkeletonBuilder.vec(points[i + 1]) - a
		var t: float = clampf((point-a).dot(axis) / maxf(axis.length_squared(), 0.000001), 0.0, 1.0)
		var distance: float = point.distance_squared_to(a + axis * t)
		if distance < closest and axis.length_squared() > 0.000001:
			closest = distance
			result = axis.normalized()
	return result

static func _joint_crease(point: Vector3, sorted_bones: Array, rig: Dictionary) -> float:
	var mask: float = 0.0
	for slot: int in range(mini(sorted_bones.size(), 4)):
		var bone: Dictionary = rig.bones[int(sorted_bones[slot])]
		if str(bone.kind) not in ["limb", "arm", "leg", "digit", "finger", "neck", "body_chain", "tail", "tendril"]:
			continue
		var node: Dictionary = rig.component_nodes.get(str(bone.component_id), {})
		var points: Array = node.get("points", [])
		var index: int = int(bone.segment_index)
		if index <= 0 or index >= points.size() - 1:
			continue
		var radius: float = float(node.get("radius", 0.12))
		var radii: Array = node.get("radii", [])
		if index < radii.size():
			radius = float(radii[index])
		var previous: Vector3 = SkeletonBuilder.vec(points[index - 1])
		var center: Vector3 = bone.start
		var next: Vector3 = SkeletonBuilder.vec(points[index + 1])
		var bend: float = 1.0 - (center - previous).normalized().dot((next - center).normalized())
		var falloff: float = exp(-point.distance_squared_to(center) / maxf(radius * radius * 2.3, 0.0001))
		mask = maxf(mask, falloff * clampf(0.45 + bend * 2.0, 0.0, 1.0))
	return clampf(mask, 0.0, 1.0)

static func _root_attachment_context(mesh_data: Dictionary, rig: Dictionary) -> Dictionary:
	var result: Dictionary = {"owners": {}, "origins": {}}
	var ids: PackedStringArray = mesh_data.get("cap_strand_ids", PackedStringArray())
	var points: PackedVector3Array = mesh_data.get("cap_endpoints", PackedVector3Array())
	var required: PackedByteArray = mesh_data.get("attachment_required", PackedByteArray())
	var offsets: PackedInt32Array = mesh_data.get("cap_vertex_offsets", PackedInt32Array())
	var vertices: PackedInt32Array = mesh_data.get("cap_vertex_indices", PackedInt32Array())
	for cap: int in range(ids.size()):
		var node: Dictionary = rig.component_nodes.get(ids[cap], {})
		var shape: Dictionary = node.get("shape", {})
		if cap >= required.size() or required[cap] == 0 or not bool(node.get("bone", false)) or str(shape.get("attachment", "")) != "root":
			continue
		var parent: String = str(node.get("parent", ""))
		if parent.is_empty() or not rig.component_bones.has(parent): continue
		if cap < points.size(): result.origins[ids[cap]] = points[cap]
		if offsets.size() <= cap + 1: continue
		for slot: int in range(offsets[cap], offsets[cap + 1]):
			if slot >= 0 and slot < vertices.size(): result.owners[vertices[slot]] = parent
	return result

static func _add_component_weights(point: Vector3, component: String, strength: float, rig: Dictionary, output: Dictionary, attachment_origins: Dictionary = {}, depth: int = 0) -> void:
	var node: Dictionary = rig.component_nodes.get(component, {})
	var shape: Dictionary = node.get("shape", {})
	var parent: String = str(node.get("parent", ""))
	var points: Array = node.get("points", [])
	if depth < 48 and bool(node.get("bone", false)) and str(shape.get("attachment", "")) == "root" and str(shape.get("geometry", "")) == "detail" and points.size() >= 2 and parent != component and rig.component_bones.has(parent):
		var origin: Vector3 = attachment_origins.get(component, SkeletonBuilder.vec(points[0]))
		var axis: Vector3 = SkeletonBuilder.vec(points[1]) - origin
		var radii: Array = node.get("radii", [])
		var radius: float = float(radii[0]) if not radii.is_empty() else 0.05
		var transition: float = maxf(minf(axis.length()*0.82, maxf(radius*2.0, axis.length()*0.5)), 0.001)
		var along: float = (point-origin).dot(axis.normalized())
		var own_amount: float = smoothstep(0.0, transition, along)
		if own_amount < 1.0:
			_add_component_weights(point, parent, strength*(1.0-own_amount), rig, output, attachment_origins, depth+1)
		strength *= own_amount
		if strength < 0.000001: return
	_add_chain_weights(point, component, strength, rig, output)

static func _add_chain_weights(point: Vector3, component: String, strength: float, rig: Dictionary, output: Dictionary) -> void:
	var chain: Array = rig.component_bones.get(component, [])
	if chain.is_empty():
		return
	if chain.size() == 1:
		_accumulate(output, int(chain[0]), strength)
		return
	var best_segment: int = 0
	var best_t: float = 0.0
	var best_distance: float = INF
	for j: int in range(chain.size() - 1):
		var a: Vector3 = rig.bones[int(chain[j])].start
		var b: Vector3 = rig.bones[int(chain[j + 1])].start
		var ab: Vector3 = b - a
		var t: float = clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		var distance: float = point.distance_squared_to(a + ab * t)
		if distance < best_distance:
			best_distance = distance
			best_segment = j
			best_t = t
	# Smooth interpolation keeps fused shoulder/knee regions continuous.
	var smooth_t: float = best_t * best_t * (3.0 - 2.0 * best_t)
	_accumulate(output, int(chain[best_segment]), strength * (1.0 - smooth_t))
	_accumulate(output, int(chain[best_segment + 1]), strength * smooth_t)

static func _accumulate(output: Dictionary, bone: int, weight: float) -> void:
	if weight > 0.000001:
		output[bone] = float(output.get(bone, 0.0)) + weight

static func validate(weights: Dictionary, bone_count: int) -> Dictionary:
	var indices: PackedInt32Array = weights.get("bones", PackedInt32Array())
	var values: PackedFloat32Array = weights.get("weights", PackedFloat32Array())
	var errors: PackedStringArray = PackedStringArray()
	if indices.size() != values.size() or values.size() % 4 != 0:
		errors.append("Skin array lengths do not match four-influence layout.")
	else:
		for i: int in range(values.size() / 4):
			var sum: float = 0.0
			for j: int in range(4):
				var index: int = i * 4 + j
				if indices[index] < 0 or indices[index] >= bone_count:
					errors.append("Bone index out of range at vertex " + str(i))
				if not is_finite(values[index]) or values[index] < 0.0:
					errors.append("Invalid skin weight at vertex " + str(i))
				sum += values[index]
			if absf(sum - 1.0) > 0.0001:
				errors.append("Non-normalized skin at vertex " + str(i))
			if errors.size() > 20:
				break
	if weights.has("surface_context"):
		var context: PackedFloat32Array = weights.surface_context
		if context.size() != values.size():
			errors.append("Surface context must contain four channels per vertex.")
		else:
			for value: float in context:
				if not is_finite(value) or value < 0.0 or value > 1.0:
					errors.append("Surface context contains a non-finite or out-of-range channel.")
					break
	return {"valid": errors.is_empty(), "errors": errors, "vertices": values.size() / 4}
