extends SceneTree
func _initialize()->void:
	var scene=load("res://scenes/main.tscn").instantiate();var sun:DirectionalLight3D=scene.get_node("Sun")
	var rays:Vector3=-sun.basis.z
	print("SCENE_SUN_RAY_DIRECTION ",rays," rotation=",sun.rotation_degrees)
	assert(rays.y< -.1,"Approved Sun correction must cast rays downward")
	scene.free();print("SCENE_LIGHTING_PASS unchanged, downward Sun");quit()
