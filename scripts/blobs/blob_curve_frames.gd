extends RefCounted
## Bounded cubic Hermite curves and parallel-transport frames, shared by binding,
## collision proxies, the CPU deformation oracle and shader equations.
static func point(points:PackedVector3Array,t:float)->Vector3:
	var u:=clampf(t,0,1)*float(points.size()-1); var i:=mini(int(u),points.size()-2); var f:=u-i
	var a:=points[maxi(i-1,0)]; var b:=points[i]; var c:=points[i+1]; var d:=points[mini(i+2,points.size()-1)]
	var length:=b.distance_to(c)
	var m0:=((c-a)*.5).limit_length(length*.75)
	var m1:=((d-b)*.5).limit_length(length*.75)
	return b*(2*f*f*f-3*f*f+1)+m0*(f*f*f-2*f*f+f)+c*(-2*f*f*f+3*f*f)+m1*(f*f*f-f*f)
static func tangent(points:PackedVector3Array,t:float)->Vector3:
	return (point(points,minf(1,t+.001))-point(points,maxf(0,t-.001))).normalized()
static func normals(points:PackedVector3Array,seed_axis:Vector3=Vector3.RIGHT)->PackedVector3Array:
	var result:=PackedVector3Array(); var normal:=seed_axis
	for i in points.size():
		var t:=float(i)/float(points.size()-1); var axis:=tangent(points,t)
		normal-=axis*normal.dot(axis)
		if normal.length_squared()<.01: normal=axis.cross(Vector3.UP if absf(axis.y)<.9 else Vector3.RIGHT)
		normal=normal.normalized(); result.append(normal)
	return result
static func frame(points:PackedVector3Array,normals_array:PackedVector3Array,t:float)->Basis:
	var u:=clampf(t,0,1)*float(points.size()-1); var i:=mini(int(u),points.size()-2)
	var tangent_vector:=tangent(points,t)
	var n:=normals_array[i].lerp(normals_array[i+1],u-i); n=(n-tangent_vector*n.dot(tangent_vector)).normalized()
	if n.length_squared()<.01: n=tangent_vector.cross(Vector3.UP if absf(tangent_vector.y)<.9 else Vector3.RIGHT).normalized()
	return Basis(n,tangent_vector.cross(n).normalized(),tangent_vector)
