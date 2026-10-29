extends RefCounted
## Shared fixed-grid tetrahedral extraction with pre-weld sign-case winding. Shared global lattice and one
## field at every face prevent load-order seams. No mixed-resolution claims.
const TETS=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colors:=PackedColorArray()
var origin:=Vector3.ZERO
var normal_cache:Dictionary={}
var field
var precise_shores:Array=[]
## Optional numeric reuse only;does not change any extracted corner/normal.
var capture_boundary_values:bool=false
var boundary_values:Array=[]
const CASE_FLIP=[false,false,true,false,false,true,false,false,true,false,true,true,false,false,true,false]
var case_flip:bool=false
func crossing(a:Vector3,b:Vector3,va:float,vb:float)->Vector3:
	# Adjacent tetrahedra visit a shared edge in opposite directions. Canonical
	# endpoint order avoids different floating-point lerp roundoff at the seam.
	if a.x>b.x or (a.x==b.x and (a.y>b.y or (a.y==b.y and a.z>b.z))):
		var point:Vector3=a;a=b;b=point;var value:float=va;va=vb;vb=value
	# Shared binary submillimetre lattice survives the subsequent64m local
	# transform exactly here. Weld before testing area,not by deleting tiny
	# positive triangles independently on either side of a topological join.
	var original:Vector3=(a.lerp(b,clampf(va/(va-vb),0,1))*4096).round()/4096
	for shore:Dictionary in precise_shores:
		if Vector2(original.x-shore.center.x,original.z-shore.center.z).length()>shore.radius+4 or absf(original.y-shore.center.y)>6:continue
		# Refine the SAME canonical signed edge,not a second extraction grid.
		# A min/max union can be far from linear near a joined bank/bed rim.
		var low:Vector3=a;var high:Vector3=b;var inside:bool=va<0
		for iteration in range(12):
			var mid:Vector3=(low+high)*.5
			if (field.sample(mid)<0)==inside:low=mid
			else:high=mid
		return (((low+high)*.5)*4096).round()/4096
	return original
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

func tetra(points:PackedVector3Array,values:PackedFloat32Array,indices:Array)->void:
	var mask:int=0
	for i in range(4):
		if values[indices[i]]<0:mask|=1<<i
	if mask==0 or mask==15:return
	var p:Vector3=points[indices[0]];var a:Vector3=points[indices[1]]-p;var b:Vector3=points[indices[2]]-p;var c:Vector3=points[indices[3]]-p;var reflected:bool=a.dot(b.cross(c))<0
	case_flip=bool(CASE_FLIP[mask])!=reflected
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
	vertices.clear();normals.clear();colors.clear();normal_cache.clear();boundary_values=[];field=volume;origin=Vector3(coordinate)*64
	var shores=field.get("precise_shores");precise_shores=shores if shores is Array else []
	if step_metres not in [1.0,2.0,4.0] or not field.has_chunk(coordinate):return []
	var count:int=roundi(64/step_metres);var row:int=count+1;var plane:int=row*row;var points:=PackedVector3Array();var values:=PackedFloat32Array();points.resize(row*plane);values.resize(row*plane)
	for z in range(row):
		for y in range(row):
			for x in range(row):
				var index:int=x+row*y+plane*z;var point:Vector3=origin+Vector3(x,y,z)*step_metres;points[index]=point;values[index]=field.sample(point)
	if capture_boundary_values and step_metres==2:
		for face in range(6):
			var face_values:=PackedFloat32Array()
			for y in range(row):
				for x in range(row):
					var index:int=(count if face%2==1 else 0)+row*x+plane*y if face<2 else (x+row*(count if face%2==1 else 0)+plane*y if face<4 else x+row*y+plane*(count if face%2==1 else 0));face_values.append(values[index])
			boundary_values.append(face_values)
	var offsets:=PackedInt32Array([0,1,1+row,row,plane,1+plane,1+row+plane,row+plane])
	for z in range(count):
		for y in range(count):
			for x in range(count):
				var base:int=x+row*y+plane*z;var any_air:bool=false;var any_rock:bool=false
				for offset:int in offsets:
					any_air=any_air or values[base+offset]<0;any_rock=any_rock or values[base+offset]>=0
					if any_air and any_rock:break
				if not any_air or not any_rock:continue
				var cube_points:=PackedVector3Array();var cube_values:=PackedFloat32Array()
				for offset:int in offsets:cube_points.append(points[base+offset]);cube_values.append(values[base+offset])
				for indices_tet:Array in TETS:tetra(cube_points,cube_values,indices_tet)
	if vertices.is_empty():return []
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;return arrays
