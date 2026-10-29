extends SceneTree
var failures:Array[String]=[]
func _initialize()->void:
	var checks:int=0
	for coverage in [0.0,50.0,100.0]:
		var scene=load("res://scenes/main.tscn").instantiate()
		var terrain=scene.get_node("Terrain")
		terrain._settings_snapshot=terrain.settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		var config:TerrainSettings=terrain._settings_snapshot
		config.grass_coverage=100.0-coverage;config.desert_coverage=coverage;config.snow_coverage=0;config.stone_coverage=0;config.temperature_enabled=false
		config.desert.far_mesh_metres=256.0;terrain._configure_noise()
		terrain._target_chunk=Vector2i.ZERO
		if terrain._tile_resolution(Vector3i.ZERO)!=maxi(terrain.chunk_resolution,terrain.close_resolution):failures.append("Camera-tile density reduced")
		if terrain._tile_resolution(Vector3i(2,2,0))!=terrain.chunk_resolution:failures.append("Near-tile density reduced")
		for level in range(1,7):
			for i in range(16):
				var key:=Vector3i(i-8,i*2-16,level)
				var span:float=terrain.chunk_size*float(1<<level)
				var box:=Rect2(Vector2(key.x,key.y)*span,Vector2.ONE*span)
				var pure:bool=terrain._sampler.is_pure_desert_rect(box)
				var resolution:int=terrain._tile_resolution(key)
				if pure:
					if resolution>64 or resolution<terrain.middle_resolution:failures.append("Unbounded/reduced parent density")
					for z in range(9):
						for x in range(9):
							var p:Vector2=box.position+box.size*Vector2(x,z)/8.0
							if terrain._sampler._biome_weights(p.x,p.y)!=Vector4(0,1,0,0):failures.append("False Desert certificate")
				else:
					var previous:int=maxi(32,terrain.middle_resolution) if level==1 else terrain.middle_resolution
					if resolution!=previous:failures.append("Grass/mixed parent density changed")
				checks+=1
		config.desert.far_mesh_metres=0
		if terrain._tile_resolution(Vector3i(0,0,6))!=terrain.middle_resolution:failures.append("Legacy parent switch failed")
		scene.free()
	FileAccess.open("res://tools/desert/far_mesh_budget_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Close density retained; only certified pure Desert parents refine, maximum64, legacy toggle works."},"\t"))
	for failure in failures:push_error(failure)
	print("Far mesh budget: ",checks," checks; failures ",failures.size());quit(0 if failures.is_empty() else 1)
