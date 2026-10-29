extends RefCounted
var slope:float=0
var intercept:float=0
func get_height_at(p:Vector3)->float:return slope*p.x+intercept
