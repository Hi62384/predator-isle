extends "res://tools/caves/cave_mesher_candidate.gd"
func emit(a:Vector3,b:Vector3,c:Vector3)->void:
	var center:Vector3=(a+b+c)/3
	# Suppress duplicate top terrain outside the designated replacement patch,
	# not genuine subterranean walls/floors. The patch is aligned to64m cells.
	if center.y>=float(field.height.call(center.x,center.z))-.02 and not field.surface_rect.has_point(Vector2(center.x,center.z)):return
	super.emit(a,b,c)
