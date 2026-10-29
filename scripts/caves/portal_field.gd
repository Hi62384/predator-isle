extends "res://scripts/caves/field.gd"
## One surface/cave air union. The same volume removes exposed tunnel roofs
## and produces native opening geometry; the committed parent mask is separate.
var surface_columns:Dictionary={}
var surface_limits:Dictionary={}
var top_height:Callable
## Ordinary cells extract only cave air. Only an atomic surface transaction
## needs the more expensive overlying terrain/surface-air union.
var include_surface_air:bool=true
func cave_sample(point:Vector3)->float:return super.sample(point)
func surface_height(point:Vector2)->float:
	return float(top_height.call(point.x,point.y)) if top_height.is_valid() else float(height.call(point.x,point.y))
func sample(point:Vector3)->float:
	if not include_surface_air:return super.sample(point)
	if not point.is_finite():return FAR
	if absf(point.x)>2147483646.0*BIN_METRES or absf(point.y)>2147483646.0*BIN_METRES or absf(point.z)>2147483646.0*BIN_METRES:return FAR
	var terrain:float=surface_height(Vector2(point.x,point.z))
	if not is_finite(terrain):return FAR
	return minf(super.sample(point),terrain-point.y)
func has_chunk(key:Vector3i)->bool:
	if super.has_chunk(key):return true
	var column:=Vector2i(key.x,key.z)
	if not surface_columns.has(column) or not surface_limits.has(column):return false
	var limits:Vector2=surface_limits[column]
	return key.y>=floori(limits.x/64) and key.y<=floori(limits.y/64)
func measure_surface(columns:Dictionary)->bool:
	surface_columns=columns.duplicate();surface_limits.clear()
	for key:Vector2i in surface_columns:
		var minimum:float=INF;var maximum:float=-INF
		# Exact extraction lattice,not a sparse height survey that can miss a
		# sharp surface peak. Two metres guard both vertical cube endpoints.
		for z in range(33):
			for x in range(33):
				var h:float=surface_height(Vector2(key)*64+Vector2(x,z)*2)
				if not is_finite(h):surface_columns.clear();surface_limits.clear();return false
				minimum=minf(minimum,h);maximum=maxf(maximum,h)
		surface_limits[key]=Vector2(minimum-2,maximum+2)
	return true
