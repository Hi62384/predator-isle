class_name PortableBlob232App
extends Control
## Additive portable front door. Startup is retained clay, never a hidden build.
const Data = preload("res://alien_foundry/standalone/PortableBlobData232.gd")
const Controls = preload("res://alien_foundry/standalone/PortableBuildControls232.gd")
const Viewer = preload("res://alien_foundry/scripts/ui/ViewerController.gd")
const LEGACY_SCENE = preload("res://alien_foundry/scenes/Main.tscn")
var tabs: TabContainer
var viewer: ViewerController
var legacy_host: VBoxContainer
var legacy: AlienFoundryApplication
var generate_button: Button
var cancel_button: Button
var status_label: Label
var origin_label: Label
var progress: ProgressBar
var details_label: Label
var _thread: Thread
var _controls: RefCounted
var _pending_quit: bool = false
var _quit_ready: bool = false
var _quit_overlay: ColorRect
var _last_good_mesh_id: int = 0
var _startup_preview_loaded: bool = false
var build_function: Callable

func _ready() -> void:
	get_tree().auto_accept_quit = false
	if not build_function.is_valid(): build_function = Data.run_build
	_build_ui()
	if not get_meta("qa_skip_initial_preview",false): call_deferred("_load_initial_preview")

func _label(text: String, font_size: int = 14) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("172027")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	margin.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new(); column.add_child(heading)
	var title: Label = _label("PREDATOR ISLE  /  BLOB 232",22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_child(title)
	_button(heading,"About / Licenses",_show_about)
	tabs = TabContainer.new(); tabs.name = "ProgramTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var current: VBoxContainer = VBoxContainer.new(); current.name = "Current Blob 232"
	current.add_theme_constant_override("separation",8); tabs.add_child(current)
	var notice: Label = _label("EXPERIMENTAL CLAY • Fixed seed 22 / Stage 5 • No final materials or rig",15)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; current.add_child(notice)
	origin_label = _label("Loading the bundled preview…")
	origin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; current.add_child(origin_label)
	var toolbar: HBoxContainer = HBoxContainer.new(); current.add_child(toolbar)
	generate_button = _button(toolbar,"Generate current blob",func(): start_generation())
	generate_button.tooltip_text = "One real 232 build of seed 22. Reference took about 2 minutes; hardware varies. No arbitrary seeds."
	cancel_button = _button(toolbar,"Cancel build",cancel_generation); cancel_button.disabled = true
	_button(toolbar,"Reset view",func(): viewer.reset_camera())
	_button(toolbar,"Zoom +",func(): viewer.zoom(0.88))
	_button(toolbar,"Zoom −",func(): viewer.zoom(1.0/0.88))
	var rotate: CheckButton = CheckButton.new(); rotate.text = "Auto rotate"
	rotate.toggled.connect(func(enabled: bool): viewer.set_auto_rotate(enabled)); toolbar.add_child(rotate)
	viewer = Viewer.new(); viewer.name = "CurrentBlobViewer"
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer.custom_minimum_size = Vector2(500,320)
	current.add_child(viewer)
	viewer.viewport_3d.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var help: Label = _label("Drag to rotate  •  Wheel to zoom  •  Middle-drag to pan  •  F to frame",13)
	current.add_child(help)
	progress = ProgressBar.new(); progress.show_percentage = false; progress.max_value = 1.0
	progress.custom_minimum_size.y = 6; current.add_child(progress)
	status_label = _label("No generation running. The bundled preview requires no setup.")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; current.add_child(status_label)
	details_label = _label("Generation cancellation is cooperative. A 15-minute timeout requests cancellation; it is not an OS memory/time limit.",12)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; current.add_child(details_label)
	legacy_host = VBoxContainer.new(); legacy_host.name = "Existing Generator Lab"
	tabs.add_child(legacy_host)
	var legacy_notice: Label = _label("Earlier generator interface, separate from the fixed 232 pipeline. Its controls do not edit the current 232 specimen.",14)
	legacy_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; legacy_host.add_child(legacy_notice)
	tabs.tab_changed.connect(_on_tab_changed)

func _load_initial_preview() -> void:
	var loaded: Dictionary = Data.load_preview()
	if not loaded.ok:
		status_label.text = "Preview could not load: " + str(loaded.error)
		origin_label.text = "Bundled preview unavailable. No replacement geometry was invented."
		return
	_display_mesh(loaded)
	_startup_preview_loaded = true
	origin_label.text = "Bundled 229 clay mesh: recorded exact geometry parity with 232. This is not a new generation."

func _display_mesh(checked: Dictionary) -> void:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = checked.mesh.vertices
	arrays[Mesh.ARRAY_NORMAL] = checked.mesh.normals
	arrays[Mesh.ARRAY_INDEX] = checked.mesh.indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.57,0.59,0.56)
	material.roughness = 0.88; material.metallic_specular = 0.22
	var body: MeshInstance3D = MeshInstance3D.new(); body.name = "FixedBlobClay"
	body.mesh = mesh; body.material_override = material
	viewer.display_creature(body,checked.bounds)
	_last_good_mesh_id = body.get_instance_id()

func _legacy_busy() -> bool:
	return is_instance_valid(legacy) and (legacy.get("job") != null or not legacy.get("_assembly_state").is_empty())

func _on_tab_changed(index: int) -> void:
	if _pending_quit: return
	if index == 1 and not is_instance_valid(legacy):
		legacy = LEGACY_SCENE.instantiate()
		legacy.set_meta("skip_autogenerate",true)
		legacy.size_flags_vertical = Control.SIZE_EXPAND_FILL
		legacy_host.add_child(legacy)
		legacy.viewer.viewport_3d.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if is_instance_valid(legacy): legacy.set_process_unhandled_key_input(index == 1)

func _unhandled_key_input(event: InputEvent) -> void:
	if _pending_quit or tabs == null or tabs.current_tab != 0: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		viewer.reset_camera()
		get_viewport().set_input_as_handled()

func start_generation() -> bool:
	if _pending_quit or _thread != null: return false
	if _legacy_busy():
		status_label.text = "The existing generator lab is still working. Finish or cancel that build first."
		return false
	var declared: Dictionary = Data.generation_request()
	if not declared.ok:
		status_label.text = "Cannot generate: " + str(declared.error)
		return false
	_controls = Controls.new()
	_thread = Thread.new()
	var error: Error = _thread.start(build_function.bind(declared.request,_controls))
	if error != OK:
		_thread = null; _controls = null
		status_label.text = "Could not start the build worker. Preview unchanged."
		return false
	generate_button.disabled = true; cancel_button.disabled = false
	tabs.set_tab_disabled(1,true)
	progress.value = 0.0
	status_label.text = "Building seed 22 once. You can keep rotating the preview."
	return true

func cancel_generation() -> void:
	if _thread == null or _controls == null: return
	_controls.cancel()
	cancel_button.disabled = true
	status_label.text = "Cancellation requested. The preview stays usable while the current bounded operation finishes."

func _process(_delta: float) -> void:
	if _thread != null:
		if _thread.is_alive():
			var state: Dictionary = _controls.snapshot()
			progress.value = state.progress
			var prefix: String = "Closing after cancellation. " if _pending_quit else ""
			status_label.text = prefix + ("Cancellation requested; waiting for a safe stopping point" if state.cancelled or state.timed_out else str(state.message)) + " · %.0f s" % (float(state.elapsed_ms)/1000.0)
		else:
			var outcome: Variant = _thread.wait_to_finish()
			var cancelled: bool = _controls.is_cancelled()
			_thread = null; _controls = null
			_consume_result(outcome,cancelled)
			cancel_button.disabled = true
			tabs.set_tab_disabled(1,_pending_quit)
	generate_button.disabled = _pending_quit or _thread != null or _legacy_busy()
	if _pending_quit and _thread == null and not _legacy_busy(): _finish_quit()

func _consume_result(outcome: Variant, cancelled: bool) -> void:
	if cancelled:
		status_label.text = "Build cancelled or timed out. Last good preview retained."
		return
	if not outcome is Dictionary or not outcome.get("artifact") is Dictionary:
		status_label.text = "Build stopped without a valid result. Last good preview retained."
		return
	var artifact: Dictionary = outcome.artifact
	if artifact.get("cancelled",false) or artifact.has("error") or artifact.get("format") != Data.Pipeline.ARTIFACT_FORMAT:
		status_label.text = "Build did not complete: " + str(artifact.get("error","Cancelled or rejected")) + ". Preview unchanged."
		return
	var checked: Dictionary = Data.validate_mesh(artifact.get("mesh_data"))
	if not checked.ok:
		status_label.text = str(checked.error)
		return
	_display_mesh(checked)
	progress.value = 1.0
	origin_label.text = "Fresh fixed seed 22 / Stage 5 build. Geometry matches the reference; independent full qualification was not rerun."
	var saved: Dictionary = outcome.get("persistence",{})
	status_label.text = "Build complete. Clay only; no new rig or final materials."
	details_label.text = "Saved result: " + str(saved.path) if saved.get("ok",false) else "Save failed: " + str(saved.get("error","Unknown storage error")) + ". The new preview is still available."
	details_label.tooltip_text = details_label.text

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: request_quit()

func request_quit() -> void:
	if _pending_quit: return
	_pending_quit = true
	get_viewport().gui_release_focus()
	if is_instance_valid(legacy): legacy.set_process_unhandled_key_input(false)
	cancel_generation()
	if is_instance_valid(legacy): legacy.cancel_generation()
	if _thread == null and not _legacy_busy(): _finish_quit(); return
	# Intercept clicks without stopping either worker's main-thread completion.
	_quit_overlay = ColorRect.new(); _quit_overlay.color = Color(0.05,0.07,0.09,0.96)
	_quit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_quit_overlay)
	var label: Label = _label("Closing safely…\nCancellation has been requested. Finishing the current bounded operation before exiting.",18)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quit_overlay.add_child(label)

func _finish_quit() -> void:
	if _quit_ready: return
	_quit_ready = true
	if not get_meta("qa_keep_tree_running",false): get_tree().quit()

func _exit_tree() -> void:
	if _thread != null:
		if _controls != null: _controls.cancel()
		if _thread.is_started(): _thread.wait_to_finish()
		_thread = null

func _show_about() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Experimental Blob 232 / About and licenses"
	dialog.exclusive = false
	var text: TextEdit = TextEdit.new(); text.editable = false
	text.custom_minimum_size = Vector2(760,480)
	text.text = "Portable experimental source checkpoint.\n\nCurrent tab: fixed seed 22, Stage 5, unrigged clay only. Initial display uses retained 229 geometry with recorded exact physical parity to 232. Generate runs the real 232 API; it is not seed variation. The existing lab is a separate, older interface. Rough cavity rims and unfinished materials remain.\n\nRuns are saved in the application's per-user data folder. Generation cancellation is cooperative; timeout is not an OS resource limiter.\n\nGodot Engine license:\n" + FileAccess.get_file_as_string("res://alien_foundry/standalone/licenses/GODOT_LICENSE.txt") + "\n\nThird-party notices:\n" + FileAccess.get_file_as_string("res://alien_foundry/standalone/licenses/GODOT_COPYRIGHT.txt")
	dialog.add_child(text); add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
