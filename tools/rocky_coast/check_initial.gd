extends SceneTree
func _initialize()->void:
	var b=preload("res://scripts/terrain_mesh_builder.gd").new();b.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL);b.settings.tropical_coverage=0;b.settings.beaches_enabled=false;b.settings.rocky_coast.coverage=1;b._configure_noise()
	var h:float=b._get_height(10000,10000);assert(is_finite(h))
	print("COAST_INITIAL ",h," ",b._last_coast);quit()
