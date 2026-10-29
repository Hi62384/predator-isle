extends "res://scripts/caves/portal_field.gd"
## Ordinary buried cells do not need to resample/extract the entire overlying
## surface. Explicit portal transactions continue to use the combined field.
func sample(point:Vector3)->float:
	if not point.is_finite():return FAR
	for component:float in [point.x,point.y,point.z]:
		if absf(component)>2147483646.0*BIN_METRES:return FAR
	var key:Vector3i=bin_cell(point)
	if not bins.has(key):return FAR
	return evaluate(point,bins[key])
