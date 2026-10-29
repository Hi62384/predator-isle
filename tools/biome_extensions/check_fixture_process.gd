extends SceneTree
var allocation:=PackedByteArray()
func _initialize()->void:call_deferred("run")
func run()->void:
	var hold:bool=OS.get_cmdline_user_args().has("hold_allocate")
	if hold:
		allocation.resize(384*1024*1024);allocation.fill(17)
		print("FIXTURE_ALLOCATED bytes=",allocation.size()," actual_engine_pid=",OS.get_process_id())
		for frame in range(200):await process_frame;OS.delay_msec(10)
		push_error("Expected predeclared 256MiB watchdog did not stop the actual allocated engine");quit(1);return
	var native:bool=DisplayServer.get_name()!="headless";var sampled:Color=Color.BLACK
	if native:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(320,240));root.size=Vector2i(320,240)
		var rectangle:=ColorRect.new();rectangle.color=Color(.125,.5,.75);root.add_child(rectangle);rectangle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for frame in range(12):await process_frame
		await RenderingServer.frame_post_draw;var frame_image:Image=root.get_texture().get_image();sampled=frame_image.get_pixel(frame_image.get_width()/2,frame_image.get_height()/2)
		print("NATIVE_FIXTURE visible=",root.visible," window_size=",root.size," visible_rect=",root.get_visible_rect()," rectangle_size=",rectangle.size," image_size=",frame_image.get_size()," center=",sampled)
		assert(frame_image.save_png("res://tools/biome_extensions/artifacts/check_fixture_process_native.png")==OK)
		assert(sampled.g>.2 and sampled.b>.4,"Actual native frame, not just a launched process")
	else:
		for frame in range(80):await process_frame;OS.delay_msec(10)
	var label:String="native" if native else "headless"
	FileAccess.open("res://tools/biome_extensions/artifacts/check_fixture_process_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"actual_engine_pid":OS.get_process_id(),"executable":OS.get_executable_path(),"native_frame":native,"sampled_pixel":sampled,"engine_version":Engine.get_version_info().string,"source_sha256":{"res://tools/biome_extensions/check_fixture_process.gd":FileAccess.get_sha256("res://tools/biome_extensions/check_fixture_process.gd"),"res://tools/biome_extensions/run_test.ps1":FileAccess.get_sha256("res://tools/biome_extensions/run_test.ps1")},"scope":"Direct engine executable process identity and native/headless lifecycle smoke. Parent watchdog PID must match this engine PID; native mode draws a real Canvas frame. No game, terrain, material-colour or performance acceptance."},"  "))
	print("FIXTURE_PROCESS ",label," actual_engine_pid=",OS.get_process_id()," executable=",OS.get_executable_path());quit()
