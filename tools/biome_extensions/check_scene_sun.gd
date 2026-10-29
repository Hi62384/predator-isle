extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate();var sun:DirectionalLight3D=scene.get_node("Sun")
	var emission:Vector3=-sun.transform.basis.z.normalized()
	assert(emission.y<-.1,"Actual saved sun emits downward; do not infer row/column layout from serialized scalar groups")
	var report:Dictionary={"passed":true,"emission_direction":emission,"upward_plane_direct_light_dot":Vector3.UP.dot(-emission),"main_scene_sha256":FileAccess.get_sha256("res://scenes/main.tscn"),"main_scene_changed":false,"scope":"Actual instantiated saved DirectionalLight3D basis, not scalar-text matrix interpretation. Sun already emits downward; no lighting/sky/fog edit is warranted."}
	report["source_sha256"]={"res://scenes/main.tscn":FileAccess.get_sha256("res://scenes/main.tscn"),"res://tools/biome_extensions/check_scene_sun.gd":FileAccess.get_sha256("res://tools/biome_extensions/check_scene_sun.gd")}
	FileAccess.open("res://tools/biome_extensions/artifacts/check_scene_sun.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SCENE_SUN_DIRECTION ",report)
	scene.free();quit()
