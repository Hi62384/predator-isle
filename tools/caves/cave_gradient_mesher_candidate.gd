extends "res://tools/caves/cave_mesher_candidate.gd"
## PRIVATE topological orientation repair. Winding follows the tetrahedron's
## sign case BEFORE welding; a submillimetre weld must not reverse a sliver
## independently of its neighbors. Shading keeps true field vertex normals.
const CASE_FLIP=[false,false,true,false,false,true,false,false,true,false,true,true,false,false,true,false]
var case_flip:bool=false
func tetra(points:PackedVector3Array,values:PackedFloat32Array,indices:Array)->void:
	var mask:int=0
	for i in range(4):
		if values[indices[i]]<0:mask|=1<<i
	if mask==0 or mask==15:return
	var p:Vector3=points[indices[0]];var a:Vector3=points[indices[1]]-p;var b:Vector3=points[indices[2]]-p;var c:Vector3=points[indices[3]]-p;var reflected:bool=a.dot(b.cross(c))<0
	case_flip=bool(CASE_FLIP[mask])!=reflected
	super.tetra(points,values,indices)
func emit(a:Vector3,b:Vector3,c:Vector3)->void:
	var cross_value:Vector3=(c-a).cross(b-a)
	if cross_value.length_squared()==0:return
	if case_flip:var swap:Vector3=b;b=c;c=swap;cross_value=-cross_value
	var face:Vector3=cross_value.normalized()
	for point:Vector3 in [a,b,c]:
		var normal:Vector3
		if normal_cache.has(point):normal=normal_cache[point]
		else:
			normal=field.normal(point)
			if normal_cache.size()<65536:normal_cache[point]=normal
		if normal.length_squared()<.5 or normal.dot(face)<.15:normal=face
		vertices.append(point-origin);normals.append(normal);colors.append(Color(.38,.35,.30,1))
