extends SceneTree
func _initialize() -> void:
	var b=load("res://scripts/terrain_mesh_builder.gd").new()
	b._configure_noise()
	for method in ["_island_mask","_biome_weights","_grass_sample","_get_height"]:
		var start:=Time.get_ticks_usec()
		for z in range(100):
			for x in range(100): b.call(method,x*4.0,z*4.0)
		print(method," 10000 samples ms=",(Time.get_ticks_usec()-start)/1000.0)
	print("HUD coordinate weights ",b._biome_weights(864.7,7959.1))
	quit()
