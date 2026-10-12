extends SceneTree

## Render the four terrain materials and their blends for visual verification.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.18, 0.23, 0.29)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.45
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	world.add_child(sun)
	var material: ShaderMaterial = load("res://materials/terrain.tres").duplicate()
	material.set_shader_parameter("water_level", -100.0)
	# Grass, desert, snow and stone, joined with interpolated climate strips.
	var climates := [Color(1,0,0,0), Color(0,1,0,0), Color(0,0,1,0), Color(0,0,0,1)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for z in range(24):
		for x in range(96):
			for offset: Vector2i in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1)]:
				var px := float(x + offset.x) / 4.0
				var region := clampi(int(px / 6.0), 0, 3)
				var climate: Color = climates[region]
				if region < 3:
					climate = climate.lerp(climates[region + 1], smoothstep(4.5, 6.0, fmod(px,6.0)))
				surface.set_color(climate)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(px - 12.0,0.0,float(z + offset.y)/4.0 - 3.0))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	world.add_child(mesh)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,14,10)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://tools/material_preview.png"
	root.get_texture().get_image().save_png(output)
	print("Saved ", output)
	quit()
