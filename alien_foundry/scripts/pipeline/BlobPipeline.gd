extends RefCounted
## Four executable stages, followed by a single final armature/bind pass.
## Intermediate DNA is saved; intermediate packed geometry stays inspectable.
## Cache dependencies are data hashes, not one shared mutable RNG or a seed alone.
const Direct = preload("res://alien_foundry/scripts/pipeline/BlobDirectSurfacePipeline.gd")
const IterativePipeline = preload("res://alien_foundry/scripts/pipeline/BlobIterativePipeline.gd")
const Generator = preload("res://alien_foundry/scripts/generators/CreatureGenerator.gd")
const Volume = preload("res://alien_foundry/scripts/geometry/OrganicVolume.gd")
const Renderer = preload("res://alien_foundry/scripts/rendering/CreatureRenderer.gd")
const LocalLattice = preload("res://alien_foundry/scripts/geometry/BlobLocalLatticeSurface.gd")
const PorousCartilage = preload("res://alien_foundry/scripts/geometry/BlobPorousCartilageSurface.gd")
const MaterialStage = preload("res://alien_foundry/scripts/pipeline/GeometryMaterialStage.gd")
const CavityMaterials = preload("res://alien_foundry/scripts/pipeline/BlobCavityMaterialContext.gd")
const FiberMaterials = preload("res://alien_foundry/scripts/pipeline/BlobFiberMaterialContext.gd")
const Cache = preload("res://alien_foundry/scripts/pipeline/PipelineCache.gd")
const Serializer = preload("res://alien_foundry/scripts/persistence/CreatureSerializer.gd")
const VERSION := 1
const STAGE_IDS := ["base_anatomy", "surface_geometry", "secondary_structures", "materials"]
const STAGE_LABELS := ["1 · Smooth base anatomy", "2 · Regional surface geometry", "3 · Secondary structures", "4 · Geometry-aware materials"]

class StageProgress:
	extends RefCounted
	var parent: RefCounted
	var offset := 0.0
	var span := 1.0
	var label := ""
	func _init(owner: RefCounted, begin: float, length: float, title: String) -> void:
		parent = owner
		offset = begin
		span = length
		label = title
	func is_cancelled() -> bool:
		return parent != null and parent.is_cancelled()
	func set_progress(value: float, detail: String) -> void:
		if parent != null:
			parent.set_progress(offset + span * clampf(value, 0.0, 1.0), label + " · " + detail)

static func supports(input: Dictionary) -> bool:
	if input.has("dna"):
		if not input.dna is Dictionary:
			return false
		var dna: Dictionary = input.dna
		# A malformed or newer staged save must fail validation, not silently
		# fall through to the old renderer and discard its intermediates.
		return str(dna.get("type", "")) == "Blob" and dna.has("pipeline")
	return str(input.get("type", "")).capitalize() == "Blob"

static func geometry_key(dna: Dictionary) -> String:
	# No palette/wetness/material seed or general metadata enters geometry keys.
	# Surface detail is irrelevant for a completely smooth Stage 1 field.
	var settings: Dictionary = dna.get("settings", {})
	var has_displacement := false
	for node: Dictionary in dna.get("nodes", []):
		if absf(float(node.get("noise", 0.0))) > 0.000001:
			has_displacement = true
			break
	var geometry_settings := {"quality": settings.get("quality", 1), "size": settings.get("size", 1.0), "irregularity": settings.get("irregularity", 0.45),
		"surface_detail": settings.get("surface_detail", 0.55) if has_displacement else 0.0}
	# Marker bytes already describe an active lip. Preserve their legacy active
	# key, but distinguish a saved marker whose real field selectors disable it.
	# Unmarked DNA (including every Stage 1) retains the exact old key schema.
	var inactive_lips: Array[String] = []
	for node: Dictionary in dna.get("nodes", []):
		var mark: Variant = node.get("contained_lip", {})
		if not mark is Dictionary or mark.is_empty() or bool(node.get("surface_opening", false)): continue
		var kind := str(node.get("kind", "mass"))
		var subtractive := kind == "cavity" or str(node.get("operation", "union")) == "subtract"
		if not subtractive or kind in ["module", "joint", "sensor", "curve"] or (node.has("points") and node.points.size() > 1): continue
		if str(node.get("role", "")) == "tendon" or str(node.get("shape", {}).get("geometry", "")) == "detail": continue
		if str(mark.get("composition", "")) != "post_subtraction_union_with_protected_throat": continue
		var version := int(mark.get("version", 0))
		if version != 1 and not (version == 2 and str(mark.get("profile", "")) == "broad_host_collar_v2"): continue
		var enabled := str(dna.get("type", "")) == "Blob" and bool(settings.get("blob_contained_lip_candidate", false))
		if version == 2: enabled = enabled and str(settings.get("blob_contained_lip_profile", "")) == "broad_host_collar_v2"
		if not enabled: inactive_lips.append(str(node.get("id", "")))
	if not inactive_lips.is_empty(): geometry_settings["inactive_contained_lip_nodes"] = inactive_lips
	var contract := {"pipeline_version": VERSION, "render_generation": dna.get("render_generation", 2), "seed": dna.get("seed", 1),
		"nodes": dna.get("nodes", []), "connections": dna.get("connections", []), "modules": dna.get("modules", []),
		"budget": dna.get("budget", {}), "settings": geometry_settings}
	return JSON.stringify(contract, "", true, true).sha256_text()

static func material_key(dna: Dictionary, final_key: String, include_assignments: bool = true) -> String:
	var contract := {"version": VERSION, "geometry": final_key, "materials": dna.get("materials", {}),
		"surface_detail": dna.get("settings", {}).get("surface_detail", 0.55),
		"material_direction": dna.get("metadata", {}).get("material_direction", ""),
		"blob_material_profile": dna.get("metadata", {}).get("blob_material_profile", "")}
	# Opt-out retains the exact pre-overlay key and field set.
	if include_assignments and CavityMaterials.is_enabled(dna): contract[CavityMaterials.SETTING] = CavityMaterials.PROFILE
	if include_assignments and FiberMaterials.is_enabled(dna): contract[FiberMaterials.SETTING] = FiberMaterials.PROFILE
	return JSON.stringify(contract, "", true, true).sha256_text()

static func _clean_snapshot(dna: Dictionary) -> Dictionary:
	var snapshot: Dictionary = dna.duplicate(true)
	snapshot.erase("pipeline")
	return snapshot

static func _plans(input: Dictionary) -> Dictionary:
	if bool(input.get("materials_only", false)) and (not input.get("dna") is Dictionary or not input.dna.has("pipeline")):
		return {"error": "A material-only refresh requires a preserved staged creature; no anatomy was regenerated."}
	if input.has("dna"):
		if not input.dna is Dictionary:
			return {"error": "The saved creature must be a complete DNA object."}
		var saved: Dictionary = input.dna
		var validation: Dictionary = Serializer.validate_dna(saved)
		if not bool(validation.get("ok", false)):
			return validation
		var persisted: Dictionary = saved.get("pipeline", {})
		if not persisted.get("base_dna") is Dictionary or not persisted.get("surface_dna") is Dictionary:
			return {"error": "The saved staged creature is missing its base or surface intermediate. The saved anatomy was not regenerated or replaced."}
		var secondary: Dictionary = _clean_snapshot(saved)
		secondary.settings.erase(CavityMaterials.SETTING)
		secondary.settings.erase(FiberMaterials.SETTING)
		return {"base_dna": _clean_snapshot(persisted.base_dna), "surface_dna": _clean_snapshot(persisted.surface_dna), "secondary_dna": secondary}
	var anatomy_options: Dictionary = input.get("settings", {}).duplicate(true)
	anatomy_options.erase(CavityMaterials.SETTING)
	anatomy_options.erase(FiberMaterials.SETTING)
	return Generator.new().generate_stages("Blob", int(input.get("seed", 1)), anatomy_options)

static func _cavity_material_assignment(input: Dictionary) -> String:
	var source: Variant = input.get("dna", input)
	if not source is Dictionary or not source.get("settings", {}) is Dictionary: return ""
	return str(source.get("settings", {}).get(CavityMaterials.SETTING, ""))

static func _fiber_material_assignment(input: Dictionary) -> String:
	var source: Variant = input.get("dna", input)
	if not source is Dictionary or not source.get("settings", {}) is Dictionary: return ""
	return str(source.get("settings", {}).get(FiberMaterials.SETTING, ""))

func build(input: Dictionary, cache: RefCounted = null, controls: RefCounted = null) -> Dictionary:
	var direct_selection: Dictionary = Direct.selection(input.get("dna", input))
	if not direct_selection.ok: return direct_selection
	var requested_mode: String = str(input.get("dna", input).get("settings", {}).get("blob_pipeline_mode", ""))
	if requested_mode not in ["", "legacy_v1", "iterative_v2"]:
		return {"error": "Unsupported explicit Blob pipeline mode: " + requested_mode}
	if requested_mode == "iterative_v2" or int(input.get("dna", {}).get("pipeline", {}).get("version", 0)) == 2:
		return IterativePipeline.new().build(input, cache, controls)
	var started := Time.get_ticks_usec()
	if controls != null and controls.is_cancelled():
		return {"cancelled": true}
	if cache == null:
		cache = Cache.new()
	var cavity_assignment: String = _cavity_material_assignment(input)
	if cavity_assignment not in ["", "off", CavityMaterials.PROFILE]:
		return {"error": "Unsupported Blob cavity material assignment: " + cavity_assignment,
			"error_code": "unsupported_blob_cavity_material_assignment"}
	var fiber_assignment: String = _fiber_material_assignment(input)
	if fiber_assignment not in ["", "off", FiberMaterials.PROFILE]:
		return {"error": "Unsupported Blob fiber material assignment: " + fiber_assignment,
			"error_code": "unsupported_blob_fiber_material_assignment"}
	var plans: Dictionary = _plans(input)
	if plans.has("error"):
		return plans
	var dna_keys := ["base_dna", "surface_dna", "secondary_dna"]
	for key: String in dna_keys:
		if not plans.get(key) is Dictionary:
			return {"error": "Blob stage planning did not return " + key + "."}
		var validation: Dictionary = Serializer.validate_dna(plans[key])
		if not bool(validation.get("ok", false)):
			return validation
	var final_dna: Dictionary = _clean_snapshot(plans.secondary_dna)
	if cavity_assignment == CavityMaterials.PROFILE: final_dna.settings[CavityMaterials.SETTING] = cavity_assignment
	if fiber_assignment == FiberMaterials.PROFILE: final_dna.settings[FiberMaterials.SETTING] = fiber_assignment
	# UI appearance selection is final-only. Never merge arbitrary metadata or
	# copy a material response into the preserved anatomical stage snapshots.
	var material_metadata: Variant = input.get("material_metadata", {})
	if str(final_dna.get("type", "")) == "Blob" and material_metadata is Dictionary and material_metadata.has("blob_material_profile"):
		if not final_dna.has("metadata"): final_dna["metadata"] = {}
		final_dna.metadata["blob_material_profile"] = str(material_metadata.blob_material_profile)
	_apply_material_options(final_dna)
	var stages: Array = []
	var hits: Dictionary = {}
	var in_run_meshes: Dictionary = {}
	var stages_started := Time.get_ticks_usec()
	for stage: int in range(3):
		if controls != null and controls.is_cancelled():
			return {"cancelled": true}
		var stage_dna: Dictionary = plans[dna_keys[stage]]
		var key: String = geometry_key(stage_dna)
		var mesh: Dictionary = cache.lookup(STAGE_IDS[stage], key)
		var hit: bool = not mesh.is_empty()
		if mesh.is_empty() and in_run_meshes.has(key):
			mesh = in_run_meshes[key].duplicate(true)
			hit = true
		var timer := Time.get_ticks_usec()
		var progress := StageProgress.new(controls, 0.03 + 0.245 * stage, 0.245, STAGE_LABELS[stage])
		progress.set_progress(0.0, "Reusing preserved geometry" if hit else "Extracting stage surface")
		if mesh.is_empty():
			mesh = Volume.new().build(stage_dna, int(stage_dna.settings.get("quality", 1)), progress)
			if mesh.has("error") or bool(mesh.get("cancelled", false)):
				return mesh
			if mesh.get("vertices", PackedVector3Array()).is_empty():
				return {"error": STAGE_LABELS[stage] + " produced no extractable surface."}
		# Local detail realization infrastructure does not determine stage meaning.
		# This geometry already belongs in the Stage 2 retained clay preview.
		if stage >= 1:
			var local_result := LocalLattice.append_geometry(stage_dna, mesh, progress)
			if local_result.has("error") or bool(local_result.get("cancelled", false)): return local_result
			var cartilage_result := PorousCartilage.append_geometry(stage_dna, mesh, progress)
			if cartilage_result.has("error") or bool(cartilage_result.get("cancelled", false)): return cartilage_result
		cache.store_value(STAGE_IDS[stage], key, mesh)
		in_run_meshes[key] = mesh
		hits[STAGE_IDS[stage]] = hit
		stages.append({"id": STAGE_IDS[stage], "label": STAGE_LABELS[stage], "dna": _clean_snapshot(stage_dna), "mesh_data": mesh,
			"cache_key": key, "cache_hit": hit, "elapsed_ms": (Time.get_ticks_usec() - timer) / 1000.0, "has_armature": false})
	var geometry: Dictionary = stages[2].mesh_data.duplicate(true)
	var final_key: String = stages[2].cache_key
	var complete_geometry: Dictionary = cache.lookup("complete_geometry", final_key)
	hits["complete_geometry"] = not complete_geometry.is_empty()
	if complete_geometry.is_empty():
		# Module deformation/LoD and any bounded volume rebuild are geometry work.
		# They must finish before the material stage and final armature creation.
		var fitted: Dictionary = Renderer.prepare_geometry(final_dna, geometry, StageProgress.new(controls, 0.765, 0.065, "3 · Finalizing every anatomical surface"))
		if fitted.has("error") or bool(fitted.get("cancelled", false)):
			return fitted
		complete_geometry = {"geometry": geometry, "prepared": fitted}
	else:
		geometry = complete_geometry.geometry
	cache.store_value("complete_geometry", final_key, complete_geometry)
	stages[2].mesh_data = geometry.duplicate(true)
	stages[2]["module_meshes"] = complete_geometry.prepared.module_meshes
	stages[2]["module_specs"] = complete_geometry.prepared.get("module_specs", [])
	var geometry_stage_ms: float = (Time.get_ticks_usec() - stages_started) / 1000.0
	var context: Dictionary = cache.lookup("material_context", final_key)
	hits["material_context"] = not context.is_empty()
	if context.is_empty():
		context = MaterialStage.build_context(final_dna, geometry, controls)
		if bool(context.get("cancelled", false)):
			return context
	cache.store_value("material_context", final_key, context)
	MaterialStage.attach_context(geometry, context)
	var cavity_context: Dictionary = {}
	if CavityMaterials.is_enabled(final_dna):
		var cavity_key: String = CavityMaterials.cache_key(final_key)
		cavity_context = cache.lookup("blob_cavity_material_context", cavity_key)
		hits["blob_cavity_material_context"] = not cavity_context.is_empty()
		if cavity_context.is_empty():
			cavity_context = CavityMaterials.build(final_dna, geometry, StageProgress.new(controls, 0.815, 0.015, STAGE_LABELS[3]))
			if cavity_context.has("error") or bool(cavity_context.get("cancelled", false)): return cavity_context
		cache.store_value("blob_cavity_material_context", cavity_key, cavity_context)
	if controls != null and controls.is_cancelled():
		return {"cancelled": true}
	var fiber_context: Dictionary = {}
	if FiberMaterials.is_enabled(final_dna):
		var fiber_key: String = FiberMaterials.cache_key(final_key)
		fiber_context = cache.lookup("blob_fiber_material_context", fiber_key)
		hits["blob_fiber_material_context"] = not fiber_context.is_empty()
		if fiber_context.is_empty():
			fiber_context = FiberMaterials.build(final_dna, geometry, controls)
			if fiber_context.has("error") or bool(fiber_context.get("cancelled", false)): return fiber_context
		cache.store_value("blob_fiber_material_context", fiber_key, fiber_context)
	var appearance_key: String = material_key(final_dna, final_key)
	# Attribution changes UV2 only; keep the unchanged atlas under its legacy key.
	var tissue_key: String = material_key(final_dna, final_key, false)
	var tissue: Dictionary = cache.lookup("material_tissue", tissue_key)
	hits["materials"] = not tissue.is_empty()
	if tissue.is_empty():
		tissue = MaterialStage.bake(final_dna, StageProgress.new(controls, 0.83, 0.09, STAGE_LABELS[3]))
		if bool(tissue.get("cancelled", false)):
			return tissue
	cache.store_value("material_tissue", tissue_key, tissue)
	stages.append({"id": STAGE_IDS[3], "label": STAGE_LABELS[3], "dna": _clean_snapshot(final_dna), "mesh_data": geometry,
		"module_meshes": complete_geometry.prepared.module_meshes, "material_context": context, "tissue_field": tissue,
		"module_specs": complete_geometry.prepared.get("module_specs", []),
		"cache_key": appearance_key, "cache_hit": hits.materials, "has_armature": false, "changes_geometry": false})
	var rig: Dictionary = cache.lookup("final_rig", final_key)
	hits["final_rig"] = not rig.is_empty()
	if rig.is_empty():
		rig = Renderer.prepare(final_dna, geometry, StageProgress.new(controls, 0.92, 0.06, "Final armature · bind · skin"),
			{"geometry": complete_geometry.prepared, "tissue_field": tissue, "strict_geometry_complete": true})
		if rig.has("error") or bool(rig.get("cancelled", false)):
			return rig
		if not bool(rig.get("validation", {}).get("valid", false)):
			return {"error": "The final complete-geometry binding failed skin validation.", "error_code": "invalid_final_binding", "validation": rig.get("validation", {})}
		for detail_validation: Dictionary in rig.get("detail_validation", []):
			if not bool(detail_validation.get("valid", false)):
				return {"error": "A final secondary surface failed skin validation.", "error_code": "invalid_final_binding", "validation": detail_validation}
	# Cached rig data is geometry-dependent. Palette changes replace tissue only.
	var binding_cache: Dictionary = rig.duplicate(true)
	binding_cache.erase("tissue_field")
	cache.store_value("final_rig", final_key, binding_cache)
	rig["tissue_field"] = tissue
	var cavity_report: Dictionary = {}
	var fiber_report: Dictionary = {}
	if CavityMaterials.is_enabled(final_dna) or FiberMaterials.is_enabled(final_dna):
		# Appearance-only upload data must not mutate complete geometry, any
		# earlier snapshot, material context or the reusable final binding.
		geometry = geometry.duplicate(true)
	if CavityMaterials.is_enabled(final_dna):
		cavity_report = CavityMaterials.apply(final_dna, geometry, cavity_context)
		stages[3].mesh_data = geometry
		stages[3]["blob_cavity_material_context"] = cavity_context
		stages[3]["blob_cavity_material_assignment"] = cavity_report
	if FiberMaterials.is_enabled(final_dna):
		# Cavity attribution and all of its guards have strict precedence.
		fiber_report = FiberMaterials.apply(final_dna, geometry, fiber_context)
		stages[3].mesh_data = geometry
		stages[3]["blob_fiber_material_context"] = fiber_context
		stages[3][FiberMaterials.SETTING] = fiber_report
	if controls != null:
		if controls.is_cancelled():
			return {"cancelled": true}
		controls.set_progress(0.98, "All four stages and final anatomical binding are ready")
	final_dna["pipeline"] = {"version": VERSION, "base_dna": _clean_snapshot(plans.base_dna), "surface_dna": _clean_snapshot(plans.surface_dna),
		"stage_order": STAGE_IDS.duplicate(), "final_binding": "after_complete_geometry_and_material_context"}
	var report := {"version": VERSION, "stage_order": STAGE_IDS.duplicate(), "final_binding_after_geometry": true,
		"cache_hits": hits, "geometry_key": final_key, "material_key": appearance_key,
		"geometry_stage_ms": geometry_stage_ms,
		"surface_operations": final_dna.get("metadata", {}).get("surface_operations", {})}
	if CavityMaterials.is_enabled(final_dna):
		report["blob_cavity_material_assignment"] = cavity_report
		report["material_tissue_key"] = tissue_key
	if FiberMaterials.is_enabled(final_dna):
		report[FiberMaterials.SETTING] = fiber_report
		report["material_tissue_key"] = tissue_key
	geometry["stats"]["pipeline"] = report
	return {"dna": final_dna, "mesh_data": geometry, "rig_data": rig, "pipeline_stages": stages, "pipeline_report": report,
		"elapsed": (Time.get_ticks_usec() - started) / 1000000.0, "target": input.get("target", "creature")}

static func _apply_material_options(dna: Dictionary) -> void:
	var settings: Dictionary = dna.get("settings", {})
	var materials: Dictionary = dna.get("materials", {})
	if settings.has("material_palette"):
		materials["palette"] = clampi(int(settings.material_palette), 0, 4)
	if settings.has("material_wetness"):
		materials["wetness"] = clampf(float(settings.material_wetness), 0.35, 1.4)
	if settings.has("material_seed"):
		materials["palette_seed"] = int(settings.material_seed)
	dna["materials"] = materials
