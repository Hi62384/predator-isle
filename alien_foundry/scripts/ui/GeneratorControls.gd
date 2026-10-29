class_name GeneratorControls
extends VBoxContainer
## The simple controls are intentionally small; combinations appear only when needed.

signal generation_requested(request: Dictionary)
signal source_generation_requested(index: int)
signal capture_source_requested(index: int)
signal source_view_requested(index: int)
signal cancel_requested
signal save_requested
signal load_requested
signal material_refresh_requested(settings: Dictionary)

const TYPES := ["Blob", "Crawler", "Humanoid", "Abomination", "Beast", "Slitherer", "Combination"]
const METHODS := ["Attachment", "Fusion", "Replacement", "Integration"]
const MaterialConfig = preload("res://alien_foundry/scripts/rendering/MaterialGenerator.gd")
const CAVITY_MATERIAL_SETTING := "blob_cavity_material_assignment"
const CAVITY_MATERIAL_PROFILE := "authored_cavity_v1"
const TISSUE_PROFILE_KEY := "blob_material_profile"
const TISSUE_BASELINE := "reference_tissue_v1"
const TISSUE_EXPERIMENT := "reference_tissue_v2_response"
# A recipe allowlist, never a copy of realized DNA or arbitrary metadata.
const LOADED_BLOB_SETTINGS := ["blob_pipeline_mode", "blob_identity_profile", "blob_body_profile", "blob_secondary_detail_mode", "blob_ground_placement", "blob_sac_group_mode", "blob_direct_surface_profile", "size", "irregularity", "growth_density", "appendage_density", "surface_detail", "uncanny_features", "quality", "surface_operations", "surface_library_version", "secondary_enabled", "material_wetness", "blob_cavity_material_assignment", "blob_fiber_mode", "fusion_intensity", "blob_hanging_load_version", "blob_hanging_surface_integration_version", "blob_fiber_material_assignment", "first_type", "second_type", "first_seed", "second_seed", "method"]
const ITERATIVE_CHOICES := [
	{"key": "blob_identity_profile", "name": "BlobIdentityProfile", "label": "Feature mixture", "values": ["foundation_171", "seeded_v1"], "labels": ["Foundation · fixed mixture", "Seeded · supported feature mixtures"]},
	{"key": "blob_body_profile", "name": "BlobBodyProfile", "label": "Body grammar", "values": ["foundation_171", "compact_body_v1"], "labels": ["Foundation · unchanged body", "Compact · eligible body grammar only"]},
	{"key": "blob_secondary_detail_mode", "name": "BlobSecondaryDetail", "label": "Secondary tendril detail", "values": ["off", "tendon_ridges_v1"], "labels": ["Off · unchanged tendrils", "Rooted tendon ridges · subtle"]},
	{"key": "blob_ground_placement", "name": "BlobGroundPlacement", "label": "Common ground frame", "values": ["off", "complete_mesh_min_y_v1"], "labels": ["Off · unchanged local frame", "Lowest completed vertex · ground zero"]},
	{"key": "blob_sac_group_mode", "name": "BlobSacGroup", "label": "Shared sac growth and folds", "values": ["off", "sac_group_growth_final_v1"], "labels": ["Off · unchanged sac anatomy", "Mapped sac/neck/cavity · Standard test profile"]},
	{"key": "blob_direct_surface_profile", "name": "BlobDirectSurface", "label": "Surface vascular network", "values": ["off", "vascular_183b_v1", "vascular_blueprint_v1"], "labels": ["Off · no direct vascular layer", "Vascular183b · seed22 / Low / growth off only", "Blueprint vascular · Low / growth off / may skip"]}
]
const PARAMS := [
	["size", "Size", 0.35, 2.5, 1.0, "Overall scale, preserving all anatomical proportions."],
	["irregularity", "Anatomical irregularity", 0.0, 1.0, 0.45, "Asymmetry, unusual proportions, and misplaced structures."],
	["growth_density", "Organic growth density", 0.0, 1.0, 0.4, "Secondary masses, lobes, and grown tissue."],
	["appendage_density", "Appendage density", 0.0, 1.0, 0.45, "Optional limbs, tendrils, digits, and branching extensions."],
	["surface_detail", "Surface detail", 0.0, 1.0, 0.55, "Organic displacement and fine surface irregularity."],
	["uncanny_features", "Uncanny features", 0.0, 1.0, 0.45, "Presence and deformation of complex faces and sensory structures."]
]

var type_select: OptionButton
var seed_input: SpinBox
var quality_select: OptionButton
var blob_pipeline_panel: VBoxContainer
var pipeline_mode_toggle: CheckButton
var pipeline_mode_notice: Label
var iterative_choices_panel: VBoxContainer
var iterative_choices: Dictionary = {}
var surface_operations_heading: Label
var legacy_surface_status: Label
var material_stage_heading: Label
var material_wetness_heading: Label
var surface_checks: Dictionary = {}
var _fiber_mode := "adherent_fibers"
var _fiber_mode_explicit := false
var secondary_toggle: CheckButton
var material_wetness: HSlider
var material_refresh_button: Button
var cavity_material_toggle: CheckButton
var tissue_response_select: OptionButton
var material_status_label: Label
var _cavity_material_assignment := ""
var _tissue_profile := ""
var _material_wetness_value := 0.92
var _material_wetness_explicit := true
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var parameter_labels: Dictionary = {}
var combination_panel: VBoxContainer
var source_types: Array[OptionButton] = []
var source_seeds: Array[SpinBox] = []
var source_labels: Array[Label] = []
var source_dna: Array[Dictionary] = [{}, {}]
var method_select: OptionButton
var fusion_slider: HSlider
var _loaded_blob_active := false
var _loaded_blob_settings: Dictionary = {}
var _loaded_blob_unsupported: Array[String] = []
var _applying_dna := false
var _busy := false
var loaded_recipe_notice: Label
var regenerate_button: Button
var generate_button: Button
var cancel_button: Button
var save_button: Button
var load_button: Button
var progress_bar: ProgressBar
var progress_label: Label
var action_panel: VBoxContainer
var _suppress_source_reset := false
var _build_buttons: Array[Button] = []

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_heading("GROW AN ORGANISM", 12, Color("8da7a3"))
	_label("Creature type")
	type_select = _option(TYPES)
	type_select.name = "CreatureType"
	type_select.select(0)
	add_child(type_select)
	type_select.item_selected.connect(func(index: int):
		combination_panel.visible = index == 6
		blob_pipeline_panel.visible = index == 0
		if index != 0: _clear_loaded_blob_recipe()
		_update_pipeline_mode_controls())
	_label("Seed")
	var seed_row := HBoxContainer.new()
	add_child(seed_row)
	seed_input = _seed(271828)
	seed_input.name = "Seed"
	seed_row.add_child(seed_input)
	var random_button := _button("↻", "Randomize seed without changing your settings.")
	random_button.custom_minimum_size.x = 44
	random_button.pressed.connect(randomize_seed)
	seed_row.add_child(random_button)
	for spec in PARAMS:
		_add_parameter(spec)
	_label("Geometry quality")
	quality_select = _option(["Low · fast preview", "Medium · balanced", "High · final detail"])
	quality_select.name = "GeometryQuality"
	quality_select.select(1)
	quality_select.item_selected.connect(func(index: int): _edit_loaded_blob_setting("quality", index))
	quality_select.tooltip_text = "Low, medium, and high use bounded field resolutions. Fine shading remains visible in every quality."
	add_child(quality_select)
	_build_blob_pipeline_controls()
	_build_combinations()
	action_panel = VBoxContainer.new()
	action_panel.name = "GenerationActions"
	action_panel.add_theme_constant_override("separation", 7)
	add_child(action_panel)
	var divider := HSeparator.new()
	action_panel.add_child(divider)
	generate_button = _button("Generate Alien", "Generate the chosen anatomy, fused organic mesh, and procedural rig.")
	generate_button.name = "GenerateAlien"
	generate_button.custom_minimum_size.y = 46
	generate_button.add_theme_font_size_override("font_size", 17)
	generate_button.pressed.connect(_request_generation)
	action_panel.add_child(generate_button)
	var action_row := HBoxContainer.new()
	action_panel.add_child(action_row)
	var regenerate := _button("Regenerate", "Reconstruct this exact seed and current settings.")
	regenerate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regenerate_button = regenerate
	regenerate.pressed.connect(_request_generation)
	action_row.add_child(regenerate)
	_build_buttons.append(regenerate)
	cancel_button = _button("Cancel", "Cancel safely while keeping the displayed creature.")
	cancel_button.disabled = true
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(func(): cancel_requested.emit())
	action_row.add_child(cancel_button)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 6
	progress_bar.show_percentage = false
	progress_bar.max_value = 1.0
	progress_bar.visible = false
	action_panel.add_child(progress_bar)
	progress_label = _label("Ready to grow.", action_panel)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_color_override("font_color", Color("9fb5b2"))
	var file_row := HBoxContainer.new()
	action_panel.add_child(file_row)
	save_button = _button("Save DNA…", "Save the complete versioned anatomy, materials, and combination ancestry.")
	save_button.disabled = true
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(func(): save_requested.emit())
	file_row.add_child(save_button)
	load_button = _button("Load DNA…", "Reconstruct a saved anatomy graph, not just its original seed.")
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(func(): load_requested.emit())
	file_row.add_child(load_button)
	var hint := _label("Same seed + same settings = same anatomy.\nSave DNA to preserve the complete organism.", action_panel)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("7d9290"))

func _build_blob_pipeline_controls() -> void:
	blob_pipeline_panel = VBoxContainer.new()
	blob_pipeline_panel.name = "BlobStageControls"
	loaded_recipe_notice = _label("", blob_pipeline_panel)
	loaded_recipe_notice.name = "LoadedBlobRecipe"
	loaded_recipe_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loaded_recipe_notice.add_theme_font_size_override("font_size", 11)
	loaded_recipe_notice.visible = false
	add_child(blob_pipeline_panel)
	pipeline_mode_toggle = CheckButton.new()
	pipeline_mode_toggle.name = "IterativeBlobPipeline"
	pipeline_mode_toggle.text = "Iterative Blob pipeline · experimental"
	pipeline_mode_toggle.tooltip_text = "Explicit opt-in. Builds four actual clay iterations, typed detail, complete geometry, materials and a biological feature map. Existing saves stay on their saved pipeline."
	pipeline_mode_toggle.toggled.connect(func(enabled: bool):
		_edit_loaded_blob_setting("blob_pipeline_mode", "iterative_v2", not enabled)
		_update_pipeline_mode_controls())
	blob_pipeline_panel.add_child(pipeline_mode_toggle)
	pipeline_mode_notice = _label("", blob_pipeline_panel)
	pipeline_mode_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pipeline_mode_notice.add_theme_font_size_override("font_size", 11)
	pipeline_mode_notice.visible = false
	iterative_choices_panel = VBoxContainer.new()
	iterative_choices_panel.name = "IterativeBlobChoices"
	iterative_choices_panel.visible = false
	blob_pipeline_panel.add_child(iterative_choices_panel)
	for spec: Dictionary in ITERATIVE_CHOICES:
		_label(str(spec.label), iterative_choices_panel)
		var choice: OptionButton = _option(spec.labels)
		choice.name = str(spec.name)
		for i in range(spec["values"].size()): choice.set_item_metadata(i, spec["values"][i])
		iterative_choices[str(spec.key)] = choice
		iterative_choices_panel.add_child(choice)
		choice.item_selected.connect(func(index: int):
			_edit_loaded_blob_setting(str(spec.key), choice.get_item_metadata(index))
			_update_pipeline_mode_controls())
	surface_operations_heading = _label("BLOB SURFACE OPERATIONS · STAGE 2", blob_pipeline_panel)
	for spec: Array in [["normal_lumpy", "Smooth / lumpy tissue · experimental", false], ["bumps", "Small tissue bumps · experimental", false], ["sacs", "Swollen tissue sacs · experimental", false], ["grooves", "Compression grooves", true], ["cavities", "Deep cavities · experimental", false], ["webbing", "Porous webbing · experimental", false], ["fibers", "Branching tissue ridges · experimental", false], ["nodules", "Legacy regional nodules", true]]:
		var toggle := CheckButton.new()
		toggle.text = str(spec[1])
		toggle.name = "Surface" + str(spec[0]).to_pascal_case()
		toggle.button_pressed = bool(spec[2])
		blob_pipeline_panel.add_child(toggle)
		surface_checks[spec[0]] = toggle
		if str(spec[0]) == "fibers":
			toggle.tooltip_text = "Bounded adherent branching tissue only. Free tendrils and mixed-mode art remain unvalidated."
			toggle.toggled.connect(func(pressed: bool):
				if pressed:
					_fiber_mode = "adherent_fibers"; _fiber_mode_explicit = true
					_update_fiber_label())
		toggle.toggled.connect(func(pressed: bool): _edit_loaded_blob_operation(str(spec[0]), pressed))
	legacy_surface_status = _label("Compatible types combine within host regions. Lumpy tissue, bumps, sacs, cavities and webbing are separate experimental geometry operations pending visual review. Branching tissue ridges have limited adherent-mode clay acceptance, not a finished fibrous category. Free tendrils and mixed modes remain unvalidated; folded messy tissue is an internal candidate, hidden pending public-path validation.", blob_pipeline_panel)
	legacy_surface_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legacy_surface_status.add_theme_font_size_override("font_size", 11)
	secondary_toggle = CheckButton.new()
	secondary_toggle.name = "SecondaryStructures"
	secondary_toggle.text = "Secondary embedded faces · stage 3"
	secondary_toggle.tooltip_text = "Current secondary support is embedded face modules. Procedural extra heads, vines, membranes and surface operations on new secondary carriers are not implemented yet."
	secondary_toggle.button_pressed = true
	secondary_toggle.toggled.connect(func(pressed: bool): _edit_loaded_blob_setting("secondary_enabled", pressed))
	blob_pipeline_panel.add_child(secondary_toggle)
	material_stage_heading = _label("MATERIALS · STAGE 4", blob_pipeline_panel)
	cavity_material_toggle = CheckButton.new()
	cavity_material_toggle.name = "CavityInteriorTissue"
	cavity_material_toggle.text = "Cavity-interior tissue"
	cavity_material_toggle.tooltip_text = "Use authored tissue inside eligible existing cavities. Keeps rims and lips unchanged; does not create cavities."
	cavity_material_toggle.toggled.connect(func(enabled: bool):
		_cavity_material_assignment = CAVITY_MATERIAL_PROFILE if enabled else ""
		_edit_loaded_blob_setting(CAVITY_MATERIAL_SETTING, _cavity_material_assignment, not enabled)
		cavity_material_toggle.text = "Cavity-interior tissue"
		_material_edit_pending())
	blob_pipeline_panel.add_child(cavity_material_toggle)
	_label("Tissue response", blob_pipeline_panel)
	tissue_response_select = _option(["Baseline tissue · v1", "Experimental tissue · v2"])
	tissue_response_select.name = "TissueResponse"
	tissue_response_select.set_item_metadata(0, TISSUE_BASELINE)
	tissue_response_select.set_item_metadata(1, TISSUE_EXPERIMENT)
	tissue_response_select.tooltip_text = "Baseline retains the established look. V2 is an artistically experimental response, not a geometry change."
	tissue_response_select.item_selected.connect(func(index: int):
		_tissue_profile = str(tissue_response_select.get_item_metadata(index))
		_material_edit_pending())
	blob_pipeline_panel.add_child(tissue_response_select)
	material_wetness_heading = _label("Material wetness · stage 4 only", blob_pipeline_panel)
	material_wetness = HSlider.new()
	material_wetness.name = "MaterialWetness"
	material_wetness.min_value = 0.35
	material_wetness.max_value = 1.4
	material_wetness.step = 0.01
	material_wetness.value = 0.92
	_material_wetness_value = material_wetness.value
	material_wetness.custom_minimum_size.y = 22
	blob_pipeline_panel.add_child(material_wetness)
	material_refresh_button = _button("Refresh materials only", "Reuse every preserved geometry stage and final skin binding. Only appearance changes.")
	material_refresh_button.name = "RefreshMaterialsOnly"
	material_refresh_button.disabled = true
	material_refresh_button.pressed.connect(func(): material_refresh_requested.emit(get_material_options()))
	material_status_label = _label("Appearance only. Cavity tissue does not create cavities.", blob_pipeline_panel)
	material_status_label.name = "MaterialStatus"
	material_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	material_status_label.add_theme_font_size_override("font_size", 11)
	blob_pipeline_panel.add_child(material_refresh_button)
	material_wetness.value_changed.connect(func(value: float):
		_material_wetness_value = value
		_material_wetness_explicit = true
		_edit_loaded_blob_setting("material_wetness", value)
		_material_edit_pending())

func _update_pipeline_mode_controls() -> void:
	if not is_instance_valid(pipeline_mode_toggle): return
	var iterative: bool = type_select.selected == 0 and pipeline_mode_toggle.button_pressed
	# These shared sliders must regain their original behavior for legacy Blob
	# and every non-Blob type. Disabled v2 values remain in the saved recipe.
	for spec: Array in PARAMS:
		var key: String = str(spec[0])
		parameter_labels[key].text = str(spec[1])
		parameter_labels[key].tooltip_text = str(spec[5])
		sliders[key].tooltip_text = str(spec[5])
		sliders[key].editable = true
	if iterative:
		for key: String in ["growth_density", "uncanny_features"]:
			sliders[key].editable = false
			parameter_labels[key].text = "Extra growth · unavailable in v2" if key == "growth_density" else "Faces / sensory · unavailable in v2"
			var explanation: String = "This generator is not implemented in iterative v2. Its saved value is retained for legacy mode, but does not change this v2 creature."
			parameter_labels[key].tooltip_text = explanation
			sliders[key].tooltip_text = explanation
		parameter_labels.appendage_density.text = "Basal support density · v2"
		parameter_labels.appendage_density.tooltip_text = "Controls structural basal support count within the body grammar. It does not vary the primary tendril count; the stage-6 toggle adds one optional secondary tendril."
		sliders.appendage_density.tooltip_text = parameter_labels.appendage_density.tooltip_text
		parameter_labels.surface_detail.text = "Sac folds / material detail · v2"
		parameter_labels.surface_detail.tooltip_text = "Controls authored sac-fold count and thickness at stage 5 plus final material detail. It does not enable porous, membrane or arbitrary surface-operation profiles."
		sliders.surface_detail.tooltip_text = parameter_labels.surface_detail.tooltip_text
		parameter_labels.irregularity.text = "Body sculpt irregularity · v2"
		parameter_labels.irregularity.tooltip_text = "Sculpts existing body masses after the smooth blockout. This does not request misplaced faces or sensory structures."
		sliders.irregularity.tooltip_text = parameter_labels.irregularity.tooltip_text
	if is_instance_valid(iterative_choices_panel): iterative_choices_panel.visible = iterative
	var compact_requested: bool = iterative and _iterative_choice("blob_body_profile") == "compact_body_v1"
	var seeded_requested: bool = iterative and _iterative_choice("blob_identity_profile") == "seeded_v1"
	if compact_requested:
		parameter_labels.appendage_density.text = "Support density · inactive in compact grammar"
		parameter_labels.appendage_density.tooltip_text = "Compact-body support count is seed-authored, not density-controlled. This value still applies when the seed selects an unchanged grammar."
		sliders.appendage_density.tooltip_text = parameter_labels.appendage_density.tooltip_text
	if iterative:
		parameter_labels.surface_detail.tooltip_text = "Controls sac folds, opted-in secondary tendon ridge density and final material detail. No porous or membrane generator is enabled here."
		sliders.surface_detail.tooltip_text = parameter_labels.surface_detail.tooltip_text
	pipeline_mode_notice.visible = iterative
	pipeline_mode_notice.text = "Seeded mixtures use only body/supports, sacs, sac cavities and tendrils; some profiles intentionally omit later features." if seeded_requested else "Foundation retains two sacs, one cavity and primary/optional secondary tendrils."
	if _iterative_choice("blob_direct_surface_profile") == "vascular_183b_v1":
		pipeline_mode_notice.text += " Vascular183b is a single qualified specimen only: seed22, Low quality, seeded mixture, compact body, tendon ridges, default shape controls, shared sac growth OFF. Unsupported bodies and edited vascular recipes fail explicitly; this is not generalized procedural diversity."
	elif _iterative_choice("blob_direct_surface_profile") == "vascular_blueprint_v1":
		pipeline_mode_notice.text += " Blueprint vascular adapts to existing core/sac features in Low quality, shared sac growth OFF. No sacs means no added network; cavity or routing exclusions may skip branches. This is bounded experimental authoring, not finished vascular art or mapped-host support."
	pipeline_mode_notice.text += " Compact changes only the eligible stilt-body grammar; other grammars remain unchanged. Ridges are subtle. Grounding moves one common intrinsic frame, not individual stages or a stable stance. Faces, membranes, porous tissue and sac-specific shaders remain unavailable. Animation rules are stored intent, not rig drivers."
	if is_instance_valid(surface_operations_heading): surface_operations_heading.visible = not iterative
	if is_instance_valid(legacy_surface_status): legacy_surface_status.visible = not iterative
	for toggle: CheckButton in surface_checks.values(): toggle.visible = not iterative
	if not iterative and _loaded_blob_active and surface_checks.has("nodules"):
		surface_checks.nodules.visible = "nodules" in _loaded_blob_settings.get("surface_operations", [])
	if is_instance_valid(secondary_toggle):
		secondary_toggle.text = "Secondary tendrils · stage 6" if iterative else "Secondary embedded faces · stage 3"
		secondary_toggle.tooltip_text = "Allows profile-authored stage-6 tendrils, which may be absent in a seeded mixture. Opted-in rooted ridges target every realized secondary tendril. No heads, membranes or arbitrary attachments." if iterative else "Current secondary support is embedded face modules. Procedural extra heads, vines, membranes and surface operations on new secondary carriers are not implemented yet."
	if is_instance_valid(cavity_material_toggle): cavity_material_toggle.visible = not iterative
	if is_instance_valid(material_stage_heading): material_stage_heading.text = "MATERIALS · STAGE 7" if iterative else "MATERIALS · STAGE 4"
	if is_instance_valid(material_wetness_heading): material_wetness_heading.text = "Material wetness · appearance only" if iterative else "Material wetness · stage 4 only"

func get_material_options() -> Dictionary:
	# A flat UI payload only. Main routes the response to metadata, not settings.
	var options := {CAVITY_MATERIAL_SETTING: _cavity_material_assignment, TISSUE_PROFILE_KEY: _tissue_profile}
	if _material_wetness_explicit: options["material_wetness"] = _material_wetness_value
	return options

func _material_edit_pending() -> void:
	if is_instance_valid(material_status_label):
		material_status_label.text = "Pending appearance changes. Use Refresh materials only."
		material_status_label.tooltip_text = "No geometry or skin binding is changed by material refresh."

func _apply_material_controls(dna: Dictionary) -> void:
	_cavity_material_assignment = str(dna.get("settings", {}).get(CAVITY_MATERIAL_SETTING, ""))
	cavity_material_toggle.set_pressed_no_signal(_cavity_material_assignment == CAVITY_MATERIAL_PROFILE)
	cavity_material_toggle.text = "Cavity-interior tissue" if _cavity_material_assignment in ["", "off", CAVITY_MATERIAL_PROFILE] else "Loaded cavity tissue · unsupported"
	_tissue_profile = str(dna.get("metadata", {}).get(TISSUE_PROFILE_KEY, ""))
	while tissue_response_select.item_count > 2:
		tissue_response_select.remove_item(2)
	if _tissue_profile in ["", TISSUE_BASELINE]:
		tissue_response_select.select(0)
	elif _tissue_profile == TISSUE_EXPERIMENT:
		tissue_response_select.select(1)
	else:
		# Preserve older/future saved choices until the user explicitly changes them.
		tissue_response_select.add_item("Loaded legacy organic" if _tissue_profile == "baseline" else "Loaded response · unsupported")
		tissue_response_select.set_item_metadata(2, _tissue_profile)
		tissue_response_select.select(2)
	# Range snaps even programmatic values to its step. Keep the exact saved
	# value until an actual edit, or a cavity-only refresh can miss the atlas
	# cache after JSON load despite an unchanged visible wetness setting.
	_material_wetness_explicit = dna.get("materials", {}).has("wetness") or dna.get("settings", {}).has("material_wetness")
	_material_wetness_value = float(dna.get("materials", {}).get("wetness", dna.get("settings", {}).get("material_wetness", MaterialConfig.configuration(dna).wetness)))
	material_wetness.set_value_no_signal(_material_wetness_value)

func show_material_result(dna: Dictionary, report: Dictionary = {}) -> void:
	_apply_material_controls(dna)
	material_status_label.tooltip_text = ""
	if str(dna.get("type", "")) != "Blob":
		material_status_label.text = "These material controls apply to Blob only."
	elif str(dna.get("settings", {}).get("blob_pipeline_mode", "")) == "iterative_v2":
		material_status_label.text = "Feature rules assign material categories. Wetness and tissue response change appearance only."
	elif _cavity_material_assignment == CAVITY_MATERIAL_PROFILE:
		var cavity: Dictionary = report.get(CAVITY_MATERIAL_SETTING, {})
		if bool(cavity.get("applied", false)):
			material_status_label.text = "Cavity tissue applied to %d interior vertices. Geometry unchanged." % int(cavity.get("interior_vertices", 0))
		elif cavity.is_empty():
			material_status_label.text = "Cavity tissue enabled; eligibility is checked on refresh."
		else:
			material_status_label.text = "No eligible cavity interior was changed. Geometry unchanged."
			material_status_label.tooltip_text = str(cavity.get("reason", "No assignable interior tissue was found."))
	elif _cavity_material_assignment not in ["", "off"]:
		material_status_label.text = "Unsupported saved cavity setting retained; choose a supported option."
	else:
		material_status_label.text = "Cavity tissue off. V2 response is experimental." if _tissue_profile == TISSUE_EXPERIMENT else "Appearance only. Cavity tissue does not create cavities."

func _build_combinations() -> void:
	combination_panel = VBoxContainer.new()
	combination_panel.name = "CombinationControls"
	combination_panel.add_theme_constant_override("separation", 8)
	combination_panel.visible = false
	add_child(combination_panel)
	var heading := Label.new()
	heading.text = "COMBINE ANATOMIES"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color("8da7a3"))
	combination_panel.add_child(heading)
	for index in range(2):
		var source_name := Label.new()
		source_name.text = "Source " + ("A" if index == 0 else "B")
		combination_panel.add_child(source_name)
		var source_row := HBoxContainer.new()
		combination_panel.add_child(source_row)
		var source_type := _option(TYPES)
		source_type.select(0 if index == 0 else 2)
		source_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		source_types.append(source_type)
		source_row.add_child(source_type)
		var source_seed := _seed(109 if index == 0 else 307)
		source_seed.custom_minimum_size.x = 105
		source_seed.size_flags_horizontal = Control.SIZE_FILL
		source_seeds.append(source_seed)
		source_row.add_child(source_seed)
		source_type.item_selected.connect(func(_unused: int): _reset_source(index))
		source_seed.value_changed.connect(func(_unused: float): _reset_source(index))
		var button_row := HBoxContainer.new()
		combination_panel.add_child(button_row)
		var build := _button("Generate " + ("A" if index == 0 else "B"), "Generate this source independently and inspect it before combining.")
		build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build.pressed.connect(func(): source_generation_requested.emit(index))
		button_row.add_child(build)
		_build_buttons.append(build)
		var capture := _button("Use displayed", "Capture the displayed full DNA as this source, including an existing combination.")
		capture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		capture.pressed.connect(func(): capture_source_requested.emit(index))
		button_row.add_child(capture)
		var view := _button("View", "Reconstruct the stored source without changing its DNA.")
		view.pressed.connect(func(): source_view_requested.emit(index))
		button_row.add_child(view)
		_build_buttons.append(view)
		var source_label := Label.new()
		source_label.text = "Generated from type + seed when combined"
		source_label.add_theme_font_size_override("font_size", 11)
		source_label.add_theme_color_override("font_color", Color("8b9c9b"))
		source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		source_labels.append(source_label)
		combination_panel.add_child(source_label)
	method_select = _option(METHODS)
	method_select.select(1)
	method_select.tooltip_text = "Attachment grows a connecting bridge. Fusion merges volumes. Replacement grafts anatomy. Integration reorganizes selected regions."
	combination_panel.add_child(method_select)
	var fusion_label := Label.new()
	fusion_label.text = "Fusion intensity"
	combination_panel.add_child(fusion_label)
	fusion_slider = HSlider.new()
	fusion_slider.min_value = 0.0
	fusion_slider.max_value = 1.0
	fusion_slider.step = 0.01
	fusion_slider.value = 0.6
	fusion_slider.custom_minimum_size.y = 22
	fusion_slider.tooltip_text = "Controls how deeply anatomy regions merge and how much source structure is integrated."
	combination_panel.add_child(fusion_slider)

func _reset_source(index: int) -> void:
	if _suppress_source_reset:
		return
	source_dna[index] = {}
	source_labels[index].text = "Generated from type + seed when combined"

func set_source(index: int, dna: Dictionary) -> void:
	source_dna[index] = dna.duplicate(true)
	_suppress_source_reset = true
	source_types[index].select(maxi(0, TYPES.find(str(dna.get("type", "Blob")))))
	source_seeds[index].value = int(dna.get("seed", 1))
	_suppress_source_reset = false
	source_labels[index].text = "Stored DNA · %s · %d components" % [str(dna.get("type", "Alien")), dna.get("nodes", []).size()]

func randomize_seed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	seed_input.value = rng.randi_range(1, 2147483647)

func get_settings() -> Dictionary:
	if _loaded_blob_active and type_select.selected == 0:
		var retained: Dictionary = _loaded_blob_settings.duplicate(true)
		# Preserve inactive intent in the controls, never leak v2-only placement
		# or authoring selectors into a legacy generation request.
		if retained.get("blob_pipeline_mode", "") != "iterative_v2":
			for spec: Dictionary in ITERATIVE_CHOICES: retained.erase(str(spec.key))
		return retained
	var settings := {"quality": quality_select.selected}
	if type_select.selected == 0:
		if pipeline_mode_toggle.button_pressed:
			settings["blob_pipeline_mode"] = "iterative_v2"
			for spec: Dictionary in ITERATIVE_CHOICES:
				var value: Variant = _iterative_choice(str(spec.key))
				if value != spec["values"][0]: settings[str(spec.key)] = value
		var operations: Array = []
		for operation: String in surface_checks:
			if surface_checks[operation].button_pressed:
				operations.append(operation)
		settings["surface_operations"] = operations
		if "fibers" in operations or _fiber_mode_explicit:
			settings["blob_fiber_mode"] = _fiber_mode
		settings["surface_library_version"] = 1
		settings["secondary_enabled"] = secondary_toggle.button_pressed
		if _material_wetness_explicit: settings["material_wetness"] = _material_wetness_value
		if not _cavity_material_assignment.is_empty():
			settings[CAVITY_MATERIAL_SETTING] = _cavity_material_assignment
	for key in sliders:
		settings[key] = sliders[key].value
	settings["first_type"] = TYPES[source_types[0].selected]
	settings["second_type"] = TYPES[source_types[1].selected]
	settings["first_seed"] = int(source_seeds[0].value)
	settings["second_seed"] = int(source_seeds[1].value)
	settings["method"] = METHODS[method_select.selected]
	settings["fusion_intensity"] = fusion_slider.value
	for index in range(2):
		if not source_dna[index].is_empty():
			settings["source_a" if index == 0 else "source_b"] = source_dna[index].duplicate(true)
	return settings

func get_request() -> Dictionary:
	var request := {"type": TYPES[type_select.selected], "seed": int(seed_input.value), "settings": get_settings(), "target": "creature"}
	if type_select.selected == 0 and not _tissue_profile.is_empty():
		request["material_metadata"] = {TISSUE_PROFILE_KEY: _tissue_profile}
	return request

func get_source_request(index: int) -> Dictionary:
	var settings := get_settings()
	settings.erase("source_a")
	settings.erase("source_b")
	settings["size"] = 1.0
	# Recursively selected combinations use the generator's bounded default pair.
	settings.erase("first_type")
	settings.erase("second_type")
	settings.erase("first_seed")
	settings.erase("second_seed")
	return {"type": TYPES[source_types[index].selected], "seed": int(source_seeds[index].value), "settings": settings, "target": "source_" + str(index)}

func apply_dna(dna: Dictionary) -> void:
	_applying_dna = true
	_clear_loaded_blob_recipe()
	var index := TYPES.find(str(dna.get("type", "Humanoid")))
	type_select.select(maxi(0, index))
	combination_panel.visible = index == 6
	blob_pipeline_panel.visible = index == 0
	seed_input.value = int(dna.get("seed", 1))
	var settings: Dictionary = dna.get("settings", {})
	pipeline_mode_toggle.set_pressed_no_signal(str(settings.get("blob_pipeline_mode", "")) == "iterative_v2")
	_load_iterative_choices(settings if index == 0 and pipeline_mode_toggle.button_pressed else {})
	_update_pipeline_mode_controls()
	for key in sliders:
		if settings.has(key):
			sliders[key].value = float(settings[key])
	quality_select.select(clampi(int(settings.get("quality", 1)), 0, 2))
	var operations: Array = settings.get("surface_operations", ["nodules", "grooves"])
	_fiber_mode = str(settings.get("blob_fiber_mode", "adherent_fibers"))
	_fiber_mode_explicit = settings.has("blob_fiber_mode")
	for operation: String in surface_checks:
		if operation == "nodules": surface_checks[operation].visible = operation in operations
		surface_checks[operation].set_pressed_no_signal(operation in operations or (operation == "cavities" and bool(settings.get("blob_porous_candidate", false))))
	_update_fiber_label()
	secondary_toggle.button_pressed = bool(settings.get("secondary_enabled", true))
	show_material_result(dna)
	if index == 6:
		_suppress_source_reset = true
		for i in range(2):
			var prefix := "first" if i == 0 else "second"
			source_types[i].select(maxi(0, TYPES.find(str(settings.get(prefix + "_type", "Blob")))))
			source_seeds[i].value = int(settings.get(prefix + "_seed", 1))
		_suppress_source_reset = false
		method_select.select(maxi(0, METHODS.find(str(settings.get("method", "Fusion")))))
		fusion_slider.value = float(settings.get("fusion_intensity", 0.6))
		for i in range(2):
			var key := "source_a" if i == 0 else "source_b"
			if settings.get(key) is Dictionary and not settings[key].is_empty():
				set_source(i, settings[key])
			else:
				_reset_source(i)

	_applying_dna = false
	if index == 0: _capture_loaded_blob_recipe(dna)
	_update_pipeline_mode_controls()


func _clear_loaded_blob_recipe() -> void:
	_loaded_blob_active = false
	_loaded_blob_settings.clear()
	_loaded_blob_unsupported.clear()
	_update_loaded_blob_notice()

func _capture_loaded_blob_recipe(dna: Dictionary) -> void:
	_loaded_blob_active = true
	var settings: Dictionary = dna.get("settings", {})
	for key: String in settings:
		if key in LOADED_BLOB_SETTINGS:
			_loaded_blob_settings[key] = settings[key]
		else:
			_loaded_blob_unsupported.append(key)
	_loaded_blob_settings = _loaded_blob_settings.duplicate(true)
	_loaded_blob_unsupported.sort()
	# Preserve the existing explicit appearance precedence without copying
	# materials or arbitrary metadata into a generation request.
	if dna.get("materials", {}).has("wetness"):
		_loaded_blob_settings["material_wetness"] = _material_wetness_value
	_update_loaded_blob_notice()

func _edit_loaded_blob_setting(key: String, value: Variant, remove: bool = false) -> void:
	if not _loaded_blob_active or _applying_dna: return
	if remove: _loaded_blob_settings.erase(key)
	else: _loaded_blob_settings[key] = value
	_update_loaded_blob_notice()

func _edit_loaded_blob_operation(operation: String, enabled: bool) -> void:
	if not _loaded_blob_active or _applying_dna: return
	var supplied: Variant = _loaded_blob_settings.get("surface_operations", ["nodules", "grooves"])
	var operations: Array = supplied.duplicate() if supplied is Array else []
	if enabled and operation not in operations: operations.append(operation)
	if not enabled:
		while operation in operations: operations.erase(operation)
	_loaded_blob_settings["surface_operations"] = operations
	if operation == "fibers" and enabled: _loaded_blob_settings["blob_fiber_mode"] = _fiber_mode
	_update_loaded_blob_notice()

func _loaded_recipe_blocked() -> bool:
	return _loaded_blob_active and (not _loaded_blob_unsupported.is_empty() or not _invalid_iterative_selector().is_empty())

func _update_generation_availability() -> void:
	if is_instance_valid(generate_button): generate_button.disabled = _busy or _loaded_recipe_blocked()
	if is_instance_valid(regenerate_button): regenerate_button.disabled = _busy or _loaded_recipe_blocked()

func _request_generation() -> void:
	if _loaded_recipe_blocked():
		progress_label.text = "This saved Blob recipe cannot be regenerated by this build. See the loaded-recipe notice; change creature type to reset."
		return
	generation_requested.emit(get_request())


func _loaded_selector_warning() -> String:
	for key: String in ["blob_hanging_load_version", "blob_hanging_surface_integration_version"]:
		if not _loaded_blob_settings.has(key): continue
		var value: Variant = _loaded_blob_settings[key]
		var valid: bool = (value is bool and not value) or ((value is int or value is float) and (float(value) in [0.0, 1.0, 2.0] if key == "blob_hanging_load_version" else float(value) in [0.0, 1.0]))
		if not valid: return " Unsupported saved selector value retained without enabling it: " + key + "."
	return ""

func _update_loaded_blob_notice() -> void:
	_update_generation_availability()
	if not is_instance_valid(loaded_recipe_notice): return
	var experimental := _loaded_blob_active and (_loaded_blob_settings.has("blob_hanging_load_version") or _loaded_blob_settings.has("blob_hanging_surface_integration_version") or _loaded_blob_settings.has("blob_fiber_material_assignment"))
	loaded_recipe_notice.visible = experimental or _loaded_recipe_blocked()
	if _loaded_recipe_blocked():
		loaded_recipe_notice.text = "Loaded recipe: regeneration unavailable"
		loaded_recipe_notice.tooltip_text = "Unsupported saved settings: %s. They are not silently discarded. Load, Save, stage views and material refresh remain available. Change creature type to reset the loaded recipe." % ", ".join(_loaded_blob_unsupported + ([_invalid_iterative_selector()] if not _invalid_iterative_selector().is_empty() else []))
	else:
		loaded_recipe_notice.text = "Loaded Blob experiment · save/API-only"
		loaded_recipe_notice.tooltip_text = "Requested hanging load: %s; surface integration: %s; fiber material: %s. Regeneration retains these exact settings; existing engine eligibility gates remain authoritative. Another seed may select different anatomy. Requested surface operations do not guarantee accepted features. Change creature type to reset the loaded recipe." % [str(_loaded_blob_settings.get("blob_hanging_load_version", "off")), str(_loaded_blob_settings.get("blob_hanging_surface_integration_version", "off")), str(_loaded_blob_settings.get("blob_fiber_material_assignment", "off"))]
		loaded_recipe_notice.tooltip_text += _loaded_selector_warning()

func _update_fiber_label() -> void:
	if not surface_checks.has("fibers"): return
	# Loading an unvalidated mode never silently rewrites saved DNA settings.
	# A fresh user selection deliberately selects only the bounded accepted mode.
	surface_checks.fibers.text = "Branching tissue ridges · experimental" if _fiber_mode == "adherent_fibers" else "Loaded %s · unvalidated" % _fiber_mode.replace("_", " ")

func set_busy(busy: bool) -> void:
	_busy = busy
	pipeline_mode_toggle.disabled = busy
	for choice: OptionButton in iterative_choices.values(): choice.disabled = busy
	generate_button.disabled = busy
	material_refresh_button.disabled = busy or not bool(material_refresh_button.get_meta("available", false))
	cavity_material_toggle.disabled = busy
	tissue_response_select.disabled = busy
	material_wetness.editable = not busy
	load_button.disabled = busy
	cancel_button.disabled = not busy
	progress_bar.visible = busy
	for button in _build_buttons:
		button.disabled = busy
	_update_generation_availability()
	if busy:
		progress_bar.value = 0.0

func show_progress(value: float, stage: String, elapsed: float) -> void:
	if is_finite(value):
		progress_bar.value = maxf(progress_bar.value, clampf(value, 0.0, 1.0))
	progress_label.text = "%s · %.1fs" % [stage, elapsed]

func _add_parameter(spec: Array) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var label := Label.new()
	label.text = spec[1]
	parameter_labels[spec[0]] = label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.tooltip_text = spec[5]
	row.add_child(label)
	var number := Label.new()
	number.text = "%.2f" % float(spec[4])
	number.add_theme_color_override("font_color", Color("a5c6be"))
	row.add_child(number)
	value_labels[spec[0]] = number
	var slider := HSlider.new()
	slider.name = str(spec[0]).to_pascal_case()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = 0.01
	slider.value = spec[4]
	slider.custom_minimum_size.y = 20
	slider.tooltip_text = spec[5]
	slider.value_changed.connect(func(value: float):
		number.text = "%.2f" % value
		_edit_loaded_blob_setting(str(spec[0]), value))
	sliders[spec[0]] = slider
	add_child(slider)

func _heading(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _label(text: String, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	if parent != null:
		parent.add_child(label)
	else:
		add_child(label)
	return label

func _option(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size.y = 34
	for item in items:
		option.add_item(item)
	return option

func _seed(value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 2147483647
	spin.step = 1
	spin.value = value
	spin.rounded = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.custom_minimum_size.y = 34
	return spin

func _button(text: String, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size.y = 31
	return button

func _iterative_choice(key: String) -> Variant:
	var choice: OptionButton = iterative_choices[key]
	return choice.get_item_metadata(choice.selected)

func _load_iterative_choices(settings: Dictionary) -> void:
	for spec: Dictionary in ITERATIVE_CHOICES:
		var choice: OptionButton = iterative_choices[str(spec.key)]
		while choice.item_count > spec["values"].size(): choice.remove_item(choice.item_count - 1)
		var requested: Variant = settings.get(str(spec.key), spec["values"][0])
		var index: int = 0 if spec.key == "blob_ground_placement" and requested == "" else spec["values"].find(requested)
		if index < 0:
			choice.add_item("Unsupported saved selector · not enabled")
			index = choice.item_count - 1
			choice.set_item_metadata(index, requested)
		choice.select(index)

func _invalid_iterative_selector() -> String:
	if _loaded_blob_settings.get("blob_pipeline_mode", "") != "iterative_v2": return ""
	for spec: Dictionary in ITERATIVE_CHOICES:
		var requested: Variant = _loaded_blob_settings.get(str(spec.key), spec["values"][0])
		if spec.key == "blob_ground_placement" and requested == "": continue
		if not requested is String or requested not in spec["values"]: return str(spec.key) + " (unsupported value)"
	return ""
