extends "res://scripts/biome_extension_structures.gd"
## Experimental only. Integer nested grids may share the exact same canonical
## sample. Fractional custom grids retain the original per-grid cache key.
var sample_misses:int=0
var cache_hits:int=0
func _grid_height(builder,x:int,z:int,index:int,step:float)->float:
	var cacheable:bool=absi(x)<=2147483647 and absi(z)<=2147483647
	var key:=Vector3i.ZERO
	if cacheable:
		if step==floorf(step) and step>=1 and step<=2147483647:
			var wx:int=x*int(step);var wz:int=z*int(step)
			key=Vector3i(wx,wz,-1) if absi(wx)<=2147483647 and absi(wz)<=2147483647 else Vector3i(x,z,index)
		else:key=Vector3i(x,z,index)
		if _support_heights.has(key):cache_hits+=1;return _support_heights[key]
	sample_misses+=1
	var h:float=builder._sample_normal_height(float(x)*step,float(z)*step)
	if cacheable:
		if _support_heights.size()>=16384:_support_heights.clear()
		_support_heights[key]=h
	return h
