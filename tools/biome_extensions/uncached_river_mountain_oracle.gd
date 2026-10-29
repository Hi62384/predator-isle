extends "res://scripts/mountain_sampler.gd"
## Reference only: execute the actual production function with no memo hits.
func _carrier(x:float,lane:int)->Vector3:
	_carriers.clear();return super._carrier(x,lane)
