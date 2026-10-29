class_name CreatureRenderer
extends RefCounted
## Two-stage threading contract: prepare is packed-data-only; assemble creates
## ArrayMesh/Skin/Skeleton3D/module resources strictly on the main scene thread.
const SkeletonBuilder = preload("res://alien_foundry/scripts/rigging/SkeletonGenerator.gd")
const Skinning = preload("res://alien_foundry/scripts/rigging/AutomaticSkinning.gd")
const Preview = preload("res://alien_foundry/scripts/rigging/RigPreview.gd")
const Materials = preload("res://alien_foundry/scripts/rendering/MaterialGenerator.gd")
const Visual = preload("res://alien_foundry/scripts/rendering/CreatureVisual.gd")
const Modules = preload("res://alien_foundry/scripts/assets/ModuleLibrary.gd")
const Volume = preload("res://alien_foundry/scripts/geometry/OrganicVolume.gd")
const MembraneCovering = preload("res://alien_foundry/scripts/geometry/BlobMembraneSurface.gd")
const LocalLattice = preload("res://alien_foundry/scripts/geometry/BlobLocalLatticeSurface.gd")
const PorousCartilage = preload("res://alien_foundry/scripts/geometry/BlobPorousCartilageSurface.gd")
const SurfaceRootBinding = preload("res://alien_foundry/scripts/rigging/ExplicitSurfaceRootBinding.gd")
const GroupFinalization = preload("res://alien_foundry/scripts/rigging/BlobSacGroupFinalization.gd")
const GroundPlacement = preload("res://alien_foundry/scripts/pipeline/BlobGroundPlacement.gd")
const TOTAL_TRIANGLE_CEILINGS: Array[int] = [150000, 300000, 500000]
const BODY_TRIANGLE_CEILINGS: Array[int] = [45000, 100000, 180000]
const DETAIL_TRIANGLE_CEILINGS: Array[int] = [35000, 65000, 120000]

## Persisted DNA cannot expand the runtime's hard ceilings. Old saves used
## max_triangles for the volume only; only the explicit total scope is inclusive.
static func resolve_triangle_budget(dna: Dictionary) -> Dictionary:
	var quality: int = clampi(int(dna.get("settings", {}).get("quality", 1)), 0, 2)
	var stored: Dictionary = dna.get("budget", {})
	var legacy: bool = str(stored.get("triangle_scope", "")) != "total"
	var limit: int = TOTAL_TRIANGLE_CEILINGS[quality]
	if not legacy:
		limit = _bounded_triangle_limit(stored.get("max_triangles", limit), limit)
	return {"quality": quality, "scope": "total", "limit": limit, "hard_limit": TOTAL_TRIANGLE_CEILINGS[quality], "legacy_scope": legacy,
		"max_body_triangles": _bounded_triangle_limit(stored.get("max_body_triangles", BODY_TRIANGLE_CEILINGS[quality]), BODY_TRIANGLE_CEILINGS[quality]),
		"max_detail_triangles": _bounded_triangle_limit(stored.get("max_detail_triangles", DETAIL_TRIANGLE_CEILINGS[quality]), DETAIL_TRIANGLE_CEILINGS[quality])}

static func _bounded_triangle_limit(value: Variant, ceiling: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return ceiling
	return int(clampf(float(value), 1.0, float(ceiling)))

static func _geometry_triangle_counts(geometry: Dictionary) -> Dictionary:
	var fused: int = _packed_triangle_count(geometry)
	var details: int = 0
	for detail: Dictionary in geometry.get("detail_meshes", []):
		details += _packed_triangle_count(detail)
	return {"fused_body": fused, "details": details, "body": fused + details}

static func _packed_triangle_count(geometry: Dictionary) -> int:
	var indices: PackedInt32Array = geometry.get("indices", PackedInt32Array())
	return indices.size() / 3 if not indices.is_empty() else geometry.get("vertices", PackedVector3Array()).size() / 3

static func _budget_error(budget: Dictionary, explanation: String) -> Dictionary:
	return {"error": explanation, "error_code": "triangle_budget_exceeded", "triangle_budget": budget}

static func _missing_prepared_module(dna: Dictionary, modules: Dictionary) -> String:
	for spec: Dictionary in dna.get("modules", []):
		var id: String = str(spec.get("id", ""))
		if not modules.has(id) or modules[id].get("surfaces", []).is_empty():
			return "Anatomical module '%s' (%s) could not be prepared. No incomplete creature was published." % [id, str(spec.get("asset", ""))]
	return ""

static func _resolved_module_specs(dna: Dictionary, geometry: Dictionary) -> Array:
	var anchors: Dictionary = {}
	for anchor: Dictionary in geometry.get("module_anchors", []):
		anchors[str(anchor.get("id", ""))] = anchor
	var specs: Array = []
	for source_spec: Dictionary in dna.get("modules", []):
		var spec: Dictionary = source_spec.duplicate(true)
		var id: String = str(spec.get("id", ""))
		if anchors.has(id):
			for field: String in ["position", "normal", "surface_grid", "surface_material", "surface_ambient_occlusion", "full_shell", "surface_mount", "mounting", "shell_surface_offset"]:
				if anchors[id].has(field):
					spec[field] = anchors[id][field]
		specs.append(spec)
	return specs

## Complete module fitting and any budget adaptation before the material stage
## or final armature. The pipeline preserves the resulting final geometry.
static func prepare_geometry(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null) -> Dictionary:
	var local_result := LocalLattice.append_geometry(dna, geometry, controls)
	if local_result.has("error") or bool(local_result.get("cancelled", false)): return local_result
	var cartilage_result := PorousCartilage.append_geometry(dna, geometry, controls)
	if cartilage_result.has("error") or bool(cartilage_result.get("cancelled", false)): return cartilage_result
	var covering: Dictionary = MembraneCovering.append_geometry(dna, geometry, controls)
	if covering.has("error") or bool(covering.get("cancelled", false)):
		return covering
	var budget: Dictionary = resolve_triangle_budget(dna)
	var generated: Dictionary = _geometry_triangle_counts(geometry)
	var has_direct: bool = not dna.get("direct_surface_carriers", []).is_empty()
	if has_direct and (int(generated.details) > int(budget.max_detail_triangles) or int(generated.body) > int(budget.limit)):
		return _budget_error(budget, "Direct layers exceed the aggregate detail/whole-creature budget; the retained body was not rebuilt.")
	var modules: Dictionary = Modules.prepare_modules(dna, geometry, controls)
	if controls != null and controls.is_cancelled():
		return {"cancelled": true}
	var missing: String = _missing_prepared_module(dna, modules)
	if not missing.is_empty():
		return {"error": missing, "error_code": "module_preparation_failed"}
	var fitted: Dictionary = Modules.fit_prepared_lods(dna, modules, int(budget.limit) - int(generated.body))
	budget.geometry_rebuilt = false
	# At most one additional generated-geometry pass. Module LoD never drops
	# faces or skips triangles: only audited offline simplification is eligible.
	if bool(fitted.over_budget):
		# Never degrade or re-ground the retained body to pay for this opt-in layer.
		if LocalLattice.has_plan(dna) or PorousCartilage.has_plan(dna) or has_direct:
			return _budget_error(budget, "The local porous layer exceeds the whole-creature budget; primary geometry was retained unchanged.")
		var available: int = int(budget.limit) - int(fitted.minimum_triangles)
		if available < 4:
			budget.minimum_module_triangles = fitted.minimum_triangles
			return _budget_error(budget, "The minimum validated anatomy cannot fit this whole-creature triangle budget.")
		var body_share: float = float(generated.fused_body) / maxf(float(generated.body), 1.0)
		var body_limit: int = mini(int(budget.max_body_triangles), maxi(1, floori(float(available) * body_share)))
		var detail_limit: int = mini(int(budget.max_detail_triangles), maxi(1, available - body_limit))
		if int(generated.details) == 0:
			body_limit = mini(int(budget.max_body_triangles), available)
		# Free first-pass arrays before resampling to keep a bounded peak RSS.
		# This dictionary belongs to the worker, never the displayed creature.
		modules.clear()
		fitted.clear()
		geometry.clear()
		if controls != null:
			controls.set_progress(0.94, "Balancing the complete creature triangle budget")
		var rebuilt: Dictionary = Volume.new().build(dna, int(budget.quality), controls, {"max_body_triangles": body_limit, "max_detail_triangles": detail_limit})
		if bool(rebuilt.get("cancelled", false)) or (controls != null and controls.is_cancelled()):
			return {"cancelled": true}
		if rebuilt.has("error"):
			return _budget_error(budget, "The complete creature cannot fit its triangle budget: " + str(rebuilt.error))
		geometry.merge(rebuilt)
		# Explicit Stage 3 sheets must refit to these actual rebuilt supports,
		# never retain roots from the discarded first extraction.
		covering = MembraneCovering.append_geometry(dna, geometry, controls)
		if covering.has("error") or bool(covering.get("cancelled", false)):
			return covering
		budget.geometry_rebuilt = true
		budget.rebuild_limits = {"max_body_triangles": body_limit, "max_detail_triangles": detail_limit}
		generated = _geometry_triangle_counts(geometry)
		modules = Modules.prepare_modules(dna, geometry, controls)
		if controls != null and controls.is_cancelled():
			return {"cancelled": true}
		missing = _missing_prepared_module(dna, modules)
		if not missing.is_empty():
			return {"error": missing, "error_code": "module_preparation_failed"}
		fitted = Modules.fit_prepared_lods(dna, modules, int(budget.limit) - int(generated.body))
	budget.fused_body = generated.fused_body
	budget.details = generated.details
	budget.body = generated.body
	budget.modules = int(fitted.triangles)
	budget.accessories = int(fitted.accessory_triangles)
	budget.total = int(generated.body) + int(fitted.triangles)
	budget.module_lods = fitted.selections
	budget.minimum_module_triangles = fitted.minimum_triangles
	budget.geometry_adaptations = geometry.get("stats", {}).get("budget_adaptations", [])
	if bool(fitted.over_budget) or int(budget.total) > int(budget.limit):
		return _budget_error(budget, "Whole-creature triangles (%d) exceed the safe budget (%d) after bounded geometry and module detail adaptation." % [budget.total, budget.limit])
	var group_proxies: Dictionary = GroupFinalization.prepare_proxies(dna,geometry)
	if group_proxies.has("error"): return group_proxies
	return {"triangle_budget": budget, "module_meshes": fitted.modules,
		"module_specs": _resolved_module_specs(dna, geometry)}

static func prepare(dna: Dictionary, geometry: Dictionary, controls: RefCounted = null, prepared: Dictionary = {}) -> Dictionary:
	var fitted: Dictionary = prepared.get("geometry", {})
	if fitted.is_empty():
		fitted = prepare_geometry(dna, geometry, controls)
	if fitted.has("error") or bool(fitted.get("cancelled", false)):
		return fitted
	var strict_geometry: bool = bool(prepared.get("strict_geometry_complete", false))
	if strict_geometry:
		for spec: Dictionary in dna.get("modules", []):
			var module: Dictionary = fitted.module_meshes.get(str(spec.get("id", "")), {})
			if not bool(module.get("accessories_prepared", false)):
				return {"error": "A secondary module has unprepared accessory geometry. No armature was generated.", "error_code": "incomplete_secondary_geometry"}
	var tissue: Dictionary = prepared.get("tissue_field", {})
	if tissue.is_empty():
		if controls != null:
			controls.set_progress(0.93, "Baking geometry-aware biological materials")
		tissue = Materials.prepare_tissue(dna, controls)
	if bool(tissue.get("cancelled", false)):
		return {"cancelled": true}
	# No vertex, module or appendage is introduced after this point.
	if controls != null:
		controls.set_progress(0.94, "Building final armature and binding complete geometry")
	var rig: Dictionary = SkeletonBuilder.build_data(dna)
	var binding_dna: Dictionary = dna
	if GroupFinalization.enabled(dna):
		var adapted: Dictionary = GroupFinalization.adapt_rig(dna,rig)
		if adapted.has("error"): return adapted
		rig = adapted.rig
		binding_dna = adapted.binding_dna
	rig.triangle_budget = fitted.triangle_budget
	rig.module_meshes = fitted.module_meshes
	rig.module_specs = fitted.get("module_specs", _resolved_module_specs(dna, geometry))
	rig.strict_geometry_complete = strict_geometry
	rig.module_bindings = {}
	for spec: Dictionary in rig.module_specs:
		var id: String = str(spec.get("id", ""))
		var component: String = str(spec.get("parent", ""))
		var origin: Vector3 = SkeletonBuilder.vec(spec.get("position", []))
		var bone_index: int = SkeletonBuilder.closest_component_bone(rig, component, origin)
		if bone_index < 0 and strict_geometry:
			return {"error": "Secondary module " + id + " has no final anatomical attachment owner.", "error_code": "invalid_module_binding"}
		rig.module_bindings[id] = {"component": component, "bone_index": bone_index, "origin": origin}
	rig.skinning = Skinning.build(binding_dna, geometry, rig, controls)
	if rig.skinning.has("error"):
		return rig.skinning
	if bool(rig.skinning.get("cancelled", false)):
		return {"cancelled": true}
	rig.validation = Skinning.validate(rig.skinning, rig.bones.size())
	rig.detail_skinning = []
	rig.detail_validation = []
	for detail: Dictionary in geometry.get("detail_meshes", []):
		var detail_skin: Dictionary = Skinning.build(binding_dna, detail, rig, controls)
		if detail_skin.has("error"):
			return detail_skin
		if bool(detail_skin.get("cancelled", false)):
			return {"cancelled": true}
		var root_binding: Dictionary = MembraneCovering.bind_roots(detail, detail_skin, geometry, rig.skinning)
		if root_binding.has("error"):
			return root_binding
		var explicit_binding := SurfaceRootBinding.bind(detail, detail_skin, geometry, rig.skinning)
		if explicit_binding.has("error"): return explicit_binding
		rig.detail_skinning.append(detail_skin)
		rig.detail_validation.append(Skinning.validate(detail_skin, rig.bones.size()))
	rig.tissue_field = tissue
	return rig

static func build(dna: Dictionary, geometry: Dictionary, rig_data: Dictionary = {}) -> Node3D:
	return assemble(dna, geometry, rig_data)

static func assemble(dna: Dictionary, geometry: Dictionary, rig_data: Dictionary = {}) -> Node3D:
	return finish_assembly(begin_assembly(dna, geometry, rig_data))

## The root remains detached while the application yields between these steps.
## The old visible organism can stay interactive until publication or cancellation.
static func begin_assembly(dna: Dictionary, geometry: Dictionary, rig_data: Dictionary = {}) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var placement_check := GroundPlacement.validate_declaration(dna)
	if not bool(placement_check.get("ok", false)):
		return {"root": null, "done": true, "aborted": true, "error": placement_check.error}
	if GroundPlacement.enabled(dna) and not dna.has("asset_placement"):
		return {"root": null, "done": true, "aborted": true, "error": "Placed assembly requires a completed reference placement record."}
	var rig: Dictionary = rig_data if not rig_data.is_empty() else prepare(dna, geometry)
	if rig.has("error") or bool(rig.get("cancelled", false)):
		return {"root": null, "done": true, "aborted": true, "error": str(rig.get("error", "Generation was cancelled.")), "triangle_budget": rig.get("triangle_budget", {})}
	var tissue_textures: Dictionary = Materials.create_tissue_textures(rig.get("tissue_field", {}))
	var root = Visual.new()
	root.name = "GeneratedOrganism"
	root.creature_bounds = geometry.get("bounds", AABB(Vector3(-1,-1,-1), Vector3(2,2,2)))
	var skeleton: Skeleton3D = SkeletonBuilder.instantiate(rig)
	root.add_child(skeleton)
	root.skeleton = skeleton
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry.get("vertices", PackedVector3Array())
	arrays[Mesh.ARRAY_NORMAL] = geometry.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_INDEX] = geometry.get("indices", PackedInt32Array())
	var colors: PackedColorArray = rig.get("skinning", {}).get("shading_colors", geometry.get("colors", PackedColorArray()))
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	var uvs: PackedVector2Array = geometry.get("uvs", PackedVector2Array())
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var uvs2: PackedVector2Array = geometry.get("uvs2", PackedVector2Array())
	if not uvs2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	if rig.has("skinning") and not rig.skinning.get("bones", PackedInt32Array()).is_empty():
		arrays[Mesh.ARRAY_BONES] = rig.skinning.bones
		arrays[Mesh.ARRAY_WEIGHTS] = rig.skinning.weights
		arrays[Mesh.ARRAY_TANGENT] = rig.skinning.tangents
	var format_flags: int = 0
	var has_bind_coordinates: bool = rig.get("skinning", {}).has("material_positions") and rig.skinning.has("material_flows")
	if has_bind_coordinates:
		arrays[Mesh.ARRAY_CUSTOM0] = rig.skinning.material_positions
		arrays[Mesh.ARRAY_CUSTOM1] = rig.skinning.material_flows
		format_flags = (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var macro_occlusion: PackedFloat32Array = geometry.get("ambient_occlusion", PackedFloat32Array())
	var has_macro_occlusion: bool = macro_occlusion.size() == arrays[Mesh.ARRAY_VERTEX].size() and not macro_occlusion.is_empty()
	if has_macro_occlusion:
		arrays[Mesh.ARRAY_CUSTOM2] = macro_occlusion
		format_flags |= Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
	var context: PackedFloat32Array = rig.get("skinning", {}).get("surface_context", PackedFloat32Array())
	var has_context: bool = context.size() == arrays[Mesh.ARRAY_VERTEX].size()*4 and not context.is_empty()
	if has_context:
		arrays[Mesh.ARRAY_CUSTOM3] = context
		format_flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
	var mesh: ArrayMesh = ArrayMesh.new()
	if not arrays[Mesh.ARRAY_VERTEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format_flags)
		var body_material: ShaderMaterial = Materials.create(dna)
		Materials.apply_tissue_textures(body_material, tissue_textures)
		body_material.set_shader_parameter("use_bind_coordinates", has_bind_coordinates)
		body_material.set_shader_parameter("use_macro_occlusion", has_macro_occlusion)
		body_material.set_shader_parameter("use_surface_context", has_context)
		mesh.surface_set_material(0, body_material)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "ContinuousOrganicSurface"
	body.mesh = mesh
	body.skin = SkeletonBuilder.create_skin(rig)
	body.skeleton = NodePath("..")
	body.extra_cull_margin = root.creature_bounds.size.length() * 0.4
	skeleton.add_child(body)
	root.body_mesh = body
	root.render_meshes.append(body)
	var specs: Array = rig.get("module_specs", _resolved_module_specs(dna, geometry)).duplicate(true)
	for spec: Dictionary in specs:
		var id: String = str(spec.get("id", ""))
		if rig.get("module_meshes", {}).has(id):
			spec.prepared_surfaces = rig.module_meshes[id]
	root.set_meta("skeleton", skeleton)
	root.set_meta("skeleton_data", rig)
	root.set_meta("rig_data", rig)
	root.set_meta("body_mesh", body)
	root.set_meta("mesh_data", geometry)
	root.set_meta("dna", dna)
	root.set_meta("bone_count", rig.bones.size())
	var body_triangles: int = _mesh_triangle_count(mesh)
	var triangle_counts: Dictionary = {"fused_body": body_triangles, "details": 0, "body": body_triangles, "modules": 0, "total": body_triangles, "per_module": {}}
	root.set_meta("tissue_textures", tissue_textures)
	root.set_meta("triangle_counts", triangle_counts)
	root.set_meta("triangle_budget", rig.get("triangle_budget", resolve_triangle_budget(dna)))
	return {"root": root, "tissue_textures": tissue_textures, "dna": dna, "geometry": geometry, "rig": rig, "specs": specs, "cursor": 0, "detail_cursor": 0, "module_count": specs.size(), "stage": "modules", "done": false, "aborted": false, "module_instances": [], "missing_modules": [], "triangle_counts": triangle_counts, "timings": {"begin_ms": (Time.get_ticks_usec() - started) / 1000.0, "detail_ms": [], "module_ms": [], "debug_ms": 0.0, "collision_ms": 0.0}}

## Exactly one module upload, or one finalization stage, per invocation.
## Returns true only when the complete detached root is ready for display.
static func step_assembly(state: Dictionary) -> bool:
	if bool(state.get("done", false)) or bool(state.get("aborted", false)):
		return true
	var root: Node3D = state.root
	var started: int = Time.get_ticks_usec()
	if int(state.detail_cursor) < state.geometry.get("detail_meshes", []).size():
		_append_detail(state, int(state.detail_cursor))
		state.detail_cursor = int(state.detail_cursor) + 1
		state.timings.detail_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		return false
	if int(state.cursor) < state.specs.size():
		_append_module(state, state.specs[int(state.cursor)])
		state.cursor = int(state.cursor) + 1
		state.timings.module_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		return false
	if str(state.stage) == "modules":
		var budget: Dictionary = state.rig.get("triangle_budget", resolve_triangle_budget(state.dna))
		budget.limit = mini(int(budget.limit), int(resolve_triangle_budget(state.dna).limit))
		if int(state.triangle_counts.total) > int(budget.limit):
			state.error = "Uploaded creature triangles (%d) exceed the complete budget (%d); the previous creature has been preserved." % [state.triangle_counts.total, budget.limit]
			state.error_code = "triangle_budget_exceeded"
			abort_assembly(state)
			return true
		budget.uploaded_total = int(state.triangle_counts.total)
		budget.prepared_matches_upload = int(budget.get("total", state.triangle_counts.total)) == int(state.triangle_counts.total)
		if bool(state.rig.get("strict_geometry_complete", false)) and not bool(budget.prepared_matches_upload):
			state.error = "Uploaded geometry differs from the complete geometry preserved before binding. The displayed creature is unchanged."
			state.error_code = "prepared_geometry_mismatch"
			abort_assembly(state)
			return true
		budget.verified_uploaded = true
		root.set_meta("triangle_budget", budget)
		state.stage = "debug"
		var preview = Preview.new()
		preview.name = "RigPreview"
		root.add_child(preview)
		preview.configure(root.skeleton, state.rig, state.module_instances)
		root.preview = preview
		root.anatomy_lines = _create_anatomy_lines(state.dna)
		root.add_child(root.anatomy_lines)
		root.anatomy_lines.visible = false
		root.set_meta("rig_preview", preview)
		state.timings.debug_ms = (Time.get_ticks_usec() - started) / 1000.0
		return false
	_add_coarse_collision(root, state.geometry)
	state.timings.collision_ms = (Time.get_ticks_usec() - started) / 1000.0
	root.set_meta("bounds", root.creature_bounds)
	root.set_meta("module_instances", state.module_instances)
	root.set_meta("missing_modules", state.missing_modules)
	root.set_meta("assembly_timings", state.timings)
	root.apply_asset_placement(state.dna.get("asset_placement", {}))
	state.stage = "complete"
	state.done = true
	return true

static func finish_assembly(state: Dictionary) -> Node3D:
	while not step_assembly(state):
		pass
	return state.get("root") if not bool(state.get("aborted", false)) else null

static func abort_assembly(state: Dictionary) -> void:
	if bool(state.get("aborted", false)):
		return
	var root: Node3D = state.get("root")
	if is_instance_valid(root):
		root.free()
	state.root = null
	state.aborted = true
	state.done = true

static func _append_module(state: Dictionary, spec: Dictionary) -> void:
	var root: Node3D = state.root
	var dna: Dictionary = state.dna
	var rig: Dictionary = state.rig
	var skeleton: Skeleton3D = root.skeleton
	var id: String = str(spec.get("id", ""))
	var fixed_binding: Dictionary = rig.get("module_bindings", {}).get(id, {})
	if bool(rig.get("strict_geometry_complete", false)) and (not bool(spec.get("prepared_surfaces", {}).get("accessories_prepared", false)) or fixed_binding.is_empty()):
		state.error = "A secondary module lost its preserved geometry or final attachment binding before upload."
		state.error_code = "incomplete_secondary_geometry"
		abort_assembly(state)
		return
	var module: Node3D = Modules.instantiate_module(spec)
	if module == null:
		state.missing_modules.append(str(spec.get("asset", "")))
		return
	# Material coordinates use the initial attachment transform, even when a
	# BoneAttachment subsequently changes the module's local coordinates.
	var host_material: String = str(spec.get("surface_material", rig.component_nodes.get(str(spec.get("parent", "")), {}).get("material", "flesh")))
	var attachment_context: Dictionary = module.get_meta("attachment_transition", {}).duplicate(true)
	attachment_context.contact_occlusion = clampf(float(spec.get("surface_ambient_occlusion", 1.0)), 0.28, 1.0)
	_setup_module_materials(module, Transform3D.IDENTITY, dna, str(spec.get("material", "flesh")), root.render_meshes, host_material, state.get("tissue_textures", {}), attachment_context)
	root.creature_bounds = _include_module_bounds(root.creature_bounds, module, Transform3D.IDENTITY)
	var rest_transform: Transform3D = module.transform
	var component: String = str(spec.get("parent", ""))
	var bone_index: int = int(fixed_binding.bone_index) if not fixed_binding.is_empty() else SkeletonBuilder.closest_component_bone(rig, component, rest_transform.origin)
	module.set_meta("final_attachment_component", component)
	module.set_meta("final_attachment_bone", bone_index)
	if bone_index >= 0:
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = module.name + "_attachment"
		attachment.bone_idx = bone_index
		attachment.bone_name = skeleton.get_bone_name(bone_index)
		attachment.transform = rig.bones[bone_index].global_rest
		skeleton.add_child(attachment)
		attachment.add_child(module)
		module.transform = rig.bones[bone_index].global_rest.affine_inverse() * rest_transform
	else:
		root.add_child(module)
	state.module_instances.append(module)
	var module_triangles: int = _node_triangle_count(module)
	state.triangle_counts.per_module[str(spec.get("id", state.cursor))] = module_triangles
	state.triangle_counts.modules = int(state.triangle_counts.modules) + module_triangles
	state.triangle_counts.total = int(state.triangle_counts.body) + int(state.triangle_counts.modules)

## Secondary tendon bridges are intentional anatomical surfaces, skinned with
## the same ownership rules rather than rigidly parented decoration.
static func _append_detail(state: Dictionary, index: int) -> void:
	var geometry: Dictionary = state.geometry.detail_meshes[index]
	var skinning: Dictionary = state.rig.detail_skinning[index]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry.get("vertices", PackedVector3Array())
	if arrays[Mesh.ARRAY_VERTEX].is_empty():
		return
	arrays[Mesh.ARRAY_NORMAL] = geometry.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_INDEX] = geometry.get("indices", PackedInt32Array())
	arrays[Mesh.ARRAY_COLOR] = skinning.shading_colors
	arrays[Mesh.ARRAY_BONES] = skinning.bones
	arrays[Mesh.ARRAY_WEIGHTS] = skinning.weights
	arrays[Mesh.ARRAY_TANGENT] = skinning.tangents
	arrays[Mesh.ARRAY_CUSTOM0] = skinning.material_positions
	arrays[Mesh.ARRAY_CUSTOM1] = skinning.material_flows
	if not geometry.get("uvs", PackedVector2Array()).is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = geometry.uvs
	if not geometry.get("uvs2", PackedVector2Array()).is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = geometry.uvs2
	var flags: int = (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var macro_occlusion: PackedFloat32Array = geometry.get("ambient_occlusion", PackedFloat32Array())
	var has_macro_occlusion: bool = macro_occlusion.size() == arrays[Mesh.ARRAY_VERTEX].size() and not macro_occlusion.is_empty()
	if has_macro_occlusion:
		arrays[Mesh.ARRAY_CUSTOM2] = macro_occlusion
		flags |= Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
	var context: PackedFloat32Array = skinning.get("surface_context", PackedFloat32Array())
	var has_context: bool = context.size() == arrays[Mesh.ARRAY_VERTEX].size()*4 and not context.is_empty()
	if has_context:
		arrays[Mesh.ARRAY_CUSTOM3] = context
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	var category: String = "membrane" if str(geometry.get("role", "")) == "membrane" else "mixed"
	var material: ShaderMaterial = Materials.create(state.dna, category)
	Materials.apply_tissue_textures(material, state.get("tissue_textures", {}))
	material.set_shader_parameter("use_bind_coordinates", true)
	material.set_shader_parameter("use_surface_context", has_context)
	material.set_shader_parameter("use_macro_occlusion", has_macro_occlusion)
	material.set_shader_parameter("use_authored_fibre_uv", str(geometry.get("fibre_uv_mode", "")) == "authored")
	if category != "membrane":
		material.set_shader_parameter("use_curve_uv", str(geometry.get("role", "")) == "tendon")
	mesh.surface_set_material(0, material)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = str(geometry.get("name", "AnatomicalDetail" + str(index)))
	instance.mesh = mesh
	instance.skin = SkeletonBuilder.create_skin(state.rig)
	instance.skeleton = NodePath("..")
	instance.extra_cull_margin = state.root.creature_bounds.size.length() * 0.4
	state.root.skeleton.add_child(instance)
	state.root.render_meshes.append(instance)
	state.root.creature_bounds = state.root.creature_bounds.merge(mesh.get_aabb())
	var count: int = _mesh_triangle_count(mesh)
	state.triangle_counts.details = int(state.triangle_counts.details) + count
	state.triangle_counts.body = int(state.triangle_counts.fused_body) + int(state.triangle_counts.details)
	state.triangle_counts.total = int(state.triangle_counts.body) + int(state.triangle_counts.modules)

## Counts the meshes actually uploaded, including teeth and optical accessories.
## Debug lines and collision approximations are deliberately excluded.
static func _mesh_triangle_count(mesh: Mesh) -> int:
	if not mesh is ArrayMesh:
		return mesh.get_faces().size() / 3
	var array_mesh: ArrayMesh = mesh as ArrayMesh
	var total: int = 0
	for surface: int in range(mesh.get_surface_count()):
		if array_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var count: int = array_mesh.surface_get_array_index_len(surface)
		if count == 0:
			count = array_mesh.surface_get_array_len(surface)
		total += count / 3
	return total

static func _node_triangle_count(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D and node.mesh:
		total += _mesh_triangle_count(node.mesh)
	for child: Node in node.get_children():
		total += _node_triangle_count(child)
	return total

static func _setup_module_materials(node: Node3D, parent_transform: Transform3D, dna: Dictionary, category: String, meshes: Array[MeshInstance3D], host_category: String = "flesh", tissue_textures: Dictionary = {}, attachment_context: Dictionary = {}) -> void:
	var local_to_creature: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh:
		meshes.append(node)
		for surface: int in range(node.mesh.get_surface_count()):
			var existing: Material = node.get_active_material(surface)
			var material_name: String = existing.resource_name.to_lower() if existing else ""
			# Keep optical organs, cavity darkness and teeth; tissue gets the same
			# procedural palette as the continuous body, not a generic solid color.
			if "cavity" in material_name or "eye" in material_name or "pupil" in material_name:
				continue
			var tissue: String = "bone" if "tooth" in material_name or "teeth" in material_name else category
			# A face/palm is anatomy, not a uniformly white decal. Soft module
			# tissue inherits the material sampled on its exposed fused carrier.
			if tissue in ["flesh", "root", "muscle", "slime"] and host_category != "":
				tissue = host_category
			var box: AABB = node.mesh.get_aabb()
			var edge_context: Dictionary = {"category": host_category, "extent": Vector2(maxf(box.size.x * 0.5, 0.01), maxf(box.size.y * 0.5, 0.01)), "center": Vector2(box.get_center().x, box.get_center().y)}
			edge_context.merge(attachment_context, true)
			if tissue == "bone":
				edge_context = {}
			node.set_surface_override_material(surface, Materials.create(dna, tissue, local_to_creature, edge_context, tissue_textures))
	for child: Node in node.get_children():
		if child is Node3D:
			_setup_module_materials(child, local_to_creature, dna, category, meshes, host_category, tissue_textures, attachment_context)

static func _include_module_bounds(bounds: AABB, node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform: Transform3D = parent_transform * node.transform
	var result: AABB = bounds
	if node is MeshInstance3D and node.mesh:
		var box: AABB = node.mesh.get_aabb()
		for i: int in range(8):
			result = result.expand(transform * box.get_endpoint(i))
	for child: Node in node.get_children():
		if child is Node3D:
			result = _include_module_bounds(result, child, transform)
	return result

static func _create_anatomy_lines(dna: Dictionary) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "AnatomyGraphDebug"
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var nodes: Dictionary = {}
	var count: int = 0
	var group_context: Dictionary = GroupFinalization.context(dna) if GroupFinalization.enabled(dna) else {"fields": {}}
	for node: Dictionary in dna.get("nodes", []):
		nodes[str(node.get("id", ""))] = node
	for node: Dictionary in dna.get("nodes", []):
		if str(node.get("kind", "")) == "cavity":
			continue
		var group: RefCounted = group_context.get("fields",{}).get(str(node.get("id","")))
		count += 1
		var position: Vector3 = SkeletonBuilder.vec(node.get("position", []))
		var size: Vector3 = SkeletonBuilder.vec(node.get("size", []), Vector3.ONE * 0.1)
		var color: Color = Color.from_hsv(fmod(float(count) * 0.618, 1.0), 0.47, 0.95)
		mesh.surface_set_color(color)
		var points: Array = node.get("points", [])
		if points.size() >= 2:
			for i: int in range(points.size() - 1):
				mesh.surface_add_vertex(SkeletonBuilder.vec(points[i]))
				mesh.surface_add_vertex(SkeletonBuilder.vec(points[i + 1]))
		else:
			for plane: int in range(3):
				for segment: int in range(24):
					for step: int in [0, 1]:
						var a: float = TAU * float(segment + step) / 24.0
						var p: Vector3
						if plane == 0:
							p = Vector3(cos(a)*size.x,sin(a)*size.y,0.0)
						elif plane == 1:
							p = Vector3(cos(a)*size.x,0.0,sin(a)*size.z)
						else:
							p = Vector3(0.0,cos(a)*size.y,sin(a)*size.z)
						mesh.surface_add_vertex(group.forward(position+p) if group != null else position+p)
		var parent: String = str(node.get("parent", ""))
		if nodes.has(parent):
			mesh.surface_add_vertex(group.forward(position) if group != null else position)
			var parent_point: Vector3 = SkeletonBuilder.vec(nodes[parent].get("position", []))
			var parent_group: RefCounted = group_context.get("fields",{}).get(parent)
			mesh.surface_add_vertex(parent_group.forward(parent_point) if parent_group != null else parent_point)
	if count == 0:
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3.UP * 0.01)
	mesh.surface_end()
	instance.mesh = mesh
	return instance

static func _add_coarse_collision(root: Node3D, geometry: Dictionary) -> void:
	var bounds: AABB = root.get_local_creature_bounds()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CoarseInspectionCollision"
	body.collision_layer = 2
	body.collision_mask = 0
	var proxies: Array = geometry.get("collision_proxies", [])
	for proxy: Dictionary in proxies:
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.name = "Proxy_" + str(body.get_child_count())
		if str(proxy.get("kind", "")) == "mapped_convex":
			var convex := ConvexPolygonShape3D.new()
			convex.points = proxy.points
			collider.shape = convex
			collider.set_meta("group_owner_id",str(proxy.group_owner_id))
			collider.set_meta("collision_scope","rest_only_inspection")
		elif str(proxy.get("kind", "")) == "capsule":
			var start: Vector3 = SkeletonBuilder.vec(proxy.get("start", []))
			var end: Vector3 = SkeletonBuilder.vec(proxy.get("end", []))
			var direction: Vector3 = (end - start).normalized()
			if direction.length_squared() < 0.1:
				direction = Vector3.UP
			var reference: Vector3 = Vector3.FORWARD if absf(direction.z) < 0.9 else Vector3.RIGHT
			var x: Vector3 = direction.cross(reference).normalized()
			var capsule: CapsuleShape3D = CapsuleShape3D.new()
			capsule.radius = maxf(float(proxy.get("radius", 0.1)), 0.005)
			capsule.height = start.distance_to(end) + capsule.radius * 2.0
			collider.shape = capsule
			collider.transform = Transform3D(Basis(x,direction,x.cross(direction)),start.lerp(end,0.5))
		else:
			# Convex 26-point ellipsoids avoid unsupported nonuniform shape scale.
			var radii: Vector3 = SkeletonBuilder.vec(proxy.get("radii", []), Vector3.ONE * 0.1)
			var points: PackedVector3Array = PackedVector3Array()
			for x: int in range(-1,2):
				for y: int in range(-1,2):
					for z: int in range(-1,2):
						if x != 0 or y != 0 or z != 0:
							points.append(Vector3(x,y,z).normalized() * radii)
			var ellipsoid: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			ellipsoid.points = points
			collider.shape = ellipsoid
			collider.position = SkeletonBuilder.vec(proxy.get("position", []))
		collider.set_meta("component", str(proxy.get("component", "")))
		body.add_child(collider)
	if proxies.is_empty():
		var collider: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = bounds.size.max(Vector3.ONE * 0.01)
		collider.shape = shape
		collider.position = bounds.get_center()
		body.add_child(collider)
	root.add_child(body)
	root.set_meta("collision_proxy_count", body.get_child_count())

static func set_view_mode(root: Node3D, mode: String) -> void:
	root.set_view_mode(mode)
static func set_skeleton_visible(root: Node3D, enabled: bool) -> void:
	root.set_skeleton_visible(enabled)
static func set_anatomy_visible(root: Node3D, enabled: bool) -> void:
	root.set_anatomy_visible(enabled)
static func set_animation_enabled(root: Node3D, enabled: bool) -> void:
	root.set_rig_preview(enabled)
