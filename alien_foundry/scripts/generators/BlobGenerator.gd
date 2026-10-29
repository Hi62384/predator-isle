extends RefCounted
## Blob-only regional anatomy. Every visible swelling grows from a common,
## asymmetrical carrier; the small internal core is not the outer silhouette.
const HANGING_SURFACE_SETTING := "blob_hanging_surface_integration_version"
const HANGING_SURFACE_OPERATIONS := ["normal_lumpy", "cavities", "fibers"]
const Direct = preload("res://alien_foundry/scripts/pipeline/BlobDirectSurfacePipeline.gd")
const Iterative = preload("res://alien_foundry/scripts/generators/BlobIterativeGenerator.gd")
const Graph = preload("res://alien_foundry/scripts/anatomy/AnatomyGraph.gd")
const RootRouting = preload("res://alien_foundry/scripts/anatomy/BlobRootRouting.gd")
const RegionalCavities = preload("res://alien_foundry/scripts/anatomy/BlobRegionalCavities.gd")
const ContainedLip = preload("res://alien_foundry/scripts/anatomy/BlobContainedLip.gd")
const PorousGrowth = preload("res://alien_foundry/scripts/anatomy/BlobPorousGrowth.gd")
const SurfaceRegions = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceRegions.gd")
const SurfaceFibers = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceFibers.gd")
const MessyTissue = preload("res://alien_foundry/scripts/anatomy/BlobMessyTissue.gd")
const MembraneCovering = preload("res://alien_foundry/scripts/anatomy/BlobMembraneCovering.gd")
const SurfaceGrowth = preload("res://alien_foundry/scripts/anatomy/BlobSurfaceGrowth.gd")
const PorousWebbing = preload("res://alien_foundry/scripts/anatomy/BlobPorousWebbing.gd")
const CavityRim = preload("res://alien_foundry/scripts/anatomy/BlobCavityRim.gd")
const LoadedLobes = preload("res://alien_foundry/scripts/anatomy/BlobLoadedLobeAnatomy.gd")
const HangingLoad = preload("res://alien_foundry/scripts/anatomy/BlobHangingLoadAnatomy.gd")
const GrownContacts = preload("res://alien_foundry/scripts/anatomy/BlobGrownContactAnatomy.gd")
const GrownEnvelope = preload("res://alien_foundry/scripts/anatomy/BlobGrownEnvelopeAnatomy.gd")
const Mantle = preload("res://alien_foundry/scripts/anatomy/BlobMantleAnatomy.gd")
const LocalLattice = preload("res://alien_foundry/scripts/anatomy/BlobLocalLattice.gd")
const PorousCartilage = preload("res://alien_foundry/scripts/anatomy/BlobPorousCartilage.gd")

func generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var direct_selection: Dictionary = Direct.selection({"type": "Blob", "seed": seed_value, "settings": options})
	if not direct_selection.ok: return direct_selection
	if str(options.get("blob_pipeline_mode", "")) not in ["", "legacy_v1", "iterative_v2"]:
		return {"error": "Unsupported explicit Blob pipeline mode."}
	if str(options.get("blob_pipeline_mode", "")) == "iterative_v2":
		var iterative: Dictionary = Iterative.generate(self, seed_value, options)
		return iterative.get("final_dna", iterative)
	return generate_stage(seed_value, options, clampi(int(options.get("blob_stage", 3)), 1, 3))

func generate_stage(seed_value: int, options: Dictionary, stage: int) -> Dictionary:
	var stages := generate_stages(seed_value, options)
	return stages[["base_dna", "surface_dna", "secondary_dna"][clampi(stage, 1, 3) - 1]]

func generate_stages(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var direct_selection: Dictionary = Direct.selection({"type": "Blob", "seed": seed_value, "settings": options})
	if not direct_selection.ok: return direct_selection
	if str(options.get("blob_pipeline_mode", "")) not in ["", "legacy_v1", "iterative_v2"]:
		return {"error": "Unsupported explicit Blob pipeline mode."}
	if str(options.get("blob_pipeline_mode", "")) == "iterative_v2":
		return Iterative.generate(self, seed_value, options)
	# Stage snapshots are independent JSON genomes, not material overrides of
	# one decorated mesh. Stage 1 is completed before any surface node exists.
	var g := Graph.new()
	# A Stage 3-only flag must not change either earlier serialized snapshot.
	var anatomy_options := options.duplicate(true)
	anatomy_options.erase("blob_membrane_candidate")
	anatomy_options.erase(HANGING_SURFACE_SETTING)
	anatomy_options.erase(LocalLattice.SETTING)
	anatomy_options.erase(PorousCartilage.SETTING)
	g.initialize("Blob", seed_value, anatomy_options)
	g.rng.seed = _stream_seed(seed_value, "base.morphology")
	var morphology := _morphology(g)
	g.rng.seed = _stream_seed(seed_value, "base.anatomy")
	var regions := _body_regions(g, morphology)
	g.rng.seed = _stream_seed(seed_value, "base.contacts")
	regions["support_ids"] = _basal_supports(g, regions, morphology)
	HangingLoad.apply(g, regions, morphology)
	_stamp_stage(g, 0, 0, 1)
	g.dna["metadata"]["body_plan"] = morphology["grammar"]
	g.dna["metadata"]["semantic_regions"] = {"root": regions["root"], "left": regions["left"], "right": regions["right"], "mantle": regions["mantle"], "pouch": regions["pouch"]}
	g.dna["metadata"]["locomotion"] = ["rolling contractile contact", "low colonial creeping", "suspended sac mass on slender fleshy roots", "off-center crawling on thick buttresses"][int(morphology["grammar_index"])]
	g.dna["metadata"]["blob_geometry_revision"] = "hanging_roots_09_clearance" if int(morphology["grammar_index"]) == 2 else "varied_growth_grammars_07"
	if g.dna["metadata"].has("loaded_lobe_anatomy"):
		g.dna["metadata"]["blob_geometry_revision"] = "hunched_loaded_lobes_v%s" % int(g.dna.metadata.loaded_lobe_anatomy.version)
	if g.dna.metadata.has("mantle_anatomy"):
		g.dna.metadata.blob_geometry_revision = "hunched_mantle_v%s" % int(g.dna.metadata.mantle_anatomy.version)
	if g.dna.metadata.has("grown_envelope_anatomy"):
		g.dna.metadata.blob_geometry_revision = "grown_envelope_v1"
	if g.dna.metadata.has("hanging_load_anatomy"):
		g.dna.metadata.blob_geometry_revision = "hanging_load_flow_v%s" % int(g.dna.metadata.hanging_load_anatomy.version)
	g.dna["metadata"]["seed_scheme"] = "SHA-256 first60bits: blob_anatomy_07|named_stream|seed"
	g.dna["metadata"]["realized_anatomy"] = morphology.duplicate(true)
	g.dna["metadata"]["realized_anatomy"]["lobe_count"] = regions["hosts"].size() - 1
	g.dna["metadata"]["realized_anatomy"]["support_count"] = regions["support_ids"].size()
	g.dna["metadata"]["realized_anatomy"]["face_count"] = 0
	g.dna["metadata"]["pipeline"] = {
		"version": 1,
		"surface_library_version": 1,
		"implemented_surface_operations": ["normal_lumpy", "bumps", "sacs", "grooves", "cavities", "webbing"],
		"legacy_surface_operations": ["nodules"],
		"surface_class_status": {"normal_lumpy": "implemented_geometry_candidate", "cavities": "implemented_geometry_candidate", "bumps": "implemented_geometry_candidate", "sacs": "implemented_geometry_candidate", "webbing": "implemented_geometry_candidate", "fibers": "not_implemented", "messy_tissue": "not_implemented"},
		"unimplemented_surface_operations": ["fibers", "messy_tissue"],
		"secondary_capabilities": ["embedded_faces"],
		"secondary_surface_reuse": false,
		"secondary_surface_reuse_note": "Existing embedded faces are authored module meshes; procedural secondary carrier surfaces are not yet implemented.",
		"rig_after_complete_geometry": true
	}
	var base := _snapshot(g, 1, "base_anatomy")
	# Capability additions belong to the surface stage, not the frozen base.
	g.dna.metadata.pipeline["unvalidated_candidate_surface_operations"] = ["fibers", "messy_tissue"]
	g.dna.metadata.pipeline.surface_class_status["fibers"] = "implemented_geometry_candidate_unvalidated"
	g.dna.metadata.pipeline.surface_class_status["messy_tissue"] = "implemented_geometry_candidate_unvalidated"
	g.dna.metadata.pipeline["surface_mode_status"] = {"fibers": {
		"adherent_fibers": "validated_geometry_limited_clay_acceptance",
		"free_tendrils": "implemented_geometry_candidate_unvalidated", "mixed_operations": "unvalidated"}}
	g.dna.metadata.pipeline.unimplemented_surface_operations = []
	var mantle_only: bool = g.dna.metadata.has("mantle_anatomy") or g.dna.metadata.has("grown_envelope_anatomy") or g.dna.metadata.has("hanging_load_anatomy")
	# One explicit surface-only integration version. Default Stage1 isolation,
	# all secondary gates and each operation's own placement gates stay intact.
	var hanging_surface := _hanging_surface_integration(g.dna, options)
	if not hanging_surface.is_empty():
		g.settings[HANGING_SURFACE_SETTING] = options[HANGING_SURFACE_SETTING]
		g.dna.metadata["hanging_surface_integration"] = hanging_surface
	var surface_isolated: bool = mantle_only and not bool(hanging_surface.get("enabled", false))
	var supplied_operations: Variant = [] if surface_isolated else options.get("surface_operations", ["nodules", "grooves"])
	var operations: Array = supplied_operations.duplicate() if supplied_operations is Array else ["nodules", "grooves"]
	if not surface_isolated and bool(options.get("blob_porous_candidate", false)) and "cavities" not in operations:
		operations.append("cavities")
	# New genomes persist their explicit choices; old saved node snapshots are
	# never rebuilt or silently mapped from the legacy nodules operation.
	g.dna["settings"]["surface_operations"] = operations.duplicate()
	g.dna["settings"]["surface_library_version"] = 1
	var surface_report := {"version":1,"requested":[],"applied":[],"unsupported":[],"porous_growth":{},"operation_results":{},"scope":"Stage1 mantle candidate; later geometry deliberately disabled"} if surface_isolated else apply_surface_operations(g, regions, morphology, operations, 2)
	if g.dna.metadata.has("grown_envelope_anatomy"):
		surface_report.scope = "Stage1 grown envelope candidate; later geometry deliberately disabled"
	if g.dna.metadata.has("hanging_load_anatomy"):
		surface_report["scope"] = "Stage1 hanging load-flow candidate; later geometry deliberately disabled"
		if bool(hanging_surface.get("enabled", false)):
			surface_report["scope"] = "Explicit hanging-v2 surface integration v1; existing placement gates authoritative; secondary geometry remains disabled"
	g.dna["metadata"]["surface_operations"] = surface_report
	g.dna["metadata"]["porous_growth"] = surface_report.get("porous_growth", {})
	g.dna["metadata"]["realized_anatomy"]["lobe_count"] = regions["hosts"].size() - 1
	# The local porous layer is surface geometry: Stage 1 is byte-identical,
	# Stage 2 owns its descriptor and preview, and Stage 3 retains it.
	# Mantle versions 1/2/3 stay strictly Stage 1-only.
	if not mantle_only and bool(options.get(LocalLattice.SETTING, false)):
		g.settings[LocalLattice.SETTING] = true
		g.dna.settings[LocalLattice.SETTING] = true
		g.dna.metadata["surface_local_lattice_plan"] = LocalLattice.plan(g, regions)
	if not mantle_only and bool(options.get(PorousCartilage.SETTING, false)):
		g.settings[PorousCartilage.SETTING] = true
		g.dna.settings[PorousCartilage.SETTING] = true
		g.dna.metadata["surface_porous_cartilage_plan"] = PorousCartilage.plan(g, regions)
	var surface := _snapshot(g, 2, "regional_surface_geometry")
	if options.has("blob_membrane_candidate"):
		g.settings["blob_membrane_candidate"] = bool(options.blob_membrane_candidate)
		g.dna.settings["blob_membrane_candidate"] = bool(options.blob_membrane_candidate)
	var start_nodes: int = g.dna["nodes"].size()
	var start_modules: int = g.dna["modules"].size()
	# Secondary anatomy has its own random stream. Surface-operation choices
	# must never select a different face or alter the completed base body.
	g.rng.seed = _stream_seed(seed_value, "secondary.faces")
	var face_count := 0
	if not mantle_only and bool(options.get("secondary_enabled", true)):
		face_count = _embedded_faces(g, regions, morphology)
	_stamp_stage(g, start_nodes, start_modules, 3)
	g.dna["metadata"]["realized_anatomy"]["face_count"] = face_count
	if not mantle_only and bool(options.get("blob_membrane_candidate", false)):
		g.dna.metadata["secondary_membrane_plan"] = MembraneCovering.plan(g, regions, morphology)
	g.dna["metadata"]["pipeline"]["secondary_surface_operations_requested"] = options.get("secondary_surface_operations", []).duplicate()
	var secondary := _snapshot(g, 3, "secondary_anatomy")
	return {"base_dna": base, "surface_dna": surface, "secondary_dna": secondary}

func _hanging_surface_integration(dna: Dictionary, options: Dictionary) -> Dictionary:
	# False/zero/absent is the exact historical route. Unknown requests never
	# unlock any anatomy or operation, and are reported on later snapshots only.
	var value: Variant = options.get(HANGING_SURFACE_SETTING, 0)
	if value is bool and not value: return {}
	if (value is int or value is float) and float(value) == 0.0: return {}
	var report := {"version": 1, "enabled": false, "status": "unsupported_integration_version",
		"stage": 2, "secondary_enabled": false, "default_isolation_preserved": true,
		"operation_algorithms_and_safety_gates_changed": false}
	if not (value is int or value is float) or float(value) != 1.0: return report
	if int(dna.get("metadata", {}).get("hanging_load_anatomy", {}).get("version", 0)) != 2:
		report.status = "unsupported_anatomy_or_hanging_version"; return report
	var requested: Variant = options.get("surface_operations")
	if not requested is Array:
		report.status = "unsupported_surface_operation_list"; return report
	for operation: Variant in requested:
		if str(operation) not in HANGING_SURFACE_OPERATIONS:
			report.status = "unsupported_surface_operation"; report["rejected_operation"] = str(operation); return report
	if str(options.get("blob_fiber_mode", "adherent_fibers")) != "adherent_fibers":
		report.status = "unsupported_fiber_mode"; return report
	report.enabled = true; report.status = "enabled_candidate_not_visually_accepted"
	report["requested_operations"] = requested.duplicate()
	return report

func apply_surface_operations(g: RefCounted, regions: Dictionary, morphology: Dictionary, operations: Array, stage: int = 2) -> Dictionary:
	# Reusable graph adapter: a future secondary carrier can supply its own
	# regions and local dimensions. No operation silently substitutes a shader.
	var report := {"version": 1, "requested": operations.duplicate(), "applied": [], "unsupported": [], "porous_growth": {}, "operation_results": {}}
	var seed_value := int(g.dna["seed"])
	for requested in operations:
		if str(requested) not in ["nodules", "grooves", "cavities", "normal_lumpy", "bumps", "sacs", "webbing", "fibers", "messy_tissue"]:
			report["unsupported"].append(str(requested))
	var start_nodes: int = g.dna["nodes"].size()
	var start_modules: int = g.dna["modules"].size()
	# Canonical order and independent streams make combinations reproducible.
	# Additions complete before subtractive cavities, then a field-checked web.
	var regional_plan := SurfaceRegions.build(g, regions, morphology, operations, stage)
	if "nodules" in operations:
		g.rng.seed = _stream_seed(seed_value, "surface.nodules")
		_subsidiary_sacs(g, regions, morphology)
		report["applied"].append("nodules")
	for operation in ["sacs", "normal_lumpy", "bumps"]:
		if operation in operations:
			var result := SurfaceGrowth.apply(g, regional_plan.records, morphology, operation, stage)
			report.operation_results[operation] = result
			if int(result.get("accepted", 0)) > 0: report.applied.append(operation)
	if "grooves" in operations:
		g.rng.seed = _stream_seed(seed_value, "surface.grooves")
		_regional_clefts(g, regions, morphology)
		report["applied"].append("grooves")
	if "cavities" in operations:
		g.rng.seed = _stream_seed(seed_value, "surface.cavities")
		var growth_morphology := morphology.duplicate(true)
		growth_morphology["grow_matrix"] = false
		growth_morphology["pipeline_stage"] = stage
		growth_morphology["domain_id"] = "primary_body"
		growth_morphology["stream_id"] = "surface.cavities"
		growth_morphology["application_id"] = "primary_body.cavities"
		report["porous_growth"] = RegionalCavities.grow(g, regions, growth_morphology, regional_plan.records) if "sacs" in operations else PorousGrowth.grow(g, regions, growth_morphology)
		var old_rim := bool(g.settings.get("blob_cavity_rim_candidate", false))
		var contained_lip := bool(g.settings.get("blob_contained_lip_candidate", false))
		if old_rim and contained_lip:
			var conflict := {"enabled": false, "status": "mutually_exclusive_candidates", "skip_reason": "Choose either the old curve rim or the contained lip, never both."}
			report["cavity_rim"] = conflict.duplicate(true); report["contained_lip"] = conflict.duplicate(true)
		elif contained_lip:
			report["contained_lip"] = ContainedLip.grow(g, report.porous_growth, growth_morphology)
		elif old_rim:
			report["cavity_rim"] = CavityRim.grow(g, report.porous_growth, growth_morphology)
		if bool(report["porous_growth"].get("enabled", false)):
			report["applied"].append("cavities")
	if "webbing" in operations:
		var web_morphology := morphology.duplicate(true)
		web_morphology.merge({"pipeline_stage": stage, "domain_id": "primary_body", "stream_id": "surface.webbing", "application_id": "primary_body.webbing", "webbing_enabled": true, "surface_regions": regional_plan.records}, true)
		report["webbing"] = PorousWebbing.grow(g, regions, web_morphology)
		_register_reported_region(g, regional_plan.records, report.webbing, "webbing")
		if bool(report.webbing.get("enabled", false)): report.applied.append("webbing")
	if "fibers" in operations:
		var fiber_morphology := morphology.duplicate(true)
		fiber_morphology.merge({"pipeline_stage": stage, "domain_id": "primary_body", "stream_id": "surface.fibers", "application_id": "primary_body.fibers", "fibers_enabled": true, "fiber_mode": str(g.settings.get("blob_fiber_mode", "adherent_fibers")), "surface_regions": regional_plan.records}, true)
		var fiber_report := SurfaceFibers.grow(g, regions, fiber_morphology)
		fiber_report["mode_validation"] = "validated_geometry_limited_clay_acceptance" if str(fiber_morphology.fiber_mode) == "adherent_fibers" and operations.size() == 1 else "unvalidated_mode_or_mixed_combination"
		report["fibers"] = fiber_report
		report.operation_results["fibers"] = fiber_report.duplicate(true)
		if bool(fiber_report.get("enabled", false)): report.applied.append("fibers")
	if "messy_tissue" in operations:
		var messy_morphology := morphology.duplicate(true)
		messy_morphology.merge({"pipeline_stage": stage, "domain_id": "primary_body", "stream_id": "surface.messy_tissue", "application_id": "primary_body.messy_tissue", "messy_tissue_enabled": true, "surface_regions": regional_plan.records}, true)
		var messy_report := MessyTissue.grow(g, regions, messy_morphology)
		messy_report["validation_scope"] = "component_geometry_proven_public_candidate_unvalidated"
		report["messy_tissue"] = messy_report
		report.operation_results["messy_tissue"] = messy_report.duplicate(true)
		_register_reported_region(g, regional_plan.records, messy_report, "messy_tissue")
		if bool(messy_report.get("enabled", false)): report.applied.append("messy_tissue")
	# Attach actual output to the host region that owns it. Reservations are
	# authored-space reports; persisted geometry keeps ordinary graph transforms.
	for node_index in range(start_nodes, g.dna.nodes.size()):
		var node: Dictionary = g.dna.nodes[node_index]
		if node.has("surface_region_id"):
			if str(node.get("surface_operation_selector", "")) == "cavities":
				for record: Dictionary in regional_plan.records:
					if str(record.id) == str(node.surface_region_id) and str(node.id) not in record.feature_nodes:
						SurfaceRegions.reserve(record, "cavities", node)
			continue
		var operation := str(node.get("surface_operation_selector", node.get("surface_operation", "")))
		if operation not in ["cavities", "webbing", "fibers", "messy_tissue"]: continue
		for record: Dictionary in regional_plan.records:
			if str(node.parent) == str(record.host_id):
				node["surface_region_id"] = str(record.id)
				SurfaceRegions.reserve(record, operation, node)
				break
	g.dna.metadata["surface_regions"] = regional_plan
	report["regional_distribution"] = regional_plan.duplicate(true)
	_stamp_stage(g, start_nodes, start_modules, stage)
	return report

func _register_reported_region(g: RefCounted, records: Array, result: Dictionary, operation: String) -> void:
	# A compound membrane can have one node rather than a strand graph. Bind
	# its reported real node IDs to its chosen union region, not a guessed host.
	var node_ids: Array = result.get("node_ids", result.get("patch_nodes", result.get("strand_nodes", result.get("fold_nodes", result.get("reservation", {}).get("node_ids", [])))))
	var region_id := str(result.get("region_id", ""))
	if region_id.is_empty(): return
	for record: Dictionary in records:
		if str(record.id) != region_id: continue
		for id: String in node_ids:
			var node: Dictionary = g.node(id)
			if node.is_empty(): continue
			node["surface_region_id"] = region_id
			if id not in record.feature_nodes: SurfaceRegions.reserve(record, operation, node)
		return

func _stamp_stage(g: RefCounted, start_nodes: int, start_modules: int, stage: int) -> void:
	for i in range(start_nodes, g.dna["nodes"].size()):
		g.dna["nodes"][i]["pipeline_stage"] = stage
	for i in range(start_modules, g.dna["modules"].size()):
		g.dna["modules"][i]["pipeline_stage"] = stage

func _snapshot(g: RefCounted, stage: int, stage_name: String) -> Dictionary:
	# Graph.finish mutates the builder. Snapshot the unscaled graph instead so
	# later stages keep the same anchors, IDs and physical units exactly once.
	var dna := Graph.repair(g.dna)
	Graph.scale_graph(dna, float(g.settings["size"]))
	if not g.dna["metadata"].has("stage_ground_translation"):
		var bottom := INF
		for node: Dictionary in dna["nodes"]:
			if Graph.GrownField.marked(node):
				var field: RefCounted = Graph.GrownField.create(node.shape.grown_envelope,Graph.vec(node.size))
				var placement: Dictionary = field.minimum_surface_y(Graph.node_basis(node))
				placement.minimum_y = float(placement.minimum_y)+Graph.vec(node.position).y
				bottom = minf(bottom,float(placement.minimum_y))
				g.dna.metadata["grown_envelope_placement"] = placement
			elif Graph.GrownContact.marked(node):
				bottom = minf(bottom,float(Graph.GrownContact.minimum(node).minimum_y))
			elif Graph.mantle_marked(node):
				bottom = minf(bottom, Graph.mantle_bounds(node).position.y)
			elif node["kind"] == "curve":
				for i in range(node["points"].size()):
					bottom = minf(bottom, Graph.vec(node["points"][i]).y - float(node["radii"][i]))
			elif node["kind"] == "mass":
				var basis := Graph.node_basis(node); var size := Graph.vec(node["size"])
				var extent_y := sqrt(pow(basis.x.y * size.x, 2.0) + pow(basis.y.y * size.y, 2.0) + pow(basis.z.y * size.z, 2.0))
				bottom = minf(bottom, Graph.vec(node["position"]).y - extent_y)
		if int(dna.get("metadata",{}).get("mantle_anatomy",{}).get("version",0)) in [3,4]:
			var placement: Dictionary=preload("res://alien_foundry/scripts/anatomy/BlobMantlePlacement.gd").graph_minimum(dna)
			bottom=float(placement.minimum_y)
			g.dna["metadata"]["mantle_body_placement"]=placement
		g.dna["metadata"]["stage_ground_translation"] = Graph.arr(Vector3(0.0, -bottom + 0.035, 0.0))
		if g.dna.metadata.has("grown_contact_anatomy"):
			g.dna.metadata["grown_contact_grounding"]={"rigid_translation":g.dna.metadata.stage_ground_translation.duplicate(),"body_only_translation":[0.0,-float(g.dna.metadata.grown_envelope_placement.minimum_y)+0.035,0.0],"individual_surface_minimum_y":bottom,"fused_union_minimum_requires_native_check":true,"body_descriptor_unchanged":true}
	if g.dna["metadata"].has("mantle_body_placement"):dna["metadata"]["mantle_body_placement"]=g.dna["metadata"]["mantle_body_placement"].duplicate(true)
	if g.dna.metadata.has("grown_envelope_placement"): dna.metadata["grown_envelope_placement"] = g.dna.metadata.grown_envelope_placement.duplicate(true)
	if g.dna.metadata.has("grown_contact_grounding"): dna.metadata["grown_contact_grounding"] = g.dna.metadata.grown_contact_grounding.duplicate(true)
	dna["metadata"]["stage_ground_translation"] = g.dna["metadata"]["stage_ground_translation"].duplicate()
	Graph.translate_graph(dna, Graph.vec(dna["metadata"]["stage_ground_translation"]))
	dna["validation"] = Graph.validate(dna)
	dna["metadata"]["node_count"] = dna["nodes"].size()
	dna["metadata"]["module_count"] = dna["modules"].size()
	dna["metadata"]["pipeline"]["stage_index"] = stage
	dna["metadata"]["pipeline"]["stage_name"] = stage_name
	dna["metadata"]["pipeline"]["stage_graph_complete"] = true
	return dna

func _stream_seed(seed_value: int, stream: String) -> int:
	# Stable avalanche before PCG; named streams do not depend on how many
	# random draws another stage or optional component happened to consume.
	return ("0x" + ("blob_anatomy_07|%s|%s" % [stream, seed_value]).sha256_text().substr(0, 15)).hex_to_int()

func _morphology(g: RefCounted) -> Dictionary:
	var grammar_index := posmod(int(g.dna["seed"]), 4)
	var grammar: String = ["rolling_fused_mass", "broad_low_colony", "hanging_unequal_sacs", "hunched_offset_mass"][grammar_index]
	var axial: float = g.rng.randf()
	var spread: float = g.rng.randf()
	var hierarchy: float = g.rng.randf()
	var mirror := -1.0 if g.rng.randf() < 0.5 else 1.0
	var lean: float = g.randf_range(0.16, 0.48) * mirror
	var base_width: float = g.randf_range(0.96, 1.18)
	var crest: float = g.rng.randf()
	var belly: float = g.rng.randf()
	var width := base_width
	var height := base_width
	var depth: float = base_width * g.randf_range(0.72, 1.02)
	match grammar_index:
		0:
			width *= lerpf(0.81, 1.53, axial)
			height *= lerpf(1.02, 0.64, axial)
			depth *= lerpf(0.85, 1.19, spread)
		1:
			width *= lerpf(0.89, 1.48, spread)
			height *= lerpf(0.62, 0.38, spread)
			depth *= lerpf(0.83, 1.30, spread)
		2:
			width *= lerpf(0.78, 1.18, spread)
			height *= lerpf(1.12, 1.82, axial)
		3:
			height *= lerpf(0.83, 1.45, axial)
	return {
		"grammar": grammar, "grammar_index": grammar_index,
		"width": width, "height": height, "depth": depth,
		"axial": axial, "spread": spread, "mass_hierarchy": hierarchy,
		"crest": crest, "belly": belly, "lean": lean, "mirror": mirror,
		"rise": 0.78 if grammar_index == 2 else (0.42 if grammar_index == 3 else 0.08),
		"porosity": g.randf_range(0.12, 0.55), "drape": 0.88 if grammar_index == 2 else 0.20,
		"complexity": clampf(0.28 + float(g.settings["growth_density"]) * 0.46 + g.randf_range(0.0, 0.26), 0.0, 1.0)
	}

func _body_regions(g: RefCounted, m: Dictionary) -> Dictionary:
	match int(m["grammar_index"]):
		0: return _rolling_body(g, m)
		1: return _colony_body(g, m)
		2: return _hanging_body(g, m)
		_: return _hunched_body(g, m)

func _compartment_count(g: RefCounted, minimum: int, maximum: int) -> int:
	var count_rng := RandomNumberGenerator.new()
	count_rng.seed = _stream_seed(int(g.dna["seed"]), "base.compartment_count")
	return count_rng.randi_range(minimum, maximum)

func _rolling_body(g: RefCounted, m: Dictionary) -> Dictionary:
	var w := float(m["width"]); var h := float(m["height"]); var d := float(m["depth"])
	var mirror := float(m["mirror"])
	var yaw: float = g.randf_range(-0.75, 0.75)
	var rotation := Vector3(0.08, yaw, -mirror * g.randf_range(0.08, 0.25))
	var root := _mass(g, "", "core", Vector3(-mirror * w * 0.12, h * 0.55, d * 0.04), Vector3(w * 0.65, h * 0.52, d * 0.64), rotation, "flesh", "core", 0.09)
	var hosts: Array = [root]
	var directions: Array = [Vector3(mirror * 0.9, 0.10, -0.36), Vector3(-mirror * 0.75, 0.18, 0.30), Vector3(0.12, 0.72, 0.62), Vector3(-mirror * 0.30, -0.08, -0.90)]
	var count := _compartment_count(g, 2, 5)
	for i in range(count - 1):
		var direction: Vector3 = (directions[i] + Vector3(g.randf_range(-0.20, 0.20), g.randf_range(-0.12, 0.22), g.randf_range(-0.16, 0.16))).rotated(Vector3.UP, yaw).normalized()
		var dominance: float = lerpf(0.74, 1.31, float(m["mass_hierarchy"])) if i == 0 else g.randf_range(0.63, 1.03)
		var size := Vector3(w * g.randf_range(0.30, 0.43), h * g.randf_range(0.34, 0.58), d * g.randf_range(0.36, 0.59)) * dominance
		_attach_primary(g, root, hosts, direction, size, Vector3(g.randf_range(-0.25, 0.25), yaw + g.randf_range(-0.40, 0.40), g.randf_range(-0.35, 0.35)), 0.38, "rolling_compartment")
	return _semantic_regions(g, root, hosts)

func _colony_body(g: RefCounted, m: Dictionary) -> Dictionary:
	var w := float(m["width"]); var h := float(m["height"]); var d := float(m["depth"])
	var spread := float(m["spread"])
	var center := Vector3(g.randf_range(-0.15, 0.15) * w, h * 0.44, g.randf_range(-0.12, 0.12) * d)
	var root := _mass(g, "", "core", center, Vector3(w * 0.74, h * lerpf(0.46, 0.31, spread), d * 0.68), Vector3(0.04, g.randf_range(-0.45, 0.45), float(m["lean"]) * 0.15), "flesh", "core", 0.075)
	var hosts: Array = [root]
	var count := _compartment_count(g, 4, 9)
	var phase: float = g.randf_range(-PI, PI)
	for i in range(count - 1):
		var angle: float = phase + TAU * float(i) / float(count - 1) + g.randf_range(-0.36, 0.36)
		var upward: float = g.randf_range(0.08, 0.32) + (1.0 - spread) * 0.32
		var direction := Vector3(cos(angle), upward, sin(angle)).normalized()
		var dominance: float = lerpf(0.77, 1.30, float(m["mass_hierarchy"])) if i == 0 else g.randf_range(0.66, 1.05)
		var size := Vector3(w * g.randf_range(0.25, 0.40), h * g.randf_range(0.31, 0.65), d * g.randf_range(0.28, 0.43)) * dominance
		_attach_primary(g, root, hosts, direction, size, Vector3(g.randf_range(-0.18, 0.18), angle + g.randf_range(-0.35, 0.35), g.randf_range(-0.18, 0.18)), lerpf(0.58, 0.28, spread), "colony_compartment")
	return _semantic_regions(g, root, hosts)

func _hanging_body(g: RefCounted, m: Dictionary) -> Dictionary:
	var w := float(m["width"]); var h := float(m["height"]); var d := float(m["depth"])
	var mirror := float(m["mirror"])
	var root := _mass(g, "", "core", Vector3(mirror * w * 0.13, h * 0.99, d * 0.10), Vector3(w * 0.68, h * 0.32, d * 0.64), Vector3(g.randf_range(-0.13, 0.20), g.randf_range(-0.30, 0.30), -float(m["lean"]) * 0.60), "flesh", "core", 0.065)
	var hosts: Array = [root]
	var count := _compartment_count(g, 3, 7)
	var phase: float = g.randf_range(-PI, PI)
	var pendant_rng := RandomNumberGenerator.new()
	pendant_rng.seed = _stream_seed(int(g.dna["seed"]), "base.hanging_pendants.08")
	for i in range(count):
		var angle: float = phase + TAU * float(i) / float(count) + g.randf_range(-0.32, 0.32)
		var direction := Vector3(cos(angle), -g.randf_range(0.65, 1.35), sin(angle)).normalized()
		var hierarchy := float(m["mass_hierarchy"])
		var dominance: float = lerpf(1.02, 1.34, hierarchy) if i == 0 else g.randf_range(0.66, 1.06)
		var size := Vector3(w * g.randf_range(0.21, 0.34), h * g.randf_range(0.27, 0.45), d * g.randf_range(0.24, 0.35)) * dominance
		# One or two sacs descend farther below the carrier; this is a smooth
		# structural hanging volume, not a decorative swelling or surface fold.
		var lower_pendant := i == 0 or (i == 2 and count >= 5)
		if lower_pendant:
			direction.y *= pendant_rng.randf_range(1.20, 1.55)
			direction = direction.normalized()
			size.y *= pendant_rng.randf_range(1.16, 1.30)
		var rotation := Vector3(g.randf_range(-0.20, 0.20), angle * 0.20, g.randf_range(-0.28, 0.28))
		var burial: float = g.randf_range(0.28, 0.43)
		if lower_pendant: burial = pendant_rng.randf_range(0.18, 0.26)
		_attach_primary(g, root, hosts, direction, size, rotation, burial, "pendant_compartment")
	return _semantic_regions(g, root, hosts)

func _hunched_body(g: RefCounted, m: Dictionary) -> Dictionary:
	# Explicit version, no new default setting and no RNG draw on the old path.
	# Saved pre-candidate seeds and the other three grammars remain untouched.
	if GrownEnvelope.selected(g.settings):
		return GrownEnvelope.build(self, g, m)
	if Mantle.selected(g.settings):
		return Mantle.build(self, g, m)
	if int(g.settings.get("blob_loaded_lobe_version", 0)) in LoadedLobes.VERSIONS:
		return LoadedLobes.build(self, g, m)
	var w := float(m["width"]); var h := float(m["height"]); var d := float(m["depth"])
	var mirror := float(m["mirror"])
	var load_offset := mirror * w * lerpf(0.08, 0.40, float(m["spread"]))
	var root := _mass(g, "", "core", Vector3(load_offset, h * 0.76, d * lerpf(-0.10, 0.21, float(m["crest"]))), Vector3(w * 0.58, h * 0.56, d * 0.62), Vector3(g.randf_range(0.05, 0.32), g.randf_range(-0.26, 0.26), -mirror * lerpf(0.14, 0.46, float(m["spread"]))), "flesh", "core", 0.075)
	var hosts: Array = [root]
	# Crest can sit behind, above or laterally over the loaded side. Belly
	# fullness and counterweight are independent, not mirrored paired haunches.
	var crest_direction := Vector3(mirror * lerpf(0.12, 0.66, float(m["crest"])), 0.78, lerpf(-0.36, 0.58, float(m["crest"]))).normalized()
	_attach_primary(g, root, hosts, crest_direction, Vector3(w * g.randf_range(0.34, 0.52), h * g.randf_range(0.27, 0.40), d * g.randf_range(0.34, 0.52)), Vector3(0.10, 0.15, -mirror * 0.23), 0.42, "crest_compartment")
	var belly := float(m["belly"])
	_attach_primary(g, root, hosts, Vector3(-mirror * 0.26, -0.67, -0.70).normalized(), Vector3(w * lerpf(0.24, 0.58, belly), h * lerpf(0.25, 0.48, belly), d * lerpf(0.27, 0.51, belly)), Vector3(0.22, -mirror * 0.19, mirror * 0.15), 0.44, "belly_compartment")
	_attach_primary(g, root, hosts, Vector3(-mirror * 0.94, -0.15, g.randf_range(-0.32, 0.42)).normalized(), Vector3(w * g.randf_range(0.28, 0.44), h * g.randf_range(0.28, 0.47), d * g.randf_range(0.32, 0.47)), Vector3(-0.10, 0.12, mirror * 0.19), 0.48, "counterweight_compartment")
	if _compartment_count(g, 0, 1) == 1:
		_attach_primary(g, root, hosts, Vector3(mirror * 0.65, -0.42, 0.68).normalized(), Vector3(w * 0.32, h * 0.33, d * 0.35), Vector3(0.21, -0.25, -mirror * 0.18), 0.43, "rear_compartment")
	return _semantic_regions(g, root, hosts)

func _attach_primary(g: RefCounted, parent: String, hosts: Array, outward: Vector3, desired_size: Vector3, rotation: Vector3, burial: float, region: String) -> void:
	var host: Dictionary = g.node(parent)
	var basis := Basis.from_euler(rotation)
	var best: Dictionary = {}; var best_score := -INF
	# Stable bounded alternatives keep a real overlapping attachment and a
	# visible compartment. Primary lobes may not swallow earlier outer lobes.
	for attempt in range(9):
		var direction := outward.rotated(Vector3.UP, [0.0, -0.28, 0.28, -0.52, 0.52, -0.12, 0.12, -0.38, 0.38][attempt]).normalized()
		var size := desired_size * (1.0 if attempt < 5 else 0.84)
		var radius := Graph.surface_radius(size, basis.inverse() * direction)
		var point := _surface_point(host, direction) - direction * radius * burial
		var proposed := {"position": Graph.arr(point), "size": Graph.arr(size), "rotation": Graph.arr(rotation), "kind": "mass"}
		var exposure := _surface_exposure(proposed, g.dna["nodes"])
		if float(exposure["fraction"]) < 0.30: continue
		var swallowed := false
		for id in hosts:
			if str(id) == parent: continue
			if _covered_fraction(g.node(str(id)), proposed) > 0.40:
				swallowed = true; break
			var remaining_union: Array = [proposed]
			for other: Dictionary in g.dna["nodes"]:
				if str(other["id"]) != str(id): remaining_union.append(other)
			if float(_surface_exposure(g.node(str(id)), remaining_union)["fraction"]) < 0.26:
				swallowed = true; break
		if swallowed: continue
		var score := float(exposure["fraction"]) - absf(float(attempt)) * 0.015
		if score > best_score:
			best = {"position": point, "size": size, "exposure": exposure["fraction"], "burial": burial}; best_score = score
	if best.is_empty(): return
	var id := _mass(g, parent, "lobe", best["position"], best["size"], rotation, "flesh", region, 0.070)
	g.node(id)["primary_placement"] = {"exposed_fraction": best["exposure"], "overlap_fraction": burial, "bounded_candidates": 9}
	hosts.append(id)

func _semantic_regions(g: RefCounted, root: String, hosts: Array) -> Dictionary:
	var result := {"root": root, "left": root, "right": root, "mantle": root, "pouch": root, "hosts": hosts}
	var low_x := INF; var high_x := -INF; var high_y := -INF; var low_z := INF
	for id in hosts:
		var p: Vector3 = g.center(str(id))
		if p.x < low_x: result["left"] = id; low_x = p.x
		if p.x > high_x: result["right"] = id; high_x = p.x
		if p.y > high_y: result["mantle"] = id; high_y = p.y
		if p.z < low_z: result["pouch"] = id; low_z = p.z
	for label in ["left", "right", "mantle", "pouch"]:
		var node: Dictionary = g.node(str(result[label]))
		if not node.has("semantic_roles"): node["semantic_roles"] = []
		node["semantic_roles"].append(label)
	return result

func _mass(g: RefCounted, parent: String, role: String, position: Vector3, size: Vector3, rotation: Vector3, material: String, region: String, blend: float) -> String:
	var id: String = g.mass(parent, role, position, size, material, region != "subsidiary")
	var n: Dictionary = g.node(id)
	n["rotation"] = Graph.arr(rotation)
	n["blend"] = blend * float(size.length())
	n["noise"] = g.randf_range(0.009, 0.018) if region == "subsidiary" else 0.0
	n["shape"] = {"sculpt_strength": g.randf_range(0.24, 0.48) if region != "subsidiary" else 0.18}
	n["blob_region"] = region
	n["surface"] = {"exposure": 0.10 if region == "mantle" else (0.06 if region == "pouch" else 0.02), "growth": 0.48 if region == "subsidiary" else (0.25 if region == "mantle" else 0.10)}
	return id

func _basal_supports(g: RefCounted, regions: Dictionary, m: Dictionary) -> Array:
	if g.dna.metadata.has("grown_envelope_anatomy"): return GrownContacts.supports(g,regions,m)
	if g.dna.metadata.has("mantle_anatomy"):
		return Mantle.supports(g, regions, m)
	var result: Array = []
	var w := float(m["width"]); var h := float(m["height"]); var d := float(m["depth"])
	var grammar := int(m["grammar_index"])
	var ranges: Array = [[0, 2], [6, 10], [4, 10], [2, 3]][grammar]
	var count: int = g.rng.randi_range(int(ranges[0]), int(ranges[1]))
	# Keep every .45-default seed unchanged while making the existing density
	# control meaningful. Each grammar retains its structural contact minimum.
	var density := float(g.settings["appendage_density"])
	if density < 0.45:
		count = int(round(lerpf(float(count), float(ranges[0]), (0.45 - density) / 0.45)))
	elif density > 0.45:
		count = int(round(lerpf(float(count), float(ranges[1]), (density - 0.45) / 0.55)))
	var phase: float = g.randf_range(-0.45, 0.45)
	if grammar == 2:
		return _hanging_roots(g, regions, m, count, phase)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count) + phase + g.randf_range(-0.22, 0.22)
		# The hunch is carried by unequal diagonals, never a four-foot stool.
		if grammar == 3:
			angle = [-2.50, -0.31, 1.75][i] + phase * 0.30
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var host := _peripheral_host(g, regions["hosts"], direction, grammar)
		var host_node: Dictionary = g.node(host)
		var downward := (direction * (0.33 if grammar == 2 else 0.70) + Vector3.DOWN).normalized()
		var anchor := _surface_point(host_node, downward, 0.74)
		if grammar == 2:
			anchor.y = maxf(anchor.y, h * 0.28)
			anchor = _inside_mass(host_node, anchor, 0.90)
		var radius: float
		var base: Vector3
		var elbow: Vector3
		var end: Vector3
		if grammar == 0:
			radius = w * g.randf_range(0.115, 0.17)
			base = anchor + direction * w * 0.25
			base.y = radius * 0.50
			elbow = anchor.lerp(base, 0.52)
			end = base + direction * w * 0.06
		elif grammar == 1:
			radius = w * g.randf_range(0.10, 0.155)
			base = _surface_point(host_node, direction, 0.86) + direction * w * g.randf_range(0.10, 0.23)
			base.y = radius * 0.50
			elbow = anchor.lerp(base, 0.58)
			end = base + direction * w * 0.08
		elif grammar == 2:
			radius = w * g.randf_range(0.065, 0.095)
			base = Vector3(anchor.x, 0.06, anchor.z) + direction * w * g.randf_range(0.20, 0.43)
			elbow = anchor.lerp(base, g.randf_range(0.44, 0.65)) + Vector3(direction.x * w * 0.06, 0.0, -direction.z * d * 0.05)
			end = base + direction * w * g.randf_range(0.09, 0.18)
		else:
			radius = w * g.randf_range(0.20, 0.29) * (1.14 if i == 0 else 1.0)
			base = Vector3(direction.x * w * g.randf_range(0.89, 1.11), radius * 0.40, direction.z * d * 0.87)
			elbow = anchor.lerp(base, 0.54) + direction * w * 0.12
			end = base + direction * w * g.randf_range(0.10, 0.18)
		end.y = maxf(0.035, radius * 0.25)
		var end_scale := 0.36 if grammar == 2 else 0.49
		var id: String = g.curve(host, "limb", [anchor, elbow, base, end], [radius, radius * (0.74 if grammar == 2 else 0.94), radius * 0.62, radius * end_scale], "flesh", true)
		var n: Dictionary = g.node(id)
		n["blend"] = radius * (0.52 if grammar == 2 else 0.70)
		n["noise"] = 0.0
		n["shape"] = {"swelling": 0.025, "twist": 0.0, "width": 1.0 if grammar == 2 else g.randf_range(1.0, 1.19), "depth": 0.95 if grammar == 2 else 0.82, "width_profile": [1.0, 0.94, 0.86, 0.76], "depth_profile": [1.0, 0.92, 0.83, 0.74]}
		n["blob_region"] = ["minimal_contact", "colony_nub", "fleshy_root", "load_buttress"][grammar]
		n["surface"] = {"exposure": 0.18, "growth": 0.08}
		result.append(id)
	return result

func _hanging_roots(g: RefCounted, regions: Dictionary, m: Dictionary, count: int, phase: float) -> Array:
	# Each candidate is checked against all prior roots using production
	# curve samples. Shared buried origins are allowed; free-root bridges are not.
	var roots: Array = []; var accepted_nodes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _stream_seed(int(g.dna["seed"]), "base.hanging_roots.08")
	var w := float(m["width"]); var h := float(m["height"])
	var body := RootRouting.body_field(g.dna)
	var carrier: Vector3 = g.center(str(regions["root"]))
	var rejected := 0; var unplaced := 0
	for i in range(count):
		var nominal: float = TAU * float(i) / float(count) + phase + rng.randf_range(-0.16, 0.16)
		var thickness_class := i % 3
		var authored_radius: float = w * rng.randf_range(0.125, 0.170) if thickness_class == 0 else w * rng.randf_range(0.080, 0.120)
		if thickness_class == 2: authored_radius = w * rng.randf_range(0.055, 0.080)
		var curl_sign := -1.0 if rng.randf() < 0.5 else 1.0
		var bow: float = w * rng.randf_range(0.16, 0.30)
		var foot_spread: float = rng.randf_range(1.03, 1.35)
		var upper_fraction: float = rng.randf_range(0.25,0.36)
		var lower_fraction: float = rng.randf_range(0.62,0.74)
		var upper_radius: float = rng.randf_range(0.87,1.13)
		var lower_radius: float = rng.randf_range(0.53,0.79)
		var tip_fraction: float = rng.randf_range(0.25,0.40)
		var selected: Dictionary = {}; var audit: Dictionary = {}
		for attempt in range(32):
			var offset: float = [0.0,-0.16,0.16,-0.31,0.31,-0.44,0.44,-0.08][attempt % 8] * TAU/float(count)
			var angle := nominal+offset
			var direction := Vector3(cos(angle),0.0,sin(angle)); var across := Vector3(-direction.z,0.0,direction.x)
			var host := _peripheral_host(g,regions["hosts"],direction,2)
			if attempt >= 24: host = str(regions["root"])
			var host_node: Dictionary = g.node(host)
			var origin_direction := (direction * (1.10+float(attempt/8)*0.45)+Vector3.DOWN).normalized()
			var anchor := _surface_point(host_node,origin_direction,0.83)
			anchor.y=maxf(anchor.y,h*0.23);anchor=_inside_mass(host_node,anchor,0.88)
			var radius := minf(authored_radius*(1.0 if attempt<16 else 0.82),maxf(anchor.y,w*0.25)/4.5)
			# Feet follow a common ordered radial envelope instead of each host's
			# offset axis, preventing different sacs from routing through one another.
			var foot := Vector3(carrier.x,0.055,carrier.z)+direction*w*(foot_spread+float(attempt/8)*0.13)
			var lateral := across*bow*curl_sign*(0.52 if attempt<8 else -0.36)
			var bend_top := anchor.lerp(foot,upper_fraction)+direction*bow*0.58+lateral
			var bend_low := anchor.lerp(foot,lower_fraction)+direction*bow*0.72-lateral*0.35
			var tip_radius := maxf(w*0.026,radius*tip_fraction)
			var tip := foot+direction*w*0.11+across*w*curl_sign*0.035
			tip.y=tip_radius+0.035;foot.y=tip_radius*1.25+0.035
			var radii: Array=[radius,radius*upper_radius,radius*lower_radius,tip_radius*1.25,tip_radius]
			var points: Array=[anchor,bend_top,bend_low,foot,tip]
			var candidate := {"kind":"curve","parent":host,"points":points,"radii":radii,"radius":radius,"blend":radius*0.55,"shape":{"swelling":0.0,"twist":0.0,"width":1.0,"depth":0.95,"width_profile":[1.0,1.0],"depth_profile":[1.0,1.0]}}
			var clearance := RootRouting.check(candidate,accepted_nodes,body,w*0.025)
			selected=candidate; audit=clearance; audit["candidate_index"]=attempt
			if bool(clearance["accepted"]): break
			rejected+=1
		if not bool(audit.get("accepted",false)):
			unplaced+=1
			continue # never trade a distinct root for an unreported fused branch
		var id: String=g.curve(str(selected["parent"]),"limb",selected["points"],selected["radii"],"flesh",true)
		var node: Dictionary=g.node(id)
		node["blend"]=selected["blend"];node["noise"]=0.0;node["shape"]=selected["shape"]
		node["blob_region"]="fleshy_root";node["surface"]={"exposure":0.18,"growth":0.08}
		node["root_anatomy"]={"revision":9,"thickness_class":thickness_class,"curvature_radius":bow,"decorative_noise":false,"clearance":audit}
		roots.append(id);accepted_nodes.append(node)
	g.dna["metadata"]["root_routing"]={"candidate_limit":32,"rejected_candidates":rejected,"unplaced_requested_roots":unplaced,"clearance_fraction_width":0.025,"shared_buried_origins_only":true}
	return roots

func _peripheral_host(g: RefCounted, hosts: Array, direction: Vector3, grammar: int) -> String:
	var best := str(hosts[0]); var best_score := -INF
	for host in hosts:
		var n: Dictionary = g.node(str(host))
		if str(n.get("blob_region", "")) == "mantle": continue
		var p := _surface_point(n, direction, 0.80)
		var score := p.dot(direction) - p.y * (0.20 if grammar == 2 else 0.05)
		if score > best_score:
			best = str(host); best_score = score
	return best

func _surface_point(node: Dictionary, outward: Vector3, fraction: float = 1.0) -> Vector3:
	if Graph.BodyGroupField.marked(node) or Graph.EnvelopeField.marked(node): return Graph.envelope_ray_surface(node,outward,fraction)
	if Graph.MantleField.marked(node): return Graph.mantle_ray_surface(node,outward,fraction)
	var local := Graph.node_basis(node).inverse() * outward.normalized()
	return Graph.vec(node["position"]) + outward.normalized() * Graph.surface_radius(Graph.vec(node["size"]), local) * fraction

func _subsidiary_sacs(g: RefCounted, regions: Dictionary, m: Dictionary) -> void:
	# These are surface nodules, not the completed smooth primary compartments.
	# Reject buried candidates against the entire current union, not only the
	# parent. The winning direction is local to the rotated host ellipsoid.
	var count := 3 + int(round(float(g.settings["growth_density"]) * 5.0))
	var choices: Array = regions["hosts"].duplicate()
	choices.erase(regions["root"])
	var siblings: Array = []
	var rejected := 0
	var baseline_bottom := INF
	for n: Dictionary in g.dna["nodes"]:
		if n["kind"] == "mass": baseline_bottom = minf(baseline_bottom, Graph.vec(n["position"]).y - Graph.vec(n["size"]).y)
	var cell_estimate := maxf(float(m["width"]), float(m["height"])) * 2.8 / float([48, 94, 132][int(g.settings["quality"])])
	for i in range(count):
		var parent := str(choices[i % choices.size()])
		var host: Dictionary = g.node(parent)
		var radial: Vector3 = g.center(parent) - g.center(str(regions["root"]))
		radial.y = maxf(radial.y, float(m["height"]) * 0.14)
		if "mantle" in host.get("semantic_roles", []): radial += Vector3(0.0, float(m["height"]) * 0.6, float(m["depth"]) * 0.5)
		var radius: float = float(m["width"]) * g.randf_range(0.18, 0.31)
		var size := Vector3(radius * g.randf_range(0.76, 1.0), radius * g.randf_range(1.13, 1.57), radius * g.randf_range(0.82, 1.13))
		var rotation := Vector3(g.randf_range(-0.3, 0.3), g.randf_range(-0.25, 0.25), g.randf_range(-0.45, 0.45))
		var basis := Basis.from_euler(rotation)
		var best: Dictionary = {}; var best_score := -INF
		for candidate_index in range(8):
			var angle: float = float(candidate_index) * TAU / 8.0 + g.randf_range(-0.12, 0.12)
			var outward := (radial.normalized() * 0.72 + Vector3(cos(angle), g.randf_range(0.10, 0.84), sin(angle)) * 0.78).normalized()
			var radial_radius := Graph.surface_radius(size, basis.inverse() * outward)
			var p: Vector3 = _surface_point(host, outward) - outward * radial_radius * g.randf_range(0.20, 0.35)
			if p.y - size.y < baseline_bottom + cell_estimate: continue
			var proposed := {"position": Graph.arr(p), "size": Graph.arr(size), "rotation": Graph.arr(rotation), "kind": "mass"}
			var exposure := _surface_exposure(proposed, g.dna["nodes"])
			if float(exposure["fraction"]) < 0.34 or float(exposure["protrusion"]) < cell_estimate * 2.0: continue
			var swallows := false
			for sibling in siblings:
				if _covered_fraction(g.node(str(sibling)), proposed) > 0.34:
					swallows = true; break
			if swallows: continue
			var score := float(exposure["fraction"]) + float(exposure["protrusion"]) / maxf(radius, 0.01) * 0.2
			if score > best_score:
				best = {"position": p, "fraction": exposure["fraction"], "protrusion": exposure["protrusion"], "candidate": candidate_index}
				best_score = score
		if best.is_empty():
			rejected += 1; continue
		var id := _mass(g, parent, "lobe", best["position"], size, rotation, "flesh", "subsidiary", 0.075)
		g.node(id)["placement_audit"] = {"exposed_fraction": best["fraction"], "max_protrusion": best["protrusion"], "minimum_protrusion": cell_estimate * 2.0, "candidate_index": best["candidate"], "tested_directions": 8, "rotation_aware": true}
		regions["hosts"].append(id); siblings.append(id)
	g.dna["metadata"]["nodule_placement"] = {"requested": count, "placed": siblings.size(), "rejected_buried_or_occluding": rejected, "minimum_exposed_fraction": 0.34, "minimum_protrusion_cells": 2}

func _surface_sample(node: Dictionary, index: int, count: int = 48) -> Vector3:
	if Graph.BodyGroupField.marked(node):
		var y := 1.0 - (float(index)+0.5)*2.0/float(count)
		var radius := sqrt(maxf(0.0,1.0-y*y)); var angle := float(index)*2.39996323
		var direction := Graph.node_basis(node)*Vector3(cos(angle)*radius,y,sin(angle)*radius)
		return Graph.envelope_ray_surface(node,direction,1.0)
	if Graph.EnvelopeField.marked(node):
		var field: RefCounted = Graph.EnvelopeField.create(node)
		if not field.valid: return Vector3(NAN,NAN,NAN)
		var fraction := (float(index)+0.5)/float(count)
		var z := lerpf(-float(field.caps[0][0]),0.5,fraction) if str(node.id)==field.owner_id else lerpf(0.5,1.0+float(field.caps[1][0]),fraction)
		return field.surface(z,float(index)*2.39996323)
	if Graph.MantleField.marked(node): return Graph.mantle_surface(node, 1.0-(float(index)+0.5)/float(count), float(index)*2.39996323)
	var y := 1.0 - (float(index) + 0.5) * 2.0 / float(count)
	var r := sqrt(maxf(0.0, 1.0 - y * y)); var angle := float(index) * 2.39996323
	return Graph.vec(node["position"]) + Graph.node_basis(node) * (Vector3(cos(angle) * r, y, sin(angle) * r) * Graph.vec(node["size"]))

func _surface_exposure(node: Dictionary, existing: Array) -> Dictionary:
	var exposed := 0; var protrusion := 0.0
	for index in range(48):
		var point := _surface_sample(node, index)
		var distance := INF
		for other: Dictionary in existing:
			if other["kind"] == "cavity": continue
			distance = minf(distance, Graph.distance_to_tissue(other, point) - float(other.get("blend", 0.0)) * 0.25)
		if distance > 0.0: exposed += 1
		protrusion = maxf(protrusion, distance)
	return {"fraction": float(exposed) / 48.0, "protrusion": protrusion}

func _covered_fraction(node: Dictionary, occluder: Dictionary) -> float:
	var covered := 0
	for index in range(48):
		if Graph.distance_to_tissue(occluder, _surface_sample(node, index)) < 0.0: covered += 1
	return float(covered) / 48.0

func _embedded_faces(g: RefCounted, regions: Dictionary, m: Dictionary) -> int:
	var uncanny := float(g.settings["uncanny_features"])
	# A face is a rare anatomical event, not the identifying feature of every
	# seed. Pores and tissue remain legible when uncanny features are disabled.
	var count := 0
	if g.randf_range(0.0, 1.0) < uncanny * 0.72:
		_face_in_tissue(g, str(regions["pouch"]), Vector3(float(m["mirror"]) * -0.12, 0.02, -1.0).normalized())
		count += 1
	if uncanny > 0.72 and g.randf_range(0.0, 1.0) < (uncanny - 0.60) * 0.85:
		var host := str(regions["left"] if float(m["mirror"]) < 0.0 else regions["right"])
		_face_in_tissue(g, host, Vector3(float(m["mirror"]) * 0.25, 0.05, -1.0).normalized())
		count += 1
	return count

func _regional_clefts(g: RefCounted, regions: Dictionary, m: Dictionary) -> void:
	# A seam is a local, oblique compression valley between tissue compartments,
	# not blanket noise and not another round surface pore.
	var w := float(m["width"])
	var h := float(m["height"])
	var d := float(m["depth"])
	var c: Vector3 = g.center(str(regions["root"]))
	var position := c + Vector3(w * 0.08, h * 0.18, -d * 0.57)
	var id: String = g.cavity(str(regions["root"]), position, Vector3(w * 0.09, h * 0.36, d * 0.24))
	var n: Dictionary = g.node(id)
	n["rotation"] = Graph.arr(Vector3(0.10, 0.0, -0.25))
	n["blend"] = w * 0.035
	n["blob_region"] = "compressed_seam"
	n["surface_opening"] = false

func _face_in_tissue(g: RefCounted, parent: String, outward: Vector3) -> void:
	var old_nodes: int = g.dna["nodes"].size()
	var old_modules: int = g.dna["modules"].size()
	g.face(parent, false, outward, true)
	if g.dna["modules"].size() <= old_modules:
		return
	var module: Dictionary = g.dna["modules"][-1]
	var scale := Graph.vec(module["scale"]) * 0.62
	var host_size := Graph.vec(g.node(parent)["size"])
	var anchor: Vector3 = g.center(parent) + outward * Graph.surface_radius(host_size, outward) * 0.93
	module["scale"] = Graph.arr(scale)
	module["position"] = Graph.arr(anchor)
	module["shell_surface_offset"] = 0.0
	# Graph.face's legacy mouth pocket must shrink/reseat with the skull too.
	for i in range(old_nodes, g.dna["nodes"].size()):
		var n: Dictionary = g.dna["nodes"][i]
		if n["kind"] == "cavity":
			n["position"] = Graph.arr(anchor - Vector3.UP * scale.y * 0.22 - outward * scale.x * 0.035)
			n["size"] = Graph.arr(Vector3(scale.x * 0.20, scale.y * 0.09, scale.z * 0.22))
			n["radius"] = scale.x * 0.20
	# One descending temple fold and a shorter opposite cheek attachment bury
	# the skull sides without making an oval frame around the whole face.
	var across := Vector3.UP.cross(outward).normalized()
	for i in range(2):
		var sign_value := -1.0 if i == 0 else 1.0
		var top := anchor + across * scale.x * sign_value * 0.38 + Vector3.UP * scale.y * (0.61 if i == 0 else 0.28) - outward * scale.z * 0.10
		var middle := anchor + across * scale.x * sign_value * 0.49 - Vector3.UP * scale.y * 0.02
		var end := anchor + across * scale.x * sign_value * 0.30 - Vector3.UP * scale.y * 0.62 - outward * scale.z * 0.16
		# The folds begin and end inside the rotated carrier, including extreme
		# face proportions. Never rely on automatic graph repair for attachment.
		top = _inside_mass(g.node(parent), top, 0.82)
		end = _inside_mass(g.node(parent), end, 0.86)
		var radius := scale.x * (0.095 if i == 0 else 0.075)
		var id: String = g.curve(parent, "cranial_fold", [top, middle, end], [radius * 0.9, radius, radius * 0.68], "flesh", false)
		g.node(id)["blend"] = radius * 0.65
		g.node(id)["noise"] = 0.008
		g.node(id)["blob_region"] = "cranial_attachment"
		g.node(id)["surface"] = {"exposure": 0.18, "growth": 0.12}

func _inside_mass(node: Dictionary, point: Vector3, fraction: float) -> Vector3:
	var center := Graph.vec(node["position"])
	var basis := Graph.node_basis(node)
	var size := Graph.vec(node["size"])
	var local := basis.inverse() * (point - center)
	var ratio := (local / size).length()
	return center + basis * local * minf(1.0, fraction / maxf(ratio, 0.0001))
