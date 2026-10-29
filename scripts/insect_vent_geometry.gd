extends RefCounted
## Thick, blind ventilation recess in an existing earthen mound summit.
## Not a traversable burrow, terrain portal or infinite cave.
static func admitted_depth(builder,anchor:Vector3,width:float,height:float,phase:float,requested:float)->float:
	if requested<=0:return 0
	var center:Vector3=anchor+Vector3(width*.16*sin(2+phase),height,width*.12)
	var floor_y:float=center.y-requested
	# Keep the whole small recess above canonical ground/water. No terrain hole
	# is cut, and steep/custom relief may reject an otherwise eligible summit.
	for z:int in [-1,0,1]:
		for x:int in [-1,0,1]:
			var p:Vector3=center+Vector3(x*width*.12,0,z*width*.12)
			if maxf(builder._get_height(p.x,p.z),builder.get_water_surface_height(p.x,p.z))>floor_y-2:return 0
	return requested
static func emit(g,outer:PackedVector3Array,depth:float,color:Color)->void:
	assert(outer.size()>=3 and depth>0)
	var center:=Vector3.ZERO
	for p:Vector3 in outer:center+=p/float(outer.size())
	var inner:=PackedVector3Array();var bottom:=PackedVector3Array()
	for p:Vector3 in outer:
		var rim:Vector3=center+(p-center)*.62
		inner.append(rim)
		bottom.append(center+(p-center)*.46-Vector3.UP*depth)
	var floor_center:Vector3=center-Vector3.UP*depth
	for i in range(outer.size()):
		var j:int=(i+1)%outer.size()
		# Rim faces sky, lining faces inward, sealed floor faces the recess.
		# Positions are shared exactly; no overlapping cap hides the opening.
		g.quad(outer[i],outer[j],inner[j],inner[i],color)
		g.quad(inner[i],inner[j],bottom[j],bottom[i],color)
		g.triangle(bottom[i],bottom[j],floor_center,color)
