extends RefCounted
## The existing2m loading margin surrounds the whole capsule,not merely
## six faces of its centre cell. At a corner its head/radius can contact a
## diagonal cell's frontier even while every face neighbour is resident.
static func ready(point:Vector3,resident:Dictionary,wanted:Dictionary)->bool:
	if not point.is_finite():return false
	var key:=Vector3i(floori(point.x/64),floori(point.y/64),floori(point.z/64))
	if not resident.has(key):return false
	var local:Vector3=point-Vector3(key)*64;var first:=Vector3i.ZERO;var last:=Vector3i.ZERO
	for axis in range(3):
		if local[axis]<=2:first[axis]=-1
		if 64-local[axis]<=2:last[axis]=1
	for z in range(first.z,last.z+1):
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var neighbor:Vector3i=key+Vector3i(x,y,z)
				if wanted.has(neighbor) and not resident.has(neighbor):return false
	return true
