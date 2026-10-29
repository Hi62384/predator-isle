extends RefCounted
const HighPreview2=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy226.gd")
const HighPreview=preload("res://alien_foundry/scripts/geometry/BlobHighPreviewPolicy224.gd")
const Cavity217=preload("res://alien_foundry/scripts/geometry/BlobPrimaryCavityDispatch223.gd")
const CavityAuthor217=preload("res://alien_foundry/scripts/anatomy/BlobMantleCavityAuthor217.gd")
## Opt-in iterative anatomy, using the existing Blob morphology/region/support
## grammar and existing analytical geometry engine. No finished mesh is decoded
## into biological identity, and no legacy snapshots are renamed into stages.
const PrimaryPleat=preload("res://alien_foundry/scripts/geometry/BlobPrimaryPleat214.gd")
const CentralPleat=preload("res://alien_foundry/scripts/geometry/BlobCentralPleat215.gd")
const SacSurface=preload("res://alien_foundry/scripts/geometry/BlobSacSurface212.gd")
const SlabPolicy=preload("res://alien_foundry/scripts/geometry/BlobSlabPolicy210.gd")
const PositiveGrowth = preload("res://alien_foundry/scripts/geometry/BlobPositiveGrowth206.gd")
const AdaptiveNormal = preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal207.gd")
const BoundedNormal = preload("res://alien_foundry/scripts/geometry/BlobAdaptiveFieldNormal208.gd")
const EdgeRefinement = preload("res://alien_foundry/scripts/geometry/BlobEdgeRootRefinement204.gd")
const Direct = preload("res://alien_foundry/scripts/pipeline/BlobDirectSurfacePipeline.gd")
const SacGroup = preload("res://alien_foundry/scripts/anatomy/BlobSacGroupGrowth.gd")
const GroupField = preload("res://alien_foundry/scripts/geometry/BlobSacGroupField.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const PlanningGraph = preload("res://alien_foundry/scripts/anatomy/BlobBlueprintGraph.gd")
const Blueprint = preload("res://alien_foundry/scripts/anatomy/BlobBiologicalBlueprint.gd")
const GroundPlacement = preload("res://alien_foundry/scripts/pipeline/BlobGroundPlacement.gd")
const TendonDetail = preload("res://alien_foundry/scripts/anatomy/BlobSecondaryTendonDetail.gd")
const Artifacts = preload("res://alien_foundry/scripts/pipeline/BlobIterationArtifacts.gd")
const BaseVolume = preload("res://alien_foundry/scripts/anatomy/BlobBaseVolumeDevelopment.gd")
const BodyGroup = preload("res://alien_foundry/scripts/anatomy/BlobBodyGroupDevelopment.gd")
const MassReprofileField = preload("res://alien_foundry/scripts/geometry/BlobMassReprofileField.gd")
const MassReprofile = preload("res://alien_foundry/scripts/anatomy/BlobMassReprofileDevelopment.gd")
const BodyGroupField = preload("res://alien_foundry/scripts/geometry/BlobBodyGroupField.gd")
const BodyEnvelope = preload("res://alien_foundry/scripts/anatomy/BlobBodyEnvelopeDevelopment.gd")
const EnvelopeField = preload("res://alien_foundry/scripts/geometry/BlobBodyEnvelopeField.gd")
const CompactBody = preload("res://alien_foundry/scripts/anatomy/BlobCompactBody.gd")
const IdentityProfiles = preload("res://alien_foundry/scripts/anatomy/BlobIdentityProfiles.gd")
const IdentityRealization = preload("res://alien_foundry/scripts/anatomy/BlobIdentityRealization.gd")

static func generate(owner: RefCounted, seed_value: int, options: Dictionary) -> Dictionary:
	var preview2_choice: Dictionary=HighPreview2.selection(options)
	if preview2_choice.has("error"):return preview2_choice
	if preview2_choice.mode!=HighPreview2.OFF:return {"error":"226 HighPreview2 applies only to authenticated saved selected Stage5 DNA; generator authoring is not released."}
	var preview_choice: Dictionary=HighPreview.selection(options)
	if preview_choice.has("error"):return preview_choice
	if preview_choice.mode!=HighPreview.OFF:return {"error":"224 HighPreview currently applies only to authenticated saved selected Stage5 DNA; generator authoring is not released."}
	var cavity_choice: Dictionary=Cavity217.selection(options)
	if cavity_choice.has("error"):return cavity_choice
	var cavity_active: bool=cavity_choice.mode!=Cavity217.OFF
	var cavity_policy: GDScript=Cavity217.policy_for_options(options)
	var cavity_cache: Dictionary={}
	var cavity_report: Dictionary={}
	var surface_choice: Dictionary=SacSurface.selection(options)
	if surface_choice.has("error"):return surface_choice
	var surface_active: bool=surface_choice.mode!=SacSurface.OFF
	if surface_active and seed_value!=22:return {"error":"212 initially qualifies seed22 only; no variation fallback."}
	var slab_choice: Dictionary=SlabPolicy.selection(options)
	if slab_choice.has("error"):return slab_choice
	var positive_choice: Dictionary=PositiveGrowth.selection(options)
	if positive_choice.has("error"): return positive_choice
	var positive: bool=positive_choice.mode==PositiveGrowth.MODE
	var direct_choice: Dictionary = Direct.selection({"type": "Blob", "seed": seed_value, "settings": options})
	if not direct_choice.ok: return direct_choice
	var group_choice: Dictionary = GroupField.selection(options)
	if group_choice.has("error"): return group_choice
	var group_active: bool = group_choice.mode != GroupField.OFF
	var detail_check: Dictionary = TendonDetail.validate(options)
	if detail_check.has("error"): return detail_check
	var ground_check: Dictionary = GroundPlacement.validate_declaration({"type": "Blob", "settings": options})
	if not bool(ground_check.get("ok", false)): return ground_check
	for unsupported: String in ["blob_loaded_lobe_version", "blob_mantle_version", "blob_grown_envelope_version", "blob_hanging_load_version"]:
		if int(options.get(unsupported, 0)) != 0:
			return {"error": "The iterative foundation cannot combine with isolated legacy candidate " + unsupported + ". Saved legacy anatomy remains supported through its own mode."}
	var normal_choice: Dictionary=BoundedNormal.selection(options)
	if normal_choice.has("error"):return normal_choice
	var edge_choice: Dictionary = EdgeRefinement.selection(options)
	if edge_choice.has("error"): return edge_choice
	var volume_choice: Dictionary = BaseVolume.selection(options)
	if volume_choice.has("error"): return volume_choice
	var envelope_choice: Dictionary = EnvelopeField.selection(options)
	if envelope_choice.has("error"): return envelope_choice
	var mass_reprofile_choice: Dictionary = MassReprofileField.selection(options)
	if mass_reprofile_choice.has("error"): return mass_reprofile_choice
	var body_group_choice: Dictionary = BodyGroupField.selection(options)
	if body_group_choice.has("error"): return body_group_choice
	var body_choice: Dictionary = CompactBody.selection(options)
	if body_choice.has("error"): return body_choice
	var identity: Dictionary = IdentityProfiles.describe(seed_value, options)
	if identity.has("error"): return identity
	var g: RefCounted = PlanningGraph.new()
	var base_options: Dictionary = options.duplicate(true)
	base_options.erase(Direct.SETTING)
	base_options.erase(GroupField.SETTING)
	base_options.erase(IdentityProfiles.SETTING)
	base_options.erase(CompactBody.SETTING)
	base_options.erase(BaseVolume.SETTING)
	base_options.erase(EnvelopeField.SETTING)
	base_options.erase(BodyGroupField.SETTING)
	base_options.erase(MassReprofileField.SETTING)
	base_options.erase(EdgeRefinement.SETTING)
	base_options.erase(AdaptiveNormal.SETTING)
	base_options.erase(PositiveGrowth.SETTING)
	base_options.erase(SlabPolicy.SETTING)
	base_options.erase(SlabPolicy.PIN_SETTING)
	base_options.erase(SacSurface.SETTING)
	base_options.erase(SacSurface.PIN_SETTING)
	base_options.erase(Cavity217.SETTING)
	base_options.erase(Cavity217.PIN_SETTING)
	# Appearance/later-stage choices do not enter earlier preserved settings.
	for key in base_options.keys():
		if str(key).begins_with("material_") or key in ["surface_operations", "secondary_enabled", "blob_secondary_detail_mode", "blob_cavity_material_assignment", "blob_fiber_material_assignment", "blob_material_profile"]:
			base_options.erase(key)
	g.initialize("Blob", seed_value, base_options)
	g.dna.metadata["pipeline"] = {"version": 2, "mode": Artifacts.MODE, "rig_after_complete_geometry": true}
	g.rng.seed = owner._stream_seed(seed_value, "base.morphology")
	var morphology: Dictionary = owner._morphology(g)
	g.rng.seed = owner._stream_seed(seed_value, "base.anatomy")
	var regions: Dictionary
	var compact_active: bool = body_choice.profile == CompactBody.COMPACT and int(morphology.grammar_index) == 2
	if volume_choice.mode == BaseVolume.MODE and not compact_active:
		return {"error": "195 requires compact Blob grammar2; no unsupported-grammar fallback."}
	if compact_active:
		regions = CompactBody.build(owner, g, morphology)
		if regions.has("error"): return regions
		g.dna.settings[CompactBody.SETTING] = CompactBody.COMPACT
	else:
		regions = owner._body_regions(g, morphology)
		g.rng.seed = owner._stream_seed(seed_value, "base.contacts")
		regions["support_ids"] = owner._basal_supports(g, regions, morphology)
	g.dna.metadata["body_plan"] = morphology.grammar
	g.dna.metadata["realized_anatomy"] = morphology.duplicate(true)
	g.dna.metadata["semantic_regions"] = {"root": regions.root, "left": regions.left, "right": regions.right, "mantle": regions.mantle, "pouch": regions.pouch}
	g.dna.metadata["generator"] = "existing_blob_grammar_with_authoritative_iterative_blueprint_v1"
	if compact_active:
		g.dna.metadata.body_plan = "compact_ground_adjacent_mass"
		g.dna.metadata.realized_anatomy["source_grammar"] = morphology.grammar
		g.dna.metadata.realized_anatomy.grammar = "compact_ground_adjacent_mass"
		g.dna.metadata.realized_anatomy["body_profile"] = CompactBody.COMPACT
		g.dna.metadata.generator = "compact_body_v1_with_authoritative_iterative_blueprint_v1"
	# The existing grammar plans developed anatomical primitives. The blueprint
	# adapter registered each feature before those graph nodes were created.
	var developed: Dictionary = owner._snapshot(g, 2, Artifacts.IDS[1])
	var primitive: Dictionary = _primitive_blockout(developed)
	if volume_choice.mode == BaseVolume.MODE:
		# Stage1 remains the original graph. Stage2 develops the SAME identities.
		var volume_report: Dictionary = BaseVolume.apply(g, morphology)
		if volume_report.has("error"): return volume_report
		var support_ids: Array = regions.support_ids.duplicate()
		regions = owner._semantic_regions(g, str(regions.root), regions.hosts)
		regions["support_ids"] = support_ids
		g.dna.metadata.semantic_regions = {"root": regions.root, "left": regions.left, "right": regions.right, "mantle": regions.mantle, "pouch": regions.pouch}
		if envelope_choice.mode == EnvelopeField.MODE:
			var envelope_report: Dictionary = BodyEnvelope.apply(g)
			if envelope_report.has("error"): return envelope_report
		if body_group_choice.mode == BodyGroupField.MODE:
			var body_group_report: Dictionary = BodyGroup.apply(g)
			if body_group_report.has("error"): return body_group_report
		if mass_reprofile_choice.mode == MassReprofileField.MODE:
			var mass_reprofile_report: Dictionary = MassReprofile.apply(g)
			if mass_reprofile_report.has("error"): return mass_reprofile_report
		if edge_choice.mode==EdgeRefinement.MODE: g.dna.settings[EdgeRefinement.SETTING]=EdgeRefinement.MODE
		if normal_choice.mode!=AdaptiveNormal.OFF: g.dna.settings[AdaptiveNormal.SETTING]=normal_choice.mode
		developed = owner._snapshot(g, 2, Artifacts.IDS[1])
	var snapshots: Array = [primitive, developed]
	g.current_iteration = 3
	if identity.profile == IdentityProfiles.FOUNDATION:
		_add_primary_features(owner, g, regions, morphology)
	else:
		g.dna.settings[IdentityProfiles.SETTING] = identity.profile
		g.dna.metadata["blob_identity_profile"] = identity.duplicate(true)
		var identity_report: Dictionary = IdentityRealization.realize(owner, g, regions, morphology, identity, 3)
		if identity_report.has("error"): return identity_report
		g.dna.metadata["primary_identity_report"] = identity_report
	var primary: Dictionary = owner._snapshot(g, 3, Artifacts.IDS[2])
	if positive:
		var context_result:=PositiveGrowth.author(primary,3)
		if context_result.has("error"):return context_result
	snapshots.append(primary)
	g.current_iteration = 4
	_integrate_features(g,positive)
	if group_active: g.dna.metadata["sac_group_report"] = SacGroup.apply(g,4,group_choice.mode)
	var refined: Dictionary = owner._snapshot(g, 4, Artifacts.IDS[3])
	if positive:
		var context_result:=PositiveGrowth.author(refined,4)
		if context_result.has("error"):return context_result
	if slab_choice.mode==SlabPolicy.MODE:
		refined.settings[SlabPolicy.SETTING]=SlabPolicy.MODE;refined.settings[SlabPolicy.PIN_SETTING]=SlabPolicy.PIN
	snapshots.append(refined)
	if positive and surface_active:
		#212 matures the same three authored sacs. It does not add anatomy IDs.
		g.current_iteration=5
		var surface_report: Dictionary=SacGroup.apply(g,5,group_choice.mode)
		if surface_report.has("error"):return surface_report
		surface_report["final_rig_supported"]=false
		surface_report["scope"]="212 partial same-sac maturation; no Stage6 or final binding"
		g.dna.metadata["feature_detail_report"]=surface_report
		var surface_dna: Dictionary=owner._snapshot(g,5,Artifacts.IDS[4])
		surface_dna.settings[SacSurface.SETTING]=surface_choice.mode
		surface_dna.settings[SacSurface.PIN_SETTING]=SacSurface.pin_for_mode(surface_choice.mode)
		surface_dna.settings[SlabPolicy.SETTING]=SlabPolicy.MODE
		surface_dna.settings[SlabPolicy.PIN_SETTING]=SlabPolicy.PIN
		if surface_choice.mode in [PrimaryPleat.MODE,CentralPleat.MODE]:
			surface_dna.metadata["iteration_index"]=5
			var primary_role: Dictionary=CentralPleat.author_nodes(surface_dna) if surface_choice.mode==CentralPleat.MODE else PrimaryPleat.author_nodes(surface_dna)
			if primary_role.has("error"):return primary_role
			var initial_primary_rules: Dictionary=CentralPleat.author_rules(surface_dna) if surface_choice.mode==CentralPleat.MODE else PrimaryPleat.author_rules(surface_dna)
			if initial_primary_rules.has("error"):return initial_primary_rules
			if surface_choice.mode==CentralPleat.MODE:
				var primary_report_found: bool=false
				for feature_report: Dictionary in surface_dna.metadata.feature_detail_report.features:
					if feature_report.feature_id==CentralPleat.PRIMARY_FEATURE:
						feature_report["crease_count"]=1;primary_report_found=true
				if not primary_report_found:return {"error":"215 primary detail report is missing."}
				surface_dna.metadata.feature_detail_report["scope"]="215 partial central primary keel-pleat [1,1,0]; no Stage6 or final binding"
		var surface_context: Dictionary=PositiveGrowth.author(surface_dna,5)
		if surface_context.has("error"):return surface_context
		snapshots.append(surface_dna)
	if positive:
		var plan_blueprint: Dictionary=g.biological_blueprint.duplicate(true)
		for i in range(snapshots.size()):
			Blueprint.annotate_snapshot(snapshots[i],g.biological_blueprint,i+1)
			if i==4 and surface_choice.mode in [PrimaryPleat.MODE,CentralPleat.MODE]:
				var primary_rules: Dictionary=CentralPleat.author_rules(snapshots[i]) if surface_choice.mode==CentralPleat.MODE else PrimaryPleat.author_rules(snapshots[i])
				if primary_rules.has("error"):return primary_rules
				plan_blueprint=snapshots[i].biological_blueprint.duplicate(true)
			if i==4 and cavity_active:
				snapshots[i].settings[Cavity217.SETTING]=cavity_choice.mode
				snapshots[i].settings[Cavity217.PIN_SETTING]=cavity_policy.PIN
				var cavity_author: GDScript=Cavity217.author_for(snapshots[i])
				var cavity_authored: Dictionary=cavity_author.author(snapshots[i])
				if cavity_authored.has("error"):return {"error":cavity_authored.error,"mantle_cavity_authoring217":cavity_authored.get("report",{}),"rejected_stage5_dna":snapshots[i]}
				cavity_cache=cavity_authored.get("cache",{})
				cavity_report=cavity_authored.get("report",{})
				snapshots[i].metadata["node_count"]=14 if Cavity217.single_enabled(snapshots[i]) else 15
				plan_blueprint=snapshots[i].biological_blueprint.duplicate(true)
			snapshots[i].metadata.pipeline["stage_index"]=i+1;snapshots[i].metadata.pipeline["stage_name"]=Artifacts.IDS[i]
			Artifacts.seal_geometry_recipe(snapshots[i])
			var validation:=Blueprint.validate(snapshots[i])
			if not validation.get("ok",false):return validation
		var result: Dictionary={"mode":Artifacts.MODE,"version":2,"geometry_dnas":snapshots,"biological_blueprint":plan_blueprint,"partial_plan":true,"stop_stage":5 if surface_active else 4,"profile":surface_choice.mode if surface_active else PositiveGrowth.MODE,"later_stages_available":false,"final_rig_supported":false}
		if cavity_active:
			result["profile"]=cavity_choice.mode
			result["cavity_author_cache217"]=cavity_cache
			result["cavity_author_report217"]=cavity_report
		return result
	g.current_iteration = 5
	var detail_report: Dictionary = SacGroup.apply(g,5,group_choice.mode) if group_active else _detail_features(g)
	g.dna.metadata["feature_detail_report"] = detail_report
	var detailed: Dictionary = owner._snapshot(g, 5, Artifacts.IDS[4])
	snapshots.append(detailed)
	g.current_iteration = 6
	if options.has(TendonDetail.SETTING): g.settings[TendonDetail.SETTING] = options[TendonDetail.SETTING]
	var secondary_enabled := bool(options.get("secondary_enabled", true))
	if identity.profile == IdentityProfiles.FOUNDATION:
		var secondary_detail: Dictionary = {"status": "skipped_disabled", "operation": "longitudinal_tendon_ridges", "node_ids": []}
		if secondary_enabled: secondary_detail = _add_secondary_tendril(owner, g, regions, morphology)
		g.dna.settings["secondary_enabled"] = secondary_enabled
		g.dna.metadata["additional_anatomy_report"] = {"status": "realized_geometry" if secondary_enabled else "skipped_disabled", "operation": "secondary_tendril", "module_count": 0, "targeted_detail_status": "not_implemented_for_tendrils", "detail_scope": "New tendril has typed material and animation rules, but no later targeted detail operation in this foundation."}
		if options.get(TendonDetail.SETTING, TendonDetail.OFF) == TendonDetail.MODE:
			g.dna.metadata.additional_anatomy_report["targeted_detail_status"] = secondary_detail.status
			g.dna.metadata.additional_anatomy_report["targeted_detail"] = secondary_detail
			g.dna.metadata.additional_anatomy_report["detail_scope"] = "Rooted tendon ridges owned by the existing secondary tendril, before final binding; no new bones."
	else:
		var identity_report: Dictionary = IdentityRealization.realize(owner, g, regions, morphology, identity, 6)
		if identity_report.has("error"): return identity_report
		g.dna.settings["secondary_enabled"] = secondary_enabled
		identity_report["operation"] = "profile_secondary_tendrils"
		identity_report["module_count"] = 0
		identity_report["targeted_detail_status"] = "not_implemented_for_tendrils"
		if options.get(TendonDetail.SETTING, TendonDetail.OFF) == TendonDetail.MODE:
			var secondary_profile_detail: Dictionary = _detail_secondary_profile(g, identity_report.feature_ids)
			identity_report["targeted_detail_status"] = secondary_profile_detail.status
			identity_report["targeted_detail"] = secondary_profile_detail
		g.dna.metadata["additional_anatomy_report"] = identity_report
	var additional: Dictionary = owner._snapshot(g, 6, Artifacts.IDS[5])
	snapshots.append(additional)
	# Planning of every stage finishes before any mesh extraction. Every
	# snapshot carries one complete authoritative registry, plus explicit
	# per-stage realized/planned status and the frozen actual anatomy graph.
	for i in range(snapshots.size()):
		Blueprint.annotate_snapshot(snapshots[i], g.biological_blueprint, i + 1)
		snapshots[i].metadata.pipeline["stage_index"] = i + 1
		snapshots[i].metadata.pipeline["stage_name"] = Artifacts.IDS[i]
		Artifacts.seal_geometry_recipe(snapshots[i])
		var validation: Dictionary = Blueprint.validate(snapshots[i])
		if not bool(validation.get("ok", false)): return validation
	# Final appearance knobs never mutate the six structural snapshots.
	var final_dna: Dictionary = snapshots[5].duplicate(true)
	# Retain explicit authoring intent even when this grammar is a no-op.
	if body_choice.profile == CompactBody.COMPACT: final_dna.settings[CompactBody.SETTING] = CompactBody.COMPACT
	for key in options:
		if str(key).begins_with("material_"): final_dna.settings[key] = options[key]
	return Direct.install({"mode": Artifacts.MODE, "version": 2, "geometry_dnas": snapshots,
		"biological_blueprint": g.biological_blueprint.duplicate(true), "final_dna": final_dna}, options)

static func _primitive_blockout(developed: Dictionary) -> Dictionary:
	var result: Dictionary = developed.duplicate(true)
	for node: Dictionary in result.nodes:
		node["noise"] = 0.0
		node["deformation"] = {"phase": 0.0, "warp": 0.0, "fold_frequency": 2.0}
		node["shape"] = {"sculpt_strength": 0.0, "swelling": 0.0, "twist": 0.0, "taper": 0.0, "width": 1.0, "depth": 1.0}
		if str(node.kind) == "mass":
			# Keep the established anatomical ellipsoid extent and orientation.
			# Forcing equal-volume spheres would move attachment/ground contacts.
			var s: Vector3 = Graph.vec(node.size)
			node["blend"] = minf(s.x, minf(s.y, s.z)) * 0.065
		elif str(node.kind) == "curve":
			var points: Array = node.points
			var start_radius := float(node.radii[0])
			var end_radius := float(node.radii[-1])
			node["points"] = [points[0].duplicate(), points[-1].duplicate()]
			node["radii"] = [start_radius, end_radius]
			node["radius"] = start_radius
			node["size"] = [start_radius, start_radius, start_radius]
			node["blend"] = start_radius * 0.20
	result.metadata["iteration_operation"] = "smooth_ellipsoid_blockout_and_straight_tapered_support_capsules"
	return result

static func _add_primary_features(owner: RefCounted, g: RefCounted, regions: Dictionary, morphology: Dictionary) -> void:
	var seed_value := int(g.dna.seed)
	var hosts: Array = [regions.mantle, regions.pouch]
	for i in range(2):
		var host_id := str(hosts[i])
		var host: Dictionary = g.node(host_id)
		var id := "blob.sac.primary.%s" % i
		var rng := RandomNumberGenerator.new()
		rng.seed = Blueprint.stream_seed(seed_value, id, "primary_shape")
		var direction := Vector3(-0.55 if i == 0 else 0.75, 0.65 if i == 0 else 0.20, -0.85).normalized()
		var hs: Vector3 = Graph.vec(host.size)
		var scale := clampf(hs.length() * 0.37, 0.24, 0.48)
		var radii := Vector3(scale * rng.randf_range(0.82, 1.04), scale * rng.randf_range(1.10, 1.38), scale * 0.87)
		var position: Vector3 = owner._surface_point(host, direction, 0.98) + direction * scale * 0.28
		var recipe := {"kind": "mass", "role": "primary_sac", "position": Graph.arr(position), "size": Graph.arr(radii), "host_node_id": host_id,
			"attachment": "overlapping_host_neck", "introduction": "base_iteration_3"}
		Blueprint.declare(g.biological_blueprint, id, "sac", g.feature_for_node(host_id), 3, direction, recipe)
		g.declared_feature_id = id
		g.rng.seed = Blueprint.stream_seed(seed_value, id, "node_realization")
		var node_id: String = g.mass(host_id, "lobe", position, radii, "flesh", true)
		var n: Dictionary = g.node(node_id)
		n["noise"] = 0.0
		n["blend"] = scale * 0.12
		n["shape"] = {"sculpt_strength": 0.04}
		n["surface"] = {"growth": 0.42, "exposure": 0.12}
		if i == 1:
			# Authored cavity identity is present only when an actual subtractive
			# primitive exists. There is no colored placeholder cavity region.
			var cavity_id := "blob.cavity.sac_ostium.0"
			var cavity_position := position + direction * Graph.surface_radius(radii, direction) * 0.94
			var cavity_size := Vector3(scale * 0.26, scale * 0.30, scale * 0.32)
			Blueprint.declare(g.biological_blueprint, cavity_id, "cavity", id, 3, direction,
				{"kind": "cavity", "position": Graph.arr(cavity_position), "size": Graph.arr(cavity_size), "host_node_id": node_id})
			g.declared_feature_id = cavity_id
			var cutter: String = g.cavity(node_id, cavity_position, cavity_size)
			g.node(cutter)["surface_opening"] = false
	_add_tendril(owner, g, str(regions.mantle), "blob.tendril.primary.0", 3, Vector3(0.48, 0.80, 0.12), float(morphology.width) * 1.05)

static func _add_tendril(owner: RefCounted, g: RefCounted, host_id: String, id: String, stage: int, direction: Vector3, length: float, detail_rules: Dictionary = {}) -> void:
	direction = direction.normalized()
	var host: Dictionary = g.node(host_id)
	var start: Vector3 = owner._surface_point(host, direction, 0.77)
	var side := direction.cross(Vector3.FORWARD).normalized()
	var middle := start + direction * length * 0.67 + side * length * 0.20
	var end := start + direction * length + side * length * 0.48 - Vector3.UP * length * 0.19
	var radius := clampf(length * 0.075, 0.055, 0.11)
	var points := [start, middle, end]
	var radii := [radius, radius * 0.62, radius * 0.27]
	var recipe := {"kind": "curve", "role": "tendril", "points": [Graph.arr(start), Graph.arr(middle), Graph.arr(end)], "radii": radii.duplicate(), "host_node_id": host_id}
	var feature: Dictionary = Blueprint.declare(g.biological_blueprint, id, "tendril", g.feature_for_node(host_id), stage, direction, recipe)
	if not detail_rules.is_empty(): feature["detail_rules"] = detail_rules.duplicate(true)
	g.declared_feature_id = id
	g.rng.seed = Blueprint.stream_seed(int(g.dna.seed), id, "node_realization")
	var node_id: String = g.curve(host_id, "tendril", points, radii, "muscle", true)
	g.node(node_id)["noise"] = 0.0
	g.node(node_id)["shape"] = {"swelling": 0.0, "twist": 0.0, "taper": 0.0}

static func _integrate_features(g: RefCounted,positive: bool=false) -> void:
	# Refine the same declared features, not another random creature. Broader
	# joins and owner-mapped transition tissue make a real new field.
	var nodes: Array = g.dna.nodes.duplicate()
	for node: Dictionary in nodes:
		var feature: Dictionary = Blueprint.feature(g.biological_blueprint, str(node.feature_id))
		if str(node.kind) == "cavity": continue
		if positive and MassReprofileField.marked(node): continue
		if str(node.kind) == "mass":
			node["blend"] = float(node.blend) * (2.5 if str(feature.type) == "sac" else 1.55)
			var envelope: Variant = node.get("shape", {}).get(EnvelopeField.KEY)
			var body_group: Variant = node.get("shape", {}).get(BodyGroupField.KEY)
			var mass_reprofile: Variant = node.get("shape", {}).get(MassReprofileField.KEY)
			node["shape"] = {"sculpt_strength": 0.36 if str(feature.type) == "sac" else 0.50}
			if envelope is Dictionary: node.shape[EnvelopeField.KEY] = envelope.duplicate(true)
			if body_group is Dictionary: node.shape[BodyGroupField.KEY] = body_group.duplicate(true)
			if mass_reprofile is Dictionary: node.shape[MassReprofileField.KEY] = mass_reprofile.duplicate(true)
		if str(feature.type) == "sac":
			var host: Dictionary = g.node(str(node.parent))
			var old_p: Vector3 = Graph.vec(node.position)
			var old_size: Vector3 = Graph.vec(node.size)
			# Visible maturation of this SAME planned sac: rounded depth, weight
			# and a broader owned neck. Its authored cavity follows the parent.
			var growth := Vector3(1.20, 1.42, 1.55)
			var s: Vector3 = old_size * growth
			var direction: Vector3 = Graph.vec(feature.growth_direction)
			var p: Vector3 = old_p - Vector3.UP * old_size.y * 0.28 + direction * old_size.z * 0.08
			var scale := maxf(0.05, float(g.settings.size))
			var fixed_ground_y: float = Graph.vec(g.dna.metadata.stage_ground_translation).y
			p.y = maxf(p.y, s.y + (0.07 - fixed_ground_y) / scale)
			node["position"] = Graph.arr(p)
			node["size"] = Graph.arr(s)
			node["radius"] = minf(s.x, minf(s.y, s.z))
			node["blend"] = minf(s.x, s.z) * 0.48
			node["integration_growth"] = {"stage": 4, "scale": Graph.arr(growth), "sag": Graph.arr(p - old_p), "fixed_ground_preserved": true}
			for child: Dictionary in nodes:
				if str(child.get("parent", "")) == str(node.id) and str(child.kind) == "cavity":
					child["position"] = Graph.arr(p + (Graph.vec(child.position) - old_p) * growth)
					child["size"] = Graph.arr(Graph.vec(child.size) * growth)
					child["integration_parent_feature_id"] = str(feature.id)
			var h: Vector3 = Graph.vec(host.position)
			g.owner_feature_id = str(feature.id)
			var collar: String = g.mass(str(node.parent), "sac_transition", p.lerp(h, 0.30), s * Vector3(0.78, 0.64, 0.78), "flesh", false)
			var connector: Dictionary = g.node(collar)
			connector["noise"] = 0.0
			connector["blend"] = minf(s.x, s.z) * 0.55
			connector["shape"] = {"sculpt_strength": 0.24}
			connector["derived_connector"] = true
			connector["source_feature_id"] = str(feature.id)
		if str(feature.type) == "tendril" and str(node.kind) == "curve":
			var p0: Vector3 = Graph.vec(node.points[0])
			var original_mid: Vector3 = Graph.vec(node.points[1])
			var original_tip: Vector3 = Graph.vec(node.points[2])
			var length: float = p0.distance_to(original_tip)
			var p1: Vector3 = original_mid - Vector3.RIGHT * length * 0.13
			var p2: Vector3 = original_tip - Vector3.RIGHT * length * 0.34 - Vector3.UP * length * 0.12
			node["points"] = [Graph.arr(p0), Graph.arr(p0.lerp(p1, 0.50)), Graph.arr(p1), Graph.arr(p1.lerp(p2, 0.58) + Vector3.UP * length * 0.07), Graph.arr(p2)]
			node["integration_growth"] = {"stage": 4, "operation": "smooth_curved_tip_and_broader_neck", "root_position_preserved": true}
			var r: float = float(node.radii[0])
			node["radii"] = [r * 1.2, r * 0.94, r * 0.62, r * 0.42, r * 0.27]
			node["blend"] = r * 1.2
	g.dna.metadata["iteration_operation"] = "same_feature_sac_maturation_parent_attached_cavity_and_curved_appendage_refinement"

static func _detail_features(g: RefCounted) -> Dictionary:
	var applied: Array = []
	var density := float(g.settings.surface_detail)
	for feature: Dictionary in g.biological_blueprint.features:
		var rules: Dictionary = feature.detail_rules
		if not bool(rules.get("enabled", false)) or str(rules.get("operation", "")) != "longitudinal_folds" or density <= 0.0: continue
		var primary_id := str(feature.geometry_refs.node_ids[0])
		var primary: Dictionary = g.node(primary_id)
		if primary.is_empty(): continue
		var position: Vector3 = Graph.vec(primary.position)
		var size: Vector3 = Graph.vec(primary.size)
		var outward: Vector3 = Graph.vec(feature.growth_direction).normalized()
		var tangent := outward.cross(Vector3.UP).normalized()
		if tangent.length_squared() < 0.01: tangent = Vector3.RIGHT
		var along := tangent.cross(outward).normalized()
		var count := maxi(1, int(round(float(rules.density) * density / 0.55)))
		for i in range(count):
			var offset := (float(i) - float(count - 1) * 0.5) * 0.29
			var points: Array = []
			for j in range(5):
				var t := (float(j) / 4.0 - 0.5) * 1.55
				var direction: Vector3 = (outward + tangent * offset + along * t).normalized()
				points.append(position + direction * Graph.surface_radius(size, direction) * 0.97)
			var radius := maxf(0.022, minf(size.x, size.z) * (0.075 + density * 0.055))
			g.owner_feature_id = str(feature.id)
			g.rng.seed = Blueprint.stream_seed(int(g.dna.seed), str(feature.id), "fold.%s" % i)
			var fold_id: String = g.curve(primary_id, "sac_fold", points, [radius * 0.48, radius, radius * 1.08, radius, radius * 0.48], "flesh", false)
			var fold: Dictionary = g.node(fold_id)
			fold["noise"] = 0.0
			fold["blend"] = radius * 0.38
			fold["shape"] = {"swelling": 0.0, "twist": 0.0, "taper": 0.0}
			fold["detail_operation"] = "longitudinal_fold"
			fold["source_feature_id"] = str(feature.id)
		applied.append({"feature_id": feature.id, "type": feature.type, "operation": rules.operation, "count": count, "status": "realized_geometry"})
	return {"version": 1, "operations": applied, "scope": "Typed sac-fold foundation; not a finished porous or membrane detail library.", "status": "realized_geometry" if not applied.is_empty() else "skipped_disabled"}

static func _add_secondary_tendril(owner: RefCounted, g: RefCounted, regions: Dictionary, morphology: Dictionary) -> Dictionary:
	var id := "blob.tendril.secondary.0"
	var rules: Dictionary = TendonDetail.rules(g.settings)
	_add_tendril(owner, g, str(regions.right), id, 6, Vector3(0.94, 0.16, -0.32), float(morphology.width) * 0.95, rules)
	if rules.is_empty(): return {"status": "skipped_not_requested", "operation": "longitudinal_tendon_ridges", "node_ids": []}
	return _detail_tendril(g, id)


static func _detail_tendril(g: RefCounted, feature_id: String) -> Dictionary:
	return TendonDetail.apply(g, feature_id)

static func _detail_secondary_profile(g: RefCounted, ids: Array) -> Dictionary:
	var operations: Array = []
	var realized := 0
	for id: String in ids:
		var feature: Dictionary = Blueprint.feature(g.biological_blueprint, id)
		if feature.get("type") != "tendril" or int(feature.get("created_stage", 0)) != 6: continue
		var operation: Dictionary = TendonDetail.apply(g, id)
		operations.append(operation)
		if operation.status == "realized_geometry": realized += 1
	var status := "skipped_profile_absent"
	if not operations.is_empty():
		status = "realized_geometry" if realized == operations.size() else ("partially_realized" if realized > 0 else "skipped_disabled_or_budget")
	return {"version": 1, "operation": "longitudinal_tendon_ridges", "status": status, "operations": operations,
		"requested_features": operations.size(), "realized_features": realized, "new_bones": 0}
