extends SceneTree
## Diagnostic only: does accelerated empty/primitive physics reproduce the
## observed job-capacity warning without terrain samplers/meshes/streaming?
func _initialize()->void:call_deferred("run")
func run()->void:
	assert(OS.get_cmdline_user_args().has("fixed-step-run"))
	var records:Array=[]
	for model in range(3):
		var stage:=Node3D.new();root.add_child(stage)
		var floor:=StaticBody3D.new();var ground:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,2,40);ground.shape=box;floor.add_child(ground);floor.position.y=-1;stage.add_child(floor)
		var body:=CharacterBody3D.new();var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.4;shape.shape=capsule;body.add_child(shape);stage.add_child(body);body.position=Vector3(0,.95,0);body.floor_snap_length=.6
		await physics_frame;await physics_frame
		var lowest:float=body.position.y;var start:int=Time.get_ticks_usec()
		for frame in range(14000):
			await physics_frame
			body.velocity=Vector3(0,0 if body.is_on_floor() else body.velocity.y-9.8/60,0);body.move_and_slide();lowest=minf(lowest,body.position.y)
		assert(body.is_on_floor() and lowest>.89)
		records.append({"model":model,"frames":14000,"lowest_y":lowest,"wall_seconds":(Time.get_ticks_usec()-start)/1000000.0});print("JOLT_MINIMAL_MODEL ",records[-1])
		stage.queue_free();await process_frame;await process_frame
	var sources:Dictionary={}
	for path:String in ["res://tools/biome_extensions/check_jolt_capacity_minimal.gd","res://project.godot"]:sources[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://tools/biome_extensions/artifacts/check_jolt_capacity_minimal.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"failures":[],"source_sha256":sources,"models":records,"engine":Engine.get_version_info(),"scope":"Three sequential primitive box/capsule models,42000 accelerated physics frames,zero terrain or streaming code. Raw engine/stderr logs must be inspected separately for WARN_PRINT_ONCE; numeric completion alone says nothing about the warning,cause or runtime-performance acceptance. No production behavior/settings changed."},"  "));quit()
