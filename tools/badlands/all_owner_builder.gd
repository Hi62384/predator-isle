extends "res://scripts/terrain_mesh_builder.gd"
## Test-only transport stressor. Actual ownership cells contain at most four owners.
## Eight simultaneous owners exercise every legacy/new bank together.
func _biome_weights(_x:float,_z:float)->Vector4:
	_jungle_weight=.125;_mountain_weight=.125;_tropical_weight=.125;_badlands_weight=.125
	return Vector4(.125,.125,.125,.125)
