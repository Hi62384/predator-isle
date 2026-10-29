extends SceneTree
## Zero-field lifecycle test. A worker callback is replaced with explicit failures;
## success is never fabricated and the real pipeline build is never called.
const App = preload("res://alien_foundry/standalone/PortableBlob232.gd")
const Data = preload("res://alien_foundry/standalone/PortableBlobData232.gd")
var checks: int = 0
var failures: Array[String] = []
var output: String = ""
var mock_calls: int = 0
var lock: Mutex = Mutex.new()
var done: bool = false
var watchdog: int = 0

func _initialize() -> void:
	watchdog = Time.get_ticks_msec()
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec()-watchdog > 20000:
		failures.append("Smoke exceeded its 20-second internal watchdog")
		_finish()
	return false

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func _mock_build(_request: Dictionary, controls: RefCounted) -> Dictionary:
	lock.lock(); mock_calls += 1; lock.unlock()
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 250 and not controls.is_cancelled():
		controls.set_progress(0.2,"Synthetic lifecycle callback; no generation")
		OS.delay_msec(5)
	return {"artifact":{"cancelled":true} if controls.is_cancelled() else {"error":"Synthetic worker rejection"},"persistence":{"ok":false,"error":"Synthetic: no disk result"}}

func _wait_idle(app: PortableBlob232App) -> bool:
	var start: int = Time.get_ticks_msec()
	while app.get("_thread") != null and Time.get_ticks_msec()-start < 3000:
		await process_frame
	return app.get("_thread") == null

func _new_app() -> PortableBlob232App:
	var app: PortableBlob232App = App.new()
	app.set_meta("qa_keep_tree_running",true)
	app.build_function = _mock_build
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return app

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--output-dir" or args[1].is_empty() or DirAccess.dir_exists_absolute(args[1]) or FileAccess.file_exists(args[1]):
		failures.append("Requires --output-dir fresh nonexistent directory"); _finish(); return
	output = args[1]
	if DirAccess.make_dir_recursive_absolute(output) != OK: failures.append("Could not create smoke output"); output=""; _finish(); return
	var app: PortableBlob232App = _new_app()
	await process_frame; await process_frame
	check(app._startup_preview_loaded,"Startup loads bundled exact preview")
	check(app._last_good_mesh_id != 0,"Startup creates one visible body")
	check(app._thread == null and mock_calls == 0,"Startup never builds")
	check(not is_instance_valid(app.legacy),"Existing lab is lazy")
	var initial_id: int = app._last_good_mesh_id
	check(app.origin_label.text.contains("not a new generation"),"Initial provenance label remains truthful")
	check(not Data.validate_mesh({}).ok,"Malformed mesh rejected")
	app.viewer.zoom(0.88); app.viewer.orbit(Vector2(20,10)); app.viewer.reset_camera()
	check(app.viewer.camera.position.is_finite(),"Orbit/zoom/reset stay finite without generation")
	var frame_key: InputEventKey = InputEventKey.new(); frame_key.keycode = KEY_F; frame_key.pressed = true
	app.viewer.orbit(Vector2(30,10)); app.viewer.grab_focus(); root.push_input(frame_key)
	await process_frame
	check(is_equal_approx(app.viewer.yaw,app.viewer.DEFAULT_YAW),"F frames current tab before lab creation")
	app.tabs.current_tab = 1
	await process_frame
	check(is_instance_valid(app.legacy),"Existing lab instantiates on request")
	check(app.legacy.get_meta("skip_autogenerate",false) and app.legacy.job == null,"Existing lab does not autogenerate")
	check(app.legacy.is_processing_unhandled_key_input(),"Visible lab keyboard input remains enabled")
	var legacy_id: int = app.legacy.get_instance_id()
	app.tabs.current_tab = 0; app.tabs.current_tab = 1
	await process_frame
	check(app.legacy.get_instance_id() == legacy_id,"Repeated tab opening preserves the same lab")
	app.tabs.current_tab = 0
	check(not app.legacy.is_processing_unhandled_key_input(),"Hidden lab keyboard input is disabled")
	app.legacy.viewer.orbit(Vector2(40,0)); var hidden_yaw: float = app.legacy.viewer.yaw
	app.viewer.orbit(Vector2(30,10)); app.viewer.grab_focus(); root.push_input(frame_key)
	await process_frame
	check(is_equal_approx(app.viewer.yaw,app.viewer.DEFAULT_YAW),"F frames current tab after lab creation")
	check(is_equal_approx(app.legacy.viewer.yaw,hidden_yaw),"Current-tab F never resets hidden lab camera")
	check(app.start_generation(),"Explicit build callback starts")
	check(not app.start_generation(),"Duplicate request rejected")
	check(app.generate_button.disabled and app.tabs.is_tab_disabled(1),"Concurrent lab/build start disabled")
	app.cancel_generation(); app.cancel_generation()
	check(app.cancel_button.disabled,"Repeated cancel is idempotent")
	check(await _wait_idle(app),"Cancelled worker completes asynchronously")
	check(app._last_good_mesh_id == initial_id,"Cancellation preserves last good body")
	check(not app.generate_button.disabled,"Cancel restores generation control")
	check(not app.tabs.is_tab_disabled(1),"Cancel restores lab tab")
	check(app.start_generation(),"Retry after cancellation starts fresh callback")
	check(await _wait_idle(app),"Rejected worker completes asynchronously")
	check(app._last_good_mesh_id == initial_id,"Failure preserves last good body")
	check(app.status_label.text.contains("Synthetic worker rejection"),"Failure reason visible")
	app._consume_result(null,false)
	check(app._last_good_mesh_id == initial_id,"Missing result preserves last good body")
	check(app.start_generation(),"Third callback starts before close")
	app.request_quit(); app.request_quit()
	check(app._pending_quit and not app.start_generation(),"Close is idempotent and blocks new work")
	check(await _wait_idle(app),"Close cooperatively completes worker")
	await process_frame
	check(app._quit_ready,"Close reaches safe idle completion")
	app.queue_free(); await process_frame
	var reopened: PortableBlob232App = _new_app()
	await process_frame; await process_frame
	check(reopened._startup_preview_loaded and reopened._thread == null,"New app instance reopens into retained preview")
	check(not reopened._pending_quit and not is_instance_valid(reopened.legacy),"Reopen has no stale quit/lab state")
	reopened.request_quit(); check(reopened._quit_ready,"Idle close completes immediately")
	reopened.queue_free(); await process_frame
	check(mock_calls == 3,"Exactly three synthetic worker callbacks, no real build")
	_finish()

func _finish() -> void:
	if done: return
	done = true
	var report: Dictionary = {"status":"PASS" if failures.is_empty() else "REJECTED","suite":"portable_blob232_zero_field_lifecycle","checks":checks,"failures":failures,"synthetic_worker_calls":mock_calls,"real_generation_calls":0,"field_calls":0,"runtime_platform":OS.get_name(),"Windows_runtime_tested":OS.get_name()=="Windows","scope":"Retained preview, packed resources and mocked failure/cancellation/reopen lifecycle. Real generation was not invoked."}
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output.path_join("smoke_report.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"\t",true,true)); file.flush(); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
