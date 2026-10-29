extends RefCounted
## PRIVATE fixed-grid tetrahedral extraction. Shared global lattice and one
## field at every face prevent load-order seams. No mixed-resolution claims.
const TETS=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var origin:=Vector3.ZERO
var normal_cache:Dictionary={}
var field
func crossing(a:Vector3,b:Vector3,va:float,vb:float)->Vector3:
	# Adjacent tetrahedra visit a shared edge in opposite directions. Canonical
	# endpoint order avoids different floating-point lerp roundoff at the seam.
	if a.x>b.x or (a.x==b.x and (a.y>b.y or (a.y==b.y and a.z>b.z))):
		var point:Vector3=a;a=b;b=point;var value:float=va;va=vb;vb=value
	# Shared binary submillimetre lattice survives the subsequent64m local
	# transform exactly here. Weld before testing area,not by deleting tiny
	# positive triangles independently on either side of a topological join.
	return (a.lerp(b,clampf(va/(va-vb),0,1))*4096).round()/4096
func emit(a:Vector3,b:Vector3,c:Vector3)->void:
	var cross_value:Vector3=(c-a).cross(b-a)
	# A positive-area sliver still closes part of the surface. An arbitrary
	# area cutoff opened tiny holes near exact lattice intersections.
	if cross_value.length_squared()==0:return
	var expected:Vector3=field.normal((a+b+c)/3)
	if cross_value.dot(expected)<0:var swap:Vector3=b;b=c;c=swap;cross_value=-cross_value
	var face:Vector3=cross_value.normalized()
	for point:Vector3 in [a,b,c]:
		var normal:Vector3
		if normal_cache.has(point):normal=normal_cache[point]
		else:
			normal=field.normal(point)
			if normal_cache.size()<65536:normal_cache[point]=normal
		if normal.length_squared()<.5 or normal.dot(face)<.15:normal=face
		vertices.append(point-origin);normals.append(normal);colors.append(Color(.38,.35,.30,1))
func tetra(points:PackedVector3Array,values:PackedFloat32Array,indices:Array)->void:
	var inside:Array[int]=[];var outside:Array[int]=[]
	for index:int in indices:
		if values[index]<0:inside.append(index)
		else:outside.append(index)
	if inside.is_empty() or outside.is_empty():return
	if inside.size()==1 or outside.size()==1:
		var single:int=inside[0] if inside.size()==1 else outside[0];var others:Array[int]=outside if inside.size()==1 else inside;var cuts:=PackedVector3Array()
		for other:int in others:cuts.append(crossing(points[single],points[other],values[single],values[other]))
		emit(cuts[0],cuts[1],cuts[2]);return
	var cuts:=PackedVector3Array()
	for pair:Array in [[inside[0],outside[0]],[inside[0],outside[1]],[inside[1],outside[1]],[inside[1],outside[0]]]:cuts.append(crossing(points[pair[0]],points[pair[1]],values[pair[0]],values[pair[1]]))
	emit(cuts[0],cuts[1],cuts[2]);emit(cuts[0],cuts[2],cuts[3])
func build(volume,coordinate:Vector3i,step_metres:float=2)->Array:
	vertices.clear();normals.clear();colors.clear();normal_cache.clear();field=volume;origin=Vector3(coordinate)*64
	if step_metres not in [1.0,2.0,4.0] or not field.has_chunk(coordinate):return []
	var count:int=roundi(64/step_metres);var row:int=count+1;var plane:int=row*row;var points:=PackedVector3Array();var values:=PackedFloat32Array();points.resize(row*plane);values.resize(row*plane)
	for z in range(row):
		for y in range(row):
			for x in range(row):
				var index:int=x+row*y+plane*z;var point:Vector3=origin+Vector3(x,y,z)*step_metres;points[index]=point;values[index]=field.sample(point)
	for z in range(count):
		for y in range(count):
			for x in range(count):
				var base:int=x+row*y+plane*z;var indices:Array[int]=[base,base+1,base+1+row,base+row,base+plane,base+1+plane,base+1+row+plane,base+row+plane];var cube_points:=PackedVector3Array();var cube_values:=PackedFloat32Array();var any_air:bool=false;var any_rock:bool=false
				for index:int in indices:cube_points.append(points[index]);cube_values.append(values[index]);any_air=any_air or values[index]<0;any_rock=any_rock or values[index]>=0
				if not any_air or not any_rock:continue
				for indices_tet:Array in TETS:tetra(cube_points,cube_values,indices_tet)
	if vertices.is_empty():return []
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;return arrays
