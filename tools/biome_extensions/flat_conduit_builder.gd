extends "res://scripts/terrain_mesh_builder.gd"
## Isolated geometry fixture; production canonical fields are never flattened.
func _get_height(_x:float,_z:float,_publish_controls:bool=true)->float:return 0.0
func _sample_normal_height(_x:float,_z:float)->float:return 0.0
