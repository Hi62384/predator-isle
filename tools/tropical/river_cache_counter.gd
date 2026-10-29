extends "res://scripts/tropical_sampler.gd"
var raw_evaluations:int=0
func _raw(p:Vector2)->PackedFloat64Array:
	raw_evaluations+=1
	return super._raw(p)
