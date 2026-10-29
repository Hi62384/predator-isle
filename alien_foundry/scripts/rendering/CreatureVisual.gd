class_name CreatureVisual
extends Node3D
## Scene-side controls deliberately do not regenerate geometry.
const Materials = preload("res://alien_foundry/scripts/rendering/MaterialGenerator.gd")
const Diagnostics = preload("res://alien_foundry/scripts/rendering/BlobFeatureDiagnostic.gd")
const Modules = preload("res://alien_foundry/scripts/assets/ModuleLibrary.gd")
const Placement = preload("res://alien_foundry/scripts/pipeline/BlobGroundPlacement.gd")
var organism_space: Node3D
var asset_placement: Dictionary = {}
var creature_bounds: AABB = AABB(Vector3(-1,-1,-1), Vector3(2,2,2))
var body_mesh: MeshInstance3D
var skeleton: Skeleton3D
var preview: Node
var anatomy_lines: MeshInstance3D
var render_meshes: Array[MeshInstance3D] = []
var view_mode: String = "textured"
var _clay: Material
var _wire: Material

func get_creature_bounds() -> AABB:
	# Preserve the omitted-profile legacy bounds byte-for-byte. This versioned
	# intrinsic placement is translation-only, so its extent is unchanged.
	if not is_instance_valid(organism_space): return creature_bounds
	return AABB(creature_bounds.position + organism_space.transform.origin, creature_bounds.size)

func get_local_creature_bounds() -> AABB:
	return creature_bounds

func organism_to_asset_transform() -> Transform3D:
	return organism_space.transform if is_instance_valid(organism_space) else Transform3D.IDENTITY

func organism_to_asset_point(point: Vector3) -> Vector3:
	return organism_to_asset_transform() * point

func apply_asset_placement(record: Dictionary) -> void:
	# Assembly calls this once after creating all local-space components. Actor
	# transform is never repurposed as an intrinsic placement or floor control.
	if record.is_empty(): return
	asset_placement = record.duplicate(true)
	if not is_instance_valid(organism_space):
		var contents: Array[Node] = get_children()
		organism_space = Node3D.new()
		organism_space.name = "OrganismPlacement"
		add_child(organism_space)
		for child: Node in contents:
			remove_child(child)
			organism_space.add_child(child)
	organism_space.transform = Placement.transform_for(record)
	organism_space.set_meta("asset_placement", asset_placement)
	set_meta("asset_placement", asset_placement)
	set_meta("bounds", get_creature_bounds())

func set_view_mode(mode: String) -> void:
	view_mode = mode
	if _clay == null:
		_clay = Materials.clay()
	if _wire == null:
		_wire = Materials.wireframe()
	for mesh_instance: MeshInstance3D in render_meshes:
		if not is_instance_valid(mesh_instance):
			continue
		match mode:
			"clay":
				mesh_instance.material_override = _clay
			"wire", "wireframe":
				mesh_instance.material_override = _wire
			_:
				mesh_instance.material_override = null

func set_skeleton_visible(value: bool) -> void:
	if is_instance_valid(preview):
		preview.set_skeleton_visible(value)

func set_anatomy_visible(value: bool) -> void:
	if is_instance_valid(anatomy_lines):
		anatomy_lines.visible = value

func set_rig_preview(value: bool) -> void:
	if is_instance_valid(preview):
		preview.set_enabled(value)

func set_animation_enabled(value: bool) -> void:
	set_rig_preview(value)

## Staged previews use retained geometry. v1 keeps its tested four-stage
## semantics; v2 uses explicit artifact metadata, never positional relabeling.
var pipeline_stages: Array = []
var pipeline_preview: int = -1
var pipeline_stage_error := ""
var _stage_preview_roots: Dictionary = {}
var _feature_mode := "categories"
var _selected_feature_id := ""
var _include_feature_descendants := false
var stage_upload_count := 0

func set_pipeline_stages(stages: Array) -> void:
	for cached: Node3D in _stage_preview_roots.values():
		if is_instance_valid(cached): cached.free()
	_stage_preview_roots.clear()
	for instance: MeshInstance3D in render_meshes:
		if is_instance_valid(instance): instance.visible = true
	pipeline_stages = stages
	pipeline_preview = -1
	pipeline_stage_error = ""
	stage_upload_count = 0
	set_meta("pipeline_stages", stages)

func is_iterative_pipeline() -> bool:
	if pipeline_stages.is_empty(): return false
	var stage: Dictionary = pipeline_stages[0]
	var dna: Dictionary = stage.get("dna", {})
	var declaration: Dictionary = dna.get("pipeline", dna.get("metadata", {}).get("pipeline", {}))
	return int(stage.get("artifact_version", 0)) in [1, 2] and int(declaration.get("version", 0)) == 2 and str(dna.get("settings", {}).get("blob_pipeline_mode", "")) == "iterative_v2"

func stage_status(index: int) -> Dictionary:
	if index < 0 or index >= pipeline_stages.size():
		return {"available": false, "reason": "No retained stage artifact is available."}
	var stage: Dictionary = pipeline_stages[index]
	if not asset_placement.is_empty() and stage.get("asset_placement", {}).get("placement_key", "") != asset_placement.get("placement_key", ""):
		return {"available": false, "reason": "Retained stage placement differs from the common organism frame."}
	if stage.has("artifact_version"):
		if int(stage.artifact_version) not in [1, 2]:
			return {"available": false, "reason": "This retained artifact version is not supported by the preview renderer."}
		if not is_iterative_pipeline() or int(stage.get("iteration_index", 0)) not in range(1, 9) or str(stage.get("default_view", "")) not in ["clay", "material", "feature_map"]:
			return {"available": false, "reason": "The retained iterative artifact declaration is incomplete or unsupported."}
	if not bool(stage.get("available", true)):
		return {"available": false, "reason": str(stage.get("unavailable_reason", "")) if not str(stage.get("unavailable_reason", "")).is_empty() else "This stage has not been generated."}
	if stage.get("mesh_data", {}).get("vertices", PackedVector3Array()).is_empty():
		return {"available": false, "reason": "The retained geometry for this stage is missing. No substitute was generated."}
	return {"available": true, "reason": ""}

func show_pipeline_stage(index: int) -> bool:
	pipeline_stage_error = ""
	if index >= 0:
		var status: Dictionary = stage_status(index)
		if not bool(status.available):
			pipeline_stage_error = str(status.reason)
			return false
	# Build/upload the requested retained artifact before hiding the old view.
	# Repeated switching is visibility-only; no generator/cache calls live here.
	var requested: int = index if index >= 0 and index < pipeline_stages.size() else -1
	var iterative: bool = is_iterative_pipeline()
	var uses_retained: bool = requested >= 0 and (iterative or requested < 2)
	if requested >= 0 and iterative and str(pipeline_stages[requested].get("default_view", "clay")) == "material":
		uses_retained = false
	if uses_retained and not _stage_preview_roots.has(requested):
		var built: Dictionary = _build_stage_preview(requested)
		if built.has("error"):
			pipeline_stage_error = str(built.error)
			return false
		if is_instance_valid(organism_space): organism_space.add_child(built.root)
		else: add_child(built.root)
		_stage_preview_roots[requested] = built.root
		stage_upload_count += 1
	pipeline_preview = requested
	for preview_root: Node3D in _stage_preview_roots.values(): preview_root.visible = false
	for instance: MeshInstance3D in render_meshes:
		if is_instance_valid(instance): instance.visible = not uses_retained
	if pipeline_preview >= 0:
		set_rig_preview(false)
		set_skeleton_visible(false)
		set_anatomy_visible(false)
	if uses_retained:
		_stage_preview_roots[pipeline_preview].visible = true
		if iterative and str(pipeline_stages[pipeline_preview].get("default_view", "")) == "feature_map":
			Diagnostics.set_selection(_stage_preview_roots[pipeline_preview], _feature_mode, _selected_feature_id, _include_feature_descendants)
	elif pipeline_preview >= 0:
		set_view_mode("textured" if iterative or pipeline_preview == 3 else "clay")
	return true

func _build_stage_preview(index: int) -> Dictionary:
	var stage: Dictionary = pipeline_stages[index]
	if is_iterative_pipeline() and str(stage.get("default_view", "")) == "feature_map":
		return Diagnostics.build(stage)
	var root := Node3D.new()
	root.name = "PreservedStage" + str(index + 1)
	if _clay == null: _clay = Materials.clay()
	var geometry: Dictionary = stage.get("mesh_data", {})
	Diagnostics.append_clay(root, geometry, _clay)
	for detail: Dictionary in geometry.get("detail_meshes", []): Diagnostics.append_clay(root, detail, _clay)
	var problem: String = Diagnostics.append_modules(root, stage, _clay)
	if not problem.is_empty():
		root.free()
		return {"error": problem}
	root.set_meta("geometry_artifact_id", stage.get("geometry_artifact_id", stage.get("cache_key", "")))
	return {"root": root}

func set_stage_view_mode(mode: String) -> void:
	if pipeline_preview < 0 or not is_iterative_pipeline(): return
	var stage: Dictionary = pipeline_stages[pipeline_preview]
	var presentation: String = str(stage.get("default_view", "clay"))
	if presentation == "feature_map": return
	if presentation == "material":
		set_view_mode(mode)
		return
	# The four base iterations are always clay. Subsequent retained geometry
	# can also be inspected as wireframe, but never pretends to be textured.
	var actual_mode: String = "clay" if int(stage.get("iteration_index", pipeline_preview + 1)) <= 4 else mode
	if _wire == null: _wire = Materials.wireframe()
	if _clay == null: _clay = Materials.clay()
	var root: Node3D = _stage_preview_roots.get(pipeline_preview)
	if is_instance_valid(root):
		for instance: MeshInstance3D in Modules.mesh_instances(root):
			instance.material_override = _wire if actual_mode in ["wire", "wireframe"] else _clay

func set_feature_inspection(mode: String, feature_id: String, include_descendants: bool = false) -> void:
	_feature_mode = "influence" if mode == "influence" else "categories"
	_selected_feature_id = feature_id
	_include_feature_descendants = include_descendants
	if pipeline_preview >= 0 and _stage_preview_roots.has(pipeline_preview):
		var root: Node3D = _stage_preview_roots[pipeline_preview]
		if root.has_meta("diagnostic_entries"):
			Diagnostics.set_selection(root, _feature_mode, _selected_feature_id, _include_feature_descendants)

func feature_report() -> Dictionary:
	if _stage_preview_roots.has(pipeline_preview):
		var report: Dictionary = _stage_preview_roots[pipeline_preview].get_meta("diagnostic_report", {}).duplicate(true)
		if not asset_placement.is_empty():
			report["asset_placement"] = asset_placement.duplicate(true)
			report["coordinate_frame"] = "local retained vertices under shared organism-to-asset transform"
		return report
	return {}

func create_final_comparison() -> Node3D:
	# At most one final-only comparison is kept. Mesh/material resources are
	# shared, not copied, and no stage DNA, feature buffers or rig is retained.
	set_rig_preview(false)
	var result := Node3D.new()
	result.name = "CompletedSeedComparison"
	result.transform = transform
	for source: MeshInstance3D in render_meshes:
		if not is_instance_valid(source) or source.mesh == null: continue
		var instance := MeshInstance3D.new()
		instance.mesh = source.mesh
		instance.transform = global_transform.affine_inverse() * source.global_transform
		for surface: int in range(source.mesh.get_surface_count()):
			instance.set_surface_override_material(surface, source.get_surface_override_material(surface))
		for shape: int in range(source.mesh.get_blend_shape_count()):
			instance.set_blend_shape_value(shape, source.get_blend_shape_value(shape))
		result.add_child(instance)
	return result
