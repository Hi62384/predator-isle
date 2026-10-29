class_name AlienFoundryApplication
extends Control
## The main thread owns UI and scene-tree/resource uploads. GenerationJob owns all
## expensive anatomical/field/skinning work; the current organism stays inspectable.

signal generation_finished(dna: Dictionary, stats: Dictionary)
signal generation_failed(message: String)
signal generation_cancelled

const ControlsScript = preload("res://alien_foundry/scripts/ui/GeneratorControls.gd")
const ViewerScript = preload("res://alien_foundry/scripts/ui/ViewerController.gd")
const JobScript = preload("res://alien_foundry/scripts/jobs/GenerationJob.gd")
const Serializer = preload("res://alien_foundry/scripts/persistence/CreatureSerializer.gd")
const Renderer = preload("res://alien_foundry/scripts/rendering/CreatureRenderer.gd")
const PipelineCache = preload("res://alien_foundry/scripts/pipeline/PipelineCache.gd")
const Diagnostics = preload("res://alien_foundry/scripts/rendering/BlobFeatureDiagnostic.gd")

var controls: GeneratorControls
var viewer: ViewerController
var job: GenerationJob
var active_dna: Dictionary = {}
var active_stats: Dictionary = {}
var last_generation_error: Dictionary = {}
var renderer = Renderer.new()
var organism_label: Label
var stats_label: Label
var view_select: OptionButton
var stage_select: OptionButton
var pipeline_status_label: Label
var variant_select: OptionButton
var feature_inspector_button: Button
var feature_inspector: PanelContainer
var feature_mode_select: OptionButton
var feature_select: OptionButton
var feature_descendants: CheckButton
var feature_parent_button: Button
var feature_coverage: Label
var feature_details: Label
var _feature_artifact: Dictionary = {}
var _inspector_registry_key := ""
var _feature_inspector_open := true
var _applied_stage := -99
var _final_view_choice := 0
var _variant_root: Node3D
var _variant_seed := 0
var _comparison_active := false
var _current_organism_title := ""
var pipeline_cache = PipelineCache.new()
var skeleton_toggle: CheckButton
var anatomy_toggle: CheckButton
var rig_toggle: CheckButton
var auto_toggle: CheckButton
var save_dialog: FileDialog
var load_dialog: FileDialog
var error_dialog: AcceptDialog
var _last_progress_update := 0.0
var _assembly_state: Dictionary = {}
var _assembly_result: Dictionary = {}
var _assembly_started_usec: int = 0
var _assembly_max_step_ms: float = 0.0

func _ready() -> void:
	theme = _make_theme()
	_build_interface()
	_build_dialogs()
	controls.generation_requested.connect(generate_request)
	controls.source_generation_requested.connect(func(index: int): generate_request(controls.get_source_request(index)))
	controls.capture_source_requested.connect(_capture_source)
	controls.source_view_requested.connect(_view_source)
	controls.cancel_requested.connect(cancel_generation)
	controls.save_requested.connect(_open_save)
	controls.material_refresh_requested.connect(_refresh_materials)
	controls.load_requested.connect(func(): load_dialog.popup_centered_ratio(0.7))
	if not get_meta("skip_autogenerate", false):
		call_deferred("_generate_initial")

func _generate_initial() -> void:
	generate_request(controls.get_request())

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("10171b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 22)
	header_margin.add_theme_constant_override("margin_right", 22)
	header_margin.add_theme_constant_override("margin_top", 14)
	header_margin.add_theme_constant_override("margin_bottom", 14)
	root.add_child(header_margin)
	var header := HBoxContainer.new()
	header_margin.add_child(header)
	var title := Label.new()
	title.text = "PREDATOR ISLE  /  ALIEN FOUNDRY"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ORGANIC GENERATION LAB"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color("7c9996"))
	header.add_child(subtitle)
	root.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 342
	sidebar.add_theme_stylebox_override("panel", _style(Color("182126"), 0, 0))
	body.add_child(sidebar)
	var sidebar_column := VBoxContainer.new()
	sidebar_column.add_theme_constant_override("separation", 0)
	sidebar.add_child(sidebar_column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_column.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 19)
	margin.add_theme_constant_override("margin_right", 19)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	scroll.add_child(margin)
	controls = ControlsScript.new()
	controls.name = "GenerationControls"
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(controls)
	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 19)
	action_margin.add_theme_constant_override("margin_right", 19)
	action_margin.add_theme_constant_override("margin_bottom", 15)
	sidebar_column.add_child(action_margin)
	controls.action_panel.reparent(action_margin)
	body.add_child(VSeparator.new())
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_theme_constant_override("separation", 0)
	body.add_child(preview)
	var toolbar_margin := MarginContainer.new()
	toolbar_margin.add_theme_constant_override("margin_left", 16)
	toolbar_margin.add_theme_constant_override("margin_right", 16)
	toolbar_margin.add_theme_constant_override("margin_top", 9)
	toolbar_margin.add_theme_constant_override("margin_bottom", 9)
	preview.add_child(toolbar_margin)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 9)
	toolbar_margin.add_child(toolbar)
	view_select = OptionButton.new()
	view_select.name = "MaterialView"
	for item in ["Textured", "Neutral clay", "Wireframe"]:
		view_select.add_item(item)
	view_select.custom_minimum_size.x = 130
	view_select.item_selected.connect(func(index: int):
		if stage_select.selected == 0: _final_view_choice = index
		_apply_view_options())
	toolbar.add_child(view_select)
	stage_select = OptionButton.new()
	stage_select.name = "PipelineStagePreview"
	for stage_label: String in ["Final rigged organism", "1 · Smooth base", "2 · Surface geometry", "3 · Secondary structures", "4 · Materials"]:
		stage_select.add_item(stage_label)
	stage_select.disabled = true
	stage_select.tooltip_text = "Inspect actual retained artifacts. Unavailable stages are identified, never replaced by renamed snapshots. Stage switching keeps seed, camera, orientation and scale."
	stage_select.item_selected.connect(func(_index: int): _apply_view_options())
	toolbar.add_child(stage_select)
	skeleton_toggle = _toggle(toolbar, "Skeleton", "Show the actual generated Skeleton3D hierarchy.")
	anatomy_toggle = _toggle(toolbar, "Anatomy", "Show anatomical component centers and their connections.")
	rig_toggle = _toggle(toolbar, "Rig preview", "Bend joints, animate flexible chains, and open compatible mouths.")
	for toggle in [skeleton_toggle, anatomy_toggle, rig_toggle]:
		toggle.toggled.connect(func(_value: bool): _apply_view_options())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	auto_toggle = _toggle(toolbar, "Spin", "Slowly orbit the camera without changing the organism.")
	auto_toggle.toggled.connect(func(value: bool): viewer.set_auto_rotate(value))
	var reset := Button.new()
	reset.text = "Reset camera"
	reset.tooltip_text = "Frame the entire organism, including long appendages. Shortcut: F."
	reset.pressed.connect(func(): viewer.reset_camera())
	toolbar.add_child(reset)
	var organism_margin := MarginContainer.new()
	organism_margin.add_theme_constant_override("margin_left", 20)
	organism_margin.add_theme_constant_override("margin_top", 8)
	organism_margin.add_theme_constant_override("margin_bottom", 9)
	preview.add_child(organism_margin)
	var description := VBoxContainer.new()
	organism_margin.add_child(description)
	organism_label = Label.new()
	organism_label.text = "Your organism will appear here"
	organism_label.add_theme_font_size_override("font_size", 18)
	description.add_child(organism_label)
	stats_label = Label.new()
	stats_label.text = "Anatomy → organic volume → continuous surface → rig"
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color("809a97"))
	description.add_child(stats_label)
	var stage_status_row := HBoxContainer.new()
	stage_status_row.custom_minimum_size.y = 28
	description.add_child(stage_status_row)
	pipeline_status_label = Label.new()
	pipeline_status_label.name = "StageArtifactStatus"
	pipeline_status_label.text = "Stage outputs appear after generation."
	pipeline_status_label.add_theme_font_size_override("font_size", 11)
	pipeline_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pipeline_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage_status_row.add_child(pipeline_status_label)
	variant_select = OptionButton.new()
	variant_select.name = "CompletedSeedVariant"
	variant_select.add_item("No completed variant")
	variant_select.disabled = true
	variant_select.tooltip_text = "Compare one previous completed Blob seed. This is not a generation stage and never starts a job."
	variant_select.item_selected.connect(_set_variant_view)
	stage_status_row.add_child(variant_select)
	feature_inspector_button = Button.new()
	feature_inspector_button.text = "Hide inspector"
	feature_inspector_button.visible = false
	feature_inspector_button.pressed.connect(func():
		_feature_inspector_open = not _feature_inspector_open
		feature_inspector.visible = _feature_inspector_open
		feature_inspector_button.text = "Hide inspector" if _feature_inspector_open else "Show inspector")
	stage_status_row.add_child(feature_inspector_button)
	var viewport_area := Control.new()
	viewport_area.name = "PreviewWithOverlay"
	viewport_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_child(viewport_area)
	viewer = ViewerScript.new()
	viewer.name = "InteractiveViewer"
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_area.add_child(viewer)
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_feature_inspector(viewport_area)
	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 18)
	hint_margin.add_theme_constant_override("margin_top", 10)
	hint_margin.add_theme_constant_override("margin_bottom", 10)
	preview.add_child(hint_margin)
	var hint := Label.new()
	hint.text = "LEFT DRAG  Orbit     •     WHEEL  Zoom     •     MIDDLE / SHIFT + LEFT DRAG  Pan     •     F  Frame"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("8ca29f"))
	hint_margin.add_child(hint)

func _build_dialogs() -> void:
	var default_dir := "user://creatures"
	DirAccess.make_dir_recursive_absolute(default_dir)
	save_dialog = FileDialog.new()
	save_dialog.title = "Save complete alien DNA"
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = PackedStringArray(["*.alien.json ; Alien DNA", "*.json ; JSON"])
	save_dialog.current_dir = ProjectSettings.globalize_path(default_dir)
	save_dialog.file_selected.connect(func(path: String):
		var result := save_creature(path if path.ends_with(".json") else path + ".alien.json")
		if not result.get("ok", false):
			_show_error(result.get("error", "Unable to save creature.")))
	add_child(save_dialog)
	load_dialog = FileDialog.new()
	load_dialog.title = "Load alien DNA"
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.filters = PackedStringArray(["*.json ; Alien DNA / JSON"])
	load_dialog.current_dir = ProjectSettings.globalize_path(default_dir)
	load_dialog.file_selected.connect(func(path: String):
		var result := load_creature(path)
		if not result.get("ok", false):
			_show_error(result.get("error", "Unable to load creature.")))
	add_child(load_dialog)
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Alien Foundry"
	add_child(error_dialog)

func generate_request(request: Dictionary) -> bool:
	if job != null:
		return false
	job = JobScript.new()
	job.pipeline_cache = pipeline_cache
	last_generation_error = {}
	_last_progress_update = 0.0
	var status := job.start(request)
	if status != OK:
		job = null
		_show_error("Could not start generation: " + error_string(status))
		return false
	controls.set_busy(true)
	controls.progress_label.text = "Refreshing appearance; preserving anatomy…" if bool(request.get("materials_only", false)) else "Growing anatomical structure…"
	return true

func cancel_generation() -> void:
	if job != null:
		job.cancel()
		controls.cancel_button.disabled = true
		controls.progress_label.text = "Cancelling safely; keeping the displayed organism…"

func _process(delta: float) -> void:
	if job == null:
		return
	var state := job.snapshot()
	if not _assembly_state.is_empty():
		if state["cancelled"]:
			renderer.abort_assembly(_assembly_state)
			_assembly_state = {}
			_assembly_result = {}
			_end_job()
			controls.progress_label.text = "Cancelled. Displayed organism unchanged."
			generation_cancelled.emit()
			return
		if _handle_assembly_failure():
			return
		var step_started := Time.get_ticks_usec()
		var finished: bool = renderer.step_assembly(_assembly_state)
		if _handle_assembly_failure():
			return
		_assembly_max_step_ms = maxf(_assembly_max_step_ms, (Time.get_ticks_usec() - step_started) / 1000.0)
		var module_count: int = int(_assembly_state.get("module_count", 0))
		var cursor: int = int(_assembly_state.get("cursor", 0))
		var detail_count: int = _assembly_result["mesh_data"].get("detail_meshes", []).size()
		var detail_cursor: int = int(_assembly_state.get("detail_cursor", 0))
		var completion := float(cursor + detail_cursor) / maxf(float(module_count + detail_count), 1.0)
		job.set_progress(0.98 + minf(completion, 1.0) * 0.019, "Assembling anatomical tissue · %d/%d" % [mini(cursor + detail_cursor, module_count + detail_count), module_count + detail_count])
		var assembly_progress := job.snapshot()
		controls.show_progress(float(assembly_progress["progress"]), str(assembly_progress["stage"]), float(assembly_progress["elapsed"]))
		if finished:
			var visual: Node3D = renderer.finish_assembly(_assembly_state)
			if _handle_assembly_failure():
				return
			if not is_instance_valid(visual):
				_fail_assembly({"error": "The completed organism could not be uploaded. The displayed organism is unchanged."})
				return
			var result := _assembly_result
			result["materials_only"] = bool(job.request.get("materials_only", false))
			result["worker_elapsed"] = result.get("elapsed", 0.0)
			result["elapsed"] = job.snapshot()["elapsed"]
			result["assembly_ms"] = (Time.get_ticks_usec() - _assembly_started_usec) / 1000.0
			result["max_assembly_step_ms"] = _assembly_max_step_ms
			_assembly_state = {}
			_assembly_result = {}
			_end_job()
			_present_result(result, visual)
		return
	_last_progress_update += delta
	if _last_progress_update >= 0.1:
		_last_progress_update = 0.0
		controls.show_progress(float(state["progress"]), str(state["stage"]), float(state["elapsed"]))
	if not state["done"]:
		return
	var result := job.finish()
	if result.get("cancelled", false):
		_end_job()
		controls.progress_label.text = "Cancelled. Displayed organism unchanged."
		generation_cancelled.emit()
		return
	if result.has("error"):
		_end_job()
		_show_generation_error(result)
		return
	_assembly_result = result
	_assembly_started_usec = Time.get_ticks_usec()
	_assembly_state = renderer.begin_assembly(result["dna"], result["mesh_data"], result.get("rig_data", {}))
	if _handle_assembly_failure():
		return
	_assembly_max_step_ms = (Time.get_ticks_usec() - _assembly_started_usec) / 1000.0
	controls.show_progress(0.98, "Uploading continuous organic surface", float(job.snapshot()["elapsed"]))

func _handle_assembly_failure() -> bool:
	if _assembly_state.has("error") or bool(_assembly_state.get("aborted", false)) or not is_instance_valid(_assembly_state.get("root")):
		var failure := {"error": str(_assembly_state.get("error", "The organism could not be assembled. The displayed organism is unchanged.")), "error_code": _assembly_state.get("error_code", "assembly_failed"), "triangle_budget": _assembly_state.get("triangle_budget", _assembly_state.get("rig", {}).get("triangle_budget", {}))}
		_fail_assembly(failure)
		return true
	return false

func _fail_assembly(failure: Dictionary) -> void:
	if not _assembly_state.is_empty():
		renderer.abort_assembly(_assembly_state)
	_assembly_state = {}
	_assembly_result = {}
	_end_job()
	_show_generation_error(failure)

func _show_generation_error(failure: Dictionary) -> void:
	last_generation_error = failure.duplicate(true)
	_show_error(str(failure.get("error", "Generation failed. The displayed organism is unchanged.")))

func _end_job() -> void:
	job = null
	controls.set_busy(false)
	if _comparison_active: controls.material_refresh_button.disabled = true

func _present_result(result: Dictionary, visual: Node3D) -> void:
	var dna: Dictionary = result["dna"]
	var mesh_data: Dictionary = result["mesh_data"]
	if not is_instance_valid(visual):
		_show_error("The renderer could not assemble this anatomy. The previous organism is still available.")
		return
	var missing_modules: Array = visual.get_meta("missing_modules", [])
	if not missing_modules.is_empty():
		visual.free()
		_show_error("Required anatomy modules could not be loaded: " + str(missing_modules))
		return
	var bounds: AABB = visual.get_creature_bounds() if visual.has_method("get_creature_bounds") else mesh_data.get("bounds", AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2)))
	var stages: Array = result.get("pipeline_stages", [])
	visual.set_pipeline_stages(stages)
	if not stages.is_empty():
		pipeline_cache.pin_displayed()
	_configure_stage_options(stages)
	var material_available := str(dna.get("type", "")) == "Blob" and not stages.is_empty()
	controls.material_refresh_button.set_meta("available", material_available)
	controls.material_refresh_button.disabled = not material_available
	var camera_state: Dictionary = {}
	if bool(result.get("materials_only", false)):
		if is_instance_valid(viewer.current_creature): visual.transform = viewer.current_creature.transform
		for property: String in ["target", "yaw", "pitch", "distance", "_fit_on_orbit"]:
			camera_state[property] = viewer.get(property)
	_capture_completed_variant(dna)
	viewer.display_creature(visual, bounds)
	_configure_variant_control(dna)
	if not camera_state.is_empty():
		for property: String in camera_state:
			viewer.set(property, camera_state[property])
		viewer._update_camera()
	active_dna = dna.duplicate(true)
	active_stats = mesh_data.get("stats", {}).duplicate(true)
	active_stats["elapsed"] = result.get("elapsed", 0.0)
	active_stats["worker_elapsed"] = result.get("worker_elapsed", result.get("elapsed", 0.0))
	active_stats["assembly_ms"] = result.get("assembly_ms", 0.0)
	active_stats["max_assembly_step_ms"] = result.get("max_assembly_step_ms", 0.0)
	active_stats["triangles"] = int(mesh_data.get("indices", PackedInt32Array()).size() / 3)
	var triangle_counts: Dictionary = visual.get_meta("triangle_counts", {})
	active_stats["body_triangles"] = int(triangle_counts.get("fused_body", active_stats["triangles"]))
	active_stats["detail_triangles"] = int(triangle_counts.get("details", 0))
	active_stats["module_triangles"] = int(triangle_counts.get("modules", 0))
	active_stats["total_triangles"] = int(triangle_counts.get("total", active_stats["body_triangles"] + active_stats["detail_triangles"] + active_stats["module_triangles"]))
	active_stats["triangle_budget"] = visual.get_meta("triangle_budget", {}).duplicate(true)
	active_stats["vertices"] = mesh_data.get("vertices", PackedVector3Array()).size()
	active_stats["nodes"] = dna.get("nodes", []).size()
	var skeleton: Skeleton3D = visual.get_meta("skeleton", null)
	active_stats["bones"] = skeleton.get_bone_count() if skeleton != null else 0
	_apply_view_options()
	var destination := str(result.get("target", "creature"))
	if destination.begins_with("source_"):
		controls.set_source(int(destination.get_slice("_", 1)), dna)
	var prefix := "Source " + ("A" if destination == "source_0" else "B") + " · " if destination.begins_with("source_") else ""
	organism_label.text = "%s%s  /  Seed %d" % [prefix, dna.get("type", "Alien"), dna.get("seed", 0)]
	_current_organism_title = organism_label.text
	stats_label.text = "%s total triangles   ·   %d components   ·   %d bones   ·   %.2fs %s" % [_format_integer(active_stats["total_triangles"]), active_stats["nodes"], active_stats["bones"], active_stats["elapsed"], "material refresh" if bool(result.get("materials_only", false)) else "generation"]
	stats_label.tooltip_text = "Body volume: %s triangles\nTendon ribbons and membranes: %s triangles\nAnatomy modules and accessories: %s triangles\nTotal rendered creature: %s triangles\nDebug guides and collision proxies are excluded." % [_format_integer(active_stats["body_triangles"]), _format_integer(active_stats["detail_triangles"]), _format_integer(active_stats["module_triangles"]), _format_integer(active_stats["total_triangles"])]
	controls.save_button.disabled = false
	controls.show_material_result(dna, result.get("pipeline_report", {}))
	controls.progress_label.text = ("Materials refreshed · %.2fs" if bool(result.get("materials_only", false)) else "Organism ready · %.2fs") % float(result.get("elapsed", 0.0))
	if bool(result.get("materials_only", false)) and stage_select.selected > 0 and ((not visual.is_iterative_pipeline() and stage_select.selected in [1, 2, 3]) or (visual.is_iterative_pipeline() and str(stages[stage_select.selected - 1].get("default_view", "")) == "clay")):
		controls.progress_label.text += " · geometry preview unchanged"
	generation_finished.emit(active_dna, active_stats)

func _build_feature_inspector(parent: Control) -> void:
	feature_inspector = PanelContainer.new()
	feature_inspector.name = "BiologicalFeatureInspector"
	parent.add_child(feature_inspector)
	feature_inspector.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	feature_inspector.offset_left = -348
	feature_inspector.offset_right = -12
	feature_inspector.offset_top = 12
	feature_inspector.offset_bottom = 480
	parent.resized.connect(func(): feature_inspector.offset_bottom = minf(480.0, maxf(180.0, parent.size.y - 12.0)))
	feature_inspector.add_theme_stylebox_override("panel", _style(Color(0.075, 0.105, 0.125, 0.96), 6, 12))
	feature_inspector.visible = false
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feature_inspector.add_child(inspector_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	inspector_scroll.add_child(column)
	var title := Label.new()
	title.text = "BIOLOGICAL FEATURE METADATA"
	title.add_theme_font_size_override("font_size", 12)
	column.add_child(title)
	feature_mode_select = OptionButton.new()
	feature_mode_select.name = "FeatureMapMode"
	feature_mode_select.add_item("Dominant retained category")
	feature_mode_select.add_item("Selected feature influence")
	feature_mode_select.item_selected.connect(func(_index: int): _update_feature_inspection())
	column.add_child(feature_mode_select)
	feature_select = OptionButton.new()
	feature_select.name = "FeatureIdentity"
	feature_select.fit_to_longest_item = false
	feature_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature_select.item_selected.connect(func(_index: int): _update_feature_inspection())
	column.add_child(feature_select)
	feature_descendants = CheckButton.new()
	feature_descendants.name = "FeatureDescendantInfluence"
	feature_descendants.text = "Include declared descendants"
	feature_descendants.tooltip_text = "Adds retained weights of declared child/descendant identities only in the selected influence view. Dominant categories always use direct weights."
	feature_descendants.toggled.connect(func(_enabled: bool): _update_feature_inspection())
	column.add_child(feature_descendants)
	feature_parent_button = Button.new()
	feature_parent_button.name = "InspectFeatureParent"
	feature_parent_button.text = "Inspect parent"
	feature_parent_button.pressed.connect(_select_feature_parent)
	column.add_child(feature_parent_button)
	var legend_title := Label.new()
	legend_title.text = "Category key (some types may be absent)"
	legend_title.add_theme_font_size_override("font_size", 11)
	column.add_child(legend_title)
	var legend := GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 8)
	column.add_child(legend)
	for category: String in Diagnostics.CATEGORY_COLORS:
		var row := HBoxContainer.new()
		legend.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = Diagnostics.category_color(category)
		swatch.custom_minimum_size = Vector2(9, 9)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var label := Label.new()
		label.text = Diagnostics.category_label(category)
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)
	feature_coverage = Label.new()
	feature_coverage.name = "FeatureCoverage"
	feature_coverage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_coverage.add_theme_font_size_override("font_size", 11)
	column.add_child(feature_coverage)
	feature_details = Label.new()
	feature_details.name = "FeatureMetadata"
	feature_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_details.add_theme_font_size_override("font_size", 11)
	column.add_child(feature_details)

func _configure_stage_options(stages: Array) -> void:
	var previous_id := ""
	if stage_select.selected >= 0:
		previous_id = str(stage_select.get_item_metadata(stage_select.selected))
	stage_select.clear()
	stage_select.add_item("Final rigged organism")
	stage_select.set_item_metadata(0, "")
	var restored := 0
	for index: int in range(stages.size()):
		var stage: Dictionary = stages[index]
		var available: bool = bool(stage.get("available", true)) and not stage.get("mesh_data", {}).get("vertices", PackedVector3Array()).is_empty()
		var label: String = str(stage.get("label", stage.get("id", "Unnamed retained stage")))
		stage_select.add_item(label + (" · unavailable" if not available else ""))
		stage_select.set_item_metadata(index + 1, str(stage.get("id", "")))
		stage_select.set_item_disabled(index + 1, not available)
		var reason: String = str(stage.get("unavailable_reason", ""))
		if reason.is_empty(): reason = "Retained geometry is missing. No substitute was generated."
		stage_select.get_popup().set_item_tooltip(index + 1, reason if not available else "Preserved artifact: " + str(stage.get("geometry_artifact_id", stage.get("cache_key", ""))))
		if available and previous_id == str(stage.get("id", "")): restored = index + 1
	stage_select.select(restored)
	stage_select.disabled = stages.is_empty()
	_applied_stage = -99
	_inspector_registry_key = ""
	_feature_artifact = {}

func _apply_view_options() -> void:
	if not is_instance_valid(viewer) or not is_instance_valid(viewer.current_creature): return
	if _comparison_active: return
	var root := viewer.current_creature
	var stage: int = stage_select.selected - 1 if not stage_select.disabled else -1
	if not root.show_pipeline_stage(stage):
		pipeline_status_label.text = "Unavailable: " + str(root.pipeline_stage_error)
		stage_select.select(int(root.pipeline_preview) + 1)
		return
	var changed: bool = _applied_stage != stage
	_applied_stage = stage
	var staged: bool = stage >= 0
	var iterative: bool = root.is_iterative_pipeline()
	var artifact: Dictionary = root.pipeline_stages[stage] if staged else {}
	var map_view: bool = iterative and str(artifact.get("default_view", "")) == "feature_map"
	var always_clay: bool = staged and iterative and int(artifact.get("iteration_index", stage + 1)) <= 4
	var geometry_view: bool = staged and iterative and str(artifact.get("default_view", "clay")) == "clay"
	view_select.disabled = (staged and not iterative) or always_clay or map_view
	view_select.set_item_disabled(0, geometry_view)
	skeleton_toggle.disabled = staged
	anatomy_toggle.disabled = staged
	rig_toggle.disabled = staged
	feature_inspector_button.visible = map_view
	feature_inspector.visible = map_view and _feature_inspector_open
	if changed:
		if not staged: view_select.select(_final_view_choice)
		elif iterative: view_select.select(1 if geometry_view else 0)
		else: view_select.select(0 if stage == 3 else 1)
	var modes := ["textured", "clay", "wire"]
	if staged:
		pipeline_status_label.text = str(artifact.get("label", "Retained stage")) + " · same seed / camera / scale"
		pipeline_status_label.tooltip_text = "Artifact: " + str(artifact.get("geometry_artifact_id", artifact.get("cache_key", "")))
		if iterative: root.set_stage_view_mode(modes[view_select.selected])
		if map_view:
			_populate_feature_inspector(artifact)
			_update_feature_inspection()
		return
	pipeline_status_label.text = "Final rig is available only after all geometry-changing passes."
	pipeline_status_label.tooltip_text = "Stage selection changes retained visibility, never the seed or camera."
	renderer.set_view_mode(root, modes[view_select.selected])
	renderer.set_skeleton_visible(root, skeleton_toggle.button_pressed)
	renderer.set_anatomy_visible(root, anatomy_toggle.button_pressed)
	renderer.set_animation_enabled(root, rig_toggle.button_pressed)

func _populate_feature_inspector(artifact: Dictionary) -> void:
	var blueprint: Dictionary = artifact.get("dna", {}).get("biological_blueprint", {})
	var key: String = str(blueprint.get("organism_id", "")) + ":" + str(artifact.get("geometry_artifact_id", ""))
	if key == _inspector_registry_key: return
	_inspector_registry_key = key
	_feature_artifact = artifact
	var previous_id := ""
	if feature_select.selected >= 0: previous_id = str(feature_select.get_item_metadata(feature_select.selected))
	feature_select.clear()
	var selected := 0
	for feature: Dictionary in Diagnostics.registry(artifact):
		var id: String = str(feature.get("id", ""))
		var index: int = feature_select.item_count
		feature_select.add_item(Diagnostics.feature_label(feature) + " · " + id)
		feature_select.set_item_metadata(index, id)
		if previous_id == id: selected = index
	if feature_select.item_count > 0: feature_select.select(selected)
	feature_select.disabled = feature_select.item_count == 0

func _update_feature_inspection() -> void:
	if not is_instance_valid(viewer) or not is_instance_valid(viewer.current_creature) or feature_select.selected < 0: return
	var id: String = str(feature_select.get_item_metadata(feature_select.selected))
	var lookup: Dictionary = Diagnostics.feature_lookup(_feature_artifact)
	var feature: Dictionary = lookup.get(id, {})
	var influence: bool = feature_mode_select.selected == 1
	feature_descendants.disabled = not influence
	viewer.current_creature.set_feature_inspection("influence" if influence else "categories", id, feature_descendants.button_pressed)
	var parent_id: String = str(feature.get("parent_id", ""))
	feature_parent_button.disabled = parent_id.is_empty() or not lookup.has(parent_id)
	feature_parent_button.tooltip_text = parent_id if not parent_id.is_empty() else "This feature has no parent."
	feature_select.tooltip_text = id
	var report: Dictionary = viewer.current_creature.feature_report()
	feature_coverage.text = "%d vertices · %d overlapping · %d uncovered\n%s\n%s" % [int(report.get("vertices", 0)), int(report.get("overlap_vertices", 0)), int(report.get("uncovered_vertices", 0)), "Direct + declared-descendant weights" if influence and feature_descendants.button_pressed else ("Direct retained feature weights" if influence else "Category color = largest direct retained weight"), Diagnostics.influence_note(_feature_artifact)]
	var realization: Dictionary = Diagnostics.realization(_feature_artifact, id)
	feature_details.text = "ID: %s\nOrganism: %s\nCategory: %s\nParent: %s\nTissue: %s\nCreated in stage: %s\nRealization: %s\nChildren: %s\nGrowth direction: %s\nDetail rules: %s\nMaterial rules: %s\nAnimation rules (stored intent): %s" % [id, str(_feature_artifact.get("dna", {}).get("biological_blueprint", {}).get("organism_id", "")), Diagnostics.feature_label(feature), parent_id if not parent_id.is_empty() else "None", str(feature.get("tissue", "Unspecified")), str(feature.get("created_stage", "")), str(realization.get("status", "Unspecified")), ", ".join(feature.get("children", [])), str(feature.get("growth_direction", [])), JSON.stringify(feature.get("detail_rules", {})), JSON.stringify(feature.get("material_rules", {})), JSON.stringify(feature.get("animation_rules", {}))]

func _select_feature_parent() -> void:
	if feature_select.selected < 0: return
	var id: String = str(feature_select.get_item_metadata(feature_select.selected))
	var parent_id: String = str(Diagnostics.feature_lookup(_feature_artifact).get(id, {}).get("parent_id", ""))
	for i: int in range(feature_select.item_count):
		if str(feature_select.get_item_metadata(i)) == parent_id:
			feature_select.select(i)
			_update_feature_inspection()
			return

func _capture_completed_variant(next_dna: Dictionary) -> void:
	if str(next_dna.get("type", "")) != "Blob":
		_clear_completed_variant()
		return
	if str(active_dna.get("type", "")) != "Blob" or int(active_dna.get("seed", 0)) == int(next_dna.get("seed", 0)) or not is_instance_valid(viewer.current_creature): return
	_clear_completed_variant()
	_variant_root = viewer.current_creature.create_final_comparison()
	_variant_seed = int(active_dna.get("seed", 0))
	_variant_root.visible = false
	viewer.creature_holder.add_child(_variant_root)

func _clear_completed_variant() -> void:
	if is_instance_valid(_variant_root): _variant_root.free()
	_variant_root = null
	_variant_seed = 0

func _configure_variant_control(dna: Dictionary) -> void:
	_comparison_active = false
	variant_select.clear()
	variant_select.add_item("Current seed " + str(dna.get("seed", 0)))
	if is_instance_valid(_variant_root): variant_select.add_item("Variant · completed seed " + str(_variant_seed))
	variant_select.select(0)
	variant_select.disabled = not is_instance_valid(_variant_root)
	variant_select.visible = str(dna.get("type", "")) == "Blob"
	if is_instance_valid(_variant_root): _variant_root.visible = false

func _set_variant_view(index: int) -> void:
	_comparison_active = index == 1 and is_instance_valid(_variant_root)
	if not is_instance_valid(viewer.current_creature): return
	viewer.current_creature.visible = not _comparison_active
	if is_instance_valid(_variant_root): _variant_root.visible = _comparison_active
	stage_select.disabled = _comparison_active or viewer.current_creature.pipeline_stages.is_empty()
	controls.save_button.disabled = _comparison_active or active_dna.is_empty()
	controls.material_refresh_button.disabled = _comparison_active or job != null or not bool(controls.material_refresh_button.get_meta("available", false))
	if _comparison_active:
		viewer.current_creature.set_rig_preview(false)
		for control: BaseButton in [view_select, skeleton_toggle, anatomy_toggle, rig_toggle]: control.disabled = true
		feature_inspector.visible = false
		feature_inspector_button.visible = false
		organism_label.text = "Variant / Blob seed %d · completed final only" % _variant_seed
		pipeline_status_label.text = "Comparison only. Current DNA is seed %d; return to Current to save or inspect stages." % int(active_dna.get("seed", 0))
	else:
		organism_label.text = _current_organism_title
		_apply_view_options()

func _refresh_materials(settings: Dictionary) -> void:
	if _comparison_active: return
	if str(active_dna.get("type", "")) != "Blob" or not active_dna.has("pipeline") or controls.type_select.selected != 0 or job != null:
		return
	var dna: Dictionary = active_dna.duplicate(true)
	if settings.has("material_wetness"):
		dna.settings["material_wetness"] = settings.material_wetness
		dna.materials["wetness"] = settings.material_wetness
	if settings.has(ControlsScript.CAVITY_MATERIAL_SETTING):
		var assignment := str(settings[ControlsScript.CAVITY_MATERIAL_SETTING])
		if assignment.is_empty(): dna.settings.erase(ControlsScript.CAVITY_MATERIAL_SETTING)
		else: dna.settings[ControlsScript.CAVITY_MATERIAL_SETTING] = assignment
	if settings.has(ControlsScript.TISSUE_PROFILE_KEY):
		if not dna.has("metadata"): dna["metadata"] = {}
		var profile := str(settings[ControlsScript.TISSUE_PROFILE_KEY])
		if profile.is_empty(): dna.metadata.erase(ControlsScript.TISSUE_PROFILE_KEY)
		else: dna.metadata[ControlsScript.TISSUE_PROFILE_KEY] = profile
	generate_request({"dna": dna, "target": "creature", "materials_only": true})

func _capture_source(index: int) -> void:
	if active_dna.is_empty():
		_show_error("Generate or load an organism before capturing its anatomy as a source.")
		return
	controls.set_source(index, active_dna)
	controls.progress_label.text = "Displayed full DNA captured as source " + ("A." if index == 0 else "B.")

func _view_source(index: int) -> void:
	if controls.source_dna[index].is_empty():
		generate_request(controls.get_source_request(index))
	else:
		generate_request({"dna": controls.source_dna[index], "target": "source_" + str(index)})

func _open_save() -> void:
	if active_dna.is_empty():
		return
	save_dialog.current_file = "%s_%s.alien.json" % [str(active_dna.get("type", "Alien")).to_lower(), active_dna.get("seed", 0)]
	save_dialog.popup_centered_ratio(0.7)

func save_creature(path: String) -> Dictionary:
	if active_dna.is_empty():
		return {"ok": false, "error": "No generated creature to save."}
	var result := Serializer.save_dna(path, active_dna)
	if result.get("ok", false):
		controls.progress_label.text = "Saved complete DNA · " + path.get_file()
	return result

func load_creature(path: String) -> Dictionary:
	if job != null:
		return {"ok": false, "error": "Cancel the current generation before loading another organism."}
	var result := Serializer.load_dna(path)
	if not result.get("ok", false):
		return result
	controls.apply_dna(result["dna"])
	if not generate_request({"dna": result["dna"], "target": "creature"}):
		return {"ok": false, "error": "Could not start reconstruction."}
	return {"ok": true, "dna": result["dna"]}

func _show_error(message: String) -> void:
	controls.progress_label.text = message
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(520, 180))
	generation_failed.emit(message)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			viewer.reset_camera()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and job != null:
			cancel_generation()
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if not _assembly_state.is_empty():
		renderer.abort_assembly(_assembly_state)
		_assembly_state = {}
		_assembly_result = {}
	if job != null:
		job.shutdown()
		job = null

func _toggle(parent: Node, text: String, hint: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.tooltip_text = hint
	toggle.add_theme_font_size_override("font_size", 12)
	parent.add_child(toggle)
	return toggle

func _format_integer(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result

func _make_theme() -> Theme:
	var output := Theme.new()
	output.default_font_size = 13
	output.set_color("font_color", "Label", Color("dbe5e2"))
	output.set_color("font_color", "Button", Color("dbe5e2"))
	output.set_color("font_hover_color", "Button", Color("f3fff9"))
	output.set_color("font_disabled_color", "Button", Color("657a77"))
	for control_type in ["Button", "OptionButton"]:
		output.set_stylebox("normal", control_type, _style(Color("273a3e"), 5, 9))
		output.set_stylebox("hover", control_type, _style(Color("34524f"), 5, 9))
		output.set_stylebox("pressed", control_type, _style(Color("3d6960"), 5, 9))
		output.set_stylebox("disabled", control_type, _style(Color("202d30"), 5, 9))
		output.set_stylebox("focus", control_type, _outline(Color("7ca89a")))
	output.set_stylebox("normal", "LineEdit", _style(Color("101a1e"), 4, 7))
	output.set_color("font_color", "LineEdit", Color("deebe5"))
	output.set_stylebox("background", "ProgressBar", _style(Color("263639"), 3, 0))
	output.set_stylebox("fill", "ProgressBar", _style(Color("7da996"), 3, 0))
	output.set_stylebox("slider", "HSlider", _style(Color("2b3d40"), 2, 0))
	output.set_stylebox("grabber_area", "HSlider", _style(Color("739b8e"), 2, 0))
	return output

func _style(color: Color, radius_value: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius_value)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

func _outline(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	return box
