extends SceneTree
func _initialize()->void:
	if not FileAccess.file_exists("res://tools/snow/baseline/builder.gd"):
		push_error("CPU comparison requires the local pre-Snow snapshot. It is not a runtime dependency.");quit(2);return
	var records:Array=[]
	for baseline in [true,false]:
		var builder=load("res://tools/snow/baseline/builder.gd" if baseline else "res://scripts/terrain_mesh_builder.gd").new()
		builder.settings=load("res://config/world/terrain_settings.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		builder.settings.grass_coverage=0;builder.settings.desert_coverage=0;builder.settings.snow_coverage=100;builder.settings.stone_coverage=0;builder.settings.temperature_enabled=false;builder.profile_build=true
		for spec in [[256.0,128],[256.0,64],[2048.0,16],[16384.0,32]]:
			builder._configure_noise();builder.chunk_size=spec[0]
			for warm in [false,true]:
				var begin:int=Time.get_ticks_usec();var arrays:Array=builder.build(Vector2i.ZERO,spec[1]);var total:float=(Time.get_ticks_usec()-begin)/1000.0
				var item:Dictionary=builder.last_build_profile.duplicate();item.merge({"baseline":baseline,"warm":warm,"span":spec[0],"resolution":spec[1],"total_ms":total,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"height_cache":builder._height_grid_cache.size(),"normal_cache":builder._normal_height_cache.size(),"snow_nodes":0 if baseline else builder._snow._nodes.size()});records.append(item)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/snow/artifacts"))
	var file:=FileAccess.open("res://tools/snow/artifacts/cpu_profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close()
	print("SNOW_CPU_PROFILE ",JSON.stringify(records));quit()
