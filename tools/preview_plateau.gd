extends SceneTree

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	for frame in range(20): await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.resize(1440,roundi(1440.0*image.get_height()/image.get_width()),Image.INTERPOLATE_LANCZOS)
	image.save_png("res://tools/plateau_"+name+".png")

func run() -> void:
	var b=load("res://scripts/terrain_mesh_builder.gd").new()
	b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	b.settings.grass_coverage=100
	b.settings.desert_coverage=0
	b.settings.snow_coverage=0
	b.settings.stone_coverage=0
	b._configure_noise()
	var top:=Vector3.ZERO
	var facing:=Vector3.FORWARD
	var best:=-INF
	for z in range(-30,31):
		for x in range(-30,31):
			var p:=Vector3(x*160.0,0,z*160.0)
			p.y=b._get_height(p.x,p.z)
			if absf(p.y-b.settings.grass_plateau_height)>12: continue
			for dir in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
				var near_height: float=b._get_height(p.x+dir.x*24,p.z+dir.z*24)
				var foot_height: float=b._get_height(p.x+dir.x*180,p.z+dir.z*180)
				if absf(near_height-p.y)>6: continue
				var score: float=p.y-foot_height-p.length()*0.004
				if score>best: best=score;top=p;facing=dir
	print("PLATEAU_TEST top=",top," outward=",facing," score=",best)
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	var camera: Camera3D=scene.get_node("FreeCamera")
	var terrain=scene.get_node("Terrain")
	camera.set_process(false)
	scene.get_node("Interface").hide()
	camera.position=top+facing*650+Vector3(170,250,90)
	camera.look_at(top-Vector3(0,60,0))
	var start:=Time.get_ticks_msec()
	while terrain.committed_revision!=terrain.partition_revision and Time.get_ticks_msec()-start<45000: await process_frame
	await capture("overview")
	camera.position=top+facing*350+Vector3(60,25,30)
	camera.look_at(top-Vector3(0,70,0))
	for frame in range(160): await process_frame
	await capture("face")
	terrain._terrain_material.set_shader_parameter("diagnostic_surface",1)
	await capture("flat_lit")
	terrain._terrain_material.set_shader_parameter("diagnostic_surface",0)
	terrain._terrain_material.set_shader_parameter("debug_view",3)
	await capture("unlit")
	terrain._terrain_material.set_shader_parameter("debug_view",0)
	camera.position=top+facing*1900+Vector3(400,620,300)
	camera.look_at(top)
	for frame in range(180): await process_frame
	await capture("distant")
	var ground:=top-facing*70.0
	ground.y=b._get_height(ground.x,ground.z)+1.8
	camera.position=ground
	camera.look_at(ground+Vector3(18,-1.1,12))
	for frame in range(120): await process_frame
	await capture("ground")
	print("PLATEAU_GROUND camera=",ground)
	print("PLATEAU_RENDER_COMPLETE")
	scene.queue_free()
	await process_frame
	quit()
