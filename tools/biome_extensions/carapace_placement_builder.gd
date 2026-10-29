extends "res://scripts/terrain_mesh_builder.gd"
## Admission-policy fixture only; no production terrain is flattened/tilted.
var test_origin:=Vector2(-65536,131072)
var test_grade:=Vector2.ZERO
var cliff:bool=false
var flooded:bool=false
var owner:float=1.0
func _get_height(x:float,z:float,publish_controls:bool=true)->float:
	super._get_height(x,z,publish_controls)
	_last_extras[7]=Vector4(owner,0,.4,1)
	var offset:=Vector2(x,z)-test_origin
	return 1000+test_grade.dot(offset)+(200 if cliff and offset.x>0 else 0)
func get_water_surface_height(x:float,z:float)->float:
	return _get_height(x,z)+10 if flooded else 0.0
