extends RefCounted
## Six retained geometry artifacts, then two read-only appearance/diagnostic
## artifacts. This opt-in route does not alter the legacy four-stage pipeline.
const Direct = preload("res://alien_foundry/scripts/pipeline/BlobDirectSurfacePipeline.gd")
const Carrier = preload("res://alien_foundry/scripts/geometry/DirectSurfaceFeatureCarrier.gd")
const Generator = preload("res://alien_foundry/scripts/generators/CreatureGenerator.gd")
const Volume = preload("res://alien_foundry/scripts/geometry/OrganicVolume.gd")
const Renderer = preload("res://alien_foundry/scripts/rendering/CreatureRenderer.gd")
const MaterialStage = preload("res://alien_foundry/scripts/pipeline/GeometryMaterialStage.gd")
const Cache = preload("res://alien_foundry/scripts/pipeline/PipelineCache.gd")
const Serializer = preload("res://alien_foundry/scripts/persistence/CreatureSerializer.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const GroupFinalization = preload("res://alien_foundry/scripts/rigging/BlobSacGroupFinalization.gd")
const GroupField = preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
const Placement = preload("res://alien_foundry/scripts/pipeline/BlobGroundPlacement.gd")

class StageProgress:
	extends RefCounted
	var parent: RefCounted
	var offset := 0.0
	var span := 1.0
	var label := ""
	func _init(owner: RefCounted, begin: float, length: float, title: String) -> void:
		parent = owner; offset = begin; span = length; label = title
	func is_cancelled() -> bool:
		return parent != null and parent.is_cancelled()
	func set_progress(value: float, detail: String) -> void:
		if parent != null: parent.set_progress(offset + span * clampf(value, 0.0, 1.0), label + " · " + detail)

static func _plans(input: Dictionary) -> Dictionary:
	if input.has("dna"):
		var saved: Dictionary = input.dna
		var checked: Dictionary = Serializer.validate_dna(saved)
		if not bool(checked.get("ok", false)): return checked
		if int(saved.get("pipeline", {}).get("version", 0)) != 2:
			return {"error": "An iterative rebuild needs its own preserved v2 snapshots. Legacy anatomy was not reinterpreted."}
		return {"geometry_dnas": saved.pipeline.geometry_dnas.duplicate(true), "final_dna": Artifacts.geometry_input(Artifacts.clean(saved))}
	if bool(input.get("materials_only", false)):
		return {"error": "Material-only refresh requires a preserved iterative organism."}
	return Generator.new().generate_stages("Blob", int(input.get("seed", 1)), input.get("settings", {}))

func build(input: Dictionary, cache: RefCounted = null, controls: RefCounted = null) -> Dictionary:
	var settings: Dictionary = input.get("dna",{}).get("settings",{}) if input.has("dna") else input.get("settings",{})
	if settings.get("blob_sac_group_mode","off") not in ["off",GroupField.FINAL_MODE]:
		return {"error": "184 shared sac deformation is a static geometry prototype. Final rig anchors, collision proxies and UI regeneration are not yet supported."}
	var started := Time.get_ticks_usec()
	var selected: Dictionary = input.get("dna", {"type": "Blob", "settings": input.get("settings", {})})
	var placement_check := Placement.validate_declaration(selected)
	if not bool(placement_check.get("ok", false)): return {"error": placement_check.error}
	if cache == null: cache = Cache.new()
	var plans: Dictionary = _plans(input)
	if plans.has("error"): return plans
	if not plans.get("geometry_dnas") is Array or plans.geometry_dnas.size() != 6:
		return {"error": "The iterative plan did not preserve six geometry inputs."}
	var direct_check: Dictionary = Direct.validate_plans(plans)
	if not direct_check.ok: return direct_check
	var direct_artifacts: Array = []
	var stages: Array = []
	var hits := {}
	var dependency := ""
	var artifacts: Array = []
	for i in range(6):
		if controls != null and controls.is_cancelled(): return {"cancelled": true}
		var dna: Dictionary = Artifacts.geometry_input(plans.geometry_dnas[i])
		if dna.has("error"): return dna
		var checked: Dictionary = Serializer.validate_dna(dna)
		if not bool(checked.get("ok", false)): return checked
		var key: String = Artifacts.geometry_key(dna, i + 1, dependency)
		var slot := "iterative_v2." + str(Artifacts.IDS[i])
		var geometry: Dictionary = cache.lookup(slot, key)
		var hit := not geometry.is_empty()
		var progress := StageProgress.new(controls, 0.02 + 0.12 * i, 0.12, Artifacts.LABELS[i])
		if geometry.is_empty():
			geometry = Volume.new().build(dna, int(dna.settings.quality), progress)
			if geometry.has("error") or bool(geometry.get("cancelled", false)): return geometry
			if geometry.get("vertices", PackedVector3Array()).is_empty(): return {"error": Artifacts.LABELS[i] + " has no extractable geometry."}
		var mapped: Dictionary = Blueprint.attach_influences(dna, geometry, progress)
		if mapped.has("error") or bool(mapped.get("cancelled", false)): return mapped
		cache.store_value(slot, key, geometry)
		var direct_result: Dictionary = Direct.realize(dna, geometry, key, i + 1, cache, progress)
		if direct_result.has("error") or direct_result.get("cancelled", false): return direct_result
		geometry = direct_result.geometry
		hits.merge(direct_result.hits)
		var composite_key: String = direct_result.geometry_key
		if not direct_result.surfaces.is_empty(): direct_artifacts.append(Direct.manifest_entry(i + 1, key, direct_result))
		var record: Dictionary = Artifacts.record(i + 1, dna, composite_key, dependency)
		if Direct.enabled(dna): record["body_geometry_key"] = key
		record["mesh_data"] = geometry
		record["cache_hit"] = hit
		record["module_meshes"] = {}
		record["module_specs"] = []
		if i == 4 and str(dna.metadata.get("feature_detail_report", {}).get("status", "")) == "skipped_disabled":
			record["changes_geometry"] = false
			record["operation_status"] = "skipped_disabled"
		if i == 5 and str(dna.metadata.get("additional_anatomy_report", {}).get("status", "")) == "skipped_disabled":
			record["changes_geometry"] = false
			record["operation_status"] = "skipped_disabled"
		# Stage ordinals/dependency hashes are not evidence of a geometry change.
		# This compares the same consumed projection with identical neutral key context.
		if i > 0 and Artifacts.geometry_key(dna, 0, "") == Artifacts.geometry_key(stages[i - 1].dna, 0, ""):
			record["changes_geometry"] = false
			if not record.has("operation_status"): record["operation_status"] = "skipped_no_authored_geometry_change"
		if not direct_result.surfaces.is_empty():
			record["changes_geometry"] = bool(record.changes_geometry) or bool(direct_result.get("changes_geometry", true))
			record["direct_surface_realization"] = geometry.direct_surface_realization.duplicate(true)
		if direct_result.has("planning_outcome"): record["direct_surface_planning"] = direct_result.planning_outcome.duplicate(true)
		stages.append(record)
		artifacts.append({"id": record.id, "version": Artifacts.ARTIFACT_VERSION, "key": composite_key, "depends_on": record.depends_on.duplicate(), "changes_geometry": record.changes_geometry})
		hits[str(Artifacts.IDS[i])] = hit
		dependency = key
	var final_key: String = stages[5].geometry_artifact_id
	if Direct.enabled(plans.final_dna) and input.has("dna"):
		var saved_direct: Array = input.dna.pipeline.direct_surface_artifacts
		for i in range(direct_artifacts.size()):
			if direct_artifacts[i].geometry_key != saved_direct[i].geometry_key: return {"error": "Saved direct artifact no longer matches the actual retained host; replay was rejected."}
			if Direct.Generalized.requested(plans.final_dna) and direct_artifacts[i].surfaces[0].status != saved_direct[i].surfaces[0].status: return {"error": "Saved direct realization status differs from current checked routing."}
	var final_dna: Dictionary = Artifacts.clean(plans.final_dna)
	var geometry: Dictionary = stages[5].mesh_data.duplicate(true)
	var complete_key: String = GroupFinalization.artifact_key(final_dna,final_key,"complete")
	var rig_key: String = GroupFinalization.artifact_key(final_dna,final_key,"rig")
	if Direct.enabled(final_dna): rig_key = Carrier.binding_key(dependency, final_key)
	var complete: Dictionary = cache.lookup("iterative_v2.complete_geometry", complete_key)
	hits["complete_geometry"] = not complete.is_empty()
	if complete.is_empty():
		var prepared: Dictionary = Renderer.prepare_geometry(final_dna, geometry, StageProgress.new(controls, 0.75, 0.06, "6 · Completing all anatomical geometry"))
		if prepared.has("error") or bool(prepared.get("cancelled", false)): return prepared
		var mapped: Dictionary = Blueprint.attach_influences(final_dna, geometry, controls)
		if mapped.has("error") or bool(mapped.get("cancelled", false)): return mapped
		complete = {"geometry": geometry, "prepared": prepared}
		cache.store_value("iterative_v2.complete_geometry", complete_key, complete)
	else:
		geometry = complete.geometry
	stages[5]["mesh_data"] = geometry.duplicate(true)
	stages[5]["module_meshes"] = complete.prepared.module_meshes
	stages[5]["module_specs"] = complete.prepared.get("module_specs", [])
	# Complete reference exists now; establish one intrinsic frame before final bind.
	var placement_result := Placement.resolve(final_dna, geometry, complete.prepared, final_key)
	if placement_result.has("error"): return placement_result
	var placement: Dictionary = placement_result.record
	if not placement.is_empty(): final_dna["asset_placement"] = placement.duplicate(true)
	var material_metadata: Variant = input.get("material_metadata", {})
	if material_metadata is Dictionary and material_metadata.has("blob_material_profile"):
		final_dna.metadata["blob_material_profile"] = str(material_metadata.blob_material_profile)
	_apply_material_options(final_dna)
	_apply_feature_material_rules(final_dna, geometry)
	var appearance_key: String = Artifacts.material_key(final_dna, final_key)
	var appearance: Dictionary = cache.lookup("iterative_v2.appearance", appearance_key)
	hits["materials"] = not appearance.is_empty()
	if appearance.is_empty():
		var context: Dictionary = MaterialStage.build_context(final_dna, geometry, controls)
		if bool(context.get("cancelled", false)): return context
		var tissue: Dictionary = MaterialStage.bake(final_dna, StageProgress.new(controls, 0.81, 0.09, Artifacts.LABELS[6]))
		if bool(tissue.get("cancelled", false)): return tissue
		appearance = {"material_context": context, "tissue_field": tissue}
		cache.store_value("iterative_v2.appearance", appearance_key, appearance)
	MaterialStage.attach_context(geometry, appearance.material_context)
	var material_record: Dictionary = Artifacts.record(7, final_dna, appearance_key, final_key)
	material_record.merge({"mesh_data": geometry, "module_meshes": complete.prepared.module_meshes,
		"module_specs": complete.prepared.get("module_specs", []), "geometry_artifact_id": final_key,
		"material_context": appearance.material_context, "tissue_field": appearance.tissue_field, "cache_hit": hits.materials}, true)
	stages.append(material_record)
	var diagnostic_key: String = JSON.stringify({"mode": Artifacts.MODE, "geometry": final_key,
		"features": final_dna.biological_blueprint.features, "mapping_version": 1}, "", true, true).sha256_text()
	var diagnostic: Dictionary = Artifacts.record(8, final_dna, diagnostic_key, final_key)
	diagnostic.merge({"mesh_data": geometry, "module_meshes": complete.prepared.module_meshes,
		"module_specs": complete.prepared.get("module_specs", []), "geometry_artifact_id": final_key, "cache_hit": false}, true)
	stages.append(diagnostic)
	for record: Dictionary in [material_record, diagnostic]:
		artifacts.append({"id": record.id, "version": Artifacts.ARTIFACT_VERSION, "key": record.cache_key, "depends_on": record.depends_on.duplicate(), "changes_geometry": false})
	var rig: Dictionary = cache.lookup("iterative_v2.final_rig", rig_key)
	hits["final_rig"] = not rig.is_empty()
	if rig.is_empty():
		rig = Renderer.prepare(final_dna, geometry, StageProgress.new(controls, 0.91, 0.08, "Final armature after iteration 6"),
			{"geometry": complete.prepared, "tissue_field": appearance.tissue_field, "strict_geometry_complete": true})
		if rig.has("error") or bool(rig.get("cancelled", false)): return rig
		if not bool(rig.get("validation", {}).get("valid", false)): return {"error": "The iterative final geometry failed skin validation.", "validation": rig.get("validation", {})}
		for check: Dictionary in rig.get("detail_validation", []):
			if not bool(check.get("valid", false)): return {"error": "A final detail failed skin validation.", "validation": check}
		if Direct.enabled(final_dna):
			for di in range(geometry.get("detail_meshes", []).size()):
				var detail: Dictionary = geometry.detail_meshes[di]
				if not detail.has("direct_surface_carrier"): continue
				var bound: Dictionary = Carrier.validate_binding(detail, rig.detail_skinning[di], geometry, rig.skinning, rig.bones.size())
				if not bound.ok: return bound
		var cached_rig: Dictionary = rig.duplicate(true)
		cached_rig.erase("tissue_field")
		cache.store_value("iterative_v2.final_rig", rig_key, cached_rig)
	rig["tissue_field"] = appearance.tissue_field
	if GroupFinalization.enabled(final_dna): final_dna["group_finalization"] = GroupFinalization.record(final_dna,final_key)
	final_dna["pipeline"] = {"version": 2, "mode": Artifacts.MODE, "recipe_contract_version": 2 if Direct.enabled(final_dna) else 1,
		"stage_order": Artifacts.IDS.duplicate(), "geometry_dnas": plans.geometry_dnas.duplicate(true), "artifacts": artifacts,
		"final_binding": "after_all_six_geometry_artifacts", "variant_is_geometry_stage": false}
	if Direct.enabled(final_dna):
		final_dna.pipeline["direct_surface_artifacts"] = direct_artifacts.duplicate(true)
	var report := {"version": 2, "mode": Artifacts.MODE, "stage_order": Artifacts.IDS.duplicate(), "cache_hits": hits,
		"geometry_key": final_key, "material_key": appearance_key, "final_binding_after_geometry": true,
		"feature_mapping": "overlapping_heuristic_not_exact_sdf_derivatives", "blueprint_version": 1,
		"incomplete_capabilities": ["Sac-specific tissue shader response (sac_skin is metadata only)", "Porous and membrane detail libraries", "Multi-seed artistic acceptance"],
		"scope": "Iterative Blob foundation: four base passes, typed sac folds, secondary tendril, materials and diagnostic data; not broad artistic acceptance."}
	if Direct.enabled(final_dna):
		report["body_geometry_key"] = dependency
		report["complete_key"] = complete_key
		report["rig_key"] = rig_key
		report["direct_surface_artifacts"] = direct_artifacts.duplicate(true)
		report["direct_surface_scope"] = "Canonical183b vascular network on exact seed22 group-off Preview host only; not procedural diversity or warped-host support."
		report["feature_mapping"] = "body_heuristic_overlap_and_authoritative_direct_surface_parts"
	if Direct.Generalized.requested(final_dna):
		report["direct_surface_planning"] = final_dna.metadata.direct_surface_planning.duplicate(true)
		report["direct_surface_scope"] = "Blueprint/seed/dimension-driven bounded vascular policy; no mapped185 host or broad artistic acceptance."
	if GroupFinalization.enabled(final_dna):
		report["group_finalization"] = final_dna.group_finalization.duplicate(true)
		report["complete_key"] = complete_key
		report["rig_key"] = rig_key
	var secondary_detail_status := str(final_dna.metadata.get("additional_anatomy_report", {}).get("targeted_detail_status", "not_requested"))
	report["secondary_detail_status"] = secondary_detail_status
	if secondary_detail_status != "realized_geometry": report.incomplete_capabilities.append("Secondary tendril targeted detail not realized for every secondary feature in this recipe")
	if not placement.is_empty():
		report["asset_placement"] = placement.duplicate(true)
		report["ground_contact_scope"] = "Lowest complete rest vertex only; not multi-support stability or grounded gait."
		var contact_reports: Array = []
		for stage: Dictionary in stages:
			stage["asset_placement"] = placement.duplicate(true)
			var contact := Placement.stage_report(stage, placement)
			if contact.has("error"): return contact
			stage["ground_contact"] = contact
			contact_reports.append(contact)
		report["stage_ground_contacts"] = contact_reports
	geometry.stats["pipeline"] = report
	if controls != null:
		if controls.is_cancelled(): return {"cancelled": true}
		controls.set_progress(1.0, "Eight retained artifacts and final binding ready")
	return {"dna": final_dna, "mesh_data": geometry, "rig_data": rig, "pipeline_stages": stages,
		"pipeline_report": report, "elapsed": float(Time.get_ticks_usec() - started) / 1000000.0, "target": input.get("target", "creature"),
		"materials_only": bool(input.get("materials_only", false))}

static func _apply_material_options(dna: Dictionary) -> void:
	var settings: Dictionary = dna.settings
	if settings.has("material_palette"): dna.materials["palette"] = clampi(int(settings.material_palette), 0, 4)
	if settings.has("material_wetness"): dna.materials["wetness"] = clampf(float(settings.material_wetness), 0.35, 1.4)
	if settings.has("material_seed"): dna.materials["palette_seed"] = int(settings.material_seed)

static func _apply_feature_material_rules(dna: Dictionary, geometry: Dictionary) -> void:
	var categories := ["flesh", "root", "muscle", "chitin", "bone", "membrane", "slime", "crystal"]
	var materials := {}
	for feature: Dictionary in dna.biological_blueprint.features:
		materials[str(feature.id)] = maxi(0, categories.find(str(feature.material_rules.get("material", "flesh"))))
	var meshes: Array = [geometry]
	meshes.append_array(geometry.get("detail_meshes", []))
	for mesh: Dictionary in meshes:
		var colors: PackedColorArray = mesh.get("colors", PackedColorArray()).duplicate()
		var uv2: PackedVector2Array = mesh.get("uvs2", PackedVector2Array()).duplicate()
		var ids: PackedStringArray = mesh.get("feature_ids", PackedStringArray())
		var indices: PackedInt32Array = mesh.get("feature_indices", PackedInt32Array())
		var weights: PackedFloat32Array = mesh.get("feature_weights", PackedFloat32Array())
		for i in range(colors.size()):
			var totals := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
			for slot in range(4):
				var at := i * 4 + slot
				if at >= indices.size() or indices[at] < 0 or indices[at] >= ids.size(): continue
				totals[int(materials.get(str(ids[indices[at]]), 0))] += weights[at]
			var primary := 0; var secondary := 0
			for material in range(8):
				if totals[material] > totals[primary]: primary = material
			for material in range(8):
				if material != primary and (secondary == primary or totals[material] > totals[secondary]): secondary = material
			var color: Color = colors[i]
			color.r = float(primary) / 7.0
			colors[i] = color
			if i < uv2.size(): uv2[i] = Vector2(float(secondary) / 7.0, totals[secondary] / maxf(totals[primary] + totals[secondary], 0.00001))
		mesh["colors"] = colors
		mesh["uvs2"] = uv2
