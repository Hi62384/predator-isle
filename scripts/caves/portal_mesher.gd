extends "res://scripts/caves/mesher.gd"
func emit(a:Vector3,b:Vector3,c:Vector3)->void:
	var center:Vector3=(a+b+c)/3;var column:=Vector2i(floori(center.x/64),floori(center.z/64))
	# Complete surface columns are replaced atomically. The one-column halo
	# around each exposed entry guarantees that a real mouth is not clipped at
	# this outer boundary. Closed cave roofs have at least8m rock cover.
	if not field.surface_columns.has(column) and center.y>=field.surface_height(Vector2(center.x,center.z))-4:return
	super.emit(a,b,c)
