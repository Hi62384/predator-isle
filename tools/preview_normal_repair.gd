extends SceneTree

func _initialize() -> void: call_deferred("run")

func capture(scene: Node,label: String,mode: int) -> void:
	var terrain=scene.get_node("Terrain")
	terrain._terrain_material.set_shader_parameter("debug_view",mode)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.resize(1440,roundi(1440.0*image.get_height()/image.get_width()),Image.INTERPOLATE_LANCZOS)
	image.save_png("res://tools/normal_repair_"+label+".png")

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.get_node("Terrain").grass_preview=true
	root.add_child(scene)
	scene.get_node("Interface").hide()
	var camera=scene.get_node("FreeCamera")
	camera.set_process(false)
	var terrain=scene.get_node("Terrain")
	camera.position=Vector3(5670,260,3840)
	camera.look_at(Vector3(5600,247.3867,3840))
	terrain._refresh_visible_chunks()
	var started:=Time.get_ticks_msec()
	while not terrain._pending_chunks.is_empty() or not terrain._jobs.is_empty() or not terrain._ready_chunks.is_empty():
		await process_frame
		assert(Time.get_ticks_msec()-started<60000,"Normal preview timeout")
	await capture(scene,"shaded",0)
	await capture(scene,"geometry_lighting",7)
	await capture(scene,"vertex_normals",4)
	await capture(scene,"mapped_normals",8)
	await capture(scene,"unlit",3)
	# Reproduce the reported failure without changing geometry or lighting.
	terrain._terrain_material.set_shader_parameter("palette_color",null)
	terrain._terrain_material.set_shader_parameter("palette_normal",null)
	await capture(scene,"unbound_reproduction",0)
	print("Captured identical camera: shaded / geometry-only / both normal views / unlit / unbound reproduction")
	scene.queue_free()
	await process_frame
	quit()
