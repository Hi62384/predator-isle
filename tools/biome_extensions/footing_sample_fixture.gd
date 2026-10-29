extends RefCounted
## Finite, varying cache-key fixture, including coordinates far beyond the
## production noise domain. It does not replace any real terrain acceptance.
func _sample_normal_height(x:float,z:float)->float:
	return x*.125+z*.375+sin(x*.001)*.25
