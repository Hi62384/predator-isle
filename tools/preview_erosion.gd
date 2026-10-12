extends SceneTree

func _initialize() -> void: call_deferred("run")

func capture(scene: Node, name: String, focus: Vector3, offset: Vector3) -> void:
	var camera=scene.get_node("FreeCamera")
	var terrain=scene.get_node("Terrain")
	camera.position=focus+offset
	camera.look_at(focus)
	terrain._refresh_visible_chunks()
	var start:=Time.get_ticks_msec()
	while not terrain._pending_chunks.is_empty() or not terrain._jobs.is_empty() or not terrain._ready_chunks.is_empty():
		await process_frame
		if Time.get_ticks_msec()-start>45000: push_error("preview timeout");quit(1);return
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.resize(1440,roundi(1440.0*image.get_height()/image.get_width()),Image.INTERPOLATE_LANCZOS)
	image.save_png("res://tools/erosion_"+name+".png")
	print(name," focus=",focus," camera=",camera.position)

func run() -> void:
	var b=load("res://scripts/terrain_mesh_builder.gd").new()
	b.settings=load("res://terrain_settings.tres").duplicate(true)
	b.settings.grass_coverage=100;b.settings.desert_coverage=0;b.settings.snow_coverage=0;b.settings.stone_coverage=0
	b._configure_noise()
	var uncut=load("res://scripts/terrain_mesh_builder.gd").new()
	uncut.settings=b.settings.duplicate(true);uncut.settings.grass_plateau_erosion=0;uncut._configure_noise()
	var cliff:=Vector3.ZERO
	var cut:=Vector3.ZERO
	var peak:=Vector3.ZERO
	var cliff_score:=-INF
	var cut_score:=-INF
	var cliff_offset:=Vector3(450,220,350)
	for z in range(-35,36):
		for x in range(-35,36):
			var p:=Vector3(x*160.0,0,z*160.0)
			p.y=b._get_height(p.x,p.z)
			var geo: Vector3=b._last_geology
			if p.y>peak.y: peak=p
			if geo.y>0.6 and p.y>20:
				var depth: float=uncut._get_height(p.x,p.z)-p.y
				var score:=depth-p.length()*0.005
				if score>cut_score: cut_score=score;cut=p
			if geo.z>0.3 and p.y>90:
				for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
					var foot: float=b._get_height(p.x+direction.x*210,p.z+direction.z*210)
					if foot<12 or foot>p.y-40: continue
					var score: float=p.y-foot-p.length()*0.003
					if score>cliff_score: cliff_score=score;cliff=p;cliff_offset=direction*440+Vector3(55,145,30)
	assert(cliff_score>-INF and cut_score>15,"No suitable geological test sites")
	print("CUT depth score=",cut_score)
	var scene=load("res://main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("FreeCamera").set_process(false)
	scene.get_node("Interface").hide()
	await capture(scene,"inland_cliff",cliff,cliff_offset)
	await capture(scene,"cut",cut,Vector3(-520,750,-600))
	await capture(scene,"ridges",peak,Vector3(1200,680,1100))
	await capture(scene,"aerial",Vector3(1800,180,1200),Vector3(1500,1300,1700))
	var ground:=Vector3(0,0,230)
	ground.y=b._get_height(ground.x,ground.z)
	await capture(scene,"ground",ground+Vector3(18,0.7,12),Vector3(-18,1.1,-12))
	scene.get_node("Terrain")._terrain_material.set_shader_parameter("debug_view",6)
	await capture(scene,"geology",cliff,cliff_offset)
	scene.queue_free()
	await process_frame
	quit()
