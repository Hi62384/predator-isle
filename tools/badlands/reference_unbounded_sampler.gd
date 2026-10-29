extends "res://scripts/badlands_sampler.gd"
## Diagnostic only: no spatial-index, grade or catchment-envelope rejection.
func _tree(index:int,lane:int,side:int)->Dictionary:
	var result:Dictionary=super._tree(index,lane,side).duplicate()
	result.support_bounds=Vector4(-INF,-INF,INF,INF)
	return result
