extends SceneTree
func _initialize()->void:
	for pair:Vector2i in [Vector2i(9,4)]:
		var f:=FileAccess.open("res://.godot/blob_validation_v4_release/model_%02d.bin"%pair.x,FileAccess.READ);var data:Dictionary=f.get_var(false);f.close();print(pair," ",data.features[pair.y].feature_type)
	quit()
