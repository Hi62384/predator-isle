extends SceneTree
func _initialize()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	var sun:DirectionalLight3D=scene.get_node("Sun")
	var direction:Vector3=-sun.transform.basis.z.normalized()
	print("SUN_EMISSION_DIRECTION ",direction," surface_to_light=",-direction)
	scene.free()
	quit(0 if direction.y<0 else 1)
