extends "res://tools/preview_erosion.gd"

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Path preview requires rendering: run without --headless.")
		quit(1)
		return
	print("PATH_PREVIEW_LOADING_SCENE")
	var scene=load("res://scenes/main.tscn").instantiate()
	print("PATH_PREVIEW_SCENE_INSTANTIATED")
	var terrain=scene.get_node("Terrain")
	terrain.grass_preview=true
	root.add_child(scene)
	print("PATH_PREVIEW_SCENE_READY")
	var camera=scene.get_node("FreeCamera")
	camera.set_process(false)
	scene.get_node("Interface").hide()
	terrain.ground_material_settings.debug_mode=3
	terrain._refresh_ground_settings()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1600
	await capture(scene,"path_locator",Vector3(1800,10,1200),Vector3(0,1000,1))
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image()
	var chosen:=Vector2.ZERO
	var best:=INF
	for y in range(50,img.get_height()-50,3):
		for x in range(50,img.get_width()-50,3):
			var color=img.get_pixel(x,y)
			var score=Vector2(x,y).distance_squared_to(Vector2(img.get_width(),img.get_height())*0.5)
			if color.r>0.65 and absf(color.r-color.g)<0.03 and score<best:
				var screen := Vector2(x,y)*root.get_visible_rect().size/Vector2(img.get_width(),img.get_height())
				var probe: Vector3 = camera.project_ray_origin(screen)
				var h: float = terrain._sampler._get_height(probe.x,probe.z)
				if h<3 or absf(terrain._sampler._get_height(probe.x+4,probe.z)-h)>0.25 or absf(terrain._sampler._get_height(probe.x,probe.z+4)-h)>0.25: continue
				best=score
				chosen=Vector2(x,y)
	assert(best<INF,"No visible path in locator")
	chosen*=root.get_visible_rect().size/Vector2(img.get_width(),img.get_height())
	var p: Vector3=camera.project_ray_origin(chosen)
	p.y=terrain._sampler._get_height(p.x,p.z)
	terrain.ground_material_settings.debug_mode=0
	terrain._refresh_ground_settings()
	await capture(scene,"path_network",Vector3(1800,10,1200),Vector3(0,1000,1))
	camera.size=55
	await capture(scene,"path_detail",p,Vector3(0,80,0.1))
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	await capture(scene,"path_surface",p,Vector3(-4,2.2,-5))
	await capture(scene,"path_route",p,Vector3(100,140,160))
	scene.queue_free()
	await process_frame
	quit()
