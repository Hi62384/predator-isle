class_name SkeletonGenerator
extends RefCounted
## Creates an arbitrary forest from explicit anatomy, then anchors disconnected
## roots to a single deform root. No humanoid names or nearest-global-bone guess.
## build_data is pure data and is safe on a generation worker.

static func vec(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

static func build_data(dna: Dictionary) -> Dictionary:
	var result: Dictionary = {"bones": [], "component_bones": {}, "component_nodes": {}, "warnings": []}
	var nodes: Array = dna.get("nodes", [])
	var budget: int = maxi(1, int(dna.get("budget", {}).get("bones", 192)))
	result["component_control_counts"] = _allocate_controls(nodes, budget)
	result["bone_budget"] = budget
	var pending: Array = []
	for node: Dictionary in nodes:
		result.component_nodes[str(node.get("id", ""))] = node
		if str(node.get("kind", "")) != "cavity":
			pending.append(node)
	var passes: int = 0
	while not pending.is_empty() and passes <= nodes.size():
		passes += 1
		var progress: bool = false
		for index: int in range(pending.size() - 1, -1, -1):
			var node: Dictionary = pending[index]
			var parent_id: String = str(node.get("parent", ""))
			if not parent_id.is_empty() and result.component_nodes.has(parent_id) and not result.component_bones.has(parent_id):
				continue
			_add_component(node, result)
			pending.remove_at(index)
			progress = true
		if not progress:
			# Invalid imported graphs remain renderable without creating a bone cycle.
			var orphan: Dictionary = pending.pop_front().duplicate(true)
			result.warnings.append("Unresolved skeletal parent of " + str(orphan.get("id", "")))
			orphan.parent = ""
			_add_component(orphan, result)
	if result.bones.is_empty():
		_append_bone(result, "organism_root", -1, Vector3.ZERO, Vector3.UP * 0.1, "", 0, "body", {})
	result.bone_count = result.bones.size()
	return result

static func _allocate_controls(nodes: Array, budget: int) -> Dictionary:
	var counts: Dictionary = {}
	var curves: Array = []
	var allocated: int = 0
	for node: Dictionary in nodes:
		var id: String = str(node.get("id", ""))
		counts[id] = 0
		if str(node.get("kind", "")) == "cavity":
			continue
		if not bool(node.get("bone", true)) and not str(node.get("parent", "")).is_empty():
			continue
		if allocated < budget:
			counts[id] = 1
			allocated += 1
		if node.get("points", []).size() >= 2:
			curves.append(node)
	curves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority: Dictionary = {"body_chain":0,"limb":1,"neck":2,"tail":3,"connection":4,"tendril":5,"digit":6}
		var ap: int = int(priority.get(str(a.get("role", "")), 7))
		var bp: int = int(priority.get(str(b.get("role", "")), 7))
		return str(a.get("id", "")) < str(b.get("id", "")) if ap == bp else ap < bp)
	# Fair rounds preserve endpoints on as many chains as possible before adding
	# intermediate joints. Only optional controls are reduced, never the mesh.
	var progress: bool = true
	while allocated < budget and progress:
		progress = false
		for node: Dictionary in curves:
			var id: String = str(node.get("id", ""))
			if int(counts[id]) > 0 and int(counts[id]) < node.points.size():
				counts[id] = int(counts[id]) + 1
				allocated += 1
				progress = true
				if allocated >= budget:
					break
	return counts

static func _add_component(node: Dictionary, result: Dictionary) -> void:
	var id: String = str(node.get("id", "component"))
	var parent_id: String = str(node.get("parent", ""))
	var position: Vector3 = vec(node.get("position", []))
	var points: Array = node.get("points", [])
	if not points.is_empty():
		position = vec(points[0], position)
	var parent: int = closest_component_bone(result, parent_id, position)
	if parent < 0 and not result.bones.is_empty():
		parent = 0
	var control_count: int = int(result.component_control_counts.get(id, 0))
	if (not bool(node.get("bone", true)) or control_count == 0) and parent >= 0:
		# Non-articulated tissue is still deformable along its anatomical
		# carrier. Keeping only the start joint made long tendon ribbons rigid
		# and pulled their distal attachments away when the limb flexed.
		var carrier_chain: Array = result.component_bones.get(parent_id, [])
		result.component_bones[id] = carrier_chain.duplicate() if not carrier_chain.is_empty() else [parent]
		return
	if points.size() > maxi(control_count, 1):
		var sampled: Array = []
		for sample: int in range(maxi(control_count, 1)):
			var source_index: int = int(round(float(sample) * float(points.size() - 1) / float(maxi(control_count - 1, 1))))
			sampled.append(points[source_index])
		points = sampled
		result.warnings.append("Reduced preview controls for " + id + " to respect the bone budget.")
	var bone_ids: Array = []
	var role: String = str(node.get("role", node.get("kind", "body")))
	if points.size() >= 2:
		# Every anatomical joint is retained. The graph's budget limits complexity.
		for i: int in range(points.size()):
			var p: Vector3 = vec(points[i])
			var end: Vector3
			if i + 1 < points.size():
				end = vec(points[i + 1])
			else:
				end = p + (p - vec(points[i - 1])).normalized() * 0.04
			var bone: int = _append_bone(result, id + "_" + str(i), parent, p, end, id, i, role, node.get("joints", {}))
			bone_ids.append(bone)
			parent = bone
	else:
		var height: float = maxf(vec(node.get("size", []), Vector3.ONE).y * 0.45, 0.06)
		bone_ids.append(_append_bone(result, id, parent, position, position + Vector3.UP * height, id, 0, role, node.get("joints", {})))
	result.component_bones[id] = bone_ids

static func _append_bone(data: Dictionary, label: String, parent: int, start: Vector3, end: Vector3, component: String, segment: int, role: String, joints: Dictionary) -> int:
	var direction: Vector3 = (end - start).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector3.UP
	var reference: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x: Vector3 = direction.cross(reference).normalized()
	var z: Vector3 = x.cross(direction).normalized()
	var global_rest: Transform3D = Transform3D(Basis(x, direction, z), start)
	var rest: Transform3D = global_rest
	if parent >= 0:
		rest = data.bones[parent].global_rest.affine_inverse() * global_rest
	var bone_id: int = data.bones.size()
	var clean_name: String = label.replace(":", "_").replace("/", "_").replace(".", "_")
	data.bones.append({"name": clean_name + "_b" + str(bone_id), "parent": parent, "rest": rest, "global_rest": global_rest, "start": start, "end": end, "component_id": component, "segment_index": segment, "kind": role, "joints": joints})
	return bone_id

static func closest_component_bone(data: Dictionary, component: String, point: Vector3) -> int:
	var chain: Array = data.get("component_bones", {}).get(component, [])
	var best: int = -1
	var distance: float = INF
	for index: int in chain:
		var d: float = point.distance_squared_to(data.bones[index].start)
		if d < distance:
			distance = d
			best = index
	return best

static func instantiate(data: Dictionary) -> Skeleton3D:
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "AnatomicalSkeleton"
	for bone: Dictionary in data.get("bones", []):
		skeleton.add_bone(str(bone.name))
	for i: int in range(data.get("bones", []).size()):
		var bone: Dictionary = data.bones[i]
		skeleton.set_bone_parent(i, int(bone.parent))
		skeleton.set_bone_rest(i, bone.rest)
		skeleton.reset_bone_pose(i)
	return skeleton

static func create_skin(data: Dictionary) -> Skin:
	var skin: Skin = Skin.new()
	skin.set_bind_count(data.get("bones", []).size())
	for i: int in range(data.get("bones", []).size()):
		skin.set_bind_bone(i, i)
		# Vertices are in skeleton-local bind space. Do NOT invert local rests:
		# the inverse GLOBAL bind cancels the complete ancestor transform chain.
		skin.set_bind_pose(i, data.bones[i].global_rest.affine_inverse())
	return skin
