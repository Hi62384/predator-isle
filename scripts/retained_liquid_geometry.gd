extends RefCounted
## Shared numeric definition of the EXISTING finite surface pool. The terrain
## renderer and underground heat witnesses use the same rim/level/clip math.
## No mesh resources,Nodes,new water source or heat-transfer simulation.
static func measure(builder,point:Vector2,radius:float)->Dictionary:
	if not point.is_finite() or not is_finite(radius) or radius<=0:return {"retained":false}
	var center:float=builder._get_height(point.x,point.y);var rim:float=INF
	for index in range(32):
		var q:Vector2=point+Vector2(cos(index*TAU/32),sin(index*TAU/32))*radius;rim=minf(rim,builder._get_height(q.x,q.y))
	var level:float=minf(center+maxf(2,(rim-center)*.35),rim-.5)
	return {"retained":is_finite(center) and is_finite(rim) and is_finite(level) and not (level<center+.5 or level<builder.water_level+2),"surface_y":level,"bed_y":center,"rim_y":rim}
static func clipped_polygon(builder,a:Vector3,b:Vector3,c:Vector3,level:float)->PackedVector3Array:
	var polygon:Array[Vector3]=[a,b,c];var clipped:=PackedVector3Array()
	for index in range(3):
		var p:Vector3=polygon[index];var q:Vector3=polygon[(index+1)%3];var p_inside:bool=p.y<level-.05;var q_inside:bool=q.y<level-.05
		if p_inside:clipped.append(Vector3(p.x,level,p.z))
		if p_inside!=q_inside:
			var inside:Vector3=p if p_inside else q;var outside:Vector3=q if p_inside else p
			for iteration in range(12):
				var mid:Vector3=(inside+outside)*.5
				if builder._get_height(mid.x,mid.z)<level-.05:inside=mid
				else:outside=mid
			clipped.append(Vector3(inside.x,level,inside.z))
	return clipped
