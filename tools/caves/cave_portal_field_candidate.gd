extends "res://tools/caves/cave_field_candidate.gd"
## PRIVATE surface/cave union. Above-ground air removes the tunnel's exposed
## roof instead of rendering an opaque roof or a decorative dark entrance.
## The finite preview patch is planning only;sample remains one common field.
var surface_rect:=Rect2()
var surface_min_y:float=120
var surface_max_y:float=120
func sample(point:Vector3)->float:
	if not point.is_finite():return FAR
	for value:float in [point.x,point.y,point.z]:
		if absf(value)>2147483646.0*BIN_METRES:return FAR
	var terrain:float=height.call(point.x,point.z)
	if not is_finite(terrain):return FAR
	return minf(super.sample(point),terrain-point.y)
func has_chunk(key:Vector3i)->bool:
	if super.has_chunk(key):return true
	var bounds:=Rect2(Vector2(key.x,key.z)*64,Vector2.ONE*64)
	return bounds.intersects(surface_rect) and key.y>=floori(surface_min_y/64) and key.y<=floori(surface_max_y/64)
