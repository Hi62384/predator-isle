class_name RigPreview
extends Node
## A reversible deformation test, not locomotion or production animation.
var skeleton: Skeleton3D
var rig_data: Dictionary = {}
var enabled: bool = false
var elapsed: float = 0.0
var amplitude: float = 1.0
var mouth_meshes: Array = []
var skeleton_lines: MeshInstance3D
var debug_material: StandardMaterial3D
var show_skeleton: bool = false

func configure(target: Skeleton3D, data: Dictionary, modules: Array) -> void:
	skeleton = target
	rig_data = data
	for module_index: int in range(modules.size()):
		_collect_mouths(modules[module_index], module_index)
	debug_material = StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.vertex_color_use_as_albedo = true
	debug_material.no_depth_test = true
	debug_material.albedo_color = Color(0.32, 0.9, 0.82)
	skeleton_lines = MeshInstance3D.new()
	skeleton_lines.name = "SkeletonDebugLines"
	skeleton_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton_lines.visible = false
	get_parent().add_child(skeleton_lines)
	_update_skeleton_lines()

func _collect_mouths(node: Node, module_group: int) -> void:
	if node is MeshInstance3D and node.mesh:
		for i: int in range(node.mesh.get_blend_shape_count()):
			var label: String = str(node.mesh.get_blend_shape_name(i)).to_lower()
			if label == "mouth_open" or label == "opening":
				mouth_meshes.append({"mesh": node, "index": i, "rest": node.get_blend_shape_value(i), "group": module_group})
	for child: Node in node.get_children():
		_collect_mouths(child, module_group)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		reset_pose()

func reset_pose() -> void:
	if is_instance_valid(skeleton):
		skeleton.reset_bone_poses()
	for mouth: Dictionary in mouth_meshes:
		if is_instance_valid(mouth.mesh):
			mouth.mesh.set_blend_shape_value(mouth.index, mouth.rest)
	elapsed = 0.0
	if show_skeleton:
		_update_skeleton_lines()

func set_skeleton_visible(value: bool) -> void:
	show_skeleton = value
	if is_instance_valid(skeleton_lines):
		skeleton_lines.visible = value
	if value:
		_update_skeleton_lines()

func _process(delta: float) -> void:
	if not is_instance_valid(skeleton):
		return
	if enabled:
		elapsed += delta
		apply_pose(elapsed)
	if show_skeleton:
		_update_skeleton_lines()

func apply_pose(time: float) -> void:
	if not is_instance_valid(skeleton):
		return
	for i: int in range(rig_data.get("bones", []).size()):
		var bone: Dictionary = rig_data.bones[i]
		var rest: Transform3D = bone.rest
		var role: String = str(bone.kind).to_lower()
		var phase: float = float(i) * 0.53 + float(bone.segment_index) * 0.38
		var angle: float = 0.025 * sin(time * 1.2 + phase)
		var axis: Vector3 = Vector3.FORWARD
		if role in ["limb", "arm", "leg", "digit", "finger"]:
			angle = 0.16 * sin(time * 1.8 + phase)
			axis = Vector3.RIGHT
		elif role in ["body_chain", "tail", "tendril", "tentacle", "neck", "antenna"]:
			angle = 0.095 * sin(time * 1.5 - float(bone.segment_index) * 0.63 + phase * 0.2)
			axis = Vector3.FORWARD
		elif "head" in role or "sensory" in role:
			angle = 0.065 * sin(time * 1.1 + phase)
			axis = Vector3.UP
		var limits: Variant = bone.get("joints", {}).get("limits", [])
		var limit: float = 0.3
		if limits is Array and limits.size() >= 2:
			limit = minf(absf(float(limits[0])), absf(float(limits[1])))
			if limit > PI:
				limit = deg_to_rad(limit)
			limit = maxf(limit, 0.01)
		angle = clampf(angle * amplitude, -limit, limit)
		# Godot 4 poses are full LOCAL transforms, not offsets from rest.
		skeleton.set_bone_pose_position(i, rest.origin)
		skeleton.set_bone_pose_rotation(i, (rest.basis.get_rotation_quaternion() * Quaternion(axis, angle)).normalized())
		var breathing: float = 1.0
		if role in ["body", "core", "torso", "pelvis", "abdomen", "segment", "lobe", "mass", "trunk"]:
			breathing += 0.012 * amplitude * sin(time * 1.65 + phase)
		skeleton.set_bone_pose_scale(i, Vector3.ONE * breathing)
	for j: int in range(mouth_meshes.size()):
		var mouth: Dictionary = mouth_meshes[j]
		if is_instance_valid(mouth.mesh):
			var opening: float = (0.5 + 0.5 * sin(time * 1.4 + float(mouth.get("group", j)) * 1.7)) * 0.72
			mouth.mesh.set_blend_shape_value(int(mouth.index), lerpf(float(mouth.rest), opening, amplitude))

func _update_skeleton_lines() -> void:
	if not is_instance_valid(skeleton_lines) or rig_data.get("bones", []).is_empty():
		return
	var lines: ImmediateMesh = ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, debug_material)
	for i: int in range(rig_data.bones.size()):
		var bone: Dictionary = rig_data.bones[i]
		var pose: Transform3D = skeleton.get_bone_global_pose(i)
		var start: Vector3 = pose.origin
		var length: float = maxf((bone.end as Vector3).distance_to(bone.start), 0.035)
		var end: Vector3 = pose * Vector3(0.0, length, 0.0)
		lines.surface_set_color(Color(0.35, 0.95, 0.82))
		lines.surface_add_vertex(start)
		lines.surface_add_vertex(end)
		var radius: float = clampf(length * 0.06, 0.012, 0.035)
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]:
			lines.surface_add_vertex(start - axis * radius)
			lines.surface_add_vertex(start + axis * radius)
		if int(bone.parent) >= 0:
			lines.surface_set_color(Color(0.75, 0.56, 0.24))
			lines.surface_add_vertex(skeleton.get_bone_global_pose(int(bone.parent)).origin)
			lines.surface_add_vertex(start)
	lines.surface_end()
	skeleton_lines.mesh = lines
