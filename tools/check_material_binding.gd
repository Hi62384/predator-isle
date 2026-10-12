extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var source=load("res://materials/terrain.tres")
	for name in ["palette_color","palette_normal"]:
		var array: Texture2DArray=source.get_shader_parameter(name)
		assert(array!=null and array.get_layers()==9,"Missing terrain palette: "+name)
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	var terrain=scene.get_node("Terrain")
	for name in ["palette_color","palette_normal"]:
		assert(terrain._terrain_material.get_shader_parameter(name).get_layers()==9)
	print("PASS saved and live terrain bind both nine-layer arrays")
	scene.queue_free()
	await process_frame
	quit()
