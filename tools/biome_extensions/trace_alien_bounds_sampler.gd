extends "res://tools/biome_extensions/reference_bounded_distance_experiment.gd"
## Diagnostic overrides add overhead; never benchmark this class.
var bound_tests:int=0
var projections:int=0
func bounded_segment_squared(p:Vector2,a:Vector2,b:Vector2,bounds:Vector4,limit:float)->float:
	bound_tests+=1
	return super.bounded_segment_squared(p,a,b,bounds,limit)
func segment_squared(p:Vector2,a:Vector2,b:Vector2)->float:
	projections+=1
	return super.segment_squared(p,a,b)
