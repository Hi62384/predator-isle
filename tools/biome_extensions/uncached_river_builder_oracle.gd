extends "res://scripts/terrain_mesh_builder.gd"
## Reference only: no alternate river formula or hand-built terrain.
func _configure_noise()->void:
	super._configure_noise()
	if _mountain!=null:
		_mountain=preload("res://tools/biome_extensions/uncached_river_mountain_oracle.gd").new();_mountain.configure(settings.mountain,world_seed,self)
func _grass_river_center(x:float,lane:int,spacing:float)->float:
	_river_cache.clear();return super._grass_river_center(x,lane,spacing)
func _river_column(x:float,lane:int,spacing:float)->Vector3:
	_river_columns.clear();return super._river_column(x,lane,spacing)
