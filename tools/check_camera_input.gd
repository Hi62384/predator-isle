extends SceneTree
var checks:int=0
var failures:Array[String]=[]
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func motion(delta:Vector2)->void:
	var event:=InputEventMouseMotion.new();event.relative=delta;event.position=Vector2(160,100);root.push_input(event,true)
func key(code:Key)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true)
func run()->void:
	var scene:=Node3D.new();root.add_child(scene);var ui:=CanvasLayer.new();scene.add_child(ui);var panel:=PanelContainer.new();panel.size=Vector2(1000,700);ui.add_child(panel);var label:=Label.new();label.text="Read-only terrain diagnostic";panel.add_child(label)
	var workshop=load("res://scripts/blobs/blob_workshop.gd").new();workshop.name="BlobWorkshop";scene.add_child(workshop)
	var camera=load("res://scripts/free_camera.gd").new();camera.debug_label=label;scene.add_child(camera);camera.set_process(false);camera.current=true;await process_frame
	verify(not panel.visible and not camera.debug_overlay_visible,"Debug overlay hidden by default")
	var hint:CanvasLayer=workshop.get_child(0);verify(not hint.visible,"Main-world workshop debug hint hidden by default")
	verify(workshop.status.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Workshop hint does not intercept pointer input")
	verify(panel.mouse_filter==Control.MOUSE_FILTER_IGNORE and label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Read-only diagnostic controls never block mouse events")
	var blocker:=Control.new();blocker.size=Vector2(1000,700);blocker.mouse_filter=Control.MOUSE_FILTER_STOP;ui.add_child(blocker)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;var before:Vector3=camera.rotation_degrees;motion(Vector2(80,25))
	verify(absf(camera.rotation_degrees.y-before.y)>1 and absf(camera.rotation_degrees.x-before.x)>1,"Captured mouse look works even under a GUI control consuming mouse input")
	blocker.hide();key(KEY_QUOTELEFT);verify(panel.visible and camera.debug_overlay_visible,"Backtick enables the diagnostic overlay on demand")
	verify(hint.visible,"Backtick reveals the workshop hint with terrain diagnostics")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;before=camera.rotation_degrees;motion(Vector2(-40,-10));verify(absf(camera.rotation_degrees.y-before.y)>1,"Mouse look still works with diagnostics visible")
	key(KEY_ESCAPE);verify(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Escape releases pointer before GUI handling")
	before=camera.rotation_degrees;motion(Vector2(100,50));verify(camera.rotation_degrees==before,"Released pointer does not rotate camera")
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(160,100);root.push_input(click,true);verify(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Clicking the noninteractive overlay recaptures mouse")
	key(KEY_QUOTELEFT);verify(not panel.visible,"Backtick hides the entire panel again")
	verify(not hint.visible,"Backtick hides the workshop hint again")
	motion(Vector2(0,10000));verify(absf(camera.rotation_degrees.x)<=89,"Pitch retains its safe clamp")
	camera._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);verify(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Focus loss releases mouse safely")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;scene.queue_free();await process_frame;print("CAMERA_INPUT ",checks," checks failures=",failures);quit(0 if failures.is_empty() else 1)
